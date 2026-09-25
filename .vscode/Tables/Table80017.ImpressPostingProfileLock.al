table 80017 "Impress Posting Profile Lock"
{
    DataClassification = SystemMetadata;
    fields
    {
        field(1; Code; Code[10]) { }
        field(10; Revision; BigInteger) { }
    }
    keys
    {
        key(PK; Code) { Clustered = true; }
    }
}
