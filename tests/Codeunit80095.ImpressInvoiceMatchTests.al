#if TG_TESTS
codeunit 80095 "Impress Invoice Match Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure RPResolvesSizesAndRejectsAmbiguousSourceLine()
    var
        Transaction: Record "Impress Inv Trans Staging";
        StagedHeader: Record "Impress Purch Header Staging";
        StagedLine: Record "Impress Purchase Line Staging";
        Other: Record "Impress Purchase Line Staging";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
    begin
        RPFixture(Transaction, StagedHeader, StagedLine, Header, Line);
        Other := StagedLine;
        Other."Entry No." := 0;
        Other."Size Position" := 2;
        Other."Source Size" := 'MD';
        Other.Insert();
        Receipt.Resolve(Transaction, StagedHeader, StagedLine, Header, Line);
        Assert(Line."Line No." = 10000, 'R/P did not select the persisted size-expanded line.');
        Other."Source Size" := 'SM';
        Other.Modify();
        asserterror Receipt.Resolve(Transaction, StagedHeader, StagedLine, Header, Line);
        Assert(StrPos(GetLastErrorText(), 'found 2') > 0, 'R/P accepted ambiguous staging.');
        Transaction."Source Size" := 'XL';
        asserterror Receipt.Resolve(Transaction, StagedHeader, StagedLine, Header, Line);
        Assert(StrPos(GetLastErrorText(), 'found 0') > 0, 'R/P guessed a missing size.');
    end;

    [Test]
    procedure RPRejectsStaleSystemIdsDespiteMatchingDocumentNumbers()
    var
        Transaction: Record "Impress Inv Trans Staging";
        StagedHeader: Record "Impress Purch Header Staging";
        StagedLine: Record "Impress Purchase Line Staging";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
    begin
        RPFixture(Transaction, StagedHeader, StagedLine, Header, Line);
        StagedLine."BC Line System ID" := CreateGuid();
        StagedLine.Modify();
        asserterror Receipt.Resolve(Transaction, StagedHeader, StagedLine, Header, Line);
        Assert(StrPos(GetLastErrorText(), 'stale BC Line System ID') > 0, 'R/P fell back from a stale line GUID.');
        StagedLine."BC Line System ID" := Line.SystemId;
        StagedLine."BC Header System ID" := CreateGuid();
        StagedLine.Modify();
        asserterror Receipt.Resolve(Transaction, StagedHeader, StagedLine, Header, Line);
        Assert(StrPos(GetLastErrorText(), 'stale BC Header System ID') > 0, 'R/P fell back from a stale header GUID.');
    end;

    [Test]
    procedure RPLocationDifferenceAllowsResolutionButRejectsSourceDrift()
    var
        Transaction: Record "Impress Inv Trans Staging";
        StagedHeader: Record "Impress Purch Header Staging";
        StagedLine: Record "Impress Purchase Line Staging";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
    begin
        RPFixture(Transaction, StagedHeader, StagedLine, Header, Line);
        Line."Location Code" := 'OTHER';
        Line.Modify();
        Receipt.Resolve(Transaction, StagedHeader, StagedLine, Header, Line);
        Line.TestField("Location Code", 'OTHER');
        Line."Location Code" := Transaction."BC Location Code";
        Line."Impress POrder Detail ID" := 999;
        Line.Modify();
        asserterror Receipt.Resolve(Transaction, StagedHeader, StagedLine, Header, Line);
        Assert(StrPos(GetLastErrorText(), 'Impress POrder Detail ID') > 0, 'R/P accepted a different source line.');
    end;

    [Test]
    procedure RPReceiptEvidencePreventsRepostWithoutLedgerOrOrder()
    var
        Transaction: Record "Impress Inv Trans Staging";
        Posted: Record "Purch. Rcpt. Header";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
        Tracking: Codeunit "Impress Posting Tracking";
    begin
        Transaction."Source Database" := 'RP-TEST';
        Transaction."Source Transaction ID" := 8763076;
        Transaction."Transaction Type" := 'R';
        Transaction."Transaction Source" := 'P';
        Transaction."Transaction Handler" := 'PURCHASE RECEIPT';
        Transaction."G/L Date" := DMY2Date(1, 5, 2026);
        Transaction.Quantity := 30;
        Transaction.Insert(true);
        Posted."No." := 'RP-EVIDENCE';
        Posted."Integration Posting ID" := Transaction.SystemId;
        Posted."Impress Source Database" := Transaction."Source Database";
        Posted."Impress Source Transaction ID" := Transaction."Source Transaction ID";
        Posted."Posting Date" := Transaction."G/L Date";
        Posted.Insert();
        Assert(Tracking.HasPostedEvidence(Transaction.SystemId), 'Receipt header must count as posted evidence.');
        asserterror Receipt.PostAtomic(Transaction);
        Assert(StrPos(GetLastErrorText(), 'exactly one nonzero receipt line') > 0, 'R/P tried resolving/posting an order before reconciling evidence.');
        asserterror Transaction.Delete(true);
        Assert(StrPos(GetLastErrorText(), 'retained for reconciliation') > 0, 'Cleared staging GUID allowed deletion of posted evidence.');
    end;

    [Test]
    procedure RPLocationOverrideUsesStandardReceivedQuantityCheck()
    var
        Transaction: Record "Impress Inv Trans Staging";
        StagedHeader: Record "Impress Purch Header Staging";
        StagedLine: Record "Impress Purchase Line Staging";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Location: Record Location;
        Receipt: Codeunit "Impress RP Receipt Mgt.";
    begin
        RPFixture(Transaction, StagedHeader, StagedLine, Header, Line);
        if not Location.Get('RP-LOC') then begin
            Location.Code := 'RP-LOC';
            Location.Insert();
        end;
        Line."Location Code" := 'OTHER';
        Line."Quantity Received" := 1;
        Line."Qty. Rcd. Not Invoiced" := 1;
        Line.Modify();
        asserterror Receipt.ApplyReceiptLocation(Transaction, Header, Line);
        Assert(StrPos(GetLastErrorText(), 'Qty. Rcd. Not Invoiced') > 0, 'Location override did not run standard receipt-activity validation.');
        Line.Get(Header."Document Type", Header."No.", 10000);
        Line.TestField("Location Code", 'OTHER');
    end;

    [Test]
    procedure RPLocationIgnoresHeaderAndStagedMapping()
    var
        Transaction: Record "Impress Inv Trans Staging";
        StagedHeader: Record "Impress Purch Header Staging";
        StagedLine: Record "Impress Purchase Line Staging";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
    begin
        RPFixture(Transaction, StagedHeader, StagedLine, Header, Line);
        StagedHeader."BC Location Code" := '';
        StagedHeader."Source Warehouse Code" := '';
        StagedHeader.Modify();
        Transaction."BC Location Code" := 'OLD';
        Receipt.Resolve(Transaction, StagedHeader, StagedLine, Header, Line);
        // Same warehouse needs no write or reopening, even on a released order.
        Header.Status := Header.Status::Released;
        Header.Modify();
        Receipt.ApplyReceiptLocation(Transaction, Header, Line);
        Header.TestField(Status, Header.Status::Released);
        Line.TestField("Location Code", 'RP-LOC');
        Transaction."Source Warehouse Code" := 'WAREHOUSE-TOO-LONG';
        asserterror Receipt.ApplyReceiptLocation(Transaction, Header, Line);
        Assert(StrPos(GetLastErrorText(), 'exceeds the BC Location Code length') > 0, 'Warehouse was truncated.');
    end;

    local procedure RPFixture(var Transaction: Record "Impress Inv Trans Staging"; var StagedHeader: Record "Impress Purch Header Staging"; var StagedLine: Record "Impress Purchase Line Staging"; var Header: Record "Purchase Header"; var Line: Record "Purchase Line")
    begin
        Transaction."Source Database" := 'RP-TEST';
        Transaction."Source Transaction ID" := 8763076;
        Transaction."Source Order No." := '43958';
        Transaction."Source Order Line No." := 1;
        Transaction."Source SKU No." := 'C006NHRO';
        Transaction."Source Size" := 'SM';
        Transaction."Source Warehouse Code" := 'RP-LOC';
        Transaction."BC Item No." := 'RP-ITEM';
        Transaction."BC Variant Code" := 'SM';
        Transaction."BC Location Code" := 'RP-LOC';
        Header."Document Type" := Header."Document Type"::Order;
        Header."No." := 'RP-ORDER';
        Header."Impress Source Database" := 'RP-TEST';
        Header."Impress Source POrder ID" := 123;
        Header."Impress Purchase Order No." := '43958';
        Header.Insert();
        Line."Document Type" := Header."Document Type";
        Line."Document No." := Header."No.";
        Line."Line No." := 10000;
        Line.Type := Line.Type::Item;
        Line."No." := Transaction."BC Item No.";
        Line."Variant Code" := Transaction."BC Variant Code";
        Line."Location Code" := Transaction."BC Location Code";
        Line."Impress Source Database" := 'RP-TEST';
        Line."Impress POrder Detail ID" := 163446;
        Line."Impress Size Position" := 1;
        Line."Impress Source Line No." := 1;
        Line."Impress Source SKU" := Transaction."Source SKU No.";
        Line.Insert();
        StagedHeader."Source Database" := 'RP-TEST';
        StagedHeader."Source POrder ID" := 123;
        StagedHeader."Purchase Order No." := '43958';
        StagedHeader."Source Warehouse Code" := 'RP-LOC';
        StagedHeader."BC Location Code" := Transaction."BC Location Code";
        StagedHeader."BC System ID" := Header.SystemId;
        StagedHeader."BC Document No." := Header."No.";
        StagedHeader.Insert();
        StagedLine."Source Database" := 'RP-TEST';
        StagedLine."Source POrder ID" := 123;
        StagedLine."Source POrder Detail ID" := 163446;
        StagedLine."Size Position" := 1;
        StagedLine."Purchase Order No." := '43958';
        StagedLine."Source Line No." := 1;
        StagedLine."Source SKU" := Transaction."Source SKU No.";
        StagedLine."Source Size" := 'SM';
        StagedLine."BC Item No." := Transaction."BC Item No.";
        StagedLine."BC Variant Code" := Transaction."BC Variant Code";
        StagedLine."BC Header System ID" := Header.SystemId;
        StagedLine."BC Document No." := Header."No.";
        StagedLine."BC Line System ID" := Line.SystemId;
        StagedLine."BC Line No." := Line."Line No.";
        StagedLine.Insert();
    end;

    [Test]
    procedure RPReconcilesRetryWithoutLiveOrderAndRejectsChangedQuantity()
    var
        Transaction: Record "Impress Inv Trans Staging";
        Posted: Record "Purch. Rcpt. Header";
        PostedLine: Record "Purch. Rcpt. Line";
        ItemEntry: Record "Item Ledger Entry";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
        NextEntryNo: Integer;
    begin
        Transaction."Source Database" := 'RP-RETRY';
        Transaction."Source Transaction ID" := 8763077;
        Transaction."Transaction Type" := 'R';
        Transaction."Transaction Source" := 'P';
        Transaction."Transaction Handler" := 'PURCHASE RECEIPT';
        Transaction."G/L Date" := DMY2Date(1, 5, 2026);
        Transaction.Quantity := 36;
        Transaction."BC Item No." := 'RP-ITEM';
        Transaction."BC Variant Code" := 'MD';
        Transaction."BC Location Code" := 'OLD';
        Transaction."Source Warehouse Code" := 'RP-LOC';
        Transaction.Insert(true);
        Posted."No." := 'RP-RETRY';
        Posted."Order No." := 'DELETED-ORDER';
        Posted."Integration Posting ID" := Transaction.SystemId;
        Posted."Impress Source Database" := Transaction."Source Database";
        Posted."Impress Source Transaction ID" := Transaction."Source Transaction ID";
        Posted."Impress Source Warehouse" := Transaction."Source Warehouse Code";
        Posted."Posting Date" := Transaction."G/L Date";
        Posted."Impress Order Line No." := 20000;
        Posted.Insert();
        PostedLine."Document No." := Posted."No.";
        PostedLine."Line No." := 20000;
        PostedLine.Type := PostedLine.Type::Item;
        PostedLine."Order No." := Posted."Order No.";
        PostedLine."Order Line No." := 20000;
        PostedLine."No." := Transaction."BC Item No.";
        PostedLine."Variant Code" := Transaction."BC Variant Code";
        PostedLine."Location Code" := Transaction."Source Warehouse Code";
        PostedLine.Quantity := 36;
        PostedLine."Quantity (Base)" := 72;
        PostedLine.Insert();
        NextEntryNo := 1;
        if ItemEntry.FindLast() then
            NextEntryNo := ItemEntry."Entry No." + 1;
        ItemEntry.Init();
        ItemEntry."Entry No." := NextEntryNo;
        ItemEntry."Integration Posting ID" := Transaction.SystemId;
        ItemEntry."Document Type" := ItemEntry."Document Type"::"Purchase Receipt";
        ItemEntry."Entry Type" := ItemEntry."Entry Type"::Purchase;
        ItemEntry."Document No." := Posted."No.";
        ItemEntry."Document Line No." := PostedLine."Line No.";
        ItemEntry."Posting Date" := Posted."Posting Date";
        ItemEntry."Item No." := PostedLine."No.";
        ItemEntry."Variant Code" := PostedLine."Variant Code";
        ItemEntry."Location Code" := PostedLine."Location Code";
        ItemEntry.Quantity := 72;
        ItemEntry.Insert();
        Receipt.PostAtomic(Transaction);
        Transaction.TestField("Processing Status", Transaction."Processing Status"::Processed);
        Transaction.TestField("BC Posted Document No.", Posted."No.");
        Transaction.TestField("BC Location Code", 'RP-LOC');
        // Processed retry must reconcile the same evidence without requiring the PO.
        Receipt.PostAtomic(Transaction);
        Posted.SetRange("Integration Posting ID", Transaction.SystemId);
        Assert(Posted.Count() = 1, 'Retry created another receipt.');
        Transaction.Quantity := 37;
        asserterror Receipt.PostAtomic(Transaction);
        Assert(StrPos(GetLastErrorText(), 'Quantity') > 0, 'Changed receipt instruction was accepted.');
    end;

    [Test]
    procedure TaxToleranceUsesLocalCurrencySetup()
    var
        TaxResolver: Codeunit "Impress Tax Resolver";
    begin
        SetTaxTolerance(true, 0.05);
        TaxResolver.CheckTaxDifference(10, 10.05, '', false);
        asserterror TaxResolver.CheckTaxDifference(10, 10.06, '', false);
        Assert(StrPos(GetLastErrorText(), '0.05') > 0, 'BC maximum difference was not enforced.');
        TaxResolver.CheckTaxDifference(10, 9.95, '', false);
        asserterror TaxResolver.CheckTaxDifference(10, 9.94, '', false);
    end;

    [Test]
    procedure TaxToleranceDisabledRequiresExactMatch()
    var
        TaxResolver: Codeunit "Impress Tax Resolver";
    begin
        SetTaxTolerance(false, 1);
        TaxResolver.CheckTaxDifference(10, 10, '', false);
        asserterror TaxResolver.CheckTaxDifference(10, 10.01, '', false);
    end;

    [Test]
    procedure TaxToleranceZeroDoesNotDefaultToOneCent()
    var
        TaxResolver: Codeunit "Impress Tax Resolver";
    begin
        SetTaxTolerance(true, 0);
        TaxResolver.CheckTaxDifference(0, 0, '', false);
        asserterror TaxResolver.CheckTaxDifference(0, 0.01, '', false);
    end;

    [Test]
    procedure TaxToleranceUsesDocumentCurrencySetup()
    var
        TaxResolver: Codeunit "Impress Tax Resolver";
        Currency: Record Currency;
        Differences: Record "Sales Tax Amount Difference";
        OriginalCount: Integer;
    begin
        SetTaxTolerance(true, 0);
        Currency.Code := 'II-TAX-FCY';
        Currency."Amount Rounding Precision" := 0.01;
        Currency."Max. VAT Difference Allowed" := 0.10;
        Currency.Insert(false);
        OriginalCount := Differences.Count();
        TaxResolver.CheckTaxDifference(10, 10.10, Currency.Code, false);
        Assert(Differences.Count() = OriginalCount, 'Validation created a persisted tax adjustment.');
        asserterror TaxResolver.CheckTaxDifference(10, 10.11, Currency.Code, false);
    end;

    local procedure SetTaxTolerance(AllowDifference: Boolean; Maximum: Decimal)
    var
        GLSetup: Record "General Ledger Setup";
        SalesSetup: Record "Sales & Receivables Setup";
    begin
        if not GLSetup.Get() then
            GLSetup.Insert(false);
        GLSetup."Amount Rounding Precision" := 0.01;
        GLSetup."Max. VAT Difference Allowed" := Maximum;
        GLSetup.Modify(false);
        if not SalesSetup.Get() then
            SalesSetup.Insert(false);
        SalesSetup."Allow VAT Difference" := AllowDifference;
        SalesSetup.Modify(false);
    end;

    [Test]
    procedure InvoiceTaxSnapshotWithoutSalesOrder()
    var
        Management: Codeunit "Impress II Invoice Mgt.";
        TaxArea: Record "Tax Area";
        Jurisdiction: Record "Tax Jurisdiction";
        AreaLine: Record "Tax Area Line";
        Detail: Record "Tax Detail";
    begin
        InitializeInvoiceTax('TAXABLE');
        Management.EnsureInvoiceTaxSetup(Header);
        TaxArea.Get(Header."Tax Area Code");
        TaxArea.TestField(Description, Header."Tax Area Description");
        Jurisdiction.Get(Header."Tax Jurisdiction Code 1");
        Jurisdiction.TestField(Description, Header."Tax Jurisdiction Desc. 1");
        Jurisdiction.TestField("Tax Account (Sales)", Header."Tax G/L Account 1");
        AreaLine.Get(TaxArea.Code, Jurisdiction.Code);
        AreaLine.TestField("Calculation Order", 1);
        Detail.Get(Jurisdiction.Code, 'TAXABLE', Detail."Tax Type"::"Sales and Use Tax", Header."G/L Post Date");
        Detail.TestField("Tax Below Maximum", 6.25);
        Management.EnsureInvoiceTaxSetup(Header);
        Detail.SetRange("Tax Jurisdiction Code", Jurisdiction.Code);
        Detail.SetRange("Tax Group Code", 'TAXABLE');
        Assert(Detail.Count() = 1, 'Retry duplicated tax detail.');
        Header.Get(Header."Entry No.");
        Header.TestField("Source Sales Order No.", '');
        Header.TestField("Tax Total", 0);
        Header.TestField("Taxable Amount 1", 0);
        Header.TestField("Tax Rate Total", 6.25);
    end;

    [Test]
    procedure InvoiceExemptTaxGroupUsesZeroRate()
    var
        Management: Codeunit "Impress II Invoice Mgt.";
        Detail: Record "Tax Detail";
    begin
        InitializeInvoiceTax('RES');
        Management.EnsureInvoiceTaxSetup(Header);
        Detail.Get(Header."Tax Jurisdiction Code 1", 'RES', Detail."Tax Type"::"Sales and Use Tax", Header."G/L Post Date");
        Detail.TestField("Tax Below Maximum", 0);
    end;

    [Test]
    procedure InvoiceTaxMissingGroupRequiresTransport()
    var
        Management: Codeunit "Impress II Invoice Mgt.";
    begin
        InitializeInvoiceTax('');
        asserterror Management.EnsureInvoiceTaxSetup(Header);
        Assert(StrPos(GetLastErrorText(), 'Transport the invoice line tax snapshot') > 0, 'Missing group was not rejected.');
    end;

    [Test]
    procedure InvoiceTaxRejectsInvalidGroup()
    var
        Management: Codeunit "Impress II Invoice Mgt.";
    begin
        InitializeInvoiceTax('INVALID');
        asserterror Management.EnsureInvoiceTaxSetup(Header);
        Assert(StrPos(GetLastErrorText(), 'Tax Group Code INVALID is invalid') > 0, 'Invalid group was not rejected.');
    end;

    [Test]
    procedure InvoiceTaxPreservesEarlierRate()
    var
        Management: Codeunit "Impress II Invoice Mgt.";
        Detail: Record "Tax Detail";
        OriginalDate: Date;
    begin
        InitializeInvoiceTax('TAXABLE');
        OriginalDate := Header."G/L Post Date";
        Management.EnsureInvoiceTaxSetup(Header);
        Header."G/L Post Date" := OriginalDate + 1;
        Header."Tax Rate 1" := 7;
        Management.EnsureInvoiceTaxSetup(Header);
        Detail.Get(Header."Tax Jurisdiction Code 1", 'TAXABLE', Detail."Tax Type"::"Sales and Use Tax", OriginalDate);
        Detail.TestField("Tax Below Maximum", 6.25);
        Detail.Get(Header."Tax Jurisdiction Code 1", 'TAXABLE', Detail."Tax Type"::"Sales and Use Tax", Header."G/L Post Date");
        Detail.TestField("Tax Below Maximum", 7);
    end;

    [Test]
    procedure InvoiceTaxRejectsOverlengthJurisdiction()
    var
        Management: Codeunit "Impress II Invoice Mgt.";
    begin
        InitializeInvoiceTax('TAXABLE');
        Header."Tax Jurisdiction Code 1" := 'TOO-LONG-JURISDICTION';
        asserterror Management.EnsureInvoiceTaxSetup(Header);
        Assert(StrPos(GetLastErrorText(), 'Tax Jurisdiction Code exceeds BC field length') > 0, 'Overlength jurisdiction was not rejected.');
    end;

    local procedure InitializeInvoiceTax(GroupCode: Code[20])
    var
        Account: Record "G/L Account";
    begin
        Clear(Header);
        Clear(InvoiceLine);
        Account."No." := 'II-TAX-GL';
        Account."Account Type" := Account."Account Type"::Posting;
        Account.Insert(false);
        Header."Source Database" := 'ImpressTest';
        Header."Document No." := 'II-TAX-TEST';
        Header."Tax Area Code" := 'II-TAX-AREA';
        Header."Tax Area Description" := 'Invoice tax area';
        Header."Tax Jurisdiction Code 1" := 'II-TAX-J';
        Header."Tax Jurisdiction Desc. 1" := 'Invoice jurisdiction';
        Header."Tax G/L Account 1" := Account."No.";
        Header."Tax Rate 1" := 6.25;
        Header."Tax Rate Total" := 6.25;
        Header."G/L Post Date" := DMY2Date(16, 9, 2026);
        Header.Insert(false);
        InvoiceLine."Sales Document Entry No." := Header."Entry No.";
        InvoiceLine.Quantity := 1;
        InvoiceLine."Tax Group Code" := GroupCode;
        InvoiceLine."Tax Group Description" := 'Invoice tax group';
        InvoiceLine.Insert(false);
    end;

    [Test]
    procedure InvoiceRelativeNumbersAndPartialQty()
    begin
        Initialize();
        AddStaged(657489, 5, 250000);
        InvoiceLine."Source Line No." := 2;
        InvoiceLine."Source Sequence" := 2;
        InvoiceLine.Quantity := 1;
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Existing line not reused.');
        Assert(Result."Line No." = 250000, 'Wrong original line.');
        Assert(Result.Quantity = 2, 'Matching changed order quantity.');
    end;

    [Test]
    procedure DuplicateStagedRawSkuErrors()
    begin
        Initialize();
        AddStaged(657489, 5, 250000);
        AddStaged(657490, 6, 260000);
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'ambiguous staged lines:') > 0, 'Duplicate raw SKU did not fail.');
        Assert(StrPos(GetLastErrorText(), '250000') > 0, 'First candidate missing.');
        Assert(StrPos(GetLastErrorText(), '260000') > 0, 'Second candidate missing.');
    end;

    [Test]
    procedure OneActualLineReusedWithoutStaging()
    begin
        Initialize();
        AddActual(10000);
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Safe BC line not reused.');
        Assert(Result."Line No." = 10000, 'Wrong BC line.');
    end;

    [Test]
    procedure MultipleActualLinesError()
    begin
        Initialize();
        AddActual(10000);
        AddActual(20000);
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'ambiguous BC lines:') > 0, 'Ambiguous BC lines did not fail.');
    end;

    [Test]
    procedure BlankVariantMatchesBlank()
    begin
        Initialize();
        InvoiceLine."BC Variant Code" := '';
        AddStaged(657489, 5, 250000);
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Blank variant not reused.');
        Assert(Result."Variant Code" = '', 'A variant was manufactured.');
    end;

    [Test]
    procedure StaleActualItemErrors()
    var
        Actual: Record "Sales Line";
    begin
        Initialize();
        AddStaged(657489, 5, 250000);
        Actual.Get(Order."Document Type", Order."No.", 250000);
        Actual."No." := 'WRONG';
        Actual.Modify(false);
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'No.') > 0, 'Stale BC line not rejected.');
    end;

    [Test]
    procedure ResourceNeverMatchesItem()
    begin
        Initialize();
        InvoiceLine."Source Line Type" := 'CHARGE';
        InvoiceLine."Size Position" := 0;
        InvoiceLine."BC Variant Code" := '';
        AddActual(10000);
        Result.Get(Order."Document Type", Order."No.", 10000);
        Result.Type := Result.Type::Resource;
        Result.Modify(false);
        AddActual(20000);
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Resource not reused.');
        Assert((Result.Type = Result.Type::Resource) and (Result."Line No." = 10000), 'Charge matched Item.');
    end;

    [Test]
    procedure DifferentSourceDoesNotMatch()
    begin
        Initialize();
        StagedHeader."Source Database" := 'STICKERSTEST';
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'Source Database') > 0, 'Cross-source order accepted.');
    end;

    [Test]
    procedure DifferentInvoiceCorrelationErrors()
    begin
        Initialize();
        AddActual(10000);
        Result.Get(Order."Document Type", Order."No.", 10000);
        Result."Impress Invoice Line Entry No." := InvoiceLine."Entry No." + 1;
        Result.Modify(false);
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'another invoice line') > 0, 'Other invoice correlation reused.');
    end;

    [Test]
    procedure SuppliedTenSizeMappings()
    var
        Position: Integer;
    begin
        Initialize();
        for Position := 1 to 5 do begin
            InvoiceLine."Size Position" := Position;
            InvoiceLine."BC Variant Code" := 'MRB-' + SizeCode(Position);
            AddStaged(657489, 5, 200000 + Position * 10000);
            Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'A603 existing size not reused.');
            Assert(Result."Line No." = 200000 + Position * 10000, 'Wrong A603 size line.');
        end;
        InvoiceLine."Source Raw SKU No." := 'A004IND';
        InvoiceLine."BC Item No." := 'A004';
        for Position := 1 to 5 do begin
            InvoiceLine."Size Position" := Position;
            InvoiceLine."BC Variant Code" := 'IND-' + SizeCode(Position);
            AddStaged(657487, 3, 100000 + Position * 10000);
            Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'A004 existing size not reused.');
            Assert(Result."Line No." = 100000 + Position * 10000, 'Wrong A004 size line.');
        end;
    end;

    [Test]
    procedure CreateMissingItemAndRetry()
    var
        Item: Record Item;
        Lines: Record "Sales Line";
        ItemUOM: Record "Item Unit of Measure";
        UOM: Record "Unit of Measure";
    begin
        Initialize();
        InvoiceLine."BC Item No." := 'II-MATCH-ITEM';
        InvoiceLine."BC Variant Code" := '';
        if not UOM.Get('EA') then begin
            UOM.Code := 'EA';
            UOM.Insert(false);
        end;
        Item."No." := InvoiceLine."BC Item No.";
        Item.Type := Item.Type::"Non-Inventory";
        Item."Base Unit of Measure" := 'EA';
        Item.Insert(false);
        ItemUOM."Item No." := Item."No.";
        ItemUOM.Code := 'EA';
        ItemUOM."Qty. per Unit of Measure" := 1;
        ItemUOM.Insert(false);
        Assert(not Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Missing line was not created.');
        Assert(Result.Type = Result.Type::Item, 'Wrong created type.');
        Assert(Result.Quantity = InvoiceLine.Quantity, 'Wrong created quantity.');
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Retry did not reuse.');
        Lines.SetRange("Document Type", Order."Document Type");
        Lines.SetRange("Document No.", Order."No.");
        Assert(Lines.Count() = 1, 'Retry created a duplicate.');
    end;

    [Test]
    procedure ExplicitOriginCreatesNewOrderLinesWithoutSkuCollision()
    var
        FirstLineNo: Integer;
        SecondLineNo: Integer;
        Lines: Record "Sales Line";
    begin
        // Establish a usable item/UOM and a line with a different correlation.
        CreateMissingItemAndRetry();
        Clear(StagedHeader);
        Header."Integration Posting ID" := CreateGuid();
        Order."Integration Posting ID" := Header."Integration Posting ID";
        Order."Impress Source Database" := Header."Source Database";
        Order.Modify(false);
        InvoiceLine."Entry No." := 778;
        InvoiceLine."Source Sales Order Line No." := 1;
        // References from a deleted order must not select a line on its replacement.
        InvoiceLine."BC Sales Line No." := 990000;
        InvoiceLine."BC Line System ID" := CreateGuid();
        Assert(not Matcher.ResolveForNewOrder(Header, InvoiceLine, Order, Result), 'New-order line was not created.');
        FirstLineNo := Result."Line No.";
        Assert(Matcher.ResolveForNewOrder(Header, InvoiceLine, Order, Result), 'Own invoice correlation was not reused.');
        Assert(Result."Line No." = FirstLineNo, 'Retry selected another line.');
        InvoiceLine."Entry No." := 779;
        InvoiceLine."Source Sales Order Line No." := 2;
        Assert(not Matcher.ResolveForNewOrder(Header, InvoiceLine, Order, Result), 'Repeated SKU incorrectly reused another invoice line.');
        SecondLineNo := Result."Line No.";
        Assert(SecondLineNo <> FirstLineNo, 'Distinct invoice lines collided.');
        Assert(Matcher.ResolveForNewOrder(Header, InvoiceLine, Order, Result), 'Second line retry was not reused.');
        Assert(Result."Line No." = SecondLineNo, 'Second line retry selected wrong correlation.');
        Lines.SetRange("Document Type", Order."Document Type");
        Lines.SetRange("Document No.", Order."No.");
        Assert(Lines.Count() = 3, 'Unexpected duplicate or missing replacement lines.');
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'originating staged Sales Order is unavailable') > 0, 'Existing-order matching was loosened.');
    end;

    [Test]
    procedure MissingStagedBCLineErrorsWithoutCreating()
    var
        Actual: Record "Sales Line";
    begin
        Initialize();
        AddStaged(657489, 5, 250000);
        Actual.Get(Order."Document Type", Order."No.", 250000);
        Actual.Delete(false);
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'is missing') > 0, 'Missing staged target did not fail.');
    end;

    [Test]
    procedure CreateMissingResourceAndRetry()
    var
        Lines: Record "Sales Line";
    begin
        Initialize();
        InvoiceLine."Source Line Type" := 'CHARGE';
        InvoiceLine."Source Item Code" := 'II-MATCH-SHIP';
        InvoiceLine."BC Item No." := 'II-MATCH-SHIP';
        InvoiceLine."BC Variant Code" := '';
        InvoiceLine."Size Position" := 0;
        Assert(not Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Missing Resource line not created.');
        Assert(Result.Type = Result.Type::Resource, 'Created a non-Resource charge.');
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Resource retry not reused.');
        Lines.SetRange("Document Type", Order."Document Type");
        Lines.SetRange("Document No.", Order."No.");
        Assert(Lines.Count() = 1, 'Resource retry duplicated line.');
    end;

    [Test]
    procedure RetryCorrelationDisambiguatesActualLines()
    begin
        Initialize();
        AddActual(10000);
        AddActual(20000);
        Result.Get(Order."Document Type", Order."No.", 20000);
        Result."Impress Invoice Line Entry No." := InvoiceLine."Entry No.";
        Result."Impress Source Database" := Header."Source Database";
        Result."Impress Raw SKU" := InvoiceLine."Source Raw SKU No.";
        Result."Impress Size Position" := InvoiceLine."Size Position";
        Result.Modify(false);
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Correlated retry not reused.');
        Assert(Result."Line No." = 20000, 'Retry ignored explicit correlation.');
    end;

    [Test]
    procedure PersistedLineSystemIdRejectsReplacement()
    begin
        Initialize();
        AddActual(10000);
        InvoiceLine."BC Sales Line No." := 10000;
        InvoiceLine."BC Line System ID" := CreateGuid();
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'SystemId') > 0, 'Replaced BC line was accepted.');
    end;

    [Test]
    procedure HeaderRecreationRefreshesVerifiedMappings()
    var
        Lifecycle: Codeunit "Impress II Line Lifecycle";
        Staged: Record "Impress Sales Line Staging";
        PreviousID: Guid;
    begin
        InitializeRecreation();
        PreviousID := Result.SystemId;
        Lifecycle.Initialize(Header, Order);
        BindSubscription(Lifecycle);
        Order.Validate("Gen. Bus. Posting Group", 'II-RECREATE');
        InvoiceLine.Get(InvoiceLine."Entry No.");
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Recreated line was not reused.');
        Assert(Result.SystemId <> PreviousID, 'Test did not recreate the physical line.');
        Assert(Result."Line No." = 10000, 'Expected standard BC renumbering was not exercised.');
        Assert(InvoiceLine."BC Line System ID" = Result.SystemId, 'Invoice reference was not refreshed.');
        Assert(InvoiceLine."BC Sales Line No." = Result."Line No.", 'Invoice line number was not refreshed.');
        Staged.SetRange("Source Sales Order Detail ID", 657489);
        Staged.FindFirst();
        Assert(Staged."BC Line System ID" = Result.SystemId, 'Order staging reference was not refreshed.');
        Assert(Staged."BC Line No." = Result."Line No.", 'Order staging line number was not refreshed.');
        Assert(Result."Impress Sales Detail ID" = 657489, 'Source detail identity was lost.');
        Assert(Result."Impress Raw SKU" = InvoiceLine."Source Raw SKU No.", 'Raw SKU was lost.');
        Assert(Result."Impress Invoice Line Entry No." = InvoiceLine."Entry No.", 'Invoice correlation was lost.');
        PreviousID := Result.SystemId;
        Order.Validate("Gen. Bus. Posting Group", '');
        UnbindSubscription(Lifecycle);
        InvoiceLine.Get(InvoiceLine."Entry No.");
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Second recreation was not tracked.');
        Assert(Result.SystemId <> PreviousID, 'Second recreation did not generate a new ID.');
        Assert(InvoiceLine."BC Line System ID" = Result.SystemId, 'Second invoice reference was stale.');
    end;

    [Test]
    procedure HeaderRecreationDoesNotRepairUnprovenGuid()
    var
        Lifecycle: Codeunit "Impress II Line Lifecycle";
        Staged: Record "Impress Sales Line Staging";
        UnprovenID: Guid;
    begin
        InitializeRecreation();
        Staged.SetRange("Source Sales Order Detail ID", 657489);
        Staged.FindFirst();
        UnprovenID := CreateGuid();
        Staged."BC Line System ID" := UnprovenID;
        Staged.Modify(false);
        Lifecycle.Initialize(Header, Order);
        BindSubscription(Lifecycle);
        Order.Validate("Gen. Bus. Posting Group", 'II-RECREATE');
        UnbindSubscription(Lifecycle);
        Staged.FindFirst();
        Assert(Staged."BC Line System ID" = UnprovenID, 'Unproven historical ID was overwritten.');
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
    end;

    [Test]
    procedure HeaderRecreationWithoutStagedOrderKeepsRetryIdentity()
    var
        Lifecycle: Codeunit "Impress II Line Lifecycle";
        Staged: Record "Impress Sales Line Staging";
        PreviousID: Guid;
    begin
        InitializeRecreation();
        Staged.SetRange("Source Sales Order Detail ID", 657489);
        Staged.DeleteAll(false);
        Clear(StagedHeader);
        Result."Impress Sales Detail ID" := 0;
        Result.Modify(false);
        PreviousID := Result.SystemId;
        Lifecycle.Initialize(Header, Order);
        BindSubscription(Lifecycle);
        Order.Validate("Gen. Bus. Posting Group", 'II-RECREATE');
        UnbindSubscription(Lifecycle);
        InvoiceLine.Get(InvoiceLine."Entry No.");
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Fallback retry identity was lost.');
        Assert(Result.SystemId <> PreviousID, 'Fallback line was not recreated.');
        Assert(Result.SystemId = InvoiceLine."BC Line System ID", 'Fallback retained the old physical ID.');
    end;

    [Test]
    procedure HeaderRecreationKeepsDuplicateSkuError()
    var
        Lifecycle: Codeunit "Impress II Line Lifecycle";
        Duplicate: Record "Impress Sales Line Staging";
    begin
        InitializeRecreation();
        Duplicate.SetRange("Source Sales Order Detail ID", 657489);
        Duplicate.FindFirst();
        Duplicate."Entry No." := 0;
        Duplicate."Source Sales Order Detail ID" := 657490;
        Duplicate."BC Line No." := 120000;
        Duplicate."BC Line System ID" := CreateGuid();
        Duplicate.Insert(false);
        Lifecycle.Initialize(Header, Order);
        BindSubscription(Lifecycle);
        Order.Validate("Gen. Bus. Posting Group", 'II-RECREATE');
        UnbindSubscription(Lifecycle);
        InvoiceLine.Get(InvoiceLine."Entry No.");
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'ambiguous staged lines:') > 0, 'Recreation bypassed duplicate SKU detection.');
    end;

    [Test]
    procedure NewOrderPostingGroupDoesNotCreateLines()
    var
        Lifecycle: Codeunit "Impress II Line Lifecycle";
        BusGroup: Record "Gen. Business Posting Group";
        Lines: Record "Sales Line";
    begin
        Initialize();
        BusGroup.Code := 'II-RECREATE';
        BusGroup.Insert(false);
        Order.SetHideValidationDialog(true);
        Lifecycle.Initialize(Header, Order);
        BindSubscription(Lifecycle);
        Order.Validate("Gen. Bus. Posting Group", BusGroup.Code);
        UnbindSubscription(Lifecycle);
        Lines.SetRange("Document Type", Order."Document Type");
        Lines.SetRange("Document No.", Order."No.");
        Assert(Lines.IsEmpty(), 'Applying the invoice posting group to an empty order created lines.');
    end;

    [Test]
    procedure UnboundRecreationDoesNotRefreshStaging()
    var
        Staged: Record "Impress Sales Line Staging";
        PreviousID: Guid;
    begin
        InitializeRecreation();
        PreviousID := Result.SystemId;
        Order.Validate("Gen. Bus. Posting Group", 'II-RECREATE');
        Staged.SetRange("Source Sales Order Detail ID", 657489);
        Staged.FindFirst();
        Assert(Staged."BC Line System ID" = PreviousID, 'Unbound handler changed staging.');
        InvoiceLine.Get(InvoiceLine."Entry No.");
        Assert(InvoiceLine."BC Line System ID" = PreviousID, 'Unbound handler changed invoice staging.');
    end;

    local procedure InitializeRecreation()
    var
        Item: Record Item;
        UOM: Record "Unit of Measure";
        ItemUOM: Record "Item Unit of Measure";
        BusGroup: Record "Gen. Business Posting Group";
        VATSetup: Record "VAT Posting Setup";
        Staged: Record "Impress Sales Line Staging";
    begin
        Initialize();
        Header."Entry No." := 778;
        InvoiceLine."Source Database" := Header."Source Database";
        InvoiceLine."Sales Document Entry No." := Header."Entry No.";
        InvoiceLine."BC Item No." := 'II-RECREATE-ITEM';
        InvoiceLine."BC Variant Code" := '';
        if not UOM.Get('EA') then begin
            UOM.Code := 'EA';
            UOM.Insert(false);
        end;
        Item."No." := InvoiceLine."BC Item No.";
        Item.Type := Item.Type::"Non-Inventory";
        Item."Base Unit of Measure" := 'EA';
        Item.Insert(false);
        ItemUOM."Item No." := Item."No.";
        ItemUOM.Code := 'EA';
        ItemUOM."Qty. per Unit of Measure" := 1;
        ItemUOM.Insert(false);
        BusGroup.Code := 'II-RECREATE';
        BusGroup.Insert(false);
        if not VATSetup.Get('', '') then
            VATSetup.Insert(false);
        Order."Impress Source Database" := StagedHeader."Source Database";
        Order."Impress Source Sales Order ID" := StagedHeader."Source Sales Order ID";
        Order.SetHideValidationDialog(true);
        Order.Modify(false);
        AddStaged(657489, 5, 110000);
        Result.Get(Order."Document Type", Order."No.", 110000);
        Result.Quantity := 0;
        Result."Unit of Measure Code" := 'EA';
        Result."Qty. per Unit of Measure" := 1;
        Result."Shipment Date" := WorkDate();
        Result."Impress Source Database" := StagedHeader."Source Database";
        Result."Impress Sales Detail ID" := 657489;
        Result."Impress Size Position" := InvoiceLine."Size Position";
        Result."Impress Raw SKU" := InvoiceLine."Source Raw SKU No.";
        Result."Impress Invoice Line Entry No." := InvoiceLine."Entry No.";
        Result.Modify(false);
        Staged.SetRange("Source Sales Order Detail ID", 657489);
        Staged.FindFirst();
        Staged."BC Document No." := Order."No.";
        Staged."BC System ID" := Order.SystemId;
        Staged."BC Line System ID" := Result.SystemId;
        Staged.Modify(false);
        InvoiceLine."BC Sales Line No." := Result."Line No.";
        InvoiceLine."BC Line System ID" := Result.SystemId;
        InvoiceLine.Insert(false);
    end;

    [Test]
    procedure PriceDoesNotResolveDuplicateSourceLines()
    begin
        Initialize();
        AddStaged(657489, 5, 250000);
        AddStaged(657490, 6, 260000);
        Result.Get(Order."Document Type", Order."No.", 250000);
        Result."Unit Price" := InvoiceLine."Unit Price";
        Result.Quantity := InvoiceLine.Quantity;
        Result.Modify(false);
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'ambiguous staged lines:') > 0, 'Quantity or price selected an ambiguous line.');
    end;

    [Test]
    procedure PersistedCorrelationReusesOneOfMultipleLines()
    begin
        Initialize();
        AddActual(10000);
        AddActual(20000);
        Result.Get(Order."Document Type", Order."No.", 20000);
        InvoiceLine."BC Sales Line No." := Result."Line No.";
        InvoiceLine."BC Line System ID" := Result.SystemId;
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Persisted line not reused.');
        Assert(Result."Line No." = 20000, 'Wrong persisted line.');
    end;

    [Test]
    procedure PostingDateUsesLinkedInventoryDate()
    var
        InvoiceMgt: Codeunit "Impress II Invoice Mgt.";
    begin
        Initialize();
        Header."Entry No." := 777;
        Header."Invoice Date" := DMY2Date(2, 5, 2026);
        AddDateTransaction(901, DMY2Date(1, 5, 2026));
        AddDateTransaction(902, DMY2Date(1, 5, 2026));
        InvoiceMgt.ResolvePostingDate(Header);
        Assert(Header."G/L Post Date" = DMY2Date(1, 5, 2026), 'Did not use linked inventory G/L date.');
    end;

    [Test]
    procedure ConflictingInventoryDatesError()
    var
        InvoiceMgt: Codeunit "Impress II Invoice Mgt.";
    begin
        Initialize();
        Header."Entry No." := 777;
        AddDateTransaction(901, DMY2Date(1, 5, 2026));
        AddDateTransaction(902, DMY2Date(2, 5, 2026));
        asserterror InvoiceMgt.ResolvePostingDate(Header);
        Assert(StrPos(GetLastErrorText(), 'different G/L dates') > 0, 'Conflicting dates not rejected.');
        Assert(Header."G/L Post Date" = 0D, 'Conflict assigned a date.');
    end;

    [Test]
    procedure MissingInventoryDateErrors()
    var
        InvoiceMgt: Codeunit "Impress II Invoice Mgt.";
    begin
        Initialize();
        Header."Entry No." := 777;
        AddDateTransaction(901, 0D);
        asserterror InvoiceMgt.ResolvePostingDate(Header);
        Assert(StrPos(GetLastErrorText(), 'G/L Date') > 0, 'Blank inventory date accepted.');
    end;

    [Test]
    procedure ExistingPostingDatePreserved()
    var
        InvoiceMgt: Codeunit "Impress II Invoice Mgt.";
    begin
        Initialize();
        Header."G/L Post Date" := DMY2Date(3, 5, 2026);
        InvoiceMgt.ResolvePostingDate(Header);
        Assert(Header."G/L Post Date" = DMY2Date(3, 5, 2026), 'Existing posting date overwritten.');
    end;

    local procedure AddDateTransaction(SourceID: Integer; PostingDate: Date)
    var
        Transaction: Record "Impress Inv Trans Staging";
        Line: Record "Impress Sales Doc Line Staging";
    begin
        Transaction."Source Database" := Header."Source Database";
        Transaction."Source Transaction ID" := SourceID;
        Transaction."Transaction Type" := 'I';
        Transaction."Transaction Source" := 'I';
        Transaction."G/L Date" := PostingDate;
        Transaction.Insert(false);
        Line."Sales Document Entry No." := Header."Entry No.";
        Line."Source Database" := Header."Source Database";
        Line."Source Line No." := SourceID;
        Line."Related Inventory Trans. ID" := SourceID;
        Line.Insert(false);
    end;

    local procedure Initialize()
    var
        Customer: Record Customer;
        SalesSetup: Record "Sales & Receivables Setup";
        GLSetup: Record "General Ledger Setup";
    begin
        Clear(Header);
        Clear(InvoiceLine);
        Clear(StagedHeader);
        Clear(Order);
        Clear(Result);
        if not SalesSetup.Get() then
            SalesSetup.Insert(false);
        if not GLSetup.Get() then
            GLSetup.Insert(false);
        GLSetup."Amount Rounding Precision" := 0.01;
        GLSetup."Unit-Amount Rounding Precision" := 0.00001;
        GLSetup.Modify(false);
        Customer."No." := 'II-MATCH-CUST';
        Customer.Insert(false);
        Header."Source Database" := 'ImpressTest';
        Header."Source Sales Order No." := 'S142846';
        Header."Document No." := '341760';
        StagedHeader."Entry No." := 1;
        StagedHeader."Source Database" := 'IMPRESSTEST';
        StagedHeader."Sales Order No." := 'S142846';
        StagedHeader."Source Sales Order ID" := 172639;
        StagedHeader."BC Document No." := 'II-MATCH-ORDER';
        Order."Document Type" := Order."Document Type"::Order;
        Order."No." := StagedHeader."BC Document No.";
        Order."Sell-to Customer No." := Customer."No.";
        Order."Bill-to Customer No." := Customer."No.";
        Order."Document Date" := DMY2Date(1, 5, 2026);
        Order."Posting Date" := Order."Document Date";
        Order.Insert(false);
        InvoiceLine."Entry No." := 777;
        InvoiceLine."Source Line Type" := 'ITEM';
        InvoiceLine."Source Raw SKU No." := 'A603MRB';
        InvoiceLine."Size Position" := 5;
        InvoiceLine."BC Item No." := 'A603';
        InvoiceLine."BC Variant Code" := 'MRB-2X';
        InvoiceLine.Quantity := 1;
        InvoiceLine."Unit Price" := 25;
    end;

    [Test]
    procedure ExplicitOriginResolvesInvoice341781()
    begin
        Initialize();
        Header."Document No." := '341781';
        Header."Source Sales Order No." := 'S143289';
        StagedHeader."Sales Order No." := Header."Source Sales Order No.";
        InvoiceLine."Source Line No." := 1;
        InvoiceLine."Source Sequence" := 1;
        InvoiceLine."Source Sales Order Line No." := 35;
        InvoiceLine."Source Raw SKU No." := 'A094BAU';
        InvoiceLine."Size Position" := 1;
        InvoiceLine."BC Item No." := 'A094';
        InvoiceLine."BC Variant Code" := 'BAU-SM';
        AddStaged(659577, 21, 990000);
        AddStaged(659591, 35, 1590000);
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Explicit source line was not reused.');
        Assert(Result."Line No." = 1590000, 'Invoice line 1 did not select source line 35.');
        InvoiceLine."Source Line No." := 2;
        InvoiceLine."Source Sequence" := 2;
        InvoiceLine."Source Sales Order Line No." := 36;
        InvoiceLine."Source Raw SKU No." := 'A094LAV';
        InvoiceLine."BC Variant Code" := 'LAV-SM';
        // Synthetic BC line for the proven source detail 659592.
        AddStaged(659592, 36, 1600000);
        Assert(Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result), 'Second explicit source line was not reused.');
        Assert(Result."Line No." = 1600000, 'Invoice line 2 did not select source line 36.');
    end;

    [Test]
    procedure ExplicitOriginCannotFallBackToOtherSourceLine()
    begin
        Initialize();
        AddStaged(659577, 21, 990000);
        InvoiceLine."Source Sales Order Line No." := 35;
        // Even a persisted BC line reference must not override the explicit origin.
        InvoiceLine."BC Sales Line No." := 990000;
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'no staged Sales Order line matches') > 0, 'Missing explicit origin used fallback.');
    end;

    [Test]
    procedure ExplicitOriginRequiresStagedOrder()
    begin
        Initialize();
        AddActual(10000);
        Clear(StagedHeader);
        InvoiceLine."Source Sales Order Line No." := 35;
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'originating staged Sales Order is unavailable') > 0, 'Explicit origin reused an unproven actual line.');
        Header."Source Sales Order No." := '';
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'requires a Source Sales Order No.') > 0, 'Missing source order was accepted.');
    end;

    [Test]
    procedure ExplicitOriginStillRejectsDuplicatesWithinSourceLine()
    begin
        Initialize();
        InvoiceLine."Source Sales Order Line No." := 35;
        AddStaged(659591, 35, 1590000);
        AddStaged(659593, 35, 1610000);
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'ambiguous staged lines:') > 0, 'Ambiguous explicit origin was accepted.');
        Assert(StrPos(GetLastErrorText(), 'originating Sales Order line 35') > 0, 'Diagnostic omitted originating source line.');
    end;

    [Test]
    procedure ExplicitOriginPreservesAllProductAndSizeFilters()
    begin
        Initialize();
        InvoiceLine."Source Sales Order Line No." := 35;
        AddStaged(659591, 35, 1590000);
        InvoiceLine."Source Raw SKU No." := 'WRONG';
        AssertExplicitOriginMismatch();
        InvoiceLine."Source Raw SKU No." := 'A603MRB';
        InvoiceLine."Size Position" := 1;
        AssertExplicitOriginMismatch();
        InvoiceLine."Size Position" := 5;
        InvoiceLine."BC Item No." := 'WRONG';
        AssertExplicitOriginMismatch();
        InvoiceLine."BC Item No." := 'A603';
        InvoiceLine."BC Variant Code" := 'WRONG';
        AssertExplicitOriginMismatch();
    end;

    local procedure AssertExplicitOriginMismatch()
    begin
        asserterror Matcher.Resolve(Header, InvoiceLine, StagedHeader, Order, Result);
        Assert(StrPos(GetLastErrorText(), 'no staged Sales Order line matches') > 0, 'Explicit origin bypassed product/size validation.');
    end;

    local procedure SizeCode(Position: Integer): Code[2]
    begin
        case Position of
            1: exit('SM');
            2: exit('MD');
            3: exit('LG');
            4: exit('XL');
            5: exit('2X');
        end;
    end;

    local procedure AddStaged(DetailID: BigInteger; SourceLine: Integer; BCLine: Integer)
    var
        Staged: Record "Impress Sales Line Staging";
    begin
        Staged."Source Database" := StagedHeader."Source Database";
        Staged."Source Sales Order ID" := StagedHeader."Source Sales Order ID";
        Staged."Sales Order No." := StagedHeader."Sales Order No.";
        Staged."Source Sales Order Detail ID" := DetailID;
        Staged."Source Line No." := SourceLine;
        Staged."Source Sequence" := SourceLine;
        Staged."BC Line Type" := 'ITEM';
        Staged."Source SKU" := InvoiceLine."Source Raw SKU No.";
        Staged."Size Position" := InvoiceLine."Size Position";
        Staged."BC Item No." := InvoiceLine."BC Item No.";
        Staged."BC Variant Code" := InvoiceLine."BC Variant Code";
        Staged."BC Line No." := BCLine;
        Staged.Insert(false);
        AddActual(BCLine);
    end;

    local procedure AddActual(LineNo: Integer)
    var
        Actual: Record "Sales Line";
    begin
        Actual."Document Type" := Order."Document Type";
        Actual."Document No." := Order."No.";
        Actual."Line No." := LineNo;
        Actual.Type := Actual.Type::Item;
        Actual."No." := InvoiceLine."BC Item No.";
        Actual."Variant Code" := InvoiceLine."BC Variant Code";
        Actual.Quantity := 2;
        Actual.Insert(false);
    end;

    local procedure Assert(Condition: Boolean; MessageText: Text)
    begin
        if not Condition then
            Error('%1', MessageText);
    end;

    var
        Header: Record "Impress Sales Doc Hdr Staging";
        InvoiceLine: Record "Impress Sales Doc Line Staging";
        StagedHeader: Record "Impress Sales Header Staging";
        Order: Record "Sales Header";
        Result: Record "Sales Line";
        Matcher: Codeunit "Impress Invoice Line Match";
}
#endif
