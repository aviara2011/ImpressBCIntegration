page 80025 "Impress Conversion Mappings"
{
    PageType = List;
    SourceTable = "Impress Conversion Mapping";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Impress Conversion Mappings';

    layout
    {
        area(content)
        {
            repeater(Mappings)
            {
                field(Module; Rec.Module)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the conversion applies to purchase or sales documents.';
                }
                field("Source Database"; Rec."Source Database")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Impress source database for this charge conversion.';
                }
                field("Conversion Type"; Rec."Conversion Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the kind of value being converted.';
                }
                field("Impress Code"; Rec."Impress Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source value received from Impress.';
                }
                field("BC Type"; Rec."BC Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central document line type produced by this conversion.';
                }
                field("BC No."; Rec."BC No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central number. The lookup is determined by BC Type.';
                }
            }
        }
    }
}
