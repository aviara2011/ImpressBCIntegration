pageextension 80002 "Impress Item Journal Ext." extends "Item Journal"
{
    layout
    {
        addafter(Description)
        {
            field(ImpressIntegrationPostingID; Rec."Integration Posting ID")
            {
                ApplicationArea = All;
                Caption = 'Integration Posting ID';
                Editable = false;
                ToolTip = 'Specifies the identifier shared by all journal components of the Impress transaction.';
            }
            field(ImpressInventoryPostingGroup; Rec."Inventory Posting Group")
            {
                ApplicationArea = All;
                Caption = 'Inventory Posting Group';
                Editable = false;
                ToolTip = 'Specifies the inventory posting group used to resolve the source inventory account.';
            }
        }
    }
}
