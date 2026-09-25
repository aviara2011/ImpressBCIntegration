page 80010 "Impress G/L Account Staging"
{
    PageType = List;
    SourceTable = "Impress G/L Account Staging";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Impress G/L Account Staging';
    Editable = true;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("SQL Run ID"; Rec."SQL Run ID") { ApplicationArea = All; }
                field("SQL Entry No."; Rec."SQL Entry No.") { ApplicationArea = All; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; }
                field("G/L Account No."; Rec."G/L Account No.") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Long Description"; Rec."Long Description") { ApplicationArea = All; }
                field("Account Type Code"; Rec."Account Type Code") { ApplicationArea = All; }
                field(Inactive; Rec.Inactive) { ApplicationArea = All; }
                field("Debit Account No."; Rec."Debit Account No.") { ApplicationArea = All; }
                field("Credit Account No."; Rec."Credit Account No.") { ApplicationArea = All; }
                field("Cost of Sales Account No."; Rec."Cost of Sales Account No.") { ApplicationArea = All; }
                field("Cost of Sales Credit Acct. No."; Rec."Cost of Sales Credit Acct. No.") { ApplicationArea = All; }
                field("Factor Fee Account No."; Rec."Factor Fee Account No.") { ApplicationArea = All; }
                field("Factor Reserve Account No."; Rec."Factor Reserve Account No.") { ApplicationArea = All; }
                field(Operation; Rec.Operation) { ApplicationArea = All; }
                field("Transport Status"; Rec."Transport Status") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
                field("BC System ID"; Rec."BC System ID") { ApplicationArea = All; }
                field("Extracted DateTime"; Rec."Extracted DateTime") { ApplicationArea = All; }
                field("Sent to BC DateTime"; Rec."Sent to BC DateTime") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ProcessGLAccounts)
            {
                ApplicationArea = All;
                Caption = 'Process G/L Account(s)';
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Create or update G/L accounts for the selected Impress G/L account staging records.';

                trigger OnAction()
                var
                    ImpressGLAccountStaging: Record "Impress G/L Account Staging";
                    ImpressGLAccountProcessingRunner: Codeunit "Impress GL Processing Runner";
                begin
                    CurrPage.SetSelectionFilter(ImpressGLAccountStaging);
                    ImpressGLAccountProcessingRunner.ProcessGLAccounts(ImpressGLAccountStaging);
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
                ToolTip = 'Retry selected Impress G/L account staging records that are in Error status.';

                trigger OnAction()
                var
                    ImpressGLAccountStaging: Record "Impress G/L Account Staging";
                    ImpressGLAccountProcessingRunner: Codeunit "Impress GL Processing Runner";
                begin
                    CurrPage.SetSelectionFilter(ImpressGLAccountStaging);
                    ImpressGLAccountProcessingRunner.ProcessErrorGLAccounts(ImpressGLAccountStaging);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
