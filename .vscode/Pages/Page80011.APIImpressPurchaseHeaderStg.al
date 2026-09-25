page 80011 "API Impress Purch Header Stg"
{
    PageType = API;
    SourceTable = "Impress Purch Header Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressPurchaseHeaderStaging';
    EntitySetName = 'impressPurchaseHeaderStaging';
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
                field(sqlRunId; Rec."SQL Run ID") { }
                field(sourceDatabase; Rec."Source Database") { }
                field(sourcePOrderId; Rec."Source POrder ID") { }
                field(purchaseOrderNo; Rec."Purchase Order No.") { }
                field(vendorNo; Rec."Vendor No.") { }
                field(orderDate; Rec."Order Date") { }
                field(shipmentDate; Rec."Shipment Date") { }
                field(firstExpectedReceiptDate; Rec."First Expected Receipt Date") { }
                field(lastExpectedReceiptDate; Rec."Last Expected Receipt Date") { }
                field(cancelDate; Rec."Cancel Date") { }
                field(notBeforeDate; Rec."Not Before Date") { }
                field(dateEntered; Rec."Date Entered") { }
                field(sourceLastChangedDateTime; Rec."Source Last Changed Date Time") { }
                field(firstReceiptDate; Rec."First Receipt Date") { }
                field(lastReceiptDate; Rec."Last Receipt Date") { }
                field(sourceWarehouseCode; Rec."Source Warehouse Code") { }
                field(bcLocationCode; Rec."BC Location Code") { }
                field(shipViaCode; Rec."Ship Via Code") { }
                field(paymentTermsCode; Rec."Payment Terms Code") { }
                field(currencyCode; Rec."Currency Code") { }
                field(exchangeRate; Rec."Exchange Rate") { }
                field(allowOverReceipt; Rec."Allow Over Receipt") { }
                field(allowUnderReceipt; Rec."Allow Under Receipt") { }
                field(totalQuantityOrdered; Rec."Total Quantity Ordered") { }
                field(totalQuantityReceived; Rec."Total Quantity Received") { }
                field(totalQuantityRemaining; Rec."Total Quantity Remaining") { }
                field(productTotal; Rec."Product Total") { }
                field(miscellaneousTotal; Rec."Miscellaneous Total") { }
                field(shippingAmount; Rec."Shipping Amount") { }
                field(unitFreightCost; Rec."Unit Freight Cost") { }
                field(unitOtherCost; Rec."Unit Other Cost") { }
                field(discountRate; Rec."Discount Rate") { }
                field(discountAmount; Rec."Discount Amount") { }
                field(purchaseOrderTotal; Rec."Purchase Order Total") { }
                field(complete; Rec.Complete) { }
                field(shorted; Rec.Shorted) { }
                field(onHold; Rec."On Hold") { }
                field(buyerUser; Rec."Buyer User") { }
                field(receivedByUser; Rec."Received By User") { }
                field(relatedSalesOrderNo; Rec."Related Sales Order No.") { }
                field(shipToName; Rec."Ship-to Name") { }
                field(shipToAddress; Rec."Ship-to Address") { }
                field(shipToAddress2; Rec."Ship-to Address 2") { }
                field(shipToAddress3; Rec."Ship-to Address 3") { }
                field(shipToCity; Rec."Ship-to City") { }
                field(shipToState; Rec."Ship-to State") { }
                field(shipToPostCode; Rec."Ship-to Post Code") { }
                field(shipToCountryCode; Rec."Ship-to Country Code") { }
                field(operation; Rec.Operation) { }
                field(transportStatus; Rec."Transport Status") { }
                field(processingStatus; Rec."Processing Status") { }
                field(errorMessage; Rec."Error Message") { }
                field(bcSystemId; Rec."BC System ID") { }
                field(bcDocumentNo; Rec."BC Document No.") { }
                field(extractedDateTime; Rec."Extracted Date Time") { }
                field(sentToBCDateTime; Rec."Sent to BC Date Time") { }
                field(processedDateTime; Rec."Processed Date Time") { }
            }
        }
    }
}
