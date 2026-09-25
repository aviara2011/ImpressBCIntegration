page 80026 "API Impress Inventory Trans."
{
    PageType = API;
    SourceTable = "Impress Inv Trans Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressInventoryTransaction';
    EntitySetName = 'impressInventoryTransactions';
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
                field(sourceDatabase; Rec."Source Database") { }
                field(sourceTransactionId; Rec."Source Transaction ID") { }
                field(glDate; Rec."G/L Date") { }
                field(transactionType; Rec."Transaction Type") { }
                field(transactionSource; Rec."Transaction Source") { }
                field(sourceSkuNo; Rec."Source SKU No.") { }
                field(sourceSize; Rec."Source Size") { }
                field(sourceWarehouseCode; Rec."Source Warehouse Code") { }
                field(quantity; Rec.Quantity) { }
                field(sourceOrderNo; Rec."Source Order No.") { }
                field(sourceOrderLineNo; Rec."Source Order Line No.") { }
                field(sourceGlAccount; Rec."Source G/L Account") { }
                field(sourceInventoryGlAccount; Rec."Source Inventory G/L Account") { }
                field(sourceOffsetGlAccount; Rec."Source Offset G/L Account") { }
                field(sourceAdjustmentGlAccount; Rec."Source Adjustment G/L Account") { }
                field(sourceCost; Rec."Source Cost") { }
                field(sourceLifoFifoCost; Rec."Source LIFO/FIFO Cost") { }
                field(sourceLifoFifoCostAdj; Rec."Source LIFO/FIFO Cost Adj.") { }
                field(sourceAddedCost; Rec."Source Added Cost") { }
                field(sourceFreightCost; Rec."Source Freight Cost") { }
                field(sourceOtherCost; Rec."Source Other Cost") { }
                field(sourceSkuId; Rec."Source SKU ID") { }
                field(bcItemNo; Rec."BC Item No.") { }
                field(bcVariantCode; Rec."BC Variant Code") { }
                field(bcLocationCode; Rec."BC Location Code") { }
                field(skuDivisionCode; Rec."SKU Division Code") { }
                field(sourceDocumentDivisionCode; Rec."Source Document Division Code") { }
                field(divisionCode; Rec."Division Code") { }
                field(divisionSource; Rec."Division Source") { }
                field(transactionHandler; Rec."Transaction Handler") { }
                field(processingStatus; Rec."Processing Status") { }
                field(transportStatus; Rec."Transport Status") { }
                field(relatedSalesDocumentEntryNo; Rec."Related Sales Doc. Entry No.") { }
                field(bcSystemId; Rec."BC System ID") { }
                field(bcDocumentNo; Rec."BC Document No.") { }
                field(errorMessage; Rec."Error Message") { }
                field(dateStaged; Rec."Date Staged") { }
                field(dateProcessingStarted; Rec."Date Processing Started") { }
                field(dateProcessed; Rec."Date Processed") { }
                field(integrationPostingId; Rec."Integration Posting ID") { Editable = false; }
                field(bcPostedDocumentType; Rec."BC Posted Document Type") { Editable = false; }
                field(bcPostedDocumentNo; Rec."BC Posted Document No.") { Editable = false; }
                field(bcPostedPostingDate; Rec."BC Posted Posting Date") { Editable = false; }
                field(processedDateTime; Rec."Processed Date/Time") { Editable = false; }
            }
        }
    }
}
