page 80015 "Impress Purchase Orders"
{
    PageType = List;
    SourceTable = "Impress Purch Header Staging";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Impress Staging Purchase Orders';
    CardPageId = "Impress Purchase Order";
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(PurchaseOrders)
            {
                field("Purchase Order No."; Rec."Purchase Order No.") { ApplicationArea = All; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; }
                field("Source POrder ID"; Rec."Source POrder ID") { ApplicationArea = All; }
                field("Vendor No."; Rec."Vendor No.") { ApplicationArea = All; }
                field("Order Date"; Rec."Order Date") { ApplicationArea = All; }
                field("Expected Receipt Date"; Rec."Last Expected Receipt Date") { ApplicationArea = All; }
                field("BC Location Code"; Rec."BC Location Code") { ApplicationArea = All; }
                field("Total Quantity Ordered"; Rec."Total Quantity Ordered") { ApplicationArea = All; }
                field("Purchase Order Total"; Rec."Purchase Order Total") { ApplicationArea = All; }
                field(Operation; Rec.Operation) { ApplicationArea = All; }
                field("Processing Status"; Rec."Processing Status") { ApplicationArea = All; StyleExpr = StatusStyle; }
                field("BC Document No."; Rec."BC Document No.") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ProcessSelected)
            {
                Caption = 'Process Selected';
                ApplicationArea = All;
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    SelectedHeaders: Record "Impress Purch Header Staging";
                    PurchaseOrderMgt: Codeunit "Impress Purchase Order Mgt.";
                begin
                    CurrPage.SetSelectionFilter(SelectedHeaders);
                    PurchaseOrderMgt.ProcessSelectedHeaders(SelectedHeaders);
                    CurrPage.Update(false);
                end;
            }
            action(OpenBCPurchaseOrder)
            {
                Caption = 'Open BC Purchase Order';
                ApplicationArea = All;
                Image = ViewOrder;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec."BC Document No." <> '';

                trigger OnAction()
                var
                    PurchaseHeader: Record "Purchase Header";
                begin
                    if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."BC Document No.") then
                        Page.Run(Page::"Purchase Order", PurchaseHeader);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec."Processing Status" of
            Rec."Processing Status"::Processed:
                StatusStyle := 'Favorable';
            Rec."Processing Status"::Error:
                StatusStyle := 'Unfavorable';
            Rec."Processing Status"::Processing:
                StatusStyle := 'Ambiguous';
            else
                StatusStyle := 'Standard';
        end;
    end;

    var
        StatusStyle: Text;
}
