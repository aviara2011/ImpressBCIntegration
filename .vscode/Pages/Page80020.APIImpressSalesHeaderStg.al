page 80020 "API Impress Sales Header Stg"
{
    PageType = API;
    SourceTable = "Impress Sales Header Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressSalesHeaderStaging';
    EntitySetName = 'impressSalesHeaderStaging';
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
                field(salesOrderNo; Rec."Sales Order No.") { }
                field(customerNo; Rec."Customer No.") { }
                field(orderDate; Rec."Order Date") { }
                field(requestedShipmentDate; Rec."Requested Shipment Date") { }
                field(notBeforeDate; Rec."Not Before Date") { }
                field(cancelDate; Rec."Cancel Date") { }
                field(dueDate; Rec."Due Date") { }
                field(dateEntered; Rec."Date Entered") { }
                field(sourceLastChangedDateTime; Rec."Source Last Changed DateTime") { }
                field(customerPoNo; Rec."Customer PO No.") { }
                field(endCustomerPoNo; Rec."End Customer PO No.") { }
                field(sourceWarehouseCode; Rec."Source Warehouse Code") { }
                field(bcLocationCode; Rec."BC Location Code") { }
                field(shipViaCode; Rec."Ship Via Code") { }
                field(paymentTermsCode; Rec."Payment Terms Code") { }
                field(currencyCode; Rec."Currency Code") { }
                field(exchangeRate; Rec."Exchange Rate") { }
                field(productTotal; Rec."Product Total") { }
                field(productQuantity; Rec."Product Quantity") { }
                field(miscellaneousTotal; Rec."Miscellaneous Total") { }
                field(miscellaneousQuantity; Rec."Miscellaneous Quantity") { }
                field(shippingAmount; Rec."Shipping Amount") { }
                field(discountRate; Rec."Discount Rate") { }
                field(discountAmount; Rec."Discount Amount") { }
                field(salesOrderTotal; Rec."Sales Order Total") { }
                field(complete; Rec.Complete) { }
                field(shorted; Rec.Shorted) { }
                field(shippedInFull; Rec."Shipped In Full") { }
                field(onHold; Rec."On Hold") { }
                field(readyToBill; Rec."Ready To Bill") { }
                field(billingHold; Rec."Billing Hold") { }
                field(divisionCode; Rec."Division Code") { }
                field(enteredByUser; Rec."Entered By User") { }
                field(changedByUser; Rec."Changed By User") { }
                field(shipToName; Rec."Ship-to Name") { }
                field(shipToAddress; Rec."Ship-to Address") { }
                field(shipToAddress2; Rec."Ship-to Address 2") { }
                field(shipToAddress3; Rec."Ship-to Address 3") { }
                field(shipToCity; Rec."Ship-to City") { }
                field(shipToState; Rec."Ship-to State") { }
                field(shipToPostCode; Rec."Ship-to Post Code") { }
                field(shipToCountryCode; Rec."Ship-to Country Code") { }
                field(sourceBillToCode; Rec."Source Bill-to Code") { }
                field(billToName; Rec."Bill-to Name") { }
                field(billToAddress; Rec."Bill-to Address") { }
                field(billToAddress2; Rec."Bill-to Address 2") { }
                field(billToAddress3; Rec."Bill-to Address 3") { }
                field(billToCity; Rec."Bill-to City") { }
                field(billToState; Rec."Bill-to State") { }
                field(billToPostCode; Rec."Bill-to Post Code") { }
                field(sourceShipToCode; Rec."Source Ship-to Code") { }
                field(operation; Rec.Operation) { }
                field(transportStatus; Rec."Transport Status") { }
                field(processingStatus; Rec."Processing Status") { }
                field(errorMessage; Rec."Error Message") { }
                field(bcSystemId; Rec."BC System ID") { }
                field(bcDocumentNo; Rec."BC Document No.") { }
                field(taxAreaCode; Rec."Tax Area Code") { }
                field(taxAreaDescription; Rec."Tax Area Description") { }
                field(shippingIsTaxable; Rec."Shipping Is Taxable") { }
                field(taxRateTotal; Rec."Tax Rate Total") { }
                field(taxJurisdictionCode1; Rec."Tax Jurisdiction Code 1") { }
                field(taxJurisdictionDescription1; Rec."Tax Jurisdiction Desc. 1") { }
                field(taxJurisdictionRate1; Rec."Tax Jurisdiction Rate 1") { }
                field(taxJurisdictionGLAccount1; Rec."Tax Jurisdiction G/L Acc. 1") { }
                field(taxJurisdictionCode2; Rec."Tax Jurisdiction Code 2") { }
                field(taxJurisdictionDescription2; Rec."Tax Jurisdiction Desc. 2") { }
                field(taxJurisdictionRate2; Rec."Tax Jurisdiction Rate 2") { }
                field(taxJurisdictionGLAccount2; Rec."Tax Jurisdiction G/L Acc. 2") { }
                field(taxJurisdictionCode3; Rec."Tax Jurisdiction Code 3") { }
                field(taxJurisdictionDescription3; Rec."Tax Jurisdiction Desc. 3") { }
                field(taxJurisdictionRate3; Rec."Tax Jurisdiction Rate 3") { }
                field(taxJurisdictionGLAccount3; Rec."Tax Jurisdiction G/L Acc. 3") { }
                field(taxJurisdictionCode4; Rec."Tax Jurisdiction Code 4") { }
                field(taxJurisdictionDescription4; Rec."Tax Jurisdiction Desc. 4") { }
                field(taxJurisdictionRate4; Rec."Tax Jurisdiction Rate 4") { }
                field(taxJurisdictionGLAccount4; Rec."Tax Jurisdiction G/L Acc. 4") { }
            }
        }
    }
}
