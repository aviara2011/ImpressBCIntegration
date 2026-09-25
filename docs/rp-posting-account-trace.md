# R/P receipt account trace — BC 28.1

## Receipt header field collision — 1.0.0.96

The 1.0.0.95 live attempt reached standard Purch.-Post.InsertReceiptHeader, whose `PurchRcptHeader.TransferFields(PurchHeader)` copies by field number. Purchase Header fields 80000/80001/80002 are Code[50] source database, BigInteger source POrder ID, and Code[35] source PO number. Receipt Header had assigned those same IDs to Guid integration ID, Text[50] source database, and BigInteger source transaction ID. All three pairings were incompatible; clearing field values would not fix the type mismatch.

Receipt tracking now uses field IDs 80020/80021/80022, retaining the existing active field names, types, indexes and application references. Old IDs remain in the installed schema as renamed ObsoleteState=Removed fields, which standard TransferFields excludes. Standard receipt creation and the existing tagging subscriber remain unchanged. The user explicitly confirmed there is no receipt data to migrate and requested no migration; no upgrade migration code is included.

Added a regression test invoking the same unmodified TransferFields call with populated purchase identity, checking standard field copying, absence of unintended receipt identity, and identity lookup after explicitly tagging the receipt. Production 1.0.0.96 and tests 1.0.0.22 compile against BC 28.1. Runtime test execution and live extension update remain unverified here; no package was published and no transaction was processed.

References: [Microsoft TransferFields field-number matching](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/record/record-transferfields-table-boolean-boolean-method) and [Microsoft AL obsolete-field TransferFields fix](https://github.com/microsoft/AL/issues/4265).

## Blank locations on other item lines — 1.0.0.95

The live 1.0.0.94 attempt reported a blank Location Code on BC PO 106472 line 11000. Standard Release Purchase Document.CheckMandatoryFields filters item lines with nonzero order Quantity, not Qty. to Receive, and requires Location Code when Inventory Setup.Location Mandatory is enabled. Thus zeroing receipt quantities does not avoid this release check.

Preparation now fills blank locations on other same-order item lines from the validated target receipt location (M for transaction 8763071). It validates the resolved IMI/IMP groups first, then validates Location Code, before standard release. Existing nonblank locations remain unchanged. A blank location triggers preparation even when all posting groups already match. Standard location validation remains active, including received-but-uninvoiced, reservation, warehouse, pricing, tax and dimension behavior; no standard restrictions are bypassed. The transaction's later quantity preparation still ensures only the target line is received. These changes remain inside the atomic posting transaction.

Regression coverage extends the same-order profile test to preserve an existing different location and verify that a blank location with matching groups reaches standard validation and rejects received-but-uninvoiced quantity. Sandbox verification must additionally exercise successful blank-location validation on a normal unreceived item line, then confirm line 11000 has M and zero receipt quantity, only the target receives 72, and retry reconciles the same receipt. Production version is 1.0.0.95; test version is 1.0.0.21. No publication or live posting was performed.

## PO-wide item-line defaults — 1.0.0.94

The user subsequently authorized copying the current receipt's resolved Impress posting groups to all other item lines on the same PO, even though those lines are not being received. This supersedes the target-line-only policy described below for 1.0.0.93.

After resolving and validating the target line, and while the order is Open, R/P validates the same Inventory Posting Group, Gen. Bus. Posting Group and Gen. Product Posting Group on the other item lines. Their locations remain unchanged. Existing quantity preparation still zeros every other line's Qty. to Receive and validates the full authoritative quantity on the target. Receive-only posting, over-receipt processing and reconciliation remain unchanged. These updates share the existing atomic posting transaction, so a failed posting rolls them back.

Every later R/P resolves its source accounts again and replaces these PO defaults with its newly resolved groups. Until that happens, the copied groups persist on the PO, including for any manual posting. Other orders and non-item lines are excluded; remaining blocked non-item setups still produce the explicit line diagnostic. CUSTOMER/ITEMS is not unblocked. No additional location setup is inferred for other lines; their later R/P resolves the profile for the actual receipt location.

Regression coverage checks same-order item-line propagation, unchanged location/quantities and blocked defaults, exclusion of other orders and comment lines, and replacement/reuse on subsequent preparation. Production 1.0.0.94 and test package 1.0.0.20 were rebuilt against BC 28.1. Runtime tests require the isolated sandbox described in TG_TESTING.md; no live receipt or publication was performed.

## Reconfirmed configuration — 2026-09-20

The user explicitly reconfirmed that Source Adjustment G/L Account **5099** maps to **Direct Cost Applied Account**, and that both **Automatic Cost Posting** and **Expected Cost Posting to G/L** are enabled in the target company. These are user-confirmed settings, not a live configuration read. Review of the existing 1.0.0.93 source confirms that it already implements this mapping through the shared resolver; no additional posting-account substitution is needed.

For ImpressTest transaction 8763071 (PO 43798, source line 4, C001SDUS / XL, warehouse M, quantity 72), the required IMI profile at M has Inventory Account and Inventory Account (Interim) = 1310. The IMP profile under Impress Defaults.Gen. Bus. Posting Group (Inv.) requires Invt. Accrual Acc. (Interim) = 2020 and Direct Cost Applied Account = 5099. The ordinary expected-cost receipt posts debit 1310 / credit 2020; 5099 is checked without posting that actual-cost pair. Actual IMP/IMI numbers depend on the company's existing profiles and cannot be determined from source alone.

The local review confirms standard purchase-line validation, full authoritative receipt quantity, Receive = true / Invoice = false, standard over-receipt validation, and the existing receipt identity/reconciliation checks. No live transaction has been processed by this review.

Inspected the cached Microsoft Base Application 28.1.49838.51713 source before changing posting-account assignments. The user confirmed that Inventory Setup has both **Automatic Cost Posting = Yes** and **Expected Cost Posting to G/L = Yes**. These settings were supplied by the user, not read from the live company.

## Receipt posting path

1. Codeunit 90 `Purch.-Post.PostItemJnlLine` copies the purchase header/line into its internal Item Journal Line buffer. Receive-only passes received quantity with zero invoiced quantity and calls `CalcItemJnlLineToBeReceivedAmounts`.
2. Codeunit 22 `Item Jnl.-Post Line.InitValueEntry` marks the receipt's direct-cost Value Entry as Expected Cost when invoiced quantity is zero. Its general posting groups and inventory posting group come from the posting buffer. The purchase line's `Posting Group` is the inventory posting group; its general business/product fields supply the general combination.
3. Codeunit 22 sets PostToGL from Inventory Setup.Automatic Cost Posting and calls `PostInventoryToGL` / `PostValueEntryToGL`.
4. Codeunit 5802 `Inventory Posting To G/L.BufferInvtPosting` permits expected-cost posting when Expected Cost Posting to G/L is enabled. `BufferPurchPosting`, for Purchase / Direct Cost and nonzero expected amount, builds Inventory (Interim) against Invt. Accrual (Interim).
5. `SetAccNo` resolves Inventory (Interim) through `Inventory Posting Setup.GetInventoryAccountInterim` and Invt. Accrual (Interim) through `General Posting Setup.GetInventoryAccrualAccount`.

For this positive receipt's expected inventory cost, the intended mapping is:

| BC setup field | Source requirement | Role |
| --- | --- | --- |
| Inventory Posting Setup.`Inventory Account (Interim)` (field 5800), Location M | Source Inventory G/L Account = **1310** | Receipt expected-cost debit |
| General Posting Setup.`Invt. Accrual Acc. (Interim)` (field 5801) | Source Offset G/L Account = **2020** | Receipt expected-cost credit |
| Inventory Posting Setup.`Inventory Account` (field 6), Location M | Source Inventory G/L Account = **1310** | Standard check-only actual-cost validation; actual inventory account for subsequent actual-cost posting |
| General Posting Setup.`Direct Cost Applied Account` | Source Adjustment G/L Account = **5099**, explicitly confirmed by the user after the trace | Standard check-only actual-cost validation during the receipt; not the expected-cost receipt credit |

The debit/credit amount is the expected cost calculated by BC from the purchase line, not quantity 72 as a currency amount. Zero-value or non-inventoriable items can have no G/L amount despite enabled setup. No invoice, vendor payable or invoice tax posting is requested by R/P.

## Additional standard validation discovered

Codeunit 22 `PostValueEntryToGL`, after posting an expected-cost entry, calls `SetValueEntry` to temporarily present an actual-cost amount. It sets Codeunit 5802 to `SetRunOnlyCheck(true, true, false)` and calls `PostInvtBuffer` again. A zero expected cost uses a synthetic amount of 1 for this check. The original entry is restored afterward.

That check follows Codeunit 5802's Purchase / Direct Cost **actual** branch: Inventory against Direct Cost Applied. Although it does not post those amounts to G/L, `SetAccNo` still calls `GetInventoryAccount` and `GetDirectCostAppliedAccount`. The latter logs a posting-setup field error when the account is blank. Therefore a new IMP profile with only Invt. Accrual Acc. (Interim) is not a complete receipt-ready profile.

The source transaction establishes 2020 as the receipt offset, which maps to the interim accrual credit. It does **not** independently establish that 2020 is also the company's Direct Cost Applied Account. Nor does the presence of adjustment account 5099 alone establish that it belongs there. After this distinction was reported, the user explicitly confirmed **SKUTRANS_GLACCT_CODEADJ = 5099** for Direct Cost Applied Account. Version 1.0.0.93 therefore uses the transaction's Source Adjustment G/L Account for that field. The numbers are not hard-coded.

## Does 5099 participate?

**Not as a posted debit/credit in the ordinary Purchase / Direct Cost expected receipt entry.** With the user's confirmed mapping, 5099 participates in the standard check-only pass as Direct Cost Applied Account. It is not assigned to Inventory Adjmt. Account by R/P. Inventory Adjmt. Account is used by different branches, including actual revaluation/rounding and adjustment entry types. Later cost adjustment, invoices or other entry types are separate paths; this trace does not authorize configuring their other accounts from this R/P event.

## Required shared-resolver change

Codeunit 80026 supports general setup requirements by BC field number and resolves the IMP signature under Impress Defaults.`Gen. Bus. Posting Group (Inv.)`. The implemented signature requires Invt. Accrual Acc. (Interim) = 2020 plus Direct Cost Applied Account = 5099. It does not unblock CUSTOMER/ITEMS. Existing exact/compatible IMP reuse rules remain in effect, including unblocking a selected matching IMP profile.

The inventory resolver now has an overload matching location + required actual **and interim** inventory accounts, so a profile for Location M with Inventory Account 1310 but a blank/conflicting interim account is not reused. The shared allocator creates a new complete IMI profile when needed; it does not overwrite the incomplete/conflicting profile. Existing journal callers retain their single-account matching behavior through the original overload. No separate R/P numbering/allocation mechanism was introduced.

Only the resolved purchase line receives the configured general business group and resolved IMP/IMI profiles, through field validation. The IMI Posting Group is applied before Location Code validation checks Inventory Posting Setup. Location remains authoritative from the transaction warehouse, including overriding a different nonblank line location through standard validation as most recently requested. Standard reopen/release surrounds group/location changes; the order is Released before quantity/over-receipt preparation, with approval/prepayment restrictions preserved. All changes remain inside the existing atomic transaction.

Scoped subscribers verify the standard posting buffer and internal item journal retain the resolved profiles. New receipt headers carry Impress RP Account Version = 1. Reconciliation verifies the posted receipt's IMP/IMI profiles, all four required account fields, and the correlated receipt Value Entry profiles. It uses the historical posted general business group rather than requiring a subsequently changed default to match. Older receipts (version marker 0) retain their existing identity/quantity/ledger reconciliation and never trigger reposting merely because they lack the new account evidence. No setup is created or changed by the reconciliation path.

## Other order lines

Codeunit 90 `CheckPurchLines` invokes `TestPurchLine` for all buffered PO lines. `CheckBlockedPostingGroups` is not conditional on Qty. to Receive being nonzero. Consequently an unrelated line still referencing blocked CUSTOMER/ITEMS can remain a blocker after the active line receives its correct IMP profile. The current error does not identify which live line triggered it. Do not silently unblock the shared setup, apply this transaction's accounts to unrelated lines, or remove lines from the posting buffer in a way that changes order-completion behavior.

## Implementation and validation — 1.0.0.93

After reporting the trace and receiving the Direct Cost Applied mapping, changed Codeunit 80026 (shared resolver), Codeunit 80037 (R/P preparation/reconciliation), Codeunit 80039 (posting-scope checks), Tableextension 80010 (receipt account-version marker), test Codeunit 80097, and the app manifest. Production 1.0.0.93 and test package 1.0.0.19 compile against BC 28.1. Runtime BC tests have not run; no extension was published and no pending transactions were processed. SQL procedures and PowerShell transport are unchanged.

Added regression tests verify actual/interim IMI matching and conflict preservation, complete-profile reuse, unchanged legacy matching, the confirmed two-field IMP signature, absent Inventory Adjmt. Account requirements, preservation of blocked non-IMP defaults, missing Direct Cost Applied source-account rejection, and explicit unrelated-line diagnostics without changing their groups or setup.

The unrelated-line blocker described above remains an intentional error, now reporting the actual BC order/line number. A controlled receipt may still require correction of those other lines' posting setup; this extension does not infer their accounting from the selected transaction. In the controlled sandbox test, verify Location M, Qty. to Receive 72, receipt date, the chosen IMP/IMI setup fields, expected-cost debit 1310 and credit 2020, no receipt amount posted to 5099, and identical receipt evidence on retry.

References: installed BC source copies in `.work/base-source`, particularly `PurchPost.Codeunit.al.reference`, `ItemJnlPostLine.Codeunit.al.reference`, `InventoryPostingToGL.Codeunit.al.reference`, `InventoryPostingSetup.Table.al.reference`, and `GeneralPostingSetup.Table.al.reference`. Microsoft documentation: [Expected cost posting](https://learn.microsoft.com/en-us/dynamics365/business-central/design-details-expected-cost-posting), [Accounts in the general ledger](https://learn.microsoft.com/en-us/dynamics365/business-central/design-details-accounts-in-the-general-ledger).
