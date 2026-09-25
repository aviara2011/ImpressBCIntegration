table 80001 "Impress Item Staging"
{
    Caption = 'Impress Item Staging';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(10; "Source Database"; Code[50])
        {
            Caption = 'Source Database';
        }
        field(20; "Source System ID"; BigInteger)
        {
            Caption = 'Source System ID';
        }
        field(30; "Source SKU Item No."; Code[30])
        {
            Caption = 'Source SKU Item No.';
        }
        field(40; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(50; "Style Code"; Code[20])
        {
            Caption = 'Style Code';
        }
        field(60; "Color Code"; Code[10])
        {
            Caption = 'Color Code';
        }
        field(70; "Size Code"; Code[10])
        {
            Caption = 'Size Code';
        }
        field(80; "Variant Code"; Code[20])
        {
            Caption = 'Variant Code';
        }
        field(90; Description; Text[150])
        {
            Caption = 'Description';
        }
        field(100; "Purchase Description"; Text[150])
        {
            Caption = 'Purchase Description';
        }
        field(110; "SKU Status"; Code[1])
        {
            Caption = 'SKU Status';
        }
        field(120; "Unit of Measure"; Code[10])
        {
            Caption = 'Unit of Measure';
        }
        field(130; "Item Category Code"; Code[30])
        {
            Caption = 'Item Category Code';
        }
        field(140; "Preferred Vendor No."; Code[20])
        {
            Caption = 'Preferred Vendor No.';
        }
        field(150; "Source Created DateTime"; DateTime)
        {
            Caption = 'Source Created DateTime';
        }
        field(160; "Source Modified DateTime"; DateTime)
        {
            Caption = 'Source Modified DateTime';
        }
        field(170; Status; Enum "Impress Integration Status")
        {
            Caption = 'Status';
        }
        field(180; "Error Message"; Text[1000])
        {
            Caption = 'Error Message';
        }
        field(190; "SQL Entry No."; Integer)
        {
            Caption = 'SQL Entry No.';
        }
        field(200; "Received DateTime"; DateTime)
        {
            Caption = 'Received DateTime';
        }
        field(210; "Processed DateTime"; DateTime)
        {
            Caption = 'Processed DateTime';
        }
        field(220; "SQL Run ID"; Integer)
        {
            Caption = 'SQL Run ID';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(SourceKey; "Source Database", "Source SKU Item No.", "Variant Code") { }
        key(ItemVariant; "Item No.", "Variant Code") { }
        key(StatusKey; Status) { }
    }

    trigger OnInsert()
    begin
        if "Received DateTime" = 0DT then
            "Received DateTime" := CurrentDateTime();
    end;
}
