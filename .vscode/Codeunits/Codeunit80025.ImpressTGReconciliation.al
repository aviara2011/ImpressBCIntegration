codeunit 80025 "Impress TG Reconciliation"
{
    procedure Reconcile(var FromRow: Record "Impress Inv Trans Staging"; var ToRow: Record "Impress Inv Trans Staging"; PostingID: Guid; GeneralRequirements: Dictionary of [Integer, Code[20]]; InventoryRequirements: Dictionary of [Code[10], Code[20]]; PostingContext: Text; CompleteStaging: Boolean)
    var
        ItemEntry: Record "Item Ledger Entry";
        FirstValue: Record "Value Entry";
        Reservation: Record "Impress Journal Reservation";
        Component: Record "Impress Journal Component";
        Tracking: Codeunit "Impress Posting Tracking";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        PostingGroup: Code[20];
        GenBusCode: Code[20];
        GenProdCode: Code[20];
        DocumentNo: Code[20];
        PostingDate: Date;
        FromQuantity: Decimal;
        ToQuantity: Decimal;
        ProcessedAt: DateTime;
    begin
        Context := PostingContext;
        Require(not IsNullGuid(PostingID), 'a nonblank Integration Posting ID', 'blank GUID');
        ItemEntry.SetCurrentKey("Integration Posting ID");
        ItemEntry.SetRange("Integration Posting ID", PostingID);
        Require(ItemEntry.FindSet(), 'posted Item Ledger Entries for the GUID', 'none');
        FirstValue.SetCurrentKey("Item Ledger Entry No.");
        FirstValue.SetRange("Item Ledger Entry No.", ItemEntry."Entry No.");
        Require(FirstValue.FindFirst(), 'posted Value Entry for profile reconciliation', 'none');
        PostingGroup := FirstValue."Inventory Posting Group";
        GenBusCode := FirstValue."Gen. Bus. Posting Group";
        GenProdCode := FirstValue."Gen. Prod. Posting Group";
        Context += StrSubstNo(', posted General profile %1/%2, Inventory profile %3', GenBusCode, GenProdCode, PostingGroup);
        // Existing posted profiles are authoritative history. Do not allocate new profiles
        // or require historical codes to follow the current IMP/IMI naming convention.
        Resolver.ValidateGeneralProfile(GenBusCode, GenProdCode, GeneralRequirements, false, Context);
        Resolver.ValidateInventoryProfile(PostingGroup, InventoryRequirements, false, Context);
        DocumentNo := ItemEntry."Document No.";
        PostingDate := ItemEntry."Posting Date";
        Require(DocumentNo <> '', 'posted Document No.', 'blank');
        Require(PostingDate = FromRow."G/L Date", Format(FromRow."G/L Date"), Format(PostingDate));
        Component.SetRange("Integration Posting ID", PostingID);
        if Reservation.Get(PostingID) then begin
            if Component.FindFirst() then
                Require(Component."Document No." = Reservation."Document No.", 'reserved primary component document', Component."Document No.")
            else
                Require(DocumentNo = Reservation."Document No.", 'reserved legacy document', DocumentNo);
            DocumentNo := Reservation."Document No.";
            Require(PostingDate = Reservation."Posting Date",
                'reserved document ' + Reservation."Document No." + ' / ' + Format(Reservation."Posting Date"),
                DocumentNo + ' / ' + Format(PostingDate));
        end;
        repeat
            if Component.IsEmpty() then
                Require(ItemEntry."Entry Type" = ItemEntry."Entry Type"::Transfer, 'legacy Transfer Item Ledger Entry', Format(ItemEntry."Entry Type"))
            else
                ValidateComponentDocument(ItemEntry);
            Require(ItemEntry."Item No." = FromRow."BC Item No.", FromRow."BC Item No.", ItemEntry."Item No.");
            Require(ItemEntry."Variant Code" = FromRow."BC Variant Code", FromRow."BC Variant Code", ItemEntry."Variant Code");
            Require(((ItemEntry."Document No." = DocumentNo) or not Component.IsEmpty()) and (ItemEntry."Posting Date" = PostingDate),
                DocumentNo + ' / ' + Format(PostingDate), ItemEntry."Document No." + ' / ' + Format(ItemEntry."Posting Date"));
            case ItemEntry."Location Code" of
                FromRow."BC Location Code":
                    begin
                        Require(ItemEntry.Quantity < 0, 'negative FROM quantity', Format(ItemEntry.Quantity));
                        Require(ItemEntry."Entry Type" in [ItemEntry."Entry Type"::Transfer, ItemEntry."Entry Type"::"Negative Adjmt."], 'transfer or negative adjustment at FROM', Format(ItemEntry."Entry Type"));
                        ReconcileCategory(ItemEntry, FromRow);
                        FromQuantity += ItemEntry.Quantity;
                    end;
                ToRow."BC Location Code":
                    begin
                        Require(ItemEntry.Quantity > 0, 'positive TO quantity', Format(ItemEntry.Quantity));
                        Require(ItemEntry."Entry Type" in [ItemEntry."Entry Type"::Transfer, ItemEntry."Entry Type"::"Positive Adjmt."], 'transfer or positive adjustment at TO', Format(ItemEntry."Entry Type"));
                        ReconcileCategory(ItemEntry, ToRow);
                        ToQuantity += ItemEntry.Quantity;
                    end;
                else
                    Require(false, FromRow."BC Location Code" + ' or ' + ToRow."BC Location Code", ItemEntry."Location Code");
            end;
            Tracking.AddLink(PostingID, Database::"Item Ledger Entry", ItemEntry."Entry No.", ItemEntry.SystemId, ItemEntry."Document No.", ItemEntry."Posting Date");
            ReconcileValues(ItemEntry, PostingGroup, GenBusCode, GenProdCode);
        until ItemEntry.Next() = 0;
        // BC can split the receipt across cost layers/tracking; reconcile sums, not an assumed entry count.
        Require(FromQuantity = FromRow.Quantity, 'FROM base quantity ' + Format(FromRow.Quantity), Format(FromQuantity));
        Require(ToQuantity = ToRow.Quantity, 'TO base quantity ' + Format(ToRow.Quantity), Format(ToQuantity));
        ValidateComponents(PostingID, FromRow, ToRow);
        ValidateLinks(PostingID);
        if not CompleteStaging then
            exit; // Preview may validate an existing posting, but must not complete staging.
        // No minimum G/L count: same-account, zero-value and deferred-cost postings are valid.
        ProcessedAt := CurrentDateTime();
        MarkProcessed(FromRow, PostingID, DocumentNo, PostingDate, ProcessedAt);
        MarkProcessed(ToRow, PostingID, DocumentNo, PostingDate, ProcessedAt);
    end;

    local procedure ValidateComponentDocument(ItemEntry: Record "Item Ledger Entry")
    var
        Component: Record "Impress Journal Component";
    begin
        Component.SetRange("Integration Posting ID", ItemEntry."Integration Posting ID");
        Component.SetRange("Document No.", ItemEntry."Document No.");
        Component.SetRange("Posting Date", ItemEntry."Posting Date");
        Component.SetRange("Entry Type", ItemEntry."Entry Type");
        Require(Component.Count() = 1, 'one reserved component for posted entry', Format(ItemEntry."Entry No."));
    end;

    local procedure ValidateComponents(PostingID: Guid; FromRow: Record "Impress Inv Trans Staging"; ToRow: Record "Impress Inv Trans Staging")
    var
        Component: Record "Impress Journal Component";
        Entry: Record "Item Ledger Entry";
        Preparation: Codeunit "Impress TG Preparation";
        Expected: Decimal;
        TransferQty: Decimal;
        ShortageQty: Decimal;
    begin
        Component.SetRange("Integration Posting ID", PostingID);
        if Component.FindSet() then
            repeat
                Require(Component."Requested Quantity" = Abs(FromRow.Quantity), 'reserved requested quantity', Format(Component."Requested Quantity"));
                Require(Component.Quantity > 0, 'positive reserved journal quantity', Format(Component.Quantity));
                if FromRow."Transaction Type" = 'T' then begin
                    Preparation.CalculateSplit(Component."Requested Quantity", Component."Available Quantity", TransferQty, ShortageQty);
                    Require((Component."Transfer Quantity" = TransferQty) and (Component."Shortage Quantity" = ShortageQty),
                        'consistent reserved availability split', Format(Component."Component No."));
                    if Component."Entry Type" = Component."Entry Type"::Transfer then
                        Require(Component.Quantity = TransferQty, 'reserved transfer quantity', Format(Component.Quantity))
                    else begin
                        Require(Component."Entry Type" in [Component."Entry Type"::"Negative Adjmt.", Component."Entry Type"::"Positive Adjmt."],
                            'reserved adjustment entry type', Format(Component."Entry Type"));
                        Require(Component.Quantity = ShortageQty, 'reserved shortage quantity', Format(Component.Quantity));
                    end;
                end;
                Entry.SetRange("Integration Posting ID", PostingID);
                Entry.SetRange("Document No.", Component."Document No.");
                Entry.SetRange("Entry Type", Component."Entry Type");
                Entry.SetRange("Location Code", FromRow."BC Location Code");
                if Component."Entry Type" = Component."Entry Type"::"Positive Adjmt." then
                    Entry.SetRange("Location Code", ToRow."BC Location Code");
                Entry.CalcSums(Quantity);
                Expected := -Component.Quantity;
                if Component."Entry Type" = Component."Entry Type"::"Positive Adjmt." then
                    Expected := Component.Quantity;
                Require(Entry.Quantity = Expected, 'reserved component quantity ' + Format(Expected), Format(Entry.Quantity));
                if Component."Entry Type" = Component."Entry Type"::Transfer then begin
                    Entry.SetRange("Location Code", ToRow."BC Location Code");
                    Entry.CalcSums(Quantity);
                    Require(Entry.Quantity = Component.Quantity, 'reserved transfer receipt quantity', Format(Entry.Quantity));
                end;
            until Component.Next() = 0;
    end;

    procedure ReconcileAA(var Row: Record "Impress Inv Trans Staging"; PostingID: Guid; GeneralRequirements: Dictionary of [Integer, Code[20]]; InventoryRequirements: Dictionary of [Code[10], Code[20]]; PostingContext: Text)
    var
        Entry: Record "Item Ledger Entry";
        Value: Record "Value Entry";
        Tracking: Codeunit "Impress Posting Tracking";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        Total: Decimal;
        DocumentNo: Code[20];
        ExpectedType: Enum "Item Ledger Entry Type";
    begin
        Context := PostingContext;
        ExpectedType := ExpectedType::"Positive Adjmt.";
        if Row.Quantity < 0 then
            ExpectedType := ExpectedType::"Negative Adjmt.";
        Entry.SetRange("Integration Posting ID", PostingID);
        Require(Entry.FindSet(), 'posted A/A Item Ledger Entries', 'none');
        DocumentNo := Entry."Document No.";
        repeat
            Entry.TestField("Entry Type", ExpectedType);
            Entry.TestField("Item No.", Row."BC Item No.");
            Entry.TestField("Variant Code", Row."BC Variant Code");
            Entry.TestField("Location Code", Row."BC Location Code");
            Entry.TestField("Posting Date", Row."G/L Date");
            Entry.TestField("Document No.", DocumentNo);
            ValidateComponentDocument(Entry);
            ReconcileCategory(Entry, Row);
            Value.SetRange("Item Ledger Entry No.", Entry."Entry No.");
            Require(Value.FindFirst(), 'A/A Value Entry', 'none');
            Resolver.ValidateGeneralProfile(Value."Gen. Bus. Posting Group", Value."Gen. Prod. Posting Group", GeneralRequirements, false, Context);
            Resolver.ValidateInventoryProfile(Value."Inventory Posting Group", InventoryRequirements, false, Context);
            ReconcileValues(Entry, Value."Inventory Posting Group", Value."Gen. Bus. Posting Group", Value."Gen. Prod. Posting Group");
            Tracking.AddLink(PostingID, Database::"Item Ledger Entry", Entry."Entry No.", Entry.SystemId, Entry."Document No.", Entry."Posting Date");
            Total += Entry.Quantity;
        until Entry.Next() = 0;
        Require(Total = Row.Quantity, 'A/A signed base quantity ' + Format(Row.Quantity), Format(Total));
        ValidateComponents(PostingID, Row, Row);
        ValidateLinks(PostingID);
        MarkProcessed(Row, PostingID, DocumentNo, Row."G/L Date", CurrentDateTime());
        Row."BC Posted Document Type" := 'Item Journal';
        Row.Modify(true);
    end;

    local procedure ReconcileValues(ItemEntry: Record "Item Ledger Entry"; PostingGroup: Code[20]; GenBusCode: Code[20]; GenProdCode: Code[20])
    var
        ValueEntry: Record "Value Entry";
        Relation: Record "G/L - Item Ledger Relation";
        GLEntry: Record "G/L Entry";
        Tracking: Codeunit "Impress Posting Tracking";
    begin
        ValueEntry.SetCurrentKey("Item Ledger Entry No.");
        ValueEntry.SetRange("Item Ledger Entry No.", ItemEntry."Entry No.");
        Require(ValueEntry.FindSet(), StrSubstNo('Value Entries for Item Ledger Entry %1', ItemEntry."Entry No."), 'none');
        repeat
            Require(ValueEntry."Integration Posting ID" = ItemEntry."Integration Posting ID",
                Format(ItemEntry."Integration Posting ID"), StrSubstNo('Value Entry %1 GUID %2', ValueEntry."Entry No.", ValueEntry."Integration Posting ID"));
            Require(ValueEntry."Inventory Posting Group" = PostingGroup, PostingGroup,
                StrSubstNo('Value Entry %1 Inventory Posting Group %2', ValueEntry."Entry No.", ValueEntry."Inventory Posting Group"));
            Require((ValueEntry."Gen. Bus. Posting Group" = GenBusCode) and (ValueEntry."Gen. Prod. Posting Group" = GenProdCode),
                GenBusCode + '/' + GenProdCode, StrSubstNo('Value Entry %1 General profile %2/%3', ValueEntry."Entry No.", ValueEntry."Gen. Bus. Posting Group", ValueEntry."Gen. Prod. Posting Group"));
            Tracking.AddLink(ValueEntry."Integration Posting ID", Database::"Value Entry", ValueEntry."Entry No.", ValueEntry.SystemId, ValueEntry."Document No.", ValueEntry."Posting Date");
            Relation.SetRange("Value Entry No.", ValueEntry."Entry No.");
            if Relation.FindSet() then
                repeat
                    Require(GLEntry.Get(Relation."G/L Entry No."), 'related G/L Entry', Format(Relation."G/L Entry No."));
                    Tracking.AddLink(ValueEntry."Integration Posting ID", Database::"G/L Entry", GLEntry."Entry No.", GLEntry.SystemId, GLEntry."Document No.", GLEntry."Posting Date");
                until Relation.Next() = 0;
        until ValueEntry.Next() = 0;
    end;

    local procedure ReconcileCategory(ItemEntry: Record "Item Ledger Entry"; Row: Record "Impress Inv Trans Staging")
    var
        Defaults: Record "Impress Defaults";
        DimensionEntry: Record "Dimension Set Entry";
        Category: Codeunit "Impress Category Dimension";
        ExpectedValue: Code[20];
    begin
        Require(Defaults.Get(), 'Impress Defaults for CATEGORY reconciliation', 'missing');
        ExpectedValue := Category.GetDimensionValueCode(Row."Source Database", Row."Division Code");
        Require(DimensionEntry.Get(ItemEntry."Dimension Set ID", Defaults."Category Dimension Code"),
            'posted CATEGORY ' + ExpectedValue, StrSubstNo('missing on Item Ledger Entry %1', ItemEntry."Entry No."));
        Require(DimensionEntry."Dimension Value Code" = ExpectedValue, 'posted CATEGORY ' + ExpectedValue, DimensionEntry."Dimension Value Code");
    end;

    local procedure ValidateLinks(PostingID: Guid)
    var
        Link: Record "Impress Posting Link";
        ItemEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        ParentItemEntry: Record "Item Ledger Entry";
        GLEntry: Record "G/L Entry";
        Relation: Record "G/L - Item Ledger Relation";
        FoundRelation: Boolean;
    begin
        // Check every tagged Value Entry, including entries whose link may be missing.
        ValueEntry.SetCurrentKey("Integration Posting ID");
        ValueEntry.SetRange("Integration Posting ID", PostingID);
        if ValueEntry.FindSet() then
            repeat
                Require(ParentItemEntry.Get(ValueEntry."Item Ledger Entry No."), 'tagged Value Entry parent', Format(ValueEntry."Item Ledger Entry No."));
                Require(ParentItemEntry."Integration Posting ID" = PostingID, 'same GUID on tagged Value Entry parent', Format(ParentItemEntry."Integration Posting ID"));
            until ValueEntry.Next() = 0;
        ValueEntry.Reset();
        Link.SetRange("Integration Posting ID", PostingID);
        if Link.FindSet() then
            repeat
                case Link."Table ID" of
                    Database::"Item Ledger Entry":
                        begin
                            Require(ItemEntry.Get(Link."Entry No."), 'linked Item Ledger Entry', Format(Link."Entry No."));
                            Require((ItemEntry.SystemId = Link."Entry System ID") and (ItemEntry."Integration Posting ID" = PostingID),
                                'matching linked Item Ledger Entry identity', Format(Link."Entry No."));
                        end;
                    Database::"Value Entry":
                        begin
                            Require(ValueEntry.Get(Link."Entry No."), 'linked Value Entry', Format(Link."Entry No."));
                            Require((ValueEntry.SystemId = Link."Entry System ID") and (ValueEntry."Integration Posting ID" = PostingID),
                                'matching linked Value Entry identity', Format(Link."Entry No."));
                            Require(ParentItemEntry.Get(ValueEntry."Item Ledger Entry No."), 'Value Entry parent', Format(ValueEntry."Item Ledger Entry No."));
                            Require(ParentItemEntry."Integration Posting ID" = PostingID, 'same GUID on Value Entry parent', Format(ParentItemEntry."Integration Posting ID"));
                        end;
                    Database::"G/L Entry":
                        begin
                            Require(GLEntry.Get(Link."Entry No."), 'linked G/L Entry', Format(Link."Entry No."));
                            Require(GLEntry.SystemId = Link."Entry System ID", 'matching G/L Entry identity', Format(Link."Entry No."));
                            FoundRelation := false;
                            Relation.SetRange("G/L Entry No.", Link."Entry No.");
                            if Relation.FindSet() then
                                repeat
                                    if ValueEntry.Get(Relation."Value Entry No.") then
                                        FoundRelation := FoundRelation or (ValueEntry."Integration Posting ID" = PostingID);
                                until Relation.Next() = 0;
                            Require(FoundRelation, 'G/L relation to a Value Entry with this GUID', Format(Link."Entry No."));
                        end;
                    else
                        Require(false, 'supported inventory posting link table', Format(Link."Table ID"));
                end;
            until Link.Next() = 0;
    end;

    local procedure MarkProcessed(var Row: Record "Impress Inv Trans Staging"; PostingID: Guid; DocumentNo: Code[20]; PostingDate: Date; ProcessedAt: DateTime)
    begin
        Row."Integration Posting ID" := PostingID;
        Row."BC Posted Document Type" := 'Item Reclassification';
        Row."BC Posted Document No." := DocumentNo;
        Row."BC Posted Posting Date" := PostingDate;
        Row."BC Document No." := DocumentNo;
        Row."Processing Status" := Row."Processing Status"::Processed;
        Row."Processed Date/Time" := ProcessedAt;
        Row."Date Processed" := ProcessedAt;
        Clear(Row."Error Message");
        Row.Modify(true);
    end;

    local procedure Require(Condition: Boolean; Expected: Text; Actual: Text)
    begin
        if not Condition then
            Error('%1. Posting reconciliation: expected [%2]; actual [%3]. No new posting is allowed until this is resolved.', Context, Expected, Actual);
    end;

    var
        Context: Text;
}
