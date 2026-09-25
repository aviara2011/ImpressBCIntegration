# T/G shortage posting — version 1.0.0.68

## Objects and setup

Table 80002 and page 80004 add three configurable fields in Inventory Transactions:

| Field ID | Field | Relationship |
| --- | --- | --- |
| 180 | Impress Item Journal Template | Item Journal Template.Name |
| 190 | Apparel Item Journal Batch | Item Journal Batch.Name, filtered by the new template |
| 200 | Stickers Item Journal Batch | Item Journal Batch.Name, filtered by the new template |

The shared preparation codeunit 80021 resolves Item templates and batches for both
A/A and T/G adjustments. It validates nonblank names, existence, nonrecurring Item
template type, and batch No. Series. Transfer components continue using the existing
Transfer template and source-specific reclass batches. Only the journal types used
by the proposed transaction require setup. No template or batch name is hard-coded.

Codeunit 80018 dispatches A/A to the shared preparation codeunit. Source-specific
codeunits 80019/80020 are unchanged. This checkout had an unimplemented A/A handler;
there was no existing A/A posting implementation to update. The new handler uses
the source inventory and adjustment accounts, CATEGORY, dynamic profiles, standard
item posting, GUID tracking, and reconciliation, with one positive or negative
adjustment according to the source sign.

New table 80019, Impress Journal Component, records each journal SystemId, document,
series, entry type, quantity, availability, split and source snapshot under one GUID.
The original table 80018 is retained without a key change and keeps the primary
logical document reference. Codeunit 80027 reserves each component number using its
selected batch's standard No. Series. The adjustment components can have distinct
numbers; all detailed resulting entries/documents are linked in table 80016.

New codeunit 80028 posts the ordered components. Codeunit 80024 restricts posting of
prepared components to that active scope. Codeunit 80025 reconciles both transfers
and adjustments. Permission set 80000 grants access to the new objects. Page 80029
has updated preview help, and page extension 80002 exposes the GUID and inventory
posting group on Item Journal. Table extension 80002 and ledger GUID propagation
remain unchanged.

## Availability and split

`GetAvailability` locks Item and Item Ledger Entry and sums actual signed Quantity
for the exact item, variant and FROM location. There is no date, positive, open-entry
or remaining-quantity filter. Locks remain held through posting and reconciliation.
`CalculateSplit` computes:

```
requested = abs(FROM source quantity)
transfer = min(requested, max(available, 0))
shortage = requested - transfer
```

`PrepareComponent` and `BuildJournal` create transfer, negative adjustment and
positive adjustment, in that order, omitting zero components. FROM and TO retain
their respective CATEGORY dimensions and source inventory accounts. The existing
account resolver validates the agreed adjustment account and resolves IMP/IMI
profiles without modifying Item Card posting groups.

BC Negative Adjmt. journal Quantity is positive: BC's `Item Journal Line.Signed`
converts it to negative Item Ledger Entry quantity. Entering -1 on a Negative
Adjmt. line would increase inventory. Thus the requested physical -1 FROM leg is
represented by Negative Adjmt. Quantity **1**, and reconciled as ledger quantity -1.

The positive adjustment refreshes Unit Amount/Unit Cost from the BC Item's current
Unit Cost immediately before posting. No source cost or applies-to/applies-from
link is assigned. BC maintains average inventory unit cost for non-standard items;
standard-cost items remain subject to BC standard-cost validation. See Microsoft's
[unit cost calculation documentation](https://learn.microsoft.com/en-us/dynamics365/business-central/finance-about-calculating-unit-cost).
There is no custom subsequent revaluation or transfer-cost correction.

## Atomicity and standard posting review

`ProcessTG`, `ProcessAA`, and `PostComponents` run under CommitBehavior::Error.
Each component uses a fresh Item Jnl.-Post Batch instance, exact journal primary-key
and GUID filters, SetSuppressCommit(true), and non-Boolean Run. All components and
reconciliation remain inside the same database transaction. Only the existing outer
ProcessTransaction orchestration commits after the entire transaction succeeds.
No compensation, Boolean codeunit Run boundary, or write-enabled TryFunction was added.

Review of the available BC 28.1 standard AL sources found:

- Item Jnl.-Post Batch's three explicit commits are guarded by SuppressCommit.
- Its RunWithCheck invocation calls an ordinary procedure, not Boolean Codeunit.Run.
- Item Jnl.-Post Line and Inventory Posting To G/L have no explicit commit in the
  reviewed sources. Warehouse posting is a non-Boolean Run.
- Automatic inventory adjustment is online. Inventory Adjustment disables its
  item-by-item commit flag for online adjustment.
- The inspected Update Analysis View posting path has no explicit commit.

No standard object was modified. Unsuppressed batch posting and journal-page posting
of reserved components are avoided. Unexpected commits from another extension fail
under the commit guard. Installed BC 28.4 and third-party subscribers still need
sandbox runtime verification; compilation against 28.1 is not proof of that behavior.

Duplicate protection is scoped with a manually bound subscriber holding the current
GUID and current journal SystemId. It permits only that component, including later
components after the first has created ledger evidence. The scope is local to the
call, not a SingleInstance session flag. Outside it, reserved components cannot post
through the journal page. Retry with evidence enters reconciliation before posting.

## Preview, deletion and reconciliation

Preview persists all required real journal lines and snapshots but no ledgers or
final staging references. Repeated Preview reuses the same GUID, journal SystemIds,
numbers and validated split. Processing rechecks exact availability, even if a
change would leave the split unchanged, and validates requested/split quantities,
source IDs, item, variant, locations, date, source accounts/order, CATEGORY, profiles,
dimensions, journal setup and number reservations. A stale preview requires deleting
all its unposted journal lines and running Preview again.

Deleting only one component does not clear staging ownership while others remain;
the incomplete preview cannot post. Deleting the last component with no posted
evidence clears both pending/error staging GUIDs. Regeneration gets a new GUID and
new numbers; valid dynamic profiles are reused. Legacy unposted previews without
availability snapshots must also be deleted and recreated. Historical posted
transfer GUIDs continue to reconcile using their actual historical profiles.

Reconciliation validates each entry's type/location, document reservation, item,
variant, date, dimensions, value-entry profiles and GUID; then checks each reserved
component's aggregate quantity plus total FROM/TO source quantities and posting
links. Only then are both T/G rows marked Processed with identical timestamps and
the primary Item Reclassification reference. A/A uses Item Journal as its type.

## Explicit differences from the prior checkout

The prior implementation ordered by staging Entry No., despite pairing on source
IDs. Per this request, dispatch, selected processing and earlier-row validation now
use Source Database / Source Transaction ID (SKUTRANS_ID), never comparing source IDs
across databases. Deterministic adjacent-source-ID pairing is unchanged.

The prior CATEGORY helper mapped blank division to AP/ST. Per this request, blank
division removes CATEGORY on inventory transaction components; nonblank division
mapping and other integration flows retain their existing behavior.

## Validation

Build with `scripts/Build-TG.ps1 -IncludeTests`. Production version is 1.0.0.68;
the test extension is 1.0.0.3. The suite adds full/partial/zero/negative availability,
both source batches, stale availability (including unchanged split), failures after
negative and positive adjustment posting, manual posting rejection, incomplete and
abandoned previews, A/A in both directions for both streams, blank CATEGORY,
source IDs arriving out of order, and missing item-batch setup.

The real-world fixture uses A004 / BAS-SM, M to WIP, source IDs 8762353/8762354,
quantity 5 and initial M stock 4. It asserts transfer 4, adjustments 1 each, one GUID,
final M=-1, and WIP +5. It is an isolated test fixture, not a posting to the live pair.

Production and test packages compile. Runtime tests have **not** executed: the test
runner connection is blank and the launch profile targets Production. No package
has been published or live inventory posted. Run codeunit 80096 in an initialized,
isolated sandbox matching deployment, including normal negative-inventory, tracking,
warehouse, automatic cost posting, and concurrent stock changes. Standard BC negative
inventory restrictions are respected; the tests explicitly permit negative stock.
