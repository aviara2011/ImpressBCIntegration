tableextension 80000 "Impress Purchase Header" extends "Purchase Header"
{
    fields
    {
        field(80000; "Impress Source Database"; Code[50]) { DataClassification = CustomerContent; }
        field(80001; "Impress Source POrder ID"; BigInteger) { DataClassification = CustomerContent; }
        field(80002; "Impress Purchase Order No."; Code[35]) { DataClassification = CustomerContent; }
    }
}
