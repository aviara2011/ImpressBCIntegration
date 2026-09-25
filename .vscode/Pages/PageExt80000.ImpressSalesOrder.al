pageextension 80000 "Impress Sales Order Ext." extends "Sales Order"
{
    layout
    {
        addlast(General)
        {
            field(ImpressOnHold; Rec."On Hold")
            {
                ApplicationArea = All;
                Caption = 'On Hold';
                ToolTip = 'Specifies the reason code that prevents the sales order from being released or posted.';
            }
        }
        addafter(General)
        {
            group("Impress Source")
            {
                Caption = 'Impress Source';

                field("Impress Source Sales Order No."; Rec."Impress Source Sales Order No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the original sales order number in Impress.';
                }
                field("Impress Source Database"; Rec."Impress Source Database")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the Impress database from which the sales order originated.';
                }
                field("Impress Source Sales Order ID"; Rec."Impress Source Sales Order ID")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the internal sales order identifier from the source Impress database.';
                }
            }
        }
    }
}
