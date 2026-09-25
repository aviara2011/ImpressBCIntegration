page 80024 "Impress Sales Order Lines"
{
    PageType = ListPart;
    SourceTable = "Impress Sales Line Staging";
    ApplicationArea = All;
    Caption = 'Lines';
    Editable = true;

    layout
    {
        area(content)
        {
            repeater(Lines)
            {
                field("Source Line No."; Rec."Source Line No.") { ApplicationArea = All; }
                field("Source Sales Order Detail ID"; Rec."Source Sales Order Detail ID") { ApplicationArea = All; }
                field("Size Position"; Rec."Size Position") { ApplicationArea = All; }
                field("BC Line Type"; Rec."BC Line Type") { ApplicationArea = All; }
                field("Source Code"; Rec."Source Code") { ApplicationArea = All; }
                field("BC Item No."; Rec."BC Item No.") { ApplicationArea = All; }
                field("BC Variant Code"; Rec."BC Variant Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Unit of Measure Code"; Rec."Unit of Measure Code") { ApplicationArea = All; }
                field(Quantity; Rec.Quantity) { ApplicationArea = All; }
                field("Quantity Shipped"; Rec."Quantity Shipped") { ApplicationArea = All; }
                field("Quantity Invoiced"; Rec."Quantity Invoiced") { ApplicationArea = All; }
                field("Unit Price"; Rec."Unit Price") { ApplicationArea = All; }
                field("Line Amount"; Rec."Line Amount") { ApplicationArea = All; }
                field("Requested Date"; Rec."Requested Date") { ApplicationArea = All; }
                field("Tax Group Code"; Rec."Tax Group Code") { ApplicationArea = All; }
                field("Tax Group Description"; Rec."Tax Group Description") { ApplicationArea = All; }
                field(Operation; Rec.Operation) { ApplicationArea = All; }
                field("Processing Status"; Rec."Processing Status") { ApplicationArea = All; StyleExpr = StatusStyle; }
                field("BC Line No."; Rec."BC Line No.") { ApplicationArea = All; }
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
                Caption = 'Process Selected'; ApplicationArea = All; Image = Process;
                trigger OnAction()
                var
                    SelectedLines: Record "Impress Sales Line Staging";
                    SalesOrderMgt: Codeunit "Impress Sales Order Mgt.";
                begin
                    CurrPage.SaveRecord();
                    CurrPage.SetSelectionFilter(SelectedLines);
                    SalesOrderMgt.ProcessSelectedLines(SelectedLines);
                    CurrPage.Update(false);
                end;
            }
            action(RetryErrors)
            {
                Caption = 'Retry Errors'; ApplicationArea = All; Image = Refresh;
                trigger OnAction()
                var
                    SelectedLines: Record "Impress Sales Line Staging";
                    SalesOrderMgt: Codeunit "Impress Sales Order Mgt.";
                begin
                    CurrPage.SaveRecord();
                    CurrPage.SetSelectionFilter(SelectedLines);
                    SelectedLines.SetRange("Processing Status", SelectedLines."Processing Status"::Error);
                    SalesOrderMgt.ResetLinesToPending(SelectedLines);
                    SalesOrderMgt.ProcessSelectedLines(SelectedLines);
                    CurrPage.Update(false);
                end;
            }
            action(ResetPending)
            {
                Caption = 'Reset to Pending'; ApplicationArea = All; Image = ReOpen;
                trigger OnAction()
                var
                    SelectedLines: Record "Impress Sales Line Staging";
                    SalesOrderMgt: Codeunit "Impress Sales Order Mgt.";
                begin
                    CurrPage.SaveRecord();
                    CurrPage.SetSelectionFilter(SelectedLines);
                    SalesOrderMgt.ResetLinesToPending(SelectedLines);
                    CurrPage.Update(false);
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
