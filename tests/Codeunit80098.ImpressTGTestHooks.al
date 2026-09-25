#if TG_TESTS
codeunit 80098 "Impress TG Test Hooks"
{
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Batch", 'OnAfterPostJnlLines', '', false, false)]
    local procedure FailAfterPosting()
    begin
        PostedComponents += 1;
        if (FailOnComponent > 0) and (PostedComponents <> FailOnComponent) then
            exit;
        Error('TG injected failure after posting');
    end;

    procedure FailAfterComponent(ComponentNo: Integer)
    begin
        FailOnComponent := ComponentNo;
        PostedComponents := 0;
    end;

    var
        FailOnComponent: Integer;
        PostedComponents: Integer;
}
#endif
