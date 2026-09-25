table 80003 "Impress Customer Staging"
{
    Caption = 'Impress Customer Staging';
    DataClassification = CustomerContent;
    DrillDownPageId = "Impress Customer Staging List";
    LookupPageId = "Impress Customer Staging List";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(10; "SQL Run ID"; Integer)
        {
            Caption = 'SQL Run ID';
        }
        field(20; "SQL Entry No."; Integer)
        {
            Caption = 'SQL Entry No.';
        }
        field(30; "Source Database"; Code[20])
        {
            Caption = 'Source Database';
        }
        field(40; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
        }
        field(50; Name; Text[100])
        {
            Caption = 'Name';
        }
        field(60; "Search Name"; Code[100])
        {
            Caption = 'Search Name';
        }
        field(70; Address; Text[100])
        {
            Caption = 'Address';
        }
        field(80; "Address 2"; Text[100])
        {
            Caption = 'Address 2';
        }
        field(90; City; Text[50])
        {
            Caption = 'City';
        }
        field(100; State; Code[20])
        {
            Caption = 'State';
        }
        field(110; "Post Code"; Code[20])
        {
            Caption = 'Post Code';
        }
        field(120; "Country Code"; Code[10])
        {
            Caption = 'Country Code';
        }
        field(130; "Phone No."; Text[30])
        {
            Caption = 'Phone No.';
        }
        field(140; Email; Text[100])
        {
            Caption = 'Email';
        }
        field(150; Contact; Text[100])
        {
            Caption = 'Contact';
        }
        field(160; "Payment Terms Code"; Code[20])
        {
            Caption = 'Payment Terms Code';
        }
        field(170; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
        }
        field(180; "Credit Limit"; Decimal)
        {
            Caption = 'Credit Limit';
        }
        field(190; "Sales Tax Code"; Code[30])
        {
            Caption = 'Sales Tax Code';
        }
        field(200; "Salesperson Code"; Code[20])
        {
            Caption = 'Salesperson Code';
        }
        field(210; "Price Level"; Code[20])
        {
            Caption = 'Price Level';
        }
        field(220; "Customer Status"; Code[1])
        {
            Caption = 'Customer Status';
        }
        field(230; "Customer Hold"; Code[1])
        {
            Caption = 'Customer Hold';
        }
        field(240; Operation; Enum "Impress Customer Operation")
        {
            Caption = 'Operation';
        }
        field(250; "Transport Status"; Enum "Impress Integration Status")
        {
            Caption = 'Transport Status';
        }
        field(260; "Error Message"; Text[1000])
        {
            Caption = 'Error Message';
        }
        field(270; "Received DateTime"; DateTime)
        {
            Caption = 'Received DateTime';
        }
        field(280; "Processed DateTime"; DateTime)
        {
            Caption = 'Processed DateTime';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(SQLRun; "SQL Run ID") { }
        key(CustomerNo; "Customer No.") { }
        key(TransportStatus; "Transport Status") { }
        key(Operation; Operation) { }
    }

    trigger OnInsert()
    begin
        if "Received DateTime" = 0DT then
            "Received DateTime" := CurrentDateTime();

        "Transport Status" := "Transport Status"::New;
    end;
}
