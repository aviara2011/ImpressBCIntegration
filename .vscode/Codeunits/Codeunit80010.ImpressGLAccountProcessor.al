codeunit 80010 "Impress GL Account Processor"
{
    TableNo = "Impress G/L Account Staging";

    trigger OnRun()
    begin
        ProcessGLAccountStaging(Rec);
    end;

    local procedure ProcessGLAccountStaging(var ImpressGLAccountStaging: Record "Impress G/L Account Staging")
    var
        GLAccount: Record "G/L Account";
    begin
        ImpressGLAccountStaging."Transport Status" := ImpressGLAccountStaging."Transport Status"::Processing;
        ImpressGLAccountStaging.Modify(true);

        if UpperCase(ImpressGLAccountStaging.Operation) <> 'UPSERT' then
            Error('Unsupported G/L account operation %1 for staging entry %2.', ImpressGLAccountStaging.Operation, ImpressGLAccountStaging."Entry No.");

        UpsertGLAccount(GLAccount, ImpressGLAccountStaging);

        ImpressGLAccountStaging."Transport Status" := ImpressGLAccountStaging."Transport Status"::Processed;
        ImpressGLAccountStaging."BC System ID" := GLAccount.SystemId;
        ImpressGLAccountStaging."Sent to BC DateTime" := CurrentDateTime();
        Clear(ImpressGLAccountStaging."Error Message");
        ImpressGLAccountStaging.Modify(true);
    end;

    local procedure UpsertGLAccount(var GLAccount: Record "G/L Account"; ImpressGLAccountStaging: Record "Impress G/L Account Staging")
    begin
        if not GLAccount.Get(ImpressGLAccountStaging."G/L Account No.") then begin
            GLAccount.Init();
            GLAccount.Validate("No.", ImpressGLAccountStaging."G/L Account No.");
            GLAccount.Insert(true);
        end;

        MapGLAccountFields(GLAccount, ImpressGLAccountStaging);
        GLAccount.Modify(true);
    end;

    local procedure MapGLAccountFields(var GLAccount: Record "G/L Account"; ImpressGLAccountStaging: Record "Impress G/L Account Staging")
    var
        AccountDescription: Text[250];
    begin
        AccountDescription := ImpressGLAccountStaging."Long Description";
        if AccountDescription = '' then
            AccountDescription := ImpressGLAccountStaging.Description;

        GLAccount.Validate(Name, CopyStr(AccountDescription, 1, MaxStrLen(GLAccount.Name)));
        ApplyAccountType(GLAccount, ImpressGLAccountStaging."G/L Account No.");
        GLAccount.Validate(Blocked, ImpressGLAccountStaging.Inactive);
    end;

    local procedure ApplyAccountType(var GLAccount: Record "G/L Account"; GLAccountNo: Code[20])
    var
        FirstDigit: Integer;
    begin
        if GLAccountNo = '' then
            Error('G/L account number is required to derive the BC account category.');

        if not Evaluate(FirstDigit, CopyStr(GLAccountNo, 1, 1)) then
            Error('G/L account number %1 must start with a digit to derive the BC account category.', GLAccountNo);

        if FirstDigit < 4 then
            GLAccount.Validate("Income/Balance", GLAccount."Income/Balance"::"Balance Sheet")
        else
            GLAccount.Validate("Income/Balance", GLAccount."Income/Balance"::"Income Statement");

        GLAccount.Validate("Account Type", GLAccount."Account Type"::Posting);
    end;
}
