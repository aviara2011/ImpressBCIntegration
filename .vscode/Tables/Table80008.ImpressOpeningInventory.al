table 80008 "Impress Opening Inventory"
{
    Caption = 'Impress Opening Inventory Staging';
    DataClassification = CustomerContent;
    DrillDownPageId = "Impress Opening Inventory";
    LookupPageId = "Impress Opening Inventory";

    fields
    {
        field(1; "Entry No."; Integer) { AutoIncrement = true; }
        field(10; "Run ID"; Guid) { }
        field(20; "Source Database"; Code[50]) { }
        field(30; "Source BC Line No."; BigInteger) { }
        field(40; "BC Line No."; Integer) { }
        field(50; "Item No."; Code[20]) { }
        field(60; "Variant Code"; Code[10]) { }
        field(70; "Location Code"; Code[10]) { }
        field(80; "Posting Date"; Date) { }
        field(90; Quantity; Decimal) { DecimalPlaces = 0 : 5; }
        field(100; "Unit Cost"; Decimal) { DecimalPlaces = 0 : 5; }
        field(110; "Inventory Value"; Decimal) { DecimalPlaces = 0 : 5; }
        field(120; "Is FIFO Tracked"; Boolean) { }
        field(130; "FIFO Sequence"; BigInteger) { }
        field(140; "Send Status"; Enum "Impress Processing Status") { }
        field(150; "Error Message"; Text[2048]) { }
        field(160; "Journal Template Name"; Code[10]) { }
        field(170; "Journal Batch Name"; Code[10]) { }
        field(180; "Journal Line No."; Integer) { }
        field(190; "BC Journal Line System ID"; Guid) { }
        field(200; "Extracted Date Time"; DateTime) { }
        field(210; "Sent to BC Date Time"; DateTime) { }
        field(220; "Processed Date Time"; DateTime) { }
        field(230; "Impress Item No."; Code[25]) { }
        field(240; "Impress Variant Code"; Code[10]) { }
        field(250; "Division Code"; Code[20]) { }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(RunSequence; "Run ID", "BC Line No.") { Unique = true; }
        key(StatusRun; "Send Status", "Run ID", "BC Line No.") { }
    }

    trigger OnInsert()
    begin
        if "Extracted Date Time" = 0DT then
            "Extracted Date Time" := CurrentDateTime();
        if "Send Status" = "Send Status"::Pending then;
    end;
}
