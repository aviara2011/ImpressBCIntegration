page 80007 "API Impress Vendor Staging"
{
    PageType = API;
    SourceTable = "Impress Vendor Staging";
    APIPublisher = 'Techstyles';
    APIGroup = 'impress';
    APIVersion = 'v1.0';
    EntityName = 'impressVendorStaging';
    EntitySetName = 'impressVendorStaging';
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
                field(vendorNo; Rec."Vendor No.") { Caption = 'Vendor No.'; }
                field(name; Rec.Name) { Caption = 'Name'; }
                field(searchName; Rec."Search Name") { Caption = 'Search Name'; }
                field(address; Rec.Address) { Caption = 'Address'; }
                field(address2; Rec."Address 2") { Caption = 'Address 2'; }
                field(address3; Rec."Address 3") { Caption = 'Address 3'; }
                field(city; Rec.City) { Caption = 'City'; }
                field(state; Rec.State) { Caption = 'State'; }
                field(postCode; Rec."Post Code") { Caption = 'Post Code'; }
                field(countryCode; Rec."Country Code") { Caption = 'Country Code'; }
                field(phoneNo; Rec."Phone No.") { Caption = 'Phone No.'; }
                field(faxNo; Rec."Fax No.") { Caption = 'Fax No.'; }
                field(email; Rec.Email) { Caption = 'Email'; }
                field(homePage; Rec."Home Page") { Caption = 'Home Page'; }
                field(contact; Rec.Contact) { Caption = 'Contact'; }
                field(paymentTermsCode; Rec."Payment Terms Code") { Caption = 'Payment Terms Code'; }
                field(currencyCode; Rec."Currency Code") { Caption = 'Currency Code'; }
                field(accountNo; Rec."Account No.") { Caption = 'Account No.'; }
                field(warehouseCode; Rec."Warehouse Code") { Caption = 'Warehouse Code'; }
                field(vendorInactive; Rec."Vendor Inactive") { Caption = 'Vendor Inactive'; }
                field(vendorHold; Rec."Vendor Hold") { Caption = 'Vendor Hold'; }
                field(sourceCreatedDateTime; Rec."Source Created DateTime") { Caption = 'Source Created DateTime'; }
                field(sourceModifiedDateTime; Rec."Source Modified DateTime") { Caption = 'Source Modified DateTime'; }
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
