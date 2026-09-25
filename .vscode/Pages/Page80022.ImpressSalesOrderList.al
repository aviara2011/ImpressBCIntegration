page 80022 "Impress Sales Orders"
{
    PageType = List;
    SourceTable = "Impress Sales Header Staging";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Impress Staging Sales Orders';
    CardPageId = "Impress Sales Order";
    Editable = true;

    layout
    {
        area(content)
        {
            repeater(SalesOrders)
            {
                field("Sales Order No."; Rec."Sales Order No.") { ApplicationArea = All; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; }
                field("Source Sales Order ID"; Rec."Source Sales Order ID") { ApplicationArea = All; }
                field("Customer No."; Rec."Customer No.") { ApplicationArea = All; }
                field("Customer Name"; Rec."Customer Name") { ApplicationArea = All; }
                field("Customer PO No."; Rec."Customer PO No.") { ApplicationArea = All; }
                field("Order Date"; Rec."Order Date") { ApplicationArea = All; }
                field("Requested Shipment Date"; Rec."Requested Shipment Date") { ApplicationArea = All; }
                field("BC Location Code"; Rec."BC Location Code") { ApplicationArea = All; }
                field("Tax Area Code"; Rec."Tax Area Code") { ApplicationArea = All; }
                field("Tax Rate Total"; Rec."Tax Rate Total") { ApplicationArea = All; }
                field("Product Quantity"; Rec."Product Quantity") { ApplicationArea = All; }
                field("Sales Order Total"; Rec."Sales Order Total") { ApplicationArea = All; }
                field(Operation; Rec.Operation) { ApplicationArea = All; }
                field("Transport Status"; Rec."Transport Status") { ApplicationArea = All; }
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
                    SelectedHeaders: Record "Impress Sales Header Staging";
                    SalesOrderMgt: Codeunit "Impress Sales Order Mgt.";
                begin
                    CurrPage.SaveRecord();
                    CurrPage.SetSelectionFilter(SelectedHeaders);
                    SalesOrderMgt.ProcessSelectedHeaders(SelectedHeaders);
                    CurrPage.Update(false);
                end;
            }
            action(RetryErrors)
            {
                Caption = 'Retry Errors';
                ApplicationArea = All;
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    SelectedHeaders: Record "Impress Sales Header Staging";
                    SalesOrderMgt: Codeunit "Impress Sales Order Mgt.";
                begin
                    CurrPage.SaveRecord();
                    CurrPage.SetSelectionFilter(SelectedHeaders);
                    SalesOrderMgt.RetryHeaderErrors(SelectedHeaders);
                    CurrPage.Update(false);
                end;
            }
            action(ResetPending)
            {
                Caption = 'Reset to Pending';
                ApplicationArea = All;
                Image = ReOpen;
                trigger OnAction()
                var
                    SelectedHeaders: Record "Impress Sales Header Staging";
                    SalesOrderMgt: Codeunit "Impress Sales Order Mgt.";
                begin
                    CurrPage.SaveRecord();
                    CurrPage.SetSelectionFilter(SelectedHeaders);
                    if SelectedHeaders.FindSet() then
                        repeat
                            SalesOrderMgt.ResetDocumentToPending(SelectedHeaders);
                        until SelectedHeaders.Next() = 0;
                    CurrPage.Update(false);
                end;
            }
            action(OpenBCSalesOrder)
            {
                Caption = 'Open BC Sales Order';
                ApplicationArea = All;
                Image = ViewOrder;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec."BC Document No." <> '';
                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if SalesHeader.Get(SalesHeader."Document Type"::Order, Rec."BC Document No.") then
                        Page.Run(Page::"Sales Order", SalesHeader);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec."Processing Status" of
            Rec."Processing Status"::Processed: StatusStyle := 'Favorable';
            Rec."Processing Status"::Error: StatusStyle := 'Unfavorable';
            Rec."Processing Status"::Processing: StatusStyle := 'Ambiguous';
            else StatusStyle := 'Standard';
        end;
    end;

    var
        StatusStyle: Text;
}
