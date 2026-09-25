codeunit 80034 "Impress Invoice Line Match"
{
    [CommitBehavior(CommitBehavior::Error)]
    procedure Resolve(Header: Record "Impress Sales Doc Hdr Staging"; InvoiceLine: Record "Impress Sales Doc Line Staging"; OrderStaging: Record "Impress Sales Header Staging"; Order: Record "Sales Header"; var SalesLine: Record "Sales Line"): Boolean
    begin
        exit(ResolveInternal(Header, InvoiceLine, OrderStaging, Order, SalesLine, false));
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure ResolveForNewOrder(Header: Record "Impress Sales Doc Hdr Staging"; InvoiceLine: Record "Impress Sales Doc Line Staging"; Order: Record "Sales Header"; var SalesLine: Record "Sales Line"): Boolean
    var
        EmptyOrderStaging: Record "Impress Sales Header Staging";
    begin
        // Only the caller that just created this invoice's replacement order
        // may bypass originating-order matching.
        Order.TestField("Integration Posting ID", Header."Integration Posting ID");
        Order.TestField("Impress Source Database", Header."Source Database");
        exit(ResolveInternal(Header, InvoiceLine, EmptyOrderStaging, Order, SalesLine, true));
    end;

    local procedure ResolveInternal(Header: Record "Impress Sales Doc Hdr Staging"; InvoiceLine: Record "Impress Sales Doc Line Staging"; OrderStaging: Record "Impress Sales Header Staging"; Order: Record "Sales Header"; var SalesLine: Record "Sales Line"; NewOrder: Boolean): Boolean
    var
        Staged: Record "Impress Sales Line Staging";
        Candidate: Record "Sales Line";
        Charge: Record "Impress Sales Line Staging";
        OrderMgt: Codeunit "Impress Sales Order Mgt.";
        CandidateNos: Text;
        Context: Text;
        ExpectedNo: Code[20];
        Count: Integer;
        NextNo: Integer;
        ExplicitSourceLine: Boolean;
    begin
        Header.TestField("Source Database");
        Order.TestField("Document Type", Order."Document Type"::Order);
        ExpectedNo := TargetNo(InvoiceLine);
        if IsItem(InvoiceLine) then
            InvoiceLine.TestField("Source Raw SKU No.");
        Context := StrSubstNo('Source %1 order %2 invoice %3 raw SKU %4 size %5 item %6 variant %7', Header."Source Database", Header."Source Sales Order No.", Header."Document No.", InvoiceLine."Source Raw SKU No.", InvoiceLine."Size Position", ExpectedNo, InvoiceLine."BC Variant Code");
        ExplicitSourceLine := IsItem(InvoiceLine) and (InvoiceLine."Source Sales Order Line No." <> 0);
        if ExplicitSourceLine then begin
            Context += StrSubstNo(' originating Sales Order line %1', InvoiceLine."Source Sales Order Line No.");
            if Header."Source Sales Order No." = '' then
                Error('%1: explicit originating line requires a Source Sales Order No.', Context);
            if (OrderStaging."Entry No." = 0) and not NewOrder then
                Error('%1: originating staged Sales Order is unavailable; explicit source line cannot use fallback matching.', Context);
        end;
        if OrderStaging."Entry No." <> 0 then begin
            OrderStaging.TestField("Source Database", Header."Source Database");
            OrderStaging.TestField("Sales Order No.", Header."Source Sales Order No.");
            OrderStaging.TestField("BC Document No.", Order."No.");
            Staged.SetRange("Source Database", OrderStaging."Source Database");
            Staged.SetRange("Source Sales Order ID", OrderStaging."Source Sales Order ID");
            Staged.SetRange("Sales Order No.", OrderStaging."Sales Order No.");
            // This is SORDERD_LINE, not the invoice line/sequence, detail ID,
            // or physical BC line number. Retain all existing identity filters.
            if ExplicitSourceLine then
                Staged.SetRange("Source Line No.", InvoiceLine."Source Sales Order Line No.");
            Staged.SetRange("Size Position", InvoiceLine."Size Position");
            if IsItem(InvoiceLine) then begin
                InvoiceLine.TestField("Source Raw SKU No.");
                Staged.SetRange("BC Line Type", 'ITEM');
                Staged.SetRange("Source SKU", InvoiceLine."Source Raw SKU No.");
                Staged.SetRange("BC Item No.", ExpectedNo);
                Staged.SetRange("BC Variant Code", InvoiceLine."BC Variant Code");
            end else begin
                InvoiceLine.TestField("Size Position", 0);
                Staged.SetRange("BC Line Type", 'CHARGE');
                Staged.SetRange("Source Code", ExpectedNo);
            end;
            Count := Staged.Count();
            if ExplicitSourceLine and (Count = 0) then
                Error('%1: no staged Sales Order line matches the explicit originating line, raw SKU, size, item and variant; fallback matching is not allowed.', Context);
            if Count > 1 then begin
                Staged.FindSet();
                repeat
                    CandidateNos += StrSubstNo(' %1(detail %2)', Staged."BC Line No.", Staged."Source Sales Order Detail ID");
                until Staged.Next() = 0;
                Error('%1: ambiguous staged lines:%2.', Context, CandidateNos);
            end;
            if Count = 1 then begin
                Staged.FindFirst();
                Staged.TestField("BC Line No.");
                if not SalesLine.Get(Order."Document Type", Order."No.", Staged."BC Line No.") then
                    Error('%1: staged BC line %2 is missing.', Context, Staged."BC Line No.");
                if not IsNullGuid(Staged."BC Line System ID") then
                    SalesLine.TestField(SystemId, Staged."BC Line System ID");
                VerifyLine(InvoiceLine, Order, SalesLine);
                exit(true);
            end;
        end;
        // Lock the order lines across the duplicate check and allocation.
        Candidate.LockTable();
        Candidate.SetRange("Document Type", Order."Document Type");
        Candidate.SetRange("Document No.", Order."No.");
        if IsItem(InvoiceLine) then
            Candidate.SetRange(Type, Candidate.Type::Item)
        else
            Candidate.SetRange(Type, Candidate.Type::Resource);
        Candidate.SetRange("No.", ExpectedNo);
        Candidate.SetRange("Variant Code", InvoiceLine."BC Variant Code");
        if NewOrder then begin
            // Different invoice lines can have the same SKU/size. Only reuse
            // this invoice line's own correlation on the newly created order.
            InvoiceLine.TestField("Entry No.");
            Candidate.SetRange("Impress Invoice Line Entry No.", InvoiceLine."Entry No.");
        end;
        // A persisted invoice correlation can distinguish a retry from other
        // lines with the same mapped item. Never choose by quantity or position.
        if InvoiceLine."Entry No." <> 0 then begin
            Candidate.SetRange("Impress Invoice Line Entry No.", InvoiceLine."Entry No.");
            if Candidate.IsEmpty() and not NewOrder then
                Candidate.SetRange("Impress Invoice Line Entry No.");
        end;
        if not NewOrder and ((InvoiceLine."BC Sales Line No." <> 0) or not IsNullGuid(InvoiceLine."BC Line System ID")) then begin
            if not SalesLine.Get(Order."Document Type", Order."No.", InvoiceLine."BC Sales Line No.") then
                Error('%1: previously correlated BC line %2 is missing.', Context, InvoiceLine."BC Sales Line No.");
            if not IsNullGuid(InvoiceLine."BC Line System ID") then
                SalesLine.TestField(SystemId, InvoiceLine."BC Line System ID");
            VerifyLine(InvoiceLine, Order, SalesLine);
            Candidate.SetRange("Line No.", SalesLine."Line No.");
        end;
        Count := Candidate.Count();
        if not NewOrder and (Count = 0) and (InvoiceLine."BC Sales Line No." <> 0) then
            Error('%1: persisted BC line correlation conflicts with the invoice source.', Context);
        if Count > 1 then begin
            Candidate.FindSet();
            repeat
                CandidateNos += StrSubstNo(' %1', Candidate."Line No.");
            until Candidate.Next() = 0;
            Error('%1: ambiguous BC lines:%2.', Context, CandidateNos);
        end;
        if Count = 1 then begin
            Candidate.FindFirst();
            if Candidate."Impress Sales Detail ID" <> 0 then begin
                Staged.Reset();
                Staged.SetRange("Source Database", Header."Source Database");
                Staged.SetRange("Source Sales Order Detail ID", Candidate."Impress Sales Detail ID");
                Staged.SetRange("Size Position", Candidate."Impress Size Position");
                if Staged.FindFirst() then begin
                    Staged.TestField("Sales Order No.", Header."Source Sales Order No.");
                    if IsItem(InvoiceLine) then begin
                        Staged.TestField("Source SKU", InvoiceLine."Source Raw SKU No.");
                        Staged.TestField("Size Position", InvoiceLine."Size Position");
                        Staged.TestField("BC Item No.", ExpectedNo);
                        Staged.TestField("BC Variant Code", InvoiceLine."BC Variant Code");
                    end else
                        Staged.TestField("Source Code", ExpectedNo);
                end else
                    Error('%1: BC line %2 has an unresolved source detail ID %3.', Context, Candidate."Line No.", Candidate."Impress Sales Detail ID");
            end;
            if (Candidate."Impress Source Database" <> '') and (Candidate."Impress Source Database" <> UpperCase(Header."Source Database")) then
                Error('%1: BC line %2 belongs to another source.', Context, Candidate."Line No.");
            if Candidate."Impress Raw SKU" <> '' then begin
                Candidate.TestField("Impress Raw SKU", InvoiceLine."Source Raw SKU No.");
                Candidate.TestField("Impress Size Position", InvoiceLine."Size Position");
            end;
            if (Candidate."Impress Invoice Line Entry No." <> 0) and (Candidate."Impress Invoice Line Entry No." <> InvoiceLine."Entry No.") then
                Error('%1: BC line %2 is correlated with another invoice line.', Context, Candidate."Line No.");
            SalesLine := Candidate;
            VerifyLine(InvoiceLine, Order, SalesLine);
            exit(true);
        end;
        Candidate.Reset();
        Candidate.SetRange("Document Type", Order."Document Type");
        Candidate.SetRange("Document No.", Order."No.");
        if Candidate.FindLast() then
            NextNo := Candidate."Line No.";
        if NextNo > 2147473647 then
            Error('%1: no space for another BC line number.', Context);
        if not IsItem(InvoiceLine) then begin
            Charge."Source Code" := ExpectedNo;
            Charge.Description := CopyStr(InvoiceLine."Source Description", 1, MaxStrLen(Charge.Description));
            OrderMgt.EnsureChargeResource(Charge);
        end;
        Clear(SalesLine);
        SalesLine."Document Type" := Order."Document Type";
        SalesLine."Document No." := Order."No.";
        SalesLine."Line No." := NextNo + 10000;
        SalesLine.Insert(true);
        SalesLine.SetHideValidationDialog(true);
        if IsItem(InvoiceLine) then
            SalesLine.Validate(Type, SalesLine.Type::Item)
        else
            SalesLine.Validate(Type, SalesLine.Type::Resource);
        SalesLine.Validate("No.", ExpectedNo);
        SalesLine.Validate("Variant Code", InvoiceLine."BC Variant Code");
        SalesLine.Validate(Quantity, InvoiceLine.Quantity);
        SalesLine.Validate("Unit Price", InvoiceLine."Unit Price");
        SalesLine."Impress Source Database" := Header."Source Database";
        SalesLine."Impress Raw SKU" := InvoiceLine."Source Raw SKU No.";
        SalesLine."Impress Size Position" := InvoiceLine."Size Position";
        SalesLine."Impress Invoice Line Entry No." := InvoiceLine."Entry No.";
        SalesLine.Modify(true);
        exit(false);
    end;

    procedure IsItem(Line: Record "Impress Sales Doc Line Staging"): Boolean
    begin
        exit(UpperCase(Line."Source Line Type") = 'ITEM');
    end;

    procedure TargetNo(Line: Record "Impress Sales Doc Line Staging"): Code[20]
    var
        Value: Text;
    begin
        if IsItem(Line) then begin
            Line.TestField("BC Item No.");
            exit(Line."BC Item No.");
        end;
        Line.TestField("Size Position", 0);
        Line.TestField("BC Variant Code", '');
        Value := Line."Source Item Code";
        if Value = '' then
            Value := Line."BC Item No.";
        if (Value = '') or (StrLen(Value) > 20) then
            Error('Invoice line %1 needs an explicit Resource code of at most 20 characters.', Line."Entry No.");
        exit(Value);
    end;

    local procedure VerifyLine(Line: Record "Impress Sales Doc Line Staging"; Order: Record "Sales Header"; SalesLine: Record "Sales Line")
    begin
        SalesLine.TestField("Document Type", SalesLine."Document Type"::Order);
        SalesLine.TestField("Document No.", Order."No.");
        if IsItem(Line) then
            SalesLine.TestField(Type, SalesLine.Type::Item)
        else
            SalesLine.TestField(Type, SalesLine.Type::Resource);
        SalesLine.TestField("No.", TargetNo(Line));
        SalesLine.TestField("Variant Code", Line."BC Variant Code");
    end;
}
