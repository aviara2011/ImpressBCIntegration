codeunit 80009 "Impress Vendor JQ Processor"
{
    trigger OnRun()
    var
        ImpressVendorProcessingRunner: Codeunit "Impress Vend Processing Runner";
    begin
        ImpressVendorProcessingRunner.ProcessNewVendors();
    end;
}
