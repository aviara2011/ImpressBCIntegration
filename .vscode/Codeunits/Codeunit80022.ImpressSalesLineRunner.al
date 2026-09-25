codeunit 80022 "Impress Sales Line Runner"
{
    TableNo = "Impress Sales Line Staging";

    trigger OnRun()
    begin
        RunLine(Rec);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    local procedure RunLine(var Staging: Record "Impress Sales Line Staging")
    var
        SalesOrderMgt: Codeunit "Impress Sales Order Mgt.";
    begin
        SalesOrderMgt.ProcessLine(Staging);
    end;
}
