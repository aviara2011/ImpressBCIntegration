# Pending adjacent T/G pairing — 1.0.0.71

The reported rows 8762387/8762388 describe a valid movement of C672 / SND-LG:
WIP -6, M +6, inventory account 1310 on both rows, adjustment account 5099 from
the positive row, and CATEGORY AP through the existing ImpressTest mapping.
The supplied rows do not establish the status or ownership of preceding row 8762386.

The old matcher counted any adjacent row with matching movement fields. The fix
retains GUID-based ownership exclusion from 1.0.0.70 and adds a source-sequence
rule for two unclaimed matches:

- Existing shared GUIDs remain authoritative and undergo full ownership validation.
- A neighbouring row assigned to another pair is excluded even when still Pending.
- Posted rows without a GUID cannot be adopted into a new pair.
- With two unclaimed matching neighbours, select the preceding neighbour only when
  it is the earliest unresolved row in that SourceDatabase. This handles selecting
  the second row of the first pending adjacent pair without consuming the first
  row of the next pair.
- If an earlier unresolved transaction exists, stop with its Source Transaction ID
  and a source-sequence error. Never skip it to resolve apparent ambiguity.

The rule uses neither odd/even source-ID parity nor an assumption that negative
rows must occur first. Item, variant, date, order/line, signs, quantities, locations,
source database and posting-ID ownership validation remain unchanged. Source IDs
are never compared across the two source streams. No posted entries or staging
statuses are rewritten as part of this change.

Install 1.0.0.71 and retry the selection. Valid unposted previews do not require
deletion. If an earlier pending transaction blocks 8762387/8762388, process that
earlier pair first; do not reset or mark it processed manually.

Regression tests cover posted and previewed neighbours, all-pending consecutive
pairs selected from either side, blocking an attempt to skip an earlier pending
pair, a processed neighbour without a GUID, and one-sided GUID recovery without
reposting. Production and test extension 1.0.0.6 compile against cached BC 28.1.
Runtime tests have not executed because no sandbox connection is configured.
