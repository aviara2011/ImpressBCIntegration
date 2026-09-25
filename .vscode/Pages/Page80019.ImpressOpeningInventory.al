page 80019 "Impress Opening Inventory"
{
    PageType = List;
    SourceTable = "Impress Opening Inventory";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Impress Opening Inventory Staging';
    Editable = true;
    SourceTableView = sorting("Run ID", "BC Line No.") order(ascending);

    layout
    {
        area(content)
        {
            repeater(Lines)
            {
                field("Run ID"; Rec."Run ID") { ApplicationArea = All; }
                field("BC Line No."; Rec."BC Line No.") { ApplicationArea = All; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; }
                field("Impress Item No."; Rec."Impress Item No.") { ApplicationArea = All; }
                field("Impress Variant Code"; Rec."Impress Variant Code") { ApplicationArea = All; }
                field("Division Code"; Rec."Division Code") { ApplicationArea = All; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field("Variant Code"; Rec."Variant Code") { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("Source BC Line No."; Rec."Source BC Line No.") { ApplicationArea = All; }
                field("Posting Date"; Rec."Posting Date") { ApplicationArea = All; }
                field(Quantity; Rec.Quantity) { ApplicationArea = All; }
                field("Unit Cost"; Rec."Unit Cost") { ApplicationArea = All; }
                field("Inventory Value"; Rec."Inventory Value") { ApplicationArea = All; }
                field("Is FIFO Tracked"; Rec."Is FIFO Tracked") { ApplicationArea = All; }
                field("FIFO Sequence"; Rec."FIFO Sequence") { ApplicationArea = All; }
                field("Send Status"; Rec."Send Status") { ApplicationArea = All; StyleExpr = StatusStyle; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
                field("Journal Template Name"; Rec."Journal Template Name") { ApplicationArea = All; }
                field("Journal Batch Name"; Rec."Journal Batch Name") { ApplicationArea = All; }
                field("Journal Line No."; Rec."Journal Line No.") { ApplicationArea = All; }
                field("BC Journal Line System ID"; Rec."BC Journal Line System ID") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ProcessCurrentRun)
            {
                Caption = 'Process Current Run';
                ApplicationArea = All;
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    OpeningInventoryMgt: Codeunit "Impress Opening Inventory Mgt";
                begin
                    OpeningInventoryMgt.ProcessRun(Rec."Run ID");
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
                    OpeningInventoryMgt: Codeunit "Impress Opening Inventory Mgt";
                begin
                    OpeningInventoryMgt.RetryRunErrors(Rec."Run ID");
                    CurrPage.Update(false);
                end;
            }
            action(ResetSelected)
            {
                Caption = 'Reset to Pending';
                ApplicationArea = All;
                Image = ReOpen;
                trigger OnAction()
                var
                    SelectedLines: Record "Impress Opening Inventory";
                    OpeningInventoryMgt: Codeunit "Impress Opening Inventory Mgt";
                begin
                    CurrPage.SetSelectionFilter(SelectedLines);
                    OpeningInventoryMgt.ResetToPending(SelectedLines);
                    CurrPage.Update(false);
                end;
            }
            action(OpenJournal)
            {
                Caption = 'Open Item Journal';
                ApplicationArea = All;
                Image = Journals;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    ItemJournalLine: Record "Item Journal Line";
                begin
                    ItemJournalLine.SetRange("Journal Template Name", Rec."Journal Template Name");
                    ItemJournalLine.SetRange("Journal Batch Name", Rec."Journal Batch Name");
                    Page.Run(Page::"Item Journal", ItemJournalLine);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec."Send Status" of
            Rec."Send Status"::Processed: StatusStyle := 'Favorable';
            Rec."Send Status"::Error: StatusStyle := 'Unfavorable';
            Rec."Send Status"::Processing: StatusStyle := 'Ambiguous';
            else StatusStyle := 'Standard';
        end;
    end;

    var
        StatusStyle: Text;
}
