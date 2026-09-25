# T/G validation

## Build

```powershell
.\scripts\Build-TG.ps1 -IncludeTests
```

Produces Techstyle_Impress BC Integration_1.0.0.71.app and the separate
Techstyle_Impress TG Tests_1.0.0.6.app. Test objects use TG_TESTS and are excluded
from production. Temporary build projects exclude research downloads.
CompilerPath/DotnetPath can be overridden.

## Automated tests

Use an isolated initialized sandbox company. Run codeunit 80096 Impress TG Test Runner,
which runs 80099 Impress TG Tests (70 tests) and 80097 Impress Profile Tests (13 tests).
The runner uses TestIsolation = Function, required to isolate the AutoCommit tests
that verify real orchestration commit boundaries. Do not run those tests without
function isolation: they create and commit fixture data. Pair-level tests call the
atomic engine under AutoRollback; 80098 supplies manually bound failure injection.

The company needs General Ledger Setup, Inventory Setup and an allowed WorkDate,
with no Impress inventory staging or existing IMP/IMI profiles. Avoid collisions
with TG/DP fixture codes, including TGTEST, TGBASE, TGBUS, TGADJ, DPBUS, DPA, DPB
and DPC. Fixtures create accounts, locations, setup and standard opening inventory.

The 83 tests cover:

- Per-pair commit for selected and source processing: invalid account setup in the
  second pair preserves the first, rolls back both failed rows, stops later rows,
  and prevents a manual action from jumping over the failed pair.
- SKUTRANS_ID ordering within each source, independent of staging arrival and page sort.

- CATEGORY in either global dimension slot: preview preserves both dimension sets
  and shortcut fields; posting preserves CATEGORY and global fields on both sides.

- Selected T/G batches with descending page order and marked rows, automatic
  partner inclusion, processed-row retries, earlier unselected blockers and
  existing I/I handler errors preserving earlier commits, and SKUTRANS_ID ordering.

- Standard transfers, either selected side, reverse direction, same-account zero
  G/L entries, different-account entries and multiple FIFO layers.
- Both source streams, overlapping source IDs and processor dispatch.
- Real persistent preview without ledgers or final staging fields; repeated preview
  and posting reuse GUID/line/number, including a separate posting series.
- Deleted preview regeneration with a new GUID/number and profile reuse.
- Adjustment-account resolution, required business group and invalid accounts.
- General signatures matching all/only required fields, future multi-account
  signatures and invalid account-field metadata.
- Complete inventory profiles, direction, immutable incomplete/conflicting profiles.
- Independent numbering, malformed codes, business-group scope, standard-profile
  exclusion, exhaustion and exact reuse at capacity.
- Changed prepared setup, edited journal and number tampering.
- Duplicate retries, missing-link repair, partial evidence and posted-evidence preview.
- Rollback and retry, including retention of previously committed preview state.
- Source sequence, pairing, series, variants and CATEGORY validation.
- Preserved Transaction Handler and Item Card groups.

## Interactive checks

1. Configure the new first Defaults field to an existing group such as IMPRESS.
   Preview a real pair; inspect the journal, posting groups/accounts and number.
   Repeat Preview then Process and confirm unchanged GUID/number and both rows complete.
2. Allocate other documents between preview and posting. Confirm the preview number
   remains unchanged; check ordinary nonintegration journal numbering too.
3. Delete/recreate a preview; confirm both IDs clear and a new GUID/number is allocated.
4. Concurrently preview matching and different signatures across both source streams.
   Confirm safe allocation/reuse without overwritten profiles. Also process one pair
   concurrently and check safe retry with no duplicate posting.
5. Run Find Entries from both completed rows; test missing posted number/date messages.
6. Exercise real item tracking, bins and warehouse requirements. Standard BC errors
   must propagate and leave the transaction retryable.
7. Exercise automatic adjustment and deferred inventory cost posting; additional
   entries must remain traceable to the original GUID.
8. Delete/recreate old unposted preparations lacking reservations. Reconcile historical
   posted GUIDs without renaming/reposting; handle pre-1.0.0.62 manual postings separately.

## Workspace results

Production 1.0.0.71 and test extension 1.0.0.6 compile against cached BC 28.1 symbols. Runtime tests have not executed: no sandbox test connection is configured. No package has been published. See [the shortage implementation and test additions](TG-shortage-implementation.md) for the new coverage and BC 28.4 runtime checks.
