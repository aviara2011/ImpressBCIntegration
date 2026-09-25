codeunit 80000 "Impress Integration Management"
{
    procedure SetItemStagingError(var ImpressItemStaging: Record "Impress Item Staging"; ErrorMessage: Text)
    begin
        ImpressItemStaging.Status := ImpressItemStaging.Status::Error;
        ImpressItemStaging."Error Message" := CopyStr(ErrorMessage, 1, MaxStrLen(ImpressItemStaging."Error Message"));
        ImpressItemStaging."Processed DateTime" := CurrentDateTime();
        ImpressItemStaging.Modify(true);
    end;

    procedure SetCustomerStagingError(var ImpressCustomerStaging: Record "Impress Customer Staging"; ErrorMessage: Text)
    begin
        ImpressCustomerStaging."Transport Status" := ImpressCustomerStaging."Transport Status"::Error;
        ImpressCustomerStaging."Error Message" := CopyStr(ErrorMessage, 1, MaxStrLen(ImpressCustomerStaging."Error Message"));
        ImpressCustomerStaging."Processed DateTime" := CurrentDateTime();
        ImpressCustomerStaging.Modify(true);
    end;

    procedure SetVendorStagingError(var ImpressVendorStaging: Record "Impress Vendor Staging"; ErrorMessage: Text)
    begin
        ImpressVendorStaging."Transport Status" := ImpressVendorStaging."Transport Status"::Error;
        ImpressVendorStaging."Error Message" := CopyStr(ErrorMessage, 1, MaxStrLen(ImpressVendorStaging."Error Message"));
        ImpressVendorStaging."Sent to BC DateTime" := CurrentDateTime();
        ImpressVendorStaging.Modify(true);
    end;

    procedure SetGLAccountStagingError(var ImpressGLAccountStaging: Record "Impress G/L Account Staging"; ErrorMessage: Text)
    begin
        ImpressGLAccountStaging."Transport Status" := ImpressGLAccountStaging."Transport Status"::Error;
        ImpressGLAccountStaging."Error Message" := CopyStr(ErrorMessage, 1, MaxStrLen(ImpressGLAccountStaging."Error Message"));
        ImpressGLAccountStaging."Sent to BC DateTime" := CurrentDateTime();
        ImpressGLAccountStaging.Modify(true);
    end;

    procedure UpdateItemControlTotals(SQLRunID: Integer)
    var
        ImpressIntegrationControl: Record "Impress Integration Control";
        ImpressItemStaging: Record "Impress Item Staging";
        StagingRecordCount: Integer;
        ProcessedRecordCount: Integer;
    begin
        if SQLRunID = 0 then
            exit;

        ImpressItemStaging.SetRange("SQL Run ID", SQLRunID);
        if ImpressItemStaging.FindSet() then
            repeat
                StagingRecordCount += 1;
                if ImpressItemStaging.Status = ImpressItemStaging.Status::Processed then
                    ProcessedRecordCount += 1;
            until ImpressItemStaging.Next() = 0;

        ImpressIntegrationControl.SetRange("SQL Run ID", SQLRunID);
        if ImpressIntegrationControl.FindSet(true) then
            repeat
                ImpressIntegrationControl."Records Processed In BC" := ProcessedRecordCount;
                ImpressIntegrationControl.Difference := StagingRecordCount - ProcessedRecordCount;
                ImpressIntegrationControl.Modify(true);
            until ImpressIntegrationControl.Next() = 0;
    end;

    procedure UpdateCustomerControlTotals(SQLRunID: Integer)
    var
        ImpressIntegrationControl: Record "Impress Integration Control";
        ImpressCustomerStaging: Record "Impress Customer Staging";
        StagingRecordCount: Integer;
        ProcessedRecordCount: Integer;
    begin
        if SQLRunID = 0 then
            exit;

        ImpressCustomerStaging.SetRange("SQL Run ID", SQLRunID);
        if ImpressCustomerStaging.FindSet() then
            repeat
                StagingRecordCount += 1;
                if ImpressCustomerStaging."Transport Status" = ImpressCustomerStaging."Transport Status"::Processed then
                    ProcessedRecordCount += 1;
            until ImpressCustomerStaging.Next() = 0;

        ImpressIntegrationControl.SetRange("SQL Run ID", SQLRunID);
        if ImpressIntegrationControl.FindSet(true) then
            repeat
                ImpressIntegrationControl."Records Processed In BC" := ProcessedRecordCount;
                ImpressIntegrationControl.Difference := StagingRecordCount - ProcessedRecordCount;
                ImpressIntegrationControl.Modify(true);
            until ImpressIntegrationControl.Next() = 0;
    end;

    procedure UpdateVendorControlTotals(SQLRunID: Integer)
    var
        ImpressIntegrationControl: Record "Impress Integration Control";
        ImpressVendorStaging: Record "Impress Vendor Staging";
        StagingRecordCount: Integer;
        ProcessedRecordCount: Integer;
    begin
        if SQLRunID = 0 then
            exit;

        ImpressVendorStaging.SetRange("SQL Run ID", SQLRunID);
        if ImpressVendorStaging.FindSet() then
            repeat
                StagingRecordCount += 1;
                if ImpressVendorStaging."Transport Status" = ImpressVendorStaging."Transport Status"::Processed then
                    ProcessedRecordCount += 1;
            until ImpressVendorStaging.Next() = 0;

        ImpressIntegrationControl.SetRange("SQL Run ID", SQLRunID);
        if ImpressIntegrationControl.FindSet(true) then
            repeat
                ImpressIntegrationControl."Records Processed In BC" := ProcessedRecordCount;
                ImpressIntegrationControl.Difference := StagingRecordCount - ProcessedRecordCount;
                ImpressIntegrationControl.Modify(true);
            until ImpressIntegrationControl.Next() = 0;
    end;

    procedure UpdateGLAccountControlTotals(SQLRunID: Integer)
    var
        ImpressIntegrationControl: Record "Impress Integration Control";
        ImpressGLAccountStaging: Record "Impress G/L Account Staging";
        StagingRecordCount: Integer;
        ProcessedRecordCount: Integer;
    begin
        if SQLRunID = 0 then
            exit;

        ImpressGLAccountStaging.SetRange("SQL Run ID", SQLRunID);
        if ImpressGLAccountStaging.FindSet() then
            repeat
                StagingRecordCount += 1;
                if ImpressGLAccountStaging."Transport Status" = ImpressGLAccountStaging."Transport Status"::Processed then
                    ProcessedRecordCount += 1;
            until ImpressGLAccountStaging.Next() = 0;

        ImpressIntegrationControl.SetRange("SQL Run ID", SQLRunID);
        if ImpressIntegrationControl.FindSet(true) then
            repeat
                ImpressIntegrationControl."Records Processed In BC" := ProcessedRecordCount;
                ImpressIntegrationControl.Difference := StagingRecordCount - ProcessedRecordCount;
                ImpressIntegrationControl.Modify(true);
            until ImpressIntegrationControl.Next() = 0;
    end;

    procedure UpdatePurchaseOrderControlTotals(SQLRunID: BigInteger)
    var
        IntegrationControl: Record "Impress Integration Control";
        HeaderStaging: Record "Impress Purch Header Staging";
        LineStaging: Record "Impress Purchase Line Staging";
        StagedCount: Integer;
        ProcessedCount: Integer;
        FailedCount: Integer;
        SentCount: Integer;
    begin
        if (SQLRunID <= 0) or (SQLRunID > 2147483647) then
            exit;
        HeaderStaging.SetRange("SQL Run ID", SQLRunID);
        if HeaderStaging.FindSet() then
            repeat
                StagedCount += 1;
                if HeaderStaging."Transport Status" <> HeaderStaging."Transport Status"::New then
                    SentCount += 1;
                case HeaderStaging."Processing Status" of
                    HeaderStaging."Processing Status"::Processed: ProcessedCount += 1;
                    HeaderStaging."Processing Status"::Error: FailedCount += 1;
                end;
            until HeaderStaging.Next() = 0;
        LineStaging.SetRange("SQL Run ID", SQLRunID);
        if LineStaging.FindSet() then
            repeat
                StagedCount += 1;
                if LineStaging."Transport Status" <> LineStaging."Transport Status"::New then
                    SentCount += 1;
                case LineStaging."Processing Status" of
                    LineStaging."Processing Status"::Processed: ProcessedCount += 1;
                    LineStaging."Processing Status"::Error: FailedCount += 1;
                end;
            until LineStaging.Next() = 0;
        IntegrationControl.SetRange("SQL Run ID", SQLRunID);
        IntegrationControl.SetRange("Process Name", 'PURCHASE ORDERS');
        if IntegrationControl.FindSet(true) then
            repeat
                IntegrationControl."Records Staged" := StagedCount;
                IntegrationControl."Records Sent To BC" := SentCount;
                IntegrationControl."Records Processed In BC" := ProcessedCount;
                IntegrationControl."Records Failed" := FailedCount;
                IntegrationControl.Difference := StagedCount - ProcessedCount;
                if FailedCount > 0 then begin
                    IntegrationControl."Run Status" := IntegrationControl."Run Status"::Error;
                    IntegrationControl."Run Message" := StrSubstNo('%1 purchase order staging record(s) failed; %2 processed.', FailedCount, ProcessedCount);
                    IntegrationControl."Run End DateTime" := CurrentDateTime();
                end else
                    if (StagedCount > 0) and (ProcessedCount = StagedCount) then begin
                        IntegrationControl."Run Status" := IntegrationControl."Run Status"::Success;
                        IntegrationControl."Run Message" := StrSubstNo('%1 purchase order staging record(s) processed successfully.', ProcessedCount);
                        IntegrationControl."Run End DateTime" := CurrentDateTime();
                        IntegrationControl."Last Successful Run DateTime" := CurrentDateTime();
                    end;
                IntegrationControl.Modify(true);
            until IntegrationControl.Next() = 0;
    end;

    procedure UpdateSalesOrderControlTotals(SQLRunID: BigInteger)
    var
        IntegrationControl: Record "Impress Integration Control";
        HeaderStaging: Record "Impress Sales Header Staging";
        LineStaging: Record "Impress Sales Line Staging";
        StagedCount: Integer;
        ProcessedCount: Integer;
        FailedCount: Integer;
        SentCount: Integer;
    begin
        if (SQLRunID <= 0) or (SQLRunID > 2147483647) then
            exit;
        HeaderStaging.SetRange("SQL Run ID", SQLRunID);
        if HeaderStaging.FindSet() then
            repeat
                StagedCount += 1;
                if HeaderStaging."Transport Status" <> HeaderStaging."Transport Status"::New then
                    SentCount += 1;
                case HeaderStaging."Processing Status" of
                    HeaderStaging."Processing Status"::Processed: ProcessedCount += 1;
                    HeaderStaging."Processing Status"::Error: FailedCount += 1;
                end;
            until HeaderStaging.Next() = 0;
        LineStaging.SetRange("SQL Run ID", SQLRunID);
        if LineStaging.FindSet() then
            repeat
                StagedCount += 1;
                if LineStaging."Transport Status" <> LineStaging."Transport Status"::New then
                    SentCount += 1;
                case LineStaging."Processing Status" of
                    LineStaging."Processing Status"::Processed: ProcessedCount += 1;
                    LineStaging."Processing Status"::Error: FailedCount += 1;
                end;
            until LineStaging.Next() = 0;
        IntegrationControl.SetRange("SQL Run ID", SQLRunID);
        IntegrationControl.SetRange("Process Name", 'SALES ORDERS');
        if IntegrationControl.FindSet(true) then
            repeat
                IntegrationControl."Records Staged" := StagedCount;
                IntegrationControl."Records Sent To BC" := SentCount;
                IntegrationControl."Records Processed In BC" := ProcessedCount;
                IntegrationControl."Records Failed" := FailedCount;
                IntegrationControl.Difference := StagedCount - ProcessedCount;
                if FailedCount > 0 then begin
                    IntegrationControl."Run Status" := IntegrationControl."Run Status"::Error;
                    IntegrationControl."Run Message" := StrSubstNo('%1 sales order staging record(s) failed; %2 processed.', FailedCount, ProcessedCount);
                    IntegrationControl."Run End DateTime" := CurrentDateTime();
                end else
                    if (StagedCount > 0) and (ProcessedCount = StagedCount) then begin
                        IntegrationControl."Run Status" := IntegrationControl."Run Status"::Success;
                        IntegrationControl."Run Message" := StrSubstNo('%1 sales order staging record(s) processed successfully.', ProcessedCount);
                        IntegrationControl."Run End DateTime" := CurrentDateTime();
                        IntegrationControl."Last Successful Run DateTime" := CurrentDateTime();
                    end;
                IntegrationControl.Modify(true);
            until IntegrationControl.Next() = 0;
    end;
}
