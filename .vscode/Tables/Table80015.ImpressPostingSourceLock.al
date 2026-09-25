table 80015 "Impress Posting Source Lock"
{
    Caption = 'Impress Posting Source Lock';
    DataClassification = SystemMetadata;
    fields
    {
        field(1; "Source Database"; Text[50]) { }
    }
    keys
    {
        key(PK; "Source Database") { Clustered = true; }
    }
}
