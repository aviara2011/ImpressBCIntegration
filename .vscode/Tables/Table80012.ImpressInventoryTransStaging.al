table 80012 "Impress Inv Trans Staging"
{
    Caption = 'Impress Inventory Trans Staging';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; BigInteger) { AutoIncrement = true; }
        field(10; "Source Database"; Text[50]) { }
        field(20; "Source Transaction ID"; BigInteger) { }
        field(30; "G/L Date"; Date) { }
        field(40; "Transaction Type"; Text[30]) { }
        field(50; "Transaction Source"; Text[30]) { }
        field(60; "Source SKU No."; Text[50]) { }
        field(70; "Source Size"; Text[30]) { }
        field(80; "Source Warehouse Code"; Text[30]) { }
        field(90; Quantity; Decimal) { DecimalPlaces = 0 : 5; }
        field(100; "Source Order No."; Text[50]) { }
        field(110; "Source Order Line No."; Integer) { }
        field(120; "Source G/L Account"; Text[30]) { }
        field(130; "Source Inventory G/L Account"; Text[30]) { }
        field(140; "Source Offset G/L Account"; Text[30]) { }
        field(150; "Source Adjustment G/L Account"; Text[30]) { }
        field(160; "Source Cost"; Decimal) { }
        field(170; "Source LIFO/FIFO Cost"; Decimal) { }
        field(180; "Source LIFO/FIFO Cost Adj."; Decimal) { }
        field(190; "Source Added Cost"; Decimal) { }
        field(200; "Source Freight Cost"; Decimal) { }
        field(210; "Source Other Cost"; Decimal) { }
        field(220; "Source SKU ID"; BigInteger) { }
        field(230; "BC Item No."; Code[20]) { }
        field(240; "BC Variant Code"; Code[10]) { }
        field(250; "BC Location Code"; Code[10]) { }
        field(260; "SKU Division Code"; Text[30]) { }
        field(270; "Source Document Division Code"; Text[30]) { }
        field(280; "Division Code"; Code[20]) { }
        field(290; "Division Source"; Text[30]) { }
        field(300; "Transaction Handler"; Text[30]) { }
        field(310; "Processing Status"; Enum "Impress Processing Status") { }
        field(320; "Transport Status"; Enum "Impress Integration Status") { }
        field(330; "Related Sales Doc. Entry No."; BigInteger) { Caption = 'Related Sales Document Entry No.'; }
        field(340; "BC System ID"; Guid) { }
        field(350; "BC Document No."; Code[20]) { }
        field(360; "Error Message"; Text[2048]) { }
        field(370; "Date Staged"; DateTime) { }
        field(380; "Date Processing Started"; DateTime) { }
        field(390; "Date Processed"; DateTime) { }
        field(400; "Integration Posting ID"; Guid) { Editable = false; }
        field(410; "BC Posted Document Type"; Text[30]) { Editable = false; }
        field(420; "BC Posted Document No."; Code[20]) { Editable = false; }
        field(430; "BC Posted Posting Date"; Date) { Editable = false; }
        field(440; "Processed Date/Time"; DateTime) { Editable = false; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(SourceIdentity; "Source Database", "Source Transaction ID") { Unique = true; }
        key(IntegrationPosting; "Integration Posting ID") { }
    }

    trigger OnInsert()
    begin
        if "Date Staged" = 0DT then
            "Date Staged" := CurrentDateTime();
    end;

    trigger OnDelete()
    var
        Journal: Record "Item Journal Line";
        Tracking: Codeunit "Impress Posting Tracking";
    begin
        if not IsTemporary() and ("Transaction Type" = 'R') and ("Transaction Source" = 'P') then
            if Tracking.HasPostedEvidence(SystemId) then
                Error('This R/P transaction has posted receipt evidence and must be retained for reconciliation.');
        if IsTemporary() or IsNullGuid("Integration Posting ID") then
            exit;
        if Tracking.HasPostedEvidence("Integration Posting ID") then
            Error('This staging record has posted BC entries for Integration Posting ID %1 and must be retained for reconciliation.', "Integration Posting ID");
        Journal.SetRange("Integration Posting ID", "Integration Posting ID");
        if not Journal.IsEmpty() then
            Error('Delete the unposted journal line for Integration Posting ID %1 before deleting its staging record.', "Integration Posting ID");
    end;
}
