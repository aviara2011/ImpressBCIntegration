codeunit 80013 "Impress Purchase Order Mgt."
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    begin
        ProcessPendingPurchaseOrders();
    end;

    procedure ProcessPendingPurchaseOrders()
    var
        HeaderStaging: Record "Impress Purch Header Staging";
    begin
        HeaderStaging.SetFilter("Processing Status", '%1|%2', HeaderStaging."Processing Status"::Pending, HeaderStaging."Processing Status"::Error);
        HeaderStaging.SetFilter("Transport Status", '%1|%2', HeaderStaging."Transport Status"::Sent, HeaderStaging."Transport Status"::Processed);
        ProcessHeaders(HeaderStaging);
    end;

    procedure ProcessRun(SQLRunID: BigInteger)
    var
        HeaderStaging: Record "Impress Purch Header Staging";
    begin
        HeaderStaging.SetRange("SQL Run ID", SQLRunID);
        HeaderStaging.SetFilter("Processing Status", '%1|%2', HeaderStaging."Processing Status"::Pending, HeaderStaging."Processing Status"::Error);
        ProcessHeaders(HeaderStaging);
    end;

    procedure ProcessSelectedHeaders(var HeaderStaging: Record "Impress Purch Header Staging")
    begin
        ProcessHeaders(HeaderStaging);
    end;

    procedure ProcessHeader(var PurchaseHeaderStaging: Record "Impress Purch Header Staging")
    begin
        ProcessOneDocument(PurchaseHeaderStaging."Entry No.");
        PurchaseHeaderStaging.Get(PurchaseHeaderStaging."Entry No.");
    end;

    procedure ProcessLine(var PurchaseLineStaging: Record "Impress Purchase Line Staging")
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        SetLineProcessing(PurchaseLineStaging);
        FindHeaderForLine(PurchaseLineStaging, PurchaseHeader);
        ProcessLineCore(PurchaseLineStaging, PurchaseHeader);
        SetLineProcessed(PurchaseLineStaging, PurchaseHeader);
    end;

    procedure ProcessSelectedLines(var LineStaging: Record "Impress Purchase Line Staging")
    var
        HeaderStaging: Record "Impress Purch Header Staging";
        HeaderEntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        if LineStaging.FindSet() then
            repeat
                HeaderStaging.Reset();
                HeaderStaging.SetRange("Source Database", LineStaging."Source Database");
                HeaderStaging.SetRange("Source POrder ID", LineStaging."Source POrder ID");
                if not HeaderStaging.FindFirst() then
                    Error('Purchase Header staging record for Source Database %1 and Source POrder ID %2 was not found.', LineStaging."Source Database", LineStaging."Source POrder ID");
                if not HeaderEntryNos.Contains(HeaderStaging."Entry No.") then
                    HeaderEntryNos.Add(HeaderStaging."Entry No.");
            until LineStaging.Next() = 0;
        foreach EntryNo in HeaderEntryNos do
            ProcessOneDocument(EntryNo);
    end;

    procedure ResetLinesToPending(var LineStaging: Record "Impress Purchase Line Staging")
    begin
        if LineStaging.FindSet(true) then
            repeat
                LineStaging."Processing Status" := LineStaging."Processing Status"::Pending;
                Clear(LineStaging."Error Message");
                LineStaging.Modify(true);
            until LineStaging.Next() = 0;
    end;

    procedure RetryHeaderErrors(var HeaderStaging: Record "Impress Purch Header Staging")
    var
        SelectedHeader: Record "Impress Purch Header Staging";
        EntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        HeaderStaging.SetRange("Processing Status", HeaderStaging."Processing Status"::Error);
        if HeaderStaging.FindSet() then
            repeat
                EntryNos.Add(HeaderStaging."Entry No.");
            until HeaderStaging.Next() = 0;
        foreach EntryNo in EntryNos do
            if SelectedHeader.Get(EntryNo) then begin
                ResetDocumentToPending(SelectedHeader);
                ProcessOneDocument(EntryNo);
            end;
    end;

    procedure ResetDocumentToPending(var HeaderStaging: Record "Impress Purch Header Staging")
    var
        LineStaging: Record "Impress Purchase Line Staging";
    begin
        HeaderStaging."Processing Status" := HeaderStaging."Processing Status"::Pending;
        Clear(HeaderStaging."Error Message");
        HeaderStaging.Modify(true);
        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source POrder ID", HeaderStaging."Source POrder ID");
        LineStaging.SetRange("Processing Status", LineStaging."Processing Status"::Error);
        if LineStaging.FindSet(true) then
            repeat
                LineStaging."Processing Status" := LineStaging."Processing Status"::Pending;
                Clear(LineStaging."Error Message");
                LineStaging.Modify(true);
            until LineStaging.Next() = 0;
    end;

    local procedure ProcessHeaders(var HeaderFilter: Record "Impress Purch Header Staging")
    var
        EntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        if HeaderFilter.FindSet() then
            repeat
                EntryNos.Add(HeaderFilter."Entry No.");
            until HeaderFilter.Next() = 0;
        foreach EntryNo in EntryNos do
            ProcessOneDocument(EntryNo);
    end;

    local procedure ProcessOneDocument(EntryNo: Integer)
    var
        HeaderStaging: Record "Impress Purch Header Staging";
        IntegrationManagement: Codeunit "Impress Integration Management";
        ErrorText: Text;
    begin
        Commit();
        if TryProcessDocument(EntryNo) then begin
            if HeaderStaging.Get(EntryNo) then
                IntegrationManagement.UpdatePurchaseOrderControlTotals(HeaderStaging."SQL Run ID");
            Commit();
            exit;
        end;
        ErrorText := GetLastErrorText();
        ClearLastError();
        if ErrorText = '' then
            ErrorText := StrSubstNo('Unknown error processing purchase header staging entry %1.', EntryNo);
        if HeaderStaging.Get(EntryNo) then
            MarkDocumentError(HeaderStaging, ErrorText);
        if HeaderStaging.Get(EntryNo) then
            IntegrationManagement.UpdatePurchaseOrderControlTotals(HeaderStaging."SQL Run ID");
        Commit();
    end;

    [TryFunction]
    local procedure TryProcessDocument(EntryNo: Integer)
    var
        HeaderStaging: Record "Impress Purch Header Staging";
        PurchaseHeader: Record "Purchase Header";
        LineStaging: Record "Impress Purchase Line Staging";
    begin
        HeaderStaging.Get(EntryNo);
        HeaderStaging."Processing Status" := HeaderStaging."Processing Status"::Processing;
        Clear(HeaderStaging."Error Message");
        HeaderStaging.Modify(true);
        UpsertHeader(HeaderStaging, PurchaseHeader);

        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source POrder ID", HeaderStaging."Source POrder ID");
        LineStaging.SetFilter(Operation, '<>%1', LineStaging.Operation::Delete);
        LineStaging.SetFilter("Processing Status", '<>%1', LineStaging."Processing Status"::Processed);
        if LineStaging.FindSet(true) then
            repeat
                SetLineProcessing(LineStaging);
                ProcessLineCore(LineStaging, PurchaseHeader);
                SetLineProcessed(LineStaging, PurchaseHeader);
            until LineStaging.Next() = 0;

        LineStaging.Reset();
        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source POrder ID", HeaderStaging."Source POrder ID");
        LineStaging.SetRange(Operation, LineStaging.Operation::Delete);
        LineStaging.SetFilter("Processing Status", '<>%1', LineStaging."Processing Status"::Processed);
        if LineStaging.FindSet(true) then
            repeat
                SetLineProcessing(LineStaging);
                ProcessLineCore(LineStaging, PurchaseHeader);
                SetLineProcessed(LineStaging, PurchaseHeader);
            until LineStaging.Next() = 0;

        HeaderStaging."BC System ID" := PurchaseHeader.SystemId;
        HeaderStaging."BC Document No." := PurchaseHeader."No.";
        HeaderStaging."Processing Status" := HeaderStaging."Processing Status"::Processed;
        HeaderStaging."Processed Date Time" := CurrentDateTime();
        Clear(HeaderStaging."Error Message");
        HeaderStaging.Modify(true);
    end;

    local procedure UpsertHeader(var Staging: Record "Impress Purch Header Staging"; var PurchaseHeader: Record "Purchase Header")
    var
        Vendor: Record Vendor;
    begin
        if not FindPurchaseHeader(Staging, PurchaseHeader) then begin
            if Staging.Operation <> Staging.Operation::Insert then
                Error('Purchase Order for Source Database %1 and Source POrder ID %2 was not found.', Staging."Source Database", Staging."Source POrder ID");
            if not Vendor.Get(Staging."Vendor No.") then
                Error('Vendor %1 does not exist.', Staging."Vendor No.");
            PurchaseHeader.Init();
            PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Order;
            PurchaseHeader.Insert(true);
            // OnInsert allocates the number and standard subscribers can update the
            // header. Reload it before validating vendor fields to avoid using the
            // pre-trigger row version ("Sorry, we just updated this page").
            PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseHeader."No.");
            PurchaseHeader.Validate("Buy-from Vendor No.", Staging."Vendor No.");
        end else
            if (Staging."Vendor No." <> '') and (PurchaseHeader."Buy-from Vendor No." <> Staging."Vendor No.") then
                Error('Vendor cannot be changed on existing Purchase Order %1. Current vendor is %2; source vendor is %3.', PurchaseHeader."No.", PurchaseHeader."Buy-from Vendor No.", Staging."Vendor No.");

        MapHeader(PurchaseHeader, Staging);
        PurchaseHeader.Modify(true);
        Staging."BC System ID" := PurchaseHeader.SystemId;
        Staging."BC Document No." := PurchaseHeader."No.";
        Staging.Modify(true);
    end;

    local procedure FindPurchaseHeader(Staging: Record "Impress Purch Header Staging"; var PurchaseHeader: Record "Purchase Header"): Boolean
    begin
        if not IsNullGuid(Staging."BC System ID") then
            if PurchaseHeader.GetBySystemId(Staging."BC System ID") and (PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::Order) then
                exit(true);
        if Staging."BC Document No." <> '' then
            if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Staging."BC Document No.") then
                exit(true);
        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
        PurchaseHeader.SetRange("Impress Source Database", Staging."Source Database");
        PurchaseHeader.SetRange("Impress Source POrder ID", Staging."Source POrder ID");
        exit(PurchaseHeader.FindFirst());
    end;

    local procedure MapHeader(var PurchaseHeader: Record "Purchase Header"; Staging: Record "Impress Purch Header Staging")
    begin
        PurchaseHeader."Impress Source Database" := Staging."Source Database";
        PurchaseHeader."Impress Source POrder ID" := Staging."Source POrder ID";
        PurchaseHeader."Impress Purchase Order No." := Staging."Purchase Order No.";
        if Staging."Purchase Order No." <> '' then
            PurchaseHeader.Validate("Vendor Order No.", CopyStr(Staging."Purchase Order No.", 1, MaxStrLen(PurchaseHeader."Vendor Order No.")));
        if Staging."Order Date" <> 0D then
            PurchaseHeader.Validate("Order Date", Staging."Order Date");
        if Staging."Last Expected Receipt Date" <> 0D then
            PurchaseHeader.Validate("Expected Receipt Date", Staging."Last Expected Receipt Date")
        else
            if Staging."First Expected Receipt Date" <> 0D then
                PurchaseHeader.Validate("Expected Receipt Date", Staging."First Expected Receipt Date");
        if Staging."Payment Terms Code" <> '' then
            PurchaseHeader.Validate("Payment Terms Code", Staging."Payment Terms Code");
        PurchaseHeader.Validate("Currency Code", Staging."Currency Code");
        if Staging."BC Location Code" <> '' then
            PurchaseHeader.Validate("Location Code", Staging."BC Location Code");
        if Staging."Ship Via Code" <> '' then
            PurchaseHeader.Validate("Shipment Method Code", CopyStr(Staging."Ship Via Code", 1, MaxStrLen(PurchaseHeader."Shipment Method Code")));
        PurchaseHeader.Validate("Ship-to Name", CopyStr(Staging."Ship-to Name", 1, MaxStrLen(PurchaseHeader."Ship-to Name")));
        PurchaseHeader.Validate("Ship-to Address", CopyStr(Staging."Ship-to Address", 1, MaxStrLen(PurchaseHeader."Ship-to Address")));
        PurchaseHeader.Validate("Ship-to Address 2", CopyStr(Staging."Ship-to Address 2", 1, MaxStrLen(PurchaseHeader."Ship-to Address 2")));
        PurchaseHeader.Validate("Ship-to City", CopyStr(Staging."Ship-to City", 1, MaxStrLen(PurchaseHeader."Ship-to City")));
        PurchaseHeader.Validate("Ship-to County", CopyStr(Staging."Ship-to State", 1, MaxStrLen(PurchaseHeader."Ship-to County")));
        PurchaseHeader.Validate("Ship-to Post Code", Staging."Ship-to Post Code");
        PurchaseHeader.Validate("Ship-to Country/Region Code", Staging."Ship-to Country Code");
        if Staging."On Hold" then
            PurchaseHeader."On Hold" := 'IMP'
        else
            Clear(PurchaseHeader."On Hold");
    end;

    local procedure ProcessLineCore(var Staging: Record "Impress Purchase Line Staging"; PurchaseHeader: Record "Purchase Header")
    var
        PurchaseLine: Record "Purchase Line";
    begin
        if Staging.Operation = Staging.Operation::Delete then begin
            if not FindPurchaseLine(Staging, PurchaseHeader."No.", PurchaseLine) then
                exit;
            if (PurchaseLine."Quantity Received" <> 0) or (PurchaseLine."Quantity Invoiced" <> 0) then
                Error('Cannot delete purchase line because quantity has already been received or invoiced. Source POrder Detail ID %1, Size Position %2.', Staging."Source POrder Detail ID", Staging."Size Position");
            PurchaseLine.Delete(true);
            exit;
        end;

        if not FindPurchaseLine(Staging, PurchaseHeader."No.", PurchaseLine) then begin
            if Staging.Operation <> Staging.Operation::Insert then
                Error('Purchase Line for Source POrder Detail ID %1 and Size Position %2 was not found.', Staging."Source POrder Detail ID", Staging."Size Position");
            InsertPurchaseLine(PurchaseLine, PurchaseHeader, Staging);
        end else
            UpdatePurchaseLine(PurchaseLine, Staging);
        Staging."BC Line System ID" := PurchaseLine.SystemId;
        Staging."BC Line No." := PurchaseLine."Line No.";
    end;

    local procedure InsertPurchaseLine(var PurchaseLine: Record "Purchase Line"; PurchaseHeader: Record "Purchase Header"; Staging: Record "Impress Purchase Line Staging")
    begin
        ValidateItemReferences(Staging);
        PurchaseLine.Init();
        PurchaseLine."Document Type" := PurchaseLine."Document Type"::Order;
        PurchaseLine."Document No." := PurchaseHeader."No.";
        PurchaseLine."Line No." := GetLineNo(PurchaseHeader."No.", Staging."BC Line No.");
        PurchaseLine.Insert(true);
        PurchaseLine.Validate(Type, PurchaseLine.Type::Item);
        PurchaseLine.Validate("No.", Staging."BC Item No.");
        if Staging."BC Variant Code" <> '' then
            PurchaseLine.Validate("Variant Code", Staging."BC Variant Code");
        ApplyMutableLineFields(PurchaseLine, Staging);
        SetLineIdentity(PurchaseLine, Staging);
        PurchaseLine.Modify(true);
    end;

    local procedure UpdatePurchaseLine(var PurchaseLine: Record "Purchase Line"; Staging: Record "Impress Purchase Line Staging")
    var
        HasActivity: Boolean;
        MinimumQuantity: Decimal;
    begin
        HasActivity := (PurchaseLine."Quantity Received" <> 0) or (PurchaseLine."Quantity Invoiced" <> 0);
        if Staging.Operation = Staging.Operation::Close then begin
            MinimumQuantity := PurchaseLine."Quantity Received";
            if PurchaseLine."Quantity Invoiced" > MinimumQuantity then
                MinimumQuantity := PurchaseLine."Quantity Invoiced";
            PurchaseLine.Validate(Quantity, MinimumQuantity);
        end else begin
            if Staging."Quantity Ordered" < PurchaseLine."Quantity Received" then
                Error('Cannot reduce quantity below quantity received. Source POrder Detail ID %1, Size Position %2.', Staging."Source POrder Detail ID", Staging."Size Position");
            if Staging."Quantity Ordered" < PurchaseLine."Quantity Invoiced" then
                Error('Cannot reduce quantity below quantity invoiced. Source POrder Detail ID %1, Size Position %2.', Staging."Source POrder Detail ID", Staging."Size Position");
            if HasActivity and ((PurchaseLine."No." <> Staging."BC Item No.") or (PurchaseLine."Variant Code" <> Staging."BC Variant Code")) then
                Error('Cannot change the item or variant after receipt activity exists. Source POrder Detail ID %1, Size Position %2.', Staging."Source POrder Detail ID", Staging."Size Position");
            if not HasActivity then begin
                ValidateItemReferences(Staging);
                if PurchaseLine."No." <> Staging."BC Item No." then
                    PurchaseLine.Validate("No.", Staging."BC Item No.");
                PurchaseLine.Validate("Variant Code", Staging."BC Variant Code");
            end;
            if PurchaseLine."Quantity Invoiced" <> 0 then
                if PurchaseLine."Direct Unit Cost" <> Staging."Direct Unit Cost" then
                    Error('Cannot change Direct Unit Cost after invoice activity exists. Source POrder Detail ID %1, Size Position %2.', Staging."Source POrder Detail ID", Staging."Size Position");
            ApplyMutableLineFields(PurchaseLine, Staging);
        end;
        SetLineIdentity(PurchaseLine, Staging);
        PurchaseLine.Modify(true);
    end;

    local procedure ApplyMutableLineFields(var PurchaseLine: Record "Purchase Line"; Staging: Record "Impress Purchase Line Staging")
    begin
        if Staging.Operation <> Staging.Operation::Close then
            PurchaseLine.Validate(Quantity, Staging."Quantity Ordered");
        if PurchaseLine."Quantity Invoiced" = 0 then
            PurchaseLine.Validate("Direct Unit Cost", Staging."Direct Unit Cost");
        if Staging."Unit of Measure Code" <> '' then
            PurchaseLine.Validate("Unit of Measure Code", Staging."Unit of Measure Code");
        if Staging."Expected Receipt Date" <> 0D then
            PurchaseLine.Validate("Expected Receipt Date", Staging."Expected Receipt Date");
        if Staging.Description <> '' then
            PurchaseLine.Description := CopyStr(Staging.Description, 1, MaxStrLen(PurchaseLine.Description));
    end;

    local procedure ValidateItemReferences(Staging: Record "Impress Purchase Line Staging")
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        if not Item.Get(Staging."BC Item No.") then
            Error('Item %1 does not exist.', Staging."BC Item No.");
        if (Staging."BC Variant Code" <> '') and not ItemVariant.Get(Staging."BC Item No.", Staging."BC Variant Code") then
            Error('Variant %1 does not exist for Item %2.', Staging."BC Variant Code", Staging."BC Item No.");
        if (Staging."Unit of Measure Code" <> '') and not ItemUnitOfMeasure.Get(Staging."BC Item No.", Staging."Unit of Measure Code") then
            Error('Unit of Measure %1 does not exist for Item %2.', Staging."Unit of Measure Code", Staging."BC Item No.");
    end;

    local procedure FindPurchaseLine(Staging: Record "Impress Purchase Line Staging"; DocumentNo: Code[20]; var PurchaseLine: Record "Purchase Line"): Boolean
    begin
        if not IsNullGuid(Staging."BC Line System ID") then
            if PurchaseLine.GetBySystemId(Staging."BC Line System ID") then
                exit(true);
        PurchaseLine.Reset();
        PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
        PurchaseLine.SetRange("Document No.", DocumentNo);
        PurchaseLine.SetRange("Impress Source Database", Staging."Source Database");
        PurchaseLine.SetRange("Impress POrder Detail ID", Staging."Source POrder Detail ID");
        PurchaseLine.SetRange("Impress Size Position", Staging."Size Position");
        exit(PurchaseLine.FindFirst());
    end;

    local procedure FindHeaderForLine(Staging: Record "Impress Purchase Line Staging"; var PurchaseHeader: Record "Purchase Header")
    begin
        if not IsNullGuid(Staging."BC Header System ID") then
            if PurchaseHeader.GetBySystemId(Staging."BC Header System ID") then
                exit;
        if Staging."BC Document No." <> '' then
            if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Staging."BC Document No.") then
                exit;
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
        PurchaseHeader.SetRange("Impress Source Database", Staging."Source Database");
        PurchaseHeader.SetRange("Impress Source POrder ID", Staging."Source POrder ID");
        if not PurchaseHeader.FindFirst() then
            Error('Purchase Order for Source Database %1 and Source POrder ID %2 was not found.', Staging."Source Database", Staging."Source POrder ID");
    end;

    local procedure GetLineNo(DocumentNo: Code[20]; RequestedLineNo: Integer): Integer
    var
        PurchaseLine: Record "Purchase Line";
    begin
        if RequestedLineNo <> 0 then
            if not PurchaseLine.Get(PurchaseLine."Document Type"::Order, DocumentNo, RequestedLineNo) then
                exit(RequestedLineNo);
        PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
        PurchaseLine.SetRange("Document No.", DocumentNo);
        if PurchaseLine.FindLast() then
            exit(PurchaseLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure SetLineIdentity(var PurchaseLine: Record "Purchase Line"; Staging: Record "Impress Purchase Line Staging")
    begin
        PurchaseLine."Impress Source Database" := Staging."Source Database";
        PurchaseLine."Impress POrder Detail ID" := Staging."Source POrder Detail ID";
        PurchaseLine."Impress Size Position" := Staging."Size Position";
        PurchaseLine."Impress Source Line No." := Staging."Source Line No.";
        PurchaseLine."Impress Source SKU" := Staging."Source SKU";
    end;

    local procedure SetLineProcessing(var Staging: Record "Impress Purchase Line Staging")
    begin
        Staging."Processing Status" := Staging."Processing Status"::Processing;
        Clear(Staging."Error Message");
        Staging.Modify(true);
    end;

    local procedure SetLineProcessed(var Staging: Record "Impress Purchase Line Staging"; PurchaseHeader: Record "Purchase Header")
    begin
        Staging."BC Header System ID" := PurchaseHeader.SystemId;
        Staging."BC Document No." := PurchaseHeader."No.";
        Staging."Processing Status" := Staging."Processing Status"::Processed;
        Staging."Processed Date Time" := CurrentDateTime();
        Clear(Staging."Error Message");
        Staging.Modify(true);
    end;

    local procedure MarkDocumentError(var HeaderStaging: Record "Impress Purch Header Staging"; ErrorText: Text)
    var
        LineStaging: Record "Impress Purchase Line Staging";
    begin
        HeaderStaging."Processing Status" := HeaderStaging."Processing Status"::Error;
        HeaderStaging."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(HeaderStaging."Error Message"));
        HeaderStaging.Modify(true);
        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source POrder ID", HeaderStaging."Source POrder ID");
        LineStaging.SetFilter("Processing Status", '<>%1', LineStaging."Processing Status"::Processed);
        if LineStaging.FindSet(true) then
            repeat
                LineStaging."Processing Status" := LineStaging."Processing Status"::Error;
                LineStaging."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(LineStaging."Error Message"));
                LineStaging.Modify(true);
            until LineStaging.Next() = 0;
    end;
}
