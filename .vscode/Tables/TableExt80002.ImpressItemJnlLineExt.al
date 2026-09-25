tableextension 80002 "Impress Item Jnl. Line Ext." extends "Item Journal Line"
{
    fields
    {
        field(80000; "Impress Opening Run ID"; Guid) { DataClassification = CustomerContent; }
        field(80001; "Impress Source Database"; Code[50]) { DataClassification = CustomerContent; }
        field(80002; "Impress Source BC Line No."; BigInteger) { DataClassification = CustomerContent; }
        field(80003; "Impress Opening FIFO Sequence"; BigInteger) { DataClassification = CustomerContent; }
        field(80004; "Impress Opening FIFO Tracked"; Boolean) { DataClassification = CustomerContent; }
        field(80005; "Integration Posting ID"; Guid) { DataClassification = CustomerContent; Editable = false; }
        field(80006; "Impress Invoice Line Entry No."; BigInteger) { DataClassification = CustomerContent; Editable = false; }
    }
    keys
    {
        key(ImpressIntegrationPosting; "Integration Posting ID") { }
    }
}
