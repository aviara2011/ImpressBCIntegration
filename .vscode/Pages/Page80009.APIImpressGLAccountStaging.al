page 80009 "API Impress GL Account Staging"
{
    PageType = API;
    SourceTable = "Impress G/L Account Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressGLAccountStaging';
    EntitySetName = 'impressGLAccountStaging';
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId) { Caption = 'Id'; }
                field(entryNo; Rec."Entry No.") { Caption = 'Entry No.'; }
                field(sqlRunId; Rec."SQL Run ID") { Caption = 'SQL Run ID'; }
                field(sqlEntryNo; Rec."SQL Entry No.") { Caption = 'SQL Entry No.'; }
                field(sourceDatabase; Rec."Source Database") { Caption = 'Source Database'; }
                field(glAccountNo; Rec."G/L Account No.") { Caption = 'G/L Account No.'; }
                field(description; Rec.Description) { Caption = 'Description'; }
                field(longDescription; Rec."Long Description") { Caption = 'Long Description'; }
                field(accountTypeCode; Rec."Account Type Code") { Caption = 'Account Type Code'; }
                field(inactive; Rec.Inactive) { Caption = 'Inactive'; }
                field(debitAccountNo; Rec."Debit Account No.") { Caption = 'Debit Account No.'; }
                field(creditAccountNo; Rec."Credit Account No.") { Caption = 'Credit Account No.'; }
                field(costOfSalesAccountNo; Rec."Cost of Sales Account No.") { Caption = 'Cost of Sales Account No.'; }
                field(costOfSalesCreditAccountNo; Rec."Cost of Sales Credit Acct. No.") { Caption = 'Cost of Sales Credit Account No.'; }
                field(factorFeeAccountNo; Rec."Factor Fee Account No.") { Caption = 'Factor Fee Account No.'; }
                field(factorReserveAccountNo; Rec."Factor Reserve Account No.") { Caption = 'Factor Reserve Account No.'; }
                field(operation; Rec.Operation) { Caption = 'Operation'; }
                field(transportStatus; Rec."Transport Status") { Caption = 'Transport Status'; }
                field(errorMessage; Rec."Error Message") { Caption = 'Error Message'; }
                field(bcSystemId; Rec."BC System ID") { Caption = 'BC System ID'; }
                field(extractedDateTime; Rec."Extracted DateTime") { Caption = 'Extracted DateTime'; }
                field(sentToBCDateTime; Rec."Sent to BC DateTime") { Caption = 'Sent to BC DateTime'; }
            }
        }
    }
}
