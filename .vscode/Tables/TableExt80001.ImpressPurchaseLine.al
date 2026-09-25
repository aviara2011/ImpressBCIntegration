tableextension 80001 "Impress Purchase Line" extends "Purchase Line"
{
    fields
    {
        field(80000; "Impress Source Database"; Code[50]) { DataClassification = CustomerContent; }
        field(80001; "Impress POrder Detail ID"; BigInteger) { DataClassification = CustomerContent; }
        field(80002; "Impress Size Position"; Integer) { DataClassification = CustomerContent; }
        field(80003; "Impress Source Line No."; Integer) { DataClassification = CustomerContent; }
        field(80004; "Impress Source SKU"; Code[50]) { DataClassification = CustomerContent; }
    }
}
