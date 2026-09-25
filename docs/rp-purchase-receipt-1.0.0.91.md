# R/P purchase receipts — 1.0.0.91

R/P now posts one positive incremental inventory transaction as one standard Purchase Receipt against an existing purchase order. The shared engine retains Source Database / Source Transaction ID ordering, source locking, and one transaction per commit. There is no receipt-number grouping, PO creation, standalone item journal, invoicing, or integration tax calculation. SQL and PowerShell files are unchanged. No extension has been published and no pending transactions have been processed.

## AL objects

New objects:

- Codeunit 80037 `Impress RP Receipt Mgt.`: exact resolution, receipt preparation, atomic posting, error persistence and reconciliation.
- Codeunit 80038 `Impress RP Posting Runner`: Boolean runner around the existing engine's atomic entry point, following the I/I rollback/error boundary.
- Codeunit 80039 `Impress RP Posting Scope`: manually bound subscribers that verify the posting buffer and attach the integration identity to the receipt and standard posting's internal item journal buffer.
- Tableextension 80010 `Impress Purch. Receipt`: extends Purch. Rcpt. Header with the Integration Posting ID, source transaction identity, source order/line/SKU/size/warehouse snapshot and resolved BC order line number.

Changed objects:

- Codeunit 80018 `Impress Trans. Posting Engine`: dispatches R/P; successful-row retries reconcile evidence instead of returning without checking it.
- Codeunit 80024 `Impress Posting Tracking`: posted purchase receipt headers now count as posted evidence, even if ledger evidence is incomplete.
- Table 80012 `Impress Inv Trans Staging`: prevents deletion of a receipt-backed R/P row even if its stored Integration Posting ID was cleared.
- Permissionset 80000: grants execute permission on the new codeunits. Standard purchase-posting permissions are still required.
- Test codeunit 80095: five R/P regression tests, included in the existing test runner.
- Manifest: version 1.0.0.91.

## Resolution and quantities

Inventory source database + source order number + source order line number + source SKU + size must select exactly one Purchase Line Staging record. Multiple records are rejected even when they point to the same BC item/variant. Its source database and Source POrder ID select the staging header.

Header lookup prefers the staged line's BC Header System ID, then the staging header's BC System ID. If neither exists, a stored BC Document No. is required. A populated but missing GUID is an error; it never falls back to another document. Both staged document numbers and header GUIDs, when present, must agree. The actual header must be an Order with matching Impress source database, POrder ID and source PO number.

Line lookup prefers BC Line System ID. Only when that GUID is absent does it use the staged BC Document No. and BC Line No. A stale GUID is an error. The resolved line must belong to the resolved order and match its persisted line number, Item type, item, variant, location, source database, source detail ID, size position, source line number and SKU. A populated staging UOM must also match.

The inventory transaction's mapped BC Location Code must match the staging header's BC Location Code and the actual purchase line. Its raw Source Warehouse Code must also match the staging header. No warehouse mapping is inferred or created in AL. Transaction item/variant must agree with the exact staged/actual line. Drop shipments and project lines are rejected because they have additional posting effects outside this receipt handler.

The quantity is exactly Inventory Transaction.Quantity, which must be positive. It is passed directly to standard `Purchase Line.Validate("Qty. to Receive", Transaction.Quantity)` and checked again afterward. Ordered and cumulative received staging quantities are never used as the current receipt quantity. The quantity is interpreted in the resolved purchase line's unit of measure, as required by the direct quantity assignment; there is no additional conversion of SKUTRANS quantity.

## Standard over-receipt behavior

Reviewed the installed Microsoft Base Application 28.1.49838.51713 source, specifically Table 39 Purchase Line, Table 38 Purchase Header, Codeunit 8510 Over-Receipt Mgt., Codeunit 90 Purch.-Post, and the posted receipt tables.

Table 39's Qty. to Receive validation calls `OverReceiptProcessing()`. When receipt quantity exceeds outstanding quantity, BC validates Over-Receipt Quantity. Codeunit 8510 selects the existing line code or a configured default (item, vendor, then default over-receipt code) and `VerifyOverReceiptQuantity` enforces its tolerance. Table 39 adjusts Quantity and costs through standard validation. This extension does not calculate an excess quantity, enlarge Quantity itself, truncate the receipt, select a tolerance, or create over-receipt codes.

The existing PO must be **Released** for standard over-receipt validation. Configure an appropriate Over-Receipt Code on the line or through BC's item/vendor/default setup, with sufficient tolerance for the complete receipt. The staging header's Allow Over Receipt Boolean is not a substitute for BC setup. `Purch.-Post.CheckOverReceipt` rejects Pending over-receipt approval; the integration never approves or bypasses it. When approval is required, prepare the intended over-receipt quantity and complete the standard approval workflow on the PO before retrying. A Pending approval generated during an integration attempt rolls back with that attempt.

Microsoft's setup guidance: [Receive more items than ordered](https://learn.microsoft.com/en-us/dynamics365/business-central/purchasing-how-record-purchases#receive-more-items-than-ordered).

## Posting scope and date

The header's Posting Date is validated from Inventory Transaction.G/L Date before quantities are prepared. For the example input, the posted receipt date is May 1, 2026. Standard date restrictions, number series, currency and purchase validations still apply.

Under the purchase header/line locks, all other order lines with nonzero Qty. to Receive are validated to zero. The target gets the complete transaction quantity. A scoped `Purch.-Post.OnAfterCopyToTempLines` subscriber also checks the actual posting buffer has exactly one nonzero receipt line with the expected line number and quantity, including if BC reloads the buffer. Receipt reconciliation rejects any additional nonzero posted line.

The handler calls `Purch.-Post.SetSuppressCommit(true)` and non-Boolean `Run` with Receive=true and Invoice=false, inside CommitBehavior::Error. There is no integration tax resolver call. BC retains its ordinary document validation and internal posting behavior. Quantity preparation is committed with a successful receipt; prior user-entered Qty. to Receive values on unrelated lines are not restored. BC may initialize next-receipt quantities after posting; every subsequent R/P attempt scopes them again.

## Evidence, retries and errors

The inventory staging row's immutable SystemId is the deterministic Integration Posting ID, matching the stable-ID approach used by I/I. A populated staging GUID must equal it and cannot be owned by another row. The receipt header stores that GUID and a source snapshot; the scoped subscriber tags the standard purchase posting's internal item-journal buffer so existing codeunit 80024 propagates the GUID into Item Ledger Entries, Value Entries and G/L links. No item journal record is created by R/P.

Before resolving or changing a live PO, the handler checks for receipt evidence by GUID. It reconciles exactly one receipt, its source snapshot and posting date, exactly one nonzero posted receipt line with the authoritative quantity, and the correlated Purchase Receipt item ledger entries. Item/variant/location/date/document/line and aggregate base quantity must agree. Ledger entries for that receipt cannot carry another GUID. A corrected/undone or inconsistent receipt cannot trigger a new posting. Value and G/L links continue to use the existing tracking subscribers, including later costing.

Successful reconciliation fills the existing BC System ID, BC Document No., BC Posted Document Type/No./Posting Date and processed timestamps, then sets Processed. Reconciliation does not require the live order to still exist. Missing receipt evidence with ledger evidence, a Processed status or posted references blocks reposting. Receipt lookup by source database/transaction ID also rejects a receipt belonging to a different GUID, protecting against deleted/recreated staging identities.

The outer Boolean runner rolls back all PO edits, numbering, receipt and ledger writes on failure. Only afterward does it save Error and a diagnostic beginning with SourceDatabase, SourceTransactionID, source PO, source line, SKU and size, then rethrow to stop the source stream. Earlier successful transaction commits remain intact. The persisted error uses the existing 2,048-character field.

## Validation and controlled first test

Production package `Techstyle_Impress BC Integration_1.0.0.91.app` and test package `Techstyle_Impress TG Tests_1.0.0.17.app` compile successfully against the cached BC 28.1 symbols. The existing build script initially produces test version 1.0.0.14; the final test package was compiled as 1.0.0.17 using a temporary test manifest, without changing the script. Runtime BC tests have not been executed. The five added regression tests cover exact size matching, zero/multiple matches, stale header/line GUIDs despite valid document numbers, location/source-detail drift, incomplete receipt evidence, staging deletion protection, completed retry without a live PO, and changed receipt quantity on retry. These are AL regression fixtures, not proof that a live standard receipt has posted successfully.

Before processing the selected controlled transaction, verify its exact staging match and PO line identity, warehouse/location, UOM, GL date, released status for over-receipt, tolerance/approval and standard item tracking/warehouse prerequisites. Warehouse-receipt-required locations and serial/lot requirements are not bypassed; missing standard prerequisites will fail the transaction.

In a disposable sandbox, validate normal partial receipt, allowed over-receipt, rejected tolerance, required approval, unrelated nonzero receipt quantities, two successive sizes on one source PO line, and retry of the completed transaction. Confirm full receipt quantities and dates, no invoice, no unrelated received quantity, one receipt per R/P, and rollback plus Error on failure. The first pending R/P transaction remains for the user's controlled selection after review. R/P Preview is not added; the existing preview action continues to reject unsupported handlers without posting.
