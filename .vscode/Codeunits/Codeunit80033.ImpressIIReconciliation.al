codeunit 80033 "Impress II Reconciliation"
{
    [CommitBehavior(CommitBehavior::Error)]
    procedure Reconcile(var Header: Record "Impress Sales Doc Hdr Staging"; PostingID: Guid)
    var
        Invoice: Record "Sales Invoice Header";
        PostedLine: Record "Sales Invoice Line";
        Line: Record "Impress Sales Doc Line Staging";
        Transaction: Record "Impress Inv Trans Staging";
        CustomerEntry: Record "Cust. Ledger Entry";
        GLEntry: Record "G/L Entry";
        Setup: Record "General Posting Setup";
        Defaults: Record "Impress Defaults";
        Management: Codeunit "Impress II Invoice Mgt.";
        Resolver: Codeunit "Impress Posting Setup Resolver";
        Tracking: Codeunit "Impress Posting Tracking";
        GeneralRequirements: Dictionary of [Integer, Code[20]];
        InventoryRequirements: Dictionary of [Code[10], Code[20]];
        ProcessedAt: DateTime;
        TotalNet: Decimal;
        TotalGross: Decimal;
        ARAmount: Decimal;
        CategoryHeader: Record "Impress Sales Doc Hdr Staging";
        Matcher: Codeunit "Impress Invoice Line Match";
        TaxResolver: Codeunit "Impress Tax Resolver";
    begin
        Defaults.Get();
        Invoice.SetRange("Integration Posting ID", PostingID);
        if Invoice.Count() <> 1 then
            Error('Invoice %1: expected one posted Sales Invoice for GUID %2, found %3. No new posting is permitted.', Header."Document No.", PostingID, Invoice.Count());
        Invoice.FindFirst();
        Invoice.TestField("Impress Source Database", Header."Source Database");
        Invoice.TestField("External Document No.", Header."Document No.");
        Invoice.TestField("Sell-to Customer No.", Header."Source Customer Code");
        Invoice.TestField("Posting Date", Header."G/L Post Date");
        Resolver.ValidateCustomerProfile(Invoice."Customer Posting Group", Header."A/R G/L Account", Header."Document No.");
        CustomerEntry.Get(Invoice."Cust. Ledger Entry No.");
        CustomerEntry.TestField("Document Type", CustomerEntry."Document Type"::Invoice);
        CustomerEntry.TestField("Document No.", Invoice."No.");
        CustomerEntry.TestField("Customer No.", Invoice."Bill-to Customer No.");
        CustomerEntry.CalcFields("Original Amount", "Original Amt. (LCY)");
        Tracking.AddLink(PostingID, Database::"Sales Invoice Header", 0, Invoice.SystemId, Invoice."No.", Invoice."Posting Date");
        Tracking.AddLink(PostingID, Database::"Cust. Ledger Entry", CustomerEntry."Entry No.", CustomerEntry.SystemId, Invoice."No.", Invoice."Posting Date");
        Management.SetDocumentLines(Line, Header);
        Line.FindSet(true);
        repeat
            if Line.Quantity <> 0 then begin
                PostedLine.Reset();
                PostedLine.SetRange("Document No.", Invoice."No.");
                PostedLine.SetRange("Integration Posting ID", PostingID);
                PostedLine.SetRange("Impress Invoice Line Entry No.", Line."Entry No.");
                if PostedLine.Count() <> 1 then
                    Error('Invoice %1 line %2: expected one tagged posted invoice line, found %3.', Header."Document No.", Line."Entry No.", PostedLine.Count());
                PostedLine.FindFirst();
                PostedLine.TestField(Quantity, Line.Quantity);
                if Line."BC Sales Line No." <> 0 then
                    PostedLine.TestField("Order Line No.", Line."BC Sales Line No.");
                CheckAmount(PostedLine.Amount, Line.Amount, 'Posted invoice line amount');
                CategoryHeader := Header;
                if Line."Related Inventory Trans. ID" <> 0 then begin
                    Management.GetTransaction(Header, Line, Transaction);
                    CategoryHeader."Division Code" := Transaction."Division Code";
                end;
                CheckCategory(CategoryHeader, PostedLine."Dimension Set ID");
                if Matcher.IsItem(Line) then
                    PostedLine.TestField(Type, PostedLine.Type::Item)
                else
                    PostedLine.TestField(Type, PostedLine.Type::Resource);
                PostedLine.TestField("No.", Matcher.TargetNo(Line));
                PostedLine.TestField("Variant Code", Line."BC Variant Code");
                Clear(GeneralRequirements);
                GeneralRequirements.Add(Setup.FieldNo("Sales Account"), Resolver.ValidateAccount(Line."Revenue G/L Account", 'Sales Account', Header."Document No."));
                if Line."Related Inventory Trans. ID" <> 0 then begin
                    Management.GetTransaction(Header, Line, Transaction);
                    PostedLine.TestField(Type, PostedLine.Type::Item);
                    PostedLine.TestField("No.", Line."BC Item No.");
                    PostedLine.TestField("Variant Code", Line."BC Variant Code");
                    PostedLine.TestField("Location Code", Transaction."BC Location Code");
                    GeneralRequirements.Add(Setup.FieldNo("COGS Account"), Resolver.ValidateAccount(Line."COGS G/L Account", 'COGS Account', Header."Document No."));
                    Clear(InventoryRequirements);
                    InventoryRequirements.Add(Transaction."BC Location Code", Resolver.ValidateAccount(Line."Inventory G/L Account", 'Inventory Account', Header."Document No."));
                    Resolver.ValidateInventoryProfile(PostedLine."Posting Group", InventoryRequirements, true, Header."Document No.");
                    CheckInventoryLine(Header, Line, Transaction, PostedLine, PostingID);
                end;
                PostedLine.TestField("Gen. Bus. Posting Group", Defaults."Gen. Bus. Posting Group (Inv.)");
                Resolver.ValidateGeneralProfile(PostedLine."Gen. Bus. Posting Group", PostedLine."Gen. Prod. Posting Group", GeneralRequirements, true, Header."Document No.");
                Tracking.AddLink(PostingID, Database::"Sales Invoice Line", PostedLine."Line No.", PostedLine.SystemId, Invoice."No.", Invoice."Posting Date");
                Line."BC Sales Line No." := PostedLine."Order Line No.";
                Line."BC Line System ID" := PostedLine.SystemId;
                Line.Modify(true);
            end;
        until Line.Next() = 0;
        // Include every posted line, including BC rounding lines, when reconciling
        // the total. An unexpected tax/discount amount rolls back standard posting.
        PostedLine.Reset();
        PostedLine.SetRange("Document No.", Invoice."No.");
        if PostedLine.FindSet() then
            repeat
                TotalNet += PostedLine.Amount;
                TotalGross += PostedLine."Amount Including VAT";
            until PostedLine.Next() = 0;
        TaxResolver.CheckTaxDifference(TotalGross - TotalNet, Header."Tax Total", Invoice."Currency Code", Invoice."Prices Including VAT");
        // Only the tax difference uses BC tax tolerance. Net and ledger integrity
        // retain their existing checks; no source amount or posted amount is adjusted.
        CheckAmount(TotalNet, Header."Invoice Total" - Header."Tax Total", 'Posted invoice net total');
        CheckAmount(CustomerEntry."Original Amount", TotalGross, 'Customer Ledger Entry invoice amount');
        GLEntry.SetRange("Transaction No.", CustomerEntry."Transaction No.");
        if GLEntry.FindSet() then
            repeat
                Tracking.AddLink(PostingID, Database::"G/L Entry", GLEntry."Entry No.", GLEntry.SystemId, GLEntry."Document No.", GLEntry."Posting Date");
                if GLEntry."G/L Account No." = Header."A/R G/L Account" then
                    ARAmount += GLEntry.Amount;
            until GLEntry.Next() = 0;
        CheckAmount(ARAmount, CustomerEntry."Original Amt. (LCY)", 'A/R G/L debit');
        ProcessedAt := CurrentDateTime();
        Header."Integration Posting ID" := PostingID;
        Header."BC Sales Order No." := Invoice."Order No.";
        Header."BC Document No." := Invoice."No.";
        Header."BC System ID" := Invoice.SystemId;
        Header."Processing Status" := Header."Processing Status"::Processed;
        Header."Date Processed" := ProcessedAt;
        Clear(Header."Error Message");
        Header.Modify(true);
        Management.SetDocumentLines(Line, Header);
        Line.FindSet(true);
        repeat
            Line."Processing Status" := Line."Processing Status"::Processed;
            Line."BC System ID" := Invoice.SystemId;
            Line."Date Processed" := ProcessedAt;
            Clear(Line."Error Message");
            Line.Modify(true);
            if Line."Related Inventory Trans. ID" <> 0 then begin
                Management.GetTransaction(Header, Line, Transaction);
                Transaction."Integration Posting ID" := PostingID;
                Transaction."Related Sales Doc. Entry No." := Header."Entry No.";
                Transaction."BC Posted Document Type" := 'Sales Invoice';
                Transaction."BC Posted Document No." := Invoice."No.";
                Transaction."BC Posted Posting Date" := Invoice."Posting Date";
                Transaction."BC Document No." := Invoice."No.";
                Transaction."BC System ID" := Invoice.SystemId;
                Transaction."Processing Status" := Transaction."Processing Status"::Processed;
                Transaction."Date Processed" := ProcessedAt;
                Transaction."Processed Date/Time" := ProcessedAt;
                Clear(Transaction."Error Message");
                Transaction.Modify(true);
            end;
        until Line.Next() = 0;
    end;

    local procedure CheckInventoryLine(Header: Record "Impress Sales Doc Hdr Staging"; Line: Record "Impress Sales Doc Line Staging"; Transaction: Record "Impress Inv Trans Staging"; PostedLine: Record "Sales Invoice Line"; PostingID: Guid)
    var
        Entry: Record "Item Ledger Entry";
        Value: Record "Value Entry";
        Relation: Record "G/L - Item Ledger Relation";
        GL: Record "G/L Entry";
        Tracking: Codeunit "Impress Posting Tracking";
        TotalQuantity: Decimal;
    begin
        Entry.SetRange("Integration Posting ID", PostingID);
        Entry.SetRange("Impress Invoice Line Entry No.", Line."Entry No.");
        if not Entry.FindSet() then
            Error('Invoice %1 line %2 has no tagged Item Ledger Entries.', Header."Document No.", Line."Entry No.");
        repeat
            Entry.TestField("Entry Type", Entry."Entry Type"::Sale);
            Entry.TestField("Item No.", Line."BC Item No.");
            Entry.TestField("Variant Code", Line."BC Variant Code");
            Entry.TestField("Location Code", Transaction."BC Location Code");
            Entry.TestField("Posting Date", Header."G/L Post Date");
            CheckCategory(Header, Entry."Dimension Set ID");
            TotalQuantity += Entry.Quantity;
            Tracking.AddLink(PostingID, Database::"Item Ledger Entry", Entry."Entry No.", Entry.SystemId, Entry."Document No.", Entry."Posting Date");
            Value.SetRange("Item Ledger Entry No.", Entry."Entry No.");
            if not Value.FindSet() then
                Error('Item Ledger Entry %1 has no Value Entries.', Entry."Entry No.");
            repeat
                Value.TestField("Integration Posting ID", PostingID);
                Value.TestField("Inventory Posting Group", PostedLine."Posting Group");
                Value.TestField("Gen. Bus. Posting Group", PostedLine."Gen. Bus. Posting Group");
                Value.TestField("Gen. Prod. Posting Group", PostedLine."Gen. Prod. Posting Group");
                Tracking.AddLink(PostingID, Database::"Value Entry", Value."Entry No.", Value.SystemId, Value."Document No.", Value."Posting Date");
                Relation.SetRange("Value Entry No.", Value."Entry No.");
                if Relation.FindSet() then
                    repeat
                        GL.Get(Relation."G/L Entry No.");
                        Tracking.AddLink(PostingID, Database::"G/L Entry", GL."Entry No.", GL.SystemId, GL."Document No.", GL."Posting Date");
                    until Relation.Next() = 0;
            until Value.Next() = 0;
        until Entry.Next() = 0;
        if TotalQuantity <> Transaction.Quantity then
            Error('Invoice %1 line %2: posted inventory %3 differs from I/I quantity %4.', Header."Document No.", Line."Entry No.", TotalQuantity, Transaction.Quantity);
    end;

    local procedure CheckCategory(Header: Record "Impress Sales Doc Hdr Staging"; DimensionSetID: Integer)
    var
        Defaults: Record "Impress Defaults";
        Entry: Record "Dimension Set Entry";
        Category: Codeunit "Impress Category Dimension";
    begin
        Defaults.Get();
        Entry.Get(DimensionSetID, Defaults."Category Dimension Code");
        Entry.TestField("Dimension Value Code", Category.GetDimensionValueCode(Header."Source Database", Header."Division Code"));
    end;

    local procedure CheckAmount(Actual: Decimal; Expected: Decimal; Purpose: Text)
    begin
        if Abs(Actual - Expected) > 0.01 then
            Error('%1: expected %2; actual %3. No further posting is permitted until reconciliation succeeds.', Purpose, Expected, Actual);
    end;
}
