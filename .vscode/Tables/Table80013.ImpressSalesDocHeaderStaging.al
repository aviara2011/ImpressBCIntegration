table 80013 "Impress Sales Doc Hdr Staging"
{
    Caption = 'Impress Sales Doc Header Staging';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; BigInteger) { AutoIncrement = true; }
        field(10; "Source Database"; Text[50]) { }
        field(20; "Source Customer Code"; Text[50]) { }
        field(30; "Source Document Type"; Text[30]) { }
        field(40; "Document Type"; Text[30]) { }
        field(50; "Document No."; Text[50]) { }
        field(60; "Source Sales Order No."; Text[50]) { }
        field(70; "Apply-to Invoice No."; Text[50]) { }
        field(80; "Invoice Date"; Date) { }
        field(90; "Due Date"; Date) { }
        field(100; "G/L Post Date"; Date) { }
        field(110; "Division Code"; Code[20]) { }
        field(120; "A/R G/L Account"; Text[30]) { }
        field(130; "Invoice Total"; Decimal) { }
        field(140; "Discount Rate"; Decimal) { DecimalPlaces = 0 : 5; }
        field(150; "Discount Amount"; Decimal) { }
        field(160; "Discount Adjust"; Decimal) { }
        field(170; "Source Balance"; Decimal) { }
        field(180; "Discount Taken"; Decimal) { }
        field(190; "Tax Area Code"; Text[30]) { }
        field(200; "Taxable Amount 1"; Decimal) { }
        field(210; "Taxable Amount 2"; Decimal) { }
        field(220; "Taxable Amount 3"; Decimal) { }
        field(230; "Taxable Amount 4"; Decimal) { }
        field(240; "Tax Rate 1"; Decimal) { DecimalPlaces = 0 : 5; }
        field(250; "Tax Rate 2"; Decimal) { DecimalPlaces = 0 : 5; }
        field(260; "Tax Rate 3"; Decimal) { DecimalPlaces = 0 : 5; }
        field(270; "Tax Rate 4"; Decimal) { DecimalPlaces = 0 : 5; }
        field(280; "Tax Total"; Decimal) { }
        field(290; "Tax Rate Total"; Decimal) { DecimalPlaces = 0 : 5; }
        field(300; "Shipping Is Taxable"; Boolean) { }
        field(310; "Tax Jurisdiction Code 1"; Text[30]) { }
        field(320; "Tax Jurisdiction Code 2"; Text[30]) { }
        field(330; "Tax Jurisdiction Code 3"; Text[30]) { }
        field(340; "Tax Jurisdiction Code 4"; Text[30]) { }
        field(350; "Tax G/L Account 1"; Text[30]) { }
        field(360; "Tax G/L Account 2"; Text[30]) { }
        field(370; "Tax G/L Account 3"; Text[30]) { }
        field(380; "Tax G/L Account 4"; Text[30]) { }
        field(390; "Has Inventory Impact"; Boolean) { }
        field(400; "First Inventory Transaction ID"; BigInteger) { }
        field(410; "Last Inventory Transaction ID"; BigInteger) { }
        field(420; "Inventory Transaction Count"; Integer) { }
        field(430; "Processing Phase"; Integer) { }
        field(440; "Processing Status"; Enum "Impress Processing Status") { }
        field(450; "Transport Status"; Enum "Impress Integration Status") { }
        field(460; "BC System ID"; Guid) { }
        field(470; "BC Document No."; Code[20]) { }
        field(480; "Error Message"; Text[2048]) { }
        field(490; "Date Staged"; DateTime) { }
        field(500; "Date Processing Started"; DateTime) { }
        field(510; "Date Processed"; DateTime) { }
        field(520; "Integration Posting ID"; Guid) { Editable = false; }
        field(530; "BC Sales Order No."; Code[20]) { Editable = false; }
        field(540; "Tax Area Description"; Text[100]) { }
        field(550; "Tax Jurisdiction Desc. 1"; Text[100]) { }
        field(560; "Tax Jurisdiction Desc. 2"; Text[100]) { }
        field(570; "Tax Jurisdiction Desc. 3"; Text[100]) { }
        field(580; "Tax Jurisdiction Desc. 4"; Text[100]) { }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(SourceIdentity; "Source Database", "Source Customer Code", "Source Document Type", "Document No.") { Unique = true; }
    }

    trigger OnInsert()
    begin
        if "Date Staged" = 0DT then
            "Date Staged" := CurrentDateTime();
    end;

    trigger OnDelete()
    var
        SalesLines: Record "Impress Sales Doc Line Staging";
    begin
        SalesLines.SetRange("Sales Document Entry No.", "Entry No.");
        SalesLines.DeleteAll(true);
    end;
}
