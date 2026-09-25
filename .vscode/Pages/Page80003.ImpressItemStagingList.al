page 80003 "Impress Item Staging"
{
    PageType = List;
    SourceTable = "Impress Item Staging";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Impress Item Staging';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; }
                field("Source System ID"; Rec."Source System ID") { ApplicationArea = All; }
                field("Source SKU Item No."; Rec."Source SKU Item No.") { ApplicationArea = All; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field("Style Code"; Rec."Style Code") { ApplicationArea = All; }
                field("Color Code"; Rec."Color Code") { ApplicationArea = All; }
                field("Size Code"; Rec."Size Code") { ApplicationArea = All; }
                field("Variant Code"; Rec."Variant Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Purchase Description"; Rec."Purchase Description") { ApplicationArea = All; }
                field("SKU Status"; Rec."SKU Status") { ApplicationArea = All; }
                field("Unit of Measure"; Rec."Unit of Measure") { ApplicationArea = All; }
                field("Item Category Code"; Rec."Item Category Code") { ApplicationArea = All; }
                field("Preferred Vendor No."; Rec."Preferred Vendor No.") { ApplicationArea = All; }
                field("Source Created DateTime"; Rec."Source Created DateTime") { ApplicationArea = All; }
                field("Source Modified DateTime"; Rec."Source Modified DateTime") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
                field("SQL Entry No."; Rec."SQL Entry No.") { ApplicationArea = All; }
                field("Received DateTime"; Rec."Received DateTime") { ApplicationArea = All; }
                field("Processed DateTime"; Rec."Processed DateTime") { ApplicationArea = All; }
                field("SQL Run ID"; Rec."SQL Run ID") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ProcessItems)
            {
                ApplicationArea = All;
                Caption = 'Process Item(s)';
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Create or update Items for the selected Impress item staging records.';

                trigger OnAction()
                var
                    ImpressItemStaging: Record "Impress Item Staging";
                    ImpressItemProcessingRunner: Codeunit "Impress Item Processing Runner";
                begin
                    CurrPage.SetSelectionFilter(ImpressItemStaging);
                    ImpressItemProcessingRunner.ProcessItems(ImpressItemStaging);
                    CurrPage.Update(false);
                end;
            }
            action(ReprocessErrors)
            {
                ApplicationArea = All;
                Caption = 'Reprocess Errors';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Retry processing for the selected Impress item staging records that are in Error status.';

                trigger OnAction()
                var
                    ImpressItemStaging: Record "Impress Item Staging";
                    ImpressItemProcessingRunner: Codeunit "Impress Item Processing Runner";
                begin
                    CurrPage.SetSelectionFilter(ImpressItemStaging);
                    ImpressItemProcessingRunner.ProcessErrorItems(ImpressItemStaging);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Reporting)
        {
            action(ItemReconciliation)
            {
                ApplicationArea = All;
                Caption = 'Item Reconciliation';
                Image = Reconcile;
                ToolTip = 'Open the item reconciliation report for the current SQL Run ID.';

                trigger OnAction()
                var
                    ImpressItemReconciliation: Report "Impress Item Reconciliation";
                begin
                    ImpressItemReconciliation.SetSQLRunIDFilter(Format(Rec."SQL Run ID"));
                    ImpressItemReconciliation.RunModal();
                end;
            }
        }
    }
}
