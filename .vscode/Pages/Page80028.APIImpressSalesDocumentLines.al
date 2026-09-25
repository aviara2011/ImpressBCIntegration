page 80028 "API Impress Sales Doc Lines"
{
    PageType = API;
    SourceTable = "Impress Sales Doc Line Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressSalesDocumentLine';
    EntitySetName = 'impressSalesDocumentLines';
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
                field(salesDocumentEntryNo; Rec."Sales Document Entry No.") { }
                field(sourceDatabase; Rec."Source Database") { }
                field(sourceCustomerCode; Rec."Source Customer Code") { }
                field(documentType; Rec."Document Type") { }
                field(documentNo; Rec."Document No.") { }
                field(sourceLineNo; Rec."Source Line No.") { }
                field(sourceSequence; Rec."Source Sequence") { }
                field(sourceSalesOrderLineNo; Rec."Source Sales Order Line No.") { }
                field(sizePosition; Rec."Size Position") { }
                field(sourceLineType; Rec."Source Line Type") { }
                field(sourceItemCode; Rec."Source Item Code") { }
                field(sourceRawSkuNo; Rec."Source Raw SKU No.") { }
                field(sourceSize; Rec."Source Size") { }
                field(sourceDescription; Rec."Source Description") { }
                field(quantity; Rec.Quantity) { }
                field(unitPrice; Rec."Unit Price") { }
                field(amount; Rec.Amount) { }
                field(nonTaxCategoryCode; Rec."Non Tax Category Code") { Caption = 'Non Tax Category Code'; }
                field(taxGroupCode; Rec."Tax Group Code") { Caption = 'Tax Group Code'; }
                field(taxGroupDescription; Rec."Tax Group Description") { Caption = 'Tax Group Description'; }
                field(bcItemNo; Rec."BC Item No.") { }
                field(bcVariantCode; Rec."BC Variant Code") { }
                field(revenueGlAccount; Rec."Revenue G/L Account") { }
                field(inventoryGlAccount; Rec."Inventory G/L Account") { }
                field(cogsGlAccount; Rec."COGS G/L Account") { }
                field(relatedInventoryTransactionId; Rec."Related Inventory Trans. ID") { }
                field(processingStatus; Rec."Processing Status") { }
                field(transportStatus; Rec."Transport Status") { }
                field(bcSystemId; Rec."BC System ID") { }
                field(bcLineSystemId; Rec."BC Line System ID") { }
                field(errorMessage; Rec."Error Message") { }
                field(dateStaged; Rec."Date Staged") { }
                field(dateProcessed; Rec."Date Processed") { }
            }
        }
    }
}
