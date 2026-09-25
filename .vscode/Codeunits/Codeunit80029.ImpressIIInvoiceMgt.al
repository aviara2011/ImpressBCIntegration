codeunit 80029 "Impress II Invoice Mgt."
{
    procedure ResolveInvoice(Transaction: Record "Impress Inv Trans Staging"; var Header: Record "Impress Sales Doc Hdr Staging")
    var
        Line: Record "Impress Sales Doc Line Staging";
    begin
        Transaction.TestField("Transaction Type", 'I');
        Transaction.TestField("Transaction Source", 'I');
        Line.SetRange("Source Database", Transaction."Source Database");
        Line.SetRange("Related Inventory Trans. ID", Transaction."Source Transaction ID");
        if Line.Count() <> 1 then
            Error('I/I %1/%2: expected exactly one Sales Document line linked by Related Inventory Transaction ID; found %3.',
                Transaction."Source Database", Transaction."Source Transaction ID", Line.Count());
        Line.FindFirst();
        Header.Get(Line."Sales Document Entry No.");
        Header.TestField("Source Database", Transaction."Source Database");
        if Transaction."Related Sales Doc. Entry No." <> 0 then
            Transaction.TestField("Related Sales Doc. Entry No.", Header."Entry No.");
    end;

    procedure ProcessTransaction(var Transaction: Record "Impress Inv Trans Staging")
    var
        Header: Record "Impress Sales Doc Hdr Staging";
    begin
        ResolveInvoice(Transaction, Header);
        ProcessDocument(Header);
        Transaction.Get(Transaction."Entry No.");
    end;

    procedure ProcessDocument(var Header: Record "Impress Sales Doc Hdr Staging")
    var
        Runner: Codeunit "Impress II Posting Runner";
        Failure: Text;
    begin
        // The Boolean runner owns the complete document transaction. No preparation
        // happens before this boundary; a failure rolls back the entire posting.
        Commit();
        ClearLastError();
        if not Runner.Run(Header) then begin
            Failure := GetLastErrorText();
            MarkDocumentError(Header, Failure);
            Commit();
            Error('I/I invoice %1 (%2) failed: %3', Header."Document No.", Header."Source Database", Failure);
        end;
        Header.Get(Header."Entry No.");
    end;

    procedure PreviewTransaction(Transaction: Record "Impress Inv Trans Staging")
    var
        Header: Record "Impress Sales Doc Hdr Staging";
    begin
        ResolveInvoice(Transaction, Header);
        PreviewDocument(Header);
    end;

    procedure PreviewDocument(Header: Record "Impress Sales Doc Hdr Staging")
    var
        Preview: Codeunit "Gen. Jnl.-Post Preview";
        Subscriber: Codeunit "Impress II Preview";
    begin
        // Standard preview must begin outside a write transaction. Its Boolean
        // runner includes setup/order creation, so all preview preparation rolls back.
        Commit();
        BindSubscription(Subscriber);
        Preview.Preview(Subscriber, Header);
        UnbindSubscription(Subscriber);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    procedure PostDocumentAtomic(var Header: Record "Impress Sales Doc Hdr Staging"; PreviewOnly: Boolean)
    var
        SourceLock: Record "Impress Posting Source Lock";
        OrderStaging: Record "Impress Sales Header Staging";
        Order: Record "Sales Header";
        Posted: Record "Sales Invoice Header";
        Scope: Codeunit "Impress II Posting Scope";
        LineLifecycle: Codeunit "Impress II Line Lifecycle";
        SalesPost: Codeunit "Sales-Post";
        Members: Dictionary of [BigInteger, Boolean];
        ExistingOrder: Boolean;
        PostingID: Guid;
    begin
        Header.Get(Header."Entry No.");
        if not (Header."Source Database" in ['ImpressTest', 'StickersTest']) then
            Error('Unsupported Source Database %1.', Header."Source Database");
        SourceLock.LockTable();
        if not SourceLock.Get(Header."Source Database") then begin
            SourceLock.Init();
            SourceLock."Source Database" := Header."Source Database";
            SourceLock.Insert();
        end;
        Header.LockTable();
        Header.Get(Header."Entry No.");
        Header.TestField("Source Database", SourceLock."Source Database");
        // Stable even if a later staging update was rolled back or its GUID cleared.
        PostingID := Header.SystemId;
        if not IsNullGuid(Header."Integration Posting ID") then
            Header.TestField("Integration Posting ID", PostingID);
        ResolvePostingDate(Header);
        ValidateDocument(Header, Members);
        Posted.SetRange("Integration Posting ID", PostingID);
        if not Posted.IsEmpty() then begin
            if PreviewOnly then
                Error('Invoice %1 already has posted evidence; use Process to reconcile it.', Header."Document No.");
            Reconcile(Header, PostingID);
            exit;
        end;
        ValidateNoUnreconciledEvidence(Header, PostingID);
        ValidateSequence(Header, Members);
        ExistingOrder := ResolveOrder(Header, OrderStaging, Order);
        if not ExistingOrder then begin
            Clear(OrderStaging);
            CreateOrder(Header, Order);
        end;
        Scope.Initialize(PostingID, Order."No.");
        BindSubscription(Scope);
        LineLifecycle.Initialize(Header, Order);
        BindSubscription(LineLifecycle);
        PrepareOrder(Header, OrderStaging, Order, PostingID, ExistingOrder);
        UnbindSubscription(LineLifecycle);
        SetProcessing(Header, PostingID);
        SalesPost.SetSuppressCommit(true);
        SalesPost.SetPreviewMode(PreviewOnly);
        Order.Ship := true;
        Order.Invoice := true;
        SalesPost.Run(Order); // Never Boolean Run inside the document transaction.
        UnbindSubscription(Scope);
        Reconcile(Header, PostingID);
        ClearRemainingOrderTags(Header."BC Sales Order No.", PostingID);
    end;

    procedure ResolvePostingDate(var Header: Record "Impress Sales Doc Hdr Staging")
    var
        Line: Record "Impress Sales Doc Line Staging";
        Transaction: Record "Impress Inv Trans Staging";
        PostingDate: Date;
    begin
        if Header."G/L Post Date" <> 0D then
            exit;
        Header.TestField("Source Database");
        SetDocumentLines(Line, Header);
        Line.SetFilter("Related Inventory Trans. ID", '<>0');
        if Line.FindSet() then
            repeat
                Line.TestField("Source Database", Header."Source Database");
                GetTransaction(Header, Line, Transaction);
                Transaction.TestField("G/L Date");
                if (PostingDate <> 0D) and (PostingDate <> Transaction."G/L Date") then
                    Error('Invoice %1: linked inventory transactions have different G/L dates (%2 and %3). A single posting date is required.', Header."Document No.", PostingDate, Transaction."G/L Date");
                PostingDate := Transaction."G/L Date";
            until Line.Next() = 0;
        if PostingDate = 0D then
            Error('Invoice %1: cannot derive G/L Post Date because no linked inventory transactions were found.', Header."Document No.");
        // PrepareOrder persists the date inside the atomic posting transaction.
        // Standard preview rolls all preparation back.
        Header."G/L Post Date" := PostingDate;
    end;

    local procedure ValidateDocument(Header: Record "Impress Sales Doc Hdr Staging"; var Members: Dictionary of [BigInteger, Boolean])
    var
        Line: Record "Impress Sales Doc Line Staging";
        OtherLine: Record "Impress Sales Doc Line Staging";
        Transaction: Record "Impress Inv Trans Staging";
        Customer: Record Customer;
        Item: Record Item;
        Variant: Record "Item Variant";
        Location: Record Location;
        Resolver: Codeunit "Impress Posting Setup Resolver";
        FirstID: BigInteger;
        LastID: BigInteger;
        NetAmount: Decimal;
        Matcher: Codeunit "Impress Invoice Line Match";
        OrderMgt: Codeunit "Impress Sales Order Mgt.";
        Charge: Record "Impress Sales Line Staging";
    begin
        if UpperCase(Header."Document Type") <> 'INVOICE' then
            Error('I/I Sales Document %1 must have Document Type Invoice.', Header."Document No.");
        Header.TestField("Document No.");
        Header.TestField("Has Inventory Impact", true);
        Header.TestField("Processing Phase", 1);
        Header.TestField("Invoice Date");
        Header.TestField("G/L Post Date");
        CheckTransport(Header."Transport Status");
        CheckLength(Header."Source Customer Code", MaxStrLen(Customer."No."), 'Source Customer Code');
        Header.TestField("Source Customer Code");
        Customer.Get(Header."Source Customer Code");
        Resolver.ValidateAccount(Header."A/R G/L Account", 'A/R G/L Account', Header."Document No.");
        Clear(Members);
        SetDocumentLines(Line, Header);
        if not Line.FindSet() then
            Error('Sales Document %1 has no lines.', Header."Document No.");
        repeat
            Line.TestField("Source Database", Header."Source Database");
            Line.TestField("Source Customer Code", Header."Source Customer Code");
            Line.TestField("Document No.", Header."Document No.");
            Line.TestField("Document Type", Header."Document Type");
            CheckTransport(Line."Transport Status");
            if Line.Quantity < 0 then
                Error('Invoice %1 line %2: negative invoice quantities require a credit memo.', Header."Document No.", Line."Entry No.");
            if (Line.Quantity = 0) and (Line.Amount <> 0) then
                Error('Invoice %1 line %2 has an amount but zero quantity.', Header."Document No.", Line."Entry No.");
            NetAmount += Line.Amount;
            if Line.Quantity <> 0 then
                Resolver.ValidateAccount(Line."Revenue G/L Account", 'Revenue G/L Account', Header."Document No.");
            if Matcher.IsItem(Line) then begin
                Item.Get(Line."BC Item No.");
                Item.TestField(Blocked, false);
                if Line."BC Variant Code" <> '' then
                    Variant.Get(Line."BC Item No.", Line."BC Variant Code");
                if Item.Type = Item.Type::Inventory then
                    Line.TestField("Related Inventory Trans. ID");
            end;
            if not Matcher.IsItem(Line) then begin
                Line.TestField("Related Inventory Trans. ID", 0);
                Charge.Init();
                Charge."Source Code" := Matcher.TargetNo(Line);
                Charge.Description := CopyStr(Line."Source Description", 1, MaxStrLen(Charge.Description));
                OrderMgt.EnsureChargeResource(Charge);
            end;
            if Line."Related Inventory Trans. ID" <> 0 then begin
                if Members.ContainsKey(Line."Related Inventory Trans. ID") then
                    Error('Invoice %1 repeats Related Inventory Transaction ID %2.', Header."Document No.", Line."Related Inventory Trans. ID");
                GetTransaction(Header, Line, Transaction);
                Line.TestField("BC Item No.");
                Item.Get(Line."BC Item No.");
                Item.TestField(Type, Item.Type::Inventory);
                Transaction.TestField("BC Location Code");
                Location.Get(Transaction."BC Location Code");
                if (Transaction.Quantity >= 0) or (Line.Quantity <> Abs(Transaction.Quantity)) then
                    Error('Invoice %1 line %2: Sales Document quantity %3 does not match negative I/I quantity %4.', Header."Document No.", Line."Entry No.", Line.Quantity, Transaction.Quantity);
                Transaction.TestField("BC Item No.", Line."BC Item No.");
                Transaction.TestField("BC Variant Code", Line."BC Variant Code");
                Transaction.TestField("G/L Date", Header."G/L Post Date");
                Transaction.TestField("Source Order No.", Header."Document No.");
                if Transaction."Related Sales Doc. Entry No." <> 0 then
                    Transaction.TestField("Related Sales Doc. Entry No.", Header."Entry No.");
                CheckTransport(Transaction."Transport Status");
                Resolver.ValidateAccount(Line."Inventory G/L Account", 'Inventory G/L Account', Header."Document No.");
                Resolver.ValidateAccount(Line."COGS G/L Account", 'COGS G/L Account', Header."Document No.");
                if Transaction."Source Inventory G/L Account" <> '' then
                    Transaction.TestField("Source Inventory G/L Account", Line."Inventory G/L Account");
                OtherLine.SetRange("Source Database", Header."Source Database");
                OtherLine.SetRange("Related Inventory Trans. ID", Transaction."Source Transaction ID");
                if OtherLine.Count() <> 1 then
                    Error('I/I %1 is linked to more than one invoice line.', Transaction."Source Transaction ID");
                Members.Add(Transaction."Source Transaction ID", true);
                if (FirstID = 0) or (Transaction."Source Transaction ID" < FirstID) then
                    FirstID := Transaction."Source Transaction ID";
                if Transaction."Source Transaction ID" > LastID then
                    LastID := Transaction."Source Transaction ID";
            end;
        until Line.Next() = 0;
        Header.TestField("Inventory Transaction Count", Members.Count());
        if Members.Count() = 0 then
            Error('Invoice %1 has no linked I/I transactions.', Header."Document No.");
        Header.TestField("First Inventory Transaction ID", FirstID);
        Header.TestField("Last Inventory Transaction ID", LastID);
        if Abs(NetAmount + Header."Tax Total" - Header."Invoice Total") > 0.01 then
            Error('Invoice %1 is incomplete: sum of staged line amounts %2 plus tax %3 differs from invoice total %4. Stage net invoice line amounts; header discounts are not guessed.',
                Header."Document No.", NetAmount, Header."Tax Total", Header."Invoice Total");
        // Catch I/I rows claiming this invoice that are absent from its line links.
        Transaction.Reset();
        Transaction.SetRange("Source Database", Header."Source Database");
        Transaction.SetRange("Transaction Type", 'I');
        Transaction.SetRange("Transaction Source", 'I');
        Transaction.SetRange("Source Order No.", Header."Document No.");
        if Transaction.FindSet() then
            repeat
                if not Members.ContainsKey(Transaction."Source Transaction ID") then
                    Error('Invoice %1 is missing a Sales Document line for I/I %2.', Header."Document No.", Transaction."Source Transaction ID");
            until Transaction.Next() = 0;
    end;

    local procedure ValidateSequence(Header: Record "Impress Sales Doc Hdr Staging"; Members: Dictionary of [BigInteger, Boolean])
    var
        Earlier: Record "Impress Inv Trans Staging";
    begin
        Earlier.SetCurrentKey("Source Database", "Source Transaction ID");
        Earlier.SetRange("Source Database", Header."Source Database");
        Earlier.SetFilter("Source Transaction ID", '<=%1', Header."Last Inventory Transaction ID");
        Earlier.SetFilter("Processing Status", '<>%1', Earlier."Processing Status"::Processed);
        if Earlier.FindSet() then
            repeat
                if not Members.ContainsKey(Earlier."Source Transaction ID") then
                    Error('Invoice %1: source sequence requires earlier transaction %2 (%3) to finish first.', Header."Document No.", Earlier."Source Transaction ID", Earlier."Processing Status");
            until Earlier.Next() = 0;
    end;

    local procedure ValidateNoUnreconciledEvidence(Header: Record "Impress Sales Doc Hdr Staging"; PostingID: Guid)
    var
        Shipment: Record "Sales Shipment Header";
        Invoice: Record "Sales Invoice Header";
        Tracking: Codeunit "Impress Posting Tracking";
    begin
        Shipment.SetRange("Integration Posting ID", PostingID);
        if not Shipment.IsEmpty() or Tracking.HasPostedEvidence(PostingID) then
            Error('Invoice %1 has partial posted evidence for GUID %2. Reconcile it before posting; fallback is prohibited.', Header."Document No.", PostingID);
        if (Header."Processing Status" = Header."Processing Status"::Processed) or (Header."BC Document No." <> '') or not IsNullGuid(Header."BC System ID") then
            Error('Invoice %1 has posted staging references but no matching posted invoice GUID. Reconciliation is required.', Header."Document No.");
        // A document number is only a conservative legacy duplicate warning, never
        // the technical key used to adopt/reconcile someone else's posted invoice.
        Invoice.SetRange("External Document No.", Header."Document No.");
        Invoice.SetRange("Sell-to Customer No.", Header."Source Customer Code");
        if not Invoice.IsEmpty() then
            Error('Invoice %1 appears already posted without this integration GUID. Reconcile existing BC evidence before fallback.', Header."Document No.");
    end;

    local procedure ResolveOrder(Header: Record "Impress Sales Doc Hdr Staging"; var Staging: Record "Impress Sales Header Staging"; var Order: Record "Sales Header"): Boolean
    var
        Posted: Record "Sales Invoice Header";
        Shipment: Record "Sales Shipment Header";
    begin
        if Header."BC Sales Order No." <> '' then begin
            if not Order.Get(Order."Document Type"::Order, Header."BC Sales Order No.") then begin
                Posted.SetRange("Order No.", Header."BC Sales Order No.");
                Shipment.SetRange("Order No.", Header."BC Sales Order No.");
                if not Posted.IsEmpty() or not Shipment.IsEmpty() then
                    Error('Invoice %1 has a missing prepared order %2 with posted evidence; reconciliation is required.', Header."Document No.", Header."BC Sales Order No.");
                exit(false);
            end;
            Order.TestField("Sell-to Customer No.", Header."Source Customer Code");
            Order.TestField("Impress Source Database", Header."Source Database");
            Order.TestField("Integration Posting ID", Header.SystemId);
            Staging.SetRange("Source Database", Header."Source Database");
            Staging.SetRange("Sales Order No.", Header."Source Sales Order No.");
            if Staging.Count() > 1 then
                Error('Invoice %1 has ambiguous originating order staging.', Header."Document No.");
            if Staging.FindFirst() then
                Staging.TestField("BC Document No.", Order."No.");
            exit(true);
        end;
        if Header."Source Sales Order No." = '' then
            exit(false);
        Staging.SetRange("Source Database", Header."Source Database");
        Staging.SetRange("Sales Order No.", Header."Source Sales Order No.");
        if Staging.Count() > 1 then
            Error('Invoice %1: Source Sales Order No. %2 resolves to multiple staging headers.', Header."Document No.", Header."Source Sales Order No.");
        if not Staging.FindFirst() then
            exit(false);
        if Staging."BC Document No." = '' then
            exit(false);
        if Order.Get(Order."Document Type"::Order, Staging."BC Document No.") then begin
            if not IsNullGuid(Staging."BC System ID") then
                Order.TestField(SystemId, Staging."BC System ID");
            Order.TestField("Sell-to Customer No.", Header."Source Customer Code");
            Order.TestField("Impress Source Database", Header."Source Database");
            Order.TestField("Impress Source Sales Order ID", Staging."Source Sales Order ID");
            exit(true);
        end;
        // An originating order may have been fully posted and removed. The
        // current invoice's duplicate/partial evidence is checked before this.
        exit(false);
    end;

    local procedure CreateOrder(Header: Record "Impress Sales Doc Hdr Staging"; var Order: Record "Sales Header")
    begin
        Clear(Order);
        Order.Init();
        Order.SetHideValidationDialog(true);
        Order."Document Type" := Order."Document Type"::Order;
        Order.Insert(true);
        Order.Validate("Sell-to Customer No.", Header."Source Customer Code");
        Order.Validate("Your Reference", '');
        Order.Modify(true);
    end;

    local procedure PrepareOrder(var Header: Record "Impress Sales Doc Hdr Staging"; OrderStaging: Record "Impress Sales Header Staging"; var Order: Record "Sales Header"; PostingID: Guid; ExistingOrder: Boolean)
    var
        Line: Record "Impress Sales Doc Line Staging";
        SalesLine: Record "Sales Line";
        Matcher: Codeunit "Impress Invoice Line Match";
        ExistingLine: Boolean;
        Defaults: Record "Impress Defaults";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        Release: Codeunit "Release Sales Document";
        UsedLines: Dictionary of [Integer, Boolean];
        LineNo: Integer;
        DimensionSetID: Integer;
        CustomerPostingGroup: Code[20];
    begin
        Defaults.Get();
        Defaults.TestField("Gen. Bus. Posting Group (Inv.)");
        Order.SetHideValidationDialog(true);
        Order.TestField("On Hold", '');
        if Order.Status = Order.Status::Released then
            Release.Reopen(Order);
        Order.TestField(Status, Order.Status::Open);
        CheckLength(Header."Document No.", MaxStrLen(Order."External Document No."), 'Impress Invoice No.');
        Order.Validate("External Document No.", Header."Document No.");
        if ExistingOrder and (OrderStaging."Customer PO No." <> '') then begin
            CheckLength(OrderStaging."Customer PO No.", MaxStrLen(Order."Your Reference"), 'Customer PO No.');
            Order.Validate("Your Reference", OrderStaging."Customer PO No.");
        end;
        Order.Validate("Posting Date", Header."G/L Post Date");
        Order.Validate("Document Date", Header."Invoice Date");
        if Header."Due Date" <> 0D then
            Order.Validate("Due Date", Header."Due Date");
        Order.Validate("Gen. Bus. Posting Group", Defaults."Gen. Bus. Posting Group (Inv.)");
        CustomerPostingGroup := Resolver.ResolveCustomerPostingGroup(Header."A/R G/L Account", Header."Document No.");
        EnableCustomerMultiplePostingGroups(Order, CustomerPostingGroup);
        Order.Validate("Customer Posting Group", CustomerPostingGroup);
        Order.Validate("Prices Including VAT", false);
        EnsureInvoiceTaxSetup(Header);
        CheckLength(Header."Tax Area Code", MaxStrLen(Order."Tax Area Code"), 'Tax Area Code');
        Order.Validate("Tax Area Code", Header."Tax Area Code");
        if Header."Tax Total" <> 0 then
            Order.TestField("Tax Area Code");
        Order.Validate("Tax Liable", true);
        ValidateTaxAccounts(Header);
        DimensionSetID := Order."Dimension Set ID";
        ApplyCategory(Header, DimensionSetID);
        Order.Validate("Dimension Set ID", DimensionSetID);
        Order."Impress Source Database" := Header."Source Database";
        Order."Integration Posting ID" := PostingID;
        Order.Modify(true);
        Header."BC Sales Order No." := Order."No.";
        Header."Integration Posting ID" := PostingID;
        Header.Modify(true);
        SalesLine.SetRange("Document Type", Order."Document Type");
        SalesLine.SetRange("Document No.", Order."No.");
        if SalesLine.FindSet(true) then
            repeat
                SalesLine.SetHideValidationDialog(true);
                SalesLine.Validate("Qty. to Ship", 0);
                SalesLine.Validate("Qty. to Invoice", 0);
                Clear(SalesLine."Integration Posting ID");
                // Preserve invoice correlation until successful reconciliation.
                SalesLine.Modify(true);
                LineNo := SalesLine."Line No.";
            until SalesLine.Next() = 0;
        SetDocumentLines(Line, Header);
        Line.FindSet(true);
        repeat
            if ExistingOrder then
                ExistingLine := Matcher.Resolve(Header, Line, OrderStaging, Order, SalesLine)
            else
                ExistingLine := Matcher.ResolveForNewOrder(Header, Line, Order, SalesLine);
            if UsedLines.ContainsKey(SalesLine."Line No.") then
                Error('Invoice %1 maps multiple invoice lines to BC Line No. %2.', Header."Document No.", SalesLine."Line No.");
            UsedLines.Add(SalesLine."Line No.", true);
            PrepareLine(Header, Line, SalesLine, Order, ExistingLine);
            Line."BC Sales Line No." := SalesLine."Line No.";
            Line."BC Line System ID" := SalesLine.SystemId;
            Line.Modify(true);
        until Line.Next() = 0;
        Resolver.PrepareInvoiceGeneralSetups(Order);
    end;

    local procedure EnableCustomerMultiplePostingGroups(Order: Record "Sales Header"; TargetGroup: Code[20])
    var
        BillToCustomer: Record Customer;
        Resolver: Codeunit "Impress Posting Setup Resolver";
    begin
        Order.TestField("Bill-to Customer No.");
        BillToCustomer.Get(Order."Bill-to Customer No.");
        Resolver.EnsureCustomerPostingGroupAlternative(Order."Customer Posting Group", TargetGroup);
        Resolver.EnsureCustomerPostingGroupAlternative(BillToCustomer."Customer Posting Group", TargetGroup);
        if BillToCustomer."Allow Multiple Posting Groups" then
            exit;
        BillToCustomer.Validate("Allow Multiple Posting Groups", true);
        BillToCustomer.Modify(true);
    end;

    local procedure PrepareLine(Header: Record "Impress Sales Doc Hdr Staging"; Line: Record "Impress Sales Doc Line Staging"; var SalesLine: Record "Sales Line"; Order: Record "Sales Header"; Existing: Boolean)
    var
        Transaction: Record "Impress Inv Trans Staging";
        Setup: Record "General Posting Setup";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        GeneralRequirements: Dictionary of [Integer, Code[20]];
        InventoryRequirements: Dictionary of [Code[10], Code[20]];
        DimensionSetID: Integer;
        FullLineAmount: Decimal;
        Matcher: Codeunit "Impress Invoice Line Match";
        CategoryHeader: Record "Impress Sales Doc Hdr Staging";
    begin
        SalesLine.SetHideValidationDialog(true);
        if Line.Quantity = 0 then begin
            if not Existing then
                SalesLine.Validate(Type, SalesLine.Type::" ");
            SalesLine.Description := CopyStr(Line."Source Description", 1, MaxStrLen(SalesLine.Description));
            SalesLine.Modify(true);
            exit;
        end;
        if Matcher.IsItem(Line) then begin
            SalesLine.TestField(Type, SalesLine.Type::Item);
            SalesLine.TestField("No.", Line."BC Item No.");
            SalesLine.TestField("Variant Code", Line."BC Variant Code");
        end else begin
            SalesLine.TestField(Type, SalesLine.Type::Resource);
            SalesLine.TestField("No.", Matcher.TargetNo(Line));
        end;
        if Existing then begin
            if SalesLine."Quantity Shipped" <> SalesLine."Quantity Invoiced" then
                Error('Sales Order %1 line %2 has shipped-not-invoiced quantity. Resolve it before I/I Ship and Invoice.', Order."No.", SalesLine."Line No.");
            if Line.Quantity > SalesLine."Outstanding Quantity" then
                Error('Invoice %1 quantity %2 exceeds outstanding quantity %3 on BC Line No. %4.', Header."Document No.", Line.Quantity, SalesLine."Outstanding Quantity", SalesLine."Line No.");
        end else
            SalesLine.Validate(Quantity, Line.Quantity);
        if Line."Related Inventory Trans. ID" <> 0 then begin
            GetTransaction(Header, Line, Transaction);
            // The linked invoice transaction owns the shipment location, including
            // existing order lines. Retain standard BC location validation.
            if SalesLine."Location Code" <> Transaction."BC Location Code" then
                SalesLine.Validate("Location Code", Transaction."BC Location Code");
            if SalesLine."Qty. per Unit of Measure" <> 1 then
                Error('Invoice %1 line %2 quantities must use the item base unit (Qty. per Unit of Measure = 1).', Header."Document No.", Line."Entry No.");
            InventoryRequirements.Add(Transaction."BC Location Code", Resolver.ValidateAccount(Line."Inventory G/L Account", 'Inventory Account', Header."Document No."));
            SalesLine.Validate("Posting Group", Resolver.ResolveInventoryPostingGroup(InventoryRequirements, Header."Document No."));
            GeneralRequirements.Add(Setup.FieldNo("COGS Account"), Resolver.ValidateAccount(Line."COGS G/L Account", 'COGS Account', Header."Document No."));
        end;
        GeneralRequirements.Add(Setup.FieldNo("Sales Account"), Resolver.ValidateAccount(Line."Revenue G/L Account", 'Sales Account', Header."Document No."));
        SalesLine.Validate("Gen. Bus. Posting Group", Order."Gen. Bus. Posting Group");
        SalesLine.Validate("Gen. Prod. Posting Group", Resolver.ResolveGeneralPostingSetup(Order."Gen. Bus. Posting Group", GeneralRequirements, Header."Document No."));
        SalesLine.Validate("Unit Price", Line."Unit Price");
        // Express the invoice's net line amount as a line discount for the retained
        // order quantity. Only invoice-controlled Qty. to Ship/Invoice is posted.
        FullLineAmount := Line.Amount * SalesLine.Quantity / Line.Quantity;
        SalesLine.Validate("Line Discount Amount", Round(SalesLine.Quantity * Line."Unit Price" - FullLineAmount, 0.01));
        SalesLine.Validate("Inv. Discount Amount", 0);
        SalesLine.Validate("Allow Invoice Disc.", false);
        SalesLine.Validate("Tax Area Code", Order."Tax Area Code");
        SalesLine.Validate("Tax Group Code", Line."Tax Group Code");
        SalesLine.Validate("Tax Liable", Order."Tax Liable");
        DimensionSetID := SalesLine."Dimension Set ID";
        CategoryHeader := Header;
        if Line."Related Inventory Trans. ID" <> 0 then
            CategoryHeader."Division Code" := Transaction."Division Code";
        ApplyCategory(CategoryHeader, DimensionSetID);
        SalesLine.Validate("Dimension Set ID", DimensionSetID);
        SalesLine.Validate("Qty. to Ship", Line.Quantity);
        SalesLine.Validate("Qty. to Invoice", Line.Quantity);
        SalesLine."Integration Posting ID" := Header."Integration Posting ID";
        SalesLine."Impress Invoice Line Entry No." := Line."Entry No.";
        SalesLine.Description := CopyStr(Line."Source Description", 1, MaxStrLen(SalesLine.Description));
        SalesLine.Modify(true);
    end;

    procedure EnsureInvoiceTaxSetup(Header: Record "Impress Sales Doc Hdr Staging")
    var
        TaxArea: Record "Tax Area";
        Line: Record "Impress Sales Doc Line Staging";
    begin
        // Use only the posted document snapshot, including invoices without an order.
        // Called within PostDocumentAtomic: setup changes roll back with posting/preview.
        SetDocumentLines(Line, Header);
        Line.SetFilter("Tax Group Code", '<>%1', '');
        if (Header."Tax Area Code" = '') and (Header."Tax Jurisdiction Code 1" = '') and
           (Header."Tax Jurisdiction Code 2" = '') and (Header."Tax Jurisdiction Code 3" = '') and
           (Header."Tax Jurisdiction Code 4" = '') and (Header."Tax Total" = 0) and
           (Header."Tax Rate Total" = 0) and Line.IsEmpty()
        then
            exit;
        Header.TestField("Tax Area Code");
        CheckLength(Header."Tax Area Code", MaxStrLen(TaxArea.Code), 'Tax Area Code');
        // A blank group must not silently inherit customer/item/order tax defaults.
        SetDocumentLines(Line, Header);
        Line.SetFilter(Quantity, '<>0');
        if Line.FindSet() then
            repeat
                if Line."Tax Group Code" = '' then
                    Error('Invoice %1 line %2 has no staged Tax Group Code. Transport the invoice line tax snapshot from Impress and retry.', Header."Document No.", Line."Entry No.");
            until Line.Next() = 0;
        SetDocumentLines(Line, Header);
        EnsureTaxGroups(Line, Header."Document No.");
        TaxResolver.EnsureTaxJurisdiction(Header."Tax Jurisdiction Code 1", Header."Tax Jurisdiction Desc. 1", Header."Tax G/L Account 1");
        TaxResolver.EnsureTaxJurisdiction(Header."Tax Jurisdiction Code 2", Header."Tax Jurisdiction Desc. 2", Header."Tax G/L Account 2");
        TaxResolver.EnsureTaxJurisdiction(Header."Tax Jurisdiction Code 3", Header."Tax Jurisdiction Desc. 3", Header."Tax G/L Account 3");
        TaxResolver.EnsureTaxJurisdiction(Header."Tax Jurisdiction Code 4", Header."Tax Jurisdiction Desc. 4", Header."Tax G/L Account 4");
        TaxResolver.EnsureTaxArea(Header."Tax Area Code", Header."Tax Area Description");
        TaxResolver.EnsureTaxAreaLine(Header."Tax Area Code", Header."Tax Jurisdiction Code 1", 1);
        TaxResolver.EnsureTaxAreaLine(Header."Tax Area Code", Header."Tax Jurisdiction Code 2", 2);
        TaxResolver.EnsureTaxAreaLine(Header."Tax Area Code", Header."Tax Jurisdiction Code 3", 3);
        TaxResolver.EnsureTaxAreaLine(Header."Tax Area Code", Header."Tax Jurisdiction Code 4", 4);
        // BC posts tax using the posting date; never substitute current rates.
        Header.TestField("G/L Post Date");
        EnsureTaxDetailsForLines(Line, Header, Header."G/L Post Date");
    end;

    local procedure EnsureTaxGroups(var LineStaging: Record "Impress Sales Doc Line Staging"; InvoiceNo: Text)
    begin
        LineStaging.SetRange("Tax Group Code");
        if LineStaging.FindSet() then
            repeat
                if LineStaging."Tax Group Code" <> '' then begin
                    ValidateTaxGroupCode(LineStaging."Tax Group Code", InvoiceNo, LineStaging."Entry No.");
                    TaxResolver.EnsureTaxGroup(LineStaging."Tax Group Code", LineStaging."Tax Group Description");
                end;
            until LineStaging.Next() = 0;
    end;

    local procedure ValidateTaxGroupCode(TaxGroupCode: Code[20]; InvoiceNo: Text; SourceDetailID: BigInteger)
    begin
        if not TaxResolver.IsSupportedTaxGroup(TaxGroupCode) then
            Error('Tax Group Code %1 is invalid for invoice %2, Sales Document Line Entry No. %3.', TaxGroupCode, InvoiceNo, SourceDetailID);
    end;

    local procedure EnsureTaxDetailsForLines(var LineStaging: Record "Impress Sales Doc Line Staging"; HeaderStaging: Record "Impress Sales Doc Hdr Staging"; EffectiveDate: Date)
    var
        ProcessedTaxGroups: List of [Code[20]];
        TaxGroupCode: Code[20];
    begin
        LineStaging.Reset();
        LineStaging.SetRange("Sales Document Entry No.", HeaderStaging."Entry No.");
        LineStaging.SetFilter("Tax Group Code", '<>%1', '');
        if LineStaging.FindSet() then
            repeat
                TaxGroupCode := LineStaging."Tax Group Code";
                if not ProcessedTaxGroups.Contains(TaxGroupCode) then begin
                    ProcessedTaxGroups.Add(TaxGroupCode);
                    TaxResolver.EnsureTaxDetail(HeaderStaging."Tax Jurisdiction Code 1", TaxGroupCode, TaxResolver.GetTaxRateForGroup(TaxGroupCode, HeaderStaging."Tax Rate 1"), EffectiveDate);
                    TaxResolver.EnsureTaxDetail(HeaderStaging."Tax Jurisdiction Code 2", TaxGroupCode, TaxResolver.GetTaxRateForGroup(TaxGroupCode, HeaderStaging."Tax Rate 2"), EffectiveDate);
                    TaxResolver.EnsureTaxDetail(HeaderStaging."Tax Jurisdiction Code 3", TaxGroupCode, TaxResolver.GetTaxRateForGroup(TaxGroupCode, HeaderStaging."Tax Rate 3"), EffectiveDate);
                    TaxResolver.EnsureTaxDetail(HeaderStaging."Tax Jurisdiction Code 4", TaxGroupCode, TaxResolver.GetTaxRateForGroup(TaxGroupCode, HeaderStaging."Tax Rate 4"), EffectiveDate);
                end;
            until LineStaging.Next() = 0;
    end;

    local procedure ValidateTaxAccounts(Header: Record "Impress Sales Doc Hdr Staging")
    begin
        ValidateTaxAccount(Header."Tax Jurisdiction Code 1", Header."Tax G/L Account 1", Header."Document No.");
        ValidateTaxAccount(Header."Tax Jurisdiction Code 2", Header."Tax G/L Account 2", Header."Document No.");
        ValidateTaxAccount(Header."Tax Jurisdiction Code 3", Header."Tax G/L Account 3", Header."Document No.");
        ValidateTaxAccount(Header."Tax Jurisdiction Code 4", Header."Tax G/L Account 4", Header."Document No.");
    end;

    local procedure ValidateTaxAccount(JurisdictionCode: Text; AccountNo: Text; InvoiceNo: Text)
    var
        Jurisdiction: Record "Tax Jurisdiction";
        Resolver: Codeunit "Impress Posting Setup Resolver";
    begin
        if (JurisdictionCode = '') and (AccountNo = '') then
            exit;
        Jurisdiction.Get(JurisdictionCode);
        Jurisdiction.TestField("Tax Account (Sales)", Resolver.ValidateAccount(AccountNo, 'Tax G/L Account', InvoiceNo));
    end;

    local procedure ApplyCategory(Header: Record "Impress Sales Doc Hdr Staging"; var DimensionSetID: Integer)
    var
        Defaults: Record "Impress Defaults";
        Category: Codeunit "Impress Category Dimension";
    begin
        Defaults.Get();
        Defaults.TestField("Category Dimension Code");
        Category.ApplyToDimensionSet(DimensionSetID, Defaults."Category Dimension Code", Category.GetDimensionValueCode(Header."Source Database", Header."Division Code"));
    end;

    local procedure Reconcile(var Header: Record "Impress Sales Doc Hdr Staging"; PostingID: Guid)
    var
        Reconciliation: Codeunit "Impress II Reconciliation";
    begin
        Reconciliation.Reconcile(Header, PostingID);
    end;

    local procedure SetProcessing(var Header: Record "Impress Sales Doc Hdr Staging"; PostingID: Guid)
    var
        Line: Record "Impress Sales Doc Line Staging";
        Transaction: Record "Impress Inv Trans Staging";
    begin
        Header."Processing Status" := Header."Processing Status"::Processing;
        Header."Date Processing Started" := CurrentDateTime();
        Header."Integration Posting ID" := PostingID;
        Clear(Header."Error Message");
        Header.Modify(true);
        SetDocumentLines(Line, Header);
        if Line.FindSet(true) then
            repeat
                Line."Processing Status" := Line."Processing Status"::Processing;
                Clear(Line."Error Message");
                Line.Modify(true);
                if Line."Related Inventory Trans. ID" <> 0 then begin
                    GetTransaction(Header, Line, Transaction);
                    if not IsNullGuid(Transaction."Integration Posting ID") then
                        Transaction.TestField("Integration Posting ID", PostingID);
                    Transaction."Integration Posting ID" := PostingID;
                    Transaction."Related Sales Doc. Entry No." := Header."Entry No.";
                    Transaction."Processing Status" := Transaction."Processing Status"::Processing;
                    Transaction."Date Processing Started" := Header."Date Processing Started";
                    Clear(Transaction."Error Message");
                    Transaction.Modify(true);
                end;
            until Line.Next() = 0;
    end;

    local procedure MarkDocumentError(var Header: Record "Impress Sales Doc Hdr Staging"; Failure: Text)
    var
        Line: Record "Impress Sales Doc Line Staging";
        Transaction: Record "Impress Inv Trans Staging";
    begin
        Header.Get(Header."Entry No.");
        Header."Processing Status" := Header."Processing Status"::Error;
        Header."Error Message" := CopyStr(Failure, 1, MaxStrLen(Header."Error Message"));
        Header.Modify(true);
        SetDocumentLines(Line, Header);
        if Line.FindSet(true) then
            repeat
                Line."Processing Status" := Line."Processing Status"::Error;
                Line."Error Message" := CopyStr(Failure, 1, MaxStrLen(Line."Error Message"));
                Line.Modify(true);
                if Line."Related Inventory Trans. ID" <> 0 then begin
                    Transaction.Reset();
                    Transaction.SetRange("Source Database", Header."Source Database");
                    Transaction.SetRange("Source Transaction ID", Line."Related Inventory Trans. ID");
                    if Transaction.FindFirst() then begin
                        Transaction."Processing Status" := Transaction."Processing Status"::Error;
                        Transaction."Error Message" := CopyStr(Failure, 1, MaxStrLen(Transaction."Error Message"));
                        Transaction.Modify(true);
                    end;
                end;
            until Line.Next() = 0;
    end;

    procedure GetTransaction(Header: Record "Impress Sales Doc Hdr Staging"; Line: Record "Impress Sales Doc Line Staging"; var Transaction: Record "Impress Inv Trans Staging")
    begin
        Transaction.Reset();
        Transaction.SetRange("Source Database", Header."Source Database");
        Transaction.SetRange("Source Transaction ID", Line."Related Inventory Trans. ID");
        if not Transaction.FindFirst() then
            Error('Invoice %1 line %2: expected I/I transaction %3 is missing.', Header."Document No.", Line."Entry No.", Line."Related Inventory Trans. ID");
        Transaction.TestField("Transaction Type", 'I');
        Transaction.TestField("Transaction Source", 'I');
    end;

    procedure SetDocumentLines(var Line: Record "Impress Sales Doc Line Staging"; Header: Record "Impress Sales Doc Hdr Staging")
    begin
        Line.Reset();
        Line.SetRange("Sales Document Entry No.", Header."Entry No.");
    end;

    local procedure ClearRemainingOrderTags(OrderNo: Code[20]; PostingID: Guid)
    var
        Order: Record "Sales Header";
        Line: Record "Sales Line";
    begin
        if Order.Get(Order."Document Type"::Order, OrderNo) then begin
            Order.TestField("Integration Posting ID", PostingID);
            Clear(Order."Integration Posting ID");
            Order.Modify();
            Line.SetRange("Document Type", Order."Document Type");
            Line.SetRange("Document No.", OrderNo);
            if Line.FindSet(true) then
                repeat
                    Clear(Line."Integration Posting ID");
                    Clear(Line."Impress Invoice Line Entry No.");
                    Line.Modify();
                until Line.Next() = 0;
        end;
    end;

    local procedure CheckTransport(Status: Enum "Impress Integration Status")
    begin
        if not (Status in [Status::Sent, Status::Processed]) then
            Error('I/I transport status must be Sent or Processed; actual %1.', Status);
    end;

    local procedure CheckLength(Value: Text; Maximum: Integer; Purpose: Text)
    begin
        if StrLen(Value) > Maximum then
            Error('%1 exceeds BC field length %2: %3.', Purpose, Maximum, Value);
    end;
    var
        TaxResolver: Codeunit "Impress Tax Resolver";
}


