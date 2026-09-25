# Transaction posting

Current version 1.0.0.71 fixes adjacent T/G pairing through GUID ownership and earliest-unresolved source order. See [pending pair matching](docs/TG-sequence-pairing-1.0.0.71.md). CATEGORY defaults from 1.0.0.69 remain in place.

Version 1.0.0.69 restores the established CATEGORY mapping, including blank Division Code: ImpressTest = AP; StickersTest blank/STK = ST; HG = HG. See [CATEGORY correction](docs/CATEGORY-1.0.0.69.md) for preview regeneration and validation. This supersedes the blank-division removal described below.

Version 1.0.0.68 adds atomic T/G availability splits, configurable Item Journal
setup, and A/A adjustment posting. See [the implementation summary](docs/TG-shortage-implementation.md)
for objects, setup, preview migration, reconciliation, standard posting review and tests.

Current ordering is Source Database / Source Transaction ID (SKUTRANS_ID), with
independent streams. Blank Division Code produces no CATEGORY for inventory
transactions. These explicit requirements supersede the historical behavior below.

Production and test packages compile against BC 28.1; sandbox runtime tests have
not run and no package was published.

## Historical implementation notes (through 1.0.0.67)

Version 1.0.0.67 commits after each inventory transaction or matched T/G pair,
for Process Transaction, Retry Error, Process Selected Transactions and both source
Job Queues. Posting and reconciliation remain atomic inside the pair. A later
exception rolls back only that transaction/pair and stops processing; earlier
completed postings stay committed. Failed rows remain unresolved and block later
entries on retry. Job Queue handler errors now propagate instead of returning normally.

Ordering is ascending Entry No. within each source database, not Source Transaction
ID. Existing source-ID matching still identifies T/G partners. An unresolved entry
before or between paired rows blocks posting. Preview retains its no-posting behavior.

Version 1.0.0.66 synchronizes both FROM and TO shortcut dimension fields from
their dimension sets before inserting a reclassification journal. CATEGORY mapping
is unchanged whether CATEGORY is a global dimension or an ordinary dimension.
The standard New Dimension Set ID field has no validation trigger to synchronize
the TO shortcut fields; blank fields otherwise remove global CATEGORY on insert.

Version 1.0.0.65 updates Process Selected Transactions to use existing handler errors
for transaction types whose posting is not implemented, without a T/G-only restriction.
Select the desired T/G rows (for example, May 1, 2026 before the first I/I row).
The action snapshots the selection, sorts by Entry No.
regardless of page sort, and posts each pair once. Selecting either side includes
its matching partner. Already Processed rows are skipped. Unselected earlier
unresolved rows still block posting. Non-T/G rows use their existing handler errors
when reached in source order; this action never dispatches the entire source stream.
Each transaction/pair commits independently; the selection is not one atomic batch.

Version 1.0.0.63 implements shared T/G preview, dynamic setup and standard BC posting.

## Configuration

Set Impress Defaults."Gen. Bus. Posting Group (Inv.)", the first Inventory
Transactions FastTab field, to an existing business group (currently IMPRESS).
The group is required, never hard-coded or auto-created, and independent of the
journal template. Configure a non-recurring Transfer template, source-specific
batch and batch No. Series.

## Accounts and profiles

The negative row is FROM; the positive row is TO. Pairing remains adjacent within
one source database with matching item, variant, date, source order/line and equal
opposite nonzero quantities. Locations must differ. Transport status and source
sequence validation remain enforced.

Source Inventory G/L Account determines each location's Inventory Account.
Source Adjustment G/L Account determines Inventory Adjmt. Account: ignore one
blank side, accept identical nonblank values, reject both blank or conflicting
values. All required accounts must exist, be unblocked Posting accounts before
setup creation. Other source account fields do not participate in T/G's signature.

Codeunit 80026 provides reusable resolvers. General requirements are a dictionary
of General Posting Setup account field numbers and accounts. Under the configured
business group, reuse an IMP001..IMP999 profile matching all required fields;
unrelated fields are ignored. Otherwise create the next global numeric IMP code
and assign only the required account fields.

Inventory requirements are the complete location/account dictionary. Reuse an
IMI001..IMI999 profile satisfying every required mapping. Incomplete/conflicting
profiles are never extended or overwritten; create a new complete profile instead.
Unrelated mappings do not prevent reuse. Both searches span source streams.

Allocation uses shared locking and a second search before creation. IMP and IMI
sequences are independent, highest valid numeric suffix plus one, with errors at
exhaustion. Malformed codes are excluded. New descriptions equal codes.

Journal fields are assigned after item validation: configured Gen. Bus. Posting
Group, resolved IMP Gen. Prod. Posting Group and resolved IMI Inventory Posting
Group. Item Card groups and Transaction Handler remain unchanged. Existing
CATEGORY mapping and independent FROM/TO dimensions are preserved.

## Preview, numbering and posting

The page calls engine 80018 PreviewTransaction or ProcessTransaction; both use
80021's shared preparation. Source job queues continue through ProcessTransaction.
Preview creates persistent setup and one real journal line with a GUID shared by
both staging rows. Rows remain Pending without final posted fields; no ledger
entries are created. Repeated preview revalidates and reuses the same preparation.

Codeunit 80027 consumes one standard batch No. Series number during preparation.
Table 80018 stores the allocation by GUID and journal SystemId. Process validates
and reuses that exact number. Scoped standard posting subscribers prevent second
consumption or replacement by a separate Posting No. Series. Ordinary journals
without reservations retain standard numbering behavior.

An existing preview's source, assigned profiles, dimensions, journal and number
reservation are revalidated before posting. Changed requirements cause an error,
not silent profile replacement. Without a prepared line, Process prepares and posts.
Deleting an unposted journal clears matching Pending/Error staging GUIDs when no
posted evidence exists. Recreating it uses a new GUID and new number; reusable
profiles and allocation history remain. Reservations are not posted evidence.

The GUID is the sole technical idempotency/correlation key. Standard
Item Jnl.-Post Batch runs with primary-key/GUID filters, SetSuppressCommit(true)
and non-Boolean Run. CommitBehavior is Error. There is no manual ledger insertion,
write-enabled TryFunction or internal commit within pair posting. The outer engine
commits only after a complete pair succeeds. Initial pair failure rolls back setup,
journal, numbering and staging changes. Failed Process after successful Preview
retains that previously committed preparation and number. BC errors propagate.

Codeunit 80024 propagates GUIDs to item/value entries and maintains Table 80016
links, including G/L links through G/L - Item Ledger Relation. Codeunit 80025
reconciles actual entries, profiles, dimensions and aggregate quantities before
both staging rows become Processed with identical posted references/timestamps.
Multiple FIFO layers and zero G/L entries are valid. Find Entries uses the actual
posted document number/date. Later adjustments and deferred G/L posting retain links.

Valid posted evidence is reconciled without reposting; Preview of posted evidence
does not complete staging. Inconsistent evidence or GUID ownership errors block
reposting. No journal/evidence allows new preparation; Processed without evidence
requires reconciliation. Table 80017 serializes dynamic profile allocation.

## Upgrade and validation

Delete/recreate old unposted preparations lacking IMP/IMI profiles or reservations.
Posted 1.0.0.62 entries use their actual historical profiles during reconciliation
when required accounts still match; profiles are not renamed and entries are not
reposted. Manual postings before 1.0.0.62 lack ledger GUIDs and require manual
reconciliation before retry. Document/source numbers cannot replace GUID evidence.

Other transaction handlers retain their preflight behavior. Build with
scripts/Build-TG.ps1 -IncludeTests. See [test instructions](docs/TG_TESTING.md).
Runtime posting/concurrency tests have not run and no package was published.
