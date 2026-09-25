page 80016 "Impress Purchase Order"
{
    PageType = Document;
    SourceTable = "Impress Purch Header Staging";
    ApplicationArea = All;
    Caption = 'Impress Staging Purchase Order';
    Editable = false;
    RefreshOnActivate = true;

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';
                field("Purchase Order No."; Rec."Purchase Order No.") { ApplicationArea = All; Importance = Promoted; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; Importance = Promoted; }
                field("Source POrder ID"; Rec."Source POrder ID") { ApplicationArea = All; }
                field("Vendor No."; Rec."Vendor No.") { ApplicationArea = All; Importance = Promoted; }
                field("Order Date"; Rec."Order Date") { ApplicationArea = All; }
                field("Shipment Date"; Rec."Shipment Date") { ApplicationArea = All; }
                field("First Expected Receipt Date"; Rec."First Expected Receipt Date") { ApplicationArea = All; }
                field("Last Expected Receipt Date"; Rec."Last Expected Receipt Date") { ApplicationArea = All; Importance = Promoted; }
                field("BC Location Code"; Rec."BC Location Code") { ApplicationArea = All; }
                field("Payment Terms Code"; Rec."Payment Terms Code") { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field("On Hold"; Rec."On Hold") { ApplicationArea = All; }
            }
            part(Lines; "Impress Purchase Order Lines")
            {
                ApplicationArea = All;
                SubPageLink = "Source Database" = field("Source Database"),
                              "Source POrder ID" = field("Source POrder ID");
                UpdatePropagation = Both;
            }
            group(Shipping)
            {
                Caption = 'Shipping and Receiving';
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
                Caption = 'Totals';
                field("Total Quantity Ordered"; Rec."Total Quantity Ordered") { ApplicationArea = All; }
                field("Total Quantity Received"; Rec."Total Quantity Received") { ApplicationArea = All; }
                field("Total Quantity Remaining"; Rec."Total Quantity Remaining") { ApplicationArea = All; }
                field("Product Total"; Rec."Product Total") { ApplicationArea = All; }
                field("Miscellaneous Total"; Rec."Miscellaneous Total") { ApplicationArea = All; }
                field("Shipping Amount"; Rec."Shipping Amount") { ApplicationArea = All; }
                field("Discount Amount"; Rec."Discount Amount") { ApplicationArea = All; }
                field("Purchase Order Total"; Rec."Purchase Order Total") { ApplicationArea = All; Importance = Promoted; }
            }
            group(Integration)
            {
                Caption = 'Integration';
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
                Caption = 'Process Order';
                ApplicationArea = All;
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    HeaderStaging: Record "Impress Purch Header Staging";
                    PurchaseOrderMgt: Codeunit "Impress Purchase Order Mgt.";
                begin
                    HeaderStaging := Rec;
                    PurchaseOrderMgt.ProcessHeader(HeaderStaging);
                    Rec.Get(Rec."Entry No.");
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
