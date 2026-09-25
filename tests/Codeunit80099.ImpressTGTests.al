#if TG_TESTS
codeunit 80099 "Impress TG Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FromSelectionPostsAndBothSelectionsAreIdempotent()
    var
        PostingID: Guid;
        EntryCount: Integer;
    begin
        Initialize(false, false);
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        PostingID := FromRow."Integration Posting ID";
        EntryCount := CountItemEntries(PostingID);
        Engine.ProcessTransactionAtomic(ToRow);
        Engine.ProcessTransactionAtomic(FromRow);
        AssertTrue(FromRow."Integration Posting ID" = PostingID, 'Retry changed the posted GUID.');
        AssertTrue(CountItemEntries(PostingID) = EntryCount, 'Retry created another posting.');
        AssertInventoryGL('TGI1', 'TGI2');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure SelectedRowsPostPairOnceAndSkipProcessedOnRetry()
    var
        Selected: Record "Impress Inv Trans Staging";
        LaterFrom: Record "Impress Inv Trans Staging";
        LaterTo: Record "Impress Inv Trans Staging";
        PostingID: Guid;
        EntryCount: Integer;
    begin
        Initialize(false, false);
        LaterFrom := FromRow;
        LaterFrom."Entry No." := 0;
        LaterFrom."Source Transaction ID" := 20;
        LaterFrom.Insert(true);
        LaterTo := ToRow;
        LaterTo."Entry No." := 0;
        LaterTo."Source Transaction ID" := 21;
        LaterTo.Insert(true);
        // Select only one side of the later pair, before marking the earlier pair.
        Selected.Get(LaterTo."Entry No.");
        Selected.Mark(true);
        Selected.Get(FromRow."Entry No.");
        Selected.Mark(true);
        Selected.Get(ToRow."Entry No.");
        Selected.Mark(true);
        Selected.MarkedOnly(true);
        Selected.Ascending(false);
        AssertTrue(Engine.ProcessSelectedTransactions(Selected) = 2, 'Selected pairs were not processed exactly once in source order.');
        AssertProcessed();
        LaterFrom.Get(LaterFrom."Entry No.");
        LaterTo.Get(LaterTo."Entry No.");
        AssertTrue(LaterFrom."Processing Status" = LaterFrom."Processing Status"::Processed, 'Unselected partner did not post.');
        AssertTrue(LaterTo."Processing Status" = LaterTo."Processing Status"::Processed, 'Later selected pair did not post.');
        PostingID := FromRow."Integration Posting ID";
        EntryCount := CountItemEntries(PostingID);
        AssertTrue(Engine.ProcessSelectedTransactions(Selected) = 0, 'Processed selection was not skipped.');
        AssertTrue(CountItemEntries(PostingID) = EntryCount, 'Selected retry duplicated ledger entries.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SelectedBatchCannotSkipEarlierUnselectedRow()
    var
        Earlier: Record "Impress Inv Trans Staging";
        Selected: Record "Impress Inv Trans Staging";
    begin
        Initialize(false, false);
        Earlier := FromRow;
        Earlier."Entry No." := -1;
        Earlier."Source Transaction ID" := 1;
        Earlier.Insert(true);
        Selected.SetRange("Entry No.", ToRow."Entry No.");
        asserterror Engine.ProcessSelectedTransactions(Selected);
        AssertContains(GetLastErrorText(), 'source sequence');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure SelectedBatchUsesExistingSalesHandlerError()
    var
        SalesRow: Record "Impress Inv Trans Staging";
        Selected: Record "Impress Inv Trans Staging";
    begin
        Initialize(false, false);
        SalesRow := FromRow;
        SalesRow."Entry No." := 0;
        SalesRow."Source Transaction ID" := 12;
        SalesRow."Transaction Type" := 'I';
        SalesRow."Transaction Source" := 'I';
        SalesRow.Insert(true);
        Selected.SetRange("Source Database", FromRow."Source Database");
        asserterror Engine.ProcessSelectedTransactions(Selected);
        AssertContains(GetLastErrorText(), 'expected exactly one Sales Document line linked by Related Inventory Transaction ID');
        FromRow.Get(FromRow."Entry No.");
        AssertTrue(FromRow."Processing Status" = FromRow."Processing Status"::Processed, 'Later failure rolled back the earlier committed pair.');
        AssertProcessed();
        // Retry reaches the same failed transaction; completed pairs stay posted.
        Selected.SetRange("Entry No.", SalesRow."Entry No.");
        asserterror Engine.ProcessSelectedTransactions(Selected);
        AssertContains(GetLastErrorText(), 'expected exactly one Sales Document line linked by Related Inventory Transaction ID');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure SelectedPostingFailurePreservesEarlierPair()
    begin
        VerifyPartialProgress(false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure SourcePostingFailurePreservesEarlierPair()
    begin
        VerifyPartialProgress(true);
    end;

    local procedure VerifyPartialProgress(UseSourceProcessor: Boolean)
    var
        LaterFrom: Record "Impress Inv Trans Staging";
        LaterTo: Record "Impress Inv Trans Staging";
        LastRow: Record "Impress Inv Trans Staging";
        Selected: Record "Impress Inv Trans Staging";
        Failure: Text;
    begin
        Initialize(false, false);
        LaterFrom := FromRow;
        LaterFrom."Entry No." := 0;
        LaterFrom."Source Transaction ID" := 20;
        LaterFrom.Quantity := -1000;
        LaterFrom."Source Adjustment G/L Account" := 'MISSING';
        LaterFrom.Insert(true);
        LaterTo := ToRow;
        LaterTo."Entry No." := 0;
        LaterTo."Source Transaction ID" := 21;
        LaterTo.Quantity := 1000;
        LaterTo."Source Adjustment G/L Account" := 'MISSING';
        LaterTo.Insert(true);
        LastRow := FromRow;
        LastRow."Entry No." := 0;
        LastRow."Source Transaction ID" := 22;
        LastRow."Transaction Type" := 'I';
        LastRow."Transaction Source" := 'I';
        LastRow.Insert(true);
        Selected.SetRange("Source Database", FromRow."Source Database");
        Selected.SetRange("Processing Status", Selected."Processing Status"::Pending);
        if UseSourceProcessor then begin
            asserterror Engine.ProcessSourceDatabase(FromRow."Source Database");
            Failure := GetLastErrorText();
        end else begin
            asserterror Engine.ProcessSelectedTransactions(Selected);
            Failure := GetLastErrorText();
        end;
        AssertContains(Failure, 'MISSING');
        AssertProcessed();
        LaterFrom.Get(LaterFrom."Entry No.");
        LaterTo.Get(LaterTo."Entry No.");
        LastRow.Get(LastRow."Entry No.");
        AssertTrue(LaterFrom."Processing Status" = LaterFrom."Processing Status"::Pending, 'Failed FROM row did not roll back.');
        AssertTrue(LaterTo."Processing Status" = LaterTo."Processing Status"::Pending, 'Failed TO row did not roll back.');
        AssertTrue(IsNullGuid(LaterFrom."Integration Posting ID") and IsNullGuid(LaterTo."Integration Posting ID"), 'Failed pair retained a new posting GUID.');
        AssertTrue(LastRow."Processing Status" = LastRow."Processing Status"::Pending, 'Processing continued beyond the failed pair.');
        asserterror Engine.ProcessTransaction(LastRow);
        AssertContains(GetLastErrorText(), 'source sequence');
        AssertProcessed();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ToSelectionPostsReverseDirection()
    var
        Group: Record "Inventory Posting Group";
    begin
        Initialize(true, false);
        Engine.ProcessTransactionAtomic(ToRow);
        AssertProcessed();
        AssertTrue(Group.Get('IMI001'), 'Dynamic inventory profile was not created.');
        AssertInventoryGL('TGI2', 'TGI1');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CategoryAsGlobalDimensionOneSurvivesPreviewAndPosting()
    begin
        VerifyGlobalCategory(1);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CategoryAsGlobalDimensionTwoSurvivesPreviewAndPosting()
    begin
        VerifyGlobalCategory(2);
    end;

    local procedure VerifyGlobalCategory(GlobalDimensionNo: Integer)
    var
        GLSetup: Record "General Ledger Setup";
        Journal: Record "Item Journal Line";
        ItemEntry: Record "Item Ledger Entry";
        DimensionEntry: Record "Dimension Set Entry";
    begin
        Initialize(false, false);
        GLSetup.Get();
        // Fixture-only setup change in an isolated AutoRollback sandbox test.
        if GlobalDimensionNo = 1 then begin
            GLSetup."Global Dimension 1 Code" := 'TG_CAT';
            GLSetup."Shortcut Dimension 1 Code" := 'TG_CAT';
        end else begin
            GLSetup."Global Dimension 2 Code" := 'TG_CAT';
            GLSetup."Shortcut Dimension 2 Code" := 'TG_CAT';
        end;
        GLSetup.Modify();
        Engine.PreviewTransaction(FromRow);
        Journal.SetRange("Integration Posting ID", FromRow."Integration Posting ID");
        AssertTrue(Journal.FindFirst(), 'Preview journal was not created.');
        AssertTrue(DimensionEntry.Get(Journal."Dimension Set ID", 'TG_CAT'), 'FROM CATEGORY disappeared on insert.');
        AssertTrue(DimensionEntry."Dimension Value Code" = 'AP', 'FROM CATEGORY changed.');
        AssertTrue(DimensionEntry.Get(Journal."New Dimension Set ID", 'TG_CAT'), 'TO CATEGORY disappeared on insert.');
        AssertTrue(DimensionEntry."Dimension Value Code" = 'AP', 'TO CATEGORY changed.');
        if GlobalDimensionNo = 1 then begin
            AssertTrue(Journal."Shortcut Dimension 1 Code" = 'AP', 'FROM global dimension 1 is missing.');
            AssertTrue(Journal."New Shortcut Dimension 1 Code" = 'AP', 'TO global dimension 1 is missing.');
        end else begin
            AssertTrue(Journal."Shortcut Dimension 2 Code" = 'AP', 'FROM global dimension 2 is missing.');
            AssertTrue(Journal."New Shortcut Dimension 2 Code" = 'AP', 'TO global dimension 2 is missing.');
        end;
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        ItemEntry.SetRange("Integration Posting ID", FromRow."Integration Posting ID");
        AssertTrue(ItemEntry.FindSet(), 'No posted item entries.');
        repeat
            AssertTrue(DimensionEntry.Get(ItemEntry."Dimension Set ID", 'TG_CAT'), 'Posted CATEGORY is missing.');
            AssertTrue(DimensionEntry."Dimension Value Code" = 'AP', 'Posted CATEGORY changed.');
            if GlobalDimensionNo = 1 then
                AssertTrue(ItemEntry."Global Dimension 1 Code" = 'AP', 'Posted global dimension 1 is missing.')
            else
                AssertTrue(ItemEntry."Global Dimension 2 Code" = 'AP', 'Posted global dimension 2 is missing.');
        until ItemEntry.Next() = 0;
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SameInventoryAccountAllowsZeroGLEntries()
    var
        Link: Record "Impress Posting Link";
    begin
        Initialize(false, true);
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        Link.SetRange("Integration Posting ID", FromRow."Integration Posting ID");
        Link.SetRange("Table ID", Database::"G/L Entry");
        AssertTrue(Link.IsEmpty(), 'Same-account transfer with identical dimensions unexpectedly created G/L entries.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SourceStreamsWithOverlappingIDsAreIndependent()
    var
        StickersFrom: Record "Impress Inv Trans Staging";
        StickersTo: Record "Impress Inv Trans Staging";
        Group: Record "Inventory Posting Group";
    begin
        Initialize(false, false);
        InsertPair('StickersTest', false, false, StickersFrom, StickersTo);
        Engine.ProcessTransactionAtomic(StickersTo);
        StickersFrom.Get(StickersFrom."Entry No.");
        FromRow.Get(FromRow."Entry No.");
        AssertTrue(StickersFrom."Processing Status" = StickersFrom."Processing Status"::Processed, 'Stickers did not post.');
        AssertTrue(FromRow."Processing Status" = FromRow."Processing Status"::Pending, 'Impress stream was changed.');
        AssertTrue(Group.Get('IMI001'), 'Stickers did not use a dynamic inventory profile.');
        Engine.ProcessTransactionAtomic(FromRow);
        AssertTrue(FromRow."Integration Posting ID" <> StickersFrom."Integration Posting ID", 'Independent postings share a GUID.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AbandonedGUIDIsReplaced()
    var
        OldID: Guid;
    begin
        Initialize(false, false);
        OldID := CreateGuid();
        SetPairID(OldID);
        Engine.ProcessTransactionAtomic(ToRow);
        AssertProcessed();
        AssertTrue(FromRow."Integration Posting ID" <> OldID, 'Abandoned GUID was reused.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ExistingJournalIsReusedAndOtherBatchLineSurvives()
    var
        Journal: Record "Item Journal Line";
        OtherJournal: Record "Item Journal Line";
        OldID: Guid;
    begin
        Initialize(false, false);
        PrepareExistingJournal(Journal);
        OldID := Journal."Integration Posting ID";
        OtherJournal := Journal;
        OtherJournal."Line No." += 10000;
        Clear(OtherJournal."Integration Posting ID");
        OtherJournal.Insert(true);
        Engine.ProcessTransactionAtomic(ToRow);
        AssertProcessed();
        AssertTrue(FromRow."Integration Posting ID" = OldID, 'Existing journal GUID was replaced.');
        AssertTrue(OtherJournal.Get(OtherJournal."Journal Template Name", OtherJournal."Journal Batch Name", OtherJournal."Line No."), 'An unrelated journal line was posted/deleted.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure EditedExistingJournalIsRejected()
    var
        Journal: Record "Item Journal Line";
    begin
        Initialize(false, false);
        PrepareExistingJournal(Journal);
        Journal.Validate(Quantity, 9);
        Journal.Modify(true);
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'Quantity');
        AssertTrue(CountItemEntries(Journal."Integration Posting ID") = 0, 'Edited journal was posted.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DeletingUnpostedJournalClearsBothIDs()
    var
        Journal: Record "Item Journal Line";
        OldID: Guid;
    begin
        Initialize(false, false);
        PrepareExistingJournal(Journal);
        OldID := Journal."Integration Posting ID";
        Journal.Delete(true);
        FromRow.Get(FromRow."Entry No.");
        ToRow.Get(ToRow."Entry No.");
        AssertTrue(IsNullGuid(FromRow."Integration Posting ID") and IsNullGuid(ToRow."Integration Posting ID"), 'Deletion did not clear both IDs.');
        Engine.ProcessTransactionAtomic(ToRow);
        AssertProcessed();
        AssertTrue(FromRow."Integration Posting ID" <> OldID, 'Deleted preparation GUID was reused.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PostedEvidenceRepairsStagingAndMissingLinks()
    var
        Link: Record "Impress Posting Link";
        PostingID: Guid;
        EntryCount: Integer;
    begin
        Initialize(false, false);
        Engine.ProcessTransactionAtomic(FromRow);
        PostingID := FromRow."Integration Posting ID";
        EntryCount := CountItemEntries(PostingID);
        Link.SetRange("Integration Posting ID", PostingID);
        Link.DeleteAll();
        ClearPostedReferences(FromRow);
        ToRow.Get(ToRow."Entry No.");
        ClearPostedReferences(ToRow);
        Engine.ProcessTransactionAtomic(ToRow);
        AssertProcessed();
        AssertTrue(CountItemEntries(PostingID) = EntryCount, 'Recovery reposted inventory.');
        AssertTrue(not Link.IsEmpty(), 'Recovery did not rebuild posting links.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PartialEvidenceNeverCreatesAnotherPosting()
    var
        Link: Record "Impress Posting Link";
        PostingID: Guid;
    begin
        Initialize(false, false);
        PostingID := CreateGuid();
        SetPairID(PostingID);
        Link."Integration Posting ID" := PostingID;
        Link."Table ID" := Database::"Item Ledger Entry";
        Link."Entry No." := -1;
        Link."Entry System ID" := CreateGuid();
        Link.Insert();
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'Posting reconciliation');
        AssertTrue(CountItemEntries(PostingID) = 0, 'Incomplete evidence caused a new posting.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FailureAfterStandardPostingRollsEverythingBack()
    var
        Hooks: Codeunit "Impress TG Test Hooks";
        ItemEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        GLEntry: Record "G/L Entry";
        Link: Record "Impress Posting Link";
        Journal: Record "Item Journal Line";
        SeriesLine: Record "No. Series Line";
        BeforeItems: Integer;
        BeforeValues: Integer;
        BeforeGL: Integer;
    begin
        Initialize(false, false);
        BeforeItems := ItemEntry.Count();
        BeforeValues := ValueEntry.Count();
        BeforeGL := GLEntry.Count();
        BindSubscription(Hooks);
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'TG injected failure after posting');
        UnbindSubscription(Hooks);
        FromRow.Get(FromRow."Entry No.");
        ToRow.Get(ToRow."Entry No.");
        AssertTrue(ItemEntry.Count() = BeforeItems, 'Item posting was not rolled back.');
        AssertTrue(ValueEntry.Count() = BeforeValues, 'Value posting was not rolled back.');
        AssertTrue(GLEntry.Count() = BeforeGL, 'G/L posting was not rolled back.');
        AssertTrue(Link.IsEmpty(), 'Posting links survived a failed transaction.');
        AssertTrue(IsNullGuid(FromRow."Integration Posting ID") and IsNullGuid(ToRow."Integration Posting ID"), 'Failed posting left GUIDs on staging.');
        AssertTrue(FromRow."Processing Status" = FromRow."Processing Status"::Pending, 'Failed posting changed status.');
        Journal.SetRange("Journal Template Name", 'TGTEST');
        AssertTrue(Journal.IsEmpty(), 'Failed posting left a created journal.');
        SeriesLine.Get('TGA', 10000);
        AssertTrue(SeriesLine."Last No. Used" = '', 'Failed posting consumed the transactional series.');
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MissingPartnerIsRejected()
    begin
        Initialize(false, false);
        ToRow.Delete();
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'adjacent partner');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MismatchedQuantityIsRejected()
    begin
        Initialize(false, false);
        ToRow.Quantity := 11;
        ToRow.Modify();
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'partner Quantity');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure EarlierUnresolvedTransactionBlocksSelectedPair()
    var
        Earlier: Record "Impress Inv Trans Staging";
    begin
        Initialize(false, false);
        Earlier := FromRow;
        Earlier."Entry No." := -1;
        Earlier."Source Transaction ID" := 1;
        Earlier.Insert(true);
        asserterror Engine.ProcessTransactionAtomic(ToRow);
        AssertContains(GetLastErrorText(), 'source sequence');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MissingNoSeriesIsRejected()
    var
        Batch: Record "Item Journal Batch";
    begin
        Initialize(false, false);
        Batch.Get('TGTEST', 'APPTEST');
        Batch."No. Series" := '';
        Batch.Modify();
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'journal batch No. Series');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConflictingInventorySetupIsNotOverwritten()
    var
        Setup: Record "Inventory Posting Setup";
    begin
        Initialize(false, false);
        CreateGroup('IMI005');
        CreateInventorySetup('TGFROM', 'IMI005', 'TGADJ');
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        Setup.Get('TGFROM', 'IMI005');
        AssertTrue(Setup."Inventory Account" = 'TGADJ', 'Conflicting setup was overwritten.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BlockedSourceInventoryAccountIsRejected()
    var
        Account: Record "G/L Account";
    begin
        Initialize(false, false);
        Account.Get('TGI2');
        Account.Blocked := true;
        Account.Modify();
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'Blocked = false');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ManualAttemptToPostExistingGUIDIsRejected()
    var
        Journal: Record "Item Journal Line";
        PostLine: Codeunit "Item Jnl.-Post Line";
    begin
        Initialize(false, false);
        Engine.ProcessTransactionAtomic(FromRow);
        Journal."Integration Posting ID" := FromRow."Integration Posting ID";
        asserterror PostLine.RunWithCheck(Journal);
        AssertContains(GetLastErrorText(), 'already has posted evidence');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BatchNumberIsPreservedDespiteSeparatePostingSeries()
    var
        Batch: Record "Item Journal Batch";
        SeriesLine: Record "No. Series Line";
    begin
        Initialize(false, false);
        CreateBatch('POSTONLY', 'TGP');
        SeriesLine.Get('TGP', 10000);
        SeriesLine."Starting No." := 'P000001';
        SeriesLine."Ending No." := 'P999999';
        SeriesLine.Modify();
        Batch.Get('TGTEST', 'APPTEST');
        Batch.Validate("Posting No. Series", 'TGP');
        Batch.Modify(true);
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        AssertTrue(FromRow."BC Posted Document No." = 'TG000001', 'The reserved batch document number was replaced.');
        SeriesLine.Get('TGP', 10000);
        AssertTrue(SeriesLine."Last No. Used" = '', 'Separate posting series was consumed despite a reserved batch number.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TransferAcrossMultipleCostLayersReconciles()
    begin
        Initialize(false, false);
        SeedInventory(FromRow."BC Location Code");
        FromRow.Quantity := -150;
        FromRow.Modify();
        ToRow.Quantity := 150;
        ToRow.Modify();
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        AssertTrue(CountItemEntries(FromRow."Integration Posting ID") >= 3, 'Expected split receipt entries across FIFO layers.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure SourceProcessorUsesTheSamePostingFlow()
    begin
        Initialize(false, false);
        Engine.ProcessSourceDatabase('ImpressTest');
        AssertProcessed();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure InvalidVariantIsRejected()
    begin
        Initialize(false, false);
        FromRow."BC Variant Code" := 'MISSING';
        FromRow.Modify();
        ToRow."BC Variant Code" := 'MISSING';
        ToRow.Modify();
        asserterror Engine.ProcessTransactionAtomic(ToRow);
        AssertContains(GetLastErrorText(), 'BC Variant Code');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BlockedCategoryIsRejected()
    var
        DimensionValue: Record "Dimension Value";
    begin
        Initialize(false, false);
        DimensionValue.Get('TG_CAT', 'AP');
        DimensionValue.Blocked := true;
        DimensionValue.Modify();
        asserterror Engine.ProcessTransactionAtomic(ToRow);
        AssertContains(GetLastErrorText(), 'Category Dimension Value Blocked');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PostedStagingCannotBeDeleted()
    begin
        Initialize(false, false);
        Engine.ProcessTransactionAtomic(FromRow);
        asserterror FromRow.Delete(true);
        AssertContains(GetLastErrorText(), 'must be retained for reconciliation');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PreviewCreatesRealProfilesAndLineWithoutPosting()
    var
        Journal: Record "Item Journal Line";
        GeneralSetup: Record "General Posting Setup";
        InventorySetup: Record "Inventory Posting Setup";
        ItemEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        GLEntry: Record "G/L Entry";
        BeforeItems: Integer;
        BeforeValues: Integer;
        BeforeGL: Integer;
    begin
        Initialize(false, false);
        BeforeItems := ItemEntry.Count();
        BeforeValues := ValueEntry.Count();
        BeforeGL := GLEntry.Count();
        PrepareExistingJournal(Journal);
        AssertTrue(Journal."Gen. Bus. Posting Group" = 'TGBUS', 'Configured business group was not applied.');
        AssertTrue(Journal."Gen. Prod. Posting Group" = 'IMP001', 'General profile is not IMP001.');
        AssertTrue(Journal."Inventory Posting Group" = 'IMI001', 'Inventory profile is not IMI001.');
        GeneralSetup.Get('TGBUS', 'IMP001');
        AssertTrue(GeneralSetup."Inventory Adjmt. Account" = 'TGADJ', 'Source adjustment account was not applied.');
        AssertTrue(GeneralSetup."COGS Account" = '', 'Unrelated general posting account was guessed.');
        InventorySetup.Get('TGFROM', 'IMI001');
        AssertTrue(InventorySetup."Inventory Account" = 'TGI1', 'FROM inventory account is wrong.');
        InventorySetup.Get('TGTO', 'IMI001');
        AssertTrue(InventorySetup."Inventory Account" = 'TGI2', 'TO inventory account is wrong.');
        AssertTrue((ItemEntry.Count() = BeforeItems) and (ValueEntry.Count() = BeforeValues) and (GLEntry.Count() = BeforeGL), 'Preview posted ledger entries.');
        AssertUnpostedPair();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RepeatedPreviewThenProcessPreservesNumberAndGUID()
    var
        Journal: Record "Item Journal Line";
        SeriesLine: Record "No. Series Line";
        ReservedDocument: Code[20];
        PostingID: Guid;
    begin
        Initialize(false, false);
        PrepareExistingJournal(Journal);
        PostingID := Journal."Integration Posting ID";
        ReservedDocument := Journal."Document No.";
        Engine.PreviewTransaction(ToRow);
        AssertTrue(Journal.Count() = 1, 'Repeated preview created another line.');
        AssertTrue(ToRow."Integration Posting ID" = PostingID, 'Repeated preview changed GUID.');
        SeriesLine.Get('TGA', 10000);
        AssertTrue(SeriesLine."Last No. Used" = ReservedDocument, 'Repeated preview consumed another number.');
        Engine.ProcessTransactionAtomic(ToRow);
        AssertProcessed();
        AssertTrue(FromRow."BC Posted Document No." = ReservedDocument, 'Posting replaced the preview document number.');
        AssertTrue(FromRow."Integration Posting ID" = PostingID, 'Posting replaced the preview GUID.');
        SeriesLine.Get('TGA', 10000);
        AssertTrue(SeriesLine."Last No. Used" = ReservedDocument, 'Posting consumed another document number.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DeletedPreviewGetsNewNumberAndReusesProfiles()
    var
        Journal: Record "Item Journal Line";
        OldNumber: Code[20];
        OldID: Guid;
        GenProd: Record "Gen. Product Posting Group";
        InventoryGroup: Record "Inventory Posting Group";
    begin
        Initialize(false, false);
        PrepareExistingJournal(Journal);
        OldNumber := Journal."Document No.";
        OldID := Journal."Integration Posting ID";
        Journal.Delete(true);
        PrepareExistingJournal(Journal);
        AssertTrue(Journal."Document No." <> OldNumber, 'Deleted number was recycled.');
        AssertTrue(Journal."Integration Posting ID" <> OldID, 'Abandoned GUID was reused.');
        GenProd.SetFilter(Code, 'IMP*');
        InventoryGroup.SetFilter(Code, 'IMI*');
        AssertTrue((GenProd.Count() = 1) and (InventoryGroup.Count() = 1), 'Replacement preview duplicated setup profiles.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BlankFromAdjustmentUsesToAccount()
    var
        Journal: Record "Item Journal Line";
    begin
        Initialize(false, false);
        FromRow."Source Adjustment G/L Account" := '';
        FromRow.Modify();
        PrepareExistingJournal(Journal);
        AssertUnpostedPair();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BlankToAdjustmentUsesFromAccount()
    var
        Journal: Record "Item Journal Line";
    begin
        Initialize(false, false);
        ToRow."Source Adjustment G/L Account" := '';
        ToRow.Modify();
        PrepareExistingJournal(Journal);
        AssertUnpostedPair();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConflictingAdjustmentAccountsAreRejected()
    begin
        Initialize(false, false);
        ToRow."Source Adjustment G/L Account" := 'TGI2';
        ToRow.Modify();
        asserterror Engine.PreviewTransaction(ToRow);
        AssertContains(GetLastErrorText(), 'pair Source Adjustment G/L Account');
        AssertNoDynamicProfiles();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BothAdjustmentAccountsBlankAreRejected()
    begin
        Initialize(false, false);
        FromRow."Source Adjustment G/L Account" := '';
        FromRow.Modify();
        ToRow."Source Adjustment G/L Account" := '';
        ToRow.Modify();
        asserterror Engine.PreviewTransaction(FromRow);
        AssertContains(GetLastErrorText(), 'both blank');
        AssertNoDynamicProfiles();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MissingInventoryBusinessGroupIsRejected()
    var
        Defaults: Record "Impress Defaults";
    begin
        Initialize(false, false);
        Defaults.Get();
        Defaults."Gen. Bus. Posting Group (Inv.)" := '';
        Defaults.Modify();
        asserterror Engine.PreviewTransaction(FromRow);
        AssertContains(GetLastErrorText(), 'Gen. Bus. Posting Group (Inv.)');
        AssertNoDynamicProfiles();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure NonexistentBusinessGroupIsNotCreated()
    var
        Defaults: Record "Impress Defaults";
        Group: Record "Gen. Business Posting Group";
    begin
        Initialize(false, false);
        Defaults.Get();
        Defaults."Gen. Bus. Posting Group (Inv.)" := 'NO-BUS';
        Defaults.Modify();
        asserterror Engine.PreviewTransaction(FromRow);
        AssertContains(GetLastErrorText(), 'NO-BUS is missing');
        AssertTrue(not Group.Get('NO-BUS'), 'Missing business group was auto-created.');
        AssertNoDynamicProfiles();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ChangedPreviewGeneralSetupStopsPosting()
    var
        Journal: Record "Item Journal Line";
        Setup: Record "General Posting Setup";
    begin
        Initialize(false, false);
        PrepareExistingJournal(Journal);
        Setup.Get(Journal."Gen. Bus. Posting Group", Journal."Gen. Prod. Posting Group");
        Setup."Inventory Adjmt. Account" := 'TGI2';
        Setup.Modify();
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'Inventory Adjmt. Account');
        AssertTrue(CountItemEntries(Journal."Integration Posting ID") = 0, 'Changed general setup was posted.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ChangedPreviewInventorySetupStopsPosting()
    var
        Journal: Record "Item Journal Line";
        Setup: Record "Inventory Posting Setup";
    begin
        Initialize(false, false);
        PrepareExistingJournal(Journal);
        Setup.Get('TGTO', Journal."Inventory Posting Group");
        Setup."Inventory Account" := 'TGADJ';
        Setup.Modify();
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'Inventory Account = TGI2');
        AssertTrue(CountItemEntries(Journal."Integration Posting ID") = 0, 'Changed inventory setup was posted.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ChangedPreviewDocumentNumberStopsPosting()
    var
        Journal: Record "Item Journal Line";
    begin
        Initialize(false, false);
        PrepareExistingJournal(Journal);
        Journal."Document No." := 'ALTERED';
        Journal.Modify();
        asserterror Engine.ProcessTransactionAtomic(ToRow);
        AssertContains(GetLastErrorText(), 'Document No.');
        AssertTrue(CountItemEntries(Journal."Integration Posting ID") = 0, 'Changed document number was posted.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FailedPostRetainsExistingPreviewAndNumber()
    var
        Journal: Record "Item Journal Line";
        Hooks: Codeunit "Impress TG Test Hooks";
        SeriesLine: Record "No. Series Line";
        ReservedDocument: Code[20];
        PostingID: Guid;
    begin
        Initialize(false, false);
        PrepareExistingJournal(Journal);
        PostingID := Journal."Integration Posting ID";
        ReservedDocument := Journal."Document No.";
        BindSubscription(Hooks);
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'TG injected failure after posting');
        UnbindSubscription(Hooks);
        AssertTrue(Journal.FindFirst(), 'Posting failure deleted the existing preview.');
        AssertTrue(CountItemEntries(PostingID) = 0, 'Failed posting left ledger entries.');
        AssertUnpostedPair();
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        AssertTrue(FromRow."BC Posted Document No." = ReservedDocument, 'Retry replaced the reserved number.');
        SeriesLine.Get('TGA', 10000);
        AssertTrue(SeriesLine."Last No. Used" = ReservedDocument, 'Failed post/retry consumed another number.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PreviewOfPostedEvidenceDoesNotCompleteStaging()
    begin
        Initialize(false, false);
        Engine.ProcessTransactionAtomic(FromRow);
        ClearPostedReferences(FromRow);
        ToRow.Get(ToRow."Entry No.");
        ClearPostedReferences(ToRow);
        Engine.PreviewTransaction(ToRow);
        FromRow.Get(FromRow."Entry No.");
        AssertTrue(FromRow."Processing Status" = FromRow."Processing Status"::Error, 'Preview completed a source row.');
        AssertTrue(ToRow."Processing Status" = ToRow."Processing Status"::Error, 'Preview completed the partner.');
        AssertTrue((FromRow."BC Posted Document No." = '') and (ToRow."BC Posted Document No." = ''), 'Preview populated final posted references.');
        Engine.ProcessTransactionAtomic(ToRow);
        AssertProcessed();
    end;

    local procedure AssertUnpostedPair()
    begin
        FromRow.Get(FromRow."Entry No.");
        ToRow.Get(ToRow."Entry No.");
        AssertTrue((FromRow."Processing Status" = FromRow."Processing Status"::Pending) and (ToRow."Processing Status" = ToRow."Processing Status"::Pending), 'Preview marked the pair Processed.');
        AssertTrue((FromRow."BC Posted Document Type" = '') and (ToRow."BC Posted Document Type" = '') and
            (FromRow."BC Posted Document No." = '') and (ToRow."BC Posted Document No." = '') and
            (FromRow."BC Posted Posting Date" = 0D) and (ToRow."BC Posted Posting Date" = 0D) and
            (FromRow."Processed Date/Time" = 0DT) and (ToRow."Processed Date/Time" = 0DT), 'Preview populated posted fields.');
        AssertTrue(not IsNullGuid(FromRow."Integration Posting ID") and (FromRow."Integration Posting ID" = ToRow."Integration Posting ID"), 'Preview GUID is missing or differs between rows.');
        AssertTrue((FromRow."Transaction Handler" = 'M-WIP RECLASSIFICATION') and (ToRow."Transaction Handler" = 'M-WIP RECLASSIFICATION'), 'Transaction Handler changed.');
    end;

    local procedure AssertNoDynamicProfiles()
    var
        GenProd: Record "Gen. Product Posting Group";
        InventoryGroup: Record "Inventory Posting Group";
    begin
        GenProd.SetFilter(Code, 'IMP*');
        InventoryGroup.SetFilter(Code, 'IMI*');
        AssertTrue(GenProd.IsEmpty() and InventoryGroup.IsEmpty(), 'Validation failure created posting profiles.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FullInventoryCreatesOnlyTransfer()
    begin
        VerifySplit(10, 5, 0, 'ImpressTest');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PartialInventoryCreatesThreeComponents()
    begin
        VerifySplit(4, 4, 1, 'ImpressTest');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ZeroInventoryCreatesOnlyAdjustments()
    begin
        VerifySplit(0, 0, 5, 'ImpressTest');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure NegativeInventoryCreatesOnlyAdjustments()
    begin
        VerifySplit(-2, 0, 5, 'ImpressTest');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure StickersUsesIndependentJournalBatches()
    begin
        VerifySplit(4, 4, 1, 'StickersTest');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure InventoryChangeMakesPreviewStale()
    begin
        InitializeSplit(4, 'ImpressTest');
        Engine.PreviewTransaction(FromRow);
        SetAvailable(3);
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'preview no longer matches current inventory');
        AssertTrue(CountItemEntries(FromRow."Integration Posting ID") = 0, 'Stale preview posted entries.');
        AssertUnpostedPair();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AvailabilityChangeWithSameSplitIsStillStale()
    begin
        InitializeSplit(10, 'ImpressTest');
        Engine.PreviewTransaction(FromRow);
        SetAvailable(11);
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'preview no longer matches current inventory');
        AssertTrue(CountItemEntries(FromRow."Integration Posting ID") = 0, 'Unchanged split hid changed availability.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ThirdComponentFailureRollsBackAllPosting()
    var
        Hooks: Codeunit "Impress TG Test Hooks";
        Journal: Record "Item Journal Line";
        PostingID: Guid;
        Link: Record "Impress Posting Link";
    begin
        InitializeSplit(4, 'ImpressTest');
        Engine.PreviewTransaction(FromRow);
        PostingID := FromRow."Integration Posting ID";
        Hooks.FailAfterComponent(3);
        BindSubscription(Hooks);
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        UnbindSubscription(Hooks);
        AssertContains(GetLastErrorText(), 'TG injected failure after posting');
        AssertTrue(CountItemEntries(PostingID) = 0, 'A partial transfer or adjustment survived.');
        Link.SetRange("Integration Posting ID", PostingID);
        AssertTrue(Link.IsEmpty(), 'Failed posting retained links.');
        Journal.SetRange("Integration Posting ID", PostingID);
        AssertTrue(Journal.Count() = 3, 'Rollback did not restore all preview components.');
        AssertUnpostedPair();
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        AssertStock(-1, 5);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ManualSplitPostingIsRejected()
    var
        Journal: Record "Item Journal Line";
        PostBatch: Codeunit "Item Jnl.-Post Batch";
    begin
        InitializeSplit(4, 'ImpressTest');
        Engine.PreviewTransaction(FromRow);
        Journal.SetRange("Integration Posting ID", FromRow."Integration Posting ID");
        Journal.FindFirst();
        Journal.SetRecFilter();
        PostBatch.SetSuppressCommit(true);
        asserterror PostBatch.Run(Journal);
        AssertContains(GetLastErrorText(), 'all components post atomically');
        AssertTrue(CountItemEntries(FromRow."Integration Posting ID") = 0, 'Manual posting left a partial transaction.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DeletedSplitComponentRequiresCompleteRegeneration()
    var
        Journal: Record "Item Journal Line";
        PostingID: Guid;
    begin
        InitializeSplit(4, 'ImpressTest');
        Engine.PreviewTransaction(FromRow);
        PostingID := FromRow."Integration Posting ID";
        Journal.SetRange("Integration Posting ID", PostingID);
        Journal.FindFirst();
        Journal.Delete(true);
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertTrue(CountItemEntries(PostingID) = 0, 'Incomplete preview was posted.');
        Journal.DeleteAll(true);
        Engine.PreviewTransaction(FromRow);
        AssertTrue(FromRow."Integration Posting ID" <> PostingID, 'Abandoned preview reused GUID.');
        AssertSplitPreview(4, 1, 'APPTEST', 'AAAPP');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PositiveAAUsesApparelItemSetup()
    begin
        VerifyAA(5, 'ImpressTest', 'AAAPP');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure NegativeAAUsesApparelItemSetup()
    begin
        VerifyAA(-5, 'ImpressTest', 'AAAPP');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PositiveAAUsesStickersItemSetup()
    begin
        VerifyAA(5, 'StickersTest', 'AASTK');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure NegativeAAUsesStickersItemSetup()
    begin
        VerifyAA(-5, 'StickersTest', 'AASTK');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BlankDivisionRetainsCategoryOnAllComponents()
    var
        Journal: Record "Item Journal Line";
        DimensionEntry: Record "Dimension Set Entry";
    begin
        InitializeSplit(4, 'ImpressTest');
        FromRow."Division Code" := '';
        FromRow.Modify();
        ToRow."Division Code" := '';
        ToRow.Modify();
        Engine.PreviewTransaction(FromRow);
        Journal.SetRange("Integration Posting ID", FromRow."Integration Posting ID");
        Journal.FindSet();
        repeat
            AssertTrue(DimensionEntry.Get(Journal."Dimension Set ID", 'TG_CAT'), 'Blank division lost CATEGORY.');
            DimensionEntry.TestField("Dimension Value Code", 'AP');
            if Journal."Entry Type" = Journal."Entry Type"::Transfer then begin
                AssertTrue(DimensionEntry.Get(Journal."New Dimension Set ID", 'TG_CAT'), 'Transfer lost TO CATEGORY.');
                DimensionEntry.TestField("Dimension Value Code", 'AP');
            end;
        until Journal.Next() = 0;
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure KnownA004BASSMPair8762353()
    var
        Item: Record Item;
        ItemUOM: Record "Item Unit of Measure";
        Variant: Record "Item Variant";
    begin
        Initialize(false, false);
        Item.Get('TG-TEST');
        Item."No." := 'A004';
        Item."Prevent Negative Inventory" := Item."Prevent Negative Inventory"::No;
        Item.Insert(true);
        ItemUOM."Item No." := 'A004';
        ItemUOM.Code := 'TGEA';
        ItemUOM."Qty. per Unit of Measure" := 1;
        ItemUOM.Insert();
        Variant."Item No." := 'A004';
        Variant.Code := 'BAS-SM';
        Variant.Insert();
        CreateLocation('M');
        CreateLocation('WIP');
        CreateInventorySetup('M', 'TGBASE', 'TGI1');
        CreateInventorySetup('WIP', 'TGBASE', 'TGI2');
        FromRow."Source Transaction ID" := 8762353;
        FromRow."BC Item No." := 'A004';
        FromRow."BC Variant Code" := 'BAS-SM';
        FromRow."BC Location Code" := 'M';
        FromRow.Quantity := -5;
        FromRow.Modify();
        ToRow."Source Transaction ID" := 8762354;
        ToRow."BC Item No." := 'A004';
        ToRow."BC Variant Code" := 'BAS-SM';
        ToRow."BC Location Code" := 'WIP';
        ToRow.Quantity := 5;
        ToRow.Modify();
        SetAvailable(4);
        Engine.PreviewTransaction(FromRow);
        AssertSplitPreview(4, 1, 'APPTEST', 'AAAPP');
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        AssertStock(-1, 5);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SourceIDOrderOverridesStagingArrivalOrder()
    var
        EarlierFrom: Record "Impress Inv Trans Staging";
        EarlierTo: Record "Impress Inv Trans Staging";
    begin
        Initialize(false, false);
        FromRow."Source Transaction ID" := 20;
        FromRow.Modify();
        ToRow."Source Transaction ID" := 21;
        ToRow.Modify();
        InsertPair('ImpressTest', false, false, EarlierFrom, EarlierTo);
        AssertTrue(EarlierFrom."Entry No." > FromRow."Entry No.", 'Fixture must arrive out of source order.');
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'source sequence');
        Engine.ProcessTransactionAtomic(EarlierFrom);
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FreshSplitFailureLeavesNoPreparationOrPosting()
    var
        Hooks: Codeunit "Impress TG Test Hooks";
        Journal: Record "Item Journal Line";
    begin
        InitializeSplit(4, 'ImpressTest');
        Hooks.FailAfterComponent(2);
        BindSubscription(Hooks);
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        UnbindSubscription(Hooks);
        AssertContains(GetLastErrorText(), 'TG injected failure after posting');
        FromRow.Get(FromRow."Entry No.");
        ToRow.Get(ToRow."Entry No.");
        AssertTrue(IsNullGuid(FromRow."Integration Posting ID") and IsNullGuid(ToRow."Integration Posting ID"), 'Failed new preparation persisted GUIDs.');
        AssertTrue(Journal.IsEmpty(), 'Failed new preparation persisted journal lines.');
        AssertStock(4, 0);
        AssertUnpostedPair();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MissingItemBatchStopsSplitBeforePosting()
    var
        Defaults: Record "Impress Defaults";
    begin
        InitializeSplit(4, 'ImpressTest');
        Defaults.Get();
        Defaults."Apparel Item Journal Batch" := '';
        Defaults.Modify();
        asserterror Engine.ProcessTransactionAtomic(FromRow);
        AssertContains(GetLastErrorText(), 'Item Journal Batch');
        AssertStock(4, 0);
        AssertUnpostedPair();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConsecutiveIdenticalPairsExcludePostedNeighbour()
    begin
        VerifyConsecutivePairOwnership(false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConsecutiveIdenticalPairsExcludePreviewNeighbour()
    begin
        VerifyConsecutivePairOwnership(true);
    end;

    local procedure VerifyConsecutivePairOwnership(PreviewFirst: Boolean)
    var
        LaterFrom: Record "Impress Inv Trans Staging";
        LaterTo: Record "Impress Inv Trans Staging";
        FirstPostingID: Guid;
    begin
        Initialize(false, false);
        InsertConsecutivePair(LaterFrom, LaterTo);
        if PreviewFirst then begin
            Engine.PreviewTransaction(FromRow);
            asserterror Engine.ProcessTransactionAtomic(LaterFrom);
            AssertContains(GetLastErrorText(), 'source sequence');
        end;
        Engine.ProcessTransactionAtomic(FromRow);
        FirstPostingID := FromRow."Integration Posting ID";
        Engine.ProcessTransactionAtomic(LaterFrom);
        LaterTo.Get(LaterTo."Entry No.");
        LaterFrom.TestField("Processing Status", LaterFrom."Processing Status"::Processed);
        LaterTo.TestField("Integration Posting ID", LaterFrom."Integration Posting ID");
        AssertTrue(LaterFrom."Integration Posting ID" <> FirstPostingID, 'Later pair reused its neighbour GUID.');
        Engine.ProcessTransactionAtomic(ToRow);
        AssertProcessed();
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LaterUnclaimedPairCannotSkipEarlierPendingPair()
    var
        LaterFrom: Record "Impress Inv Trans Staging";
        LaterTo: Record "Impress Inv Trans Staging";
    begin
        Initialize(false, false);
        InsertConsecutivePair(LaterFrom, LaterTo);
        asserterror Engine.ProcessTransactionAtomic(LaterFrom);
        AssertContains(GetLastErrorText(), 'source sequence');
        AssertTrue(IsNullGuid(LaterFrom."Integration Posting ID"), 'Ambiguous pair was claimed.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OneSidedPostedGuidStillReconciles()
    var
        PostingID: Guid;
        EntryCount: Integer;
    begin
        Initialize(false, false);
        Engine.ProcessTransactionAtomic(FromRow);
        PostingID := FromRow."Integration Posting ID";
        EntryCount := CountItemEntries(PostingID);
        Clear(FromRow."Integration Posting ID");
        FromRow.Modify();
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        AssertTrue(CountItemEntries(PostingID) = EntryCount, 'One-sided recovery reposted.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SelectingSecondPendingRowUsesFirstSourcePair()
    var
        LaterFrom: Record "Impress Inv Trans Staging";
        LaterTo: Record "Impress Inv Trans Staging";
        FirstID: Guid;
    begin
        Initialize(false, false);
        InsertConsecutivePair(LaterFrom, LaterTo);
        // All four rows are pending. Row 11 matches both 10 and 12 by movement fields.
        Engine.PreviewTransaction(ToRow);
        FromRow.Get(FromRow."Entry No.");
        FromRow.TestField("Integration Posting ID", ToRow."Integration Posting ID");
        FirstID := ToRow."Integration Posting ID";
        Engine.ProcessTransactionAtomic(ToRow);
        AssertProcessed();
        Engine.ProcessTransactionAtomic(LaterFrom);
        LaterTo.Get(LaterTo."Entry No.");
        LaterTo.TestField("Integration Posting ID", LaterFrom."Integration Posting ID");
        AssertTrue(LaterFrom."Integration Posting ID" <> FirstID, 'Adjacent pending pairs were merged.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PendingPairDoesNotAdoptProcessedNeighbourWithoutGuid()
    var
        LaterFrom: Record "Impress Inv Trans Staging";
        LaterTo: Record "Impress Inv Trans Staging";
    begin
        Initialize(false, false);
        InsertConsecutivePair(LaterFrom, LaterTo);
        Engine.ProcessTransactionAtomic(FromRow);
        ToRow.Get(ToRow."Entry No.");
        Clear(ToRow."Integration Posting ID");
        ToRow.Modify();
        // The selected pair is pending, even though the preceding compatible row is posted.
        Engine.ProcessTransactionAtomic(LaterFrom);
        LaterTo.Get(LaterTo."Entry No.");
        LaterTo.TestField("Integration Posting ID", LaterFrom."Integration Posting ID");
        LaterTo.TestField("Processing Status", LaterTo."Processing Status"::Processed);
        ToRow.Get(ToRow."Entry No.");
        AssertTrue(IsNullGuid(ToRow."Integration Posting ID"), 'Legacy neighbour was adopted into a new pair.');
    end;

    local procedure InsertConsecutivePair(var LaterFrom: Record "Impress Inv Trans Staging"; var LaterTo: Record "Impress Inv Trans Staging")
    begin
        LaterFrom := FromRow;
        LaterFrom."Entry No." := 0;
        LaterFrom."Source Transaction ID" := 12;
        LaterFrom.Insert(true);
        LaterTo := ToRow;
        LaterTo."Entry No." := 0;
        LaterTo."Source Transaction ID" := 13;
        LaterTo.Insert(true);
    end;

    local procedure VerifySplit(Available: Decimal; Transfer: Decimal; Shortage: Decimal; SourceDatabase: Text[50])
    var
        PostingID: Guid;
        Count: Integer;
    begin
        InitializeSplit(Available, SourceDatabase);
        Engine.PreviewTransaction(FromRow);
        PostingID := FromRow."Integration Posting ID";
        Engine.PreviewTransaction(ToRow);
        AssertTrue(ToRow."Integration Posting ID" = PostingID, 'Repeated preview changed GUID.');
        if SourceDatabase = 'ImpressTest' then
            AssertSplitPreview(Transfer, Shortage, 'APPTEST', 'AAAPP')
        else
            AssertSplitPreview(Transfer, Shortage, 'STKTEST', 'AASTK');
        AssertTrue(CountItemEntries(PostingID) = 0, 'Preview posted entries.');
        AssertUnpostedPair();
        Engine.ProcessTransactionAtomic(FromRow);
        AssertProcessed();
        AssertStock(Available - 5, 5);
        Count := CountItemEntries(PostingID);
        Engine.ProcessTransactionAtomic(ToRow);
        AssertTrue(CountItemEntries(PostingID) = Count, 'Split retry duplicated entries.');
    end;

    local procedure InitializeSplit(Available: Decimal; SourceDatabase: Text[50])
    var
        Item: Record Item;
    begin
        Initialize(false, false);
        Item.Get(FromRow."BC Item No.");
        Item."Prevent Negative Inventory" := Item."Prevent Negative Inventory"::No;
        Item.Modify();
        FromRow.Quantity := -5;
        ToRow.Quantity := 5;
        FromRow."Source Database" := SourceDatabase;
        ToRow."Source Database" := SourceDatabase;
        FromRow.Modify();
        ToRow.Modify();
        SetAvailable(Available);
    end;

    local procedure SetAvailable(Available: Decimal)
    var
        Journal: Record "Item Journal Line";
        Entry: Record "Item Ledger Entry";
        PostLine: Codeunit "Item Jnl.-Post Line";
        Delta: Decimal;
    begin
        Entry.SetRange("Item No.", FromRow."BC Item No.");
        Entry.SetRange("Variant Code", FromRow."BC Variant Code");
        Entry.SetRange("Location Code", FromRow."BC Location Code");
        Entry.CalcSums(Quantity);
        Delta := Available - Entry.Quantity;
        if Delta = 0 then
            exit;
        Journal."Source Code" := 'TGTEST';
        Journal.Validate("Posting Date", WorkDate());
        Journal.Validate("Document No.", 'TG-STOCK');
        if Delta > 0 then
            Journal.Validate("Entry Type", Journal."Entry Type"::"Positive Adjmt.")
        else
            Journal.Validate("Entry Type", Journal."Entry Type"::"Negative Adjmt.");
        Journal.Validate("Item No.", FromRow."BC Item No.");
        Journal.Validate("Variant Code", FromRow."BC Variant Code");
        Journal.Validate("Location Code", FromRow."BC Location Code");
        Journal.Validate(Quantity, Abs(Delta));
        Journal.Validate("Unit Amount", 10);
        Journal.Validate("Unit Cost", 10);
        PostLine.RunWithCheck(Journal);
    end;

    local procedure AssertSplitPreview(Transfer: Decimal; Shortage: Decimal; ReclassBatch: Code[10]; ItemBatch: Code[10])
    var
        Journal: Record "Item Journal Line";
        ExpectedCount: Integer;
        ActualCount: Integer;
    begin
        if Transfer > 0 then
            ExpectedCount += 1;
        if Shortage > 0 then
            ExpectedCount += 2;
        Journal.SetRange("Integration Posting ID", FromRow."Integration Posting ID");
        AssertTrue(Journal.Count() = ExpectedCount, 'Wrong preview component count.');
        Journal.FindSet();
        repeat
            if Journal."Entry Type" = Journal."Entry Type"::Transfer then begin
                Journal.TestField("Journal Template Name", 'TGTEST');
                Journal.TestField("Journal Batch Name", ReclassBatch);
                Journal.TestField(Quantity, Transfer);
                Journal.TestField("Location Code", FromRow."BC Location Code");
                Journal.TestField("New Location Code", ToRow."BC Location Code");
            end else begin
                Journal.TestField("Journal Template Name", 'TGITEM');
                Journal.TestField("Journal Batch Name", ItemBatch);
                Journal.TestField(Quantity, Shortage);
                Journal.TestField("New Location Code", '');
                if Journal."Entry Type" = Journal."Entry Type"::"Negative Adjmt." then
                    Journal.TestField("Location Code", FromRow."BC Location Code")
                else begin
                    Journal.TestField("Entry Type", Journal."Entry Type"::"Positive Adjmt.");
                    Journal.TestField("Location Code", ToRow."BC Location Code");
                end;
            end;
            Journal.TestField("Applies-to Entry", 0);
            Journal.TestField("Applies-from Entry", 0);
            ActualCount += 1;
        until Journal.Next() = 0;
        AssertTrue(ActualCount = ExpectedCount, 'Incomplete proposed structure.');
    end;

    local procedure AssertStock(FromStock: Decimal; ToStock: Decimal)
    var
        Entry: Record "Item Ledger Entry";
    begin
        Entry.SetRange("Item No.", FromRow."BC Item No.");
        Entry.SetRange("Variant Code", FromRow."BC Variant Code");
        Entry.SetRange("Location Code", FromRow."BC Location Code");
        Entry.CalcSums(Quantity);
        AssertTrue(Entry.Quantity = FromStock, 'Wrong final FROM inventory.');
        Entry.SetRange("Location Code", ToRow."BC Location Code");
        Entry.CalcSums(Quantity);
        AssertTrue(Entry.Quantity = ToStock, 'Wrong final TO inventory.');
    end;

    local procedure VerifyAA(Qty: Decimal; SourceDatabase: Text[50]; ExpectedSeries: Code[20])
    var
        Component: Record "Impress Journal Component";
        PostingID: Guid;
        Count: Integer;
    begin
        Initialize(false, false);
        ToRow.Delete();
        FromRow."Source Database" := SourceDatabase;
        FromRow."Transaction Type" := 'A';
        FromRow."Transaction Source" := 'A';
        FromRow.Quantity := Qty;
        FromRow.Modify();
        Engine.ProcessTransactionAtomic(FromRow);
        FromRow.TestField("Processing Status", FromRow."Processing Status"::Processed);
        FromRow.TestField("BC Posted Document Type", 'Item Journal');
        PostingID := FromRow."Integration Posting ID";
        Component.SetRange("Integration Posting ID", PostingID);
        AssertTrue(Component.Count() = 1, 'A/A must have one component.');
        Component.FindFirst();
        Component.TestField("No. Series", ExpectedSeries);
        Count := CountItemEntries(PostingID);
        Engine.ProcessTransactionAtomic(FromRow);
        AssertTrue(CountItemEntries(PostingID) = Count, 'A/A retry duplicated entries.');
    end;

    local procedure InitializeItemJournalSetup()
    var
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Defaults: Record "Impress Defaults";
    begin
        Template.Name := 'TGITEM';
        Template.Type := Template.Type::Item;
        Template."Source Code" := 'TGTEST';
        Template.Insert(true);
        CreateBatch('AAAPP', 'AAAPP');
        Batch.Get('TGTEST', 'AAAPP');
        Batch.Rename('TGITEM', 'AAAPP');
        CreateBatch('AASTK', 'AASTK');
        Batch.Get('TGTEST', 'AASTK');
        Batch.Rename('TGITEM', 'AASTK');
        Defaults.Get();
        Defaults."Impress Item Journal Template" := 'TGITEM';
        Defaults."Apparel Item Journal Batch" := 'AAAPP';
        Defaults."Stickers Item Journal Batch" := 'AASTK';
        Defaults.Modify();
    end;

    local procedure Initialize(ReverseDirection: Boolean; SameAccount: Boolean)
    var
        Staging: Record "Impress Inv Trans Staging";
        InventorySetup: Record "Inventory Setup";
        GLSetup: Record "General Ledger Setup";
        GenProduct: Record "Gen. Product Posting Group";
        GenBus: Record "Gen. Business Posting Group";
        GenSetup: Record "General Posting Setup";
        Item: Record Item;
        UOM: Record "Unit of Measure";
        ItemUOM: Record "Item Unit of Measure";
        Defaults: Record "Impress Defaults";
        Dimension: Record Dimension;
        Template: Record "Item Journal Template";
        SourceCode: Record "Source Code";
    begin
        // Use an isolated, initialized test company. Never erase an existing source stream.
        AssertTrue(Staging.IsEmpty(), 'Run T/G tests in a company with no inventory staging records.');
        GLSetup.Get();
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := true;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup.Modify();
        GenBus.Code := 'TGBUS';
        GenBus.Insert(true);
        CreateAccount('TGI1');
        CreateAccount('TGI2');
        CreateAccount('TGADJ');
        CreateGroup('TGBASE');
        CreateLocation('TGFROM');
        CreateLocation('TGTO');
        CreateInventorySetup('TGFROM', 'TGBASE', 'TGI1');
        CreateInventorySetup('TGTO', 'TGBASE', 'TGI2');
        GenProduct.Code := 'TGTEST';
        GenProduct.Insert(true);
        GenSetup."Gen. Prod. Posting Group" := 'TGTEST';
        GenSetup."Inventory Adjmt. Account" := 'TGADJ';
        GenSetup."COGS Account" := 'TGADJ';
        GenSetup.Insert(true);
        UOM.Code := 'TGEA';
        UOM.Insert(true);
        Item."No." := 'TG-TEST';
        Item."Inventory Posting Group" := 'TGBASE';
        Item."Gen. Prod. Posting Group" := 'TGTEST';
        Item."Costing Method" := Item."Costing Method"::FIFO;
        Item.Insert(true);
        ItemUOM."Item No." := Item."No.";
        ItemUOM.Code := 'TGEA';
        ItemUOM."Qty. per Unit of Measure" := 1;
        ItemUOM.Insert(true);
        Item.Validate("Base Unit of Measure", 'TGEA');
        Item.Modify(true);
        Dimension.Code := 'TG_CAT';
        Dimension.Insert(true);
        CreateDimensionValue('AP');
        CreateDimensionValue('ST');
        SourceCode.Code := 'TGTEST';
        SourceCode.Insert(true);
        Template.Name := 'TGTEST';
        Template.Type := Template.Type::Transfer;
        Template."Source Code" := 'TGTEST';
        Template.Insert(true);
        CreateBatch('APPTEST', 'TGA');
        CreateBatch('STKTEST', 'TGS');
        if not Defaults.Get() then
            Defaults.Insert(true);
        Defaults."Gen. Bus. Posting Group (Inv.)" := 'TGBUS';
        Defaults."Category Dimension Code" := 'TG_CAT';
        Defaults."Impress Reclass Jnl. Template" := 'TGTEST';
        Defaults."Apparel Reclass Journal Batch" := 'APPTEST';
        Defaults."Stickers Reclass Journal Batch" := 'STKTEST';
        Defaults.Modify(true);
        InitializeItemJournalSetup();
        InsertPair('ImpressTest', ReverseDirection, SameAccount, FromRow, ToRow);
        SeedInventory(FromRow."BC Location Code");
    end;

    local procedure InsertPair(SourceDatabase: Text[50]; ReverseDirection: Boolean; SameAccount: Boolean; var NewFrom: Record "Impress Inv Trans Staging"; var NewTo: Record "Impress Inv Trans Staging")
    begin
        NewFrom.Init();
        NewFrom."Entry No." := 0;
        NewFrom."Source Database" := SourceDatabase;
        NewFrom."Division Code" := '';
        NewFrom."Source Transaction ID" := 10;
        NewFrom."Transaction Type" := 'T';
        NewFrom."Transaction Source" := 'G';
        NewFrom."Transaction Handler" := 'M-WIP RECLASSIFICATION';
        NewFrom."Transport Status" := NewFrom."Transport Status"::Sent;
        NewFrom."G/L Date" := WorkDate();
        NewFrom."BC Item No." := 'TG-TEST';
        NewFrom."BC Location Code" := 'TGFROM';
        NewFrom."Source Inventory G/L Account" := 'TGI1';
        NewFrom."Source Order No." := 'TG-ORDER';
        NewFrom."Source Adjustment G/L Account" := 'TGADJ';
        // These unrelated source accounts must still be ignored.
        NewFrom."Source G/L Account" := 'DOES-NOT-EXIST';
        NewFrom."Source Offset G/L Account" := 'DOES-NOT-EXIST';
        NewFrom.Quantity := -10;
        if ReverseDirection then begin
            NewFrom."BC Location Code" := 'TGTO';
            NewFrom."Source Inventory G/L Account" := 'TGI2';
        end;
        NewFrom.Insert(true);
        NewTo := NewFrom;
        NewTo."Entry No." := 0;
        NewTo."Source Transaction ID" := 11;
        NewTo.Quantity := 10;
        NewTo."BC Location Code" := 'TGTO';
        NewTo."Source Inventory G/L Account" := 'TGI2';
        if ReverseDirection then begin
            NewTo."BC Location Code" := 'TGFROM';
            NewTo."Source Inventory G/L Account" := 'TGI1';
        end;
        if SameAccount then
            NewTo."Source Inventory G/L Account" := NewFrom."Source Inventory G/L Account";
        NewTo.Insert(true);
    end;

    local procedure SeedInventory(LocationCode: Code[10])
    var
        Journal: Record "Item Journal Line";
        PostLine: Codeunit "Item Jnl.-Post Line";
    begin
        Journal."Source Code" := 'TGTEST';
        Journal.Validate("Posting Date", WorkDate());
        Journal.Validate("Document No.", 'TG-OPEN');
        Journal.Validate("Entry Type", Journal."Entry Type"::"Positive Adjmt.");
        Journal.Validate("Item No.", 'TG-TEST');
        Journal.Validate("Location Code", LocationCode);
        Journal.Validate(Quantity, 100);
        Journal.Validate("Unit Amount", 10);
        Journal.Validate("Unit Cost", 10);
        PostLine.RunWithCheck(Journal);
    end;

    local procedure PrepareExistingJournal(var Journal: Record "Item Journal Line")
    begin
        Engine.PreviewTransaction(FromRow);
        ToRow.Get(ToRow."Entry No.");
        Journal.SetRange("Integration Posting ID", FromRow."Integration Posting ID");
        AssertTrue(Journal.FindFirst(), 'Preview did not create its actual journal.');
    end;

    local procedure SetPairID(PostingID: Guid)
    begin
        FromRow."Integration Posting ID" := PostingID;
        FromRow.Modify();
        ToRow."Integration Posting ID" := PostingID;
        ToRow.Modify();
    end;

    local procedure ClearPostedReferences(var Row: Record "Impress Inv Trans Staging")
    begin
        Row."Processing Status" := Row."Processing Status"::Error;
        Clear(Row."BC Posted Document Type");
        Clear(Row."BC Posted Document No.");
        Clear(Row."BC Posted Posting Date");
        Clear(Row."Processed Date/Time");
        Row.Modify();
    end;

    local procedure CreateAccount(AccountNo: Code[20])
    var
        Account: Record "G/L Account";
    begin
        Account."No." := AccountNo;
        Account.Name := AccountNo;
        Account."Account Type" := Account."Account Type"::Posting;
        Account."Income/Balance" := Account."Income/Balance"::"Balance Sheet";
        Account."Direct Posting" := true;
        Account.Insert(true);
    end;

    local procedure CreateGroup(GroupCode: Code[20])
    var
        Group: Record "Inventory Posting Group";
    begin
        Group.Code := GroupCode;
        Group.Description := GroupCode;
        Group.Insert(true);
    end;

    local procedure CreateLocation(LocationCode: Code[10])
    var
        Location: Record Location;
    begin
        Location.Code := LocationCode;
        Location.Insert(true);
    end;

    local procedure CreateInventorySetup(LocationCode: Code[10]; GroupCode: Code[20]; AccountNo: Code[20])
    var
        Setup: Record "Inventory Posting Setup";
    begin
        Setup."Location Code" := LocationCode;
        Setup."Invt. Posting Group Code" := GroupCode;
        Setup."Inventory Account" := AccountNo;
        Setup.Insert(true);
    end;

    local procedure CreateDimensionValue(ValueCode: Code[20])
    var
        Value: Record "Dimension Value";
    begin
        Value."Dimension Code" := 'TG_CAT';
        Value.Code := ValueCode;
        Value.Insert(true);
    end;

    local procedure CreateBatch(BatchName: Code[10]; SeriesCode: Code[20])
    var
        Batch: Record "Item Journal Batch";
        Series: Record "No. Series";
        SeriesLine: Record "No. Series Line";
    begin
        Series.Code := SeriesCode;
        Series."Default Nos." := true;
        Series.Insert(true);
        SeriesLine."Series Code" := SeriesCode;
        SeriesLine."Line No." := 10000;
        SeriesLine."Starting No." := 'TG000001';
        SeriesLine."Ending No." := 'TG999999';
        SeriesLine."Increment-by No." := 1;
        SeriesLine.Insert(true);
        Batch."Journal Template Name" := 'TGTEST';
        Batch.Name := BatchName;
        Batch."No. Series" := SeriesCode;
        Batch.Insert(true);
    end;

    local procedure AssertProcessed()
    var
        Item: Record Item;
    begin
        FromRow.Get(FromRow."Entry No.");
        ToRow.Get(ToRow."Entry No.");
        AssertTrue(FromRow."Processing Status" = FromRow."Processing Status"::Processed, 'FROM is not Processed.');
        AssertTrue(ToRow."Processing Status" = ToRow."Processing Status"::Processed, 'TO is not Processed.');
        AssertTrue(not IsNullGuid(FromRow."Integration Posting ID"), 'Posted GUID is blank.');
        AssertTrue(FromRow."Integration Posting ID" = ToRow."Integration Posting ID", 'Pair GUIDs differ.');
        AssertTrue(FromRow."BC Posted Document Type" = 'Item Reclassification', 'Posted document type is wrong.');
        AssertTrue(FromRow."BC Posted Document Type" = ToRow."BC Posted Document Type", 'Posted document types differ.');
        AssertTrue((FromRow."BC Posted Document No." <> '') and (FromRow."BC Posted Document No." = ToRow."BC Posted Document No."), 'Posted document references are missing/different.');
        AssertTrue((FromRow."BC Posted Posting Date" = WorkDate()) and (FromRow."BC Posted Posting Date" = ToRow."BC Posted Posting Date"), 'Posted dates differ.');
        AssertTrue((FromRow."Processed Date/Time" <> 0DT) and (FromRow."Processed Date/Time" = ToRow."Processed Date/Time"), 'Processed timestamps differ.');
        AssertTrue(FromRow."Transaction Handler" = 'M-WIP RECLASSIFICATION', 'Transaction Handler was overwritten.');
        AssertTrue(ToRow."Transaction Handler" = 'M-WIP RECLASSIFICATION', 'Partner Transaction Handler was overwritten.');
        Item.Get('TG-TEST');
        AssertTrue(Item."Inventory Posting Group" = 'TGBASE', 'Permanent Item posting group changed.');
        AssertTrue(Item."Gen. Prod. Posting Group" = 'TGTEST', 'Permanent Item general product posting group changed.');
    end;

    local procedure AssertInventoryGL(FromAccount: Code[20]; ToAccount: Code[20])
    var
        Link: Record "Impress Posting Link";
        Entry: Record "G/L Entry";
        FromAmount: Decimal;
        ToAmount: Decimal;
    begin
        Link.SetRange("Integration Posting ID", FromRow."Integration Posting ID");
        Link.SetRange("Table ID", Database::"G/L Entry");
        if Link.FindSet() then
            repeat
                Entry.Get(Link."Entry No.");
                if Entry."G/L Account No." = FromAccount then
                    FromAmount += Entry.Amount;
                if Entry."G/L Account No." = ToAccount then
                    ToAmount += Entry.Amount;
            until Link.Next() = 0;
        AssertTrue(FromAmount = -100, 'Expected a 100 credit to FROM inventory.');
        AssertTrue(ToAmount = 100, 'Expected a 100 debit to TO inventory.');
    end;

    local procedure CountItemEntries(PostingID: Guid): Integer
    var
        Entry: Record "Item Ledger Entry";
    begin
        Entry.SetRange("Integration Posting ID", PostingID);
        exit(Entry.Count());
    end;

    local procedure AssertContains(Actual: Text; Expected: Text)
    begin
        AssertTrue(StrPos(Actual, Expected) > 0, StrSubstNo('Expected error containing [%1], got [%2].', Expected, Actual));
    end;

    local procedure AssertTrue(Condition: Boolean; Failure: Text)
    begin
        if not Condition then
            Error('%1', Failure);
    end;

    var
        FromRow: Record "Impress Inv Trans Staging";
        ToRow: Record "Impress Inv Trans Staging";
        Engine: Codeunit "Impress Trans. Posting Engine";
}
#endif

