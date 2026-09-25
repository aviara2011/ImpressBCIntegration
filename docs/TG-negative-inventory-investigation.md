# Negative inventory for T/G movements

## Finding

Standard transfer posting is not a suitable path for negative stock. The observed
28.4 call stack fails in Item Ledger Entry.VerifyOnInventory. Inspection of the
available 28.1 Base Application source confirms that transfers reject an open
negative entry regardless of the item's Prevent Negative Inventory setting.
Item application also has transfer-specific restrictions on applying later entries.
Suppressing the first error would not establish a working cost/application model.

For A004 / BAS-SM at M, 4 available minus 20 outbound must result in -16 at M,
with 20 added at WIP and no change in total company quantity from this movement.

## Candidate for sandbox validation

Use standard item journal posting for a paired negative adjustment at FROM and
positive adjustment at TO. Keep both postings, applications, tracking links and
staging completion in one atomic transaction; commit only when the pair succeeds.
Continue Entry No. ordering per source and stop on failure, as in 1.0.0.67.
Respect the item's effective Prevent Negative Inventory setting.

Preserve the business group from Impress Defaults (IMPRESS_INV in this company),
dynamic product/inventory profiles, source inventory/adjustment accounts, CATEGORY,
variant and source identity. Do not substitute item-card groups or OPENINV.
Historical cost adjustment still needs the original entries' posting setups.

Investigate Applies-from Entry on the TO positive adjustment, pointing to the
posted FROM negative adjustment, to forward cost rather than invent an independent
receipt cost. This is a candidate, not a verified implementation. Microsoft describes
this as a cost application: it does not close the outbound quantity. A later real
receipt must cover the source shortage. Open entries can prevent inventory-period
closing. Do not use the artificial destination receipt to cover the source shortage.

Two independent adjustments with an equal initial unit cost are insufficient proof
of correct accounting: later receipts/invoices may change the outbound cost without
updating the destination. When paired values match, adjustment-account debits and
credits should offset and value should move between the intended inventory accounts.
This must remain true after cost adjustment and any downstream consumption/sale.

## Required integration changes if the candidate passes

- Add an explicit posting mode; retain recognition/reconciliation of historical
  Transfer entries and existing prepared journals. Do not reinterpret posted pairs.
- Support two journal lines and standard posting of FROM before constructing the
  TO cost application. Current preparation and number reservation assume one line.
- Adapt duplicate protection: current GUID checks reject additional posting once
  any item entries exist for the GUID. Allow only the expected second leg in the
  active atomic pair, without weakening retry protection.
- Reconcile adjustment entry types, signed quantities, cost applications, dimensions,
  generated profiles and G/L outcomes; current reconciliation requires Transfer.
- Update preview, journal-number reservation, GUID ownership, cleanup and recovery
  for two legs. A failure on TO must roll back FROM too; a later pair failure must
  preserve earlier committed pairs.
- Establish provisional costing for an outbound quantity with no cost source yet.
  Do not assume Source Cost is a unit cost or authoritative without checking its
  source meaning. A004's costing method is not established by the screenshots.

## Sandbox acceptance scenario

1. Use a company matching installed BC 28.4 and the real item's costing method.
   Seed 4 units at M, post the proposed movement of 20 to WIP, and verify M=-16,
   WIP increases by 20, correct CATEGORY/profiles and balanced movement value.
2. Receive the missing 16 at M at a different cost, then run cost adjustment and
   inventory-to-G/L posting. Verify the application chain, destination value,
   source closure and clearing of the pair's adjustment-account balance.
3. Repeat after some/all destination stock has been sold or consumed, and after a
   later invoice changes receipt cost. Check for cyclic applications on return moves.
4. Cover FIFO layers, zero stock, already-negative stock, reverse direction,
   same/different inventory accounts and the supported costing/tracking methods.
5. Inject failure on the second leg; retry; verify no partial or duplicate posting.
   Verify earlier committed pairs survive and subsequent Entry Nos. remain blocked.
6. Verify inventory-period closing after the actual shortage has been resolved.

No production posting changes or runtime experiments were made in this investigation.
The available local symbols are 28.1; the failing environment reports 28.4, so final
validation must use that environment's version.

## Microsoft references

- [Item application](https://learn.microsoft.com/en-us/dynamics365/business-central/design-details-item-application)
- [Fixed applications and open item ledger entries](https://learn.microsoft.com/en-us/dynamics365/business-central/finance-how-to-close-open-item-ledger-entries-resulting-from-fixed-application-in-the-item-journal)
- [Cost adjustment](https://learn.microsoft.com/en-us/dynamics365/business-central/design-details-cost-adjustment)
