codeunit 80020 "Impress Stickers Trans. Proc."
{
    TableNo = "Job Queue Entry";
    trigger OnRun()
    var
        PostingEngine: Codeunit "Impress Trans. Posting Engine";
    begin
        PostingEngine.ProcessSourceDatabase('StickersTest');
    end;
}
