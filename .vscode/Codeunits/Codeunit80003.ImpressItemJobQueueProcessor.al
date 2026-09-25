codeunit 80003 "Impress Item JQ Processor"
{
    trigger OnRun()
    var
        ImpressItemProcessingRunner: Codeunit "Impress Item Processing Runner";
    begin
        ImpressItemProcessingRunner.ProcessNewItems();
    end;
}
