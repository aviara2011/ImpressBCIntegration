table 80007 "Impress Purchase Line Staging"
{
    Caption = 'Impress Purchase Line Staging';
    DataClassification = CustomerContent;
    DrillDownPageId = "Impress Purch. Line Staging";
    LookupPageId = "Impress Purch. Line Staging";
    fields
    {
        field(1; "Entry No."; Integer) { AutoIncrement = true; }
        field(10; "SQL Run ID"; BigInteger) { }
        field(20; "Source Database"; Code[50]) { }
        field(30; "Source POrder ID"; BigInteger) { }
        field(40; "Source POrder Detail ID"; BigInteger) { }
        field(50; "Size Position"; Integer) { }
        field(60; "Purchase Order No."; Code[35]) { }
        field(70; "Source Line No."; Integer) { }
        field(80; "Source Sequence"; Integer) { }
        field(90; "Source Design Line No."; Integer) { }
        field(100; "BC Line No."; Integer) { }
        field(110; "Vendor No."; Code[20]) { }
        field(120; "Source SKU"; Code[50]) { }
        field(130; "Source Style"; Code[30]) { }
        field(140; "Source Color"; Code[20]) { }
        field(150; "Source Size"; Code[20]) { }
        field(160; "BC Item No."; Code[20]) { }
        field(170; "BC Variant Code"; Code[10]) { }
        field(180; Description; Text[100]) { }
        field(190; "Unit of Measure Code"; Code[10]) { }
        field(200; "Quantity Ordered"; Decimal) { DecimalPlaces = 0 : 5; }
        field(210; "Quantity Received"; Decimal) { DecimalPlaces = 0 : 5; }
        field(220; "Quantity Remaining"; Decimal) { DecimalPlaces = 0 : 5; }
        field(230; "Direct Unit Cost"; Decimal) { }
        field(240; "Full Unit Cost"; Decimal) { }
        field(250; "Ordered Line Amount"; Decimal) { }
        field(260; "Received Line Amount"; Decimal) { }
        field(270; "Remaining Line Amount"; Decimal) { }
        field(280; "Order Date"; Date) { }
        field(290; "Shipment Date"; Date) { }
        field(300; "Expected Receipt Date"; Date) { }
        field(310; "First Receipt Date"; Date) { }
        field(320; "Last Receipt Date"; Date) { }
        field(330; Complete; Boolean) { }
        field(340; Shorted; Boolean) { }
        field(350; "On Hold"; Boolean) { }
        field(360; "Ship Via Code"; Code[20]) { }
        field(370; "Division Code"; Code[20]) { }
        field(380; "Related Production Header ID"; BigInteger) { }
        field(390; Operation; Enum "Impress Purchase Operation") { }
        field(400; "Transport Status"; Enum "Impress Integration Status") { }
        field(410; "Processing Status"; Enum "Impress Processing Status") { }
        field(420; "Error Message"; Text[2048]) { }
        field(430; "BC Header System ID"; Guid) { }
        field(440; "BC Document No."; Code[20]) { }
        field(450; "BC Line System ID"; Guid) { }
        field(460; "Extracted Date Time"; DateTime) { }
        field(470; "Sent to BC Date Time"; DateTime) { }
        field(480; "Processed Date Time"; DateTime) { }
    }
    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(SourceIdentity; "Source Database", "Source POrder Detail ID", "Size Position") { Unique = true; }
        key(RunTransport; "SQL Run ID", "Transport Status") { }
        key(DocumentLine; "Source Database", "Purchase Order No.", "BC Line No.") { }
    }
    trigger OnInsert()
    begin
        if "Extracted Date Time" = 0DT then
            "Extracted Date Time" := CurrentDateTime();
        "Processing Status" := "Processing Status"::Pending;
    end;
}
