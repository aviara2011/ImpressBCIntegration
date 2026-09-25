page 80000 "API Impress Control"
{
    PageType = API;
    SourceTable = "Impress Integration Control";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'integrationControl';
    EntitySetName = 'integrationControls';
    DelayedInsert = true;
    ODataKeyFields = SystemId;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId) { Caption = 'Id'; }
                field(runId; Rec."Run ID") { Caption = 'Run Id'; }
                field(sqlRunId; Rec."SQL Run ID") { Caption = 'SQL Run ID'; }
                field(sqlRunGuid; Rec."SQL Run Guid") { Caption = 'SQL Run Guid'; }
                field(processName; Rec."Process Name") { Caption = 'Process Name'; }
                field(runStartDateTime; Rec."Run Start DateTime") { Caption = 'Run Start DateTime'; }
                field(runEndDateTime; Rec."Run End DateTime") { Caption = 'Run End DateTime'; }
                field(runStatus; Rec."Run Status") { Caption = 'Run Status'; }
                field(runMessage; Rec."Run Message") { Caption = 'Run Message'; }
                field(lastSuccessfulRunDateTime; Rec."Last Successful Run DateTime") { Caption = 'Last Successful Run DateTime'; }
                field(recordsSelected; Rec."Records Selected") { Caption = 'Records Selected'; }
                field(recordsStaged; Rec."Records Staged") { Caption = 'Records Staged'; }
                field(recordsSentToBC; Rec."Records Sent To BC") { Caption = 'Records Sent To BC'; }
                field(recordsFailed; Rec."Records Failed") { Caption = 'Records Failed'; }
                field(recordsProcessedInBC; Rec."Records Processed In BC") { Caption = 'Records Processed In BC'; }
                field(difference; Rec.Difference) { Caption = 'Difference'; }
            }
        }
    }
}
