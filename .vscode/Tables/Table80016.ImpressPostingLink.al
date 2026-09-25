table 80016 "Impress Posting Link"
{
    Caption = 'Impress Posting Link';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Integration Posting ID"; Guid) { }
        field(2; "Table ID"; Integer) { }
        field(3; "Entry No."; Integer) { }
        field(10; "Entry System ID"; Guid) { }
        field(20; "Document No."; Code[20]) { }
        field(30; "Posting Date"; Date) { }
    }
    keys
    {
        key(PK; "Integration Posting ID", "Table ID", "Entry No.") { Clustered = true; }
    }
}
