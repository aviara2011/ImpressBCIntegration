codeunit 80007 "Impress Vendor Processor"
{
    TableNo = "Impress Vendor Staging";

    trigger OnRun()
    begin
        ProcessVendorStaging(Rec);
    end;

    procedure UpdateVendorsWithImpressDefaults(): Integer
    var
        Vendor: Record Vendor;
        ImpressDefaults: Record "Impress Defaults";
        UpdatedCount: Integer;
    begin
        if ImpressDefaults.Get() then;
        EnsureVendorDefaultsConfigured(ImpressDefaults);

        if Vendor.FindSet(true) then
            repeat
                ApplyVendorDefaults(Vendor, ImpressDefaults);
                Vendor.Modify(true);
                UpdatedCount += 1;
            until Vendor.Next() = 0;

        exit(UpdatedCount);
    end;

    local procedure ProcessVendorStaging(var ImpressVendorStaging: Record "Impress Vendor Staging")
    var
        Vendor: Record Vendor;
        ImpressDefaults: Record "Impress Defaults";
    begin
        ImpressVendorStaging."Transport Status" := ImpressVendorStaging."Transport Status"::Processing;
        ImpressVendorStaging.Modify(true);

        if ImpressDefaults.Get() then;

        UpsertVendor(Vendor, ImpressVendorStaging, ImpressDefaults);

        case ImpressVendorStaging.Operation of
            ImpressVendorStaging.Operation::Block:
                Vendor.Validate(Blocked, Vendor.Blocked::All);
            ImpressVendorStaging.Operation::Unblock:
                Vendor.Validate(Blocked, Vendor.Blocked::" ");
        end;
        Vendor.Modify(true);

        ImpressVendorStaging."Transport Status" := ImpressVendorStaging."Transport Status"::Processed;
        ImpressVendorStaging."BC System ID" := Vendor.SystemId;
        ImpressVendorStaging."Sent to BC DateTime" := CurrentDateTime();
        Clear(ImpressVendorStaging."Error Message");
        ImpressVendorStaging.Modify(true);
    end;

    local procedure UpsertVendor(var Vendor: Record Vendor; ImpressVendorStaging: Record "Impress Vendor Staging"; ImpressDefaults: Record "Impress Defaults")
    begin
        if not Vendor.Get(ImpressVendorStaging."Vendor No.") then begin
            EnsureVendorDefaultsConfigured(ImpressDefaults);
            Vendor.Init();
            Vendor.Validate("No.", ImpressVendorStaging."Vendor No.");
            Vendor.Insert(true);
            MapVendorFields(Vendor, ImpressVendorStaging);
            ApplyVendorDefaults(Vendor, ImpressDefaults);
        end else
            MapVendorFields(Vendor, ImpressVendorStaging);
    end;

    local procedure MapVendorFields(var Vendor: Record Vendor; ImpressVendorStaging: Record "Impress Vendor Staging")
    begin
        Vendor.Validate(Name, CopyStr(ImpressVendorStaging.Name, 1, MaxStrLen(Vendor.Name)));
        Vendor.Validate("Search Name", CopyStr(ImpressVendorStaging."Search Name", 1, MaxStrLen(Vendor."Search Name")));
        Vendor.Validate(Address, CopyStr(ImpressVendorStaging.Address, 1, MaxStrLen(Vendor.Address)));
        Vendor.Validate("Address 2", CopyStr(ImpressVendorStaging."Address 2", 1, MaxStrLen(Vendor."Address 2")));
        Vendor.Validate(City, CopyStr(ImpressVendorStaging.City, 1, MaxStrLen(Vendor.City)));
        Vendor.Validate(County, CopyStr(ImpressVendorStaging.State, 1, MaxStrLen(Vendor.County)));
        Vendor.Validate("Post Code", CopyStr(ImpressVendorStaging."Post Code", 1, MaxStrLen(Vendor."Post Code")));
        EnsureCountryRegionExists(ImpressVendorStaging."Country Code");
        Vendor.Validate("Country/Region Code", ImpressVendorStaging."Country Code");
        Vendor."Phone No." := CopyStr(GetPhoneNoWithoutLettersOrBlank(ImpressVendorStaging."Phone No."), 1, MaxStrLen(Vendor."Phone No."));
        Vendor."Fax No." := CopyStr(GetPhoneNoWithoutLettersOrBlank(ImpressVendorStaging."Fax No."), 1, MaxStrLen(Vendor."Fax No."));
        Vendor."E-Mail" := GetValidEmailOrBlank(ImpressVendorStaging.Email);
        Vendor."Home Page" := CopyStr(ImpressVendorStaging."Home Page", 1, MaxStrLen(Vendor."Home Page"));
        Vendor.Validate(Contact, CopyStr(ImpressVendorStaging.Contact, 1, MaxStrLen(Vendor.Contact)));
        EnsurePaymentTermsExists(ImpressVendorStaging."Payment Terms Code");
        Vendor.Validate("Payment Terms Code", ImpressVendorStaging."Payment Terms Code");
        Vendor.Validate("Currency Code", ImpressVendorStaging."Currency Code");
        Vendor.Validate("Our Account No.", CopyStr(ImpressVendorStaging."Account No.", 1, MaxStrLen(Vendor."Our Account No.")));
        Vendor.Validate("Location Code", CopyStr(ImpressVendorStaging."Warehouse Code", 1, MaxStrLen(Vendor."Location Code")));

        if ImpressVendorStaging."Vendor Inactive" or (ImpressVendorStaging."Vendor Hold" <> '') then
            Vendor.Validate(Blocked, Vendor.Blocked::All)
        else
            Vendor.Validate(Blocked, Vendor.Blocked::" ");
    end;

    local procedure ApplyVendorDefaults(var Vendor: Record Vendor; ImpressDefaults: Record "Impress Defaults")
    begin
        if ImpressDefaults."Vend. Gen. Bus. Posting Group" <> '' then
            Vendor.Validate("Gen. Bus. Posting Group", ImpressDefaults."Vend. Gen. Bus. Posting Group");

        if ImpressDefaults."Vendor Posting Group" <> '' then
            Vendor.Validate("Vendor Posting Group", ImpressDefaults."Vendor Posting Group");
    end;

    local procedure EnsureVendorDefaultsConfigured(ImpressDefaults: Record "Impress Defaults")
    begin
        if ImpressDefaults."Vend. Gen. Bus. Posting Group" = '' then
            Error('Vendor Gen. Business Posting Group must be specified on Impress Defaults before creating vendors from Impress vendor staging.');

        if ImpressDefaults."Vendor Posting Group" = '' then
            Error('Vendor Posting Group must be specified on Impress Defaults before creating vendors from Impress vendor staging.');
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
}
