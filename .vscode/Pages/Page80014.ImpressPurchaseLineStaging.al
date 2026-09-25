page 80014 "Impress Purch. Line Staging"
{
    PageType = List;
    SourceTable = "Impress Purchase Line Staging";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Impress Purchase Line Staging';
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
                field("Source POrder Detail ID"; Rec."Source POrder Detail ID") { ApplicationArea = All; }
                field("Size Position"; Rec."Size Position") { ApplicationArea = All; }
                field("Purchase Order No."; Rec."Purchase Order No.") { ApplicationArea = All; }
                field("BC Line No."; Rec."BC Line No.") { ApplicationArea = All; }
                field("Source SKU"; Rec."Source SKU") { ApplicationArea = All; }
                field("BC Item No."; Rec."BC Item No.") { ApplicationArea = All; }
                field("BC Variant Code"; Rec."BC Variant Code") { ApplicationArea = All; }
                field("Quantity Ordered"; Rec."Quantity Ordered") { ApplicationArea = All; }
                field("Direct Unit Cost"; Rec."Direct Unit Cost") { ApplicationArea = All; }
                field(Operation; Rec.Operation) { ApplicationArea = All; }
                field("Transport Status"; Rec."Transport Status") { ApplicationArea = All; }
                field("Processing Status"; Rec."Processing Status") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
                field("BC Document No."; Rec."BC Document No.") { ApplicationArea = All; }
                field("BC Line System ID"; Rec."BC Line System ID") { ApplicationArea = All; }
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
                var Selected: Record "Impress Purchase Line Staging"; Mgt: Codeunit "Impress Purchase Order Mgt.";
                begin CurrPage.SetSelectionFilter(Selected); Mgt.ProcessSelectedLines(Selected); CurrPage.Update(false); end;
            }
            action(RetryErrors)
            {
                Caption = 'Retry Errors'; ApplicationArea = All; Image = Refresh; Promoted = true; PromotedCategory = Process;
                trigger OnAction()
                var Selected: Record "Impress Purchase Line Staging"; Mgt: Codeunit "Impress Purchase Order Mgt.";
                begin CurrPage.SetSelectionFilter(Selected); Selected.SetRange("Processing Status", Selected."Processing Status"::Error); Mgt.ResetLinesToPending(Selected); Mgt.ProcessSelectedLines(Selected); CurrPage.Update(false); end;
            }
            action(ResetPending)
            {
                Caption = 'Reset to Pending'; ApplicationArea = All; Image = ReOpen;
                trigger OnAction()
                var Selected: Record "Impress Purchase Line Staging"; Mgt: Codeunit "Impress Purchase Order Mgt.";
                begin CurrPage.SetSelectionFilter(Selected); Mgt.ResetLinesToPending(Selected); CurrPage.Update(false); end;
            }
            action(OpenPurchaseOrder)
            {
                Caption = 'Open Purchase Order'; ApplicationArea = All; Image = ViewOrder;
                trigger OnAction()
                var PurchaseHeader: Record "Purchase Header";
                begin if (Rec."BC Document No." <> '') and PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."BC Document No.") then Page.Run(Page::"Purchase Order", PurchaseHeader); end;
            }
        }
    }
}
