table 80009 "Impress Sales Header Staging"
{
    Caption = 'Impress Sales Header Staging';
    DataClassification = CustomerContent;
    DataCaptionFields = "Sales Order No.", "Customer Name";

    fields
    {
        field(1; "Entry No."; Integer) { AutoIncrement = true; }
        field(10; "SQL Run ID"; BigInteger) { }
        field(20; "Source Database"; Code[50]) { }
        field(30; "Source Sales Order ID"; BigInteger) { }
        field(40; "Sales Order No."; Code[35]) { }
        field(50; "Customer No."; Code[20]) { }
        field(60; "Order Date"; Date) { }
        field(70; "Requested Shipment Date"; Date) { }
        field(80; "Not Before Date"; Date) { }
        field(90; "Cancel Date"; Date) { }
        field(100; "Due Date"; Date) { }
        field(110; "Date Entered"; Date) { }
        field(120; "Source Last Changed DateTime"; DateTime) { }
        field(130; "Customer PO No."; Code[35]) { }
        field(140; "End Customer PO No."; Code[35]) { }
        field(150; "Source Warehouse Code"; Code[20]) { }
        field(160; "BC Location Code"; Code[10]) { }
        field(170; "Ship Via Code"; Code[20]) { }
        field(180; "Payment Terms Code"; Code[10]) { }
        field(190; "Currency Code"; Code[10]) { }
        field(200; "Exchange Rate"; Decimal) { DecimalPlaces = 0 : 15; }
        field(210; "Product Total"; Decimal) { }
        field(220; "Product Quantity"; Decimal) { DecimalPlaces = 0 : 5; }
        field(230; "Miscellaneous Total"; Decimal) { }
        field(240; "Miscellaneous Quantity"; Decimal) { DecimalPlaces = 0 : 5; }
        field(250; "Shipping Amount"; Decimal) { }
        field(260; "Discount Rate"; Decimal) { }
        field(270; "Discount Amount"; Decimal) { }
        field(280; "Sales Order Total"; Decimal) { }
        field(290; Complete; Boolean) { }
        field(300; Shorted; Boolean) { }
        field(310; "Shipped In Full"; Boolean) { }
        field(320; "On Hold"; Boolean) { }
        field(330; "Ready To Bill"; Boolean) { }
        field(340; "Billing Hold"; Boolean) { }
        field(350; "Division Code"; Code[20]) { }
        field(360; "Entered By User"; Code[50]) { }
        field(370; "Changed By User"; Code[50]) { }
        field(380; "Ship-to Name"; Text[100]) { }
        field(390; "Ship-to Address"; Text[100]) { }
        field(400; "Ship-to Address 2"; Text[100]) { }
        field(410; "Ship-to Address 3"; Text[100]) { }
        field(420; "Ship-to City"; Text[50]) { }
        field(430; "Ship-to State"; Code[30]) { }
        field(440; "Ship-to Post Code"; Code[20]) { }
        field(450; "Ship-to Country Code"; Code[10]) { }
        field(460; Operation; Enum "Impress Sales Operation") { }
        field(470; "Transport Status"; Enum "Impress Integration Status") { }
        field(480; "Processing Status"; Enum "Impress Processing Status") { }
        field(490; "Error Message"; Text[2048]) { }
        field(500; "BC System ID"; Guid) { }
        field(510; "BC Document No."; Code[20]) { }
        field(520; "Extracted Date Time"; DateTime) { }
        field(530; "Sent to BC Date Time"; DateTime) { }
        field(540; "Processed Date Time"; DateTime) { }
        field(550; "Customer Name"; Text[100])
        {
            Caption = 'Customer Name';
            FieldClass = FlowField;
            CalcFormula = lookup(Customer.Name where("No." = field("Customer No.")));
        }
        field(560; "Tax Area Code"; Code[20]) { }
        field(570; "Tax Area Description"; Text[100]) { }
        field(580; "Shipping Is Taxable"; Boolean) { }
        field(590; "Tax Rate Total"; Decimal) { DecimalPlaces = 0 : 5; }
        field(600; "Tax Jurisdiction Code 1"; Code[10]) { }
        field(610; "Tax Jurisdiction Desc. 1"; Text[100]) { }
        field(620; "Tax Jurisdiction Rate 1"; Decimal) { DecimalPlaces = 0 : 5; }
        field(630; "Tax Jurisdiction G/L Acc. 1"; Code[20]) { }
        field(640; "Tax Jurisdiction Code 2"; Code[10]) { }
        field(650; "Tax Jurisdiction Desc. 2"; Text[100]) { }
        field(660; "Tax Jurisdiction Rate 2"; Decimal) { DecimalPlaces = 0 : 5; }
        field(670; "Tax Jurisdiction G/L Acc. 2"; Code[20]) { }
        field(680; "Tax Jurisdiction Code 3"; Code[10]) { }
        field(690; "Tax Jurisdiction Desc. 3"; Text[100]) { }
        field(700; "Tax Jurisdiction Rate 3"; Decimal) { DecimalPlaces = 0 : 5; }
        field(710; "Tax Jurisdiction G/L Acc. 3"; Code[20]) { }
        field(720; "Tax Jurisdiction Code 4"; Code[10]) { }
        field(730; "Tax Jurisdiction Desc. 4"; Text[100]) { }
        field(740; "Tax Jurisdiction Rate 4"; Decimal) { DecimalPlaces = 0 : 5; }
        field(750; "Tax Jurisdiction G/L Acc. 4"; Code[20]) { }
        field(760; "Source Bill-to Code"; Text[8]) { }
        field(770; "Bill-to Name"; Text[65]) { }
        field(780; "Bill-to Address"; Text[55]) { }
        field(790; "Bill-to Address 2"; Text[55]) { }
        field(800; "Bill-to Address 3"; Text[55]) { }
        field(810; "Bill-to City"; Text[30]) { }
        field(820; "Bill-to State"; Text[30]) { }
        field(830; "Bill-to Post Code"; Text[10]) { }
        field(840; "Source Ship-to Code"; Text[8]) { }
    }
    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(SourceIdentity; "Source Database", "Source Sales Order ID") { Unique = true; }
        key(RunTransport; "SQL Run ID", "Transport Status") { }
        key(OrderNo; "Sales Order No.") { }
    }
    trigger OnInsert()
    begin
        if "Extracted Date Time" = 0DT then
            "Extracted Date Time" := CurrentDateTime();
        "Processing Status" := "Processing Status"::Pending;
    end;

    trigger OnDelete()
    var
        SalesLineStaging: Record "Impress Sales Line Staging";
    begin
        SalesLineStaging.SetRange("Source Database", "Source Database");
        SalesLineStaging.SetRange("Source Sales Order ID", "Source Sales Order ID");
        SalesLineStaging.DeleteAll(true);
    end;
}
