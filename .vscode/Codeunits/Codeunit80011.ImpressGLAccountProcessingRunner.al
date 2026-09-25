codeunit 80011 "Impress GL Processing Runner"
{
    procedure ProcessNewGLAccounts()
    var
        ImpressGLAccountStaging: Record "Impress G/L Account Staging";
    begin
        ImpressGLAccountStaging.SetRange("Transport Status", ImpressGLAccountStaging."Transport Status"::New);
        while ImpressGLAccountStaging.FindFirst() do
            ProcessGLAccountStagingWithErrorHandling(ImpressGLAccountStaging);
    end;

    procedure ProcessGLAccounts(var ImpressGLAccountStaging: Record "Impress G/L Account Staging")
    var
        GLAccountStagingToProcess: Record "Impress G/L Account Staging";
        EntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        if ImpressGLAccountStaging.FindSet() then
            repeat
                EntryNos.Add(ImpressGLAccountStaging."Entry No.");
            until ImpressGLAccountStaging.Next() = 0;

        foreach EntryNo in EntryNos do
            if GLAccountStagingToProcess.Get(EntryNo) then
                ProcessGLAccountStagingWithErrorHandling(GLAccountStagingToProcess);
    end;

    procedure ProcessErrorGLAccounts(var ImpressGLAccountStaging: Record "Impress G/L Account Staging")
    begin
        ImpressGLAccountStaging.SetRange("Transport Status", ImpressGLAccountStaging."Transport Status"::Error);
        ProcessGLAccounts(ImpressGLAccountStaging);
    end;

    local procedure ProcessGLAccountStagingWithErrorHandling(ImpressGLAccountStaging: Record "Impress G/L Account Staging")
    var
        ErrorGLAccountStaging: Record "Impress G/L Account Staging";
        ImpressIntegrationManagement: Codeunit "Impress Integration Management";
        ImpressGLAccountProcessor: Codeunit "Impress GL Account Processor";
        ErrorMessage: Text;
    begin
        Clear(ImpressGLAccountProcessor);
        if ImpressGLAccountProcessor.Run(ImpressGLAccountStaging) then begin
            ImpressIntegrationManagement.UpdateGLAccountControlTotals(ImpressGLAccountStaging."SQL Run ID");
            Commit();
            exit;
        end;

        ErrorMessage := GetLastErrorText();
        if ErrorMessage = '' then
            ErrorMessage := StrSubstNo('Unknown error while processing Impress G/L Account Staging entry %1.', ImpressGLAccountStaging."Entry No.");
        ClearLastError();

        if ErrorGLAccountStaging.Get(ImpressGLAccountStaging."Entry No.") then begin
            ImpressIntegrationManagement.SetGLAccountStagingError(ErrorGLAccountStaging, ErrorMessage);
            ImpressIntegrationManagement.UpdateGLAccountControlTotals(ErrorGLAccountStaging."SQL Run ID");
            Commit();
        end;
    end;
}
