codeunit 80037 "Impress RP Receipt Mgt."
{
    procedure ProcessTransaction(var Transaction: Record "Impress Inv Trans Staging")
    var
        Runner: Codeunit "Impress RP Posting Runner";
        Failure: Text;
    begin
        // Same Boolean runner boundary as I/I: posting rolls back before Error is saved.
        Commit();
        ClearLastError();
        if not Runner.Run(Transaction) then begin
            Failure := StrSubstNo('%1: %2', Context(Transaction), GetLastErrorText());
            Transaction.Get(Transaction."Entry No.");
            Transaction."Processing Status" := Transaction."Processing Status"::Error;
            Transaction."Error Message" := CopyStr(Failure, 1, MaxStrLen(Transaction."Error Message"));
            Transaction.Modify(true);
            Commit();
            Error('%1', Failure);
        end;
        Transaction.Get(Transaction."Entry No.");
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure PostAtomic(var Transaction: Record "Impress Inv Trans Staging")
    var
        StagedLine: Record "Impress Purchase Line Staging";
        StagedHeader: Record "Impress Purch Header Staging";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Posted: Record "Purch. Rcpt. Header";
        Owner: Record "Impress Inv Trans Staging";
        Tracking: Codeunit "Impress Posting Tracking";
        Scope: Codeunit "Impress RP Posting Scope";
        PurchPost: Codeunit "Purch.-Post";
    begin
        Transaction.TestField("Transaction Type", 'R');
        Transaction.TestField("Transaction Source", 'P');
        Transaction.TestField("Transaction Handler", 'PURCHASE RECEIPT');
        Transaction.TestField("G/L Date");
        if Transaction.Quantity <= 0 then
            Error('%1: receipt quantity must be positive.', Context(Transaction));
        if not IsNullGuid(Transaction."Integration Posting ID") then
            Transaction.TestField("Integration Posting ID", Transaction.SystemId);
        Owner.SetRange("Integration Posting ID", Transaction.SystemId);
        Owner.SetFilter("Entry No.", '<>%1', Transaction."Entry No.");
        if not Owner.IsEmpty() then
            Error('R/P Integration Posting ID is owned by another transaction.');
        Posted.SetRange("Integration Posting ID", Transaction.SystemId);
        if not Posted.IsEmpty() then begin
            Reconcile(Transaction);
            exit;
        end;
        // Source identity also detects a deleted/recreated staging row with a new SystemId.
        Posted.Reset();
        Posted.SetRange("Impress Source Database", Transaction."Source Database");
        Posted.SetRange("Impress Source Transaction ID", Transaction."Source Transaction ID");
        if not Posted.IsEmpty() then
            Error('R/P source transaction already has a receipt with a different integration identity. Reconcile before retrying.');
        if Tracking.HasPostedEvidence(Transaction.SystemId) or
           (Transaction."Processing Status" = Transaction."Processing Status"::Processed) or
           (Transaction."BC Posted Document No." <> '') or not IsNullGuid(Transaction."BC System ID") then
            Error('R/P has incomplete posted evidence. Reconcile before retrying; no receipt was posted.');
        if not (Transaction."Transport Status" in [Transaction."Transport Status"::Sent, Transaction."Transport Status"::Processed]) then
            Error('R/P transport must be Sent or Processed.');
        Resolve(Transaction, StagedHeader, StagedLine, Header, Line);
        Header.SetHideValidationDialog(true);
        Header.Validate("Posting Date", Transaction."G/L Date");
        Header.Modify(true);
        PreparePostingLine(Transaction, Header, Line);
        Transaction."BC Location Code" := ReceiptLocation(Transaction);
        PrepareQuantities(Transaction, Header, Line);
        Transaction."Integration Posting ID" := Transaction.SystemId;
        Transaction."Processing Status" := Transaction."Processing Status"::Processing;
        Transaction."Date Processing Started" := CurrentDateTime();
        Transaction.Modify(true);
        Scope.Initialize(Transaction, Line);
        BindSubscription(Scope);
        Header.Receive := true;
        Header.Invoice := false;
        PurchPost.SetSuppressCommit(true);
        PurchPost.Run(Header);
        UnbindSubscription(Scope);
        Reconcile(Transaction);
    end;

    procedure Resolve(Transaction: Record "Impress Inv Trans Staging"; var StagedHeader: Record "Impress Purch Header Staging"; var StagedLine: Record "Impress Purchase Line Staging"; var Header: Record "Purchase Header"; var Line: Record "Purchase Line")
    begin
        StagedLine.Reset();
        StagedLine.SetRange("Source Database", Transaction."Source Database");
        StagedLine.SetRange("Purchase Order No.", Transaction."Source Order No.");
        StagedLine.SetRange("Source Line No.", Transaction."Source Order Line No.");
        StagedLine.SetRange("Source SKU", Transaction."Source SKU No.");
        StagedLine.SetRange("Source Size", Transaction."Source Size");
        if StagedLine.Count() <> 1 then
            Error('%1: expected exactly one size-expanded PO staging line; found %2.', Context(Transaction), StagedLine.Count());
        StagedLine.FindFirst();
        StagedHeader.Reset();
        StagedHeader.SetRange("Source Database", StagedLine."Source Database");
        StagedHeader.SetRange("Source POrder ID", StagedLine."Source POrder ID");
        if StagedHeader.Count() <> 1 then
            Error('%1: expected exactly one PO staging header.', Context(Transaction));
        StagedHeader.FindFirst();
        StagedHeader.TestField("Purchase Order No.", StagedLine."Purchase Order No.");
        Header.LockTable();
        if not IsNullGuid(StagedLine."BC Header System ID") then begin
            if not Header.GetBySystemId(StagedLine."BC Header System ID") then
                Error('%1: stale BC Header System ID; Purchase Order not found.', Context(Transaction));
        end else
            if not IsNullGuid(StagedHeader."BC System ID") then begin
                if not Header.GetBySystemId(StagedHeader."BC System ID") then
                    Error('%1: stale BC System ID; Purchase Order not found.', Context(Transaction));
            end else begin
                if StagedLine."BC Document No." <> '' then begin
                    if not Header.Get(Header."Document Type"::Order, StagedLine."BC Document No.") then
                        Error('%1: existing BC Purchase Order not found.', Context(Transaction));
                end else begin
                    StagedHeader.TestField("BC Document No.");
                    if not Header.Get(Header."Document Type"::Order, StagedHeader."BC Document No.") then
                        Error('%1: existing BC Purchase Order not found.', Context(Transaction));
                end;
            end;
        Header.TestField("Document Type", Header."Document Type"::Order);
        if not IsNullGuid(StagedHeader."BC System ID") then
            Header.TestField(SystemId, StagedHeader."BC System ID");
        if StagedHeader."BC Document No." <> '' then
            Header.TestField("No.", StagedHeader."BC Document No.");
        if StagedLine."BC Document No." <> '' then
            Header.TestField("No.", StagedLine."BC Document No.");
        Header.TestField("Impress Source Database", StagedLine."Source Database");
        Header.TestField("Impress Source POrder ID", StagedLine."Source POrder ID");
        Header.TestField("Impress Purchase Order No.", StagedLine."Purchase Order No.");
        Line.LockTable();
        if not IsNullGuid(StagedLine."BC Line System ID") then begin
            if not Line.GetBySystemId(StagedLine."BC Line System ID") then
                Error('%1: stale BC Line System ID; Purchase Line not found.', Context(Transaction));
        end else begin
            StagedLine.TestField("BC Document No.", Header."No.");
            StagedLine.TestField("BC Line No.");
            if not Line.Get(Header."Document Type", Header."No.", StagedLine."BC Line No.") then
                Error('%1: persisted BC Purchase Line not found.', Context(Transaction));
        end;
        Line.TestField("Document Type", Header."Document Type");
        Line.TestField("Document No.", Header."No.");
        if StagedLine."BC Line No." <> 0 then
            Line.TestField("Line No.", StagedLine."BC Line No.");
        Line.TestField(Type, Line.Type::Item);
        StagedLine.TestField("BC Item No.");
        Line.TestField("No.", StagedLine."BC Item No.");
        Line.TestField("Variant Code", StagedLine."BC Variant Code");
        Line.TestField("Impress Source Database", StagedLine."Source Database");
        Line.TestField("Impress POrder Detail ID", StagedLine."Source POrder Detail ID");
        Line.TestField("Impress Size Position", StagedLine."Size Position");
        Line.TestField("Impress Source Line No.", StagedLine."Source Line No.");
        Line.TestField("Impress Source SKU", StagedLine."Source SKU");
        Transaction.TestField("BC Item No.", Line."No.");
        Transaction.TestField("BC Variant Code", Line."Variant Code");
        if StagedLine."Unit of Measure Code" <> '' then
            Line.TestField("Unit of Measure Code", StagedLine."Unit of Measure Code");
        Line.TestField("Drop Shipment", false);
        Line.TestField("Job No.", '');
    end;

    procedure ReceiptLocation(Transaction: Record "Impress Inv Trans Staging"): Code[10]
    var
        LocationCode: Code[10];
    begin
        Transaction.TestField("Source Warehouse Code");
        if StrLen(Transaction."Source Warehouse Code") > MaxStrLen(LocationCode) then
            Error('%1: warehouse %2 exceeds the BC Location Code length.', Context(Transaction), Transaction."Source Warehouse Code");
        LocationCode := Transaction."Source Warehouse Code";
        if LocationCode = '' then
            Error('%1: receipt warehouse must not be blank.', Context(Transaction));
        exit(LocationCode);
    end;

    procedure BuildPostingRequirements(Transaction: Record "Impress Inv Trans Staging"; var GeneralRequirements: Dictionary of [Integer, Code[20]]; var InventoryRequirements: Dictionary of [Code[10], Code[20]]; var InterimRequirements: Dictionary of [Code[10], Code[20]])
    var
        Setup: Record "General Posting Setup";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        InventoryAccount: Code[20];
        LocationCode: Code[10];
    begin
        Clear(GeneralRequirements);
        Clear(InventoryRequirements);
        Clear(InterimRequirements);
        LocationCode := ReceiptLocation(Transaction);
        InventoryAccount := Resolver.ValidateAccount(Transaction."Source Inventory G/L Account", 'Source Inventory G/L Account', Context(Transaction));
        InventoryRequirements.Add(LocationCode, InventoryAccount);
        InterimRequirements.Add(LocationCode, InventoryAccount);
        GeneralRequirements.Add(Setup.FieldNo("Invt. Accrual Acc. (Interim)"),
            Resolver.ValidateAccount(Transaction."Source Offset G/L Account", 'Source Offset G/L Account / Invt. Accrual Acc. (Interim)', Context(Transaction)));
        // Confirmed source mapping: ADJ is Direct Cost Applied for R/P.
        // BC validates this actual-cost account even on its expected-cost receipt path.
        GeneralRequirements.Add(Setup.FieldNo("Direct Cost Applied Account"),
            Resolver.ValidateAccount(Transaction."Source Adjustment G/L Account", 'Source Adjustment G/L Account / Direct Cost Applied Account', Context(Transaction)));
    end;

    procedure PreparePostingLine(Transaction: Record "Impress Inv Trans Staging"; var Header: Record "Purchase Header"; var Line: Record "Purchase Line")
    var
        Defaults: Record "Impress Defaults";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        ReleasePurchase: Codeunit "Release Purchase Document";
        GeneralRequirements: Dictionary of [Integer, Code[20]];
        InventoryRequirements: Dictionary of [Code[10], Code[20]];
        InterimRequirements: Dictionary of [Code[10], Code[20]];
        GenProdCode: Code[20];
        InventoryCode: Code[20];
    begin
        Defaults.Get();
        BuildPostingRequirements(Transaction, GeneralRequirements, InventoryRequirements, InterimRequirements);
        GenProdCode := Resolver.ResolveGeneralPostingSetup(Defaults."Gen. Bus. Posting Group (Inv.)", GeneralRequirements, Context(Transaction));
        InventoryCode := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, InterimRequirements, Context(Transaction));
        if Header.Status = Header.Status::Released then
            ReleasePurchase.PerformManualReopen(Header);
        Header.TestField(Status, Header.Status::Open);
        Line.Get(Header."Document Type", Header."No.", Line."Line No.");
        // Set IMI before Location validation checks Inventory Posting Setup.
        Line.Validate("Posting Group", InventoryCode);
        Line.Validate("Gen. Bus. Posting Group", Defaults."Gen. Bus. Posting Group (Inv.)");
        Line.Validate("Gen. Prod. Posting Group", GenProdCode);
        Line.Modify(true);
        ApplyReceiptLocation(Transaction, Header, Line);
        ApplyReceiptCategory(Transaction, Line);
        ApplyOtherItemLinePostingGroups(Header, Line);
        CheckOtherLineSetups(Header, Line."Line No.");
        // Standard over-receipt validation requires a released order. Release
        // through BC so approval/prepayment/warehouse restrictions remain active.
        ReleasePurchase.PerformManualRelease(Header);
        Line.Get(Header."Document Type", Header."No.", Line."Line No.");
        Line.TestField("Gen. Bus. Posting Group", Defaults."Gen. Bus. Posting Group (Inv.)");
        Line.TestField("Gen. Prod. Posting Group", GenProdCode);
        Line.TestField("Posting Group", InventoryCode);
        Line.TestField("Location Code", ReceiptLocation(Transaction));
        CheckReceiptCategory(Transaction, Line."Dimension Set ID");
    end;

    procedure ApplyReceiptCategory(Transaction: Record "Impress Inv Trans Staging"; var Line: Record "Purchase Line")
    var
        Defaults: Record "Impress Defaults";
        Category: Codeunit "Impress Category Dimension";
        DimensionSetID: Integer;
    begin
        Defaults.Get();
        Defaults.TestField("Category Dimension Code");
        DimensionSetID := Line."Dimension Set ID";
        Category.ApplyToDimensionSet(DimensionSetID, Defaults."Category Dimension Code",
            Category.GetDimensionValueCode(Transaction."Source Database", Transaction."Division Code"));
        Line.Validate("Dimension Set ID", DimensionSetID);
        Line.Modify(true);
    end;

    local procedure CheckReceiptCategory(Transaction: Record "Impress Inv Trans Staging"; DimensionSetID: Integer)
    var
        Defaults: Record "Impress Defaults";
        Entry: Record "Dimension Set Entry";
        Category: Codeunit "Impress Category Dimension";
    begin
        Defaults.Get();
        Defaults.TestField("Category Dimension Code");
        Entry.Get(DimensionSetID, Defaults."Category Dimension Code");
        Entry.TestField("Dimension Value Code",
            Category.GetDimensionValueCode(Transaction."Source Database", Transaction."Division Code"));
    end;

    procedure ApplyOtherItemLinePostingGroups(Header: Record "Purchase Header"; ReceiptLine: Record "Purchase Line")
    var
        Line: Record "Purchase Line";
    begin
        Header.TestField(Status, Header.Status::Open);
        ReceiptLine.TestField("Document Type", Header."Document Type");
        ReceiptLine.TestField("Document No.", Header."No.");
        ReceiptLine.TestField("Location Code");
        // The user-authorized PO default is the current receipt's resolved profile.
        // Every later R/P resolves its own source accounts before copying again.
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        Line.SetRange(Type, Line.Type::Item);
        Line.SetFilter("Line No.", '<>%1', ReceiptLine."Line No.");
        if Line.FindSet(true) then
            repeat
                if (Line."Posting Group" <> ReceiptLine."Posting Group") or
                   (Line."Gen. Bus. Posting Group" <> ReceiptLine."Gen. Bus. Posting Group") or
                   (Line."Gen. Prod. Posting Group" <> ReceiptLine."Gen. Prod. Posting Group") or
                   (Line."Location Code" = '') then begin
                    Line.Validate("Posting Group", ReceiptLine."Posting Group");
                    Line.Validate("Gen. Bus. Posting Group", ReceiptLine."Gen. Bus. Posting Group");
                    Line.Validate("Gen. Prod. Posting Group", ReceiptLine."Gen. Prod. Posting Group");
                    // Standard release checks locations even on zero-receipt lines.
                    // Set the resolved IMI first so Location validation has its setup.
                    if Line."Location Code" = '' then begin
                        Line.Validate("Location Code", ReceiptLine."Location Code");
                        Line.TestField("Location Code", ReceiptLine."Location Code");
                    end;
                    Line.Modify(true);
                end;
            until Line.Next() = 0;
    end;

    procedure CheckOtherLineSetups(Header: Record "Purchase Header"; TargetLineNo: Integer)
    var
        Line: Record "Purchase Line";
        Setup: Record "General Posting Setup";
    begin
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        Line.SetFilter("Line No.", '<>%1', TargetLineNo);
        if Line.FindSet() then
            repeat
                if Line.HasTypeToFillMandatoryFields() then
                    if Setup.Get(Line."Gen. Bus. Posting Group", Line."Gen. Prod. Posting Group") then
                        if Setup.Blocked then
                            Error('R/P: unrelated PO %1 line %2 still references blocked General Posting Setup %3/%4. Standard BC validates this line even with zero receipt quantity. R/P copies receipt groups to item lines only; correct this remaining setup separately without unblocking shared defaults.',
                                Header."No.", Line."Line No.", Line."Gen. Bus. Posting Group", Line."Gen. Prod. Posting Group");
            until Line.Next() = 0;
    end;

    procedure ApplyReceiptLocation(Transaction: Record "Impress Inv Trans Staging"; var Header: Record "Purchase Header"; var Line: Record "Purchase Line")
    var
        ReleasePurchase: Codeunit "Release Purchase Document";
        LocationCode: Code[10];
        WasReleased: Boolean;
    begin
        LocationCode := ReceiptLocation(Transaction);
        if Line."Location Code" = LocationCode then
            exit;
        // Location validation requires Open. Use standard lifecycle functions;
        // never suspend status, approval, reservation or warehouse checks.
        WasReleased := Header.Status = Header.Status::Released;
        if WasReleased then
            ReleasePurchase.PerformManualReopen(Header);
        Line.Get(Header."Document Type", Header."No.", Line."Line No.");
        Line.Validate("Location Code", LocationCode);
        Line.TestField("Location Code", LocationCode);
        Line.Modify(true);
        if WasReleased then
            ReleasePurchase.PerformManualRelease(Header);
    end;

    procedure PrepareQuantities(Transaction: Record "Impress Inv Trans Staging"; Header: Record "Purchase Header"; var Target: Record "Purchase Line")
    var
        Line: Record "Purchase Line";
    begin
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet(true) then
            repeat
                if (Line."Line No." <> Target."Line No.") and (Line."Qty. to Receive" <> 0) then begin
                    Line.Validate("Qty. to Receive", 0);
                    Line.Modify(true);
                end;
            until Line.Next() = 0;
        Target.Get(Header."Document Type", Header."No.", Target."Line No.");
        // Standard Table 39 invokes OverReceiptProcessing and codeunit 8510.
        Target.Validate("Qty. to Receive", Transaction.Quantity);
        Target.TestField("Qty. to Receive", Transaction.Quantity);
        Target.Modify(true);
    end;

    procedure Reconcile(var Transaction: Record "Impress Inv Trans Staging")
    var
        Header: Record "Purch. Rcpt. Header";
        Line: Record "Purch. Rcpt. Line";
        ItemEntry: Record "Item Ledger Entry";
        TotalBase: Decimal;
    begin
        Header.SetRange("Integration Posting ID", Transaction.SystemId);
        if Header.Count() <> 1 then
            Error('R/P requires exactly one posted Purchase Receipt for Integration Posting ID %1.', Transaction.SystemId);
        Header.FindFirst();
        Header.TestField("Impress Source Database", Transaction."Source Database");
        Header.TestField("Impress Source Transaction ID", Transaction."Source Transaction ID");
        Header.TestField("Impress Source Order No.", Transaction."Source Order No.");
        Header.TestField("Impress Source Order Line No.", Transaction."Source Order Line No.");
        Header.TestField("Impress Source SKU", Transaction."Source SKU No.");
        Header.TestField("Impress Source Size", Transaction."Source Size");
        Header.TestField("Impress Source Warehouse", Transaction."Source Warehouse Code");
        Header.TestField("Posting Date", Transaction."G/L Date");
        Line.SetRange("Document No.", Header."No.");
        Line.SetFilter(Quantity, '<>0');
        if Line.Count() <> 1 then
            Error('R/P receipt %1 must contain exactly one nonzero receipt line.', Header."No.");
        Line.FindFirst();
        Line.TestField(Type, Line.Type::Item);
        Line.TestField("Order No.", Header."Order No.");
        Line.TestField("Order Line No.", Header."Impress Order Line No.");
        Line.TestField("No.", Transaction."BC Item No.");
        Line.TestField("Variant Code", Transaction."BC Variant Code");
        Line.TestField("Location Code", ReceiptLocation(Transaction));
        Line.TestField(Quantity, Transaction.Quantity);
        Line.TestField(Correction, false);
        if Header."Impress RP Account Version" <> 0 then begin
            Header.TestField("Impress RP Account Version", 1);
            ReconcilePostingProfiles(Transaction, Line);
        end;
        ItemEntry.SetRange("Integration Posting ID", Transaction.SystemId);
        if not ItemEntry.FindSet() then
            Error('R/P receipt %1 has no correlated item ledger evidence.', Header."No.");
        repeat
            ItemEntry.TestField("Document Type", ItemEntry."Document Type"::"Purchase Receipt");
            ItemEntry.TestField("Entry Type", ItemEntry."Entry Type"::Purchase);
            ItemEntry.TestField("Document No.", Header."No.");
            ItemEntry.TestField("Document Line No.", Line."Line No.");
            ItemEntry.TestField("Posting Date", Header."Posting Date");
            ItemEntry.TestField("Item No.", Line."No.");
            ItemEntry.TestField("Variant Code", Line."Variant Code");
            ItemEntry.TestField("Location Code", Line."Location Code");
            TotalBase += ItemEntry.Quantity;
        until ItemEntry.Next() = 0;
        if (TotalBase <= 0) or (TotalBase <> Line."Quantity (Base)") then
            Error('R/P receipt %1 item ledger quantity does not match the posted receipt.', Header."No.");
        ItemEntry.Reset();
        ItemEntry.SetRange("Document Type", ItemEntry."Document Type"::"Purchase Receipt");
        ItemEntry.SetRange("Document No.", Header."No.");
        if ItemEntry.FindSet() then
            repeat
                ItemEntry.TestField("Integration Posting ID", Transaction.SystemId);
            until ItemEntry.Next() = 0;
        Transaction."Integration Posting ID" := Transaction.SystemId;
        Transaction."BC Location Code" := Line."Location Code";
        Transaction."BC System ID" := Header.SystemId;
        Transaction."BC Document No." := Header."No.";
        Transaction."BC Posted Document Type" := 'Purchase Receipt';
        Transaction."BC Posted Document No." := Header."No.";
        Transaction."BC Posted Posting Date" := Header."Posting Date";
        Transaction."Processing Status" := Transaction."Processing Status"::Processed;
        Transaction."Error Message" := '';
        Transaction."Date Processed" := CurrentDateTime();
        Transaction."Processed Date/Time" := Transaction."Date Processed";
        Transaction.Modify(true);
    end;

    local procedure ReconcilePostingProfiles(Transaction: Record "Impress Inv Trans Staging"; ReceiptLine: Record "Purch. Rcpt. Line")
    var
        ValueEntry: Record "Value Entry";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        GeneralRequirements: Dictionary of [Integer, Code[20]];
        InventoryRequirements: Dictionary of [Code[10], Code[20]];
        InterimRequirements: Dictionary of [Code[10], Code[20]];
    begin
        BuildPostingRequirements(Transaction, GeneralRequirements, InventoryRequirements, InterimRequirements);
        // Historical posted business group is authoritative on retry, even if
        // the configured default has since changed. No setup is created here.
        Resolver.ValidateGeneralProfile(ReceiptLine."Gen. Bus. Posting Group", ReceiptLine."Gen. Prod. Posting Group", GeneralRequirements, true, Context(Transaction));
        Resolver.ValidateInventoryProfile(ReceiptLine."Posting Group", InventoryRequirements, InterimRequirements, true, Context(Transaction));
        ValueEntry.SetRange("Integration Posting ID", Transaction.SystemId);
        ValueEntry.SetRange("Document Type", ValueEntry."Document Type"::"Purchase Receipt");
        ValueEntry.SetRange("Document No.", ReceiptLine."Document No.");
        if not ValueEntry.FindSet() then
            Error('R/P receipt %1 is missing correlated value entries.', ReceiptLine."Document No.");
        repeat
            ValueEntry.TestField("Document Line No.", ReceiptLine."Line No.");
            ValueEntry.TestField("Item No.", ReceiptLine."No.");
            ValueEntry.TestField("Location Code", ReceiptLine."Location Code");
            ValueEntry.TestField("Inventory Posting Group", ReceiptLine."Posting Group");
            ValueEntry.TestField("Gen. Bus. Posting Group", ReceiptLine."Gen. Bus. Posting Group");
            ValueEntry.TestField("Gen. Prod. Posting Group", ReceiptLine."Gen. Prod. Posting Group");
        until ValueEntry.Next() = 0;
    end;

    local procedure Context(Transaction: Record "Impress Inv Trans Staging"): Text
    begin
        exit(StrSubstNo('R/P SourceDatabase=%1 SourceTransactionID=%2 PO=%3 SourceLine=%4 SKU=%5 Size=%6',
            Transaction."Source Database", Transaction."Source Transaction ID", Transaction."Source Order No.",
            Transaction."Source Order Line No.", Transaction."Source SKU No.", Transaction."Source Size"));
    end;
}
