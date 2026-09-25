#if TG_TESTS
codeunit 80097 "Impress Profile Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RPAssignsCategoryFromReceiptAndPreservesOtherDimensions()
    var
        Defaults: Record "Impress Defaults";
        Dimension: Record Dimension;
        Value: Record "Dimension Value";
        Entry: Record "Dimension Set Entry";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Transaction: Record "Impress Inv Trans Staging";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
        Category: Codeunit "Impress Category Dimension";
        DimensionSetID: Integer;
        ValueCode: Code[20];
        ValueCodes: List of [Code[20]];
    begin
        if not Defaults.Get() then
            Defaults.Insert();
        Defaults."Category Dimension Code" := 'RP_CAT';
        Defaults.Modify();
        Dimension.Code := 'RP_CAT';
        Dimension.Insert(true);
        ValueCodes.Add('AP');
        ValueCodes.Add('ST');
        ValueCodes.Add('HG');
        foreach ValueCode in ValueCodes do begin
            Value.Init();
            Value."Dimension Code" := Dimension.Code;
            Value.Code := ValueCode;
            Value.Insert(true);
        end;
        Dimension.Code := 'RP_OTHER';
        Dimension.Insert(true);
        Value.Init();
        Value."Dimension Code" := Dimension.Code;
        Value.Code := 'KEEP';
        Value.Insert(true);
        Category.ApplyToDimensionSet(DimensionSetID, 'RP_OTHER', 'KEEP');
        Header."Document Type" := Header."Document Type"::Order;
        Header."No." := 'RP-CATEGORY';
        Header.Insert(false);
        Line."Document Type" := Header."Document Type";
        Line."Document No." := Header."No.";
        Line."Line No." := 10000;
        Line."Dimension Set ID" := DimensionSetID;
        Line.Insert(false);
        foreach ValueCode in ValueCodes do begin
            Transaction."Source Database" := 'StickersTest';
            Transaction."Division Code" := '';
            case ValueCode of
                'AP':
                    Transaction."Source Database" := 'ImpressTest';
                'HG':
                    Transaction."Division Code" := 'HG';
            end;
            Receipt.ApplyReceiptCategory(Transaction, Line);
            Line.Get(Header."Document Type", Header."No.", 10000);
            Entry.Get(Line."Dimension Set ID", 'RP_CAT');
            Entry.TestField("Dimension Value Code", ValueCode);
            Entry.Get(Line."Dimension Set ID", 'RP_OTHER');
            Entry.TestField("Dimension Value Code", 'KEEP');
        end;
    end;

    [Test]
    procedure RPReceiptHeaderTransferFieldsDoesNotCollideWithPurchaseIdentity()
    var
        PurchaseHeader: Record "Purchase Header" temporary;
        Receipt: Record "Purch. Rcpt. Header" temporary;
        PostingID: Guid;
    begin
        PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Order;
        PurchaseHeader."No." := '106472';
        PurchaseHeader."Posting Date" := 20260921D;
        PurchaseHeader."Impress Source Database" := 'ImpressTest';
        PurchaseHeader."Impress Source POrder ID" := 12345;
        PurchaseHeader."Impress Purchase Order No." := '43798';
        // Exactly the standard Purch.-Post call, with no skip-type override.
        Receipt.Init();
        Receipt.TransferFields(PurchaseHeader);
        Receipt.TestField("No.", PurchaseHeader."No.");
        Receipt.TestField("Posting Date", PurchaseHeader."Posting Date");
        AssertTrue(IsNullGuid(Receipt."Integration Posting ID"), 'Purchase identity populated the receipt posting ID.');
        Receipt.TestField("Impress Source Database", '');
        Receipt.TestField("Impress Source Transaction ID", 0);
        PostingID := CreateGuid();
        Receipt."Integration Posting ID" := PostingID;
        Receipt."Impress Source Database" := 'ImpressTest';
        Receipt."Impress Source Transaction ID" := 8763071;
        Receipt.Insert(false);
        Receipt.SetRange("Integration Posting ID", PostingID);
        Receipt.SetRange("Impress Source Database", 'ImpressTest');
        Receipt.SetRange("Impress Source Transaction ID", 8763071);
        AssertTrue(Receipt.Count() = 1, 'Receipt identity lookup failed after field replacement.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure InventoryInterimSignatureRejectsConflictsAndReusesCompleteProfile()
    var
        Setup: Record "Inventory Posting Setup";
        Interim: Dictionary of [Code[10], Code[20]];
        Result: Code[20];
        LegacyResult: Code[20];
    begin
        Initialize();
        Clear(InventoryRequirements);
        InventoryRequirements.Add('DPM', 'DPA');
        Interim.Add('DPM', 'DPA');
        CreateInventoryGroup('IMI001');
        CreateInventorySetup('DPM', 'IMI001', 'DPA');
        Setup.Get('DPM', 'IMI001');
        Setup."Inventory Account (Interim)" := 'DPB';
        Setup.Modify();
        CreateInventoryGroup('IMI002');
        CreateInventorySetup('DPM', 'IMI002', 'DPA');
        Result := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, Interim, 'R/P interim signature');
        AssertTrue(Result = 'IMI003', 'Conflicting or blank interim account was reused.');
        Setup.Get('DPM', 'IMI001');
        Setup.TestField("Inventory Account (Interim)", 'DPB');
        Setup.Get('DPM', 'IMI002');
        Setup.TestField("Inventory Account (Interim)", '');
        Setup.Get('DPM', Result);
        Setup.TestField("Inventory Account", 'DPA');
        Setup.TestField("Inventory Account (Interim)", 'DPA');
        AssertTrue(Resolver.ResolveInventoryPostingGroup(InventoryRequirements, Interim, 'R/P repeat') = Result, 'Complete R/P profile was not reused.');
        Resolver.ValidateInventoryProfile(Result, InventoryRequirements, Interim, true, 'R/P validate');
        asserterror Resolver.ValidateInventoryProfile('IMI001', InventoryRequirements, Interim, true, 'R/P conflict');
        AssertContains(GetLastErrorText(), 'Inventory Account (Interim)');
        LegacyResult := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, 'existing journal caller');
        AssertTrue(LegacyResult = 'IMI001', 'Legacy single-account matching changed.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RPRequirementsUseInterimOffsetAndConfirmedDirectCostAccount()
    var
        Transaction: Record "Impress Inv Trans Staging";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
        Setup: Record "General Posting Setup";
        Interim: Dictionary of [Code[10], Code[20]];
        Result: Code[20];
    begin
        Initialize();
        Transaction."Source Warehouse Code" := 'DPM';
        Transaction."Source Inventory G/L Account" := 'DPA';
        Transaction."Source Offset G/L Account" := 'DPB';
        Transaction."Source Adjustment G/L Account" := 'DPC';
        Receipt.BuildPostingRequirements(Transaction, GeneralRequirements, InventoryRequirements, Interim);
        AssertTrue(GeneralRequirements.Count() = 2, 'R/P added unestablished general accounts.');
        AssertTrue(GeneralRequirements.Get(Setup.FieldNo("Invt. Accrual Acc. (Interim)")) = 'DPB', 'Offset did not map to interim accrual.');
        AssertTrue(GeneralRequirements.Get(Setup.FieldNo("Direct Cost Applied Account")) = 'DPC', 'ADJ did not map to the confirmed Direct Cost Applied field.');
        AssertTrue(not GeneralRequirements.ContainsKey(Setup.FieldNo("Inventory Adjmt. Account")), 'R/P incorrectly requires Inventory Adjmt. Account.');
        AssertTrue((InventoryRequirements.Get('DPM') = 'DPA') and (Interim.Get('DPM') = 'DPA'), 'Inventory source was not used for both inventory fields.');
        CreateGeneral('DPBUS', 'ITEMS', 'DPA', 'DPA');
        Setup.Get('DPBUS', 'ITEMS');
        Setup.Blocked := true;
        Setup.Modify();
        Result := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'R/P general signature');
        Setup.Get('DPBUS', Result);
        Setup.TestField("Invt. Accrual Acc. (Interim)", 'DPB');
        Setup.TestField("Direct Cost Applied Account", 'DPC');
        Setup.TestField("Inventory Adjmt. Account", '');
        AssertTrue(Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'R/P repeat') = Result, 'R/P general profile was not reused.');
        Setup.Get('DPBUS', 'ITEMS');
        Setup.TestField(Blocked, true);
        Transaction."Source Adjustment G/L Account" := '';
        asserterror Receipt.BuildPostingRequirements(Transaction, GeneralRequirements, InventoryRequirements, Interim);
        AssertContains(GetLastErrorText(), 'Direct Cost Applied Account');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RPReportsUnrelatedBlockedLinesWithoutUnblocking()
    var
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Setup: Record "General Posting Setup";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
    begin
        Initialize();
        CreateGeneral('DPBUS', 'ITEMS', 'DPA', 'DPC');
        Setup.Get('DPBUS', 'ITEMS');
        Setup.Blocked := true;
        Setup.Modify();
        Header."Document Type" := Header."Document Type"::Order;
        Header."No." := 'DP-RP';
        Line."Document Type" := Header."Document Type";
        Line."Document No." := Header."No.";
        Line."Line No." := 20000;
        Line.Type := Line.Type::Item;
        Line."Gen. Bus. Posting Group" := 'DPBUS';
        Line."Gen. Prod. Posting Group" := 'ITEMS';
        Line.Insert();
        asserterror Receipt.CheckOtherLineSetups(Header, 10000);
        AssertContains(GetLastErrorText(), 'line 20000');
        Setup.Get('DPBUS', 'ITEMS');
        Setup.TestField(Blocked, true);
        Line.Get(Header."Document Type", Header."No.", 20000);
        Line.TestField("Gen. Prod. Posting Group", 'ITEMS');
        // The target's setup is resolved separately, not treated as unrelated.
        Receipt.CheckOtherLineSetups(Header, 20000);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RPCopiesProfilesOnlyWithinOrderAndRefreshesOnLaterReceipt()
    var
        Header: Record "Purchase Header";
        Target: Record "Purchase Line";
        Line: Record "Purchase Line";
        Setup: Record "General Posting Setup";
        Receipt: Codeunit "Impress RP Receipt Mgt.";
    begin
        Initialize();
        CreateGeneral('DPBUS', 'ITEMS', 'DPA', 'DPC');
        CreateGeneral('DPBUS', 'IMP001', 'DPA', 'DPC');
        CreateGeneral('DPBUS', 'IMP002', 'DPB', 'DPC');
        CreateInventoryGroup('IMI001');
        CreateInventoryGroup('IMI002');
        Setup.Get('DPBUS', 'ITEMS');
        Setup.Blocked := true;
        Setup.Modify();
        Header."Document Type" := Header."Document Type"::Order;
        Header."No." := 'DP-RP';
        Header.Insert(false);
        Target."Document Type" := Header."Document Type";
        Target."Document No." := Header."No.";
        Target."Line No." := 10000;
        Target.Type := Target.Type::Item;
        Target."Posting Group" := 'IMI001';
        Target."Gen. Bus. Posting Group" := 'DPBUS';
        Target."Gen. Prod. Posting Group" := 'IMP001';
        Target."Location Code" := 'DPM';
        Target.Insert(false);
        Line := Target;
        Line."Line No." := 20000;
        Line."Posting Group" := '';
        Line."Gen. Prod. Posting Group" := 'ITEMS';
        Line."Location Code" := 'DPW';
        Line.Quantity := 9;
        Line."Quantity Received" := 3;
        Line."Qty. to Receive" := 0;
        Line.Insert(false);
        Line."Document No." := 'DP-OTHER';
        Line.Insert(false);
        Line."Document No." := Header."No.";
        Line."Line No." := 30000;
        Line.Type := Line.Type::" ";
        Line.Insert(false);

        Receipt.ApplyOtherItemLinePostingGroups(Header, Target);
        Receipt.CheckOtherLineSetups(Header, Target."Line No.");
        Line.Get(Header."Document Type", Header."No.", 20000);
        Line.TestField("Posting Group", 'IMI001');
        Line.TestField("Gen. Bus. Posting Group", 'DPBUS');
        Line.TestField("Gen. Prod. Posting Group", 'IMP001');
        Line.TestField("Location Code", 'DPW');
        Line.TestField(Quantity, 9);
        Line.TestField("Quantity Received", 3);
        Line.TestField("Qty. to Receive", 0);
        Setup.Get('DPBUS', 'ITEMS');
        Setup.TestField(Blocked, true);
        Line.Get(Header."Document Type", 'DP-OTHER', 20000);
        Line.TestField("Gen. Prod. Posting Group", 'ITEMS');
        Line.TestField("Posting Group", '');
        Line.Get(Header."Document Type", Header."No.", 30000);
        Line.TestField("Gen. Prod. Posting Group", 'ITEMS');
        // A subsequent receipt's newly resolved profiles replace previous defaults.
        Target."Posting Group" := 'IMI002';
        Target."Gen. Prod. Posting Group" := 'IMP002';
        Target.Modify(false);
        Receipt.ApplyOtherItemLinePostingGroups(Header, Target);
        Receipt.ApplyOtherItemLinePostingGroups(Header, Target);
        Line.Get(Header."Document Type", Header."No.", 20000);
        Line.TestField("Posting Group", 'IMI002');
        Line.TestField("Gen. Prod. Posting Group", 'IMP002');
        Line.TestField("Qty. to Receive", 0);
        Line.TestField("Location Code", 'DPW');
        // Matching groups must not skip a blank location. Standard validation
        // must still reject moving a line with received-but-uninvoiced quantity.
        Line."Location Code" := '';
        Line."Qty. Rcd. Not Invoiced" := 3;
        Line.Modify(false);
        asserterror Receipt.ApplyOtherItemLinePostingGroups(Header, Target);
        AssertContains(GetLastErrorText(), Line.FieldCaption("Qty. Rcd. Not Invoiced"));
        Line.Get(Header."Document Type", Header."No.", 20000);
        Line.TestField("Location Code", '');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure GeneralSignatureMatchesAllAndOnlyRequiredFields()
    var
        Setup: Record "General Posting Setup";
        Result: Code[20];
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP004', 'DPC', 'DPA');
        Result := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'signature test');
        AssertTrue(Result = 'IMP004', 'An unrelated Direct Cost Applied Account prevented reuse.');
        GeneralRequirements.Add(Setup.FieldNo("Direct Cost Applied Account"), 'DPB');
        Result := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'signature test');
        AssertTrue(Result = 'IMP005', 'A mismatched required field was ignored.');
        Setup.Get('DPBUS', 'IMP004');
        AssertTrue(Setup."Direct Cost Applied Account" = 'DPA', 'Existing general profile was changed.');
        Setup.Get('DPBUS', 'IMP005');
        AssertTrue((Setup."Inventory Adjmt. Account" = 'DPC') and (Setup."Direct Cost Applied Account" = 'DPB'), 'New profile did not populate the entire signature.');
        AssertTrue(Setup."COGS Account" = '', 'An unspecified account was populated.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure InventoryCompleteMatchIsReusedRegardlessOfInputOrder()
    var
        Result: Code[20];
    begin
        Initialize();
        CreateInventoryGroup('IMI003');
        CreateInventorySetup('DPM', 'IMI003', 'DPA');
        CreateInventorySetup('DPW', 'IMI003', 'DPB');
        Clear(InventoryRequirements);
        InventoryRequirements.Add('DPW', 'DPB');
        InventoryRequirements.Add('DPM', 'DPA');
        Result := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, 'complete test');
        AssertTrue(Result = 'IMI003', 'Complete location/account profile was not reused.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure IncompleteAndConflictingInventoryProfilesRemainUntouched()
    var
        Setup: Record "Inventory Posting Setup";
        Result: Code[20];
    begin
        Initialize();
        CreateInventoryGroup('IMI004');
        CreateInventorySetup('DPM', 'IMI004', 'DPA');
        CreateInventoryGroup('IMI005');
        CreateInventorySetup('DPM', 'IMI005', 'DPB');
        CreateInventorySetup('DPW', 'IMI005', 'DPB');
        Result := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, 'immutable test');
        AssertTrue(Result = 'IMI006', 'An incomplete/conflicting profile was reused.');
        AssertTrue(not Setup.Get('DPW', 'IMI004'), 'Incomplete profile was extended.');
        Setup.Get('DPM', 'IMI005');
        AssertTrue(Setup."Inventory Account" = 'DPB', 'Conflicting profile was modified.');
        Setup.Get('DPM', 'IMI006');
        AssertTrue(Setup."Inventory Account" = 'DPA', 'New FROM relationship is wrong.');
        Setup.Get('DPW', 'IMI006');
        AssertTrue(Setup."Inventory Account" = 'DPB', 'New TO relationship is wrong.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SwappedLocationAccountsNeedAnotherProfile()
    var
        Result: Code[20];
    begin
        Initialize();
        CreateInventoryGroup('IMI001');
        CreateInventorySetup('DPM', 'IMI001', 'DPB');
        CreateInventorySetup('DPW', 'IMI001', 'DPA');
        Result := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, 'location test');
        AssertTrue(Result = 'IMI002', 'Matching considered only the account set and ignored locations.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SameAccountInventoryProfileIsValid()
    var
        Result: Code[20];
    begin
        Initialize();
        InventoryRequirements.Set('DPW', 'DPA');
        CreateInventoryGroup('IMI002');
        CreateInventorySetup('DPM', 'IMI002', 'DPA');
        CreateInventorySetup('DPW', 'IMI002', 'DPA');
        Result := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, 'same account test');
        AssertTrue(Result = 'IMI002', 'Same-account profile was rejected or duplicated.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ProfileSequencesAreIndependentAndDescriptionsEqualCodes()
    var
        GeneralCode: Code[20];
        InventoryCode: Code[20];
        GeneralGroup: Record "Gen. Product Posting Group";
        InventoryGroup: Record "Inventory Posting Group";
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP002', 'DPA', '');
        CreateInventoryGroup('IMI007');
        GeneralCode := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'sequence test');
        InventoryCode := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, 'sequence test');
        AssertTrue((GeneralCode = 'IMP003') and (InventoryCode = 'IMI008'), 'IMP and IMI sequences were coupled.');
        GeneralGroup.Get(GeneralCode);
        InventoryGroup.Get(InventoryCode);
        AssertTrue((GeneralGroup.Description = GeneralCode) and (InventoryGroup.Description = InventoryCode), 'Profile descriptions differ from their codes.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MalformedCodesAreExcludedFromSequenceAndMatching()
    var
        Result: Code[20];
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP099', 'DPA', '');
        CreateGeneral('DPBUS', 'IMP1000', 'DPC', '');
        CreateGeneral('DPBUS', 'IMPXYZ', 'DPC', '');
        Result := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'malformed code test');
        AssertTrue(Result = 'IMP100', 'General sequence/match accepted malformed codes.');
        CreateInventoryGroup('IMI005');
        CreateInventoryGroup('IMI1000');
        CreateInventorySetup('DPM', 'IMI1000', 'DPA');
        CreateInventorySetup('DPW', 'IMI1000', 'DPB');
        Result := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, 'malformed code test');
        AssertTrue(Result = 'IMI006', 'Inventory sequence/match accepted malformed codes.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure GeneralMatchingIsScopedToConfiguredBusinessGroup()
    var
        BusinessGroup: Record "Gen. Business Posting Group";
        Result: Code[20];
    begin
        Initialize();
        BusinessGroup.Code := 'DPOTHER';
        BusinessGroup.Insert(true);
        CreateGeneral('DPOTHER', 'IMP008', 'DPC', '');
        Result := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'business group test');
        AssertTrue(Result = 'IMP009', 'Resolver reused a setup under the wrong business group.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure StandardProfilesAreNotReusedOrChanged()
    var
        GeneralCode: Code[20];
        InventoryCode: Code[20];
    begin
        Initialize();
        CreateGeneral('DPBUS', 'DPSTANDARD', 'DPC', '');
        CreateInventoryGroup('DPSTANDARD');
        CreateInventorySetup('DPM', 'DPSTANDARD', 'DPA');
        CreateInventorySetup('DPW', 'DPSTANDARD', 'DPB');
        GeneralCode := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'ownership test');
        InventoryCode := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, 'ownership test');
        AssertTrue((GeneralCode = 'IMP001') and (InventoryCode = 'IMI001'), 'A standard profile was reused.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ExhaustedSequencesFailWithoutWrapping()
    var
        Result: Code[20];
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP999', 'DPA', '');
        asserterror Result := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'exhaustion test');
        AssertContains(GetLastErrorText(), 'sequence exhausted');
        CreateInventoryGroup('IMI999');
        asserterror Result := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, 'exhaustion test');
        AssertContains(GetLastErrorText(), 'sequence exhausted');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ExhaustedSequenceStillAllowsExactReuse()
    var
        Result: Code[20];
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP999', 'DPC', '');
        Result := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'full sequence reuse test');
        AssertTrue(Result = 'IMP999', 'Matching profile was rejected at sequence capacity.');
        CreateInventoryGroup('IMI999');
        CreateInventorySetup('DPM', 'IMI999', 'DPA');
        CreateInventorySetup('DPW', 'IMI999', 'DPB');
        Result := Resolver.ResolveInventoryPostingGroup(InventoryRequirements, 'full sequence reuse test');
        AssertTrue(Result = 'IMI999', 'Matching inventory profile was rejected at sequence capacity.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure InvalidAccountFailsBeforeCreatingProfile()
    var
        Setup: Record "General Posting Setup";
        Group: Record "Gen. Product Posting Group";
        Result: Code[20];
    begin
        Initialize();
        GeneralRequirements.Set(Setup.FieldNo("Inventory Adjmt. Account"), 'DP-MISSING');
        asserterror Result := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'account test');
        AssertContains(GetLastErrorText(), 'DP-MISSING is missing');
        Group.SetFilter(Code, 'IMP*');
        AssertTrue(Group.IsEmpty(), 'Invalid source account created a profile.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SignatureRejectsNonAccountFields()
    var
        Setup: Record "General Posting Setup";
        Result: Code[20];
    begin
        Initialize();
        GeneralRequirements.Add(Setup.FieldNo("Gen. Prod. Posting Group"), 'DPA');
        asserterror Result := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'field test');
        AssertContains(GetLastErrorText(), 'G/L Account field');
    end;

    [Test]
    procedure CustomerProfileReusesExactReceivables()
    var
        Group: Record "Customer Posting Group";
        Actual: Code[20];
    begin
        Initialize();
        Group.SetFilter(Code, 'IMC*');
        Group.DeleteAll();
        Group.Init();
        Group.Code := 'IMC004';
        Group."Receivables Account" := 'DPA';
        Group.Insert(false);
        Actual := Resolver.ResolveCustomerPostingGroup('DPA', 'IMC reuse');
        AssertTrue(Actual = 'IMC004', 'Exact IMC receivables profile not reused.');
        Resolver.ValidateCustomerProfile(Actual, 'DPA', 'IMC validation');
    end;

    [Test]
    procedure CustomerProfileAllocatesAfterHighestSuffix()
    var
        Group: Record "Customer Posting Group";
        Actual: Code[20];
    begin
        Initialize();
        Group.SetFilter(Code, 'IMC*');
        Group.DeleteAll();
        Group.Init();
        Group.Code := 'IMC009';
        Group."Receivables Account" := 'DPA';
        Group.Insert(false);
        Actual := Resolver.ResolveCustomerPostingGroup('DPB', 'IMC allocation');
        AssertTrue(Actual = 'IMC010', 'IMC allocation reused a gap.');
        Group.Get(Actual);
        AssertTrue(Group.Description = Actual, 'IMC description differs from code.');
        AssertTrue(Group."Receivables Account" = 'DPB', 'Wrong receivables account.');
        Group.Get('IMC009');
        AssertTrue(Group."Receivables Account" = 'DPA', 'Existing IMC group changed.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CustomerAlternativeAllowsStandardValidationAndRetry()
    var
        Group: Record "Customer Posting Group";
        Alternative: Record "Alt. Customer Posting Group";
        PostingGroupChange: Codeunit "Posting Group Change";
        Target: Code[20];
    begin
        Initialize();
        Group.Code := 'DPDOMESTIC';
        Group.Insert(true);
        Target := Resolver.ResolveCustomerPostingGroup('DPA', 'alternative test');
        asserterror PostingGroupChange.CheckCustomerPostingGroupSubstSetup(Target, Group.Code);
        Resolver.EnsureCustomerPostingGroupAlternative(Group.Code, Target);
        PostingGroupChange.CheckCustomerPostingGroupSubstSetup(Target, Group.Code);
        Resolver.EnsureCustomerPostingGroupAlternative(Group.Code, Target);
        Alternative.SetRange("Customer Posting Group", Group.Code);
        Alternative.SetRange("Alt. Customer Posting Group", Target);
        AssertTrue(Alternative.Count() = 1, 'Retry duplicated the alternative posting group.');
        AssertTrue(not Alternative.Get(Target, Group.Code), 'An unrequested reverse relationship was created.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CustomerAlternativeSupportsSuccessiveInvoiceGroups()
    var
        PostingGroupChange: Codeunit "Posting Group Change";
        Alternative: Record "Alt. Customer Posting Group";
        FirstGroup: Code[20];
        SecondGroup: Code[20];
    begin
        Initialize();
        FirstGroup := Resolver.ResolveCustomerPostingGroup('DPA', 'first invoice');
        SecondGroup := Resolver.ResolveCustomerPostingGroup('DPB', 'second invoice');
        Resolver.EnsureCustomerPostingGroupAlternative(FirstGroup, SecondGroup);
        PostingGroupChange.CheckCustomerPostingGroupSubstSetup(SecondGroup, FirstGroup);
        Resolver.EnsureCustomerPostingGroupAlternative(SecondGroup, SecondGroup);
        AssertTrue(not Alternative.Get(SecondGroup, SecondGroup), 'Created a self substitution.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ComplementaryGeneralAccountsReuseOneSetup()
    var
        Setup: Record "General Posting Setup";
        Result: Code[20];
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP001', 'DPC', '');
        Clear(GeneralRequirements);
        GeneralRequirements.Add(Setup.FieldNo("Sales Account"), 'DPA');
        GeneralRequirements.Add(Setup.FieldNo("COGS Account"), 'DPB');
        Result := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'complementary accounts');
        AssertTrue(Result = 'IMP001', 'Complementary sales accounts created another group.');
        Setup.Get('DPBUS', Result);
        AssertTrue((Setup."Sales Account" = 'DPA') and (Setup."COGS Account" = 'DPB'), 'Blank required accounts were not filled.');
        AssertTrue(Setup."Inventory Adjmt. Account" = 'DPC', 'Unrequested existing account changed.');
        AssertTrue(Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'retry') = Result, 'Retry did not reuse the extended setup.');
        GeneralRequirements.Set(Setup.FieldNo("Sales Account"), 'DPC');
        AssertTrue(Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'different revenue') = 'IMP002', 'Conflicting revenue account reused the setup.');
        Setup.Get('DPBUS', 'IMP001');
        AssertTrue(Setup."Sales Account" = 'DPA', 'Conflicting revenue replaced the existing account.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MatchingAndBlankRequiredAccountsAreCompatible()
    var
        Setup: Record "General Posting Setup";
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP001', 'DPC', '');
        GeneralRequirements.Add(Setup.FieldNo("Direct Cost Applied Account"), 'DPB');
        AssertTrue(Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'mixed required accounts') = 'IMP001', 'Matching and blank requirements did not reuse setup.');
        Setup.Get('DPBUS', 'IMP001');
        AssertTrue((Setup."Inventory Adjmt. Account" = 'DPC') and (Setup."Direct Cost Applied Account" = 'DPB'), 'Required accounts were not preserved/filled.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConflictingCandidateIsNotPartiallyFilled()
    var
        Setup: Record "General Posting Setup";
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP001', 'DPA', '');
        Clear(GeneralRequirements);
        GeneralRequirements.Add(Setup.FieldNo("Sales Account"), 'DPB');
        GeneralRequirements.Add(Setup.FieldNo("Inventory Adjmt. Account"), 'DPC');
        AssertTrue(Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'conflict after blank') = 'IMP002', 'Conflict was accepted.');
        Setup.Get('DPBUS', 'IMP001');
        AssertTrue((Setup."Sales Account" = '') and (Setup."Inventory Adjmt. Account" = 'DPA'), 'Rejected candidate was partially updated.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ExactGeneralMatchPrecedesCompatibleSetup()
    var
        Setup: Record "General Posting Setup";
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP001', '', '');
        CreateGeneral('DPBUS', 'IMP002', 'DPC', '');
        AssertTrue(Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'exact first') = 'IMP002', 'Compatible candidate took precedence over exact match.');
        Setup.Get('DPBUS', 'IMP001');
        AssertTrue(Setup."Inventory Adjmt. Account" = '', 'Exact reuse unnecessarily modified another setup.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BlockedExactGeneralSetupIsUnblockedAndReused()
    var
        Setup: Record "General Posting Setup";
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP001', '', '');
        CreateGeneral('DPBUS', 'IMP002', 'DPC', '');
        Setup.Get('DPBUS', 'IMP001');
        Setup.Blocked := true;
        Setup.Modify(false);
        Setup.Get('DPBUS', 'IMP002');
        Setup.Blocked := true;
        Setup.Modify(false);
        AssertTrue(Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'blocked') = 'IMP002', 'Blocked exact setup was not reused.');
        Setup.Get('DPBUS', 'IMP002');
        AssertTrue(not Setup.Blocked, 'Selected exact setup remained blocked.');
        Setup.Get('DPBUS', 'IMP001');
        AssertTrue(Setup.Blocked and (Setup."Inventory Adjmt. Account" = ''), 'Unselected setup was modified.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BlockedCompatibleSetupIsExtendedButConflictRemainsBlocked()
    var
        Setup: Record "General Posting Setup";
    begin
        Initialize();
        CreateGeneral('DPBUS', 'IMP001', 'DPA', '');
        CreateGeneral('DPBUS', 'IMP002', '', '');
        Setup.Get('DPBUS', 'IMP001');
        Setup.Blocked := true;
        Setup.Modify(false);
        Setup.Get('DPBUS', 'IMP002');
        Setup.Blocked := true;
        Setup.Modify(false);
        AssertTrue(Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'blocked compatible') = 'IMP002', 'Compatible blocked setup was not reused.');
        Setup.Get('DPBUS', 'IMP002');
        AssertTrue(not Setup.Blocked and (Setup."Inventory Adjmt. Account" = 'DPC'), 'Compatible setup was not filled and unblocked.');
        Setup.Get('DPBUS', 'IMP001');
        AssertTrue(Setup.Blocked and (Setup."Inventory Adjmt. Account" = 'DPA'), 'Conflicting setup was changed.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure InactiveOrderLineSetupIsUnblockedWithoutChangingItsGroup()
    var
        Order: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Setup: Record "General Posting Setup";
    begin
        Initialize();
        CreateGeneral('DPBUS', 'ITEMS', 'DPA', '');
        CreateGeneral('DPBUS', 'UNRELATED', 'DPB', '');
        Setup.Get('DPBUS', 'ITEMS');
        Setup.Blocked := true;
        Setup.Modify(false);
        Setup.Get('DPBUS', 'UNRELATED');
        Setup.Blocked := true;
        Setup.Modify(false);
        Order."Document Type" := Order."Document Type"::Order;
        Order."No." := 'DP-ORDER';
        SalesLine."Document Type" := Order."Document Type";
        SalesLine."Document No." := Order."No.";
        SalesLine."Line No." := 10000;
        SalesLine.Type := SalesLine.Type::Item;
        SalesLine."Gen. Bus. Posting Group" := 'DPBUS';
        SalesLine."Gen. Prod. Posting Group" := 'ITEMS';
        SalesLine.Insert(false);
        Resolver.PrepareInvoiceGeneralSetups(Order);
        Setup.Get('DPBUS', 'ITEMS');
        AssertTrue(not Setup.Blocked and (Setup."Inventory Adjmt. Account" = 'DPA'), 'Referenced setup was not unblocked with accounts preserved.');
        Setup.Get('DPBUS', 'UNRELATED');
        AssertTrue(Setup.Blocked, 'Unrelated setup was unblocked.');
        SalesLine.Get(Order."Document Type", Order."No.", 10000);
        AssertTrue(SalesLine."Gen. Prod. Posting Group" = 'ITEMS', 'Inactive line group was changed.');
        SalesLine."Qty. to Ship" := 1;
        SalesLine.Modify(false);
        asserterror Resolver.PrepareInvoiceGeneralSetups(Order);
        AssertContains(GetLastErrorText(), 'IMP001..IMP999');
        SalesLine."Gen. Prod. Posting Group" := Resolver.ResolveGeneralPostingSetup('DPBUS', GeneralRequirements, 'active invoice');
        SalesLine.Modify(false);
        Resolver.PrepareInvoiceGeneralSetups(Order);
    end;

    local procedure Initialize()
    var
        BusinessGroup: Record "Gen. Business Posting Group";
        GeneralGroup: Record "Gen. Product Posting Group";
        InventoryGroup: Record "Inventory Posting Group";
        Setup: Record "General Posting Setup";
    begin
        GeneralGroup.SetFilter(Code, 'IMP*');
        InventoryGroup.SetFilter(Code, 'IMI*');
        AssertTrue(GeneralGroup.IsEmpty() and InventoryGroup.IsEmpty(), 'Run profile tests in an isolated company without IMP/IMI profiles.');
        BusinessGroup.Code := 'DPBUS';
        BusinessGroup.Insert(true);
        CreateAccount('DPA');
        CreateAccount('DPB');
        CreateAccount('DPC');
        CreateLocation('DPM');
        CreateLocation('DPW');
        Clear(GeneralRequirements);
        Clear(InventoryRequirements);
        GeneralRequirements.Add(Setup.FieldNo("Inventory Adjmt. Account"), 'DPC');
        InventoryRequirements.Add('DPM', 'DPA');
        InventoryRequirements.Add('DPW', 'DPB');
    end;

    local procedure CreateAccount(AccountNo: Code[20])
    var
        Account: Record "G/L Account";
    begin
        Account."No." := AccountNo;
        Account."Account Type" := Account."Account Type"::Posting;
        Account.Insert(true);
    end;

    local procedure CreateLocation(LocationCode: Code[10])
    var
        Location: Record Location;
    begin
        Location.Code := LocationCode;
        Location.Insert(true);
    end;

    local procedure CreateGeneral(BusinessCode: Code[20]; ProductCode: Code[20]; AdjustmentAccount: Code[20]; DirectCostAccount: Code[20])
    var
        Group: Record "Gen. Product Posting Group";
        Setup: Record "General Posting Setup";
    begin
        Group.Code := ProductCode;
        Group.Description := ProductCode;
        Group.Insert(true);
        Setup."Gen. Bus. Posting Group" := BusinessCode;
        Setup."Gen. Prod. Posting Group" := ProductCode;
        Setup."Inventory Adjmt. Account" := AdjustmentAccount;
        Setup."Direct Cost Applied Account" := DirectCostAccount;
        Setup.Insert(true);
    end;

    local procedure CreateInventoryGroup(GroupCode: Code[20])
    var
        Group: Record "Inventory Posting Group";
    begin
        Group.Code := GroupCode;
        Group.Description := GroupCode;
        Group.Insert(true);
    end;

    local procedure CreateInventorySetup(LocationCode: Code[10]; GroupCode: Code[20]; AccountCode: Code[20])
    var
        Setup: Record "Inventory Posting Setup";
    begin
        Setup."Location Code" := LocationCode;
        Setup."Invt. Posting Group Code" := GroupCode;
        Setup."Inventory Account" := AccountCode;
        Setup.Insert(true);
    end;

    local procedure AssertContains(Actual: Text; Expected: Text)
    begin
        AssertTrue(StrPos(Actual, Expected) > 0, StrSubstNo('Expected [%1] in [%2].', Expected, Actual));
    end;

    local procedure AssertTrue(Condition: Boolean; Failure: Text)
    begin
        if not Condition then
            Error('%1', Failure);
    end;

    var
        Resolver: Codeunit "Impress Posting Setup Resolver";
        GeneralRequirements: Dictionary of [Integer, Code[20]];
        InventoryRequirements: Dictionary of [Code[10], Code[20]];
}
#endif
