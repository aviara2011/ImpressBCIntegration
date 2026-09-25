table 80014 "Impress Sales Doc Line Staging"
{
    Caption = 'Impress Sales Doc Line Staging';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; BigInteger) { AutoIncrement = true; }
        field(10; "Sales Document Entry No."; BigInteger)
        {
            TableRelation = "Impress Sales Doc Hdr Staging"."Entry No.";
        }
        field(20; "Source Database"; Text[50]) { }
        field(30; "Source Customer Code"; Text[50]) { }
        field(40; "Document Type"; Text[30]) { }
        field(50; "Document No."; Text[50]) { }
        field(60; "Source Line No."; Integer) { }
        field(70; "Source Sequence"; Integer) { }
        field(80; "Size Position"; Integer) { }
        field(90; "Source Line Type"; Text[30]) { }
        field(100; "Source Item Code"; Text[50]) { }
        field(110; "Source Raw SKU No."; Text[50]) { }
        field(120; "Source Size"; Text[30]) { }
        field(130; "Source Description"; Text[250]) { }
        field(140; Quantity; Decimal) { DecimalPlaces = 0 : 5; }
        field(150; "Unit Price"; Decimal) { }
        field(160; Amount; Decimal) { }
        field(170; "BC Item No."; Code[20]) { }
        field(180; "BC Variant Code"; Code[10]) { }
        field(190; "Revenue G/L Account"; Text[30]) { }
        field(200; "Inventory G/L Account"; Text[30]) { }
        field(210; "COGS G/L Account"; Text[30]) { }
        field(220; "Related Inventory Trans. ID"; BigInteger) { Caption = 'Related Inventory Transaction ID'; }
        field(230; "Processing Status"; Enum "Impress Processing Status") { }
        field(240; "Transport Status"; Enum "Impress Integration Status") { }
        field(250; "BC System ID"; Guid) { }
        field(260; "BC Line System ID"; Guid) { }
        field(270; "Error Message"; Text[2048]) { }
        field(280; "Date Staged"; DateTime) { }
        field(290; "Date Processed"; DateTime) { }
        field(300; "BC Sales Line No."; Integer) { Editable = false; }
        field(310; "Tax Group Code"; Code[20]) { Caption = 'Tax Group Code'; }
        field(320; "Tax Group Description"; Text[100]) { Caption = 'Tax Group Description'; }
        field(330; "Non Tax Category Code"; Text[20]) { Caption = 'Non Tax Category Code'; }
        // AL Integer fields use zero for an unavailable source value.
        field(340; "Source Sales Order Line No."; Integer) { Caption = 'Source Sales Order Line No.'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(SourceIdentity; "Sales Document Entry No.", "Source Line No.", "Source Sequence", "Size Position") { Unique = true; }
    }

    trigger OnInsert()
    begin
        if "Date Staged" = 0DT then
            "Date Staged" := CurrentDateTime();
    end;
}
