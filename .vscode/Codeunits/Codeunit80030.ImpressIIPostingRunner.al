codeunit 80030 "Impress II Posting Runner"
{
    TableNo = "Impress Sales Doc Hdr Staging";
    trigger OnRun()
    var
        Management: Codeunit "Impress II Invoice Mgt.";
    begin
        Management.PostDocumentAtomic(Rec, false);
    end;
}
