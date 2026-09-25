codeunit 80014 "Impress Opening Inventory Mgt"
{
    TableNo = "Job Queue Entry";
    Permissions = tabledata "Item Journal Line" = RIMD;

    trigger OnRun()
    var
        ErrorText: Text;
    begin
        CurrentProcessingPhase := 'RunID discovery';
        Clear(CurrentRunID);
        if TryProcessPendingRuns() then
            exit;

        // GetLastErrorText must be the first call after the failed TryFunction.
        ErrorText := GetLastErrorText();
        ClearLastError();
        if ErrorText = '' then
            ErrorText := 'The opening inventory run failed without an error message.';
        ErrorText := StrSubstNo('%1: %2', CurrentProcessingPhase, ErrorText);
        WriteRunDiagnostic(CurrentRunID, ErrorText);
        Commit();
        Error(ErrorText);
    end;

    [TryFunction]
    local procedure TryProcessPendingRuns()
    begin
        ProcessPendingRuns();
    end;

    procedure ProcessPendingRuns()
    var
        Staging: Record "Impress Opening Inventory";
        RunIDs: List of [Guid];
        RunID: Guid;
    begin
        CurrentProcessingPhase := 'RunID discovery';
        Staging.SetCurrentKey("Send Status", "Run ID", "BC Line No.");
        Staging.SetFilter("Send Status", '%1|%2', Staging."Send Status"::Pending, Staging."Send Status"::Error);
        if Staging.FindSet() then
            repeat
                if not RunIDs.Contains(Staging."Run ID") then
                    RunIDs.Add(Staging."Run ID");
            until Staging.Next() = 0;
        foreach RunID in RunIDs do
            ProcessRun(RunID);
    end;

    procedure ProcessRun(RunID: Guid)
    var
        Staging: Record "Impress Opening Inventory";
        StagingToProcess: Record "Impress Opening Inventory";
        EntryNos: List of [Integer];
        EntryNo: Integer;
        SetupError: Text;
    begin
        CurrentRunID := RunID;
        CurrentProcessingPhase := 'PrepareRun';
        if IsNullGuid(RunID) then
            Error('Run ID must be specified.');
        if not PrepareRun(RunID, SetupError) then begin
            // Preserve the TryFunction error before clearing it or touching the database.
            SetupError := GetLastErrorText();
            ClearLastError();
            if SetupError = '' then
                SetupError := 'PrepareRun failed without an error message.';
            SetupError := StrSubstNo('%1: %2', CurrentProcessingPhase, SetupError);
            MarkRunError(RunID, SetupError);
            Commit();
            exit;
        end;

        // PrepareRun assigns the journal setup to the staging rows. A Boolean
        // Codeunit.Run call cannot start while that write transaction is open.
        Commit();

        CurrentProcessingPhase := 'staging-row discovery';
        Staging.SetCurrentKey("Run ID", "BC Line No.");
        Staging.SetRange("Run ID", RunID);
        Staging.SetFilter("Send Status", '%1|%2', Staging."Send Status"::Pending, Staging."Send Status"::Error);
        if Staging.FindSet() then
            repeat
                EntryNos.Add(Staging."Entry No.");
            until Staging.Next() = 0;
        foreach EntryNo in EntryNos do
            if StagingToProcess.Get(EntryNo) then begin
                CurrentProcessingPhase := StrSubstNo('staging-row processing (Entry No. %1)', EntryNo);
                ProcessLineWithErrorHandling(StagingToProcess);
            end;
        CurrentProcessingPhase := 'Integration Control update';
        UpdateControlTotals(RunID);
    end;

    procedure RetryRunErrors(RunID: Guid)
    var
        Staging: Record "Impress Opening Inventory";
    begin
        Staging.SetRange("Run ID", RunID);
        Staging.SetRange("Send Status", Staging."Send Status"::Error);
        ResetToPending(Staging);
        ProcessRun(RunID);
    end;

    procedure ResetToPending(var Staging: Record "Impress Opening Inventory")
    begin
        if Staging.FindSet(true) then
            repeat
                if Staging."Send Status" <> Staging."Send Status"::Processed then begin
                    Staging."Send Status" := Staging."Send Status"::Pending;
                    Clear(Staging."Error Message");
                    Staging.Modify(true);
                end;
            until Staging.Next() = 0;
    end;

    [TryFunction]
    local procedure PrepareRun(RunID: Guid; var SetupError: Text)
    var
        Defaults: Record "Impress Defaults";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        Staging: Record "Impress Opening Inventory";
    begin
        CurrentProcessingPhase := 'journal setup validation';
        if not Defaults.Get() then
            Error('Impress Defaults must be configured before processing opening inventory.');
        if Defaults."Opening Inv. Journal Template" = '' then
            Error('Opening Inventory Journal Template must be configured on Impress Defaults.');
        if Defaults."Opening Inv. Journal Batch" = '' then
            Error('Opening Inventory Journal Batch must be configured on Impress Defaults.');
        if Defaults."Open Inv. Gen. Bus. Group" = '' then
            Error('Gen. Bus. Posting Group (Open Inv.) must be configured on Impress Defaults.');
        if Defaults."Category Dimension Code" = '' then
            Error('Category Dimension must be configured on Impress Defaults.');
        if not ItemJournalTemplate.Get(Defaults."Opening Inv. Journal Template") then
            Error('Item Journal Template %1 does not exist.', Defaults."Opening Inv. Journal Template");
        if not ItemJournalBatch.Get(Defaults."Opening Inv. Journal Template", Defaults."Opening Inv. Journal Batch") then
            Error('Item Journal Batch %1/%2 does not exist.', Defaults."Opening Inv. Journal Template", Defaults."Opening Inv. Journal Batch");

        CurrentProcessingPhase := 'batch isolation';
        ItemJournalLine.SetRange("Journal Template Name", Defaults."Opening Inv. Journal Template");
        ItemJournalLine.SetRange("Journal Batch Name", Defaults."Opening Inv. Journal Batch");
        if ItemJournalLine.FindSet() then
            repeat
                if ItemJournalLine."Impress Opening Run ID" <> RunID then
                    Error(
                        'Item Journal Batch %1/%2 contains unrelated line %3. Post, move, or remove unrelated lines before processing Run ID %4.',
                        Defaults."Opening Inv. Journal Template", Defaults."Opening Inv. Journal Batch", ItemJournalLine."Line No.", RunID);
            until ItemJournalLine.Next() = 0;

        CurrentProcessingPhase := 'PrepareRun staging update';
        Staging.SetRange("Run ID", RunID);
        Staging.SetFilter("Send Status", '%1|%2', Staging."Send Status"::Pending, Staging."Send Status"::Error);
        if Staging.FindSet(true) then
            repeat
                Staging."Journal Template Name" := Defaults."Opening Inv. Journal Template";
                Staging."Journal Batch Name" := Defaults."Opening Inv. Journal Batch";
                Staging.Modify(true);
            until Staging.Next() = 0;
        Clear(SetupError);
    end;

    local procedure ProcessLineWithErrorHandling(Staging: Record "Impress Opening Inventory")
    var
        ErrorStaging: Record "Impress Opening Inventory";
        LineProcessor: Codeunit "Impress Opening Inv. Line";
        ErrorText: Text;
    begin
        Clear(LineProcessor);
        if LineProcessor.Run(Staging) then begin
            Commit();
            exit;
        end;
        ErrorText := GetLastErrorText();
        ClearLastError();
        if ErrorText = '' then
            ErrorText := StrSubstNo('Unknown error processing Run ID %1, BC Line No. %2.', Staging."Run ID", Staging."BC Line No.");
        if ErrorStaging.Get(Staging."Entry No.") then begin
            ErrorStaging."Send Status" := ErrorStaging."Send Status"::Error;
            ErrorStaging."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(ErrorStaging."Error Message"));
            ErrorStaging."Processed Date Time" := CurrentDateTime();
            ErrorStaging.Modify(true);
            Commit();
        end;
    end;

    local procedure MarkRunError(RunID: Guid; ErrorText: Text)
    var
        Staging: Record "Impress Opening Inventory";
    begin
        if ErrorText = '' then
            ErrorText := 'Opening inventory processing failed without an error message.';
        Staging.SetRange("Run ID", RunID);
        Staging.SetFilter("Send Status", '%1|%2', Staging."Send Status"::Pending, Staging."Send Status"::Error);
        if Staging.FindSet(true) then
            repeat
                Staging."Send Status" := Staging."Send Status"::Error;
                Staging."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(Staging."Error Message"));
                Staging."Processed Date Time" := CurrentDateTime();
                Staging.Modify(true);
            until Staging.Next() = 0;
        UpdateControlTotals(RunID);
    end;

    local procedure WriteRunDiagnostic(RunID: Guid; ErrorText: Text)
    var
        Staging: Record "Impress Opening Inventory";
        IntegrationControl: Record "Impress Integration Control";
    begin
        if not IsNullGuid(RunID) then
            Staging.SetRange("Run ID", RunID);
        Staging.SetFilter("Send Status", '%1|%2', Staging."Send Status"::Pending, Staging."Send Status"::Error);
        if Staging.FindSet(true) then
            repeat
                Staging."Send Status" := Staging."Send Status"::Error;
                Staging."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(Staging."Error Message"));
                Staging."Processed Date Time" := CurrentDateTime();
                Staging.Modify(false);
            until Staging.Next() = 0;

        if IsNullGuid(RunID) then
            exit;
        IntegrationControl.SetRange("Process Name", 'OPENING INVENTORY');
        IntegrationControl.SetRange("SQL Run Guid", RunID);
        if IntegrationControl.FindSet(true) then
            repeat
                IntegrationControl."Run Status" := IntegrationControl."Run Status"::Error;
                IntegrationControl."Run Message" := CopyStr(ErrorText, 1, MaxStrLen(IntegrationControl."Run Message"));
                IntegrationControl.Modify(false);
            until IntegrationControl.Next() = 0;
    end;

    local procedure UpdateControlTotals(RunID: Guid)
    var
        IntegrationControl: Record "Impress Integration Control";
        Staging: Record "Impress Opening Inventory";
        StagedCount: Integer;
        ProcessedCount: Integer;
        FailedCount: Integer;
    begin
        if IsNullGuid(RunID) then
            exit;
        Staging.SetRange("Run ID", RunID);
        if Staging.FindSet() then
            repeat
                StagedCount += 1;
                case Staging."Send Status" of
                    Staging."Send Status"::Processed, Staging."Send Status"::Ignored: ProcessedCount += 1;
                    Staging."Send Status"::Error: FailedCount += 1;
                end;
            until Staging.Next() = 0;
        IntegrationControl.SetRange("Process Name", 'OPENING INVENTORY');
        IntegrationControl.SetRange("SQL Run Guid", RunID);
        if IntegrationControl.FindSet(true) then
            repeat
                IntegrationControl."Records Staged" := StagedCount;
                IntegrationControl."Records Sent To BC" := ProcessedCount;
                IntegrationControl."Records Processed In BC" := ProcessedCount;
                IntegrationControl."Records Failed" := FailedCount;
                IntegrationControl.Difference := StagedCount - ProcessedCount;
                if FailedCount > 0 then begin
                    IntegrationControl."Run Status" := IntegrationControl."Run Status"::Error;
                    IntegrationControl."Run Message" := StrSubstNo('%1 opening inventory line(s) failed; %2 processed.', FailedCount, ProcessedCount);
                end else
                    if (StagedCount > 0) and (StagedCount = ProcessedCount) then begin
                        IntegrationControl."Run Status" := IntegrationControl."Run Status"::Success;
                        IntegrationControl."Run Message" := StrSubstNo('%1 opening inventory line(s) created successfully.', ProcessedCount);
                    end;
                IntegrationControl.Modify(true);
            until IntegrationControl.Next() = 0;
    end;

    var
        CurrentProcessingPhase: Text;
        CurrentRunID: Guid;
}
