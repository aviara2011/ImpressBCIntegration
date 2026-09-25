page 80006 "Impress Customer Staging List"
{
    PageType = List;
    SourceTable = "Impress Customer Staging";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Impress Customer Staging';
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
                field("Customer No."; Rec."Customer No.") { ApplicationArea = All; }
                field(Name; Rec.Name) { ApplicationArea = All; }
                field(City; Rec.City) { ApplicationArea = All; }
                field(State; Rec.State) { ApplicationArea = All; }
                field("Post Code"; Rec."Post Code") { ApplicationArea = All; }
                field("Country Code"; Rec."Country Code") { ApplicationArea = All; }
                field("Phone No."; Rec."Phone No.") { ApplicationArea = All; }
                field(Email; Rec.Email) { ApplicationArea = All; }
                field("Payment Terms Code"; Rec."Payment Terms Code") { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field("Credit Limit"; Rec."Credit Limit") { ApplicationArea = All; }
                field("Salesperson Code"; Rec."Salesperson Code") { ApplicationArea = All; }
                field("Customer Status"; Rec."Customer Status") { ApplicationArea = All; }
                field("Customer Hold"; Rec."Customer Hold") { ApplicationArea = All; }
                field(Operation; Rec.Operation) { ApplicationArea = All; }
                field("Transport Status"; Rec."Transport Status") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
                field("Received DateTime"; Rec."Received DateTime") { ApplicationArea = All; }
                field("Processed DateTime"; Rec."Processed DateTime") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ProcessCustomers)
            {
                ApplicationArea = All;
                Caption = 'Process Customer(s)';
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Create or update Customers for the selected Impress customer staging records.';

                trigger OnAction()
                var
                    ImpressCustomerStaging: Record "Impress Customer Staging";
                    ImpressCustomerProcessingRunner: Codeunit "Impress Cust Processing Runner";
                begin
                    CurrPage.SetSelectionFilter(ImpressCustomerStaging);
                    ImpressCustomerProcessingRunner.ProcessCustomers(ImpressCustomerStaging);
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
                ToolTip = 'Retry processing for the selected Impress customer staging records that are in Error status.';

                trigger OnAction()
                var
                    ImpressCustomerStaging: Record "Impress Customer Staging";
                    ImpressCustomerProcessingRunner: Codeunit "Impress Cust Processing Runner";
                begin
                    CurrPage.SetSelectionFilter(ImpressCustomerStaging);
                    ImpressCustomerProcessingRunner.ProcessErrorCustomers(ImpressCustomerStaging);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
