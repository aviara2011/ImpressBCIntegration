codeunit 80023 "Impress Sales Header Runner"
{
    TableNo = "Impress Sales Header Staging";

    trigger OnRun()
    var
        Mgt: Codeunit "Impress Sales Order Mgt.";
    begin
        Mgt.PrepareSalesHeader(Rec);
    end;
}
