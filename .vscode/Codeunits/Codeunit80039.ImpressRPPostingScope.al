codeunit 80039 "Impress RP Posting Scope"
{
    EventSubscriberInstance = Manual;

    procedure Initialize(Transaction: Record "Impress Inv Trans Staging"; Line: Record "Purchase Line")
    begin
        ActiveTransaction := Transaction;
        ActiveLine := Line;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforePurchRcptHeaderInsert', '', false, false)]
    local procedure TagReceipt(var PurchRcptHeader: Record "Purch. Rcpt. Header"; var PurchaseHeader: Record "Purchase Header")
    begin
        if PurchaseHeader."No." <> ActiveLine."Document No." then
            exit;
        PurchaseHeader.TestField(Receive, true);
        PurchaseHeader.TestField(Invoice, false);
        PurchRcptHeader."Integration Posting ID" := ActiveTransaction.SystemId;
        PurchRcptHeader."Impress Source Database" := ActiveTransaction."Source Database";
        PurchRcptHeader."Impress Source Transaction ID" := ActiveTransaction."Source Transaction ID";
        PurchRcptHeader."Impress Source Order No." := ActiveTransaction."Source Order No.";
        PurchRcptHeader."Impress Source Order Line No." := ActiveTransaction."Source Order Line No.";
        PurchRcptHeader."Impress Source SKU" := ActiveTransaction."Source SKU No.";
        PurchRcptHeader."Impress Source Size" := ActiveTransaction."Source Size";
        PurchRcptHeader."Impress Source Warehouse" := ActiveTransaction."Source Warehouse Code";
        PurchRcptHeader."Impress Order Line No." := ActiveLine."Line No.";
        PurchRcptHeader."Impress RP Account Version" := 1;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnAfterCopyToTempLines', '', false, false)]
    local procedure CheckPostingQuantities(var TempPurchLine: Record "Purchase Line" temporary; var PurchaseHeader: Record "Purchase Header")
    var
        Lines: Record "Purchase Line" temporary;
    begin
        if PurchaseHeader."No." <> ActiveLine."Document No." then
            exit;
        Lines.Copy(TempPurchLine, true);
        Lines.Reset();
        Lines.SetRange("Document Type", ActiveLine."Document Type");
        Lines.SetRange("Document No.", ActiveLine."Document No.");
        Lines.SetFilter("Qty. to Receive", '<>0');
        if Lines.Count() <> 1 then
            Error('R/P posting must receive exactly one purchase line.');
        Lines.FindFirst();
        Lines.TestField("Line No.", ActiveLine."Line No.");
        Lines.TestField("Qty. to Receive", ActiveTransaction.Quantity);
        Lines.TestField("Posting Group", ActiveLine."Posting Group");
        Lines.TestField("Gen. Bus. Posting Group", ActiveLine."Gen. Bus. Posting Group");
        Lines.TestField("Gen. Prod. Posting Group", ActiveLine."Gen. Prod. Posting Group");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnPostItemJnlLineOnAfterPrepareItemJnlLine', '', false, false)]
    local procedure TagLedger(var ItemJournalLine: Record "Item Journal Line"; PurchaseLine: Record "Purchase Line"; PurchaseHeader: Record "Purchase Header")
    var
        PersistedLine: Record "Purchase Line";
    begin
        if PurchaseHeader."No." <> ActiveLine."Document No." then
            exit;
        PurchaseLine.TestField("Line No.", ActiveLine."Line No.");
        // Purch.-Post copies lines into temporary records with new SystemIds.
        PersistedLine.Get(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.");
        PersistedLine.TestField(SystemId, ActiveLine.SystemId);
        ItemJournalLine.TestField("Inventory Posting Group", ActiveLine."Posting Group");
        ItemJournalLine.TestField("Gen. Bus. Posting Group", ActiveLine."Gen. Bus. Posting Group");
        ItemJournalLine.TestField("Gen. Prod. Posting Group", ActiveLine."Gen. Prod. Posting Group");
        ItemJournalLine."Integration Posting ID" := ActiveTransaction.SystemId;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Impress Posting Tracking", 'OnAuthorizeComponent', '', false, false)]
    local procedure AuthorizeReceipt(Journal: Record "Item Journal Line"; var Authorized: Boolean)
    begin
        if not IsNullGuid(ActiveTransaction.SystemId) and (Journal."Integration Posting ID" = ActiveTransaction.SystemId) then
            Authorized := true;
    end;

    var
        ActiveTransaction: Record "Impress Inv Trans Staging";
        ActiveLine: Record "Purchase Line";
}
