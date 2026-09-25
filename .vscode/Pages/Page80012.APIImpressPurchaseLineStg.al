page 80012 "API Impress Purchase Line Stg"
{
    PageType = API;
    SourceTable = "Impress Purchase Line Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressPurchaseLineStaging';
    EntitySetName = 'impressPurchaseLineStaging';
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
                field(sourcePOrderDetailId; Rec."Source POrder Detail ID") { }
                field(sizePosition; Rec."Size Position") { }
                field(purchaseOrderNo; Rec."Purchase Order No.") { }
                field(sourceLineNo; Rec."Source Line No.") { }
                field(sourceSequence; Rec."Source Sequence") { }
                field(sourceDesignLineNo; Rec."Source Design Line No.") { }
                field(bcLineNo; Rec."BC Line No.") { }
                field(vendorNo; Rec."Vendor No.") { }
                field(sourceSku; Rec."Source SKU") { }
                field(sourceStyle; Rec."Source Style") { }
                field(sourceColor; Rec."Source Color") { }
                field(sourceSize; Rec."Source Size") { }
                field(bcItemNo; Rec."BC Item No.") { }
                field(bcVariantCode; Rec."BC Variant Code") { }
                field(description; Rec.Description) { }
                field(unitOfMeasureCode; Rec."Unit of Measure Code") { }
                field(quantityOrdered; Rec."Quantity Ordered") { }
                field(quantityReceived; Rec."Quantity Received") { }
                field(quantityRemaining; Rec."Quantity Remaining") { }
                field(directUnitCost; Rec."Direct Unit Cost") { }
                field(fullUnitCost; Rec."Full Unit Cost") { }
                field(orderedLineAmount; Rec."Ordered Line Amount") { }
                field(receivedLineAmount; Rec."Received Line Amount") { }
                field(remainingLineAmount; Rec."Remaining Line Amount") { }
                field(orderDate; Rec."Order Date") { }
                field(shipmentDate; Rec."Shipment Date") { }
                field(expectedReceiptDate; Rec."Expected Receipt Date") { }
                field(firstReceiptDate; Rec."First Receipt Date") { }
                field(lastReceiptDate; Rec."Last Receipt Date") { }
                field(complete; Rec.Complete) { }
                field(shorted; Rec.Shorted) { }
                field(onHold; Rec."On Hold") { }
                field(shipViaCode; Rec."Ship Via Code") { }
                field(divisionCode; Rec."Division Code") { }
                field(relatedProductionHeaderId; Rec."Related Production Header ID") { }
                field(operation; Rec.Operation) { }
                field(transportStatus; Rec."Transport Status") { }
                field(processingStatus; Rec."Processing Status") { }
                field(errorMessage; Rec."Error Message") { }
                field(bcHeaderSystemId; Rec."BC Header System ID") { }
                field(bcDocumentNo; Rec."BC Document No.") { }
                field(bcLineSystemId; Rec."BC Line System ID") { }
                field(extractedDateTime; Rec."Extracted Date Time") { }
                field(sentToBCDateTime; Rec."Sent to BC Date Time") { }
                field(processedDateTime; Rec."Processed Date Time") { }
            }
        }
    }
}
