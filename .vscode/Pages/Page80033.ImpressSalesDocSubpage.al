page 80033 "Impress Sales Doc. Subpage"
{
    PageType = ListPart;
    SourceTable = "Impress Sales Doc Line Staging";
    Caption = 'Impress Sales Document Lines';
    ApplicationArea = All;
    Editable = true;
    DeleteAllowed = true;
    InsertAllowed = false;
    SourceTableView = sorting("Sales Document Entry No.", "Source Line No.", "Source Sequence", "Size Position");

    layout
    {
        area(content)
        {
            repeater(Lines)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; Visible = false; Editable = false; }
                field("Sales Document Entry No."; Rec."Sales Document Entry No.") { ApplicationArea = All; Visible = false; Editable = false; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; Visible = false; Editable = false; }
                field("Source Customer Code"; Rec."Source Customer Code") { ApplicationArea = All; }
                field("Document Type"; Rec."Document Type") { ApplicationArea = All; Visible = false; Editable = false; }
                field("Document No."; Rec."Document No.") { ApplicationArea = All; Visible = false; Editable = false; }
                field("Source Line No."; Rec."Source Line No.") { ApplicationArea = All; }
                field("Source Sequence"; Rec."Source Sequence") { ApplicationArea = All; }
                field("Source Sales Order Line No."; Rec."Source Sales Order Line No.") { ApplicationArea = All; Editable = false; }
                field("Size Position"; Rec."Size Position") { ApplicationArea = All; }
                field("Source Line Type"; Rec."Source Line Type") { ApplicationArea = All; }
                field("Source Item Code"; Rec."Source Item Code") { ApplicationArea = All; }
                field("Source Raw SKU No."; Rec."Source Raw SKU No.") { ApplicationArea = All; }
                field("Source Size"; Rec."Source Size") { ApplicationArea = All; }
                field("Source Description"; Rec."Source Description") { ApplicationArea = All; }
                field(Quantity; Rec.Quantity) { ApplicationArea = All; }
                field("Unit Price"; Rec."Unit Price") { ApplicationArea = All; }
                field(Amount; Rec.Amount) { ApplicationArea = All; }
                field("Tax Group Code"; Rec."Tax Group Code") { ApplicationArea = All; Editable = false; }
                field("Non Tax Category Code"; Rec."Non Tax Category Code") { ApplicationArea = All; Editable = false; }
                field("Tax Group Description"; Rec."Tax Group Description") { ApplicationArea = All; Editable = false; }
                field("BC Item No."; Rec."BC Item No.") { ApplicationArea = All; }
                field("BC Variant Code"; Rec."BC Variant Code") { ApplicationArea = All; }
                field("Revenue G/L Account"; Rec."Revenue G/L Account") { ApplicationArea = All; }
                field("Inventory G/L Account"; Rec."Inventory G/L Account") { ApplicationArea = All; }
                field("COGS G/L Account"; Rec."COGS G/L Account") { ApplicationArea = All; }
                field("Related Inventory Transaction ID"; Rec."Related Inventory Trans. ID") { ApplicationArea = All; }
                field("Processing Status"; Rec."Processing Status") { ApplicationArea = All; }
                field("Transport Status"; Rec."Transport Status") { ApplicationArea = All; }
                field("BC System ID"; Rec."BC System ID") { ApplicationArea = All; }
                field("BC Line System ID"; Rec."BC Line System ID") { ApplicationArea = All; }
                field("BC Sales Line No."; Rec."BC Sales Line No.") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
                field("Date Staged"; Rec."Date Staged") { ApplicationArea = All; }
                field("Date Processed"; Rec."Date Processed") { ApplicationArea = All; }
            }
        }
    }

}

