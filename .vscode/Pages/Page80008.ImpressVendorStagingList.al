page 80008 "Impress Vendor Staging List"
{
    PageType = List;
    SourceTable = "Impress Vendor Staging";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Impress Vendor Staging';
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
                field("Vendor No."; Rec."Vendor No.") { ApplicationArea = All; }
                field(Name; Rec.Name) { ApplicationArea = All; }
                field(City; Rec.City) { ApplicationArea = All; }
                field(State; Rec.State) { ApplicationArea = All; }
                field("Post Code"; Rec."Post Code") { ApplicationArea = All; }
                field("Country Code"; Rec."Country Code") { ApplicationArea = All; }
                field("Phone No."; Rec."Phone No.") { ApplicationArea = All; }
                field(Email; Rec.Email) { ApplicationArea = All; }
                field("Payment Terms Code"; Rec."Payment Terms Code") { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field("Warehouse Code"; Rec."Warehouse Code") { ApplicationArea = All; }
                field("Vendor Inactive"; Rec."Vendor Inactive") { ApplicationArea = All; }
                field("Vendor Hold"; Rec."Vendor Hold") { ApplicationArea = All; }
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
            action(ProcessVendors)
            {
                ApplicationArea = All;
                Caption = 'Process Vendor(s)';
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Create or update vendors for the selected Impress vendor staging records.';

                trigger OnAction()
                var
                    ImpressVendorStaging: Record "Impress Vendor Staging";
                    ImpressVendorProcessingRunner: Codeunit "Impress Vend Processing Runner";
                begin
                    CurrPage.SetSelectionFilter(ImpressVendorStaging);
                    ImpressVendorProcessingRunner.ProcessVendors(ImpressVendorStaging);
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
                ToolTip = 'Retry selected Impress vendor staging records that are in Error status.';

                trigger OnAction()
                var
                    ImpressVendorStaging: Record "Impress Vendor Staging";
                    ImpressVendorProcessingRunner: Codeunit "Impress Vend Processing Runner";
                begin
                    CurrPage.SetSelectionFilter(ImpressVendorStaging);
                    ImpressVendorProcessingRunner.ProcessErrorVendors(ImpressVendorStaging);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
