table 80004 "Impress Vendor Staging"
{
    Caption = 'Impress Vendor Staging';
    DataClassification = CustomerContent;
    DrillDownPageId = "Impress Vendor Staging List";
    LookupPageId = "Impress Vendor Staging List";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(10; "SQL Run ID"; Integer) { Caption = 'SQL Run ID'; }
        field(20; "SQL Entry No."; Integer) { Caption = 'SQL Entry No.'; }
        field(30; "Source Database"; Code[50]) { Caption = 'Source Database'; }
        field(40; "Vendor No."; Code[20]) { Caption = 'Vendor No.'; }
        field(50; Name; Text[100]) { Caption = 'Name'; }
        field(60; "Search Name"; Code[100]) { Caption = 'Search Name'; }
        field(70; Address; Text[100]) { Caption = 'Address'; }
        field(80; "Address 2"; Text[100]) { Caption = 'Address 2'; }
        field(90; "Address 3"; Text[100]) { Caption = 'Address 3'; }
        field(100; City; Text[50]) { Caption = 'City'; }
        field(110; State; Code[30]) { Caption = 'State'; }
        field(120; "Post Code"; Code[20]) { Caption = 'Post Code'; }
        field(130; "Country Code"; Code[10]) { Caption = 'Country Code'; }
        field(140; "Phone No."; Text[30]) { Caption = 'Phone No.'; }
        field(150; "Fax No."; Text[30]) { Caption = 'Fax No.'; }
        field(160; Email; Text[100]) { Caption = 'Email'; }
        field(170; "Home Page"; Text[100]) { Caption = 'Home Page'; }
        field(180; Contact; Text[100]) { Caption = 'Contact'; }
        field(190; "Payment Terms Code"; Code[20]) { Caption = 'Payment Terms Code'; }
        field(200; "Currency Code"; Code[10]) { Caption = 'Currency Code'; }
        field(210; "Account No."; Text[50]) { Caption = 'Account No.'; }
        field(220; "Warehouse Code"; Code[20]) { Caption = 'Warehouse Code'; }
        field(230; "Vendor Inactive"; Boolean) { Caption = 'Vendor Inactive'; }
        field(240; "Vendor Hold"; Code[10]) { Caption = 'Vendor Hold'; }
        field(250; "Source Created DateTime"; DateTime) { Caption = 'Source Created DateTime'; }
        field(260; "Source Modified DateTime"; DateTime) { Caption = 'Source Modified DateTime'; }
        field(270; Operation; Enum "Impress Vendor Operation") { Caption = 'Operation'; }
        field(280; "Transport Status"; Enum "Impress Integration Status") { Caption = 'Transport Status'; }
        field(290; "Error Message"; Text[1000]) { Caption = 'Error Message'; }
        field(300; "BC System ID"; Guid) { Caption = 'BC System ID'; }
        field(310; "Extracted DateTime"; DateTime) { Caption = 'Extracted DateTime'; }
        field(320; "Sent to BC DateTime"; DateTime) { Caption = 'Sent to BC DateTime'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(SQLRun; "SQL Run ID") { }
        key(VendorNo; "Vendor No.") { }
        key(TransportStatus; "Transport Status") { }
    }

    trigger OnInsert()
    begin
        if "Extracted DateTime" = 0DT then
            "Extracted DateTime" := CurrentDateTime();
        "Transport Status" := "Transport Status"::New;
    end;
}
