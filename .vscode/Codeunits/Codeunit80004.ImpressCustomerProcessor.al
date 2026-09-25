codeunit 80004 "Impress Customer Processor"
{
    TableNo = "Impress Customer Staging";

    trigger OnRun()
    begin
        ProcessCustomerStaging(Rec);
    end;

    procedure ProcessNewCustomers()
    var
        ImpressCustomerProcessingRunner: Codeunit "Impress Cust Processing Runner";
    begin
        ImpressCustomerProcessingRunner.ProcessNewCustomers();
    end;

    local procedure ProcessCustomerStaging(var ImpressCustomerStaging: Record "Impress Customer Staging")
    var
        Customer: Record Customer;
        ImpressDefaults: Record "Impress Defaults";
    begin
        ImpressCustomerStaging."Transport Status" := ImpressCustomerStaging."Transport Status"::Processing;
        ImpressCustomerStaging.Modify(true);

        if ImpressDefaults.Get() then;

        case ImpressCustomerStaging.Operation of
            ImpressCustomerStaging.Operation::Create,
            ImpressCustomerStaging.Operation::Update:
                UpsertCustomer(Customer, ImpressCustomerStaging, ImpressDefaults);
            ImpressCustomerStaging.Operation::Block:
                begin
                    UpsertCustomer(Customer, ImpressCustomerStaging, ImpressDefaults);
                    Customer.Validate(Blocked, Customer.Blocked::All);
                    Customer.Modify(true);
                end;
            ImpressCustomerStaging.Operation::Unblock:
                begin
                    UpsertCustomer(Customer, ImpressCustomerStaging, ImpressDefaults);
                    Customer.Validate(Blocked, Customer.Blocked::" ");
                    Customer.Modify(true);
                end;
        end;

        ImpressCustomerStaging."Transport Status" := ImpressCustomerStaging."Transport Status"::Processed;
        ImpressCustomerStaging."Processed DateTime" := CurrentDateTime();
        Clear(ImpressCustomerStaging."Error Message");
        ImpressCustomerStaging.Modify(true);
    end;

    local procedure UpsertCustomer(var Customer: Record Customer; ImpressCustomerStaging: Record "Impress Customer Staging"; ImpressDefaults: Record "Impress Defaults")
    begin
        if not Customer.Get(ImpressCustomerStaging."Customer No.") then begin
            Customer.Init();
            Customer.Validate("No.", ImpressCustomerStaging."Customer No.");
            Customer.Insert(true);
            MapCustomerFields(Customer, ImpressCustomerStaging);
            ApplyCustomerDefaults(Customer, ImpressDefaults);
            Customer.Validate("Tax Liable", true);
            Customer.Modify(true);
        end else begin
            MapCustomerFields(Customer, ImpressCustomerStaging);
            Customer.Modify(true);
        end;
    end;

    local procedure MapCustomerFields(var Customer: Record Customer; ImpressCustomerStaging: Record "Impress Customer Staging")
    begin
        Customer.Validate(Name, ImpressCustomerStaging.Name);
        Customer.Validate("Search Name", ImpressCustomerStaging."Search Name");
        Customer.Validate(Address, ImpressCustomerStaging.Address);
        Customer.Validate("Address 2", ImpressCustomerStaging."Address 2");
        Customer.Validate(City, ImpressCustomerStaging.City);
        Customer.Validate(County, ImpressCustomerStaging.State);
        Customer.Validate("Post Code", ImpressCustomerStaging."Post Code");
        EnsureCountryRegionExists(ImpressCustomerStaging."Country Code");
        Customer.Validate("Country/Region Code", ImpressCustomerStaging."Country Code");
        Customer."Phone No." := GetPhoneNoWithoutLettersOrBlank(ImpressCustomerStaging."Phone No.");
        Customer."E-Mail" := GetValidEmailOrBlank(ImpressCustomerStaging.Email);
        Customer.Validate(Contact, ImpressCustomerStaging.Contact);
        EnsurePaymentTermsExists(ImpressCustomerStaging."Payment Terms Code");
        Customer.Validate("Payment Terms Code", ImpressCustomerStaging."Payment Terms Code");
        Customer.Validate("Currency Code", ImpressCustomerStaging."Currency Code");
        Customer.Validate("Credit Limit (LCY)", ImpressCustomerStaging."Credit Limit");
        EnsureSalespersonExists(ImpressCustomerStaging."Salesperson Code");
        Customer.Validate("Salesperson Code", ImpressCustomerStaging."Salesperson Code");
        Customer.Validate("Tax Area Code", EnsureTaxAreaExists(ImpressCustomerStaging."Sales Tax Code"));

        if IsCustomerBlocked(ImpressCustomerStaging) then
            Customer.Validate(Blocked, Customer.Blocked::All)
        else
            Customer.Validate(Blocked, Customer.Blocked::" ");
    end;

    local procedure IsCustomerBlocked(ImpressCustomerStaging: Record "Impress Customer Staging"): Boolean
    begin
        exit((ImpressCustomerStaging."Customer Status" <> '') and (ImpressCustomerStaging."Customer Status" <> 'A') or (ImpressCustomerStaging."Customer Hold" <> ''));
    end;

    local procedure ApplyCustomerDefaults(var Customer: Record Customer; ImpressDefaults: Record "Impress Defaults")
    begin
        if ImpressDefaults."Cust. Gen. Bus. Posting Group" <> '' then
            Customer.Validate("Gen. Bus. Posting Group", ImpressDefaults."Cust. Gen. Bus. Posting Group");

        if ImpressDefaults."Customer Posting Group" <> '' then
            Customer.Validate("Customer Posting Group", ImpressDefaults."Customer Posting Group");
    end;

    local procedure EnsurePaymentTermsExists(PaymentTermsCode: Code[20])
    var
        PaymentTerms: Record "Payment Terms";
    begin
        if PaymentTermsCode = '' then
            exit;

        if PaymentTerms.Get(PaymentTermsCode) then
            exit;

        PaymentTerms.Init();
        PaymentTerms.Validate(Code, PaymentTermsCode);
        PaymentTerms.Validate(Description, PaymentTermsCode);
        PaymentTerms.Insert(true);
    end;

    local procedure GetPhoneNoWithoutLettersOrBlank(PhoneNo: Text[30]): Text[30]
    var
        UpperPhoneNo: Text[30];
    begin
        UpperPhoneNo := UpperCase(PhoneNo);
        if DelChr(UpperPhoneNo, '=', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ') <> UpperPhoneNo then
            exit('');

        exit(PhoneNo);
    end;

    local procedure GetValidEmailOrBlank(EmailAddress: Text[100]): Text[80]
    var
        MailManagement: Codeunit "Mail Management";
        CleanEmailAddress: Text[80];
    begin
        CleanEmailAddress := CopyStr(DelChr(EmailAddress, '=', ' '), 1, MaxStrLen(CleanEmailAddress));
        if CleanEmailAddress = '' then
            exit('');

        if not MailManagement.CheckValidEmailAddress(CleanEmailAddress) then
            exit('');

        exit(CleanEmailAddress);
    end;

    local procedure EnsureCountryRegionExists(CountryRegionCode: Code[10])
    var
        CountryRegion: Record "Country/Region";
    begin
        if CountryRegionCode = '' then
            exit;

        if CountryRegion.Get(CountryRegionCode) then
            exit;

        CountryRegion.Init();
        CountryRegion.Validate(Code, CountryRegionCode);
        CountryRegion.Validate(Name, CountryRegionCode);
        CountryRegion.Insert(true);
    end;

    local procedure EnsureSalespersonExists(SalespersonCode: Code[20])
    var
        SalespersonPurchaser: Record "Salesperson/Purchaser";
    begin
        if SalespersonCode = '' then
            exit;

        if SalespersonPurchaser.Get(SalespersonCode) then
            exit;

        SalespersonPurchaser.Init();
        SalespersonPurchaser.Validate(Code, SalespersonCode);
        SalespersonPurchaser.Validate(Name, SalespersonCode);
        SalespersonPurchaser.Insert(true);
    end;

    local procedure EnsureTaxAreaExists(SalesTaxCode: Code[30]): Code[20]
    var
        TaxArea: Record "Tax Area";
        TaxAreaCode: Code[20];
    begin
        if SalesTaxCode = '' then
            exit('');

        if StrLen(SalesTaxCode) > MaxStrLen(TaxArea.Code) then
            Error('Impress Sales Tax Code %1 is longer than the Business Central Tax Area Code length of %2.', SalesTaxCode, MaxStrLen(TaxArea.Code));

        TaxAreaCode := SalesTaxCode;
        if TaxArea.Get(TaxAreaCode) then
            exit(TaxAreaCode);

        TaxArea.Init();
        TaxArea.Validate(Code, TaxAreaCode);
        TaxArea.Validate(Description, TaxAreaCode);
        TaxArea.Insert(true);

        exit(TaxAreaCode);
    end;
}
