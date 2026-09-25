table 80000 "Impress Integration Control"
{
    Caption = 'Impress Integration Control';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Run ID"; Integer)
        {
            Caption = 'Run ID';
            AutoIncrement = true;
        }
        field(10; "Process Name"; Code[50])
        {
            Caption = 'Process Name';
        }
        field(20; "Run Start DateTime"; DateTime)
        {
            Caption = 'Run Start DateTime';
        }
        field(30; "Run End DateTime"; DateTime)
        {
            Caption = 'Run End DateTime';
        }
        field(40; "Run Status"; Enum "Impress Run Status")
        {
            Caption = 'Run Status';
        }
        field(50; "Run Message"; Text[1000])
        {
            Caption = 'Run Message';
        }
        field(60; "Last Successful Run DateTime"; DateTime)
        {
            Caption = 'Last Successful Run DateTime';
        }
        field(70; "Records Selected"; Integer)
        {
            Caption = 'Records Selected';
        }
        field(80; "Records Staged"; Integer)
        {
            Caption = 'Records Staged';
        }
        field(90; "Records Sent To BC"; Integer)
        {
            Caption = 'Records Sent To BC';
        }
        field(100; "Records Failed"; Integer)
        {
            Caption = 'Records Failed';
        }
        field(110; "SQL Run ID"; Integer)
        {
            Caption = 'SQL Run ID';
        }
        field(120; "Records Processed In BC"; Integer)
        {
            Caption = 'Records Processed In BC';
        }
        field(130; Difference; Integer)
        {
            Caption = 'Difference';
        }
        field(140; "SQL Run Guid"; Guid)
        {
            Caption = 'SQL Run Guid';
        }
    }

    keys
    {
        key(PK; "Run ID")
        {
            Clustered = true;
        }
        key(ProcessStatus; "Process Name", "Run Status", "Run ID") { }
        key(ProcessRunGuid; "Process Name", "SQL Run Guid") { }
    }

    trigger OnInsert()
    begin
        if "Run Start DateTime" = 0DT then begin
            "Run Start DateTime" := CurrentDateTime();
            "Run Status" := "Run Status"::Started;
        end;
    end;
}
