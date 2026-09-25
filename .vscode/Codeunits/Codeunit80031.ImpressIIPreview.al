codeunit 80031 "Impress II Preview"
{
    TableNo = "Impress Sales Doc Hdr Staging";
    EventSubscriberInstance = Manual;

    trigger OnRun()
    var
        Management: Codeunit "Impress II Invoice Mgt.";
    begin
        Management.PostDocumentAtomic(Rec, true);
        Error('The I/I document did not produce a posting preview.');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Preview", 'OnRunPreview', '', false, false)]
    local procedure RunPreview(var Result: Boolean; Subscriber: Variant; RecVar: Variant)
    var
        Header: Record "Impress Sales Doc Hdr Staging";
        Runner: Codeunit "Impress II Preview";
        ErrorManagement: Codeunit "Error Message Management";
        TempErrors: Record "Error Message" temporary;
        FailureText: Text;
    begin
        Header := RecVar;
        ClearLastError();
        Result := Runner.Run(Header);
        // The runner always ends in an error to roll back preparation and posting.
        // Keep normal errors and the standard successful-preview sentinel intact.
        if not Result and (GetLastErrorCallStack() <> '') then
            exit;

        FailureText := GetLastErrorText();
        TempErrors.SetRange("Message Type", TempErrors."Message Type"::Error);
        if ErrorManagement.GetErrors(TempErrors) then begin
            TempErrors.ShowErrors();
            Error('');
        end;
        if FailureText <> '' then
            Error('Invoice %1 posting preview stopped: %2', Header."Document No.", FailureText);
        Error('Invoice %1 posting preview did not return the required rollback error, and BC retained no validation details. Preview cannot be displayed. Capture the first error in the AL debugger before retrying.', Header."Document No.");
    end;
}
