tableextension 80010 "Impress Purch. Receipt" extends "Purch. Rcpt. Header"
{
    fields
    {
        // Removed fields retain the installed schema, but are excluded from
        // standard TransferFields. Never reuse these IDs for receipt metadata.
        field(80000; "Legacy RP Posting ID"; Guid)
        {
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteReason = 'Collides with Purchase Header field 80000. Replaced by 80020.';
            ObsoleteTag = '1.0.0.96';
        }
        field(80001; "Legacy RP Source Database"; Text[50])
        {
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteReason = 'Collides with Purchase Header field 80001. Replaced by 80021.';
            ObsoleteTag = '1.0.0.96';
        }
        field(80002; "Legacy RP Source Trans. ID"; BigInteger)
        {
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteReason = 'Collides with Purchase Header field 80002. Replaced by 80022.';
            ObsoleteTag = '1.0.0.96';
        }
        field(80020; "Integration Posting ID"; Guid) { DataClassification = CustomerContent; }
        field(80021; "Impress Source Database"; Text[50]) { DataClassification = CustomerContent; }
        field(80022; "Impress Source Transaction ID"; BigInteger) { DataClassification = CustomerContent; }
        field(80003; "Impress Source Order No."; Text[50]) { DataClassification = CustomerContent; }
        field(80004; "Impress Source Order Line No."; Integer) { DataClassification = CustomerContent; }
        field(80005; "Impress Source SKU"; Text[50]) { DataClassification = CustomerContent; }
        field(80006; "Impress Source Size"; Text[30]) { DataClassification = CustomerContent; }
        field(80007; "Impress Source Warehouse"; Text[30]) { DataClassification = CustomerContent; }
        field(80008; "Impress Order Line No."; Integer) { DataClassification = CustomerContent; }
        field(80009; "Impress RP Account Version"; Integer) { DataClassification = CustomerContent; }
    }
    keys
    {
        key(ImpressPosting; "Integration Posting ID") { }
        key(ImpressSource; "Impress Source Database", "Impress Source Transaction ID") { }
    }
}
