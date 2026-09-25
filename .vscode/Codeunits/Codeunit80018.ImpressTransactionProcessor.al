codeunit 80018 "Impress Trans. Posting Engine"
{
    // Each inventory transaction/pair is atomic; orchestration commits after success.
    procedure ProcessSourceDatabase(SourceDatabase: Text[50])
    begin
        if not (SourceDatabase in ['ImpressTest', 'StickersTest']) then
            Error('Unsupported Source Database %1.', SourceDatabase);
        ProcessInventoryTransactions(SourceDatabase);
        if not ProcessSalesInvoices(SourceDatabase) then
            exit;
        ProcessSalesCreditMemos(SourceDatabase);
    end;

    local procedure ProcessInventoryTransactions(SourceDatabase: Text[50])
    var
        Staging: Record "Impress Inv Trans Staging";
    begin
        Staging.SetCurrentKey("Source Database", "Source Transaction ID");
        Staging.SetRange("Source Database", SourceDatabase);
        Staging.SetFilter("Processing Status", '<>%1', Staging."Processing Status"::Processed);
        // Requery after every commit: paired rows and status filters can change.
        while Staging.FindFirst() do
            ProcessTransaction(Staging);
    end;
    local procedure DispatchInventory(var Staging: Record "Impress Inv Trans Staging"): Text
    begin
        case Staging."Transaction Type" + '/' + Staging."Transaction Source" of
            'I/I': exit(ProcessII(Staging));
            'R/P': exit(ProcessRP(Staging));
            'A/A': exit(ProcessAA(Staging));
            'T/G': exit(ProcessTG(Staging));
            'T/T': exit(ProcessTT(Staging));
            'T/1': exit(ProcessT1(Staging));
            'R/R': exit(ProcessRR(Staging));
        end;
        exit(StrSubstNo('Unsupported transaction %1/%2. Source %3, transaction %4. No posting was performed.',
            Staging."Transaction Type", Staging."Transaction Source", Staging."Source Database", Staging."Source Transaction ID"));
    end;

    local procedure ProcessII(Staging: Record "Impress Inv Trans Staging"): Text
    var
        Management: Codeunit "Impress II Invoice Mgt.";
        Header: Record "Impress Sales Doc Hdr Staging";
    begin
        Management.ResolveInvoice(Staging, Header);
        Management.PostDocumentAtomic(Header, false);
        exit('');
    end;

    local procedure ProcessRP(var Staging: Record "Impress Inv Trans Staging"): Text
    var
        Receipt: Codeunit "Impress RP Receipt Mgt.";
    begin
        Receipt.PostAtomic(Staging);
        exit('');
    end;

    local procedure ProcessAA(var Staging: Record "Impress Inv Trans Staging"): Text
    var
        Preparation: Codeunit "Impress TG Preparation";
    begin
        Preparation.ProcessAA(Staging);
        exit('');
    end;

    local procedure ProcessTG(var Staging: Record "Impress Inv Trans Staging"): Text
    var
        TGPosting: Codeunit "Impress TG Preparation";
    begin
        TGPosting.ProcessTG(Staging);
        exit('');
    end;

    local procedure ProcessTT(Staging: Record "Impress Inv Trans Staging"): Text
    begin
        exit(HandlerNotReady(Staging, 'T/T'));
    end;

    local procedure ProcessT1(Staging: Record "Impress Inv Trans Staging"): Text
    begin
        exit(HandlerNotReady(Staging, 'T/1'));
    end;

    local procedure ProcessRR(Staging: Record "Impress Inv Trans Staging"): Text
    begin
        exit(HandlerNotReady(Staging, 'R/R'));
    end;

    local procedure HandlerNotReady(Staging: Record "Impress Inv Trans Staging"; Handler: Text): Text
    begin
        // Pair/group membership is not inferred. This is a preflight error only.
        exit(StrSubstNo('%1 handler awaits reviewed grouping, posting and recovery rules. Source %2, transaction %3. No rows were claimed or posted.',
            Handler, Staging."Source Database", Staging."Source Transaction ID"));
    end;

    local procedure ProcessSalesInvoices(SourceDatabase: Text[50]): Boolean
    begin
        exit(ProcessSalesPhase(SourceDatabase, 2));
    end;

    local procedure ProcessSalesCreditMemos(SourceDatabase: Text[50]): Boolean
    begin
        exit(ProcessSalesPhase(SourceDatabase, 3));
    end;

    local procedure ProcessSalesPhase(SourceDatabase: Text[50]; Phase: Integer): Boolean
    var
        Header: Record "Impress Sales Doc Hdr Staging";
        Failure: Text;
    begin
        Header.SetRange("Source Database", SourceDatabase);
        Header.SetFilter("Processing Status", '<>%1', Header."Processing Status"::Processed);
        if Header.FindSet() then
            repeat
                // Phase 1 must complete through I/I; unknown phase values cannot post.
                if (Header."Processing Phase" < 2) or (Header."Processing Phase" > 3) then begin
                    SetSalesDocumentError(Header, 'Unresolved inventory-bearing document or unsupported Processing Phase. No posting was performed.');
                    exit(false);
                end;
                if Header."Processing Phase" = Phase then begin
                    if not TransportReady(Header."Transport Status") then
                        exit(false);
                    if Header."Processing Status" = Header."Processing Status"::Processing then
                        exit(false);
                    if Phase = 2 then
                        Failure := ProcessSalesInvoice(Header)
                    else
                        Failure := ProcessSalesCreditMemo(Header);
                    if Failure <> '' then begin
                        SetSalesDocumentError(Header, Failure);
                        exit(false);
                    end;
                end;
            until Header.Next() = 0;
        exit(true);
    end;

    local procedure ProcessSalesInvoice(Header: Record "Impress Sales Doc Hdr Staging"): Text
    begin
        exit(StrSubstNo('Sales invoice handler awaits reviewed classification, account and idempotency rules. Source %1, document %2. No posting was performed.', Header."Source Database", Header."Document No."));
    end;

    local procedure ProcessSalesCreditMemo(Header: Record "Impress Sales Doc Hdr Staging"): Text
    begin
        // Item/SKU lines remain Item lines with financial-only reversal.
        // Never substitute Resources or add compensating item journals.
        exit(StrSubstNo('Sales credit memo handler awaits reviewed financial-only Item posting and invoice application rules. Source %1, document %2. No posting was performed.', Header."Source Database", Header."Document No."));
    end;

    local procedure SetSalesDocumentError(var Header: Record "Impress Sales Doc Hdr Staging"; Failure: Text)
    var
        Line: Record "Impress Sales Doc Line Staging";
    begin
        Header."Processing Status" := Header."Processing Status"::Error;
        Header."Error Message" := CopyStr(Failure, 1, MaxStrLen(Header."Error Message"));
        Header.Modify(true);
        Line.SetRange("Source Database", Header."Source Database");
        Line.SetRange("Sales Document Entry No.", Header."Entry No.");
        Line.SetFilter("Processing Status", '<>%1', Line."Processing Status"::Processed);
        if Line.FindSet(true) then
            repeat
                Line."Processing Status" := Line."Processing Status"::Error;
                Line."Error Message" := CopyStr(Failure, 1, MaxStrLen(Line."Error Message"));
                Line.Modify(true);
            until Line.Next() = 0;
    end;

    local procedure TransportReady(Status: Enum "Impress Integration Status"): Boolean
    begin
        exit(Status in [Status::Sent, Status::Processed]);
    end;

    procedure ProcessSelectedTransactions(var Selected: Record "Impress Inv Trans Staging"): Integer
    var
        Worklist: Record "Impress Inv Trans Staging" temporary;
        Current: Record "Impress Inv Trans Staging";
        InvoiceHeader: Record "Impress Sales Doc Hdr Staging";
        InvoiceMgt: Codeunit "Impress II Invoice Mgt.";
        Invoices: Dictionary of [BigInteger, Boolean];
        PairCount: Integer;
    begin
        // Snapshot page filters/marks, then sort each independent source by SKUTRANS_ID.
        if Selected.FindSet() then
            repeat
                if (Selected."Transaction Type" = 'I') and (Selected."Transaction Source" = 'I') then begin
                    InvoiceMgt.ResolveInvoice(Selected, InvoiceHeader);
                    if not Invoices.ContainsKey(InvoiceHeader."Entry No.") then begin
                        Invoices.Add(InvoiceHeader."Entry No.", true);
                        Current.Reset();
                        Current.SetRange("Source Database", Selected."Source Database");
                        Current.SetRange("Source Transaction ID", InvoiceHeader."First Inventory Transaction ID");
                        Current.FindFirst();
                        Worklist := Current;
                        Worklist.Insert();
                    end;
                end else begin
                    Worklist := Selected;
                    Worklist.Insert();
                end;
            until Selected.Next() = 0;

        Worklist.SetCurrentKey("Source Database", "Source Transaction ID");
        Worklist.Ascending(true);
        if Worklist.FindSet() then
            repeat
                Current.Get(Worklist."Entry No.");
                if Current."Processing Status" <> Current."Processing Status"::Processed then begin
                    ProcessTransaction(Current);
                    PairCount += 1;
                end;
            until Worklist.Next() = 0;
        exit(PairCount);
    end;

    procedure ProcessInventoryTransaction(var InventoryStaging: Record "Impress Inv Trans Staging")
    begin
        ProcessTransaction(InventoryStaging);
    end;

    procedure ProcessTransaction(var InventoryStaging: Record "Impress Inv Trans Staging")
    var
        Management: Codeunit "Impress II Invoice Mgt.";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
    begin
        InventoryStaging.Get(InventoryStaging."Entry No.");
        if (InventoryStaging."Transaction Type" = 'R') and (InventoryStaging."Transaction Source" = 'P') then begin
            Receipt.ProcessTransaction(InventoryStaging);
            exit;
        end;
        if (InventoryStaging."Transaction Type" = 'I') and (InventoryStaging."Transaction Source" = 'I') then begin
            Management.ProcessTransaction(InventoryStaging);
            exit;
        end;
        ProcessTransactionAtomic(InventoryStaging);
        // Commit the complete pair only after posting and reconciliation succeed.
        Commit();
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure ProcessTransactionAtomic(var InventoryStaging: Record "Impress Inv Trans Staging")
    var
        Earlier: Record "Impress Inv Trans Staging";
        SourceLock: Record "Impress Posting Source Lock";
        Failure: Text;
    begin
        InventoryStaging.Get(InventoryStaging."Entry No.");
        SourceLock.LockTable();
        if not SourceLock.Get(InventoryStaging."Source Database") then begin
            SourceLock.Init();
            SourceLock."Source Database" := InventoryStaging."Source Database";
            SourceLock.Insert();
        end;
        InventoryStaging.LockTable();
        InventoryStaging.Get(InventoryStaging."Entry No.");
        InventoryStaging.TestField("Source Database", SourceLock."Source Database");
        if (InventoryStaging."Transaction Type" = 'I') and (InventoryStaging."Transaction Source" = 'I') then begin
            Failure := ProcessII(InventoryStaging);
            InventoryStaging.Get(InventoryStaging."Entry No.");
            exit;
        end;
        // T/G checks ordering for both paired rows under this same source lock.
        if (InventoryStaging."Transaction Type" <> 'T') or (InventoryStaging."Transaction Source" <> 'G') then begin
            if InventoryStaging."Processing Status" = InventoryStaging."Processing Status"::Processed then
                if (InventoryStaging."Transaction Type" = 'A') and (InventoryStaging."Transaction Source" = 'A') then begin
                    Failure := ProcessAA(InventoryStaging);
                    exit;
                end else
                    if (InventoryStaging."Transaction Type" = 'R') and (InventoryStaging."Transaction Source" = 'P') then begin
                        Failure := ProcessRP(InventoryStaging);
                        exit;
                    end else
                        exit;
            Earlier.SetCurrentKey("Source Database", "Source Transaction ID");
            Earlier.SetRange("Source Database", InventoryStaging."Source Database");
            Earlier.SetFilter("Source Transaction ID", '<%1', InventoryStaging."Source Transaction ID");
            Earlier.SetFilter("Processing Status", '<>%1', Earlier."Processing Status"::Processed);
            if Earlier.FindFirst() then
                Error('Entry No. %1: source sequence requires earlier entries processed first. Entry No. %2 (Source Transaction ID %3) is %4.',
                    InventoryStaging."Entry No.", Earlier."Entry No.", Earlier."Source Transaction ID", Earlier."Processing Status");
        end;
        Failure := DispatchInventory(InventoryStaging);
        if Failure <> '' then
            Error('%1', Failure);
        InventoryStaging.Get(InventoryStaging."Entry No.");
    end;

    procedure PreviewTransaction(var InventoryStaging: Record "Impress Inv Trans Staging")
    var
        TGPreparation: Codeunit "Impress TG Preparation";
        Management: Codeunit "Impress II Invoice Mgt.";
    begin
        InventoryStaging.Get(InventoryStaging."Entry No.");
        case InventoryStaging."Transaction Type" + '/' + InventoryStaging."Transaction Source" of
            'T/G': TGPreparation.PreviewTG(InventoryStaging);
            'I/I': Management.PreviewTransaction(InventoryStaging);
            else
                Error('Preview (No Posting) is not implemented for %1/%2. Source %3, transaction %4. Nothing was posted.',
                    InventoryStaging."Transaction Type", InventoryStaging."Transaction Source", InventoryStaging."Source Database", InventoryStaging."Source Transaction ID");
        end;
        InventoryStaging.Get(InventoryStaging."Entry No.");
    end;

    procedure ProcessSalesDocument(var SalesHeaderStaging: Record "Impress Sales Doc Hdr Staging")
    var
        Management: Codeunit "Impress II Invoice Mgt.";
    begin
        if SalesHeaderStaging."Has Inventory Impact" and (UpperCase(SalesHeaderStaging."Document Type") = 'INVOICE') then begin
            Management.ProcessDocument(SalesHeaderStaging);
            exit;
        end;
        ProcessSourceDatabase(SalesHeaderStaging."Source Database");
        SalesHeaderStaging.Get(SalesHeaderStaging."Entry No.");
    end;

    procedure RetryInventoryTransaction(var InventoryStaging: Record "Impress Inv Trans Staging")
    begin
        ProcessTransaction(InventoryStaging);
    end;

    procedure RetrySalesDocument(var SalesHeaderStaging: Record "Impress Sales Doc Hdr Staging")
    begin
        ProcessSalesDocument(SalesHeaderStaging);
    end;

    procedure ResetInventoryTransaction(var InventoryStaging: Record "Impress Inv Trans Staging")
    begin
        Error('Reset requires reviewed transaction grouping and posted-result reconciliation rules. No status was changed.');
    end;

    procedure ResetSalesDocument(var SalesHeaderStaging: Record "Impress Sales Doc Hdr Staging")
    begin
        Error('Reset requires reviewed posted-document reconciliation rules. No status was changed.');
    end;

    procedure ValidateGLAccount(AccountNo: Text; AccountPurpose: Text)
    var
        GLAccount: Record "G/L Account";
    begin
        if AccountNo = '' then
            Error('%1 account is required.', AccountPurpose);
        if StrLen(AccountNo) > MaxStrLen(GLAccount."No.") then
            Error('%1 account %2 exceeds the BC account number length.', AccountPurpose, AccountNo);
        if not GLAccount.Get(AccountNo) then
            Error('%1 account %2 does not exist.', AccountPurpose, AccountNo);
        GLAccount.TestField("Account Type", GLAccount."Account Type"::Posting);
        GLAccount.TestField(Blocked, false);
    end;

    procedure ValidateExpectedAccount(ExpectedAccount: Text; ActualAccount: Code[20]; AccountPurpose: Text)
    begin
        ValidateGLAccount(ExpectedAccount, AccountPurpose);
        if ExpectedAccount <> ActualAccount then
            Error('%1 account mismatch. Impress expects %2; BC posting setup uses %3.', AccountPurpose, ExpectedAccount, ActualAccount);
    end;

    procedure ApplyCategoryDimension(var DimensionSetID: Integer; DivisionCode: Code[20])
    var
        TempEntry: Record "Dimension Set Entry" temporary;
        DimensionManagement: Codeunit DimensionManagement;
    begin
        DimensionManagement.GetDimensionSet(TempEntry, DimensionSetID);
        TempEntry.SetRange("Dimension Code", 'CATEGORY');
        TempEntry.DeleteAll();
        TempEntry.Reset();
        if DivisionCode <> '' then begin
            TempEntry.Init();
            TempEntry."Dimension Set ID" := DimensionSetID;
            TempEntry.Validate("Dimension Code", 'CATEGORY');
            TempEntry.Validate("Dimension Value Code", DivisionCode);
            TempEntry.Insert();
        end;
        DimensionSetID := DimensionManagement.GetDimensionSetID(TempEntry);
    end;
}
