pageextension 80001 "Impress Reclass Journal Ext." extends "Item Reclass. Journal"
{
    layout
    {
        addafter(Description)
        {
            field(ImpressGenBusPostingGroup; Rec."Gen. Bus. Posting Group")
            {
                ApplicationArea = All;
                Caption = 'Gen. Bus. Posting Group';
                Editable = false;
                ToolTip = 'Specifies the configured general business posting group for this journal line.';
            }
            field(ImpressGenProdPostingGroup; Rec."Gen. Prod. Posting Group")
            {
                ApplicationArea = All;
                Caption = 'Gen. Prod. Posting Group';
                Editable = false;
                ToolTip = 'Specifies the IMP profile that resolves the source adjustment account.';
            }
            field(ImpressInventoryPostingGroup; Rec."Inventory Posting Group")
            {
                ApplicationArea = All;
                Caption = 'Inventory Posting Group';
                Editable = false;
                ToolTip = 'Specifies the inventory posting group used with each location to resolve the inventory accounts.';
            }
            field(ImpressIntegrationPostingID; Rec."Integration Posting ID")
            {
                ApplicationArea = All;
                Caption = 'Integration Posting ID';
                Editable = false;
                ToolTip = 'Specifies the shared identifier linking this prepared journal line to its two Impress staging transactions.';
            }
        }
    }
}
