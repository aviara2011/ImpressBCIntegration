table 80011 "Impress Conversion Mapping"
{
    Caption = 'Impress Conversion Mapping';
    DataClassification = CustomerContent;

    fields
    {
        field(1; Module; Enum "Impress Conversion Module")
        {
            Caption = 'Module';
        }
        field(10; "Source Database"; Code[50])
        {
            Caption = 'Source Database';
        }
        field(20; "Conversion Type"; Enum "Impress Conversion Type")
        {
            Caption = 'Conversion Type';
        }
        field(30; "Impress Code"; Code[50])
        {
            Caption = 'Impress Code';
        }
        field(40; "BC Type"; Enum "Impress Conv. Target Type")
        {
            Caption = 'BC Type';
        }
        field(50; "BC No."; Code[20])
        {
            Caption = 'BC No.';
            TableRelation = if ("BC Type" = const("G/L Account")) "G/L Account"."No."
            else if ("BC Type" = const(Item)) Item."No."
            else if ("BC Type" = const(Resource)) Resource."No."
            else if ("BC Type" = const("Fixed Asset")) "Fixed Asset"."No."
            else if ("BC Type" = const("Charge (Item)")) "Item Charge"."No.";
        }
    }

    keys
    {
        key(PK; Module, "Source Database", "Conversion Type", "Impress Code")
        {
            Clustered = true;
        }
    }
}
