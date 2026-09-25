page 80023 "Impress Sales Order"
{
    PageType = Document;
    SourceTable = "Impress Sales Header Staging";
    ApplicationArea = All;
    Caption = 'Impress Staging Sales Order';
    Editable = true;
    RefreshOnActivate = true;

    layout
    {
        area(content)
        {
            group(General)
            {
                field("Sales Order No."; Rec."Sales Order No.") { ApplicationArea = All; Importance = Promoted; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; Importance = Promoted; }
                field("Source Sales Order ID"; Rec."Source Sales Order ID") { ApplicationArea = All; }
                field("Customer No."; Rec."Customer No.") { ApplicationArea = All; Importance = Promoted; }
                field("Customer Name"; Rec."Customer Name") { ApplicationArea = All; Importance = Promoted; }
                field("Customer PO No."; Rec."Customer PO No.") { ApplicationArea = All; }
                field("End Customer PO No."; Rec."End Customer PO No.") { ApplicationArea = All; }
                field("Order Date"; Rec."Order Date") { ApplicationArea = All; }
                field("Requested Shipment Date"; Rec."Requested Shipment Date") { ApplicationArea = All; Importance = Promoted; }
                field("Due Date"; Rec."Due Date") { ApplicationArea = All; }
                field("BC Location Code"; Rec."BC Location Code") { ApplicationArea = All; }
                field("Payment Terms Code"; Rec."Payment Terms Code") { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field("On Hold"; Rec."On Hold") { ApplicationArea = All; }
                field("Billing Hold"; Rec."Billing Hold") { ApplicationArea = All; }
            }
            group(Billing)
            {
                Caption = 'Bill-to';
                field("Source Bill-to Code"; Rec."Source Bill-to Code") { ApplicationArea = All; }
                field("Bill-to Name"; Rec."Bill-to Name") { ApplicationArea = All; }
                field("Bill-to Address"; Rec."Bill-to Address") { ApplicationArea = All; }
                field("Bill-to Address 2"; Rec."Bill-to Address 2") { ApplicationArea = All; }
                field("Bill-to Address 3"; Rec."Bill-to Address 3") { ApplicationArea = All; }
                field("Bill-to City"; Rec."Bill-to City") { ApplicationArea = All; }
                field("Bill-to State"; Rec."Bill-to State") { ApplicationArea = All; }
                field("Bill-to Post Code"; Rec."Bill-to Post Code") { ApplicationArea = All; }
            }
            part(Lines; "Impress Sales Order Lines")
            {
                ApplicationArea = All;
                SubPageLink = "Source Database" = field("Source Database"),
                              "Source Sales Order ID" = field("Source Sales Order ID");
                UpdatePropagation = Both;
            }
            group(Shipping)
            {
                field("Source Ship-to Code"; Rec."Source Ship-to Code") { ApplicationArea = All; }
                field("Source Warehouse Code"; Rec."Source Warehouse Code") { ApplicationArea = All; }
                field("Ship Via Code"; Rec."Ship Via Code") { ApplicationArea = All; }
                field("Ship-to Name"; Rec."Ship-to Name") { ApplicationArea = All; }
                field("Ship-to Address"; Rec."Ship-to Address") { ApplicationArea = All; }
                field("Ship-to Address 2"; Rec."Ship-to Address 2") { ApplicationArea = All; }
                field("Ship-to Address 3"; Rec."Ship-to Address 3") { ApplicationArea = All; }
                field("Ship-to City"; Rec."Ship-to City") { ApplicationArea = All; }
                field("Ship-to State"; Rec."Ship-to State") { ApplicationArea = All; }
                field("Ship-to Post Code"; Rec."Ship-to Post Code") { ApplicationArea = All; }
                field("Ship-to Country Code"; Rec."Ship-to Country Code") { ApplicationArea = All; }
            }
            group(Totals)
            {
                field("Product Quantity"; Rec."Product Quantity") { ApplicationArea = All; }
                field("Product Total"; Rec."Product Total") { ApplicationArea = All; }
                field("Miscellaneous Quantity"; Rec."Miscellaneous Quantity") { ApplicationArea = All; }
                field("Miscellaneous Total"; Rec."Miscellaneous Total") { ApplicationArea = All; }
                field("Shipping Amount"; Rec."Shipping Amount") { ApplicationArea = All; }
                field("Discount Amount"; Rec."Discount Amount") { ApplicationArea = All; }
                field("Sales Order Total"; Rec."Sales Order Total") { ApplicationArea = All; Importance = Promoted; }
            }
            group(SalesTax)
            {
                Caption = 'Sales Tax';
                field("Tax Area Code"; Rec."Tax Area Code") { ApplicationArea = All; }
                field("Tax Area Description"; Rec."Tax Area Description") { ApplicationArea = All; }
                field("Shipping Is Taxable"; Rec."Shipping Is Taxable") { ApplicationArea = All; }
                field("Tax Rate Total"; Rec."Tax Rate Total") { ApplicationArea = All; }
                group(Jurisdiction1)
                {
                    Caption = 'Jurisdiction 1';
                    field("Tax Jurisdiction Code 1"; Rec."Tax Jurisdiction Code 1") { ApplicationArea = All; }
                    field("Tax Jurisdiction Desc. 1"; Rec."Tax Jurisdiction Desc. 1") { ApplicationArea = All; }
                    field("Tax Jurisdiction Rate 1"; Rec."Tax Jurisdiction Rate 1") { ApplicationArea = All; }
                    field("Tax Jurisdiction G/L Acc. 1"; Rec."Tax Jurisdiction G/L Acc. 1") { ApplicationArea = All; }
                }
                group(Jurisdiction2)
                {
                    Caption = 'Jurisdiction 2';
                    field("Tax Jurisdiction Code 2"; Rec."Tax Jurisdiction Code 2") { ApplicationArea = All; }
                    field("Tax Jurisdiction Desc. 2"; Rec."Tax Jurisdiction Desc. 2") { ApplicationArea = All; }
                    field("Tax Jurisdiction Rate 2"; Rec."Tax Jurisdiction Rate 2") { ApplicationArea = All; }
                    field("Tax Jurisdiction G/L Acc. 2"; Rec."Tax Jurisdiction G/L Acc. 2") { ApplicationArea = All; }
                }
                group(Jurisdiction3)
                {
                    Caption = 'Jurisdiction 3';
                    field("Tax Jurisdiction Code 3"; Rec."Tax Jurisdiction Code 3") { ApplicationArea = All; }
                    field("Tax Jurisdiction Desc. 3"; Rec."Tax Jurisdiction Desc. 3") { ApplicationArea = All; }
                    field("Tax Jurisdiction Rate 3"; Rec."Tax Jurisdiction Rate 3") { ApplicationArea = All; }
                    field("Tax Jurisdiction G/L Acc. 3"; Rec."Tax Jurisdiction G/L Acc. 3") { ApplicationArea = All; }
                }
                group(Jurisdiction4)
                {
                    Caption = 'Jurisdiction 4';
                    field("Tax Jurisdiction Code 4"; Rec."Tax Jurisdiction Code 4") { ApplicationArea = All; }
                    field("Tax Jurisdiction Desc. 4"; Rec."Tax Jurisdiction Desc. 4") { ApplicationArea = All; }
                    field("Tax Jurisdiction Rate 4"; Rec."Tax Jurisdiction Rate 4") { ApplicationArea = All; }
                    field("Tax Jurisdiction G/L Acc. 4"; Rec."Tax Jurisdiction G/L Acc. 4") { ApplicationArea = All; }
                }
            }
            group(Integration)
            {
                field("SQL Run ID"; Rec."SQL Run ID") { ApplicationArea = All; }
                field(Operation; Rec.Operation) { ApplicationArea = All; }
                field("Transport Status"; Rec."Transport Status") { ApplicationArea = All; }
                field("Processing Status"; Rec."Processing Status") { ApplicationArea = All; StyleExpr = StatusStyle; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; MultiLine = true; }
                field("BC Document No."; Rec."BC Document No.") { ApplicationArea = All; }
                field("BC System ID"; Rec."BC System ID") { ApplicationArea = All; }
                field("Processed Date Time"; Rec."Processed Date Time") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ProcessOrder)
            {
                Caption = 'Process Order'; ApplicationArea = All; Image = Process; Promoted = true; PromotedCategory = Process;
                trigger OnAction()
                var
                    HeaderStaging: Record "Impress Sales Header Staging";
                    SalesOrderMgt: Codeunit "Impress Sales Order Mgt.";
                begin
                    CurrPage.SaveRecord();
                    HeaderStaging := Rec;
                    SalesOrderMgt.ProcessHeader(HeaderStaging);
                    Rec.Get(Rec."Entry No.");
                    CurrPage.Update(false);
                end;
            }
            action(RetryError)
            {
                Caption = 'Retry Error'; ApplicationArea = All; Image = Refresh; Promoted = true; PromotedCategory = Process;
                Enabled = Rec."Processing Status" = Rec."Processing Status"::Error;
                trigger OnAction()
                var
                    HeaderStaging: Record "Impress Sales Header Staging";
                    SalesOrderMgt: Codeunit "Impress Sales Order Mgt.";
                begin
                    CurrPage.SaveRecord();
                    HeaderStaging := Rec;
                    SalesOrderMgt.RetryHeaderErrors(HeaderStaging);
                    Rec.Get(Rec."Entry No.");
                    CurrPage.Update(false);
                end;
            }
            action(ResetPending)
            {
                Caption = 'Reset to Pending'; ApplicationArea = All; Image = ReOpen;
                trigger OnAction()
                var
                    HeaderStaging: Record "Impress Sales Header Staging";
                    SalesOrderMgt: Codeunit "Impress Sales Order Mgt.";
                begin
                    CurrPage.SaveRecord();
                    HeaderStaging := Rec;
                    SalesOrderMgt.ResetDocumentToPending(HeaderStaging);
                    Rec.Get(Rec."Entry No.");
                    CurrPage.Update(false);
                end;
            }
            action(OpenBCSalesOrder)
            {
                Caption = 'Open BC Sales Order'; ApplicationArea = All; Image = ViewOrder; Promoted = true; PromotedCategory = Process;
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
