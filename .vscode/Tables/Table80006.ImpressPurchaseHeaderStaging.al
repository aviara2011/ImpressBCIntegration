table 80006 "Impress Purch Header Staging"
{
    Caption = 'Impress Purchase Header Staging';
    DataClassification = CustomerContent;
    DrillDownPageId = "Impress Purch. Header Staging";
    LookupPageId = "Impress Purch. Header Staging";
    fields
    {
        field(1; "Entry No."; Integer) { AutoIncrement = true; }
        field(10; "SQL Run ID"; BigInteger) { }
        field(20; "Source Database"; Code[50]) { }
        field(30; "Source POrder ID"; BigInteger) { }
        field(40; "Purchase Order No."; Code[35]) { }
        field(50; "Vendor No."; Code[20]) { }
        field(60; "Order Date"; Date) { }
        field(70; "Shipment Date"; Date) { }
        field(80; "First Expected Receipt Date"; Date) { }
        field(90; "Last Expected Receipt Date"; Date) { }
        field(100; "Cancel Date"; Date) { }
        field(110; "Not Before Date"; Date) { }
        field(120; "Date Entered"; Date) { }
        field(130; "Source Last Changed Date Time"; DateTime) { }
        field(140; "First Receipt Date"; Date) { }
        field(150; "Last Receipt Date"; Date) { }
        field(160; "Source Warehouse Code"; Code[20]) { }
        field(170; "BC Location Code"; Code[10]) { }
        field(180; "Ship Via Code"; Code[20]) { }
        field(190; "Payment Terms Code"; Code[10]) { }
        field(200; "Currency Code"; Code[10]) { }
        field(210; "Exchange Rate"; Decimal) { DecimalPlaces = 0 : 15; }
        field(220; "Allow Over Receipt"; Boolean) { }
        field(230; "Allow Under Receipt"; Boolean) { }
        field(240; "Total Quantity Ordered"; Decimal) { DecimalPlaces = 0 : 5; }
        field(250; "Total Quantity Received"; Decimal) { DecimalPlaces = 0 : 5; }
        field(260; "Total Quantity Remaining"; Decimal) { DecimalPlaces = 0 : 5; }
        field(270; "Product Total"; Decimal) { }
        field(280; "Miscellaneous Total"; Decimal) { }
        field(290; "Shipping Amount"; Decimal) { }
        field(300; "Unit Freight Cost"; Decimal) { }
        field(310; "Unit Other Cost"; Decimal) { }
        field(320; "Discount Rate"; Decimal) { }
        field(330; "Discount Amount"; Decimal) { }
        field(340; "Purchase Order Total"; Decimal) { }
        field(350; Complete; Boolean) { }
        field(360; Shorted; Boolean) { }
        field(370; "On Hold"; Boolean) { }
        field(380; "Buyer User"; Code[50]) { }
        field(390; "Received By User"; Code[50]) { }
        field(400; "Related Sales Order No."; Code[35]) { }
        field(410; "Ship-to Name"; Text[100]) { }
        field(420; "Ship-to Address"; Text[100]) { }
        field(430; "Ship-to Address 2"; Text[100]) { }
        field(440; "Ship-to Address 3"; Text[100]) { }
        field(450; "Ship-to City"; Text[50]) { }
        field(460; "Ship-to State"; Code[30]) { }
        field(470; "Ship-to Post Code"; Code[20]) { }
        field(480; "Ship-to Country Code"; Code[10]) { }
        field(490; Operation; Enum "Impress Purchase Operation") { }
        field(500; "Transport Status"; Enum "Impress Integration Status") { }
        field(510; "Processing Status"; Enum "Impress Processing Status") { }
        field(520; "Error Message"; Text[2048]) { }
        field(530; "BC System ID"; Guid) { }
        field(540; "BC Document No."; Code[20]) { }
        field(550; "Extracted Date Time"; DateTime) { }
        field(560; "Sent to BC Date Time"; DateTime) { }
        field(570; "Processed Date Time"; DateTime) { }
    }
    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(SourceIdentity; "Source Database", "Source POrder ID") { Unique = true; }
        key(RunTransport; "SQL Run ID", "Transport Status") { }
        key(PONo; "Purchase Order No.") { }
    }
    trigger OnInsert()
    begin
        if "Extracted Date Time" = 0DT then
            "Extracted Date Time" := CurrentDateTime();
        "Processing Status" := "Processing Status"::Pending;
    end;
}
