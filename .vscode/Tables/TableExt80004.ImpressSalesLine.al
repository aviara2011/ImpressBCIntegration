tableextension 80004 "Impress Sales Line" extends "Sales Line"
{
    fields
    {
        field(80000; "Impress Source Database"; Code[50]) { DataClassification = CustomerContent; }
        field(80001; "Impress Sales Detail ID"; BigInteger) { DataClassification = CustomerContent; }
        field(80002; "Impress Size Position"; Integer) { DataClassification = CustomerContent; }
        field(80003; "Integration Posting ID"; Guid) { DataClassification = CustomerContent; Editable = false; }
        field(80004; "Impress Invoice Line Entry No."; BigInteger) { DataClassification = CustomerContent; Editable = false; }
        field(80005; "Impress Raw SKU"; Text[50]) { DataClassification = CustomerContent; Editable = false; }
    }
}
