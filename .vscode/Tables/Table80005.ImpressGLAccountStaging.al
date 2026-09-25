table 80005 "Impress G/L Account Staging"
{
    Caption = 'Impress G/L Account Staging';
    DataClassification = CustomerContent;
    DrillDownPageId = "Impress G/L Account Staging";
    LookupPageId = "Impress G/L Account Staging";

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
        field(40; "G/L Account No."; Code[20]) { Caption = 'G/L Account No.'; }
        field(50; Description; Text[100]) { Caption = 'Description'; }
        field(60; "Long Description"; Text[250]) { Caption = 'Long Description'; }
        field(70; "Account Type Code"; Code[10]) { Caption = 'Account Type Code'; }
        field(80; Inactive; Boolean) { Caption = 'Inactive'; }
        field(90; "Debit Account No."; Code[20]) { Caption = 'Debit Account No.'; }
        field(100; "Credit Account No."; Code[20]) { Caption = 'Credit Account No.'; }
        field(110; "Cost of Sales Account No."; Code[20]) { Caption = 'Cost of Sales Account No.'; }
        field(120; "Cost of Sales Credit Acct. No."; Code[20]) { Caption = 'Cost of Sales Credit Account No.'; }
        field(130; "Factor Fee Account No."; Code[20]) { Caption = 'Factor Fee Account No.'; }
        field(140; "Factor Reserve Account No."; Code[20]) { Caption = 'Factor Reserve Account No.'; }
        field(150; Operation; Code[20]) { Caption = 'Operation'; }
        field(160; "Transport Status"; Enum "Impress Integration Status") { Caption = 'Transport Status'; }
        field(170; "Error Message"; Text[1000]) { Caption = 'Error Message'; }
        field(180; "BC System ID"; Guid) { Caption = 'BC System ID'; }
        field(190; "Extracted DateTime"; DateTime) { Caption = 'Extracted DateTime'; }
        field(200; "Sent to BC DateTime"; DateTime) { Caption = 'Sent to BC DateTime'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(SQLRun; "SQL Run ID") { }
        key(SQLRunAccount; "SQL Run ID", "G/L Account No.") { }
        key(GLAccountNo; "G/L Account No.") { }
        key(TransportStatus; "Transport Status") { }
    }

    trigger OnInsert()
    begin
        if "Extracted DateTime" = 0DT then
            "Extracted DateTime" := CurrentDateTime();
        if Operation = '' then
            Operation := 'Upsert';
        "Transport Status" := "Transport Status"::New;
    end;
}
