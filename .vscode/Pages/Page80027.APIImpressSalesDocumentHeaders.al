page 80027 "API Impress Sales Doc Headers"
{
    PageType = API;
    SourceTable = "Impress Sales Doc Hdr Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressSalesDocumentHeader';
    EntitySetName = 'impressSalesDocumentHeaders';
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
                field(sourceCustomerCode; Rec."Source Customer Code") { }
                field(sourceDocumentType; Rec."Source Document Type") { }
                field(documentType; Rec."Document Type") { }
                field(documentNo; Rec."Document No.") { }
                field(sourceSalesOrderNo; Rec."Source Sales Order No.") { }
                field(applyToInvoiceNo; Rec."Apply-to Invoice No.") { }
                field(invoiceDate; Rec."Invoice Date") { }
                field(dueDate; Rec."Due Date") { }
                field(glPostDate; Rec."G/L Post Date") { }
                field(divisionCode; Rec."Division Code") { }
                field(arGlAccount; Rec."A/R G/L Account") { }
                field(invoiceTotal; Rec."Invoice Total") { }
                field(discountRate; Rec."Discount Rate") { }
                field(discountAmount; Rec."Discount Amount") { }
                field(discountAdjust; Rec."Discount Adjust") { }
                field(sourceBalance; Rec."Source Balance") { }
                field(discountTaken; Rec."Discount Taken") { }
                field(taxAreaCode; Rec."Tax Area Code") { }
                field(taxAreaDescription; Rec."Tax Area Description") { }
                field(taxableAmount1; Rec."Taxable Amount 1") { }
                field(taxableAmount2; Rec."Taxable Amount 2") { }
                field(taxableAmount3; Rec."Taxable Amount 3") { }
                field(taxableAmount4; Rec."Taxable Amount 4") { }
                field(taxRate1; Rec."Tax Rate 1") { }
                field(taxRate2; Rec."Tax Rate 2") { }
                field(taxRate3; Rec."Tax Rate 3") { }
                field(taxRate4; Rec."Tax Rate 4") { }
                field(taxTotal; Rec."Tax Total") { }
                field(taxRateTotal; Rec."Tax Rate Total") { }
                field(shippingIsTaxable; Rec."Shipping Is Taxable") { }
                field(taxJurisdictionCode1; Rec."Tax Jurisdiction Code 1") { }
                field(taxJurisdictionDescription1; Rec."Tax Jurisdiction Desc. 1") { }
                field(taxJurisdictionCode2; Rec."Tax Jurisdiction Code 2") { }
                field(taxJurisdictionDescription2; Rec."Tax Jurisdiction Desc. 2") { }
                field(taxJurisdictionCode3; Rec."Tax Jurisdiction Code 3") { }
                field(taxJurisdictionDescription3; Rec."Tax Jurisdiction Desc. 3") { }
                field(taxJurisdictionCode4; Rec."Tax Jurisdiction Code 4") { }
                field(taxJurisdictionDescription4; Rec."Tax Jurisdiction Desc. 4") { }
                field(taxGlAccount1; Rec."Tax G/L Account 1") { }
                field(taxGlAccount2; Rec."Tax G/L Account 2") { }
                field(taxGlAccount3; Rec."Tax G/L Account 3") { }
                field(taxGlAccount4; Rec."Tax G/L Account 4") { }
                field(hasInventoryImpact; Rec."Has Inventory Impact") { }
                field(firstInventoryTransactionId; Rec."First Inventory Transaction ID") { }
                field(lastInventoryTransactionId; Rec."Last Inventory Transaction ID") { }
                field(inventoryTransactionCount; Rec."Inventory Transaction Count") { }
                field(processingPhase; Rec."Processing Phase") { }
                field(processingStatus; Rec."Processing Status") { }
                field(transportStatus; Rec."Transport Status") { }
                field(bcSystemId; Rec."BC System ID") { }
                field(bcDocumentNo; Rec."BC Document No.") { }
                field(errorMessage; Rec."Error Message") { }
                field(dateStaged; Rec."Date Staged") { }
                field(dateProcessingStarted; Rec."Date Processing Started") { }
                field(dateProcessed; Rec."Date Processed") { }
            }
        }
    }
}
