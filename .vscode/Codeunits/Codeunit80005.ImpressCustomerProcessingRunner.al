codeunit 80005 "Impress Cust Processing Runner"
{
    procedure ProcessNewCustomers()
    var
        ImpressCustomerStaging: Record "Impress Customer Staging";
    begin
        ImpressCustomerStaging.SetRange("Transport Status", ImpressCustomerStaging."Transport Status"::New);
        while ImpressCustomerStaging.FindFirst() do
            ProcessCustomerStagingWithErrorHandling(ImpressCustomerStaging);
    end;

    procedure ProcessCustomers(var ImpressCustomerStaging: Record "Impress Customer Staging")
    var
        CustomerStagingToProcess: Record "Impress Customer Staging";
        EntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        if ImpressCustomerStaging.FindSet() then
            repeat
                EntryNos.Add(ImpressCustomerStaging."Entry No.");
            until ImpressCustomerStaging.Next() = 0;

        foreach EntryNo in EntryNos do
            if CustomerStagingToProcess.Get(EntryNo) then
                ProcessCustomerStagingWithErrorHandling(CustomerStagingToProcess);
    end;

    procedure ProcessErrorCustomers(var ImpressCustomerStaging: Record "Impress Customer Staging")
    begin
        ImpressCustomerStaging.SetRange("Transport Status", ImpressCustomerStaging."Transport Status"::Error);
        ProcessCustomers(ImpressCustomerStaging);
    end;

    local procedure ProcessCustomerStagingWithErrorHandling(ImpressCustomerStaging: Record "Impress Customer Staging")
    var
        ErrorCustomerStaging: Record "Impress Customer Staging";
        ImpressIntegrationManagement: Codeunit "Impress Integration Management";
        ErrorMessage: Text;
        ImpressCustomerProcessor: Codeunit "Impress Customer Processor";
    begin
        Clear(ImpressCustomerProcessor);
        if ImpressCustomerProcessor.Run(ImpressCustomerStaging) then begin
            ImpressIntegrationManagement.UpdateCustomerControlTotals(ImpressCustomerStaging."SQL Run ID");
            Commit();
            exit;
        end;

        ErrorMessage := GetLastErrorText();
        if ErrorMessage = '' then
            ErrorMessage := StrSubstNo('Unknown error while processing Impress Customer Staging entry %1.', ImpressCustomerStaging."Entry No.");
        ClearLastError();

        if ErrorCustomerStaging.Get(ImpressCustomerStaging."Entry No.") then begin
            ImpressIntegrationManagement.SetCustomerStagingError(ErrorCustomerStaging, ErrorMessage);
            ImpressIntegrationManagement.UpdateCustomerControlTotals(ErrorCustomerStaging."SQL Run ID");
            Commit();
        end;
    end;
}
