codeunit 80038 "Impress RP Posting Runner"
{
    TableNo = "Impress Inv Trans Staging";

    trigger OnRun()
    var
        Engine: Codeunit "Impress Trans. Posting Engine";
    begin
        Engine.ProcessTransactionAtomic(Rec);
    end;
}
