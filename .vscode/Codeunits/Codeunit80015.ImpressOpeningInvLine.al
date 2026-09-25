codeunit 80015 "Impress Opening Inv. Line"
{
    TableNo = "Impress Opening Inventory";
    Permissions = tabledata "Item Journal Line" = RIMD;

    trigger OnRun()
    begin
        ProcessLine(Rec);
    end;

    local procedure ProcessLine(var Staging: Record "Impress Opening Inventory")
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        if Staging."Send Status" = Staging."Send Status"::Processed then
            exit;

        Staging."Send Status" := Staging."Send Status"::Processing;
        Clear(Staging."Error Message");
        Staging.Modify(true);

        if Staging.Quantity = 0 then begin
            Staging."Send Status" := Staging."Send Status"::Ignored;
            Staging."Error Message" := CopyStr(
                StrSubstNo('Run ID %1, BC Line No. %2 was skipped because Quantity is zero.', Staging."Run ID", Staging."BC Line No."),
                1, MaxStrLen(Staging."Error Message"));
            Staging."Processed Date Time" := CurrentDateTime();
            Staging.Modify(true);
            exit;
        end;

        ValidateStagingReferences(Staging);
        if FindExistingJournalLine(Staging, ItemJournalLine) then begin
            MarkProcessed(Staging, ItemJournalLine);
            exit;
        end;
        EnsureRequestedLineNoAvailable(Staging);
        InsertJournalLine(Staging, ItemJournalLine);
        MarkProcessed(Staging, ItemJournalLine);
    end;

    local procedure ValidateStagingReferences(Staging: Record "Impress Opening Inventory")
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Location: Record Location;
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        if Staging."Posting Date" = 0D then
            Error('Run ID %1, BC Line No. %2: Posting Date is required.', Staging."Run ID", Staging."BC Line No.");
        if Staging."BC Line No." = 0 then
            Error('Run ID %1: BC Line No. is required.', Staging."Run ID");
        if not Item.Get(Staging."Item No.") then
            Error(
                'Run ID %1, BC Line No. %2: BC Item %3 / Variant %4 does not exist. Impress source: Item %5 / Size %6.',
                Staging."Run ID", Staging."BC Line No.", Staging."Item No.", Staging."Variant Code",
                Staging."Impress Item No.", Staging."Impress Variant Code");
        if (Staging."Variant Code" <> '') and not ItemVariant.Get(Staging."Item No.", Staging."Variant Code") then
            Error(
                'Run ID %1, BC Line No. %2: BC Item %3 / Variant %4 does not exist. Impress source: Item %5 / Size %6.',
                Staging."Run ID", Staging."BC Line No.", Staging."Item No.", Staging."Variant Code",
                Staging."Impress Item No.", Staging."Impress Variant Code");
        if not Location.Get(Staging."Location Code") then
            Error('Run ID %1, BC Line No. %2: Location %3 does not exist.', Staging."Run ID", Staging."BC Line No.", Staging."Location Code");
        if (Staging.Quantity > 0) and (Staging."Unit Cost" < 0) then
            Error('Run ID %1, BC Line No. %2: positive opening inventory cannot have negative Unit Cost %3.', Staging."Run ID", Staging."BC Line No.", Staging."Unit Cost");
        if not ItemJournalTemplate.Get(Staging."Journal Template Name") then
            Error('Run ID %1: Item Journal Template %2 does not exist.', Staging."Run ID", Staging."Journal Template Name");
        if not ItemJournalBatch.Get(Staging."Journal Template Name", Staging."Journal Batch Name") then
            Error('Run ID %1: Item Journal Batch %2/%3 does not exist.', Staging."Run ID", Staging."Journal Template Name", Staging."Journal Batch Name");
    end;

    local procedure FindExistingJournalLine(Staging: Record "Impress Opening Inventory"; var ItemJournalLine: Record "Item Journal Line"): Boolean
    begin
        if not IsNullGuid(Staging."BC Journal Line System ID") then
            if ItemJournalLine.GetBySystemId(Staging."BC Journal Line System ID") then
                exit(true);
        ItemJournalLine.Reset();
        ItemJournalLine.SetRange("Journal Template Name", Staging."Journal Template Name");
        ItemJournalLine.SetRange("Journal Batch Name", Staging."Journal Batch Name");
        ItemJournalLine.SetRange("Impress Opening Run ID", Staging."Run ID");
        ItemJournalLine.SetRange("Line No.", Staging."BC Line No.");
        exit(ItemJournalLine.FindFirst());
    end;

    local procedure EnsureRequestedLineNoAvailable(Staging: Record "Impress Opening Inventory")
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        if ItemJournalLine.Get(Staging."Journal Template Name", Staging."Journal Batch Name", Staging."BC Line No.") then
            Error(
                'Run ID %1, BC Line No. %2: the requested Item Journal Line No. is already used by an unrelated line.',
                Staging."Run ID", Staging."BC Line No.");
    end;

    local procedure InsertJournalLine(Staging: Record "Impress Opening Inventory"; var ItemJournalLine: Record "Item Journal Line")
    var
        Defaults: Record "Impress Defaults";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        Defaults.Get();
        ItemJournalTemplate.Get(Staging."Journal Template Name");
        ItemJournalBatch.Get(Staging."Journal Template Name", Staging."Journal Batch Name");

        ItemJournalLine.Init();
        ItemJournalLine."Journal Template Name" := Staging."Journal Template Name";
        ItemJournalLine."Journal Batch Name" := Staging."Journal Batch Name";
        ItemJournalLine."Line No." := Staging."BC Line No.";
        ItemJournalLine."Source Code" := ItemJournalTemplate."Source Code";
        ItemJournalLine."Reason Code" := ItemJournalBatch."Reason Code";
        ItemJournalLine."Posting No. Series" := ItemJournalBatch."Posting No. Series";
        ItemJournalLine.Insert(true);

        ItemJournalLine.Validate("Posting Date", Staging."Posting Date");
        ItemJournalLine.Validate("Document No.", 'IMP-OPEN-INV');
        if Staging.Quantity > 0 then
            ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::"Positive Adjmt.")
        else
            ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::"Negative Adjmt.");
        ItemJournalLine.Validate("Item No.", Staging."Item No.");
        ItemJournalLine.Validate("Gen. Bus. Posting Group", Defaults."Open Inv. Gen. Bus. Group");
        ItemJournalLine.Validate("Location Code", Staging."Location Code");
        if Staging."Variant Code" <> '' then
            ItemJournalLine.Validate("Variant Code", Staging."Variant Code");
        ItemJournalLine.Validate(Quantity, Abs(Staging.Quantity));

        ApplyCategoryDimension(ItemJournalLine, Defaults."Category Dimension Code", Staging);

        // Item/location/variant/quantity validation can derive cost. Cost is
        // deliberately applied last so the SQL conversion cost remains authoritative.
        if Staging.Quantity > 0 then begin
            ItemJournalLine.Validate("Unit Amount", Staging."Unit Cost");
            ItemJournalLine.Validate("Unit Cost", Staging."Unit Cost");
        end else begin
            ItemJournalLine.Validate("Unit Amount", 0);
            ItemJournalLine.Validate("Unit Cost", 0);
        end;

        ItemJournalLine."Impress Opening Run ID" := Staging."Run ID";
        ItemJournalLine."Impress Source Database" := Staging."Source Database";
        ItemJournalLine."Impress Source BC Line No." := Staging."Source BC Line No.";
        ItemJournalLine."Impress Opening FIFO Sequence" := Staging."FIFO Sequence";
        ItemJournalLine."Impress Opening FIFO Tracked" := Staging."Is FIFO Tracked";
        ItemJournalLine.Modify(true);
    end;

    local procedure ApplyCategoryDimension(var ItemJournalLine: Record "Item Journal Line"; DimensionCode: Code[20]; Staging: Record "Impress Opening Inventory")
    var
        CategoryDimension: Codeunit "Impress Category Dimension";
        DimensionSetID: Integer;
    begin
        DimensionSetID := ItemJournalLine."Dimension Set ID";
        CategoryDimension.ApplyToDimensionSet(
            DimensionSetID, DimensionCode,
            CategoryDimension.GetDimensionValueCode(Staging."Source Database", Staging."Division Code"));
        ItemJournalLine.Validate("Dimension Set ID", DimensionSetID);
    end;

    local procedure MarkProcessed(var Staging: Record "Impress Opening Inventory"; ItemJournalLine: Record "Item Journal Line")
    begin
        Staging."Journal Line No." := ItemJournalLine."Line No.";
        Staging."BC Journal Line System ID" := ItemJournalLine.SystemId;
        Staging."Send Status" := Staging."Send Status"::Processed;
        Staging."Sent to BC Date Time" := CurrentDateTime();
        Staging."Processed Date Time" := CurrentDateTime();
        Clear(Staging."Error Message");
        Staging.Modify(true);
    end;
}
