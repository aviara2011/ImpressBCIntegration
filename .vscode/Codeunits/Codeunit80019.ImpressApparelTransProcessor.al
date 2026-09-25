codeunit 80019 "Impress Apparel Trans. Proc."
{
    TableNo = "Job Queue Entry";
    trigger OnRun()
    var
        PostingEngine: Codeunit "Impress Trans. Posting Engine";
    begin
        PostingEngine.ProcessSourceDatabase('ImpressTest');
    end;
}
