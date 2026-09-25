table 80018 "Impress Journal Reservation"
{
    Caption = 'Impress Journal Number Reservation';
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Integration Posting ID"; Guid) { }
        field(10; "Journal System ID"; Guid) { }
        field(20; "No. Series"; Code[20]) { TableRelation = "No. Series"; }
        field(30; "Document No."; Code[20]) { }
        field(40; "Posting Date"; Date) { }
    }
    keys
    {
        key(PK; "Integration Posting ID") { Clustered = true; }
    }
}
