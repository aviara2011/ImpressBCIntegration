tableextension 80003 "Impress Sales Header" extends "Sales Header"
{
    fields
    {
        field(80000; "Impress Source Database"; Code[50]) { DataClassification = CustomerContent; }
        field(80001; "Impress Source Sales Order ID"; BigInteger) { DataClassification = CustomerContent; }
        field(80002; "Impress Source Sales Order No."; Code[35]) { DataClassification = CustomerContent; }
        field(80003; "Integration Posting ID"; Guid) { DataClassification = CustomerContent; Editable = false; }
    }
}
