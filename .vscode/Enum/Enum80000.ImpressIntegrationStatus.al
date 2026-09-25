enum 80000 "Impress Integration Status"
{
    Extensible = true;

    value(0; New)
    {
        Caption = 'New';
    }
    value(1; Processing)
    {
        Caption = 'Processing';
    }
    value(2; Processed)
    {
        Caption = 'Processed';
    }
    value(3; Error)
    {
        Caption = 'Error';
    }
    value(4; Sent)
    {
        Caption = 'Sent';
    }
    value(5; Ignored)
    {
        Caption = 'Ignored';
    }
}
