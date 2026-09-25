page 80032 "Impress Sales Document"
{
    PageType = Document;
    SourceTable = "Impress Sales Doc Hdr Staging";
    Caption = 'Impress Sales Document';
    ApplicationArea = All;
    Editable = true;
    DeleteAllowed = true;
    InsertAllowed = false;
    RefreshOnActivate = true;
    DataCaptionFields = "Document Type", "Document No.";

    layout
    {
        area(content)
        {
            group(General)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; }
                field("Source Document Type"; Rec."Source Document Type") { ApplicationArea = All; }
                field("Document Type"; Rec."Document Type") { ApplicationArea = All; }
                field("Document No."; Rec."Document No.") { ApplicationArea = All; }
                field("Source Customer Code"; Rec."Source Customer Code") { ApplicationArea = All; }
                field("Source Sales Order No."; Rec."Source Sales Order No.") { ApplicationArea = All; }
                field("Apply-to Invoice No."; Rec."Apply-to Invoice No.") { ApplicationArea = All; }
                field("Invoice Date"; Rec."Invoice Date") { ApplicationArea = All; }
                field("Due Date"; Rec."Due Date") { ApplicationArea = All; }
                field("G/L Post Date"; Rec."G/L Post Date") { ApplicationArea = All; }
                field("Division Code"; Rec."Division Code") { ApplicationArea = All; }
                field("A/R G/L Account"; Rec."A/R G/L Account") { ApplicationArea = All; }
            }
            part(DocumentLines; "Impress Sales Doc. Subpage")
            {
                ApplicationArea = All;
                SubPageLink = "Sales Document Entry No." = field("Entry No.");
                UpdatePropagation = Both;
            }
            group(Totals)
            {
                field("Invoice Total"; Rec."Invoice Total") { ApplicationArea = All; }
                field("Discount Rate"; Rec."Discount Rate") { ApplicationArea = All; }
                field("Discount Amount"; Rec."Discount Amount") { ApplicationArea = All; }
                field("Discount Adjust"; Rec."Discount Adjust") { ApplicationArea = All; }
                field("Discount Taken"; Rec."Discount Taken") { ApplicationArea = All; }
                field("Source Balance"; Rec."Source Balance") { ApplicationArea = All; }
            }
            group(SalesTax)
            {
                Caption = 'Sales Tax';
                Editable = false;
                field("Tax Area Code"; Rec."Tax Area Code") { ApplicationArea = All; }
                field("Tax Area Description"; Rec."Tax Area Description") { ApplicationArea = All; }
                field("Shipping Is Taxable"; Rec."Shipping Is Taxable") { ApplicationArea = All; }
                field("Tax Rate Total"; Rec."Tax Rate Total") { ApplicationArea = All; }
                field("Tax Total"; Rec."Tax Total") { ApplicationArea = All; }
                group(Jurisdiction1)
                {
                    Caption = 'Jurisdiction 1';
                    field("Tax Jurisdiction Code 1"; Rec."Tax Jurisdiction Code 1") { ApplicationArea = All; }
                    field("Tax Jurisdiction Desc. 1"; Rec."Tax Jurisdiction Desc. 1") { ApplicationArea = All; }
                    field("Taxable Amount 1"; Rec."Taxable Amount 1") { ApplicationArea = All; }
                    field("Tax Rate 1"; Rec."Tax Rate 1") { ApplicationArea = All; }
                    field("Tax G/L Account 1"; Rec."Tax G/L Account 1") { ApplicationArea = All; }
                }
                group(Jurisdiction2)
                {
                    Caption = 'Jurisdiction 2';
                    field("Tax Jurisdiction Code 2"; Rec."Tax Jurisdiction Code 2") { ApplicationArea = All; }
                    field("Tax Jurisdiction Desc. 2"; Rec."Tax Jurisdiction Desc. 2") { ApplicationArea = All; }
                    field("Taxable Amount 2"; Rec."Taxable Amount 2") { ApplicationArea = All; }
                    field("Tax Rate 2"; Rec."Tax Rate 2") { ApplicationArea = All; }
                    field("Tax G/L Account 2"; Rec."Tax G/L Account 2") { ApplicationArea = All; }
                }
                group(Jurisdiction3)
                {
                    Caption = 'Jurisdiction 3';
                    field("Tax Jurisdiction Code 3"; Rec."Tax Jurisdiction Code 3") { ApplicationArea = All; }
                    field("Tax Jurisdiction Desc. 3"; Rec."Tax Jurisdiction Desc. 3") { ApplicationArea = All; }
                    field("Taxable Amount 3"; Rec."Taxable Amount 3") { ApplicationArea = All; }
                    field("Tax Rate 3"; Rec."Tax Rate 3") { ApplicationArea = All; }
                    field("Tax G/L Account 3"; Rec."Tax G/L Account 3") { ApplicationArea = All; }
                }
                group(Jurisdiction4)
                {
                    Caption = 'Jurisdiction 4';
                    field("Tax Jurisdiction Code 4"; Rec."Tax Jurisdiction Code 4") { ApplicationArea = All; }
                    field("Tax Jurisdiction Desc. 4"; Rec."Tax Jurisdiction Desc. 4") { ApplicationArea = All; }
                    field("Taxable Amount 4"; Rec."Taxable Amount 4") { ApplicationArea = All; }
                    field("Tax Rate 4"; Rec."Tax Rate 4") { ApplicationArea = All; }
                    field("Tax G/L Account 4"; Rec."Tax G/L Account 4") { ApplicationArea = All; }
                }
            }
            group(ProcessingDetails)
            {
                Caption = 'Processing';
                field("Integration Posting ID"; Rec."Integration Posting ID") { ApplicationArea = All; }
                field("BC Sales Order No."; Rec."BC Sales Order No.") { ApplicationArea = All; }
                field("Has Inventory Impact"; Rec."Has Inventory Impact") { ApplicationArea = All; }
                field("First Inventory Transaction ID"; Rec."First Inventory Transaction ID") { ApplicationArea = All; }
                field("Last Inventory Transaction ID"; Rec."Last Inventory Transaction ID") { ApplicationArea = All; }
                field("Inventory Transaction Count"; Rec."Inventory Transaction Count") { ApplicationArea = All; }
                field("Processing Phase"; Rec."Processing Phase") { ApplicationArea = All; }
                field("Processing Status"; Rec."Processing Status") { ApplicationArea = All; }
                field("Transport Status"; Rec."Transport Status") { ApplicationArea = All; }
                field("BC Document No."; Rec."BC Document No.") { ApplicationArea = All; }
                field("BC System ID"; Rec."BC System ID") { ApplicationArea = All; }
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
                    CurrPage.SaveRecord();
                    Processor.ProcessSalesDocument(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(RetryError)
            {
                ApplicationArea = All;
                Caption = 'Retry Error';
                Image = Refresh;
                trigger OnAction()
                begin
                    CurrPage.SaveRecord();
                    Processor.RetrySalesDocument(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ResetToPending)
            {
                ApplicationArea = All;
                Caption = 'Reset to Pending';
                Image = ResetStatus;
                trigger OnAction()
                begin
                    CurrPage.SaveRecord();
                    Processor.ResetSalesDocument(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        Processor: Codeunit "Impress Trans. Posting Engine";
}

