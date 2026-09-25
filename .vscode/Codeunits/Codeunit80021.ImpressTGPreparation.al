codeunit 80021 "Impress TG Preparation"
{
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterDeleteEvent', '', false, false)]
    local procedure ClearStagingLinkAfterJournalDeletion(var Rec: Record "Item Journal Line"; RunTrigger: Boolean)
    var
        Staging: Record "Impress Inv Trans Staging";
        Tracking: Codeunit "Impress Posting Tracking";
        Remaining: Record "Item Journal Line";
    begin
        if Rec.IsTemporary() or not RunTrigger or IsNullGuid(Rec."Integration Posting ID") then
            exit;
        if Tracking.HasPostedEvidence(Rec."Integration Posting ID") then
            exit;
        Remaining.SetRange("Integration Posting ID", Rec."Integration Posting ID");
        if not Remaining.IsEmpty() then
            exit;
        Staging.SetRange("Integration Posting ID", Rec."Integration Posting ID");
        Staging.SetRange("Transaction Type", 'T');
        Staging.SetRange("Transaction Source", 'G');
        Staging.SetFilter("Processing Status", '%1|%2', Staging."Processing Status"::Pending, Staging."Processing Status"::Error);
        if Staging.FindSet(true) then
            repeat
                Clear(Staging."Integration Posting ID");
                Staging.Modify(true);
            until Staging.Next() = 0;
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure ProcessTG(var Selected: Record "Impress Inv Trans Staging")
    begin
        RunTG(Selected, false);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure PreviewTG(var Selected: Record "Impress Inv Trans Staging")
    begin
        RunTG(Selected, true);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure ProcessAA(var Row: Record "Impress Inv Trans Staging")
    var
        Defaults: Record "Impress Defaults";
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Journal: Record "Item Journal Line";
        Owner: Record "Impress Inv Trans Staging";
        Setup: Record "General Posting Setup";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        Tracking: Codeunit "Impress Posting Tracking";
        Reconciliation: Codeunit "Impress TG Reconciliation";
        AtomicPost: Codeunit "Impress Atomic Journal Post";
        GeneralRequirements: Dictionary of [Integer, Code[20]];
        InventoryRequirements: Dictionary of [Code[10], Code[20]];
        GenProdCode: Code[20];
        PostingGroup: Code[20];
        PostingID: Guid;
        EntryType: Enum "Item Ledger Entry Type";
    begin
        Row.Get(Row."Entry No.");
        Context := StrSubstNo('A/A SourceDatabase %1, Source Transaction ID %2', Row."Source Database", Row."Source Transaction ID");
        Row.TestField("Transaction Type", 'A');
        Row.TestField("Transaction Source", 'A');
        Require(Row.Quantity <> 0, 'Quantity', 'nonzero', '0');
        Defaults.Get();
        PostingID := Row."Integration Posting ID";
        if not IsNullGuid(PostingID) then begin
            Owner.SetRange("Integration Posting ID", PostingID);
            Owner.SetFilter("Entry No.", '<>%1', Row."Entry No.");
            Require(Owner.IsEmpty(), 'Integration Posting ID ownership', 'only this A/A row', 'another owner');
        end;
        GeneralRequirements.Add(Setup.FieldNo("Inventory Adjmt. Account"), Resolver.ValidateAccount(Row."Source Adjustment G/L Account", 'Source Adjustment G/L Account', Context));
        InventoryRequirements.Add(Row."BC Location Code", Resolver.ValidateAccount(Row."Source Inventory G/L Account", 'Source Inventory G/L Account', Context));
        if Tracking.HasPostedEvidence(PostingID) then begin
            Reconciliation.ReconcileAA(Row, PostingID, GeneralRequirements, InventoryRequirements, Context);
            exit;
        end;
        Require(Row."Processing Status" <> Row."Processing Status"::Processed, 'posted evidence', 'entries for Processed row', 'missing');
        ValidateTransport(Row);
        ValidateSide(Row);
        GetItemJournalSetup(Row."Source Database", Defaults, Template, Batch);
        Resolver.ValidateGeneralRequirements(Defaults."Gen. Bus. Posting Group (Inv.)", GeneralRequirements, Context);
        Resolver.ValidateInventoryRequirements(InventoryRequirements, Context);
        Journal.LockTable();
        Require(not FindPreparedJournal(PostingID, Journal), 'A/A preparation', 'no abandoned journal lines', 'remove unposted lines before retry');
        GenProdCode := Resolver.ResolveGeneralPostingSetup(Defaults."Gen. Bus. Posting Group (Inv.)", GeneralRequirements, Context);
        PostingGroup := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, Context);
        PostingID := CreateGuid();
        EntryType := EntryType::"Positive Adjmt.";
        if Row.Quantity < 0 then
            EntryType := EntryType::"Negative Adjmt.";
        PrepareComponent(Row, Row, Defaults, Template, Batch, GenProdCode, PostingGroup, PostingID,
            EntryType, Abs(Row.Quantity), 0, 0, Abs(Row.Quantity), false);
        SetProcessing(Row, PostingID);
        BindSubscription(AtomicPost);
        AtomicPost.PostComponents(PostingID);
        UnbindSubscription(AtomicPost);
        Reconciliation.ReconcileAA(Row, PostingID, GeneralRequirements, InventoryRequirements, Context);
        Require(not FindPreparedJournal(PostingID, Journal), 'journal cleanup', 'posted lines removed', 'journal remains');
    end;

    // Preview and Process share every preparation step. Only Process continues to posting.
    local procedure RunTG(var Selected: Record "Impress Inv Trans Staging"; PreviewOnly: Boolean)
    var
        Partner: Record "Impress Inv Trans Staging";
        FromRow: Record "Impress Inv Trans Staging";
        ToRow: Record "Impress Inv Trans Staging";
        SourceLock: Record "Impress Posting Source Lock";
        Defaults: Record "Impress Defaults";
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Journal: Record "Item Journal Line";
        AtomicPost: Codeunit "Impress Atomic Journal Post";
        Component: Record "Impress Journal Component";
        ItemTemplate: Record "Item Journal Template";
        ItemBatch: Record "Item Journal Batch";
        AvailableQty: Decimal;
        TransferQty: Decimal;
        ShortageQty: Decimal;
        ExpectedCount: Integer;
        Tracking: Codeunit "Impress Posting Tracking";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        GeneralRequirements: Dictionary of [Integer, Code[20]];
        InventoryRequirements: Dictionary of [Code[10], Code[20]];
        PostingGroup: Code[20];
        GenProdCode: Code[20];
        PostingID: Guid;
        ExistingJournal: Boolean;
    begin
        Selected.Get(Selected."Entry No.");
        Context := StrSubstNo('T/G SourceDatabase %1, selected Source Transaction ID %2, adjacent candidates %3 / %4',
            Selected."Source Database", Selected."Source Transaction ID", Selected."Source Transaction ID" - 1, Selected."Source Transaction ID" + 1);
        Require(Selected."Source Database" in ['ImpressTest', 'StickersTest'], 'SourceDatabase', 'ImpressTest or StickersTest', Selected."Source Database");
        SourceLock.LockTable();
        if not SourceLock.Get(Selected."Source Database") then begin
            SourceLock.Init();
            SourceLock."Source Database" := Selected."Source Database";
            SourceLock.Insert();
        end;
        Selected.LockTable();
        Selected.Get(Selected."Entry No.");
        Require(Selected."Source Database" = SourceLock."Source Database", 'locked SourceDatabase', SourceLock."Source Database", Selected."Source Database");
        Require(Selected."Transaction Type" = 'T', 'Transaction Type', 'T', Selected."Transaction Type");
        Require(Selected."Transaction Source" = 'G', 'Transaction Source', 'G', Selected."Transaction Source");
        FindPartner(Selected, Partner);
        Context := StrSubstNo('T/G SourceDatabase %1, Source Transaction IDs %2 / %3',
            Selected."Source Database", Selected."Source Transaction ID", Partner."Source Transaction ID");
        ValidatePair(Selected, Partner);
        if Selected.Quantity < 0 then begin
            FromRow := Selected;
            ToRow := Partner;
        end else begin
            FromRow := Partner;
            ToRow := Selected;
        end;
        Context += StrSubstNo(', Item %1, Variant %2, FROM %3 / inventory account %4 / adjustment account %5, TO %6 / inventory account %7 / adjustment account %8',
            FromRow."BC Item No.", FromRow."BC Variant Code", FromRow."BC Location Code", FromRow."Source Inventory G/L Account", FromRow."Source Adjustment G/L Account",
            ToRow."BC Location Code", ToRow."Source Inventory G/L Account", ToRow."Source Adjustment G/L Account");
        Require(Defaults.Get(), 'Impress Defaults', 'configured record', 'missing');
        Context += StrSubstNo(', Gen. Bus. Posting Group (Inv.) %1', Defaults."Gen. Bus. Posting Group (Inv.)");

        Journal.LockTable();
        PostingID := ResolvePostingID(FromRow, ToRow);
        Context += StrSubstNo(', Integration Posting ID %1', PostingID);
        BuildAccountRequirements(FromRow, ToRow, GeneralRequirements, InventoryRequirements);
        if Tracking.HasPostedEvidence(PostingID) then begin
            // Validate actual posted profiles, including legacy profiles; do not allocate new ones.
            Reconcile(FromRow, ToRow, PostingID, GeneralRequirements, InventoryRequirements, not PreviewOnly);
            if not PreviewOnly then
                if FindPreparedJournal(PostingID, Journal) then
                    Journal.DeleteAll(true);
            Selected.Get(Selected."Entry No.");
            exit;
        end;
        Require((FromRow."Processing Status" <> FromRow."Processing Status"::Processed) and
            (ToRow."Processing Status" <> ToRow."Processing Status"::Processed),
            'posted evidence', 'posted BC entries for a Processed pair; reconcile before retry', 'no posted entries for the GUID');
        ValidateSequence(FromRow, ToRow);
        ValidateTransport(FromRow);
        ValidateTransport(ToRow);
        ValidateSide(FromRow);
        ValidateSide(ToRow);
        AvailableQty := GetAvailability(FromRow);
        CalculateSplit(Abs(FromRow.Quantity), AvailableQty, TransferQty, ShortageQty);
        if FindPreparedJournal(PostingID, Journal) then begin
            Component.SetRange("Integration Posting ID", PostingID);
            Require(Component.FindFirst(), 'preview snapshot', 'delete all preview lines and recreate Preview', 'legacy preview has no availability snapshot');
            Require(Component."Available Quantity" = AvailableQty,
                'preview no longer matches current inventory', 'delete all preview lines and recreate Preview',
                StrSubstNo('preview availability %1; current availability %2', Component."Available Quantity", AvailableQty));
        end;
        if TransferQty > 0 then
            GetJournalSetup(FromRow, Defaults, Template, Batch);
        if ShortageQty > 0 then
            GetItemJournalSetup(FromRow."Source Database", Defaults, ItemTemplate, ItemBatch);
        // Validate ALL required accounts and configuration before either resolver creates setup.
        Resolver.ValidateGeneralRequirements(Defaults."Gen. Bus. Posting Group (Inv.)", GeneralRequirements, Context);
        Resolver.ValidateInventoryRequirements(InventoryRequirements, Context);

        ExistingJournal := FindPreparedJournal(PostingID, Journal);
        if ExistingJournal then begin
            Component.SetRange("Integration Posting ID", PostingID);
            Require(not Component.IsEmpty(), 'preview snapshot', 'recreate the legacy preview', 'missing availability snapshot');
            Require(Journal."Gen. Bus. Posting Group" = Defaults."Gen. Bus. Posting Group (Inv.)",
                'existing journal Gen. Bus. Posting Group', Defaults."Gen. Bus. Posting Group (Inv.)", Journal."Gen. Bus. Posting Group");
            GenProdCode := Journal."Gen. Prod. Posting Group";
            PostingGroup := Journal."Inventory Posting Group";
            Context += StrSubstNo(', prepared IMP profile %1, IMI profile %2', GenProdCode, PostingGroup);
            // Never silently substitute a different profile after a preview is changed.
            Resolver.ValidateGeneralProfile(Journal."Gen. Bus. Posting Group", GenProdCode, GeneralRequirements, true, Context);
            Resolver.ValidateInventoryProfile(PostingGroup, InventoryRequirements, true, Context);
        end else begin
            GenProdCode := Resolver.ResolveGeneralPostingSetup(Defaults."Gen. Bus. Posting Group (Inv.)", GeneralRequirements, Context);
            PostingGroup := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, Context);
            PostingID := CreateGuid();
            Context += StrSubstNo(', resolved IMP profile %1, IMI profile %2, new Integration Posting ID %3', GenProdCode, PostingGroup, PostingID);
        end;
        if TransferQty > 0 then begin
            PrepareComponent(FromRow, ToRow, Defaults, Template, Batch, GenProdCode, PostingGroup, PostingID,
                Journal."Entry Type"::Transfer, TransferQty, AvailableQty, TransferQty, ShortageQty, ExistingJournal);
            ExpectedCount += 1;
        end;
        if ShortageQty > 0 then begin
            PrepareComponent(FromRow, ToRow, Defaults, ItemTemplate, ItemBatch, GenProdCode, PostingGroup, PostingID,
                Journal."Entry Type"::"Negative Adjmt.", ShortageQty, AvailableQty, TransferQty, ShortageQty, ExistingJournal);
            PrepareComponent(FromRow, ToRow, Defaults, ItemTemplate, ItemBatch, GenProdCode, PostingGroup, PostingID,
                Journal."Entry Type"::"Positive Adjmt.", ShortageQty, AvailableQty, TransferQty, ShortageQty, ExistingJournal);
            ExpectedCount += 2;
        end;
        FindPreparedJournal(PostingID, Journal);
        Require(Journal.Count() = ExpectedCount, 'prepared component count', Format(ExpectedCount), Format(Journal.Count()));
        Component.SetRange("Integration Posting ID", PostingID);
        Require(Component.Count() = ExpectedCount, 'component reservation count', Format(ExpectedCount), Format(Component.Count()));
        if PreviewOnly then begin
            SetPrepared(FromRow, PostingID);
            SetPrepared(ToRow, PostingID);
            Selected.Get(Selected."Entry No.");
            exit; // Real journal and reusable setup persist; no BC posting and no final posted fields.
        end;

        SetProcessing(FromRow, PostingID);
        SetProcessing(ToRow, PostingID);
        BindSubscription(AtomicPost);
        AtomicPost.PostComponents(PostingID);
        UnbindSubscription(AtomicPost);
        Reconcile(FromRow, ToRow, PostingID, GeneralRequirements, InventoryRequirements, true);
        Require(not FindPreparedJournal(PostingID, Journal), 'journal cleanup', 'posted line removed by BC', 'journal line still exists');
        Selected.Get(Selected."Entry No.");
    end;

    procedure CalculateSplit(RequestedQty: Decimal; AvailableQty: Decimal; var TransferQty: Decimal; var ShortageQty: Decimal)
    begin
        if RequestedQty <= 0 then
            Error('Requested quantity must be positive.');
        TransferQty := 0;
        if AvailableQty > 0 then
            TransferQty := AvailableQty;
        if TransferQty > RequestedQty then
            TransferQty := RequestedQty;
        ShortageQty := RequestedQty - TransferQty;
    end;

    local procedure GetAvailability(Row: Record "Impress Inv Trans Staging"): Decimal
    var
        ItemEntry: Record "Item Ledger Entry";
        Item: Record Item;
    begin
        // Hold the standard inventory records through all components and reconciliation.
        // No date/open/positive filter: this is actual signed stock, not remaining FIFO layers.
        Item.LockTable();
        Item.Get(Row."BC Item No.");
        ItemEntry.LockTable();
        ItemEntry.SetCurrentKey("Item No.", "Entry Type", "Variant Code", "Drop Shipment", "Location Code", "Posting Date");
        ItemEntry.SetRange("Item No.", Row."BC Item No.");
        ItemEntry.SetRange("Variant Code", Row."BC Variant Code");
        ItemEntry.SetRange("Location Code", Row."BC Location Code");
        ItemEntry.CalcSums(Quantity);
        exit(ItemEntry.Quantity);
    end;

    procedure GetItemJournalSetup(SourceDatabase: Text[50]; Defaults: Record "Impress Defaults"; var Template: Record "Item Journal Template"; var Batch: Record "Item Journal Batch")
    var
        BatchName: Code[10];
    begin
        Defaults.TestField("Impress Item Journal Template");
        Template.Get(Defaults."Impress Item Journal Template");
        Template.TestField(Type, Template.Type::Item);
        Template.TestField(Recurring, false);
        case SourceDatabase of
            'ImpressTest': BatchName := Defaults."Apparel Item Journal Batch";
            'StickersTest': BatchName := Defaults."Stickers Item Journal Batch";
            else Error('Unsupported Source Database %1.', SourceDatabase);
        end;
        Require(BatchName <> '', 'source-specific Item Journal Batch', 'configured batch', 'blank');
        Batch.Get(Template.Name, BatchName);
        Batch.TestField("No. Series");
    end;

    local procedure PrepareComponent(FromRow: Record "Impress Inv Trans Staging"; ToRow: Record "Impress Inv Trans Staging"; Defaults: Record "Impress Defaults"; Template: Record "Item Journal Template"; Batch: Record "Item Journal Batch"; GenProdCode: Code[20]; PostingGroup: Code[20]; PostingID: Guid; EntryType: Enum "Item Ledger Entry Type"; ComponentQty: Decimal; AvailableQty: Decimal; TransferQty: Decimal; ShortageQty: Decimal; Existing: Boolean)
    var
        Expected: Record "Item Journal Line" temporary;
        Journal: Record "Item Journal Line";
        Component: Record "Impress Journal Component";
        Numbering: Codeunit "Impress Journal Numbering";
        Signature: Text;
    begin
        Signature := SourceSignature(FromRow) + SourceSignature(ToRow);
        BuildJournal(Expected, FromRow, ToRow, Defaults, Template, Batch, GenProdCode, PostingGroup, PostingID, EntryType, ComponentQty);
        if Existing then begin
            Component.SetRange("Integration Posting ID", PostingID);
            Component.SetRange("Entry Type", EntryType);
            Require(Component.FindFirst(), 'preview no longer matches current inventory', 'delete all preview lines and recreate Preview', 'component is missing or split changed');
            Require((Component."Available Quantity" = AvailableQty) and
                (Component."Requested Quantity" = Abs(FromRow.Quantity)) and
                (Component."Transfer Quantity" = TransferQty) and (Component."Shortage Quantity" = ShortageQty) and
                (Component."Source Signature" = Signature),
                'preview no longer matches current inventory or source', 'delete all preview lines and recreate Preview', 'availability, quantity or source mapping changed');
            Require(Journal.GetBySystemId(Component."Journal System ID"), 'preview component', 'delete all preview lines and recreate Preview', 'journal was deleted');
            ValidateExistingJournal(Journal, Expected, FromRow, ToRow, PostingGroup);
            Numbering.ValidateReservation(Journal, Batch."No. Series");
        end else begin
            Journal := Expected;
            Numbering.InsertWithReservedNumber(Journal, Batch."No. Series");
            Component.SetRange("Integration Posting ID", PostingID);
            Component.SetRange("Journal System ID", Journal.SystemId);
            Component.FindFirst();
            Component."Available Quantity" := AvailableQty;
            Component."Requested Quantity" := Abs(FromRow.Quantity);
            Component."Transfer Quantity" := TransferQty;
            Component."Shortage Quantity" := ShortageQty;
            Component."Source Signature" := CopyStr(Signature, 1, MaxStrLen(Component."Source Signature"));
            Require(StrLen(Signature) <= MaxStrLen(Component."Source Signature"), 'source snapshot length', 'within snapshot capacity', Format(StrLen(Signature)));
            Component.Modify();
        end;
    end;

    local procedure SourceSignature(Row: Record "Impress Inv Trans Staging") Result: Text
    var
        Source: JsonObject;
    begin
        Source.Add('database', Row."Source Database");
        Source.Add('id', Row."Source Transaction ID");
        Source.Add('item', Row."BC Item No.");
        Source.Add('variant', Row."BC Variant Code");
        Source.Add('location', Row."BC Location Code");
        Source.Add('date', Row."G/L Date");
        Source.Add('quantity', Row.Quantity);
        Source.Add('inventoryAccount', Row."Source Inventory G/L Account");
        Source.Add('adjustmentAccount', Row."Source Adjustment G/L Account");
        Source.Add('division', Row."Division Code");
        Source.Add('order', Row."Source Order No.");
        Source.Add('line', Row."Source Order Line No.");
        Source.WriteTo(Result);
    end;

    local procedure BuildAccountRequirements(FromRow: Record "Impress Inv Trans Staging"; ToRow: Record "Impress Inv Trans Staging"; var GeneralRequirements: Dictionary of [Integer, Code[20]]; var InventoryRequirements: Dictionary of [Code[10], Code[20]])
    var
        Setup: Record "General Posting Setup";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        AdjustmentAccount: Text;
    begin
        AdjustmentAccount := FromRow."Source Adjustment G/L Account";
        if AdjustmentAccount = '' then
            AdjustmentAccount := ToRow."Source Adjustment G/L Account"
        else
            if ToRow."Source Adjustment G/L Account" <> '' then
                Require(AdjustmentAccount = ToRow."Source Adjustment G/L Account", 'pair Source Adjustment G/L Account',
                    AdjustmentAccount, ToRow."Source Adjustment G/L Account");
        Require(AdjustmentAccount <> '', 'Source Adjustment G/L Account', 'one agreed nonblank account across the pair', 'both blank');
        Clear(GeneralRequirements);
        Clear(InventoryRequirements);
        GeneralRequirements.Add(Setup.FieldNo("Inventory Adjmt. Account"), Resolver.ValidateAccount(AdjustmentAccount, 'Source Adjustment G/L Account', Context));
        InventoryRequirements.Add(FromRow."BC Location Code", Resolver.ValidateAccount(FromRow."Source Inventory G/L Account", 'FROM Source Inventory G/L Account', Context));
        InventoryRequirements.Add(ToRow."BC Location Code", Resolver.ValidateAccount(ToRow."Source Inventory G/L Account", 'TO Source Inventory G/L Account', Context));
    end;

    local procedure SetPrepared(var Row: Record "Impress Inv Trans Staging"; PostingID: Guid)
    begin
        Row."Integration Posting ID" := PostingID;
        Row."Processing Status" := Row."Processing Status"::Pending;
        Clear(Row."Error Message");
        Clear(Row."Date Processing Started");
        Clear(Row."Date Processed");
        Clear(Row."BC Posted Document Type");
        Clear(Row."BC Posted Document No.");
        Clear(Row."BC Posted Posting Date");
        Clear(Row."BC Document No.");
        Clear(Row."Processed Date/Time");
        Row.Modify(true);
    end;

    local procedure GetJournalSetup(FromRow: Record "Impress Inv Trans Staging"; var Defaults: Record "Impress Defaults"; var Template: Record "Item Journal Template"; var Batch: Record "Item Journal Batch")
    var
        BatchName: Code[10];
    begin
        Require(Defaults.Get(), 'Impress Defaults', 'configured record', 'missing');
        Require(Defaults."Impress Reclass Jnl. Template" <> '', 'Impress Reclass Journal Template', 'configured template', 'blank');
        Require(Template.Get(Defaults."Impress Reclass Jnl. Template"), 'Item Journal Template', Defaults."Impress Reclass Jnl. Template", 'missing');
        Require(Template.Type = Template.Type::Transfer, 'Item Journal Template Type', 'Transfer', Format(Template.Type));
        Require(not Template.Recurring, 'Recurring template', 'false', Format(Template.Recurring));
        case FromRow."Source Database" of
            'ImpressTest': BatchName := Defaults."Apparel Reclass Journal Batch";
            'StickersTest': BatchName := Defaults."Stickers Reclass Journal Batch";
        end;
        Require(BatchName <> '', 'source-specific Reclass Journal Batch', 'configured batch', 'blank');
        Require(Batch.Get(Template.Name, BatchName), 'Item Journal Batch', Template.Name + '/' + BatchName, 'missing');
        Require(Batch."No. Series" <> '', 'journal batch No. Series', 'configured number series', 'blank');
    end;

    local procedure BuildJournal(var Journal: Record "Item Journal Line" temporary; FromRow: Record "Impress Inv Trans Staging"; ToRow: Record "Impress Inv Trans Staging"; Defaults: Record "Impress Defaults"; Template: Record "Item Journal Template"; Batch: Record "Item Journal Batch"; GenProdCode: Code[20]; PostingGroup: Code[20]; PostingID: Guid; EntryType: Enum "Item Ledger Entry Type"; ComponentQty: Decimal)
    var
        LastJournal: Record "Item Journal Line";
        DimensionManagement: Codeunit DimensionManagement;
        AtomicPost: Codeunit "Impress Atomic Journal Post";
        DimensionSetID: Integer;
        NewDimensionSetID: Integer;
    begin
        Require(StrLen(FromRow."Source Order No.") <= MaxStrLen(Journal."External Document No."),
            'Source Order No. length', Format(MaxStrLen(Journal."External Document No.")), Format(StrLen(FromRow."Source Order No.")));
        LastJournal.SetRange("Journal Template Name", Template.Name);
        LastJournal.SetRange("Journal Batch Name", Batch.Name);
        Clear(Journal);
        Journal.Init();
        Journal."Journal Template Name" := Template.Name;
        Journal."Journal Batch Name" := Batch.Name;
        Journal."Line No." := 10000;
        if LastJournal.FindLast() then
            Journal."Line No." := LastJournal."Line No." + 10000;
        Journal.Validate("Posting Date", FromRow."G/L Date");
        Journal.Validate("Entry Type", EntryType);
        Journal."Source Code" := Template."Source Code";
        Journal."Reason Code" := Batch."Reason Code";
        Journal.Validate("Item No.", FromRow."BC Item No.");
        Journal.Validate("Variant Code", FromRow."BC Variant Code");
        if EntryType = EntryType::"Positive Adjmt." then
            Journal.Validate("Location Code", ToRow."BC Location Code")
        else
            Journal.Validate("Location Code", FromRow."BC Location Code");
        if EntryType = EntryType::Transfer then
            Journal.Validate("New Location Code", ToRow."BC Location Code");
        Journal.Validate(Quantity, ComponentQty);
        if EntryType = EntryType::"Positive Adjmt." then
            AtomicPost.RefreshPositiveCost(Journal);
        Require(Journal."Quantity (Base)" = ComponentQty, 'Quantity (Base)', Format(ComponentQty), Format(Journal."Quantity (Base)"));
        Journal."External Document No." := FromRow."Source Order No.";
        Journal.Validate("Gen. Bus. Posting Group", Defaults."Gen. Bus. Posting Group (Inv.)");
        Journal.Validate("Gen. Prod. Posting Group", GenProdCode);
        Journal.Validate("Inventory Posting Group", PostingGroup);
        DimensionSetID := Journal."Dimension Set ID";
        NewDimensionSetID := Journal."New Dimension Set ID";
        if EntryType = EntryType::"Positive Adjmt." then
            ApplyCategory(ToRow, Defaults, DimensionSetID)
        else
            ApplyCategory(FromRow, Defaults, DimensionSetID);
        if EntryType = EntryType::Transfer then
            ApplyCategory(ToRow, Defaults, NewDimensionSetID);
        Journal.Validate("Dimension Set ID", DimensionSetID);
        Journal.Validate("New Dimension Set ID", NewDimensionSetID);
        // Insert(true) revalidates all four shortcut fields. Keep them consistent
        // with the sets so a blank shortcut cannot remove a global CATEGORY.
        DimensionManagement.UpdateGlobalDimFromDimSetID(Journal."Dimension Set ID",
            Journal."Shortcut Dimension 1 Code", Journal."Shortcut Dimension 2 Code");
        DimensionManagement.UpdateGlobalDimFromDimSetID(Journal."New Dimension Set ID",
            Journal."New Shortcut Dimension 1 Code", Journal."New Shortcut Dimension 2 Code");
        Journal."Integration Posting ID" := PostingID;
    end;

    local procedure ValidateExistingJournal(Journal: Record "Item Journal Line"; Expected: Record "Item Journal Line" temporary; FromRow: Record "Impress Inv Trans Staging"; ToRow: Record "Impress Inv Trans Staging"; PostingGroup: Code[20])
    begin
        Journal.TestField("Entry Type", Expected."Entry Type");
        Journal.TestField("Item No.", Expected."Item No.");
        Journal.TestField("Variant Code", Expected."Variant Code");
        Journal.TestField("Location Code", Expected."Location Code");
        Journal.TestField("New Location Code", Expected."New Location Code");
        Journal.TestField(Quantity, Expected.Quantity);
        Journal.TestField("Quantity (Base)", Expected."Quantity (Base)");
        Journal.TestField("Posting Date", Expected."Posting Date");
        Journal.TestField("Inventory Posting Group", Expected."Inventory Posting Group");
        Journal.TestField("External Document No.", Expected."External Document No.");
        Journal.TestField("Source Code", Expected."Source Code");
        Journal.TestField("Reason Code", Expected."Reason Code");
        Journal.TestField("Applies-to Entry", 0);
        Journal.TestField("Applies-from Entry", 0);
        Journal.TestField("Shortcut Dimension 1 Code", Expected."Shortcut Dimension 1 Code");
        Journal.TestField("Shortcut Dimension 2 Code", Expected."Shortcut Dimension 2 Code");
        Journal.TestField("New Shortcut Dimension 1 Code", Expected."New Shortcut Dimension 1 Code");
        Journal.TestField("New Shortcut Dimension 2 Code", Expected."New Shortcut Dimension 2 Code");
        Require(Journal."Integration Posting ID" = Expected."Integration Posting ID", 'existing journal Integration Posting ID', Format(Expected."Integration Posting ID"), Format(Journal."Integration Posting ID"));
        Require(Journal."Gen. Bus. Posting Group" = Expected."Gen. Bus. Posting Group", 'existing journal Gen. Bus. Posting Group', Expected."Gen. Bus. Posting Group", Journal."Gen. Bus. Posting Group");
        Require(Journal."Gen. Prod. Posting Group" = Expected."Gen. Prod. Posting Group", 'existing journal Gen. Prod. Posting Group', Expected."Gen. Prod. Posting Group", Journal."Gen. Prod. Posting Group");
        Require(Journal."Journal Template Name" = Expected."Journal Template Name", 'existing journal template', Expected."Journal Template Name", Journal."Journal Template Name");
        Require(Journal."Journal Batch Name" = Expected."Journal Batch Name", 'existing journal batch', Expected."Journal Batch Name", Journal."Journal Batch Name");
        Require(Journal."Unit of Measure Code" = Expected."Unit of Measure Code", 'existing journal unit of measure', Expected."Unit of Measure Code", Journal."Unit of Measure Code");
        Require(Journal."Qty. per Unit of Measure" = Expected."Qty. per Unit of Measure", 'existing journal unit conversion', Format(Expected."Qty. per Unit of Measure"), Format(Journal."Qty. per Unit of Measure"));
        Require(Journal."Dimension Set ID" = Expected."Dimension Set ID", 'existing journal FROM dimensions', Format(Expected."Dimension Set ID"), Format(Journal."Dimension Set ID"));
        Require(Journal."New Dimension Set ID" = Expected."New Dimension Set ID", 'existing journal TO dimensions', Format(Expected."New Dimension Set ID"), Format(Journal."New Dimension Set ID"));
        Journal.TestField("Value Entry Type", Journal."Value Entry Type"::"Direct Cost");
        Journal.TestField("Item Charge No.", '');
        Journal.TestField("Phys. Inventory", false);
        Journal.TestField("Recurring Method", 0);
        Journal.TestField("Inventory Value Per", Journal."Inventory Value Per"::" ");
    end;

    local procedure ResolvePostingID(FromRow: Record "Impress Inv Trans Staging"; ToRow: Record "Impress Inv Trans Staging"): Guid
    var
        Owner: Record "Impress Inv Trans Staging";
        PostingID: Guid;
    begin
        PostingID := FromRow."Integration Posting ID";
        if IsNullGuid(PostingID) then
            PostingID := ToRow."Integration Posting ID";
        if not IsNullGuid(FromRow."Integration Posting ID") and not IsNullGuid(ToRow."Integration Posting ID") then
            Require(FromRow."Integration Posting ID" = ToRow."Integration Posting ID", 'pair Integration Posting IDs',
                Format(FromRow."Integration Posting ID"), Format(ToRow."Integration Posting ID"));
        if not IsNullGuid(PostingID) then begin
            Owner.SetRange("Integration Posting ID", PostingID);
            Owner.SetFilter("Entry No.", '<>%1&<>%2', FromRow."Entry No.", ToRow."Entry No.");
            Require(Owner.IsEmpty(), 'Integration Posting ID ownership', 'only this source pair', 'another staging row uses ' + Format(PostingID));
        end;
        exit(PostingID);
    end;

    local procedure ValidateSequence(FromRow: Record "Impress Inv Trans Staging"; ToRow: Record "Impress Inv Trans Staging")
    var
        Earlier: Record "Impress Inv Trans Staging";
        LastSourceID: BigInteger;
    begin
        LastSourceID := FromRow."Source Transaction ID";
        if ToRow."Source Transaction ID" > LastSourceID then
            LastSourceID := ToRow."Source Transaction ID";
        Earlier.SetCurrentKey("Source Database", "Source Transaction ID");
        Earlier.SetRange("Source Database", FromRow."Source Database");
        // No unresolved row may precede or sit between the two paired entries.
        Earlier.SetFilter("Source Transaction ID", '<%1&<>%2&<>%3', LastSourceID, FromRow."Source Transaction ID", ToRow."Source Transaction ID");
        Earlier.SetFilter("Processing Status", '<>%1', Earlier."Processing Status"::Processed);
        if Earlier.FindFirst() then
            Require(false, 'source sequence', 'earlier transactions processed first',
                StrSubstNo('Entry No. %1 (Source Transaction ID %2) is %3', Earlier."Entry No.", Earlier."Source Transaction ID", Earlier."Processing Status"));
    end;

    local procedure ValidateTransport(Row: Record "Impress Inv Trans Staging")
    begin
        Require(Row."Transport Status" in [Row."Transport Status"::Sent, Row."Transport Status"::Processed],
            StrSubstNo('transaction %1 Transport Status', Row."Source Transaction ID"), 'Sent or Processed', Format(Row."Transport Status"));
    end;

    local procedure SetProcessing(var Row: Record "Impress Inv Trans Staging"; PostingID: Guid)
    begin
        Row."Integration Posting ID" := PostingID;
        Row."Processing Status" := Row."Processing Status"::Processing;
        Row."Date Processing Started" := CurrentDateTime();
        Clear(Row."Error Message");
        Row.Modify(true);
    end;

    local procedure FindPartner(Selected: Record "Impress Inv Trans Staging"; var Partner: Record "Impress Inv Trans Staging")
    var
        Candidate: Record "Impress Inv Trans Staging";
        OnlyCandidate: Record "Impress Inv Trans Staging";
        CandidateCount: Integer;
        EligibleCount: Integer;
        MatchCount: Integer;
        LinkedMatchCount: Integer;
        LinkedPartner: Record "Impress Inv Trans Staging";
    begin
        Candidate.SetRange("Source Database", Selected."Source Database");
        Candidate.SetFilter("Source Transaction ID", '%1|%2', Selected."Source Transaction ID" - 1, Selected."Source Transaction ID" + 1);
        if Candidate.FindSet() then
            repeat
                CandidateCount += 1;
                if not IsNullGuid(Selected."Integration Posting ID") and
                    (Selected."Integration Posting ID" = Candidate."Integration Posting ID") then begin
                    LinkedMatchCount += 1;
                    LinkedPartner := Candidate;
                end;
                if CandidateAvailableForPair(Selected, Candidate) then begin
                    EligibleCount += 1;
                    OnlyCandidate := Candidate;
                    if PairMatches(Selected, Candidate) then begin
                        MatchCount += 1;
                        Partner := Candidate;
                    end;
                end;
            until Candidate.Next() = 0;
        if LinkedMatchCount = 1 then begin
            Partner := LinkedPartner;
            exit; // Existing pair identity disambiguates identical adjacent transfers; validation still follows.
        end;
        if MatchCount = 1 then
            exit;
        if MatchCount = 2 then
            if ResolveFirstUnclaimedPair(Selected, Partner) then
                exit;
        if (MatchCount = 0) and (EligibleCount = 1) then begin
            Partner := OnlyCandidate;
            exit; // Detailed field validation follows.
        end;
        Require(false, 'adjacent partner', 'exactly one valid adjacent T/G partner',
            StrSubstNo('%1 adjacent rows; %2 eligible rows; %3 matching pairs. Already-owned or unlinked posted rows cannot be reused. Check type/source, item, variant, date, order, signs, quantities and locations.', CandidateCount, EligibleCount, MatchCount));
    end;

    local procedure ResolveFirstUnclaimedPair(Selected: Record "Impress Inv Trans Staging"; var Partner: Record "Impress Inv Trans Staging"): Boolean
    var
        Previous: Record "Impress Inv Trans Staging";
        Following: Record "Impress Inv Trans Staging";
        FirstUnresolved: Record "Impress Inv Trans Staging";
    begin
        // Existing GUIDs are stronger evidence than sequence; do not reassign them.
        if not IsNullGuid(Selected."Integration Posting ID") then
            exit(false);
        Previous.SetRange("Source Database", Selected."Source Database");
        Previous.SetRange("Source Transaction ID", Selected."Source Transaction ID" - 1);
        Following.SetRange("Source Database", Selected."Source Database");
        Following.SetRange("Source Transaction ID", Selected."Source Transaction ID" + 1);
        if not Previous.FindFirst() or not Following.FindFirst() then
            exit(false);
        if not IsNullGuid(Previous."Integration Posting ID") or not IsNullGuid(Following."Integration Posting ID") then
            exit(false);
        FirstUnresolved.SetCurrentKey("Source Database", "Source Transaction ID");
        FirstUnresolved.SetRange("Source Database", Selected."Source Database");
        FirstUnresolved.SetFilter("Processing Status", '<>%1', FirstUnresolved."Processing Status"::Processed);
        if not FirstUnresolved.FindFirst() then
            exit(false);
        if FirstUnresolved."Source Transaction ID" < Previous."Source Transaction ID" then
            Require(false, 'source sequence', 'process the earliest unresolved transaction/pair first',
                StrSubstNo('Source Transaction ID %1 is %2; transaction %3 cannot skip it',
                    FirstUnresolved."Source Transaction ID", FirstUnresolved."Processing Status", Selected."Source Transaction ID"));
        if FirstUnresolved."Entry No." <> Previous."Entry No." then
            exit(false);
        // The selected row is the second row of the first unresolved adjacent pair.
        // Consume that pair before the following row; do not use signs or ID parity.
        if not CandidateAvailableForPair(Selected, Previous) or not PairMatches(Selected, Previous) then
            exit(false);
        Partner := Previous;
        exit(true);
    end;

    local procedure CandidateAvailableForPair(Selected: Record "Impress Inv Trans Staging"; Candidate: Record "Impress Inv Trans Staging"): Boolean
    var
        Owner: Record "Impress Inv Trans Staging";
    begin
        if not IsNullGuid(Candidate."Integration Posting ID") then begin
            if not IsNullGuid(Selected."Integration Posting ID") and
                (Selected."Integration Posting ID" <> Candidate."Integration Posting ID") then
                exit(false);
            // A preceding receipt can look identical to the next receipt, but its
            // GUID may already belong to a different logical pair (posted or previewed).
            Owner.SetRange("Integration Posting ID", Candidate."Integration Posting ID");
            Owner.SetFilter("Entry No.", '<>%1&<>%2', Selected."Entry No.", Candidate."Entry No.");
            exit(Owner.IsEmpty());
        end;
        // Do not adopt legacy posted rows lacking a correlation key. One-sided
        // GUID recovery remains possible when the candidate has no other owner.
        exit((Candidate."Processing Status" <> Candidate."Processing Status"::Processed) and
            (Candidate."BC Posted Document No." = '') and (Candidate."Processed Date/Time" = 0DT));
    end;

    local procedure PairMatches(A: Record "Impress Inv Trans Staging"; B: Record "Impress Inv Trans Staging"): Boolean
    begin
        exit((B."Transaction Type" = 'T') and (B."Transaction Source" = 'G') and
            (A."BC Item No." = B."BC Item No.") and (A."BC Variant Code" = B."BC Variant Code") and
            (A."G/L Date" = B."G/L Date") and (A."Source Order No." = B."Source Order No.") and
            (A."Source Order Line No." = B."Source Order Line No.") and
            (A.Quantity <> 0) and (A.Quantity = -B.Quantity) and (A."BC Location Code" <> B."BC Location Code"));
    end;

    local procedure ValidatePair(A: Record "Impress Inv Trans Staging"; B: Record "Impress Inv Trans Staging")
    begin
        Require(A."Source Database" = B."Source Database", 'SourceDatabase', A."Source Database", B."Source Database");
        Require(B."Transaction Type" = 'T', 'partner Transaction Type', 'T', B."Transaction Type");
        Require(B."Transaction Source" = 'G', 'partner Transaction Source', 'G', B."Transaction Source");
        Require(A."BC Item No." = B."BC Item No.", 'partner BC Item No.', A."BC Item No.", B."BC Item No.");
        Require(A."BC Variant Code" = B."BC Variant Code", 'partner BC Variant Code', A."BC Variant Code", B."BC Variant Code");
        Require(A."G/L Date" = B."G/L Date", 'partner G/L Date', Format(A."G/L Date"), Format(B."G/L Date"));
        Require(A."Source Order No." = B."Source Order No.", 'partner Source Order No.', A."Source Order No.", B."Source Order No.");
        Require(A."Source Order Line No." = B."Source Order Line No.", 'partner Source Order Line No.', Format(A."Source Order Line No."), Format(B."Source Order Line No."));
        Require((A.Quantity <> 0) and (A.Quantity = -B.Quantity), 'partner Quantity', Format(-A.Quantity) + ' (nonzero, opposite sign)', Format(B.Quantity));
        Require(A."BC Location Code" <> B."BC Location Code", 'partner BC Location Code', 'different from ' + A."BC Location Code", B."BC Location Code");
    end;

    local procedure ValidateSide(Row: Record "Impress Inv Trans Staging")
    var
        Item: Record Item;
        Variant: Record "Item Variant";
        Location: Record Location;
        Account: Record "G/L Account";
        Side: Text;
    begin
        Side := StrSubstNo('transaction %1 ', Row."Source Transaction ID");
        Require(Row."BC Item No." <> '', Side + 'BC Item No.', 'nonblank item', 'blank');
        Require(Item.Get(Row."BC Item No."), Side + 'BC Item No.', Row."BC Item No.", 'missing');
        Require(Item.Type = Item.Type::Inventory, Side + 'Item Type', 'Inventory', Format(Item.Type));
        Require(not Item.Blocked, Side + 'Item Blocked', 'false', Format(Item.Blocked));
        if Row."BC Variant Code" <> '' then
            Require(Variant.Get(Row."BC Item No.", Row."BC Variant Code"), Side + 'BC Variant Code', Row."BC Variant Code", 'missing for item ' + Row."BC Item No.");
        Require(Row."BC Location Code" <> '', Side + 'BC Location Code', 'nonblank location', 'blank');
        Require(Location.Get(Row."BC Location Code"), Side + 'BC Location Code', Row."BC Location Code", 'missing');
        Require(not Location."Use As In-Transit", Side + 'Use As In-Transit', 'false', Format(Location."Use As In-Transit"));
        Require(Row."G/L Date" <> 0D, Side + 'G/L Date', 'nonblank date', Format(Row."G/L Date"));
        Require(Row."Source Inventory G/L Account" <> '', Side + 'Source Inventory G/L Account', 'nonblank account', 'blank');
        Require(StrLen(Row."Source Inventory G/L Account") <= MaxStrLen(Account."No."), Side + 'Inventory Account length', Format(MaxStrLen(Account."No.")), Format(StrLen(Row."Source Inventory G/L Account")));
        Require(Account.Get(Row."Source Inventory G/L Account"), Side + 'Inventory G/L Account', Row."Source Inventory G/L Account", 'missing');
        Require(Account."Account Type" = Account."Account Type"::Posting, Side + 'Inventory Account Type', 'Posting', Format(Account."Account Type"));
        Require(not Account.Blocked, Side + 'Inventory Account Blocked', 'false', Format(Account.Blocked));
    end;

    local procedure FindPreparedJournal(PostingID: Guid; var Journal: Record "Item Journal Line"): Boolean
    begin
        Journal.Reset();
        if IsNullGuid(PostingID) then
            exit(false);
        Journal.SetRange("Integration Posting ID", PostingID);
        exit(Journal.FindFirst());
    end;

    local procedure Reconcile(var FromRow: Record "Impress Inv Trans Staging"; var ToRow: Record "Impress Inv Trans Staging"; PostingID: Guid; GeneralRequirements: Dictionary of [Integer, Code[20]]; InventoryRequirements: Dictionary of [Code[10], Code[20]]; CompleteStaging: Boolean)
    var
        Reconciliation: Codeunit "Impress TG Reconciliation";
    begin
        Reconciliation.Reconcile(FromRow, ToRow, PostingID, GeneralRequirements, InventoryRequirements, Context, CompleteStaging);
    end;

    local procedure ApplyCategory(Row: Record "Impress Inv Trans Staging"; Defaults: Record "Impress Defaults"; var DimensionSetID: Integer)
    var
        Category: Codeunit "Impress Category Dimension";
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
        CategoryValue: Code[20];
    begin
        Require(Defaults."Category Dimension Code" <> '', 'Category Dimension Code', 'configured dimension', 'blank');
        Require(Dimension.Get(Defaults."Category Dimension Code"), 'Category Dimension', Defaults."Category Dimension Code", 'missing');
        Require(not Dimension.Blocked, 'Category Dimension Blocked', 'false', Format(Dimension.Blocked));
        if UpperCase(Row."Source Database") = 'STICKERSTEST' then
            Require(Row."Division Code" in ['', 'STK', 'HG'], 'Division Code', 'blank, STK or HG', Row."Division Code");
        CategoryValue := Category.GetDimensionValueCode(Row."Source Database", Row."Division Code");
        Require(DimensionValue.Get(Defaults."Category Dimension Code", CategoryValue), 'Category Dimension Value', CategoryValue, 'missing');
        Require(not DimensionValue.Blocked, 'Category Dimension Value Blocked', 'false', Format(DimensionValue.Blocked));
        Category.ApplyToDimensionSet(DimensionSetID, Defaults."Category Dimension Code", CategoryValue);
    end;

    local procedure Require(Condition: Boolean; FieldOrSetup: Text; Expected: Text; Actual: Text)
    begin
        if not Condition then
            Error('%1. %2: expected [%3]; actual [%4].', Context, FieldOrSetup, Expected, Actual);
    end;

    var
        Context: Text;
}
