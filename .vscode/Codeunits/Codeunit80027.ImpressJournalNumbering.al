codeunit 80027 "Impress Journal Numbering"
{
    Permissions = tabledata "Impress Journal Reservation" = ri,
                  tabledata "Impress Journal Component" = rim;

    procedure InsertWithReservedNumber(var Journal: Record "Item Journal Line"; SeriesCode: Code[20])
    var
        Reservation: Record "Impress Journal Reservation";
        Component: Record "Impress Journal Component";
        NoSeries: Codeunit "No. Series";
        ComponentNo: Integer;
    begin
        Journal.TestField("Integration Posting ID");
        Journal.TestField("Posting Date");
        if SeriesCode = '' then
            Error('A journal batch No. Series is required for Integration Posting ID %1.', Journal."Integration Posting ID");
        // Reserve once at preparation, including Preview. Deletion does not recycle this number.
        Journal.Validate("Document No.", NoSeries.GetNextNo(SeriesCode, Journal."Posting Date"));
        Journal.TestField("Document No.");
        Clear(Journal."Posting No. Series");
        Journal.Insert(true);
        Component.SetRange("Integration Posting ID", Journal."Integration Posting ID");
        if Component.FindLast() then
            ComponentNo := Component."Component No.";
        Component.Init();
        Component."Integration Posting ID" := Journal."Integration Posting ID";
        Component."Component No." := ComponentNo + 1;
        Component."Journal System ID" := Journal.SystemId;
        Component."No. Series" := SeriesCode;
        Component."Document No." := Journal."Document No.";
        Component."Posting Date" := Journal."Posting Date";
        Component."Entry Type" := Journal."Entry Type";
        Component.Quantity := Journal.Quantity;
        Component.Insert(true);
        // Retain the original primary logical reference and legacy reservation schema.
        if Reservation.Get(Journal."Integration Posting ID") then
            exit;
        Reservation."Integration Posting ID" := Journal."Integration Posting ID";
        Reservation."Journal System ID" := Journal.SystemId;
        Reservation."No. Series" := SeriesCode;
        Reservation."Document No." := Journal."Document No.";
        Reservation."Posting Date" := Journal."Posting Date";
        Reservation.Insert(true);
    end;

    procedure ValidateReservation(Journal: Record "Item Journal Line"; SeriesCode: Code[20])
    var
        Reservation: Record "Impress Journal Reservation";
        Component: Record "Impress Journal Component";
    begin
        Component.SetRange("Integration Posting ID", Journal."Integration Posting ID");
        Component.SetRange("Journal System ID", Journal.SystemId);
        if Component.FindFirst() then begin
            Component.TestField("Document No.", Journal."Document No.");
            Component.TestField("Posting Date", Journal."Posting Date");
            Component.TestField("No. Series", SeriesCode);
            Journal.TestField("Posting No. Series", '');
            exit;
        end;
        if not Reservation.Get(Journal."Integration Posting ID") then
            Error('Integration Posting ID %1 has no journal number reservation. Delete this legacy unposted preparation and run Preview or Process Transaction again.',
                Journal."Integration Posting ID");
        if (Reservation."Journal System ID" <> Journal.SystemId) or
            (Reservation."Document No." <> Journal."Document No.") or
            (Reservation."Posting Date" <> Journal."Posting Date") or
            (Reservation."No. Series" <> SeriesCode) or
            (Journal."Posting No. Series" <> '') then
            Error('Integration Posting ID %1: the prepared journal number/date/series was changed. Expected Document No. %2, Posting Date %3, No. Series %4 and no separate Posting No. Series; actual %5, %6, %7 / %8. Recreate the preview if the configuration must change.',
                Journal."Integration Posting ID", Reservation."Document No.", Reservation."Posting Date", Reservation."No. Series",
                Journal."Document No.", Journal."Posting Date", SeriesCode, Journal."Posting No. Series");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Batch", 'OnBeforeValidateDocumentNo', '', false, false)]
    local procedure UseReservedNumber(var ItemJournalLine: Record "Item Journal Line"; var ItemJournalBatch: Record "Item Journal Batch"; var IsHandled: Boolean)
    begin
        if not HasReservation(ItemJournalLine) then
            exit;
        ValidateReservation(ItemJournalLine, ItemJournalBatch."No. Series");
        // The standard No. Series already consumed this exact number for this GUID/line.
        // All other journals keep the unmodified standard batch numbering behavior.
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Batch", 'OnBeforeConstructPostingNumber', '', false, false)]
    local procedure PreserveReservedNumber(var ItemJournalLine: Record "Item Journal Line"; ItemJnlBatch: Record "Item Journal Batch"; var LastDocNo: Code[20]; var LastPostedDocNo: Code[20]; var IsHandled: Boolean)
    begin
        if not HasReservation(ItemJournalLine) then
            exit;
        ValidateReservation(ItemJournalLine, ItemJnlBatch."No. Series");
        LastDocNo := ItemJournalLine."Document No.";
        LastPostedDocNo := ItemJournalLine."Document No.";
        IsHandled := true;
    end;

    local procedure HasReservation(Journal: Record "Item Journal Line"): Boolean
    var
        Reservation: Record "Impress Journal Reservation";
    begin
        if IsNullGuid(Journal."Integration Posting ID") then
            exit(false);
        exit(Reservation.Get(Journal."Integration Posting ID"));
    end;
}
