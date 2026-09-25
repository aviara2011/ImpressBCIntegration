table 80010 "Impress Sales Line Staging"
{
    Caption = 'Impress Sales Line Staging';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { AutoIncrement = true; }
        field(10; "SQL Run ID"; BigInteger) { }
        field(20; "Source Database"; Code[50]) { }
        field(30; "Source Sales Order ID"; BigInteger) { }
        field(40; "Source Sales Order Detail ID"; BigInteger) { }
        field(50; "Size Position"; Integer) { }
        field(60; "Sales Order No."; Code[35]) { }
        field(70; "Source Line No."; Integer) { }
        field(80; "Source Sequence"; Integer) { }
        field(90; "Source Design Line No."; Integer) { }
        field(100; "BC Line No."; Integer) { }
        field(110; "Customer No."; Code[20]) { }
        field(120; "Source Line Type"; Code[20]) { }
        field(130; "BC Line Type"; Code[10]) { }
        field(140; "Source Code"; Code[50]) { }
        field(150; "Source SKU"; Code[50]) { }
        field(160; "Source Style"; Code[30]) { }
        field(170; "Source Color"; Code[20]) { }
        field(180; "Source Size"; Code[20]) { }
        field(190; "BC Item No."; Code[20]) { }
        field(200; "BC Variant Code"; Code[10]) { }
        field(210; Description; Text[100]) { }
        field(220; "Unit of Measure Code"; Code[10]) { }
        field(230; Quantity; Decimal) { DecimalPlaces = 0 : 5; }
        field(240; "Quantity Shipped"; Decimal) { DecimalPlaces = 0 : 5; }
        field(250; "Quantity Invoiced"; Decimal) { DecimalPlaces = 0 : 5; }
        field(260; "Unit Price"; Decimal) { }
        field(270; "Line Amount"; Decimal) { }
        field(280; "Discount Rate"; Decimal) { }
        field(290; Discountable; Boolean) { }
        field(300; "Requested Date"; Date) { }
        field(310; "Ship Complete"; Boolean) { }
        field(320; Complete; Boolean) { }
        field(330; Shorted; Boolean) { }
        field(340; "Shipped In Full"; Boolean) { }
        field(350; "Sales Account No."; Code[20]) { }
        field(360; "Non-Tax Category Code"; Code[20]) { }
        field(370; "Division Code"; Code[20]) { }
        field(380; Operation; Enum "Impress Sales Operation") { }
        field(390; "Transport Status"; Enum "Impress Integration Status") { }
        field(400; "Processing Status"; Enum "Impress Processing Status") { }
        field(410; "Error Message"; Text[2048]) { }
        field(420; "BC System ID"; Guid) { }
        field(430; "BC Document No."; Code[20]) { }
        field(440; "BC Line System ID"; Guid) { }
        field(450; "Extracted Date Time"; DateTime) { }
        field(460; "Sent to BC Date Time"; DateTime) { }
        field(470; "Processed Date Time"; DateTime) { }
        field(480; "Tax Group Code"; Code[20]) { }
        field(490; "Tax Group Description"; Text[100]) { }
    }
    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(SourceIdentity; "Source Database", "Source Sales Order Detail ID", "Size Position") { Unique = true; }
        key(RunTransport; "SQL Run ID", "Transport Status") { }
        key(DocumentLine; "Source Database", "Source Sales Order ID", "BC Line No.") { }
        key(SourceOrder; "Source Database", "Source Sales Order ID", "Source Line No.", "Source Sequence", "Size Position", "Entry No.") { }
    }
    trigger OnInsert()
    begin
        if "Extracted Date Time" = 0DT then
            "Extracted Date Time" := CurrentDateTime();
        "Processing Status" := "Processing Status"::Pending;
    end;
}
