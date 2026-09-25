codeunit 80016 "Impress Sales Order Mgt."
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    begin
        ProcessPendingSalesOrders();
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterDeleteEvent', '', false, false)]
    local procedure ReopenStagingAfterOrderDeletion(var Rec: Record "Sales Header"; RunTrigger: Boolean)
    var
        HeaderStaging: Record "Impress Sales Header Staging";
        LineStaging: Record "Impress Sales Line Staging";
        IntegrationManagement: Codeunit "Impress Integration Management";
    begin
        // Posting deletes orders without running the table trigger. Do not reopen those.
        if Rec.IsTemporary() or not RunTrigger then
            exit;
        if (Rec."Document Type" <> Rec."Document Type"::Order) or (Rec.Status <> Rec.Status::Open) then
            exit;
        if Rec."Impress Source Database" = '' then
            exit;
        HeaderStaging.SetRange("Source Database", Rec."Impress Source Database");
        HeaderStaging.SetRange("Source Sales Order ID", Rec."Impress Source Sales Order ID");
        if not HeaderStaging.FindFirst() then
            exit;
        // A source-requested deletion must remain a deletion, not become a new order.
        if HeaderStaging.Operation = HeaderStaging.Operation::Delete then
            exit;
        if HeaderStaging."Processing Status" = HeaderStaging."Processing Status"::Processing then
            exit; // Internal cleanup of a newly prepared order with no successful lines.
        if not IsNullGuid(HeaderStaging."BC System ID") then
            if HeaderStaging."BC System ID" <> Rec.SystemId then
                exit;

        HeaderStaging.Operation := HeaderStaging.Operation::Insert;
        HeaderStaging."Processing Status" := HeaderStaging."Processing Status"::Pending;
        Clear(HeaderStaging."BC System ID");
        Clear(HeaderStaging."BC Document No.");
        Clear(HeaderStaging."Processed Date Time");
        Clear(HeaderStaging."Error Message");
        HeaderStaging.Modify(true);

        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source Sales Order ID", HeaderStaging."Source Sales Order ID");
        if LineStaging.FindSet(true) then
            repeat
                if LineStaging.Operation <> LineStaging.Operation::Delete then
                    LineStaging.Operation := LineStaging.Operation::Insert;
                LineStaging."Processing Status" := LineStaging."Processing Status"::Pending;
                Clear(LineStaging."BC System ID");
                Clear(LineStaging."BC Document No.");
                Clear(LineStaging."BC Line System ID");
                // Retain reserved line positions when the order is recreated.
                Clear(LineStaging."Processed Date Time");
                Clear(LineStaging."Error Message");
                LineStaging.Modify(true);
            until LineStaging.Next() = 0;
        IntegrationManagement.UpdateSalesOrderControlTotals(HeaderStaging."SQL Run ID");
    end;

    procedure ProcessPendingSalesOrders()
    var
        HeaderStaging: Record "Impress Sales Header Staging";
    begin
        HeaderStaging.SetFilter("Processing Status", '%1|%2', HeaderStaging."Processing Status"::Pending, HeaderStaging."Processing Status"::Error);
        HeaderStaging.SetFilter("Transport Status", '%1|%2', HeaderStaging."Transport Status"::Sent, HeaderStaging."Transport Status"::Processed);
        ProcessHeaders(HeaderStaging);
    end;

    procedure ProcessRun(SQLRunID: BigInteger)
    var
        HeaderStaging: Record "Impress Sales Header Staging";
    begin
        HeaderStaging.SetRange("SQL Run ID", SQLRunID);
        HeaderStaging.SetRange("Transport Status", HeaderStaging."Transport Status"::Sent);
        HeaderStaging.SetFilter("Processing Status", '%1|%2', HeaderStaging."Processing Status"::Pending, HeaderStaging."Processing Status"::Error);
        ProcessHeaders(HeaderStaging);
    end;

    procedure ProcessHeader(var HeaderStaging: Record "Impress Sales Header Staging")
    begin
        ProcessOneDocument(HeaderStaging."Entry No.");
        HeaderStaging.Get(HeaderStaging."Entry No.");
    end;

    procedure ProcessSelectedHeaders(var HeaderStaging: Record "Impress Sales Header Staging")
    begin
        ProcessHeaders(HeaderStaging);
    end;

    procedure ProcessLine(var SalesLineStaging: Record "Impress Sales Line Staging")
    var
        SalesHeader: Record "Sales Header";
    begin
        SetLineProcessing(SalesLineStaging);
        FindHeaderForLine(SalesLineStaging, SalesHeader);
        ProcessLineCore(SalesLineStaging, SalesHeader);
        SetLineProcessed(SalesLineStaging, SalesHeader);
    end;

    procedure ProcessSelectedLines(var LineStaging: Record "Impress Sales Line Staging")
    var
        HeaderStaging: Record "Impress Sales Header Staging";
        HeaderEntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        if LineStaging.FindSet() then
            repeat
                HeaderStaging.Reset();
                HeaderStaging.SetRange("Source Database", LineStaging."Source Database");
                HeaderStaging.SetRange("Source Sales Order ID", LineStaging."Source Sales Order ID");
                if not HeaderStaging.FindFirst() then
                    Error('Sales Header staging record for Source Database %1 and Source Sales Order ID %2 was not found.', LineStaging."Source Database", LineStaging."Source Sales Order ID");
                if not HeaderEntryNos.Contains(HeaderStaging."Entry No.") then
                    HeaderEntryNos.Add(HeaderStaging."Entry No.");
            until LineStaging.Next() = 0;
        foreach EntryNo in HeaderEntryNos do
            ProcessOneDocument(EntryNo);
    end;

    procedure ResetLinesToPending(var LineStaging: Record "Impress Sales Line Staging")
    begin
        if LineStaging.FindSet(true) then
            repeat
                LineStaging."Processing Status" := LineStaging."Processing Status"::Pending;
                Clear(LineStaging."Error Message");
                LineStaging.Modify(true);
            until LineStaging.Next() = 0;
    end;

    procedure RetryHeaderErrors(var HeaderStaging: Record "Impress Sales Header Staging")
    var
        SelectedHeader: Record "Impress Sales Header Staging";
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

    procedure ResetDocumentToPending(var HeaderStaging: Record "Impress Sales Header Staging")
    var
        LineStaging: Record "Impress Sales Line Staging";
    begin
        HeaderStaging."Processing Status" := HeaderStaging."Processing Status"::Pending;
        Clear(HeaderStaging."Error Message");
        HeaderStaging.Modify(true);
        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source Sales Order ID", HeaderStaging."Source Sales Order ID");
        LineStaging.SetRange("Processing Status", LineStaging."Processing Status"::Error);
        if LineStaging.FindSet(true) then
            repeat
                LineStaging."Processing Status" := LineStaging."Processing Status"::Pending;
                Clear(LineStaging."Error Message");
                LineStaging.Modify(true);
            until LineStaging.Next() = 0;
    end;

    local procedure ProcessHeaders(var HeaderFilter: Record "Impress Sales Header Staging")
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
        HeaderStaging: Record "Impress Sales Header Staging";
        IntegrationManagement: Codeunit "Impress Integration Management";
        ErrorText: Text;
    begin
        Commit();
        if TryProcessDocument(EntryNo) then begin
            if HeaderStaging.Get(EntryNo) then
                IntegrationManagement.UpdateSalesOrderControlTotals(HeaderStaging."SQL Run ID");
            Commit();
            exit;
        end;
        ErrorText := GetLastErrorText();
        ClearLastError();
        if ErrorText = '' then
            ErrorText := StrSubstNo('Unknown error processing sales header staging entry %1.', EntryNo);
        if HeaderStaging.Get(EntryNo) then begin
            MarkDocumentError(HeaderStaging, ErrorText);
            IntegrationManagement.UpdateSalesOrderControlTotals(HeaderStaging."SQL Run ID");
        end;
        Commit();
    end;

    [TryFunction]
    local procedure TryProcessDocument(EntryNo: Integer)
    var
        HeaderStaging: Record "Impress Sales Header Staging";
        SalesHeader: Record "Sales Header";
        LineStaging: Record "Impress Sales Line Staging";
        HeaderRunner: Codeunit "Impress Sales Header Runner";
        NewOrder: Boolean;
        RemovedEmptyOrder: Boolean;
        HeaderError: Text;
    begin
        HeaderStaging.Get(EntryNo);
        NewOrder := not FindSalesHeader(HeaderStaging, SalesHeader);
        Commit();
        ClearLastError();
        if not HeaderRunner.Run(HeaderStaging) then begin
            HeaderError := GetLastErrorText();
            Error('%1', HeaderError);
        end;
        HeaderStaging.Get(EntryNo);
        if HeaderStaging.Operation = HeaderStaging.Operation::Delete then
            exit;
        SalesHeader.GetBySystemId(HeaderStaging."BC System ID");
        ProcessDocumentLines(HeaderStaging, false);
        ProcessDocumentLines(HeaderStaging, true);
        HeaderStaging.Get(EntryNo);
        if NewOrder then
            RemovedEmptyOrder := RemoveNewEmptyOrder(HeaderStaging, SalesHeader);
        // Report the first unresolved error in sales-line order, never the last failure.
        LineStaging.SetCurrentKey("Source Database", "Source Sales Order ID", "BC Line No.");
        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source Sales Order ID", HeaderStaging."Source Sales Order ID");
        LineStaging.SetRange("Processing Status", LineStaging."Processing Status"::Error);
        if LineStaging.FindFirst() then begin
            HeaderStaging."Processing Status" := HeaderStaging."Processing Status"::Error;
            HeaderStaging."Error Message" := CopyStr(StrSubstNo('Line %1: %2', LineStaging."BC Line No.", LineStaging."Error Message"), 1, MaxStrLen(HeaderStaging."Error Message"));
            HeaderStaging.Modify(true);
            exit;
        end;
        if RemovedEmptyOrder then begin
            HeaderStaging."Processing Status" := HeaderStaging."Processing Status"::Error;
            HeaderStaging."Error Message" := 'No sales lines were created. The new empty sales order was removed; correct the staging lines and retry.';
            HeaderStaging.Modify(true);
            exit;
        end;
        if HeaderStaging.Operation = HeaderStaging.Operation::Close then
            CloseSalesOrderLines(SalesHeader);
        HeaderStaging."BC System ID" := SalesHeader.SystemId;
        HeaderStaging."BC Document No." := SalesHeader."No.";
        SetHeaderProcessed(HeaderStaging);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure PrepareSalesHeader(var HeaderStaging: Record "Impress Sales Header Staging")
    var
        SalesHeader: Record "Sales Header";
        LineStaging: Record "Impress Sales Line Staging";
    begin
        HeaderStaging.Get(HeaderStaging."Entry No.");
        HeaderStaging."Processing Status" := HeaderStaging."Processing Status"::Processing;
        Clear(HeaderStaging."Error Message");
        Clear(HeaderStaging."Processed Date Time");
        HeaderStaging.Modify(true);
        if HeaderStaging.Operation = HeaderStaging.Operation::Delete then begin
            DeleteSalesOrder(HeaderStaging);
            SetHeaderProcessed(HeaderStaging);
            exit;
        end;
        if not FindSalesHeader(HeaderStaging, SalesHeader) then begin
            LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
            LineStaging.SetRange("Source Sales Order ID", HeaderStaging."Source Sales Order ID");
            LineStaging.SetFilter(Operation, '<>%1', LineStaging.Operation::Delete);
            if LineStaging.IsEmpty() then
                Error('Cannot create sales order %1: no active staging lines exist for source %2, staging header entry %3.', HeaderStaging."Sales Order No.", HeaderStaging."Source Database", HeaderStaging."Entry No.");
            if LineStaging.FindSet(true) then
                repeat
                    Clear(LineStaging."BC System ID");
                    Clear(LineStaging."BC Document No.");
                    Clear(LineStaging."BC Line System ID");
                    if LineStaging."Processing Status" = LineStaging."Processing Status"::Processed then
                        LineStaging."Processing Status" := LineStaging."Processing Status"::Pending;
                    LineStaging.Modify(true);
                until LineStaging.Next() = 0;
        end;
        UpsertHeader(HeaderStaging, SalesHeader);
        ReserveDocumentLineNumbers(HeaderStaging, SalesHeader);
    end;

    local procedure RemoveNewEmptyOrder(var HeaderStaging: Record "Impress Sales Header Staging"; var SalesHeader: Record "Sales Header"): Boolean
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if not SalesLine.IsEmpty() then
            exit(false);
        SalesHeader.Delete(true);
        Clear(HeaderStaging."BC System ID");
        Clear(HeaderStaging."BC Document No.");
        HeaderStaging.Modify(true);
        exit(true);
    end;

    local procedure ProcessDocumentLines(HeaderStaging: Record "Impress Sales Header Staging"; Deletes: Boolean)
    var
        LineStaging: Record "Impress Sales Line Staging";
        Runner: Codeunit "Impress Sales Line Runner";
        EntryNos: List of [Integer];
        EntryNo: Integer;
        ErrorText: Text;
    begin
        LineStaging.SetCurrentKey("Source Database", "Source Sales Order ID", "BC Line No.");
        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source Sales Order ID", HeaderStaging."Source Sales Order ID");
        LineStaging.SetFilter("Processing Status", '<>%1', LineStaging."Processing Status"::Processed);
        if Deletes then
            LineStaging.SetRange(Operation, LineStaging.Operation::Delete)
        else
            LineStaging.SetFilter(Operation, '<>%1', LineStaging.Operation::Delete);
        if LineStaging.FindSet() then
            repeat
                EntryNos.Add(LineStaging."Entry No.");
            until LineStaging.Next() = 0;
        LineStaging.Reset();
        foreach EntryNo in EntryNos do begin
            // Persist header and reserved positions before the isolated line transaction.
            Commit();
            LineStaging.Get(EntryNo);
            Clear(Runner);
            ClearLastError();
            if not Runner.Run(LineStaging) then begin
                ErrorText := GetLastErrorText();
                ClearLastError();
                LineStaging.Get(EntryNo);
                LineStaging."Processing Status" := LineStaging."Processing Status"::Error;
                LineStaging."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(LineStaging."Error Message"));
                Clear(LineStaging."Processed Date Time");
                LineStaging.Modify(true);
            end;
        end;
        Commit();
    end;

    local procedure ReserveDocumentLineNumbers(HeaderStaging: Record "Impress Sales Header Staging"; SalesHeader: Record "Sales Header")
    var
        Staging: Record "Impress Sales Line Staging";
        SalesLine: Record "Sales Line";
        Missing: List of [Integer];
        PreviousNo: Integer;
    begin
        Staging.SetCurrentKey("Source Database", "Source Sales Order ID", "Source Line No.", "Source Sequence", "Size Position", "Entry No.");
        Staging.SetRange("Source Database", HeaderStaging."Source Database");
        Staging.SetRange("Source Sales Order ID", HeaderStaging."Source Sales Order ID");
        Staging.SetFilter(Operation, '<>%1', Staging.Operation::Delete);
        if Staging.FindSet(true) then
            repeat
                if FindSalesLine(Staging, SalesHeader."No.", SalesLine) then
                    if Staging."BC Line No." <> SalesLine."Line No." then begin
                        Staging."BC Line No." := SalesLine."Line No.";
                        Staging.Modify(true);
                    end;
                if Staging."BC Line No." = 0 then
                    Missing.Add(Staging."Entry No.")
                else begin
                    ReserveMissingPositions(Missing, SalesHeader."No.", PreviousNo, Staging."BC Line No.");
                    PreviousNo := Staging."BC Line No.";
                end;
            until Staging.Next() = 0;
        ReserveMissingPositions(Missing, SalesHeader."No.", PreviousNo, 0);
    end;

    local procedure ReserveMissingPositions(var Missing: List of [Integer]; DocumentNo: Code[20]; PreviousNo: Integer; NextNo: Integer)
    var
        Staging: Record "Impress Sales Line Staging";
        Reserved: Record "Impress Sales Line Staging";
        ExistingLine: Record "Sales Line";
        EntryNo: Integer;
        Position: Integer;
        Step: Integer;
        Occupied: Boolean;
    begin
        if Missing.Count() = 0 then
            exit;
        Step := 10000;
        if NextNo <> 0 then begin
            Step := (NextNo - PreviousNo) div (Missing.Count() + 1);
            if Step < 1 then
                Error('Sales order %1 has no room for %2 staged lines between BC line numbers %3 and %4. Correct the staged line sequence before retrying.', DocumentNo, Missing.Count(), PreviousNo, NextNo);
        end;
        Position := PreviousNo;
        foreach EntryNo in Missing do begin
            Staging.Get(EntryNo);
            Position += Step;
            repeat
                if (NextNo <> 0) and (Position >= NextNo) then
                    Error('Sales order %1 has no free line number before %2 for staging entry %3.', DocumentNo, NextNo, EntryNo);
                Reserved.Reset();
                Reserved.SetRange("Source Database", Staging."Source Database");
                Reserved.SetRange("Source Sales Order ID", Staging."Source Sales Order ID");
                Reserved.SetRange("BC Line No.", Position);
                Occupied := ExistingLine.Get(ExistingLine."Document Type"::Order, DocumentNo, Position) or not Reserved.IsEmpty();
                if Occupied then
                    Position += 1;
            until not Occupied;
            Staging."BC Line No." := Position;
            Staging.Modify(true);
        end;
        Clear(Missing);
    end;

    local procedure UpsertHeader(var Staging: Record "Impress Sales Header Staging"; var SalesHeader: Record "Sales Header")
    var
        Customer: Record Customer;
    begin
        ValidateSalesOrderNo(Staging);
        if not FindSalesHeader(Staging, SalesHeader) then begin
            if Staging.Operation <> Staging.Operation::Insert then
                Error('Sales Order for Source Database %1 and Source Sales Order ID %2 was not found.', Staging."Source Database", Staging."Source Sales Order ID");
            if not Customer.Get(Staging."Customer No.") then
                Error('Customer %1 does not exist.', Staging."Customer No.");
            CreateSalesHeader(SalesHeader, Staging);
        end else begin
            if (Staging."Customer No." <> '') and (SalesHeader."Sell-to Customer No." <> Staging."Customer No.") then
                Error('Customer cannot be changed on existing Sales Order %1. Current customer is %2; source customer is %3.', SalesHeader."No.", SalesHeader."Sell-to Customer No.", Staging."Customer No.");
        end;

        MapHeader(SalesHeader, Staging);
        SalesHeader.Modify(true);
        Staging."BC System ID" := SalesHeader.SystemId;
        Staging."BC Document No." := SalesHeader."No.";
        Staging.Modify(true);
    end;

    local procedure ValidateSalesOrderNo(Staging: Record "Impress Sales Header Staging")
    begin
        if Staging."Sales Order No." = '' then
            Error('Sales Order No. is required for sales header staging entry %1.', Staging."Entry No.");
    end;

    local procedure CreateSalesHeader(var SalesHeader: Record "Sales Header"; Staging: Record "Impress Sales Header Staging")
    begin
        SalesHeader.Init();
        SalesHeader.SetHideValidationDialog(true);
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", Staging."Customer No.");
    end;

    local procedure FindSalesHeader(Staging: Record "Impress Sales Header Staging"; var SalesHeader: Record "Sales Header"): Boolean
    begin
        if not IsNullGuid(Staging."BC System ID") then
            if SalesHeader.GetBySystemId(Staging."BC System ID") and (SalesHeader."Document Type" = SalesHeader."Document Type"::Order) then
                exit(true);
        SalesHeader.Reset();
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("Impress Source Database", Staging."Source Database");
        SalesHeader.SetRange("Impress Source Sales Order ID", Staging."Source Sales Order ID");
        exit(SalesHeader.FindFirst());
    end;

    local procedure MapHeader(var SalesHeader: Record "Sales Header"; Staging: Record "Impress Sales Header Staging")
    begin
        SalesHeader.SetHideValidationDialog(true);
        SalesHeader."Impress Source Database" := Staging."Source Database";
        SalesHeader."Impress Source Sales Order ID" := Staging."Source Sales Order ID";
        SalesHeader."Impress Source Sales Order No." := Staging."Sales Order No.";
        if Staging."Customer PO No." <> '' then
            SalesHeader.Validate("External Document No.", CopyStr(Staging."Customer PO No.", 1, MaxStrLen(SalesHeader."External Document No.")));
        if Staging."Order Date" <> 0D then
            SalesHeader.Validate("Order Date", Staging."Order Date");
        if Staging."Requested Shipment Date" <> 0D then
            SalesHeader.Validate("Shipment Date", Staging."Requested Shipment Date");
        if Staging."Due Date" <> 0D then
            SalesHeader.Validate("Due Date", Staging."Due Date");
        if Staging."Payment Terms Code" <> '' then
            SalesHeader.Validate("Payment Terms Code", Staging."Payment Terms Code");
        SalesHeader.Validate("Currency Code", Staging."Currency Code");
        if Staging."BC Location Code" <> '' then
            SalesHeader.Validate("Location Code", Staging."BC Location Code");
        // Ship Via Code conversion is disabled. Preserve the shipment method
        // inherited from the customer or already set on the sales order.
        // if Staging."Ship Via Code" <> '' then
        //     SalesHeader.Validate("Shipment Method Code", CopyStr(Staging."Ship Via Code", 1, MaxStrLen(SalesHeader."Shipment Method Code")));
        if Staging."On Hold" or Staging."Billing Hold" then
            SalesHeader."On Hold" := 'IMP'
        else
            Clear(SalesHeader."On Hold");

        EnsureTaxSetup(Staging);
        if Staging."Tax Area Code" <> '' then
            SalesHeader.Validate("Tax Area Code", Staging."Tax Area Code");
        SalesHeader.Validate("Tax Liable", true);

        SalesHeader."Bill-to Name" := CopyStr(Staging."Bill-to Name", 1, MaxStrLen(SalesHeader."Bill-to Name"));
        SalesHeader."Bill-to Address" := CopyStr(Staging."Bill-to Address", 1, MaxStrLen(SalesHeader."Bill-to Address"));
        SalesHeader."Bill-to Address 2" := CopyStr(Staging."Bill-to Address 2", 1, MaxStrLen(SalesHeader."Bill-to Address 2"));
        SalesHeader."Bill-to City" := CopyStr(Staging."Bill-to City", 1, MaxStrLen(SalesHeader."Bill-to City"));
        SalesHeader."Bill-to County" := CopyStr(Staging."Bill-to State", 1, MaxStrLen(SalesHeader."Bill-to County"));
        SalesHeader."Bill-to Post Code" := CopyStr(Staging."Bill-to Post Code", 1, MaxStrLen(SalesHeader."Bill-to Post Code"));

        SalesHeader."Ship-to Name" := CopyStr(Staging."Ship-to Name", 1, MaxStrLen(SalesHeader."Ship-to Name"));
        SalesHeader."Ship-to Address" := CopyStr(Staging."Ship-to Address", 1, MaxStrLen(SalesHeader."Ship-to Address"));
        SalesHeader."Ship-to Address 2" := CopyStr(Staging."Ship-to Address 2", 1, MaxStrLen(SalesHeader."Ship-to Address 2"));
        SalesHeader."Ship-to City" := CopyStr(Staging."Ship-to City", 1, MaxStrLen(SalesHeader."Ship-to City"));
        SalesHeader."Ship-to County" := CopyStr(Staging."Ship-to State", 1, MaxStrLen(SalesHeader."Ship-to County"));
        SalesHeader."Ship-to Post Code" := CopyStr(Staging."Ship-to Post Code", 1, MaxStrLen(SalesHeader."Ship-to Post Code"));
        SalesHeader."Ship-to Country/Region Code" := CopyStr(Staging."Ship-to Country Code", 1, MaxStrLen(SalesHeader."Ship-to Country/Region Code"));

        ApplyCategoryDimension(SalesHeader, Staging);
    end;

    local procedure ApplyCategoryDimension(var SalesHeader: Record "Sales Header"; Staging: Record "Impress Sales Header Staging")
    var
        Defaults: Record "Impress Defaults";
        CategoryDimension: Codeunit "Impress Category Dimension";
        DimensionSetID: Integer;
    begin
        if not Defaults.Get() then
            Error('Impress Defaults must be configured before processing sales orders.');
        if Defaults."Category Dimension Code" = '' then
            Error('Category Dimension must be configured on Impress Defaults.');

        DimensionSetID := SalesHeader."Dimension Set ID";
        CategoryDimension.ApplyToDimensionSet(
            DimensionSetID, Defaults."Category Dimension Code",
            CategoryDimension.GetDimensionValueCode(Staging."Source Database", Staging."Division Code"));
        SalesHeader.Validate("Dimension Set ID", DimensionSetID);
    end;

    local procedure ProcessLineCore(var Staging: Record "Impress Sales Line Staging"; SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
    begin
        if Staging.Operation = Staging.Operation::Delete then begin
            if not FindSalesLine(Staging, SalesHeader."No.", SalesLine) then
                exit;
            if (SalesLine."Quantity Shipped" <> 0) or (SalesLine."Quantity Invoiced" <> 0) then
                Error('Cannot delete sales line because quantity has already been shipped or invoiced. Source Sales Order Detail ID %1, Size Position %2.', Staging."Source Sales Order Detail ID", Staging."Size Position");
            SalesLine.Delete(true);
            exit;
        end;
        ValidateLineType(Staging);
        if not FindSalesLine(Staging, SalesHeader."No.", SalesLine) then
            InsertSalesLine(SalesLine, SalesHeader, Staging)
        else
            UpdateSalesLine(SalesLine, Staging);
        Staging."BC Line System ID" := SalesLine.SystemId;
        Staging."BC Line No." := SalesLine."Line No.";
    end;

    local procedure InsertSalesLine(var SalesLine: Record "Sales Line"; SalesHeader: Record "Sales Header"; Staging: Record "Impress Sales Line Staging")
    begin
        ValidateTargetReference(Staging);
        SalesLine.Init();
        SalesLine.SetHideValidationDialog(true);
        SalesLine."Document Type" := SalesLine."Document Type"::Order;
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := GetLineNo(SalesHeader."No.", Staging."BC Line No.");
        SalesLine.Insert(true);
        ApplyLineTarget(SalesLine, Staging);
        ApplyMutableLineFields(SalesLine, Staging);
        ApplyTaxGroup(SalesLine, Staging);
        SalesLine.Validate("Tax Liable", true);
        ApplyLineCategoryDimension(SalesLine, Staging);
        SetLineIdentity(SalesLine, Staging);
        SalesLine.Modify(true);
    end;

    local procedure UpdateSalesLine(var SalesLine: Record "Sales Line"; Staging: Record "Impress Sales Line Staging")
    var
        HasActivity: Boolean;
        MinimumQuantity: Decimal;
    begin
        SalesLine.SetHideValidationDialog(true);
        HasActivity := (SalesLine."Quantity Shipped" <> 0) or (SalesLine."Quantity Invoiced" <> 0);
        if Staging.Operation = Staging.Operation::Close then begin
            MinimumQuantity := SalesLine."Quantity Shipped";
            if SalesLine."Quantity Invoiced" > MinimumQuantity then
                MinimumQuantity := SalesLine."Quantity Invoiced";
            SalesLine.Validate(Quantity, MinimumQuantity);
        end else begin
            if Staging.Quantity < SalesLine."Quantity Shipped" then
                Error('Cannot reduce quantity below quantity shipped. Source Sales Order Detail ID %1, Size Position %2.', Staging."Source Sales Order Detail ID", Staging."Size Position");
            if Staging.Quantity < SalesLine."Quantity Invoiced" then
                Error('Cannot reduce quantity below quantity invoiced. Source Sales Order Detail ID %1, Size Position %2.', Staging."Source Sales Order Detail ID", Staging."Size Position");
            if HasActivity and not TargetMatches(SalesLine, Staging) then
                Error('Cannot change line type, number, or variant after shipment or invoice activity exists. Source Sales Order Detail ID %1, Size Position %2.', Staging."Source Sales Order Detail ID", Staging."Size Position");
            if not HasActivity then begin
                ValidateTargetReference(Staging);
                ApplyLineTarget(SalesLine, Staging);
            end;
            ApplyMutableLineFields(SalesLine, Staging);
        end;
        ApplyTaxGroup(SalesLine, Staging);
        SalesLine.Validate("Tax Liable", true);
        ApplyLineCategoryDimension(SalesLine, Staging);
        SetLineIdentity(SalesLine, Staging);
        SalesLine.Modify(true);
    end;

    local procedure ApplyLineTarget(var SalesLine: Record "Sales Line"; Staging: Record "Impress Sales Line Staging")
    var
        ChargeCode: Code[20];
    begin
        if Staging."BC Line Type" = 'ITEM' then begin
            if SalesLine.Type <> SalesLine.Type::Item then
                SalesLine.Validate(Type, SalesLine.Type::Item);
            if SalesLine."No." <> Staging."BC Item No." then
                SalesLine.Validate("No.", Staging."BC Item No.");
            SalesLine.Validate("Variant Code", Staging."BC Variant Code");
        end else begin
            ChargeCode := GetChargeCode(Staging);
            if SalesLine.Type <> SalesLine.Type::Resource then
                SalesLine.Validate(Type, SalesLine.Type::Resource);
            // Refresh resource defaults when retrying an unposted charge line too.
            SalesLine.Validate("No.", ChargeCode);
            if SalesLine."Variant Code" <> '' then
                SalesLine.Validate("Variant Code", '');
        end;
    end;

    local procedure ApplyMutableLineFields(var SalesLine: Record "Sales Line"; Staging: Record "Impress Sales Line Staging")
    begin
        SalesLine.Validate(Quantity, Staging.Quantity);
        SalesLine.Validate("Unit Price", Staging."Unit Price");
        if (Staging."BC Line Type" = 'ITEM') and (Staging."Unit of Measure Code" <> '') then
            SalesLine.Validate("Unit of Measure Code", Staging."Unit of Measure Code");
        if Staging."Requested Date" <> 0D then
            SalesLine.Validate("Shipment Date", Staging."Requested Date");
        if Staging.Discountable then
            SalesLine.Validate("Line Discount %", Staging."Discount Rate")
        else
            SalesLine.Validate("Line Discount %", 0);
        if Staging.Description <> '' then
            SalesLine.Description := CopyStr(Staging.Description, 1, MaxStrLen(SalesLine.Description));
    end;

    local procedure ApplyTaxGroup(var SalesLine: Record "Sales Line"; Staging: Record "Impress Sales Line Staging")
    begin
        if Staging."Tax Group Code" <> '' then
            SalesLine.Validate("Tax Group Code", Staging."Tax Group Code");
    end;

    local procedure ApplyLineCategoryDimension(var SalesLine: Record "Sales Line"; Staging: Record "Impress Sales Line Staging")
    var
        Defaults: Record "Impress Defaults";
        CategoryDimension: Codeunit "Impress Category Dimension";
        DimensionSetID: Integer;
    begin
        if not Defaults.Get() then
            Error('Impress Defaults must be configured before processing sales order lines.');
        if Defaults."Category Dimension Code" = '' then
            Error('Category Dimension must be configured on Impress Defaults.');

        DimensionSetID := SalesLine."Dimension Set ID";
        CategoryDimension.ApplyToDimensionSet(
            DimensionSetID, Defaults."Category Dimension Code",
            CategoryDimension.GetDimensionValueCode(Staging."Source Database", Staging."Division Code"));
        SalesLine.Validate("Dimension Set ID", DimensionSetID);
    end;

    local procedure EnsureTaxSetup(HeaderStaging: Record "Impress Sales Header Staging")
    var
        LineStaging: Record "Impress Sales Line Staging";
        EffectiveDate: Date;
    begin
        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source Sales Order ID", HeaderStaging."Source Sales Order ID");
        if not TaxSetupIsRequired(HeaderStaging, LineStaging) then
            exit;
        if HeaderStaging."Tax Area Code" = '' then
            Error('Tax Area Code is blank in stored sales staging header entry %1, source %2, sales order %3. Transaction tax setup is required. Save the staging Tax Area Code and retry.', HeaderStaging."Entry No.", HeaderStaging."Source Database", HeaderStaging."Sales Order No.");

        EnsureTaxGroups(LineStaging, HeaderStaging."Sales Order No.");
        TaxResolver.EnsureTaxJurisdiction(HeaderStaging."Tax Jurisdiction Code 1", HeaderStaging."Tax Jurisdiction Desc. 1", HeaderStaging."Tax Jurisdiction G/L Acc. 1");
        TaxResolver.EnsureTaxJurisdiction(HeaderStaging."Tax Jurisdiction Code 2", HeaderStaging."Tax Jurisdiction Desc. 2", HeaderStaging."Tax Jurisdiction G/L Acc. 2");
        TaxResolver.EnsureTaxJurisdiction(HeaderStaging."Tax Jurisdiction Code 3", HeaderStaging."Tax Jurisdiction Desc. 3", HeaderStaging."Tax Jurisdiction G/L Acc. 3");
        TaxResolver.EnsureTaxJurisdiction(HeaderStaging."Tax Jurisdiction Code 4", HeaderStaging."Tax Jurisdiction Desc. 4", HeaderStaging."Tax Jurisdiction G/L Acc. 4");
        TaxResolver.EnsureTaxArea(HeaderStaging."Tax Area Code", HeaderStaging."Tax Area Description");
        TaxResolver.EnsureTaxAreaLine(HeaderStaging."Tax Area Code", HeaderStaging."Tax Jurisdiction Code 1", 1);
        TaxResolver.EnsureTaxAreaLine(HeaderStaging."Tax Area Code", HeaderStaging."Tax Jurisdiction Code 2", 2);
        TaxResolver.EnsureTaxAreaLine(HeaderStaging."Tax Area Code", HeaderStaging."Tax Jurisdiction Code 3", 3);
        TaxResolver.EnsureTaxAreaLine(HeaderStaging."Tax Area Code", HeaderStaging."Tax Jurisdiction Code 4", 4);

        EffectiveDate := HeaderStaging."Order Date";
        if EffectiveDate = 0D then
            EffectiveDate := WorkDate();
        EnsureTaxDetailsForLines(LineStaging, HeaderStaging, EffectiveDate);
    end;

    local procedure TaxSetupIsRequired(HeaderStaging: Record "Impress Sales Header Staging"; var LineStaging: Record "Impress Sales Line Staging"): Boolean
    begin
        if (HeaderStaging."Tax Area Code" <> '') or (HeaderStaging."Tax Jurisdiction Code 1" <> '') or
           (HeaderStaging."Tax Jurisdiction Code 2" <> '') or (HeaderStaging."Tax Jurisdiction Code 3" <> '') or
           (HeaderStaging."Tax Jurisdiction Code 4" <> '')
        then
            exit(true);
        LineStaging.SetFilter("Tax Group Code", '<>%1', '');
        exit(not LineStaging.IsEmpty());
    end;

    local procedure EnsureTaxGroups(var LineStaging: Record "Impress Sales Line Staging"; SalesOrderNo: Code[35])
    begin
        LineStaging.SetRange("Tax Group Code");
        if LineStaging.FindSet() then
            repeat
                if LineStaging."Tax Group Code" <> '' then begin
                    ValidateTaxGroupCode(LineStaging."Tax Group Code", SalesOrderNo, LineStaging."Source Sales Order Detail ID");
                    TaxResolver.EnsureTaxGroup(LineStaging."Tax Group Code", LineStaging."Tax Group Description");
                end;
            until LineStaging.Next() = 0;
    end;

    local procedure ValidateTaxGroupCode(TaxGroupCode: Code[20]; SalesOrderNo: Code[35]; SourceDetailID: BigInteger)
    begin
        if not TaxResolver.IsSupportedTaxGroup(TaxGroupCode) then
            Error('Tax Group Code %1 is invalid for sales order %2, Source Sales Order Detail ID %3.', TaxGroupCode, SalesOrderNo, SourceDetailID);
    end;

    local procedure EnsureTaxDetailsForLines(var LineStaging: Record "Impress Sales Line Staging"; HeaderStaging: Record "Impress Sales Header Staging"; EffectiveDate: Date)
    var
        ProcessedTaxGroups: List of [Code[20]];
        TaxGroupCode: Code[20];
    begin
        LineStaging.Reset();
        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source Sales Order ID", HeaderStaging."Source Sales Order ID");
        LineStaging.SetFilter("Tax Group Code", '<>%1', '');
        if LineStaging.FindSet() then
            repeat
                TaxGroupCode := LineStaging."Tax Group Code";
                if not ProcessedTaxGroups.Contains(TaxGroupCode) then begin
                    ProcessedTaxGroups.Add(TaxGroupCode);
                    TaxResolver.EnsureTaxDetail(HeaderStaging."Tax Jurisdiction Code 1", TaxGroupCode, TaxResolver.GetTaxRateForGroup(TaxGroupCode, HeaderStaging."Tax Jurisdiction Rate 1"), EffectiveDate);
                    TaxResolver.EnsureTaxDetail(HeaderStaging."Tax Jurisdiction Code 2", TaxGroupCode, TaxResolver.GetTaxRateForGroup(TaxGroupCode, HeaderStaging."Tax Jurisdiction Rate 2"), EffectiveDate);
                    TaxResolver.EnsureTaxDetail(HeaderStaging."Tax Jurisdiction Code 3", TaxGroupCode, TaxResolver.GetTaxRateForGroup(TaxGroupCode, HeaderStaging."Tax Jurisdiction Rate 3"), EffectiveDate);
                    TaxResolver.EnsureTaxDetail(HeaderStaging."Tax Jurisdiction Code 4", TaxGroupCode, TaxResolver.GetTaxRateForGroup(TaxGroupCode, HeaderStaging."Tax Jurisdiction Rate 4"), EffectiveDate);
                end;
            until LineStaging.Next() = 0;
    end;

    local procedure ValidateLineType(Staging: Record "Impress Sales Line Staging")
    begin
        if not (Staging."BC Line Type" in ['ITEM', 'CHARGE']) then
            Error('BC Line Type must be ITEM or CHARGE. Value %1 is invalid.', Staging."BC Line Type");
        if (Staging."BC Line Type" = 'ITEM') and ((Staging."Size Position" < 1) or (Staging."Size Position" > 6)) then
            Error('ITEM Size Position must be between 1 and 6. Value %1 is invalid.', Staging."Size Position");
        if (Staging."BC Line Type" = 'CHARGE') and (Staging."Size Position" <> 0) then
            Error('CHARGE Size Position must be 0. Value %1 is invalid.', Staging."Size Position");
    end;

    local procedure ValidateTargetReference(Staging: Record "Impress Sales Line Staging")
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        if Staging."BC Line Type" = 'CHARGE' then begin
            EnsureChargeResource(Staging);
            exit;
        end;
        if Staging."BC Item No." = '' then
            Error('BC Item No. is blank for sales order %1, Source Sales Order Detail ID %2, Size Position %3, Source Code %4.', Staging."Sales Order No.", Staging."Source Sales Order Detail ID", Staging."Size Position", Staging."Source Code");
        if not Item.Get(Staging."BC Item No.") then
            Error('BC Item %1 does not exist for sales order %2, Source Sales Order Detail ID %3, Size Position %4, Source Code %5.', Staging."BC Item No.", Staging."Sales Order No.", Staging."Source Sales Order Detail ID", Staging."Size Position", Staging."Source Code");
        if (Staging."BC Variant Code" <> '') and not ItemVariant.Get(Staging."BC Item No.", Staging."BC Variant Code") then
            Error('Variant %1 does not exist for Item %2.', Staging."BC Variant Code", Staging."BC Item No.");
        if (Staging."Unit of Measure Code" <> '') and not ItemUnitOfMeasure.Get(Staging."BC Item No.", Staging."Unit of Measure Code") then
            Error('Unit of Measure %1 does not exist for Item %2.', Staging."Unit of Measure Code", Staging."BC Item No.");
    end;

    local procedure TargetMatches(SalesLine: Record "Sales Line"; Staging: Record "Impress Sales Line Staging"): Boolean
    begin
        if Staging."BC Line Type" = 'ITEM' then
            exit((SalesLine.Type = SalesLine.Type::Item) and (SalesLine."No." = Staging."BC Item No.") and (SalesLine."Variant Code" = Staging."BC Variant Code"));
        exit((SalesLine.Type = SalesLine.Type::Resource) and (SalesLine."No." = GetChargeCode(Staging)) and (SalesLine."Variant Code" = ''));
    end;

    local procedure GetChargeCode(Staging: Record "Impress Sales Line Staging"): Code[20]
    begin
        Staging.TestField("Source Code");
        if StrLen(Staging."Source Code") > 20 then
            Error('Charge code %1 exceeds the 20-character resource and posting group limit.', Staging."Source Code");
        exit(Staging."Source Code");
    end;

    procedure EnsureChargeResource(Staging: Record "Impress Sales Line Staging")
    var
        ChargeResource: Record Resource;
        ProductPostingGroup: Record "Gen. Product Posting Group";
        UnitOfMeasure: Record "Unit of Measure";
        ResourceUnitOfMeasure: Record "Resource Unit of Measure";
        ChargeCode: Code[20];
        UnitCode: Code[10];
    begin
        ChargeCode := GetChargeCode(Staging);
        if not ProductPostingGroup.Get(ChargeCode) then begin
            ProductPostingGroup.Init();
            ProductPostingGroup.Code := ChargeCode;
            ProductPostingGroup.Description := CopyStr(Staging.Description, 1, MaxStrLen(ProductPostingGroup.Description));
            ProductPostingGroup.Insert(true);
        end;
        if not ChargeResource.Get(ChargeCode) then begin
            ChargeResource.Init();
            ChargeResource.Validate("No.", ChargeCode);
            ChargeResource.Name := Staging.Description;
            if ChargeResource.Name = '' then
                ChargeResource.Name := ChargeCode;
            ChargeResource.Type := ChargeResource.Type::Person;
            ChargeResource.Insert(true);
        end;
        ChargeResource.TestField(Blocked, false);
        UnitCode := 'EA';
        if not UnitOfMeasure.Get(UnitCode) then begin
            UnitOfMeasure.Init();
            UnitOfMeasure.Code := UnitCode;
            UnitOfMeasure.Description := UnitCode;
            UnitOfMeasure.Insert(true);
        end;
        if not ResourceUnitOfMeasure.Get(ChargeCode, UnitCode) then begin
            ResourceUnitOfMeasure.Init();
            ResourceUnitOfMeasure."Resource No." := ChargeCode;
            ResourceUnitOfMeasure.Code := UnitCode;
            ResourceUnitOfMeasure.Validate("Qty. per Unit of Measure", 1);
            ResourceUnitOfMeasure.Insert(true);
        end;
        ResourceUnitOfMeasure.TestField("Qty. per Unit of Measure", 1);
        ChargeResource.Validate(Type, ChargeResource.Type::Person);
        if ChargeResource."Base Unit of Measure" <> UnitCode then
            ChargeResource.Validate("Base Unit of Measure", UnitCode);
        ChargeResource.Validate("Gen. Prod. Posting Group", ChargeCode);
        ChargeResource.Modify(true);
    end;

    local procedure FindSalesLine(Staging: Record "Impress Sales Line Staging"; DocumentNo: Code[20]; var SalesLine: Record "Sales Line"): Boolean
    begin
        if not IsNullGuid(Staging."BC Line System ID") then
            if SalesLine.GetBySystemId(Staging."BC Line System ID") then
                exit((SalesLine."Document Type" = SalesLine."Document Type"::Order) and (SalesLine."Document No." = DocumentNo));
        SalesLine.Reset();
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", DocumentNo);
        SalesLine.SetRange("Impress Source Database", Staging."Source Database");
        SalesLine.SetRange("Impress Sales Detail ID", Staging."Source Sales Order Detail ID");
        SalesLine.SetRange("Impress Size Position", Staging."Size Position");
        exit(SalesLine.FindFirst());
    end;

    local procedure FindHeaderForLine(Staging: Record "Impress Sales Line Staging"; var SalesHeader: Record "Sales Header")
    begin
        if not IsNullGuid(Staging."BC System ID") then
            if SalesHeader.GetBySystemId(Staging."BC System ID") then
                exit;
        if Staging."BC Document No." <> '' then
            if SalesHeader.Get(SalesHeader."Document Type"::Order, Staging."BC Document No.") then
                exit;
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("Impress Source Database", Staging."Source Database");
        SalesHeader.SetRange("Impress Source Sales Order ID", Staging."Source Sales Order ID");
        if not SalesHeader.FindFirst() then
            Error('Sales Order for Source Database %1 and Source Sales Order ID %2 was not found.', Staging."Source Database", Staging."Source Sales Order ID");
    end;

    local procedure GetLineNo(DocumentNo: Code[20]; RequestedLineNo: Integer): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        if RequestedLineNo <> 0 then
            if not SalesLine.Get(SalesLine."Document Type"::Order, DocumentNo, RequestedLineNo) then
                exit(RequestedLineNo)
            else
                Error('Sales order %1 line number %2 is occupied by another line. The staged line cannot be appended because its sequence must be preserved.', DocumentNo, RequestedLineNo);
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", DocumentNo);
        if SalesLine.FindLast() then
            exit(SalesLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure SetLineIdentity(var SalesLine: Record "Sales Line"; Staging: Record "Impress Sales Line Staging")
    begin
        SalesLine."Impress Source Database" := Staging."Source Database";
        SalesLine."Impress Sales Detail ID" := Staging."Source Sales Order Detail ID";
        SalesLine."Impress Size Position" := Staging."Size Position";
    end;

    local procedure CloseSalesOrderLines(SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        MinimumQuantity: Decimal;
    begin
        SalesLine.SetHideValidationDialog(true);
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet(true) then
            repeat
                MinimumQuantity := SalesLine."Quantity Shipped";
                if SalesLine."Quantity Invoiced" > MinimumQuantity then
                    MinimumQuantity := SalesLine."Quantity Invoiced";
                if SalesLine.Quantity <> MinimumQuantity then begin
                    SalesLine.Validate(Quantity, MinimumQuantity);
                    SalesLine.Modify(true);
                end;
            until SalesLine.Next() = 0;
    end;

    local procedure DeleteSalesOrder(var Staging: Record "Impress Sales Header Staging")
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        if not FindSalesHeader(Staging, SalesHeader) then
            exit;
        Staging."BC System ID" := SalesHeader.SystemId;
        Staging."BC Document No." := SalesHeader."No.";
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter("Quantity Shipped", '<>0');
        if not SalesLine.IsEmpty() then
            Error('Sales Order %1 cannot be deleted because it has shipment activity.', SalesHeader."No.");
        SalesLine.SetRange("Quantity Shipped");
        SalesLine.SetFilter("Quantity Invoiced", '<>0');
        if not SalesLine.IsEmpty() then
            Error('Sales Order %1 cannot be deleted because it has invoice activity.', SalesHeader."No.");
        SalesHeader.Delete(true);
    end;

    local procedure SetHeaderProcessed(var Staging: Record "Impress Sales Header Staging")
    begin
        Staging."Processing Status" := Staging."Processing Status"::Processed;
        Staging."Processed Date Time" := CurrentDateTime();
        Clear(Staging."Error Message");
        Staging.Modify(true);
    end;

    local procedure SetLineProcessing(var Staging: Record "Impress Sales Line Staging")
    begin
        Staging."Processing Status" := Staging."Processing Status"::Processing;
        Clear(Staging."Error Message");
        Staging.Modify(true);
    end;

    local procedure SetLineProcessed(var Staging: Record "Impress Sales Line Staging"; SalesHeader: Record "Sales Header")
    begin
        Staging."BC System ID" := SalesHeader.SystemId;
        Staging."BC Document No." := SalesHeader."No.";
        Staging."Processing Status" := Staging."Processing Status"::Processed;
        Staging."Processed Date Time" := CurrentDateTime();
        Clear(Staging."Error Message");
        Staging.Modify(true);
    end;

    local procedure MarkDocumentError(var HeaderStaging: Record "Impress Sales Header Staging"; ErrorText: Text)
    var
        LineStaging: Record "Impress Sales Line Staging";
    begin
        HeaderStaging."Processing Status" := HeaderStaging."Processing Status"::Error;
        HeaderStaging."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(HeaderStaging."Error Message"));
        HeaderStaging.Modify(true);
        LineStaging.SetRange("Source Database", HeaderStaging."Source Database");
        LineStaging.SetRange("Source Sales Order ID", HeaderStaging."Source Sales Order ID");
        // A later document-level failure must not replace a line's original error.
        LineStaging.SetFilter("Processing Status", '%1|%2', LineStaging."Processing Status"::Pending, LineStaging."Processing Status"::Processing);
        if LineStaging.FindSet(true) then
            repeat
                LineStaging."Processing Status" := LineStaging."Processing Status"::Error;
                LineStaging."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(LineStaging."Error Message"));
                LineStaging.Modify(true);
            until LineStaging.Next() = 0;
    end;
    var
        TaxResolver: Codeunit "Impress Tax Resolver";
}
