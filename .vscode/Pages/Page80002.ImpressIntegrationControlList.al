page 80002 "Impress Integration Control"
{
    PageType = List;
    SourceTable = "Impress Integration Control";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Impress Integration Control';
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Run ID"; Rec."Run ID") { ApplicationArea = All; }
                field("Process Name"; Rec."Process Name") { ApplicationArea = All; }
                field("Run Start DateTime"; Rec."Run Start DateTime") { ApplicationArea = All; }
                field("Run End DateTime"; Rec."Run End DateTime") { ApplicationArea = All; }
                field("Run Status"; Rec."Run Status") { ApplicationArea = All; }
                field("Run Message"; Rec."Run Message") { ApplicationArea = All; }
                field("Last Successful Run DateTime"; Rec."Last Successful Run DateTime") { ApplicationArea = All; }
                field("Records Selected"; Rec."Records Selected") { ApplicationArea = All; }
                field("Records Staged"; Rec."Records Staged") { ApplicationArea = All; }
                field("Records Sent To BC"; Rec."Records Sent To BC") { ApplicationArea = All; }
                field("Records Failed"; Rec."Records Failed") { ApplicationArea = All; }
                field("Records Processed In BC"; Rec."Records Processed In BC") { ApplicationArea = All; }
                field(Difference; Rec.Difference) { ApplicationArea = All; }
                field("SQL Run ID"; Rec."SQL Run ID") { ApplicationArea = All; }
                field("SQL Run Guid"; Rec."SQL Run Guid") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DeleteSalesOrders)
            {
                ApplicationArea = All;
                Caption = 'Delete Sales Orders';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Delete all sales orders in the current company for testing, using standard BC deletion checks. Linked open orders return to Pending in staging.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                    RecordCount: Integer;
                begin
                    SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                    RecordCount := SalesHeader.Count();
                    if not Confirm('Delete all %1 sales orders and their lines in the current company? This includes orders outside Impress and is not limited to the selected integration run. Linked open orders will return to Pending in staging and may be recreated by the job queue. This action is intended for testing only.', false, RecordCount) then
                        exit;

                    SalesHeader.DeleteAll(true);
                    CurrPage.Update(false);
                    Message('%1 sales orders were deleted.', RecordCount);
                end;
            }
            action(DeleteStagedSalesOrders)
            {
                ApplicationArea = All;
                Caption = 'Delete Staged Sales Orders';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Delete all Impress sales order staging headers and lines in the current company for testing. Existing BC sales orders are retained.';

                trigger OnAction()
                var
                    HeaderStaging: Record "Impress Sales Header Staging";
                    LineStaging: Record "Impress Sales Line Staging";
                    IntegrationControl: Record "Impress Integration Control";
                    IntegrationManagement: Codeunit "Impress Integration Management";
                    HeaderCount: Integer;
                    LineCount: Integer;
                begin
                    HeaderCount := HeaderStaging.Count();
                    LineCount := LineStaging.Count();
                    if not Confirm('Delete all %1 Impress sales order staging headers and %2 staging lines in the current company? This is not limited to the selected integration run. Existing BC sales orders will remain. This action is intended for testing only.', false, HeaderCount, LineCount) then
                        exit;

                    HeaderStaging.DeleteAll(true);
                    // Also remove any staging lines with no matching header.
                    LineStaging.DeleteAll(true);
                    IntegrationControl.SetRange("Process Name", 'SALES ORDERS');
                    if IntegrationControl.FindSet() then
                        repeat
                            IntegrationManagement.UpdateSalesOrderControlTotals(IntegrationControl."SQL Run ID");
                        until IntegrationControl.Next() = 0;
                    CurrPage.Update(false);
                    Message('%1 staged sales order headers and %2 staging lines were deleted.', HeaderCount, LineCount);
                end;
            }
            action(DeleteItems)
            {
                ApplicationArea = All;
                Caption = 'Delete Items';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Delete all items for testing.';

                trigger OnAction()
                var
                    Item: Record Item;
                    RecordCount: Integer;
                begin
                    if not Confirm('Delete all items? This action is intended for testing only.', false) then
                        exit;

                    RecordCount := Item.Count();
                    Item.DeleteAll(true);
                    Message('%1 items were deleted.', RecordCount);
                end;
            }
            action(DeleteCustomers)
            {
                ApplicationArea = All;
                Caption = 'Delete Customers';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Delete all customers for testing.';

                trigger OnAction()
                var
                    Customer: Record Customer;
                    RecordCount: Integer;
                begin
                    if not Confirm('Delete all customers? This action is intended for testing only.', false) then
                        exit;

                    RecordCount := Customer.Count();
                    Customer.DeleteAll(true);
                    Message('%1 customers were deleted.', RecordCount);
                end;
            }
            action(DeleteVendors)
            {
                ApplicationArea = All;
                Caption = 'Delete Vendors';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Delete all vendors for testing.';

                trigger OnAction()
                var
                    Vendor: Record Vendor;
                    RecordCount: Integer;
                begin
                    if not Confirm('Delete all vendors? This action is intended for testing only.', false) then
                        exit;

                    RecordCount := Vendor.Count();
                    Vendor.DeleteAll(true);
                    Message('%1 vendors were deleted.', RecordCount);
                end;
            }
            action(UpdateVendorsWithImpressDefaults)
            {
                ApplicationArea = All;
                Caption = 'Update Vendors with Impress Defaults';
                Image = UpdateDescription;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Update all vendors with the vendor posting group defaults from Impress Defaults. This action is intended for temporary correction only.';

                trigger OnAction()
                var
                    ImpressVendorProcessor: Codeunit "Impress Vendor Processor";
                    UpdatedCount: Integer;
                begin
                    if not Confirm('Update all vendors with the vendor defaults from Impress Defaults? This temporary action will modify existing vendor posting groups.', false) then
                        exit;

                    UpdatedCount := ImpressVendorProcessor.UpdateVendorsWithImpressDefaults();
                    Message('%1 vendors were updated with Impress Defaults.', UpdatedCount);
                end;
            }
            action(DeleteGLAccounts)
            {
                ApplicationArea = All;
                Caption = 'Delete G/L Accounts';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Delete all G/L accounts for testing.';

                trigger OnAction()
                var
                    GLAccount: Record "G/L Account";
                    RecordCount: Integer;
                begin
                    if not Confirm('Delete all G/L accounts? This action is intended for testing only.', false) then
                        exit;

                    RecordCount := GLAccount.Count();
                    GLAccount.DeleteAll(true);
                    Message('%1 G/L accounts were deleted.', RecordCount);
                end;
            }
            action(DeleteItemStaging)
            {
                ApplicationArea = All;
                Caption = 'Delete Item Staging';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Delete all Impress item staging records for testing.';

                trigger OnAction()
                var
                    ImpressItemStaging: Record "Impress Item Staging";
                    RecordCount: Integer;
                begin
                    if not Confirm('Delete all Impress item staging records? This action is intended for testing only.', false) then
                        exit;

                    RecordCount := ImpressItemStaging.Count();
                    ImpressItemStaging.DeleteAll(true);
                    Message('%1 Impress item staging records were deleted.', RecordCount);
                end;
            }
            action(DeleteCustomerStaging)
            {
                ApplicationArea = All;
                Caption = 'Delete Customer Staging';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Delete all Impress customer staging records for testing.';

                trigger OnAction()
                var
                    ImpressCustomerStaging: Record "Impress Customer Staging";
                    RecordCount: Integer;
                begin
                    if not Confirm('Delete all Impress customer staging records? This action is intended for testing only.', false) then
                        exit;

                    RecordCount := ImpressCustomerStaging.Count();
                    ImpressCustomerStaging.DeleteAll(true);
                    Message('%1 Impress customer staging records were deleted.', RecordCount);
                end;
            }
            action(DeleteVendorStaging)
            {
                ApplicationArea = All;
                Caption = 'Delete Vendor Staging';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Delete all Impress vendor staging records for testing.';

                trigger OnAction()
                var
                    ImpressVendorStaging: Record "Impress Vendor Staging";
                    RecordCount: Integer;
                begin
                    if not Confirm('Delete all Impress vendor staging records? This action is intended for testing only.', false) then
                        exit;

                    RecordCount := ImpressVendorStaging.Count();
                    ImpressVendorStaging.DeleteAll(true);
                    Message('%1 Impress vendor staging records were deleted.', RecordCount);
                end;
            }
            action(DeleteGLAccountStaging)
            {
                ApplicationArea = All;
                Caption = 'Delete G/L Account Staging';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Delete all Impress G/L account staging records for testing.';

                trigger OnAction()
                var
                    ImpressGLAccountStaging: Record "Impress G/L Account Staging";
                    RecordCount: Integer;
                begin
                    if not Confirm('Delete all Impress G/L account staging records? This action is intended for testing only.', false) then
                        exit;

                    RecordCount := ImpressGLAccountStaging.Count();
                    ImpressGLAccountStaging.DeleteAll(true);
                    Message('%1 Impress G/L account staging records were deleted.', RecordCount);
                end;
            }
        }
        area(Reporting)
        {
            action(ItemReconciliation)
            {
                ApplicationArea = All;
                Caption = 'Item Reconciliation';
                Image = Reconcile;
                ToolTip = 'Open the item reconciliation report for the current SQL Run ID.';

                trigger OnAction()
                var
                    ImpressItemReconciliation: Report "Impress Item Reconciliation";
                begin
                    ImpressItemReconciliation.RunModal();
                end;
            }
            action(CurrentRunItemReconciliation)
            {
                ApplicationArea = All;
                Caption = 'Current Run Item Reconciliation';
                Image = Reconcile;
                ToolTip = 'Open the item reconciliation report filtered to the current SQL Run ID.';

                trigger OnAction()
                var
                    ImpressItemReconciliation: Report "Impress Item Reconciliation";
                begin
                    ImpressItemReconciliation.SetSQLRunIDFilter(Format(Rec."SQL Run ID"));
                    ImpressItemReconciliation.RunModal();
                end;
            }
        }
    }
}
