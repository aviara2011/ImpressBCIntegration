tableextension 80005 "Impress Item Ledger Entry" extends "Item Ledger Entry"
{
    fields
    {
        field(80005; "Integration Posting ID"; Guid) { DataClassification = CustomerContent; Editable = false; }
        field(80006; "Impress Invoice Line Entry No."; BigInteger) { DataClassification = CustomerContent; Editable = false; }
    }
    keys
    {
        key(ImpressIntegrationPosting; "Integration Posting ID") { }
    }
}
