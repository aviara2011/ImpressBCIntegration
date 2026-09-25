table 80019 "Impress Journal Component"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Integration Posting ID"; Guid) { }
        field(2; "Component No."; Integer) { }
        field(10; "Journal System ID"; Guid) { }
        field(20; "No. Series"; Code[20]) { }
        field(30; "Document No."; Code[20]) { }
        field(40; "Posting Date"; Date) { }
        field(50; "Available Quantity"; Decimal) { }
        field(60; "Requested Quantity"; Decimal) { }
        field(70; "Transfer Quantity"; Decimal) { }
        field(80; "Shortage Quantity"; Decimal) { }
        field(90; "Source Signature"; Text[2048]) { }
        field(100; "Entry Type"; Enum "Item Ledger Entry Type") { }
        field(110; Quantity; Decimal) { }
    }
    keys
    {
        key(PK; "Integration Posting ID", "Component No.") { Clustered = true; }
        key(Journal; "Journal System ID") { }
    }
}
