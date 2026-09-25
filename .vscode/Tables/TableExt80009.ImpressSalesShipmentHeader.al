tableextension 80009 "Impress Sales Shipment Header" extends "Sales Shipment Header"
{
    fields
    {
        field(80003; "Integration Posting ID"; Guid) { DataClassification = CustomerContent; Editable = false; }
    }
    keys { key(ImpressPosting; "Integration Posting ID") { } }
}
