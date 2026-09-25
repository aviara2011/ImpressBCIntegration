codeunit 80012 "Impress GL JQ Processor"
{
    trigger OnRun()
    var
        ImpressGLAccountProcessingRunner: Codeunit "Impress GL Processing Runner";
    begin
        ImpressGLAccountProcessingRunner.ProcessNewGLAccounts();
    end;
}
