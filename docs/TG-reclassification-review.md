# T/G manual journal preparation — 1.0.0.58

Process Transaction on Impress Inventory Transactions prepares one item reclassification journal line. It does not post or mark either staging row Processed. Select either side of the pair.

## Setup

In Impress Defaults → Inventory Transactions, configure:

| Field | Requested value |
|---|---|
| Impress Reclass Journal Template | IMPRESS |
| Apparel Reclass Journal Batch | APPAREL |
| Stickers Reclass Journal Batch | STICKERS |

The template must exist with type Transfer, and both batches must exist under it. The handler reads these values; it does not create templates/batches. Configure the existing Category Dimension Code and mapped dimension values (AP for ImpressTest; ST/HG for StickersTest).

The batch number series supplies Document No. If no number series is configured, the posting reference is TG-RECLASS. Neither value participates in duplicate detection. Source Order No. is preserved in External Document No.; overlength values cause an error rather than truncation.

## Account resolution

Negative quantity determines FROM; positive determines TO. One code is derived in that order: A1310-1320 or S1310-1320, for example. The reverse direction creates a distinct code. Equal accounts produce A1310-1310.

The same group is assigned to the journal line and both Inventory Posting Setup records. Each location/group record must use that side's Source Inventory G/L Account. Existing conflicting accounts cause an error; they are never replaced. Item cards and the other source G/L account fields are not changed or used.

## Preparation identity

Only Integration Posting ID links the pair to its journal line. Both staging rows receive the same newly generated GUID. Prepared is a calculated display on the staging page based on whether that journal line exists. Staging status remains Pending.

Processing again while the line exists reports Already Prepared. Deleting the line makes Prepared false on page refresh; the next preparation replaces the old GUID with a new one. If multiple journal lines share a GUID, or the pair has inconsistent IDs while a referenced line exists, processing stops.

This mode does not reconcile posted ledger entries. As requested, a removed journal line permits preparation again; do not treat preparation as a record of completed posting.

## BC acceptance checks (not yet executed)

Use a sandbox with an inventory item, valid variant and available quantity/cost at the FROM location. Record the item's permanent inventory posting group before testing.

1. Create adjacent T/G rows in ImpressTest with quantity -5 at M/account 1310 and +5 at WIP/account 1320, matching item, variant, date and source order. Process the positive row. Expect one Transfer line, quantity 5, M → WIP, posting group A1310-1320, and one shared nonblank GUID on both rows and the journal line.
2. Verify setup M/A1310-1320 = 1310 and WIP/A1310-1320 = 1320. Run Posting Preview. Verify negative and positive item entries and the inventory G/L credit/debit to the respective accounts. G/L preview depends on standard inventory cost posting configuration. Verify preview leaves the journal and staging intact and creates no permanent ledger entries.
3. Process the negative row. Expect Already Prepared and no second journal line.
4. Delete the unposted journal line. Refresh staging and confirm Prepared is false. Process either side again. Expect one replacement line and a new shared GUID.
5. Test reverse direction, equal accounts and StickersTest. Expect A1320-1310, A1310-1310 and S1310-1320 respectively; verify the correct batch each time.
6. Precreate a conflicting location/group setup. Preparation must fail with source database, both transaction IDs, expected account and actual account; no new journal or partial preparation should remain.
7. Test a missing partner, two valid adjacent partners, mismatched item/variant/date/order, zero/unequal quantities, equal locations, missing or invalid item/variant/location, blank/missing/blocked/non-posting inventory account, overlength group code, and missing template/batch. Expect an error and no new journal line.
8. Change only Source Adjustment G/L Account, Source Offset G/L Account and Source G/L Account. They must not affect the derived group or inventory accounts.
9. Verify the item's permanent inventory posting group is unchanged, the FROM and TO category dimensions follow the existing mapping, and neither staging row becomes Processed.
10. In two sessions process opposite sides concurrently. Expect one journal line for the pair; the second session must report Already Prepared after the first commits.

Validation completed in development: extension compiled against the local BC 28.1 symbols, without errors or warnings. No BC service is connected for running the above checks.
