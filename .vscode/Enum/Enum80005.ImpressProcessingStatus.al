enum 80005 "Impress Processing Status"
{
    Extensible = true;
    value(0; Pending) { Caption = 'Pending'; }
    value(1; Processing) { Caption = 'Processing'; }
    value(2; Processed) { Caption = 'Processed'; }
    value(3; Error) { Caption = 'Error'; }
    value(4; Ignored) { Caption = 'Ignored'; }
}
