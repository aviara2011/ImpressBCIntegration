codeunit 80017 "Impress Category Dimension"
{
    procedure RemoveFromDimensionSet(var DimensionSetID: Integer; DimensionCode: Code[20])
    var
        Entry: Record "Dimension Set Entry" temporary;
        Management: Codeunit DimensionManagement;
    begin
        Management.GetDimensionSet(Entry, DimensionSetID);
        Entry.SetRange("Dimension Code", DimensionCode);
        Entry.DeleteAll();
        Entry.Reset();
        DimensionSetID := Management.GetDimensionSetID(Entry);
    end;

    procedure GetDimensionValueCode(SourceDatabase: Code[50]; DivisionCode: Code[20]): Code[20]
    begin
        case SourceDatabase of
            'ImpressTest':
                exit('AP');
            'StickersTest':
                case DivisionCode of
                    '', 'STK':
                        exit('ST');
                    'HG':
                        exit('HG');
                    else
                        Error(
                            'Division Code %1 has no Category dimension mapping for database %2.',
                            DivisionCode, SourceDatabase);
                end;
            else
                Error('Source Database %1 has no Category dimension mapping.', SourceDatabase);
        end;
    end;

    procedure ApplyToDimensionSet(var DimensionSetID: Integer; DimensionCode: Code[20]; DimensionValueCode: Code[20])
    var
        TempDimensionSetEntry: Record "Dimension Set Entry" temporary;
        DimensionManagement: Codeunit DimensionManagement;
    begin
        DimensionManagement.GetDimensionSet(TempDimensionSetEntry, DimensionSetID);
        TempDimensionSetEntry.SetRange("Dimension Code", DimensionCode);
        if TempDimensionSetEntry.FindFirst() then begin
            TempDimensionSetEntry.Validate("Dimension Value Code", DimensionValueCode);
            TempDimensionSetEntry.Modify();
        end else begin
            TempDimensionSetEntry.Reset();
            TempDimensionSetEntry.Init();
            TempDimensionSetEntry."Dimension Set ID" := DimensionSetID;
            TempDimensionSetEntry.Validate("Dimension Code", DimensionCode);
            TempDimensionSetEntry.Validate("Dimension Value Code", DimensionValueCode);
            TempDimensionSetEntry.Insert();
        end;
        TempDimensionSetEntry.Reset();
        DimensionSetID := DimensionManagement.GetDimensionSetID(TempDimensionSetEntry);
    end;
}
