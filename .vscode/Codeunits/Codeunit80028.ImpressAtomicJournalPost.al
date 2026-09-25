codeunit 80028 "Impress Atomic Journal Post"
{
    EventSubscriberInstance = Manual;

    [CommitBehavior(CommitBehavior::Error)]
    procedure PostComponents(PostingID: Guid)
    var
        Component: Record "Impress Journal Component";
        Journal: Record "Item Journal Line";
        PostBatch: Codeunit "Item Jnl.-Post Batch";
        Tracking: Codeunit "Impress Posting Tracking";
    begin
        if Tracking.HasPostedEvidence(PostingID) then
            Error('Integration Posting ID %1 already has posted evidence. Reconcile before posting.', PostingID);
        Component.SetRange("Integration Posting ID", PostingID);
        Component.FindSet();
        repeat
            Journal.Reset();
            if not Journal.GetBySystemId(Component."Journal System ID") then
                Error('Preview component is missing. Recreate the preview for %1.', PostingID);
            Journal.TestField("Integration Posting ID", PostingID);
            Journal.TestField("Entry Type", Component."Entry Type");
            Journal.TestField(Quantity, Component.Quantity);
            // Refresh standard BC item cost immediately before the positive receipt.
            // No source cost, fixed application, or later custom cost correction.
            if Journal."Entry Type" = Journal."Entry Type"::"Positive Adjmt." then begin
                RefreshPositiveCost(Journal);
                Journal.Modify(true);
            end;
            ActivePostingID := PostingID;
            ActiveJournalID := Journal.SystemId;
            Journal.SetRecFilter();
            Journal.SetRange("Integration Posting ID", PostingID);
            Clear(PostBatch);
            PostBatch.SetSuppressCommit(true);
            PostBatch.Run(Journal);
            Clear(ActiveJournalID);
        until Component.Next() = 0;
        Clear(ActivePostingID);
    end;

    procedure RefreshPositiveCost(var Journal: Record "Item Journal Line")
    var
        Item: Record Item;
    begin
        Item.Get(Journal."Item No.");
        // BC maintains Item.Unit Cost as average inventory cost for non-standard items.
        // Standard-cost validation remains BC-owned. Never read an Impress cost field.
        Journal.Validate("Unit Amount", Item."Unit Cost" * Journal."Qty. per Unit of Measure");
        Journal.Validate("Unit Cost", Item."Unit Cost" * Journal."Qty. per Unit of Measure");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Impress Posting Tracking", 'OnAuthorizeComponent', '', false, false)]
    local procedure AuthorizeComponent(Journal: Record "Item Journal Line"; var Authorized: Boolean)
    begin
        Authorized := (not IsNullGuid(ActivePostingID)) and
            (Journal."Integration Posting ID" = ActivePostingID) and (Journal.SystemId = ActiveJournalID);
    end;

    var
        ActivePostingID: Guid;
        ActiveJournalID: Guid;
}
