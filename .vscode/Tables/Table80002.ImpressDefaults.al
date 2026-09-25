table 80002 "Impress Defaults"
{
    Caption = 'Impress Defaults';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Item Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            TableRelation = "Unit of Measure";
        }
        field(20; "Item Gen. Prod. Post. Group"; Code[20])
        {
            Caption = 'Gen. Product Posting Group Code';
            TableRelation = "Gen. Product Posting Group";
        }
        field(30; "Item Inventory Posting Group"; Code[20])
        {
            Caption = 'Inventory Posting Group Code';
            TableRelation = "Inventory Posting Group";
        }
        field(40; "Cust. Gen. Bus. Posting Group"; Code[20])
        {
            Caption = 'Customer Gen. Business Posting Group';
            TableRelation = "Gen. Business Posting Group";
        }
        field(60; "Customer Posting Group"; Code[20])
        {
            Caption = 'Customer Posting Group';
            TableRelation = "Customer Posting Group";
        }
        field(70; "Vend. Gen. Bus. Posting Group"; Code[20])
        {
            Caption = 'Vendor Gen. Business Posting Group';
            TableRelation = "Gen. Business Posting Group";
        }
        field(80; "Vendor Posting Group"; Code[20])
        {
            Caption = 'Vendor Posting Group';
            TableRelation = "Vendor Posting Group";
        }
        field(90; "Opening Inv. Journal Template"; Code[10])
        {
            Caption = 'Opening Inventory Journal Template';
            TableRelation = "Item Journal Template".Name;
        }
        field(100; "Opening Inv. Journal Batch"; Code[10])
        {
            Caption = 'Opening Inventory Journal Batch';
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("Opening Inv. Journal Template"));
        }
        field(110; "Open Inv. Gen. Bus. Group"; Code[20])
        {
            Caption = 'Gen. Bus. Posting Group (Open Inv.)';
            TableRelation = "Gen. Business Posting Group";
        }
        field(120; "Category Dimension Code"; Code[20])
        {
            Caption = 'Category Dimension';
            TableRelation = Dimension.Code;
        }
        field(130; "Sales Cr. Memo Item Resource"; Code[20])
        {
            Caption = 'Sales Credit Memo Item Resource';
            TableRelation = Resource."No.";
        }
        field(140; "Impress Reclass Jnl. Template"; Code[10])
        {
            Caption = 'Impress Reclass Journal Template';
            TableRelation = "Item Journal Template".Name where(Type = const(Transfer));
        }
        field(150; "Apparel Reclass Journal Batch"; Code[10])
        {
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("Impress Reclass Jnl. Template"));
        }
        field(160; "Stickers Reclass Journal Batch"; Code[10])
        {
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("Impress Reclass Jnl. Template"));
        }
        field(180; "Impress Item Journal Template"; Code[10])
        {
            TableRelation = "Item Journal Template".Name;
        }
        field(190; "Apparel Item Journal Batch"; Code[10])
        {
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("Impress Item Journal Template"));
        }
        field(200; "Stickers Item Journal Batch"; Code[10])
        {
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("Impress Item Journal Template"));
        }
        field(170; "Gen. Bus. Posting Group (Inv.)"; Code[20])
        {
            Caption = 'Gen. Bus. Posting Group (Inv.)';
            TableRelation = "Gen. Business Posting Group".Code;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
