page 80005 "API Impress Customer Staging"
{
    PageType = API;
    SourceTable = "Impress Customer Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressCustomerStaging';
    EntitySetName = 'impressCustomerStaging';
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
                field(customerNo; Rec."Customer No.") { Caption = 'Customer No.'; }
                field(name; Rec.Name) { Caption = 'Name'; }
                field(searchName; Rec."Search Name") { Caption = 'Search Name'; }
                field(address; Rec.Address) { Caption = 'Address'; }
                field(address2; Rec."Address 2") { Caption = 'Address 2'; }
                field(city; Rec.City) { Caption = 'City'; }
                field(state; Rec.State) { Caption = 'State'; }
                field(postCode; Rec."Post Code") { Caption = 'Post Code'; }
                field(countryCode; Rec."Country Code") { Caption = 'Country Code'; }
                field(phoneNo; Rec."Phone No.") { Caption = 'Phone No.'; }
                field(email; Rec.Email) { Caption = 'Email'; }
                field(contact; Rec.Contact) { Caption = 'Contact'; }
                field(paymentTermsCode; Rec."Payment Terms Code") { Caption = 'Payment Terms Code'; }
                field(currencyCode; Rec."Currency Code") { Caption = 'Currency Code'; }
                field(creditLimit; Rec."Credit Limit") { Caption = 'Credit Limit'; }
                field(salesTaxCode; Rec."Sales Tax Code") { Caption = 'Sales Tax Code'; }
                field(salespersonCode; Rec."Salesperson Code") { Caption = 'Salesperson Code'; }
                field(priceLevel; Rec."Price Level") { Caption = 'Price Level'; }
                field(customerStatus; Rec."Customer Status") { Caption = 'Customer Status'; }
                field(customerHold; Rec."Customer Hold") { Caption = 'Customer Hold'; }
                field(operation; Rec.Operation) { Caption = 'Operation'; }
                field(transportStatus; Rec."Transport Status") { Caption = 'Transport Status'; }
                field(errorMessage; Rec."Error Message") { Caption = 'Error Message'; }
                field(receivedDateTime; Rec."Received DateTime") { Caption = 'Received DateTime'; }
                field(processedDateTime; Rec."Processed DateTime") { Caption = 'Processed DateTime'; }
            }
        }
    }
}
