tableextension 80007 "Impress Sales Invoice Header" extends "Sales Invoice Header"
{
    fields
    {
        field(80000; "Impress Source Database"; Code[50]) { DataClassification = CustomerContent; }
        field(80003; "Integration Posting ID"; Guid) { DataClassification = CustomerContent; Editable = false; }
    }
    keys { key(ImpressPosting; "Integration Posting ID") { } }
}
