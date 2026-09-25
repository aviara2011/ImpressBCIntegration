page 80013 "Impress Purch. Header Staging"
{
    PageType = List;
    SourceTable = "Impress Purch Header Staging";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Impress Purchase Header Staging';
    Editable = true;
    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("SQL Run ID"; Rec."SQL Run ID") { ApplicationArea = All; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; }
                field("Source POrder ID"; Rec."Source POrder ID") { ApplicationArea = All; }
                field("Purchase Order No."; Rec."Purchase Order No.") { ApplicationArea = All; }
                field("Vendor No."; Rec."Vendor No.") { ApplicationArea = All; }
                field("Order Date"; Rec."Order Date") { ApplicationArea = All; }
                field("Expected Receipt Date"; Rec."Last Expected Receipt Date") { ApplicationArea = All; }
                field("BC Location Code"; Rec."BC Location Code") { ApplicationArea = All; }
                field(Operation; Rec.Operation) { ApplicationArea = All; }
                field("Transport Status"; Rec."Transport Status") { ApplicationArea = All; }
                field("Processing Status"; Rec."Processing Status") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
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
            action(ProcessSelected)
            {
                Caption = 'Process Selected'; ApplicationArea = All; Image = Process; Promoted = true; PromotedCategory = Process;
                trigger OnAction()
                var Selected: Record "Impress Purch Header Staging"; Mgt: Codeunit "Impress Purchase Order Mgt.";
                begin CurrPage.SetSelectionFilter(Selected); Mgt.ProcessSelectedHeaders(Selected); CurrPage.Update(false); end;
            }
            action(ProcessRun)
            {
                Caption = 'Process Current Run'; ApplicationArea = All; Image = Process; Promoted = true; PromotedCategory = Process;
                trigger OnAction()
                var Mgt: Codeunit "Impress Purchase Order Mgt.";
                begin Mgt.ProcessRun(Rec."SQL Run ID"); CurrPage.Update(false); end;
            }
            action(RetryErrors)
            {
                Caption = 'Retry Errors'; ApplicationArea = All; Image = Refresh; Promoted = true; PromotedCategory = Process;
                trigger OnAction()
                var Selected: Record "Impress Purch Header Staging"; Mgt: Codeunit "Impress Purchase Order Mgt.";
                begin CurrPage.SetSelectionFilter(Selected); Mgt.RetryHeaderErrors(Selected); CurrPage.Update(false); end;
            }
            action(ResetPending)
            {
                Caption = 'Reset to Pending'; ApplicationArea = All; Image = ReOpen;
                trigger OnAction()
                var Selected: Record "Impress Purch Header Staging"; Mgt: Codeunit "Impress Purchase Order Mgt.";
                begin CurrPage.SetSelectionFilter(Selected); if Selected.FindSet() then repeat Mgt.ResetDocumentToPending(Selected); until Selected.Next() = 0; CurrPage.Update(false); end;
            }
            action(OpenPurchaseOrder)
            {
                Caption = 'Open Purchase Order'; ApplicationArea = All; Image = ViewOrder;
                trigger OnAction()
                var PurchaseHeader: Record "Purchase Header";
                begin if (Rec."BC Document No." <> '') and PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."BC Document No.") then Page.Run(Page::"Purchase Order", PurchaseHeader); end;
            }
            action(RelatedLines)
            {
                Caption = 'Show Purchase Lines'; ApplicationArea = All; Image = Line;
                trigger OnAction()
                var Lines: Record "Impress Purchase Line Staging";
                begin Lines.SetRange("Source Database", Rec."Source Database"); Lines.SetRange("Source POrder ID", Rec."Source POrder ID"); Page.Run(Page::"Impress Purch. Line Staging", Lines); end;
            }
        }
    }
}
