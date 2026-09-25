tableextension 80006 "Impress Value Entry" extends "Value Entry"
{
    fields
    {
        field(80005; "Integration Posting ID"; Guid) { DataClassification = CustomerContent; Editable = false; }
    }
    keys
    {
        key(ImpressIntegrationPosting; "Integration Posting ID") { }
    }
}
