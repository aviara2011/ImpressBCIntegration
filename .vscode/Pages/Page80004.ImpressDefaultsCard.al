page 80004 "Impress Defaults"
{
    PageType = Card;
    SourceTable = "Impress Defaults";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Impress Defaults';
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            group(Items)
            {
                Caption = 'Items';

                field("Item Unit of Measure Code"; Rec."Item Unit of Measure Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default unit of measure code to use when creating items from Impress item staging records without a unit of measure.';
                }
                field("Item Gen. Prod. Post. Group"; Rec."Item Gen. Prod. Post. Group")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default general product posting group code to use when creating items from Impress item staging records.';
                }
                field("Item Inventory Posting Group"; Rec."Item Inventory Posting Group")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default inventory posting group code to use when creating items from Impress item staging records.';
                }
            }
            group(Customers)
            {
                Caption = 'Customers';

                field("Cust. Gen. Bus. Posting Group"; Rec."Cust. Gen. Bus. Posting Group")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default general business posting group code to use when creating customers from Impress customer staging records.';
                }
                field("Customer Posting Group"; Rec."Customer Posting Group")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default customer posting group code to use when creating customers from Impress customer staging records.';
                }
            }
            group(Vendors)
            {
                Caption = 'Vendors';

                field("Vend. Gen. Bus. Posting Group"; Rec."Vend. Gen. Bus. Posting Group")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default general business posting group code to use when creating vendors from Impress vendor staging records.';
                }
                field("Vendor Posting Group"; Rec."Vendor Posting Group")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default vendor posting group code to use when creating vendors from Impress vendor staging records.';
                }
            }
            group(SalesOrders)
            {
                Caption = 'Sales Orders';

                field("Sales Cr. Memo Item Resource"; Rec."Sales Cr. Memo Item Resource")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central Resource used to convert Impress item lines when creating sales credit memos without a physical item return.';
                }
            }
            group(InventoryTransactions)
            {
                Caption = 'Inventory Transactions';
                field("Gen. Bus. Posting Group (Inv.)"; Rec."Gen. Bus. Posting Group (Inv.)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the existing general business posting group used with dynamic Impress inventory transaction posting profiles.';
                }
                field("Impress Reclass Jnl. Template"; Rec."Impress Reclass Jnl. Template") { ApplicationArea = All; }
                field("Apparel Reclass Journal Batch"; Rec."Apparel Reclass Journal Batch") { ApplicationArea = All; }
                field("Stickers Reclass Journal Batch"; Rec."Stickers Reclass Journal Batch") { ApplicationArea = All; }
                field("Impress Item Journal Template"; Rec."Impress Item Journal Template") { ApplicationArea = All; }
                field("Apparel Item Journal Batch"; Rec."Apparel Item Journal Batch") { ApplicationArea = All; }
                field("Stickers Item Journal Batch"; Rec."Stickers Item Journal Batch") { ApplicationArea = All; }
            }
            group(OpeningInventory)
            {
                Caption = 'Opening Inventory';
                field("Opening Inv. Journal Template"; Rec."Opening Inv. Journal Template")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the dedicated item journal template used for Impress opening inventory.';
                }
                field("Opening Inv. Journal Batch"; Rec."Opening Inv. Journal Batch")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the dedicated item journal batch used for Impress opening inventory.';
                }
                field("Open Inv. Gen. Bus. Group"; Rec."Open Inv. Gen. Bus. Group")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the general business posting group assigned to item journal lines created for opening inventory.';
                }
                field("Category Dimension Code"; Rec."Category Dimension Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the dimension used to classify opening inventory item journal lines by the mapped Impress division code.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(ConversionMappings)
            {
                Caption = 'Conversion Mappings';
                ApplicationArea = All;
                Image = MapAccounts;
                RunObject = page "Impress Conversion Mappings";
                ToolTip = 'Maintain module-specific conversions from Impress codes to Business Central Resources.';
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;
}
