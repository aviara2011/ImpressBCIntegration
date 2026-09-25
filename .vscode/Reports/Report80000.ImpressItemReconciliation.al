report 80000 "Impress Item Reconciliation"
{
    ApplicationArea = All;
    Caption = 'Impress Item Reconciliation';
    UsageCategory = ReportsAndAnalysis;
    DefaultRenderingLayout = ItemReconciliationRdlc;

    dataset
    {
        dataitem(Run; Integer)
        {
            DataItemTableView = sorting(Number);

            column(SQL_Run_ID; SQLRunID) { }
            column(Staging_Record_Count; StagingRecordCount) { }
            column(Staged_Item_Count; StagedItemCount) { }
            column(Processed_Record_Count; ProcessedRecordCount) { }
            column(Error_Record_Count; ErrorRecordCount) { }
            column(BC_Item_Count; BCItemCount) { }
            column(Difference_Count; DifferenceCount) { }

            trigger OnPreDataItem()
            begin
                BuildRunIDList();
                SetRange(Number, 1, RunIDs.Count());
            end;

            trigger OnAfterGetRecord()
            begin
                RunIDs.Get(Number, SQLRunID);
                CalculateRunTotals(SQLRunID);
                if ShowDifferencesOnly and (DifferenceCount = 0) then
                    CurrReport.Skip();
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';

                    field(SQLRunIDFilter; SQLRunIDFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'SQL Run ID Filter';
                        ToolTip = 'Specifies the SQL Run ID filter to use for item reconciliation. Leave blank to include all runs.';
                    }
                    field(RunStartDate; RunStartDate)
                    {
                        ApplicationArea = All;
                        Caption = 'Run Start Date';
                        ToolTip = 'Specifies the first integration control run date to include. Leave blank to include earlier runs.';
                    }
                    field(RunEndDate; RunEndDate)
                    {
                        ApplicationArea = All;
                        Caption = 'Run End Date';
                        ToolTip = 'Specifies the last integration control run date to include. Leave blank to include later runs.';
                    }
                    field(ShowDifferencesOnly; ShowDifferencesOnly)
                    {
                        ApplicationArea = All;
                        Caption = 'Show Differences Only';
                        ToolTip = 'Specifies whether the report only shows runs where the difference is not zero.';
                    }
                }
            }
        }
    }

    rendering
    {
        layout(ItemReconciliationRdlc)
        {
            Type = RDLC;
            LayoutFile = './.vscode/Layouts/Report80000.ImpressItemReconciliation.rdlc';
            Caption = 'Item Reconciliation';
        }
    }

    var
        RunIDs: List of [Integer];
        SQLRunIDFilter: Text;
        RunStartDate: Date;
        RunEndDate: Date;
        ShowDifferencesOnly: Boolean;
        SQLRunID: Integer;
        StagingRecordCount: Integer;
        StagedItemCount: Integer;
        ProcessedRecordCount: Integer;
        ErrorRecordCount: Integer;
        BCItemCount: Integer;
        DifferenceCount: Integer;

    local procedure BuildRunIDList()
    var
        ImpressItemStaging: Record "Impress Item Staging";
    begin
        Clear(RunIDs);

        if HasDateFilter() then
            BuildRunIDListFromIntegrationControl()
        else begin
            ApplySQLRunIDFilter(ImpressItemStaging);
            if ImpressItemStaging.FindSet() then
                repeat
                    AddRunID(ImpressItemStaging."SQL Run ID");
                until ImpressItemStaging.Next() = 0;
        end;
    end;

    local procedure BuildRunIDListFromIntegrationControl()
    var
        ImpressIntegrationControl: Record "Impress Integration Control";
    begin
        ApplySQLRunIDFilterToIntegrationControl(ImpressIntegrationControl);
        ApplyRunDateFilter(ImpressIntegrationControl);

        if ImpressIntegrationControl.FindSet() then
            repeat
                AddRunID(ImpressIntegrationControl."SQL Run ID");
            until ImpressIntegrationControl.Next() = 0;
    end;

    local procedure CalculateRunTotals(CurrentSQLRunID: Integer)
    var
        ImpressItemStaging: Record "Impress Item Staging";
        Item: Record Item;
        ItemNos: List of [Code[20]];
        ItemNo: Code[20];
    begin
        Clear(StagingRecordCount);
        Clear(StagedItemCount);
        Clear(ProcessedRecordCount);
        Clear(ErrorRecordCount);
        Clear(BCItemCount);
        Clear(DifferenceCount);

        ImpressItemStaging.SetRange("SQL Run ID", CurrentSQLRunID);
        if ImpressItemStaging.FindSet() then
            repeat
                StagingRecordCount += 1;

                if ImpressItemStaging.Status = ImpressItemStaging.Status::Processed then
                    ProcessedRecordCount += 1;
                if ImpressItemStaging.Status = ImpressItemStaging.Status::Error then
                    ErrorRecordCount += 1;

                if (ImpressItemStaging."Item No." <> '') and (not ItemNos.Contains(ImpressItemStaging."Item No.")) then
                    ItemNos.Add(ImpressItemStaging."Item No.");
            until ImpressItemStaging.Next() = 0;

        StagedItemCount := ItemNos.Count();
        foreach ItemNo in ItemNos do
            if Item.Get(ItemNo) then
                BCItemCount += 1;

        DifferenceCount := StagingRecordCount - ProcessedRecordCount;
    end;

    local procedure ApplySQLRunIDFilter(var ImpressItemStaging: Record "Impress Item Staging")
    begin
        if SQLRunIDFilter <> '' then
            ImpressItemStaging.SetFilter("SQL Run ID", SQLRunIDFilter);
    end;

    local procedure ApplySQLRunIDFilterToIntegrationControl(var ImpressIntegrationControl: Record "Impress Integration Control")
    begin
        if SQLRunIDFilter <> '' then
            ImpressIntegrationControl.SetFilter("SQL Run ID", SQLRunIDFilter);
    end;

    local procedure ApplyRunDateFilter(var ImpressIntegrationControl: Record "Impress Integration Control")
    var
        StartDateTime: DateTime;
        EndDateTime: DateTime;
    begin
        if RunStartDate <> 0D then
            StartDateTime := CreateDateTime(RunStartDate, 0T);
        if RunEndDate <> 0D then
            EndDateTime := CreateDateTime(RunEndDate, 235959T);

        if (RunStartDate <> 0D) and (RunEndDate <> 0D) then
            ImpressIntegrationControl.SetRange("Run Start DateTime", StartDateTime, EndDateTime);
        if (RunStartDate <> 0D) and (RunEndDate = 0D) then
            ImpressIntegrationControl.SetFilter("Run Start DateTime", '>=%1', StartDateTime);
        if (RunStartDate = 0D) and (RunEndDate <> 0D) then
            ImpressIntegrationControl.SetFilter("Run Start DateTime", '<=%1', EndDateTime);
    end;

    local procedure HasDateFilter(): Boolean
    begin
        exit((RunStartDate <> 0D) or (RunEndDate <> 0D));
    end;

    local procedure AddRunID(NewSQLRunID: Integer)
    begin
        if (NewSQLRunID <> 0) and (not RunIDs.Contains(NewSQLRunID)) then
            RunIDs.Add(NewSQLRunID);
    end;

    procedure SetSQLRunIDFilter(NewSQLRunIDFilter: Text)
    begin
        SQLRunIDFilter := NewSQLRunIDFilter;
    end;
}
