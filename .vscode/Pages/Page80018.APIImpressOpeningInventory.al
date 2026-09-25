page 80018 "API Impress Opening Inventory"
{
    PageType = API;
    SourceTable = "Impress Opening Inventory";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressOpeningInventory';
    EntitySetName = 'impressOpeningInventory';
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId) { }
                field(entryNo; Rec."Entry No.") { }
                field(runId; Rec."Run ID") { }
                field(sourceDatabase; Rec."Source Database") { }
                field(sourceBCLineNo; Rec."Source BC Line No.") { }
                field(bcLineNo; Rec."BC Line No.") { }
                field(impressItemNo; Rec."Impress Item No.") { }
                field(impressVariantCode; Rec."Impress Variant Code") { }
                field(divisionCode; Rec."Division Code") { }
                field(itemNo; Rec."Item No.") { }
                field(variantCode; Rec."Variant Code") { }
                field(locationCode; Rec."Location Code") { }
                field(postingDate; Rec."Posting Date") { }
                field(quantity; Rec.Quantity) { }
                field(unitCost; Rec."Unit Cost") { }
                field(inventoryValue; Rec."Inventory Value") { }
                field(isFIFOTracked; Rec."Is FIFO Tracked") { }
                field(fifoSequence; Rec."FIFO Sequence") { }
                field(sendStatus; Rec."Send Status") { }
                field(errorMessage; Rec."Error Message") { }
                field(journalTemplateName; Rec."Journal Template Name") { }
                field(journalBatchName; Rec."Journal Batch Name") { }
                field(journalLineNo; Rec."Journal Line No.") { }
                field(bcJournalLineSystemId; Rec."BC Journal Line System ID") { }
                field(extractedDateTime; Rec."Extracted Date Time") { }
                field(sentToBCDateTime; Rec."Sent to BC Date Time") { }
                field(processedDateTime; Rec."Processed Date Time") { }
            }
        }
    }
}
