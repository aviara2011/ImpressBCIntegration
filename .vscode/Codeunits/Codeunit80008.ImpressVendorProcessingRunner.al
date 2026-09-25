codeunit 80008 "Impress Vend Processing Runner"
{
    procedure ProcessNewVendors()
    var
        ImpressVendorStaging: Record "Impress Vendor Staging";
    begin
        ImpressVendorStaging.SetRange("Transport Status", ImpressVendorStaging."Transport Status"::New);
        while ImpressVendorStaging.FindFirst() do
            ProcessVendorStagingWithErrorHandling(ImpressVendorStaging);
    end;

    procedure ProcessVendors(var ImpressVendorStaging: Record "Impress Vendor Staging")
    var
        VendorStagingToProcess: Record "Impress Vendor Staging";
        EntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        if ImpressVendorStaging.FindSet() then
            repeat
                EntryNos.Add(ImpressVendorStaging."Entry No.");
            until ImpressVendorStaging.Next() = 0;

        foreach EntryNo in EntryNos do
            if VendorStagingToProcess.Get(EntryNo) then
                ProcessVendorStagingWithErrorHandling(VendorStagingToProcess);
    end;

    procedure ProcessErrorVendors(var ImpressVendorStaging: Record "Impress Vendor Staging")
    begin
        ImpressVendorStaging.SetRange("Transport Status", ImpressVendorStaging."Transport Status"::Error);
        ProcessVendors(ImpressVendorStaging);
    end;

    local procedure ProcessVendorStagingWithErrorHandling(ImpressVendorStaging: Record "Impress Vendor Staging")
    var
        ErrorVendorStaging: Record "Impress Vendor Staging";
        ImpressIntegrationManagement: Codeunit "Impress Integration Management";
        ImpressVendorProcessor: Codeunit "Impress Vendor Processor";
        ErrorMessage: Text;
    begin
        Clear(ImpressVendorProcessor);
        if ImpressVendorProcessor.Run(ImpressVendorStaging) then begin
            ImpressIntegrationManagement.UpdateVendorControlTotals(ImpressVendorStaging."SQL Run ID");
            Commit();
            exit;
        end;

        ErrorMessage := GetLastErrorText();
        if ErrorMessage = '' then
            ErrorMessage := StrSubstNo('Unknown error while processing Impress Vendor Staging entry %1.', ImpressVendorStaging."Entry No.");
        ClearLastError();

        if ErrorVendorStaging.Get(ImpressVendorStaging."Entry No.") then begin
            ImpressIntegrationManagement.SetVendorStagingError(ErrorVendorStaging, ErrorMessage);
            ImpressIntegrationManagement.UpdateVendorControlTotals(ErrorVendorStaging."SQL Run ID");
            Commit();
        end;
    end;
}
