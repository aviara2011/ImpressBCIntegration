# I/I Sales Line lifecycle diagnosis and correction — 1.0.0.85

## Finding and evidence limits

There is a concrete lifecycle defect in the inspected 1.0.0.83 package and pre-fix workspace: invoice preparation changes the Sales Header general business posting group before matching invoice lines. Standard BC recreates existing Sales Lines when that group changes. Neither the original order staging references nor the custom Sales Line identity fields were maintained across this operation. The matcher subsequently reads the current physical line and tests its new SystemId against the old stored reference.

The user's clarification is consistent with this distinction: the first invoice created an order from scratch; the second invoice uses an existing order. On a new, empty order the header validation has no Sales Lines to recreate. On an existing order, recreation occurs if its general business posting group differs from Impress Defaults."Gen. Bus. Posting Group (Inv.)". An existing order alone is not sufficient to prove recreation; the group change and the BC recreation events must be observed.

No live BC records, change log, or Application Insights were available. Neither supplied GUID occurs in the searched workspace text. Consequently the exact historical provenance of `09498404-E0AC-F111-AAA8-002248AA94FA` and `1EEF1A40-14B2-F111-AAA8-000D3AEFBD59`, and the actual failing matcher branch, are NOT proven. This correction addresses the demonstrated code lifecycle defect, not an assumed historical data repair.

The error's “Current value” is the value during the failing transaction. The Boolean runner rolls preparation back on error, so this GUID may have existed only inside that attempt. It must not be assumed to identify a currently persisted line after the failure. This also means a retry may generate a different replacement GUID.

## Objects and call flow

1. Page 80029 "Impress Inventory Transactions", Process action, calls Codeunit 80018 "Impress Trans. Posting Engine". Its I/I branch delegates to Codeunit 80029 and exits before the direct journal path. Page 80032 "Impress Sales Document" also reaches Codeunit 80029 through Codeunit 80018.ProcessSalesDocument.
2. Codeunit 80029.ResolveInvoice finds exactly one Table 80014 invoice staging line by source database and related inventory transaction ID, then loads Table 80013 invoice staging header.
3. ProcessDocument runs Codeunit 80030 "Impress II Posting Runner" as a Boolean transaction boundary. Runner.OnRun calls PostDocumentAtomic. On failure it rolls back, marks invoice/header/linked inventory staging Error, and raises the outer error supplied by the user. This wrapper retains GetLastErrorText but does not include the inner call stack in its new Error call.
4. PostDocumentAtomic derives the integration posting ID from the invoice staging header SystemId, validates source data, and reconciles any posted invoice with that ID before resolving order lines. It separately rejects partial/legacy posted evidence. Therefore an already-posted invoice is not supposed to reach the matcher.
5. ResolveOrder uses the prepared-order reference or the originating Sales Order staging mapping (Table 80009). If the originating order is absent, the established fallback creates a new header and clears OrderStaging; it does not reconstruct the old physical Sales Line IDs.
6. PrepareOrder reopens a released order and validates header fields, including the invoice general business posting group. It then zeros Qty. to Ship/Invoice on current lines and calls Codeunit 80034 "Impress Invoice Line Match" for each invoice staging line.
7. Matcher resolves the existing staged business identity or its existing unambiguous actual-order fallback. PrepareLine applies invoice quantities, prices, posting profiles and correlation fields. PrepareOrder stores the resolved current Sales Line ID on invoice staging.
8. Standard Codeunit "Sales-Post" receives the prepared header with Ship=true and Invoice=true, with commits suppressed. Codeunit 80032 "Impress II Posting Scope" carries posting tags and tax validation. Standard sales posting owns inventory and COGS; no replacement Item Journal path is introduced.
9. Codeunit 80033 "Impress II Reconciliation" verifies posted invoice, line and ledger evidence, uses Codeunit 80024 posting links, and marks staging Processed. Codeunit 80031 provides the rollback-only preview path.

Supporting paths inspected include Codeunit 80016 order transport/upsert/deletion, its runners 80022/80023, posting setup resolver 80026, custom sales table extensions, staging tables/APIs, and relevant standard BC source from the installed Base Application 28.1.49838.51713 package. Reference source is outside the project so it is not compiled into the extension.

## Expected and current IDs; exact error statements

| Reference | Writer / meaning | Relevance |
| --- | --- | --- |
| Table 80010 "Impress Sales Line Staging"."BC Line System ID" | Codeunit 80016.ProcessLineCore assigns the current Sales Line SystemId after transport insert/update. | Matcher 80034 line 55 executes `SalesLine.TestField(SystemId, Staged."BC Line System ID")` after a fresh Get by order/line. This is the likely branch when exactly one originating staged candidate exists. |
| Table 80014 "Impress Sales Doc Line Staging"."BC Line System ID" | Codeunit 80029.PrepareOrder stores the live Sales Line ID before posting. Codeunit 80033.Reconcile later replaces it with the posted Sales Invoice Line ID. | Matcher 80034 line 81 tests this field on the fallback/persisted-correlation branch. Do not treat a processed line's posted ID as a live Sales Line ID. |
| Table 80009 order header staging."BC System ID" | Sales Header SystemId assigned by Codeunit 80016. | Codeunit 80029 checks this against Sales Header, not Sales Line; it cannot directly produce the supplied Sales Line TestField error. |
| Table 80013 invoice header staging."BC System ID" | Posted Sales Invoice Header SystemId assigned during reconciliation. | Used as posted-result evidence, not the expected Sales Line ID. |
| Table 80012 inventory transaction staging."BC System ID" | For I/I, Codeunit 80033.Reconcile assigns `Invoice.SystemId` with the posted invoice number/type/date. | Zero is normal for pending/unprocessed I/I. It does not participate in either Sales Line ID comparison. A zero on an allegedly reconciled Processed I/I row needs separate evidence review; do not populate it simply because it is zero. |

Staging API pages expose these reference fields too, so the code alone cannot exclude an external write. Exact attribution of the supplied expected GUID requires inspecting Tables 80010 and 80014, or breaking at the two matcher TestField statements before the outer runner rethrows.

The standard path that generates a replacement ID is:

```text
80029.PrepareOrder
  Order.Validate("Gen. Bus. Posting Group", Defaults."Gen. Bus. Posting Group (Inv.)")
    Table 36 Sales Header, field 74 OnValidate (standard source line 1542)
      RecreateSalesLines (line 4706)
        copy old lines into TempSalesLine (line 7510 onward)
        SalesLine.DeleteAll(true) (line 4762)
        RecreateSalesLinesHandleSupplementTypes -> CreateSalesLine
          SalesLine.Init; assign new line number; validate standard fields
          SalesLine.Insert() (line 7613): BC allocates the new physical SystemId
  80034.Resolve: SalesLine.Get(current order/line)
    SalesLine.TestField(SystemId, stored staging ID) -> mismatch
```

Standard CreateSalesLine assigns line numbers in increments of 10000 and explicitly transfers standard fields; it does not copy this extension's six custom identity/correlation fields. Thus recreation can also change line numbers or lose source identity. Re-reading by old line number alone is insufficient.

Standard Release Sales Document.Reopen changes status and reopens warehouse requests; the inspected procedure does not itself delete/reinsert Sales Lines. The proven recreating call is header field validation. Standard source also permits recreation for other header changes; the correction handles the actual recreation events rather than hard-coding one field.

No stale custom Sales Line variable or stored RecordId is needed to explain this defect. The matcher performs a fresh Get. The stale value is the persistent reference, while standard BC uses a temporary old-line buffer during reconstruction. Custom tax temporary buffers in Codeunit 80032 are used later during posting; RecordRef use in 80026 is for posting setup, not Sales Line identity. No custom Sales Line SystemId assignment, RecordId lookup, Rename, or TransferFields-based reconstruction was found in the original relevant path.

Codeunit 80016 has separate supported deletion/recreation paths. Whole-order deletion resets order staging mappings; missing-order preparation clears line mappings before a new order is transported; ProcessLineCore saves the resulting line ID. These do not maintain mappings during the standard in-place header-driven recreation in invoice preparation.

## Implemented correction

New Codeunit 80036 "Impress II Line Lifecycle" is a manual subscriber bound by Codeunit 80029 only around PrepareOrder for the active I/I order, including preview.

- Before standard recreation, snapshot the actual old records and keep their physical IDs separately from temporary-record IDs.
- On BC's OnAfterRecreateSalesLine event, use its explicit old/new pairing. Reload the new physical record and verify its ID, document, type, item/resource and variant.
- Preserve all six custom line identity/correlation fields from the verified old record.
- Refresh originating order staging only when its old physical ID, source/order scope, source detail/size, header identity and mapped target agree. Refresh only active invoice references with the verified old ID; processed references are rejected.
- Save the new ID and the actual new line number. Mapping lookup uses the captured old ID within its source scope, so BC renumbering cannot accidentally select a staging row just refreshed for another line.
- Continue through the unchanged matcher. Raw SKU/size/order candidate resolution, multiple-candidate rejection, fallback rules, missing-line errors and existing SystemId TestField checks remain intact.

No real Sales Line SystemId is assigned or changed by this extension. No historical GUID is blindly overwritten. A GUID already stale before the observed recreation is not refreshed. Standard validations, transactional rollback, stable invoice posting ID, posted-evidence reconciliation and duplicate protection are preserved. The handler is unbound before standard posting; it does not alter reconciliation's posted-line references.

Modified production object: Codeunit 80029. Added production object: Codeunit 80036. App version is 1.0.0.85. Tests added to Codeunit 80095; the test build script produces test version 1.0.0.12. Matcher 80034, sales-order transport 80016, reconciliation 80033 and standard BC are unchanged.

## Validation and limitations

Production and test packages compile against local BC 28.1 symbols. Added regression cases exercise real Sales Header posting-group validation and cover verified order/invoice mapping refresh, BC renumbering, repeated recreation, unproven stale GUID rejection, fallback retry correlation, duplicate SKU rejection, a new empty order, and the unbound handler. Existing replacement-ID rejection and matching tests are retained.

BC runtime tests have NOT run: no connected test service/runtime is configured. No deployment, live data repair, or invoice processing was performed. A pre-existing persisted mismatch remains an error and needs record-level investigation; this package intentionally does not retrospectively adopt an unexplained replacement line.

## Controlled retest: ImpressTest invoice 341760 / SO05546 / original line 110000

Run in the test company with this invoice selected only. I/I processes the complete invoice and all its linked inventory rows even when invoked from one inventory row; this is not a single-line posting test.

Before testing, capture:

1. Sales Header SO05546: SystemId, status, source database/order ID, general business posting group and Integration Posting ID; compare with Impress Defaults invoice general business posting group.
2. Sales Line 110000 and the rest of the order: line numbers, SystemIds/SystemCreatedAt, type, item, variant, quantity/shipped/invoiced/outstanding, location, and all six Impress identity fields. Do not assume the GUID printed during the failed transaction persisted after rollback.
3. Originating order header staging and the unique matching Table 80010 row: source database/order ID/order number, Raw SKU, size position, detail ID, mapped item/variant, BC document/line numbers and both BC IDs. Verify its old line ID equals the actual pre-test physical line. If it already differs, stop this posting test and capture the unexplained replacement history instead of editing the GUID.
4. Invoice 341760 staging header/lines: header SystemId/Integration Posting ID, originating order number, statuses, BC references, Raw SKU/size/item/variant and related inventory IDs. Inspect corresponding Table 80012 rows, including quantities, location/date, status, posting ID and posted references.
5. Search posted invoice headers by invoice staging SystemId as Integration Posting ID, and separately by external document 341760/customer. Check shipments and posting links too. If this exact invoice is already posted, verify reconciliation rather than attempting a new posting. The earlier first invoice is separate evidence and must not be adopted as invoice 341760.

Preview first. To prove the incident mechanism, break at CaptureLines, RefreshRecreatedLine, and matcher 80034 lines 55/81. Record old/current GUIDs, old/new line numbers, the posting-group change, matched staging entry and full inner call stack. Successful preview must roll back all generated lines, ID refreshes, header changes and posting results; compare the captured before-state afterward. A preview GUID is not expected to equal the subsequent process GUID.

Then Process the single invoice once. Expect exactly one posted Sales Invoice with the staging header SystemId as Integration Posting ID; matching source invoice/customer, amounts, item quantities, location and posting date; standard shipment/item/value/G/L/customer entries; and no direct integration Item Journal posting. The invoice header/lines and all linked I/I rows should be Processed with no error. Their BC System ID should be the posted Sales Invoice Header ID. Nonzero-quantity invoice staging BC Line System IDs should identify posted Sales Invoice Lines, while BC Sales Line No. retains their originating order-line numbers. Table 80010's refreshed references identify the recreated order lines; a fully posted/deleted order need not retain live Sales Lines.

Process that same invoice again only as an idempotency check: it must reconcile the same posted invoice without adding another invoice, shipment or ledger posting. On a failed attempt, expect Error statuses/error text, with no newly committed posting or recreation/mapping updates. Preserve the inner stack and before/after evidence if the error persists.
