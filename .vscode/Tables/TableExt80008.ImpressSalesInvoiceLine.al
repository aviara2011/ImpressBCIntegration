tableextension 80008 "Impress Sales Invoice Line" extends "Sales Invoice Line"
{
    fields
    {
        field(80003; "Integration Posting ID"; Guid) { DataClassification = CustomerContent; Editable = false; }
        field(80004; "Impress Invoice Line Entry No."; BigInteger) { DataClassification = CustomerContent; Editable = false; }
    }
    keys { key(ImpressPosting; "Integration Posting ID", "Impress Invoice Line Entry No.") { } }
}
