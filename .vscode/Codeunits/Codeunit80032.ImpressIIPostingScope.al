codeunit 80032 "Impress II Posting Scope"
{
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnBeforeCheckShipmentDateBeforeWorkDate', '', false, false)]
    local procedure SuppressHistoricalShipmentDateMessage(var SalesLine: Record "Sales Line"; xSalesLine: Record "Sales Line"; var HasBeenShown: Boolean; var IsHandled: Boolean)
    begin
        // Header validation can recreate line buffers without HideValidationDialog.
        // Suppress only this informational message for the active integration order.
        if (ActiveOrder <> '') and
           (SalesLine."Document Type" = SalesLine."Document Type"::Order) and
           (SalesLine."Document No." = ActiveOrder)
        then
            IsHandled := true;
    end;

    procedure Initialize(PostingID: Guid; OrderNo: Code[20])
    begin
        ActiveID := PostingID;
        ActiveOrder := OrderNo;
        HaveSalesTaxLines := false;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforeCalculateSalesTax', '', false, false)]
    local procedure CaptureSalesTaxLines(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; var SalesTaxAmountLine: Record "Sales Tax Amount Line"; var LocalwasProcessed: Boolean; CommitIsSuppressed: Boolean)
    begin
        if (SalesHeader."Integration Posting ID" <> ActiveID) or (SalesHeader."No." <> ActiveOrder) then
            exit;
        // Share BC's invoice-quantity buffer; standard calculation populates it next.
        CalculatedSalesLines.Copy(SalesLine, true);
        HaveSalesTaxLines := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesLines', '', false, false)]
    local procedure ValidateCalculatedTax(var SalesHeader: Record "Sales Header"; var TempSalesLineGlobal: Record "Sales Line" temporary; var TempVATAmountLine: Record "VAT Amount Line" temporary; var EverythingInvoiced: Boolean)
    var
        Header: Record "Impress Sales Doc Hdr Staging";
        TaxResolver: Codeunit "Impress Tax Resolver";
        VATLines: Record "VAT Amount Line" temporary;
        CalculatedTax: Decimal;
    begin
        if (SalesHeader."Integration Posting ID" <> ActiveID) or (SalesHeader."No." <> ActiveOrder) then
            exit;
        Header.GetBySystemId(ActiveID);
        if HaveSalesTaxLines then begin
            CalculatedSalesLines.Reset();
            CalculatedSalesLines.SetRange("Document Type", SalesHeader."Document Type");
            CalculatedSalesLines.SetRange("Document No.", SalesHeader."No.");
            if CalculatedSalesLines.FindSet() then
                repeat
                    CalculatedTax += CalculatedSalesLines."Amount Including VAT" - CalculatedSalesLines.Amount;
                until CalculatedSalesLines.Next() = 0;
        end else begin
            VATLines.Copy(TempVATAmountLine, true);
            VATLines.Reset();
            if VATLines.FindSet() then
                repeat
                    CalculatedTax += VATLines."VAT Amount";
                until VATLines.Next() = 0;
        end;
        // BC has calculated tax, but has not posted the document lines yet.
        TaxResolver.CheckTaxDifference(CalculatedTax, Header."Tax Total", SalesHeader."Currency Code", SalesHeader."Prices Including VAT");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnPostItemJnlLineOnAfterPrepareItemJnlLine', '', false, false)]
    local procedure TagItemJournal(var ItemJournalLine: Record "Item Journal Line"; SalesLine: Record "Sales Line"; SalesHeader: Record "Sales Header")
    begin
        if (SalesHeader."Integration Posting ID" <> ActiveID) or (SalesHeader."No." <> ActiveOrder) then
            exit;
        SalesLine.TestField("Integration Posting ID", ActiveID);
        SalesLine.TestField("Impress Invoice Line Entry No.");
        ItemJournalLine."Integration Posting ID" := ActiveID;
        ItemJournalLine."Impress Invoice Line Entry No." := SalesLine."Impress Invoice Line Entry No.";
        ActiveLineEntry := SalesLine."Impress Invoice Line Entry No.";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Impress Posting Tracking", 'OnAuthorizeComponent', '', false, false)]
    local procedure AuthorizeInvoiceLine(Journal: Record "Item Journal Line"; var Authorized: Boolean)
    begin
        if IsNullGuid(ActiveID) then
            exit;
        if (Journal."Integration Posting ID" = ActiveID) and
            (Journal."Impress Invoice Line Entry No." = ActiveLineEntry) and (ActiveLineEntry <> 0) then
            Authorized := true;
    end;

    var
        ActiveID: Guid;
        ActiveOrder: Code[20];
        ActiveLineEntry: BigInteger;
        CalculatedSalesLines: Record "Sales Line" temporary;
        HaveSalesTaxLines: Boolean;
}
