codeunit 80024 "Impress Posting Tracking"
{
    Permissions = tabledata "Impress Posting Link" = rim;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnBeforeRunWithCheck', '', false, false)]
    local procedure PreventDuplicatePosting(var ItemJournalLine: Record "Item Journal Line"; CalledFromAdjustment: Boolean)
    var
        Component: Record "Impress Journal Component";
        Authorized: Boolean;
    begin
        if CalledFromAdjustment or ItemJournalLine.Adjustment then
            exit;
        OnAuthorizeComponent(ItemJournalLine, Authorized);
        if Authorized then
            exit;
        if HasPostedEvidence(ItemJournalLine."Integration Posting ID") then
            Error('Integration Posting ID %1 already has posted evidence. Use Process Transaction on the staging pair to reconcile it; do not post this journal again.',
                ItemJournalLine."Integration Posting ID");
        Component.SetRange("Integration Posting ID", ItemJournalLine."Integration Posting ID");
        if not Component.IsEmpty() then
            Error('Post this prepared transaction through Process Transaction so all components post atomically. Integration Posting ID %1.', ItemJournalLine."Integration Posting ID");
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAuthorizeComponent(Journal: Record "Item Journal Line"; var Authorized: Boolean)
    begin
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnBeforeInsertItemLedgEntry', '', false, false)]
    local procedure CopyJournalPostingID(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
    begin
        // Set even an empty GUID: never inherit the identity of an applied entry.
        ItemLedgerEntry."Integration Posting ID" := ItemJournalLine."Integration Posting ID";
        ItemLedgerEntry."Impress Invoice Line Entry No." := ItemJournalLine."Impress Invoice Line Entry No.";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Ledger Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure LinkItemEntry(var Rec: Record "Item Ledger Entry"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        AddLink(Rec."Integration Posting ID", Database::"Item Ledger Entry", Rec."Entry No.", Rec.SystemId, Rec."Document No.", Rec."Posting Date");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Value Entry", 'OnBeforeInsertEvent', '', false, false)]
    local procedure CopyValuePostingID(var Rec: Record "Value Entry"; RunTrigger: Boolean)
    var
        ItemEntry: Record "Item Ledger Entry";
    begin
        if Rec.IsTemporary() then
            exit;
        // Also covers transfer receipt entries and later standard cost adjustment.
        Clear(Rec."Integration Posting ID");
        if ItemEntry.Get(Rec."Item Ledger Entry No.") then
            Rec."Integration Posting ID" := ItemEntry."Integration Posting ID";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Value Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure LinkValueEntry(var Rec: Record "Value Entry"; RunTrigger: Boolean)
    var
        Relation: Record "G/L - Item Ledger Relation";
        GLEntry: Record "G/L Entry";
    begin
        if Rec.IsTemporary() then
            exit;
        AddLink(Rec."Integration Posting ID", Database::"Value Entry", Rec."Entry No.", Rec.SystemId, Rec."Document No.", Rec."Posting Date");
        if IsNullGuid(Rec."Integration Posting ID") then
            exit;
        // Immediate cost posting can insert G/L relations before the Value Entry itself.
        Relation.SetRange("Value Entry No.", Rec."Entry No.");
        if Relation.FindSet() then
            repeat
                if GLEntry.Get(Relation."G/L Entry No.") then
                    AddLink(Rec."Integration Posting ID", Database::"G/L Entry", GLEntry."Entry No.", GLEntry.SystemId, GLEntry."Document No.", GLEntry."Posting Date");
            until Relation.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Table, Database::"G/L - Item Ledger Relation", 'OnAfterInsertEvent', '', false, false)]
    local procedure LinkInventoryGL(var Rec: Record "G/L - Item Ledger Relation"; RunTrigger: Boolean)
    var
        ValueEntry: Record "Value Entry";
        GLEntry: Record "G/L Entry";
    begin
        if Rec.IsTemporary() then
            exit;
        if not ValueEntry.Get(Rec."Value Entry No.") then
            exit;
        if IsNullGuid(ValueEntry."Integration Posting ID") then
            exit;
        if GLEntry.Get(Rec."G/L Entry No.") then
            AddLink(ValueEntry."Integration Posting ID", Database::"G/L Entry", GLEntry."Entry No.", GLEntry.SystemId, GLEntry."Document No.", GLEntry."Posting Date");
    end;

    procedure HasPostedEvidence(PostingID: Guid): Boolean
    var
        Receipt: Record "Purch. Rcpt. Header";
        ItemEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        Link: Record "Impress Posting Link";
    begin
        if IsNullGuid(PostingID) then
            exit(false);
        Receipt.SetRange("Integration Posting ID", PostingID);
        if not Receipt.IsEmpty() then
            exit(true);
        Link.SetRange("Integration Posting ID", PostingID);
        if not Link.IsEmpty() then
            exit(true);
        ItemEntry.SetCurrentKey("Integration Posting ID");
        ItemEntry.SetRange("Integration Posting ID", PostingID);
        if not ItemEntry.IsEmpty() then
            exit(true);
        ValueEntry.SetCurrentKey("Integration Posting ID");
        ValueEntry.SetRange("Integration Posting ID", PostingID);
        exit(not ValueEntry.IsEmpty());
    end;

    procedure AddLink(PostingID: Guid; TableID: Integer; EntryNo: Integer; EntrySystemID: Guid; DocumentNo: Code[20]; PostingDate: Date)
    var
        Link: Record "Impress Posting Link";
    begin
        if IsNullGuid(PostingID) then
            exit;
        if Link.Get(PostingID, TableID, EntryNo) then begin
            Link.TestField("Entry System ID", EntrySystemID);
            Link.TestField("Document No.", DocumentNo);
            Link.TestField("Posting Date", PostingDate);
            exit;
        end;
        Link.Init();
        Link."Integration Posting ID" := PostingID;
        Link."Table ID" := TableID;
        Link."Entry No." := EntryNo;
        Link."Entry System ID" := EntrySystemID;
        Link."Document No." := DocumentNo;
        Link."Posting Date" := PostingDate;
        Link.Insert(true);
    end;
}
