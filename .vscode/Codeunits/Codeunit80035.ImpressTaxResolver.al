codeunit 80035 "Impress Tax Resolver"
{
    procedure EnsureTaxJurisdiction(JurisdictionCode: Text; JurisdictionDescription: Text[100]; GLAccountNo: Text)
    var
        TaxJurisdiction: Record "Tax Jurisdiction";
        GLAccount: Record "G/L Account";
        Changed: Boolean;
    begin
        if JurisdictionCode = '' then
            exit;
        CheckLength(JurisdictionCode, MaxStrLen(TaxJurisdiction.Code), 'Tax Jurisdiction Code');
        CheckLength(GLAccountNo, MaxStrLen(TaxJurisdiction."Tax Account (Sales)"), 'Tax G/L Account');
        if (GLAccountNo <> '') and not GLAccount.Get(GLAccountNo) then
            Error('G/L Account %1 referenced by Tax Jurisdiction %2 does not exist.', GLAccountNo, JurisdictionCode);
        if not TaxJurisdiction.Get(JurisdictionCode) then begin
            TaxJurisdiction.Init();
            TaxJurisdiction.Code := JurisdictionCode;
            TaxJurisdiction.Insert(true);
        end;
        if (JurisdictionDescription <> '') and (TaxJurisdiction.Description <> JurisdictionDescription) then begin
            TaxJurisdiction.Description := JurisdictionDescription;
            Changed := true;
        end;
        if (GLAccountNo <> '') and (TaxJurisdiction."Tax Account (Sales)" <> GLAccountNo) then begin
            TaxJurisdiction.Validate("Tax Account (Sales)", GLAccountNo);
            Changed := true;
        end;
        if Changed then
            TaxJurisdiction.Modify(true);
    end;

    procedure EnsureTaxArea(TaxAreaCode: Text; TaxAreaDescription: Text[100])
    var
        TaxArea: Record "Tax Area";
    begin
        CheckLength(TaxAreaCode, MaxStrLen(TaxArea.Code), 'Tax Area Code');
        if TaxArea.Get(TaxAreaCode) then begin
            if (TaxAreaDescription <> '') and (TaxArea.Description <> TaxAreaDescription) then begin
                TaxArea.Description := TaxAreaDescription;
                TaxArea.Modify(true);
            end;
            exit;
        end;
        TaxArea.Init();
        TaxArea.Code := TaxAreaCode;
        if TaxAreaDescription <> '' then
            TaxArea.Description := TaxAreaDescription
        else
            TaxArea.Description := TaxAreaCode;
        TaxArea.Insert(true);
    end;

    procedure EnsureTaxAreaLine(TaxAreaCode: Text; JurisdictionCode: Text; CalculationOrder: Integer)
    var
        TaxAreaLine: Record "Tax Area Line";
    begin
        if JurisdictionCode = '' then
            exit;
        if TaxAreaLine.Get(TaxAreaCode, JurisdictionCode) then begin
            if TaxAreaLine."Calculation Order" <> CalculationOrder then begin
                TaxAreaLine."Calculation Order" := CalculationOrder;
                TaxAreaLine.Modify(true);
            end;
            exit;
        end;
        TaxAreaLine.Init();
        TaxAreaLine."Tax Area" := TaxAreaCode;
        TaxAreaLine."Tax Jurisdiction Code" := JurisdictionCode;
        TaxAreaLine."Calculation Order" := CalculationOrder;
        TaxAreaLine.Insert(true);
    end;

    procedure GetTaxRateForGroup(TaxGroupCode: Code[20]; TaxableRate: Decimal): Decimal
    begin
        if TaxGroupCode = 'TAXABLE' then
            exit(TaxableRate);
        exit(0);
    end;

    procedure EnsureTaxDetail(JurisdictionCode: Text; TaxGroupCode: Code[20]; TaxRate: Decimal; EffectiveDate: Date)
    var
        TaxDetail: Record "Tax Detail";
        ActiveTaxDetail: Record "Tax Detail";
    begin
        if JurisdictionCode = '' then
            exit;
        if TaxDetail.Get(JurisdictionCode, TaxGroupCode, TaxDetail."Tax Type"::"Sales and Use Tax", EffectiveDate) then begin
            if (TaxDetail."Tax Below Maximum" <> TaxRate) or (TaxDetail."Maximum Amount/Qty." <> 0) then begin
                TaxDetail.Validate("Maximum Amount/Qty.", 0);
                TaxDetail.Validate("Tax Below Maximum", TaxRate);
                TaxDetail.Validate("Tax Above Maximum", 0);
                TaxDetail.Modify(true);
            end;
            exit;
        end;

        ActiveTaxDetail.SetRange("Tax Jurisdiction Code", JurisdictionCode);
        ActiveTaxDetail.SetRange("Tax Group Code", TaxGroupCode);
        ActiveTaxDetail.SetRange("Tax Type", ActiveTaxDetail."Tax Type"::"Sales and Use Tax");
        ActiveTaxDetail.SetFilter("Effective Date", '<=%1', EffectiveDate);
        if ActiveTaxDetail.FindLast() then
            if (ActiveTaxDetail."Maximum Amount/Qty." = 0) and (ActiveTaxDetail."Tax Below Maximum" = TaxRate) then
                exit;

        TaxDetail.Init();
        TaxDetail."Tax Jurisdiction Code" := JurisdictionCode;
        TaxDetail."Tax Group Code" := TaxGroupCode;
        TaxDetail."Tax Type" := TaxDetail."Tax Type"::"Sales and Use Tax";
        TaxDetail."Effective Date" := EffectiveDate;
        TaxDetail."Maximum Amount/Qty." := 0;
        TaxDetail."Tax Below Maximum" := TaxRate;
        TaxDetail."Tax Above Maximum" := 0;
        TaxDetail.Insert(true);
    end;

    procedure IsSupportedTaxGroup(TaxGroupCode: Code[20]): Boolean
    begin
        exit(TaxGroupCode in ['TAXABLE', 'RES', 'NTS', 'GOV', 'NP', 'OOS']);
    end;

    procedure EnsureTaxGroup(TaxGroupCode: Code[20]; Description: Text[100])
    var
        TaxGroup: Record "Tax Group";
    begin
        if not TaxGroup.Get(TaxGroupCode) then begin
            TaxGroup.Init();
            TaxGroup.Code := TaxGroupCode;
            if Description <> '' then
                TaxGroup.Description := Description
            else
                TaxGroup.Description := TaxGroupCode;
            TaxGroup.Insert(true);
        end else
            if (Description <> '') and (TaxGroup.Description <> Description) then begin
                TaxGroup.Description := Description;
                TaxGroup.Modify(true);
            end;
    end;

    procedure CheckTaxDifference(CalculatedTax: Decimal; SourceTax: Decimal; CurrencyCode: Code[10]; PricesIncludingTax: Boolean)
    var
        TaxAmountLine: Record "Sales Tax Amount Line" temporary;
        SalesSetup: Record "Sales & Receivables Setup";
    begin
        SalesSetup.Get();
        // Validation only. Never save a tax difference or alter BC-calculated tax.
        TaxAmountLine."Tax Difference" := SourceTax - CalculatedTax;
        TaxAmountLine.CheckTaxDifference(CurrencyCode, SalesSetup."Allow VAT Difference", PricesIncludingTax);
    end;

    local procedure CheckLength(Value: Text; Maximum: Integer; Purpose: Text)
    begin
        if StrLen(Value) > Maximum then
            Error('%1 exceeds BC field length %2: %3.', Purpose, Maximum, Value);
    end;
}
