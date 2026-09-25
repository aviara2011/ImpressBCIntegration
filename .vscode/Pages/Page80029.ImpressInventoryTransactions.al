page 80029 "Impress Inventory Transactions"
{
    PageType = List;
    SourceTable = "Impress Inv Trans Staging";
    Caption = 'Impress Inventory Transactions';
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = true;
    DeleteAllowed = true;

    layout
    {
        area(content)
        {
            repeater(Transactions)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Source Database"; Rec."Source Database") { ApplicationArea = All; }
                field("Source Transaction ID"; Rec."Source Transaction ID") { ApplicationArea = All; }
                field("G/L Date"; Rec."G/L Date") { ApplicationArea = All; }
                field("Transaction Type"; Rec."Transaction Type") { ApplicationArea = All; }
                field("Transaction Source"; Rec."Transaction Source") { ApplicationArea = All; }
                field("Transaction Handler"; Rec."Transaction Handler") { ApplicationArea = All; }
                field("Source SKU No."; Rec."Source SKU No.") { ApplicationArea = All; }
                field("Source Size"; Rec."Source Size") { ApplicationArea = All; }
                field("Source Warehouse Code"; Rec."Source Warehouse Code") { ApplicationArea = All; }
                field(Quantity; Rec.Quantity) { ApplicationArea = All; }
                field("Source Order No."; Rec."Source Order No.") { ApplicationArea = All; }
                field("Source Order Line No."; Rec."Source Order Line No.") { ApplicationArea = All; }
                field("BC Item No."; Rec."BC Item No.") { ApplicationArea = All; }
                field("BC Variant Code"; Rec."BC Variant Code") { ApplicationArea = All; }
                field("BC Location Code"; Rec."BC Location Code") { ApplicationArea = All; }
                field("Division Code"; Rec."Division Code") { ApplicationArea = All; }
                field("Processing Status"; Rec."Processing Status") { ApplicationArea = All; }
                field("BC Posted Document Type"; Rec."BC Posted Document Type") { ApplicationArea = All; Editable = false; }
                field("BC Posted Document No."; Rec."BC Posted Document No.") { ApplicationArea = All; Editable = false; }
                field("BC Posted Posting Date"; Rec."BC Posted Posting Date") { ApplicationArea = All; Editable = false; }
                field("Processed Date/Time"; Rec."Processed Date/Time") { ApplicationArea = All; Editable = false; }
                field("Transport Status"; Rec."Transport Status") { ApplicationArea = All; }
                field("Related Sales Document Entry No."; Rec."Related Sales Doc. Entry No.") { ApplicationArea = All; }
                field("BC Document No."; Rec."BC Document No.") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
                field("Date Staged"; Rec."Date Staged") { ApplicationArea = All; }
                field("Date Processing Started"; Rec."Date Processing Started") { ApplicationArea = All; }
                field("Date Processed"; Rec."Date Processed") { ApplicationArea = All; }
                field("Source G/L Account"; Rec."Source G/L Account") { ApplicationArea = All; }
                field("Source Inventory G/L Account"; Rec."Source Inventory G/L Account") { ApplicationArea = All; }
                field("Source Offset G/L Account"; Rec."Source Offset G/L Account") { ApplicationArea = All; }
                field("Source Adjustment G/L Account"; Rec."Source Adjustment G/L Account") { ApplicationArea = All; }
                field("Source Cost"; Rec."Source Cost") { ApplicationArea = All; }
                field("Source LIFO/FIFO Cost"; Rec."Source LIFO/FIFO Cost") { ApplicationArea = All; }
                field("Source LIFO/FIFO Cost Adj."; Rec."Source LIFO/FIFO Cost Adj.") { ApplicationArea = All; }
                field("Source Added Cost"; Rec."Source Added Cost") { ApplicationArea = All; }
                field("Source Freight Cost"; Rec."Source Freight Cost") { ApplicationArea = All; }
                field("Source Other Cost"; Rec."Source Other Cost") { ApplicationArea = All; }
                field("Source SKU ID"; Rec."Source SKU ID") { ApplicationArea = All; }
                field("SKU Division Code"; Rec."SKU Division Code") { ApplicationArea = All; }
                field("Source Document Division Code"; Rec."Source Document Division Code") { ApplicationArea = All; }
                field("Division Source"; Rec."Division Source") { ApplicationArea = All; }
                field("BC System ID"; Rec."BC System ID") { ApplicationArea = All; }
                field("Integration Posting ID"; Rec."Integration Posting ID") { ApplicationArea = All; Editable = false; Visible = false; }
                field(Prepared; Prepared) { ApplicationArea = All; Editable = false; ToolTip = 'Specifies whether a journal line currently exists for this Integration Posting ID.'; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(PreviewNoPosting)
            {
                ApplicationArea = All;
                Caption = 'Preview (No Posting)';
                Image = View;
                ToolTip = 'Create or reuse the proposed transfer and shortage adjustment journal lines for review without posting.';
                trigger OnAction()
                begin
                    CurrPage.SaveRecord();
                    PostingEngine.PreviewTransaction(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(Process)
            {
                ApplicationArea = All;
                Caption = 'Process Transaction';
                Image = Process;
                trigger OnAction()
                begin
                    CurrPage.SaveRecord();
                    PostingEngine.ProcessTransaction(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ProcessSelectedTransactions)
            {
                ApplicationArea = All;
                Caption = 'Process Selected Transactions';
                Image = Process;
                ToolTip = 'Process selected transactions in Entry No. order within each source, including matching T/G partners. Each completed transaction or pair commits immediately. Stop on the first failure; earlier postings remain committed. Earlier unresolved entries cannot be skipped.';
                trigger OnAction()
                var
                    Selected: Record "Impress Inv Trans Staging";
                    PairCount: Integer;
                begin
                    CurrPage.SaveRecord();
                    CurrPage.SetSelectionFilter(Selected);
                    PairCount := PostingEngine.ProcessSelectedTransactions(Selected);
                    CurrPage.Update(false);
                    Message('Processed %1 transaction group(s). Each T/G pair counts as one group. Already processed transactions were skipped.', PairCount);
                end;
            }
            action(RetryError)
            {
                ApplicationArea = All;
                Caption = 'Retry Error';
                Image = Refresh;
                trigger OnAction()
                begin
                    CurrPage.SaveRecord();
                    PostingEngine.RetryInventoryTransaction(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ResetToPending)
            {
                ApplicationArea = All;
                Caption = 'Reset to Pending';
                Image = ResetStatus;
                trigger OnAction()
                begin
                    PostingEngine.ResetInventoryTransaction(Rec);
                end;
            }
            action(FindEntries)
            {
                ApplicationArea = All;
                Caption = 'Find Entries';
                Image = Navigate;
                ToolTip = 'Find the Business Central entries for the posted document number and posting date.';
                trigger OnAction()
                var
                    Navigate: Page Navigate;
                begin
                    if Rec."BC Posted Document No." = '' then begin
                        Message('This transaction has not been posted or does not have a posted BC document reference.');
                        exit;
                    end;
                    if Rec."BC Posted Posting Date" = 0D then begin
                        Message('The posted BC posting date is missing. Process Transaction to reconcile the posting before finding entries.');
                        exit;
                    end;
                    Navigate.SetDoc(Rec."BC Posted Posting Date", Rec."BC Posted Document No.");
                    Navigate.RunModal();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Journal: Record "Item Journal Line";
    begin
        Prepared := false;
        if IsNullGuid(Rec."Integration Posting ID") then
            exit;
        Journal.SetRange("Integration Posting ID", Rec."Integration Posting ID");
        Prepared := not Journal.IsEmpty();
    end;

    var
        Prepared: Boolean;
        PostingEngine: Codeunit "Impress Trans. Posting Engine";
}
