page 80021 "API Impress Sales Line Stg"
{
    PageType = API;
    SourceTable = "Impress Sales Line Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressSalesLineStaging';
    EntitySetName = 'impressSalesLineStaging';
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = true;
    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId) { }
                field(runId; Rec."SQL Run ID") { }
                field(sourceDatabase; Rec."Source Database") { }
                field(sourceSalesOrderId; Rec."Source Sales Order ID") { }
                field(sourceSalesOrderDetailId; Rec."Source Sales Order Detail ID") { }
                field(sizePosition; Rec."Size Position") { }
                field(salesOrderNo; Rec."Sales Order No.") { }
                field(sourceLineNo; Rec."Source Line No.") { }
                field(sourceSequence; Rec."Source Sequence") { }
                field(sourceDesignLineNo; Rec."Source Design Line No.") { }
                field(bcLineNo; Rec."BC Line No.") { }
                field(customerNo; Rec."Customer No.") { }
                field(sourceLineType; Rec."Source Line Type") { }
                field(bcLineType; Rec."BC Line Type") { }
                field(sourceCode; Rec."Source Code") { }
                field(sourceSku; Rec."Source SKU") { }
                field(sourceStyle; Rec."Source Style") { }
                field(sourceColor; Rec."Source Color") { }
                field(sourceSize; Rec."Source Size") { }
                field(bcItemNo; Rec."BC Item No.") { }
                field(bcVariantCode; Rec."BC Variant Code") { }
                field(description; Rec.Description) { }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { }
                field(quantity; Rec.Quantity) { }
                field(quantityShipped; Rec."Quantity Shipped") { }
                field(quantityInvoiced; Rec."Quantity Invoiced") { }
                field(unitPrice; Rec."Unit Price") { }
                field(lineAmount; Rec."Line Amount") { }
                field(discountRate; Rec."Discount Rate") { }
                field(discountable; Rec.Discountable) { }
                field(requestedDate; Rec."Requested Date") { }
                field(shipComplete; Rec."Ship Complete") { }
                field(complete; Rec.Complete) { }
                field(shorted; Rec.Shorted) { }
                field(shippedInFull; Rec."Shipped In Full") { }
                field(salesAccountNo; Rec."Sales Account No.") { }
                field(nonTaxCategoryCode; Rec."Non-Tax Category Code") { }
                field(divisionCode; Rec."Division Code") { }
                field(operation; Rec.Operation) { }
                field(transportStatus; Rec."Transport Status") { }
                field(processingStatus; Rec."Processing Status") { }
                field(errorMessage; Rec."Error Message") { }
                field(bcSystemId; Rec."BC System ID") { }
                field(bcDocumentNo; Rec."BC Document No.") { }
                field(bcLineSystemId; Rec."BC Line System ID") { }
                field(taxGroupCode; Rec."Tax Group Code") { }
                field(taxGroupDescription; Rec."Tax Group Description") { }
            }
        }
    }
}
