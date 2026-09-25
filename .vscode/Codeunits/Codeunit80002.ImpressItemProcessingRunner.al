codeunit 80002 "Impress Item Processing Runner"
{
    procedure ProcessNewItems()
    var
        ImpressItemStaging: Record "Impress Item Staging";
    begin
        ImpressItemStaging.SetRange(Status, ImpressItemStaging.Status::New);
        while ImpressItemStaging.FindFirst() do
            ProcessItemStagingWithErrorHandling(ImpressItemStaging);
    end;

    procedure ProcessItems(var ImpressItemStaging: Record "Impress Item Staging")
    var
        ItemStagingToProcess: Record "Impress Item Staging";
        EntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        if ImpressItemStaging.FindSet() then
            repeat
                EntryNos.Add(ImpressItemStaging."Entry No.");
            until ImpressItemStaging.Next() = 0;

        foreach EntryNo in EntryNos do
            if ItemStagingToProcess.Get(EntryNo) then
                ProcessItemStagingWithErrorHandling(ItemStagingToProcess);
    end;

    procedure ProcessErrorItems(var ImpressItemStaging: Record "Impress Item Staging")
    begin
        ImpressItemStaging.SetRange(Status, ImpressItemStaging.Status::Error);
        ProcessItems(ImpressItemStaging);
    end;

    local procedure ProcessItemStagingWithErrorHandling(ImpressItemStaging: Record "Impress Item Staging")
    var
        ErrorItemStaging: Record "Impress Item Staging";
        ImpressIntegrationManagement: Codeunit "Impress Integration Management";
        ErrorMessage: Text;
        ImpressItemProcessor: Codeunit "Impress Item Processor";
    begin
        Clear(ImpressItemProcessor);
        if ImpressItemProcessor.Run(ImpressItemStaging) then begin
            ImpressIntegrationManagement.UpdateItemControlTotals(ImpressItemStaging."SQL Run ID");
            Commit();
            exit;
        end;

        ErrorMessage := GetLastErrorText();
        if ErrorMessage = '' then
            ErrorMessage := StrSubstNo('Unknown error while processing Impress Item Staging entry %1.', ImpressItemStaging."Entry No.");
        ClearLastError();

        if ErrorItemStaging.Get(ImpressItemStaging."Entry No.") then begin
            ImpressIntegrationManagement.SetItemStagingError(ErrorItemStaging, ErrorMessage);
            ImpressIntegrationManagement.UpdateItemControlTotals(ErrorItemStaging."SQL Run ID");
            Commit();
        end;
    end;
}
