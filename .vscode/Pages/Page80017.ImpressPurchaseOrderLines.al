page 80017 "Impress Purchase Order Lines"
{
    PageType = ListPart;
    SourceTable = "Impress Purchase Line Staging";
    ApplicationArea = All;
    Caption = 'Lines';
    Editable = false;
    AutoSplitKey = false;

    layout
    {
        area(content)
        {
            repeater(Lines)
            {
                field("Source Line No."; Rec."Source Line No.") { ApplicationArea = All; }
                field("Size Position"; Rec."Size Position") { ApplicationArea = All; }
                field("BC Item No."; Rec."BC Item No.") { ApplicationArea = All; }
                field("BC Variant Code"; Rec."BC Variant Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Unit of Measure Code"; Rec."Unit of Measure Code") { ApplicationArea = All; }
                field("Quantity Ordered"; Rec."Quantity Ordered") { ApplicationArea = All; }
                field("Quantity Received"; Rec."Quantity Received") { ApplicationArea = All; }
                field("Quantity Remaining"; Rec."Quantity Remaining") { ApplicationArea = All; }
                field("Direct Unit Cost"; Rec."Direct Unit Cost") { ApplicationArea = All; }
                field("Ordered Line Amount"; Rec."Ordered Line Amount") { ApplicationArea = All; }
                field("Expected Receipt Date"; Rec."Expected Receipt Date") { ApplicationArea = All; }
                field(Operation; Rec.Operation) { ApplicationArea = All; }
                field("Processing Status"; Rec."Processing Status") { ApplicationArea = All; StyleExpr = StatusStyle; }
                field("BC Line No."; Rec."BC Line No.") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec."Processing Status" of
            Rec."Processing Status"::Processed:
                StatusStyle := 'Favorable';
            Rec."Processing Status"::Error:
                StatusStyle := 'Unfavorable';
            Rec."Processing Status"::Processing:
                StatusStyle := 'Ambiguous';
            else
                StatusStyle := 'Standard';
        end;
    end;

    var
        StatusStyle: Text;
}
