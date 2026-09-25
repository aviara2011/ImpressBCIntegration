page 80030 "Impress Sales Documents"
{
    PageType = List;
    CardPageId = "Impress Sales Document";
    SourceTable = "Impress Sales Doc Hdr Staging";
    Caption = 'Impress Sales Documents';
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = true;
    DeleteAllowed = true;

    layout
    {
        area(content)
        {
            repeater(Documents)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; }
                field("Document Type"; Rec."Document Type") { ApplicationArea = All; }
                field("Document No."; Rec."Document No.") { ApplicationArea = All; }
                field("Source Customer Code"; Rec."Source Customer Code") { ApplicationArea = All; }
                field("Source Sales Order No."; Rec."Source Sales Order No.") { ApplicationArea = All; }
                field("Apply-to Invoice No."; Rec."Apply-to Invoice No.") { ApplicationArea = All; }
                field("Invoice Date"; Rec."Invoice Date") { ApplicationArea = All; }
                field("G/L Post Date"; Rec."G/L Post Date") { ApplicationArea = All; }
                field("Division Code"; Rec."Division Code") { ApplicationArea = All; }
                field("A/R G/L Account"; Rec."A/R G/L Account") { ApplicationArea = All; }
                field("Invoice Total"; Rec."Invoice Total") { ApplicationArea = All; }
                field("Tax Total"; Rec."Tax Total") { ApplicationArea = All; }
                field("Has Inventory Impact"; Rec."Has Inventory Impact") { ApplicationArea = All; }
                field("First Inventory Transaction ID"; Rec."First Inventory Transaction ID") { ApplicationArea = All; }
                field("Last Inventory Transaction ID"; Rec."Last Inventory Transaction ID") { ApplicationArea = All; }
                field("Inventory Transaction Count"; Rec."Inventory Transaction Count") { ApplicationArea = All; }
                field("Processing Phase"; Rec."Processing Phase") { ApplicationArea = All; }
                field("Processing Status"; Rec."Processing Status") { ApplicationArea = All; }
                field("Transport Status"; Rec."Transport Status") { ApplicationArea = All; }
                field("BC Document No."; Rec."BC Document No.") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
                field("Date Staged"; Rec."Date Staged") { ApplicationArea = All; }
                field("Date Processing Started"; Rec."Date Processing Started") { ApplicationArea = All; }
                field("Date Processed"; Rec."Date Processed") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(OpenDocument)
            {
                ApplicationArea = All;
                Caption = 'Open Document';
                Image = Document;
                RunObject = page "Impress Sales Document";
                RunPageLink = "Entry No." = field("Entry No.");
            }
            action(Lines)
            {
                ApplicationArea = All;
                Caption = 'Lines';
                Image = Line;
                trigger OnAction()
                var
                    SalesLine: Record "Impress Sales Doc Line Staging";
                begin
                    SalesLine.SetRange("Sales Document Entry No.", Rec."Entry No.");
                    Page.Run(Page::"Impress Sales Document Lines", SalesLine);
                end;
            }
        }
        area(Processing)
        {
            action(Process)
            {
                ApplicationArea = All;
                Caption = 'Process';
                Image = Process;
                trigger OnAction()
                begin
                    Processor.ProcessSalesDocument(Rec);
                end;
            }
            action(RetryError)
            {
                ApplicationArea = All;
                Caption = 'Retry Error';
                Image = Refresh;
                trigger OnAction()
                begin
                    Processor.RetrySalesDocument(Rec);
                end;
            }
            action(ResetToPending)
            {
                ApplicationArea = All;
                Caption = 'Reset to Pending';
                Image = ResetStatus;
                trigger OnAction()
                begin
                    Processor.ResetSalesDocument(Rec);
                end;
            }
        }
    }

    var
        Processor: Codeunit "Impress Trans. Posting Engine";
}
