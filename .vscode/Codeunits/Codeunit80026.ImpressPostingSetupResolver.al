codeunit 80026 "Impress Posting Setup Resolver"
{
    [CommitBehavior(CommitBehavior::Error)]
    procedure ResolveCustomerPostingGroup(ReceivablesAccount: Text; Context: Text): Code[20]
    var
        Group: Record "Customer Posting Group";
        RequiredAccount: Code[20];
        Highest: Integer;
        Sequence: Integer;
        ResolvedCode: Code[20];
    begin
        RequiredAccount := ValidateAccount(ReceivablesAccount, 'Receivables Account', Context);
        LockProfiles();
        Group.LockTable();
        Group.SetFilter(Code, 'IMC*');
        if Group.FindSet() then
            repeat
                Sequence := ProfileSequence(Group.Code, 'IMC');
                if Sequence > 0 then begin
                    if Group."Receivables Account" = RequiredAccount then
                        exit(Group.Code);
                    if Sequence > Highest then
                        Highest := Sequence;
                end;
            until Group.Next() = 0;
        ResolvedCode := NextCode('IMC', Highest, Context);
        Group.Init();
        Group.Code := ResolvedCode;
        Group.Description := ResolvedCode;
        Group.Validate("Receivables Account", RequiredAccount);
        Group.Insert(true);
        exit(ResolvedCode);
    end;

    procedure EnsureCustomerPostingGroupAlternative(CurrentGroup: Code[20]; TargetGroup: Code[20])
    var
        Alternative: Record "Alt. Customer Posting Group";
        Group: Record "Customer Posting Group";
    begin
        if (CurrentGroup = '') or (CurrentGroup = TargetGroup) then
            exit;
        Require(ProfileSequence(TargetGroup, 'IMC') > 0, 'Customer posting group change', 'IMC001..IMC999 target', TargetGroup);
        Group.Get(CurrentGroup);
        Group.Get(TargetGroup);
        Alternative.LockTable();
        if Alternative.Get(CurrentGroup, TargetGroup) then
            exit;
        Alternative.Init();
        Alternative.Validate("Customer Posting Group", CurrentGroup);
        Alternative.Validate("Alt. Customer Posting Group", TargetGroup);
        Alternative.Insert(true);
    end;

    procedure ValidateCustomerProfile(GroupCode: Code[20]; ReceivablesAccount: Text; Context: Text)
    var
        Group: Record "Customer Posting Group";
        RequiredAccount: Code[20];
    begin
        RequiredAccount := ValidateAccount(ReceivablesAccount, 'Receivables Account', Context);
        Require(ProfileSequence(GroupCode, 'IMC') > 0, Context, 'IMC001..IMC999 Customer Posting Group', GroupCode);
        Require(Group.Get(GroupCode), Context, 'existing Customer Posting Group', GroupCode);
        Require(Group."Receivables Account" = RequiredAccount, Context, 'Receivables Account ' + RequiredAccount, Group."Receivables Account");
    end;

    // Requirements contain only the fields/locations needed by the caller.
    // General account keys are standard General Posting Setup field numbers.
    [CommitBehavior(CommitBehavior::Error)]
    procedure ResolveGeneralPostingSetup(GenBusCode: Code[20]; Requirements: Dictionary of [Integer, Code[20]]; Context: Text): Code[20]
    var
        Group: Record "Gen. Product Posting Group";
        Setup: Record "General Posting Setup";
        SetupRef: RecordRef;
        AccountField: FieldRef;
        FieldNo: Integer;
        Highest: Integer;
        Sequence: Integer;
        ResolvedCode: Code[20];
    begin
        ValidateGeneralRequirements(GenBusCode, Requirements, Context);
        ResolvedCode := FindGeneralMatch(GenBusCode, Requirements);
        LockProfiles();
        Group.LockTable();
        Setup.LockTable();
        // Recheck even when the optimistic search found a profile.
        ResolvedCode := FindGeneralMatch(GenBusCode, Requirements);
        if ResolvedCode <> '' then begin
            EnsureGeneralSetupUnblocked(GenBusCode, ResolvedCode);
            exit(ResolvedCode);
        end;
        ResolvedCode := ExtendCompatibleGeneralSetup(GenBusCode, Requirements);
        if ResolvedCode <> '' then
            exit(ResolvedCode);
        Group.SetFilter(Code, 'IMP*');
        if Group.FindSet() then
            repeat
                Sequence := ProfileSequence(Group.Code, 'IMP');
                if Sequence > Highest then
                    Highest := Sequence;
            until Group.Next() = 0;
        ResolvedCode := NextCode('IMP', Highest, Context);
        Require(not Group.Get(ResolvedCode), Context, 'unused IMP code', ResolvedCode);
        Group.Init();
        Group.Code := ResolvedCode;
        Group.Description := ResolvedCode;
        Group.Insert(true);
        Setup.Init();
        Setup.Validate("Gen. Bus. Posting Group", GenBusCode);
        Setup.Validate("Gen. Prod. Posting Group", ResolvedCode);
        SetupRef.GetTable(Setup);
        foreach FieldNo in Requirements.Keys() do begin
            AccountField := SetupRef.Field(FieldNo);
            AccountField.Validate(Requirements.Get(FieldNo));
        end;
        SetupRef.SetTable(Setup);
        Setup.Insert(true);
        exit(ResolvedCode);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure ResolveInventoryPostingGroup(Requirements: Dictionary of [Code[10], Code[20]]; Context: Text): Code[20]
    var
        InterimRequirements: Dictionary of [Code[10], Code[20]];
    begin
        exit(ResolveInventoryPostingGroup(Requirements, InterimRequirements, Context));
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure ResolveInventoryPostingGroup(Requirements: Dictionary of [Code[10], Code[20]]; InterimRequirements: Dictionary of [Code[10], Code[20]]; Context: Text): Code[20]
    var
        Group: Record "Inventory Posting Group";
        Setup: Record "Inventory Posting Setup";
        LocationCode: Code[10];
        Highest: Integer;
        Sequence: Integer;
        ResolvedCode: Code[20];
    begin
        ValidateInventoryRequirements(Requirements, Context);
        ValidateInterimRequirements(Requirements, InterimRequirements, Context);
        ResolvedCode := FindInventoryMatch(Requirements, InterimRequirements);
        LockProfiles();
        Group.LockTable();
        Setup.LockTable();
        ResolvedCode := FindInventoryMatch(Requirements, InterimRequirements);
        if ResolvedCode <> '' then
            exit(ResolvedCode);
        Group.SetFilter(Code, 'IMI*');
        if Group.FindSet() then
            repeat
                Sequence := ProfileSequence(Group.Code, 'IMI');
                if Sequence > Highest then
                    Highest := Sequence;
            until Group.Next() = 0;
        ResolvedCode := NextCode('IMI', Highest, Context);
        Require(not Group.Get(ResolvedCode), Context, 'unused IMI code', ResolvedCode);
        Group.Init();
        Group.Code := ResolvedCode;
        Group.Description := ResolvedCode;
        Group.Insert(true);
        foreach LocationCode in Requirements.Keys() do begin
            Setup.Init();
            Setup.Validate("Location Code", LocationCode);
            Setup.Validate("Invt. Posting Group Code", ResolvedCode);
            Setup.Validate("Inventory Account", Requirements.Get(LocationCode));
            if InterimRequirements.ContainsKey(LocationCode) then
                Setup.Validate("Inventory Account (Interim)", InterimRequirements.Get(LocationCode));
            Setup.Insert(true);
        end;
        exit(ResolvedCode);
    end;

    procedure ValidateGeneralRequirements(GenBusCode: Code[20]; Requirements: Dictionary of [Integer, Code[20]]; Context: Text)
    var
        GenBus: Record "Gen. Business Posting Group";
        Setup: Record "General Posting Setup";
        SetupRef: RecordRef;
        AccountField: FieldRef;
        FieldNo: Integer;
        AccountCode: Code[20];
    begin
        Require(GenBusCode <> '', Context, 'configured Gen. Bus. Posting Group (Inv.)', 'blank');
        Require(GenBus.Get(GenBusCode), Context, 'existing Gen. Bus. Posting Group (Inv.)', GenBusCode + ' is missing');
        Require(Requirements.Count() > 0, Context, 'nonempty General Posting Setup account signature', 'empty');
        SetupRef.GetTable(Setup);
        foreach FieldNo in Requirements.Keys() do begin
            Require(SetupRef.FieldExist(FieldNo), Context, 'General Posting Setup account field', Format(FieldNo));
            AccountField := SetupRef.Field(FieldNo);
            Require((AccountField.Type = FieldType::Code) and (AccountField.Relation = Database::"G/L Account"),
                Context, 'G/L Account field in General Posting Setup', AccountField.Name);
            AccountCode := ValidateAccount(Requirements.Get(FieldNo), AccountField.Name, Context);
        end;
    end;

    procedure ValidateInventoryRequirements(Requirements: Dictionary of [Code[10], Code[20]]; Context: Text)
    var
        Location: Record Location;
        LocationCode: Code[10];
        AccountCode: Code[20];
    begin
        Require(Requirements.Count() > 0, Context, 'nonempty Location + Inventory Account requirements', 'empty');
        foreach LocationCode in Requirements.Keys() do begin
            Require(LocationCode <> '', Context, 'nonblank BC Location Code', 'blank');
            Require(Location.Get(LocationCode), Context, 'existing BC location', LocationCode + ' is missing');
            AccountCode := ValidateAccount(Requirements.Get(LocationCode), 'Inventory Account for location ' + LocationCode, Context);
        end;
    end;

    procedure ValidateAccount(AccountNo: Text; Purpose: Text; Context: Text): Code[20]
    var
        Account: Record "G/L Account";
    begin
        Require(AccountNo <> '', Context, Purpose + ' is required', 'blank');
        Require(StrLen(AccountNo) <= MaxStrLen(Account."No."), Context, Purpose + ' within BC account length', AccountNo);
        Require(Account.Get(AccountNo), Context, Purpose + ' exists', AccountNo + ' is missing');
        Require(Account."Account Type" = Account."Account Type"::Posting, Context, Purpose + ' Account Type = Posting', AccountNo + ' / ' + Format(Account."Account Type"));
        Require(not Account.Blocked, Context, Purpose + ' Blocked = false', AccountNo + ' / ' + Format(Account.Blocked));
        exit(Account."No.");
    end;

    procedure ValidateGeneralProfile(GenBusCode: Code[20]; GenProdCode: Code[20]; Requirements: Dictionary of [Integer, Code[20]]; IntegrationOnly: Boolean; Context: Text)
    var
        Group: Record "Gen. Product Posting Group";
        Setup: Record "General Posting Setup";
        SetupRef: RecordRef;
        AccountField: FieldRef;
        FieldNo: Integer;
    begin
        if IntegrationOnly then
            Require(ProfileSequence(GenProdCode, 'IMP') > 0, Context, 'IMP001..IMP999 profile on journal; recreate legacy preparations', GenProdCode);
        Require(Group.Get(GenProdCode), Context, 'existing Gen. Prod. Posting Group', GenProdCode);
        Setup.LockTable();
        Require(Setup.Get(GenBusCode, GenProdCode), Context, 'General Posting Setup ' + GenBusCode + '/' + GenProdCode, 'missing');
        SetupRef.GetTable(Setup);
        foreach FieldNo in Requirements.Keys() do begin
            AccountField := SetupRef.Field(FieldNo);
            Require(Format(AccountField.Value) = Requirements.Get(FieldNo), Context,
                GenBusCode + '/' + GenProdCode + ' ' + AccountField.Name + ' = ' + Requirements.Get(FieldNo), Format(AccountField.Value));
        end;
    end;

    procedure ValidateInventoryProfile(GroupCode: Code[20]; Requirements: Dictionary of [Code[10], Code[20]]; IntegrationOnly: Boolean; Context: Text)
    var
        InterimRequirements: Dictionary of [Code[10], Code[20]];
    begin
        ValidateInventoryProfile(GroupCode, Requirements, InterimRequirements, IntegrationOnly, Context);
    end;

    procedure ValidateInventoryProfile(GroupCode: Code[20]; Requirements: Dictionary of [Code[10], Code[20]]; InterimRequirements: Dictionary of [Code[10], Code[20]]; IntegrationOnly: Boolean; Context: Text)
    var
        Group: Record "Inventory Posting Group";
        Setup: Record "Inventory Posting Setup";
        LocationCode: Code[10];
    begin
        if IntegrationOnly then
            Require(ProfileSequence(GroupCode, 'IMI') > 0, Context, 'IMI001..IMI999 profile on journal; recreate legacy preparations', GroupCode);
        Require(Group.Get(GroupCode), Context, 'existing Inventory Posting Group', GroupCode);
        Setup.LockTable();
        foreach LocationCode in Requirements.Keys() do begin
            Require(Setup.Get(LocationCode, GroupCode), Context, 'Inventory Posting Setup ' + LocationCode + '/' + GroupCode, 'missing');
            Require(Setup."Inventory Account" = Requirements.Get(LocationCode), Context,
                LocationCode + '/' + GroupCode + ' Inventory Account = ' + Requirements.Get(LocationCode), Setup."Inventory Account");
            if InterimRequirements.ContainsKey(LocationCode) then
                Require(Setup."Inventory Account (Interim)" = InterimRequirements.Get(LocationCode), Context,
                    LocationCode + '/' + GroupCode + ' Inventory Account (Interim) = ' + InterimRequirements.Get(LocationCode), Setup."Inventory Account (Interim)");
        end;
    end;

    local procedure FindGeneralMatch(GenBusCode: Code[20]; Requirements: Dictionary of [Integer, Code[20]]): Code[20]
    var
        Setup: Record "General Posting Setup";
        Group: Record "Gen. Product Posting Group";
        SetupRef: RecordRef;
        AccountField: FieldRef;
        FieldNo: Integer;
        Matches: Boolean;
    begin
        Setup.SetRange("Gen. Bus. Posting Group", GenBusCode);
        Setup.SetFilter("Gen. Prod. Posting Group", 'IMP*');
        if Setup.FindSet() then
            repeat
                if (ProfileSequence(Setup."Gen. Prod. Posting Group", 'IMP') > 0) and Group.Get(Setup."Gen. Prod. Posting Group") then begin
                    Matches := true;
                    SetupRef.GetTable(Setup);
                    foreach FieldNo in Requirements.Keys() do begin
                        AccountField := SetupRef.Field(FieldNo);
                        Matches := Matches and (Format(AccountField.Value) = Requirements.Get(FieldNo));
                    end;
                    if Matches then
                        exit(Setup."Gen. Prod. Posting Group");
                end;
            until Setup.Next() = 0;
        exit('');
    end;

    local procedure ExtendCompatibleGeneralSetup(GenBusCode: Code[20]; Requirements: Dictionary of [Integer, Code[20]]): Code[20]
    var
        Setup: Record "General Posting Setup";
        Group: Record "Gen. Product Posting Group";
        SetupRef: RecordRef;
        AccountField: FieldRef;
        FieldNo: Integer;
        ExistingAccount: Text;
        Compatible: Boolean;
    begin
        // Caller holds the profile and setup locks. Check the entire signature
        // before filling any blanks; never overwrite a conflicting account.
        Setup.SetRange("Gen. Bus. Posting Group", GenBusCode);
        Setup.SetFilter("Gen. Prod. Posting Group", 'IMP*');
        if Setup.FindSet(true) then
            repeat
                if (ProfileSequence(Setup."Gen. Prod. Posting Group", 'IMP') > 0) and Group.Get(Setup."Gen. Prod. Posting Group") then begin
                    Compatible := true;
                    SetupRef.GetTable(Setup);
                    foreach FieldNo in Requirements.Keys() do begin
                        AccountField := SetupRef.Field(FieldNo);
                        ExistingAccount := Format(AccountField.Value);
                        Compatible := Compatible and ((ExistingAccount = '') or (ExistingAccount = Requirements.Get(FieldNo)));
                    end;
                    if Compatible then begin
                        foreach FieldNo in Requirements.Keys() do begin
                            AccountField := SetupRef.Field(FieldNo);
                            if Format(AccountField.Value) = '' then
                                AccountField.Validate(Requirements.Get(FieldNo));
                        end;
                        SetupRef.SetTable(Setup);
                        Setup.Validate(Blocked, false);
                        Setup.Modify(true);
                        exit(Setup."Gen. Prod. Posting Group");
                    end;
                end;
            until Setup.Next() = 0;
        exit('');
    end;

    procedure PrepareInvoiceGeneralSetups(Order: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", Order."Document Type");
        SalesLine.SetRange("Document No.", Order."No.");
        if SalesLine.FindSet() then
            repeat
                if SalesLine.HasTypeToFillMandatoryFields() then begin
                    if (SalesLine."Qty. to Ship" <> 0) or (SalesLine."Qty. to Invoice" <> 0) then
                        Require(ProfileSequence(SalesLine."Gen. Prod. Posting Group", 'IMP') > 0,
                            StrSubstNo('Sales Order %1 line %2', Order."No.", SalesLine."Line No."),
                            'IMP001..IMP999 invoice posting profile', SalesLine."Gen. Prod. Posting Group");
                    // Standard Sales-Post checks blocked setups even for lines
                    // with zero quantities to ship/invoice. Do not change their accounts.
                    EnsureGeneralSetupUnblocked(SalesLine."Gen. Bus. Posting Group", SalesLine."Gen. Prod. Posting Group");
                end;
            until SalesLine.Next() = 0;
    end;

    local procedure EnsureGeneralSetupUnblocked(GenBusCode: Code[20]; GenProdCode: Code[20])
    var
        Setup: Record "General Posting Setup";
    begin
        Setup.LockTable();
        if Setup.Get(GenBusCode, GenProdCode) then
            if Setup.Blocked then begin
                Setup.Validate(Blocked, false);
                Setup.Modify(true);
            end;
    end;

    local procedure FindInventoryMatch(Requirements: Dictionary of [Code[10], Code[20]]; InterimRequirements: Dictionary of [Code[10], Code[20]]): Code[20]
    var
        Group: Record "Inventory Posting Group";
        Setup: Record "Inventory Posting Setup";
        LocationCode: Code[10];
        Matches: Boolean;
    begin
        Group.SetFilter(Code, 'IMI*');
        if Group.FindSet() then
            repeat
                if ProfileSequence(Group.Code, 'IMI') > 0 then begin
                    Matches := true;
                    foreach LocationCode in Requirements.Keys() do
                        if Setup.Get(LocationCode, Group.Code) then begin
                            Matches := Matches and (Setup."Inventory Account" = Requirements.Get(LocationCode));
                            if InterimRequirements.ContainsKey(LocationCode) then
                                Matches := Matches and (Setup."Inventory Account (Interim)" = InterimRequirements.Get(LocationCode));
                        end else
                            Matches := false;
                    if Matches then
                        exit(Group.Code);
                end;
            until Group.Next() = 0;
        exit('');
    end;

    local procedure ValidateInterimRequirements(Requirements: Dictionary of [Code[10], Code[20]]; InterimRequirements: Dictionary of [Code[10], Code[20]]; Context: Text)
    var
        LocationCode: Code[10];
        AccountCode: Code[20];
    begin
        foreach LocationCode in InterimRequirements.Keys() do begin
            Require(Requirements.ContainsKey(LocationCode), Context, 'Inventory Account requirement for interim location', LocationCode);
            AccountCode := ValidateAccount(InterimRequirements.Get(LocationCode), 'Inventory Account (Interim) for location ' + LocationCode, Context);
        end;
    end;

    local procedure LockProfiles()
    var
        ProfileLock: Record "Impress Posting Profile Lock";
    begin
        // One cross-source lock avoids equivalent-profile races even on initially empty tables.
        // IMP and IMI still derive their highest numbers independently from their own BC tables.
        ProfileLock.LockTable();
        if not ProfileLock.Get('SETUP') then begin
            ProfileLock.Code := 'SETUP';
            if not ProfileLock.Insert() then
                ProfileLock.Get('SETUP');
        end;
        ProfileLock.Revision += 1;
        ProfileLock.Modify();
    end;

    local procedure ProfileSequence(GroupCode: Code[20]; Prefix: Text[3]): Integer
    var
        Suffix: Text[3];
        Sequence: Integer;
    begin
        if (StrLen(GroupCode) <> 6) or (CopyStr(GroupCode, 1, 3) <> Prefix) then
            exit(0);
        Suffix := CopyStr(GroupCode, 4, 3);
        if DelChr(Suffix, '=', '0123456789') <> '' then
            exit(0);
        if not Evaluate(Sequence, Suffix) then
            exit(0);
        exit(Sequence);
    end;

    local procedure NextCode(Prefix: Text[3]; Highest: Integer; Context: Text): Code[20]
    var
        NumberText: Text;
    begin
        Require(Highest < 999, Context, 'available ' + Prefix + '001..' + Prefix + '999 sequence', 'sequence exhausted');
        NumberText := Format(Highest + 1, 0, 9);
        exit(Prefix + PadStr('', 3 - StrLen(NumberText), '0') + NumberText);
    end;

    local procedure Require(Condition: Boolean; Context: Text; Expected: Text; Actual: Text)
    begin
        if not Condition then
            Error('%1. Posting setup: expected [%2]; actual [%3].', Context, Expected, Actual);
    end;
}
