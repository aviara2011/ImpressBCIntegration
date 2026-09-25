codeunit 80036 "Impress II Line Lifecycle"
{
    EventSubscriberInstance = Manual;

    procedure Initialize(Header: Record "Impress Sales Doc Hdr Staging"; Order: Record "Sales Header")
    begin
        InvoiceHeader := Header;
        ActiveOrder := Order."No.";
        OldLines.Reset();
        OldLines.DeleteAll();
        Clear(OldIDs);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeRecreateSalesLines', '', false, false)]
    local procedure CaptureLines(var SalesHeader: Record "Sales Header")
    var
        CurrentLine: Record "Sales Line";
    begin
        if not IsActiveOrder(SalesHeader) then
            exit;
        OldLines.Reset();
        OldLines.DeleteAll();
        Clear(OldIDs);
        CurrentLine.SetRange("Document Type", SalesHeader."Document Type");
        CurrentLine.SetRange("Document No.", SalesHeader."No.");
        if CurrentLine.FindSet(true) then
            repeat
                // Keep the physical ID separately: temporary inserts have their own IDs.
                OldIDs.Add(CurrentLine."Line No.", CurrentLine.SystemId);
                OldLines := CurrentLine;
                OldLines.Insert(false);
            until CurrentLine.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterRecreateSalesLine', '', false, false)]
    local procedure RefreshRecreatedLine(var SalesLine: Record "Sales Line"; var TempSalesLine: Record "Sales Line" temporary; var SalesHeader: Record "Sales Header")
    var
        CurrentLine: Record "Sales Line";
        OldID: Guid;
    begin
        if not IsActiveOrder(SalesHeader) then
            exit;
        OldLines.Get(TempSalesLine."Document Type", TempSalesLine."Document No.", TempSalesLine."Line No.");
        OldID := OldIDs.Get(OldLines."Line No.");
        CheckTarget(TempSalesLine, OldLines);
        // Use BC's explicit old/new pair, never a guess based on a reused position.
        CurrentLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        CurrentLine.TestField(SystemId, SalesLine.SystemId);
        CheckTarget(CurrentLine, OldLines);
        CurrentLine."Impress Source Database" := OldLines."Impress Source Database";
        CurrentLine."Impress Sales Detail ID" := OldLines."Impress Sales Detail ID";
        CurrentLine."Impress Size Position" := OldLines."Impress Size Position";
        CurrentLine."Impress Raw SKU" := OldLines."Impress Raw SKU";
        CurrentLine."Impress Invoice Line Entry No." := OldLines."Impress Invoice Line Entry No.";
        CurrentLine."Integration Posting ID" := OldLines."Integration Posting ID";
        CurrentLine.Modify(false);
        RefreshOrderMapping(SalesHeader, OldLines, OldID, CurrentLine);
        RefreshInvoiceMapping(OldLines, OldID, CurrentLine);
        SalesLine := CurrentLine;
        OldIDs.Remove(OldLines."Line No.");
    end;

    local procedure RefreshOrderMapping(Order: Record "Sales Header"; OldLine: Record "Sales Line"; OldID: Guid; CurrentLine: Record "Sales Line")
    var
        Staged: Record "Impress Sales Line Staging";
    begin
        Staged.SetRange("Source Database", InvoiceHeader."Source Database");
        Staged.SetRange("Source Sales Order ID", Order."Impress Source Sales Order ID");
        Staged.SetRange("Sales Order No.", InvoiceHeader."Source Sales Order No.");
        Staged.SetRange("BC Line System ID", OldID);
        if Staged.Count() > 1 then
            Error('Order %1 line %2 has ambiguous staging references during line recreation.', Order."No.", OldLine."Line No.");
        if not Staged.FindFirst() then
            exit;
        // Prove the mapping was valid BEFORE BC recreated the physical record.
        Staged.TestField("BC Document No.", Order."No.");
        Staged.TestField("BC System ID", Order.SystemId);
        Staged.TestField("BC Line System ID", OldID);
        Staged.TestField("BC Line No.", OldLine."Line No.");
        OldLine.TestField("Impress Source Database", Staged."Source Database");
        OldLine.TestField("Impress Sales Detail ID", Staged."Source Sales Order Detail ID");
        OldLine.TestField("Impress Size Position", Staged."Size Position");
        case Staged."BC Line Type" of
            'ITEM':
                begin
                    OldLine.TestField(Type, OldLine.Type::Item);
                    OldLine.TestField("No.", Staged."BC Item No.");
                    OldLine.TestField("Variant Code", Staged."BC Variant Code");
                    if OldLine."Impress Raw SKU" <> '' then
                        OldLine.TestField("Impress Raw SKU", Staged."Source SKU");
                end;
            'CHARGE':
                begin
                    OldLine.TestField(Type, OldLine.Type::Resource);
                    OldLine.TestField("No.", Staged."Source Code");
                    Staged.TestField("Size Position", 0);
                end;
            else
                Error('Unsupported staged line type %1 during sales line recreation.', Staged."BC Line Type");
        end;
        Staged."BC Line No." := CurrentLine."Line No.";
        Staged."BC Line System ID" := CurrentLine.SystemId;
        Staged.Modify(true);
    end;

    local procedure RefreshInvoiceMapping(OldLine: Record "Sales Line"; OldID: Guid; CurrentLine: Record "Sales Line")
    var
        Line: Record "Impress Sales Doc Line Staging";
        Matcher: Codeunit "Impress Invoice Line Match";
    begin
        Line.SetRange("Sales Document Entry No.", InvoiceHeader."Entry No.");
        Line.SetRange("BC Line System ID", OldID);
        if Line.Count() > 1 then
            Error('Invoice %1 has multiple references to recreated order line %2.', InvoiceHeader."Document No.", OldLine."Line No.");
        if not Line.FindFirst() then
            exit;
        Line.TestField("Source Database", InvoiceHeader."Source Database");
        if Line."Processing Status" = Line."Processing Status"::Processed then
            Error('Invoice %1 line %2 is already processed; its posted line reference cannot be refreshed.', InvoiceHeader."Document No.", Line."Entry No.");
        Line.TestField("BC Line System ID", OldID);
        Line.TestField("BC Sales Line No.", OldLine."Line No.");
        OldLine.TestField("No.", Matcher.TargetNo(Line));
        OldLine.TestField("Variant Code", Line."BC Variant Code");
        if Matcher.IsItem(Line) then
            OldLine.TestField(Type, OldLine.Type::Item)
        else
            OldLine.TestField(Type, OldLine.Type::Resource);
        if OldLine."Impress Raw SKU" <> '' then begin
            OldLine.TestField("Impress Raw SKU", Line."Source Raw SKU No.");
            OldLine.TestField("Impress Size Position", Line."Size Position");
        end;
        if OldLine."Impress Invoice Line Entry No." <> 0 then
            OldLine.TestField("Impress Invoice Line Entry No.", Line."Entry No.");
        Line."BC Sales Line No." := CurrentLine."Line No.";
        Line."BC Line System ID" := CurrentLine.SystemId;
        Line.Modify(true);
    end;

    local procedure CheckTarget(CurrentLine: Record "Sales Line"; OldLine: Record "Sales Line")
    begin
        CurrentLine.TestField("Document Type", OldLine."Document Type");
        CurrentLine.TestField("Document No.", OldLine."Document No.");
        CurrentLine.TestField(Type, OldLine.Type);
        CurrentLine.TestField("No.", OldLine."No.");
        CurrentLine.TestField("Variant Code", OldLine."Variant Code");
    end;

    local procedure IsActiveOrder(Order: Record "Sales Header"): Boolean
    begin
        exit(not Order.IsTemporary() and (ActiveOrder <> '') and
            (Order."Document Type" = Order."Document Type"::Order) and (Order."No." = ActiveOrder));
    end;

    var
        InvoiceHeader: Record "Impress Sales Doc Hdr Staging";
        OldLines: Record "Sales Line" temporary;
        OldIDs: Dictionary of [Integer, Guid];
        ActiveOrder: Code[20];
}
