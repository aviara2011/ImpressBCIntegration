page 80001 "API Impress Item Staging"
{
    PageType = API;
    SourceTable = "Impress Item Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressItemStaging';
    EntitySetName = 'impressItemStaging';
    DelayedInsert = true;
    ODataKeyFields = SystemId;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId) { Caption = 'Id'; }
                field(entryNo; Rec."Entry No.") { Caption = 'Entry No.'; }
                field(sqlRunId; Rec."SQL Run ID") { Caption = 'SQL Run ID'; }
                field(sourceDatabase; Rec."Source Database") { Caption = 'Source Database'; }
                field(sourceSystemId; Rec."Source System ID") { Caption = 'Source System ID'; }
                field(sourceSkuItemNo; Rec."Source SKU Item No.") { Caption = 'Source SKU Item No.'; }
                field(itemNo; Rec."Item No.") { Caption = 'Item No.'; }
                field(styleCode; Rec."Style Code") { Caption = 'Style Code'; }
                field(colorCode; Rec."Color Code") { Caption = 'Color Code'; }
                field(sizeCode; Rec."Size Code") { Caption = 'Size Code'; }
                field(variantCode; Rec."Variant Code") { Caption = 'Variant Code'; }
                field(description; Rec.Description) { Caption = 'Description'; }
                field(purchaseDescription; Rec."Purchase Description") { Caption = 'Purchase Description'; }
                field(skuStatus; Rec."SKU Status") { Caption = 'SKU Status'; }
                field(unitOfMeasure; Rec."Unit of Measure") { Caption = 'Unit of Measure'; }
                field(itemCategoryCode; Rec."Item Category Code") { Caption = 'Item Category Code'; }
                field(preferredVendorNo; Rec."Preferred Vendor No.") { Caption = 'Preferred Vendor No.'; }
                field(sourceCreatedDateTime; Rec."Source Created DateTime") { Caption = 'Source Created DateTime'; }
                field(sourceModifiedDateTime; Rec."Source Modified DateTime") { Caption = 'Source Modified DateTime'; }
                field(status; Rec.Status) { Caption = 'Status'; }
                field(errorMessage; Rec."Error Message") { Caption = 'Error Message'; }
                field(sqlEntryNo; Rec."SQL Entry No.") { Caption = 'SQL Entry No.'; }
                field(receivedDateTime; Rec."Received DateTime") { Caption = 'Received DateTime'; }
                field(processedDateTime; Rec."Processed DateTime") { Caption = 'Processed DateTime'; }
            }
        }
    }
}
