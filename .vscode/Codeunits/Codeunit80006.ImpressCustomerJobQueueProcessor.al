codeunit 80006 "Impress Customer JQ Processor"
{
    trigger OnRun()
    var
        ImpressCustomerProcessingRunner: Codeunit "Impress Cust Processing Runner";
    begin
        ImpressCustomerProcessingRunner.ProcessNewCustomers();
    end;
}
