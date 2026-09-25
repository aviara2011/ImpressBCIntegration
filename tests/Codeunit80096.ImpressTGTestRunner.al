#if TG_TESTS
codeunit 80096 "Impress TG Test Runner"
{
    Subtype = TestRunner;
    TestIsolation = Function;

    trigger OnRun()
    begin
        Codeunit.Run(Codeunit::"Impress TG Tests");
        Codeunit.Run(Codeunit::"Impress Profile Tests");
        Codeunit.Run(Codeunit::"Impress Invoice Match Tests");
    end;
}
#endif
