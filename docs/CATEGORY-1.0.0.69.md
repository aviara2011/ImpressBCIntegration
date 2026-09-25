# CATEGORY correction — 1.0.0.69

Version 1.0.0.68 incorrectly bypassed the established source CATEGORY mapping when
Division Code was blank. That removed CATEGORY from both sides of the transfer and
from the negative/positive adjustment lines. The original request's blank-division
clause conflicted with preserving the existing mapping; the user's clarification
restores the established mapping.

Preparation and posted reconciliation now both use the existing shared resolver:

| Source database | Division | CATEGORY |
| --- | --- | --- |
| ImpressTest | Any, including blank | AP |
| StickersTest | Blank or STK | ST |
| StickersTest | HG | HG |

No mapping values are duplicated in preparation or reconciliation. FROM and TO
dimension sets and all four shortcut dimension fields remain synchronized before
journal insertion. A/A uses the same corrected preparation and reconciliation.

Install production package 1.0.0.69. For the unposted preview shown in the screenshots,
delete all three generated lines (one reclass line and two item journal lines), then
run Preview (No Posting) again from staging. Existing previews are deliberately
validated rather than silently rewritten; Process rejects missing CATEGORY.
The recreated ImpressTest preview must show CATEGORY=AP on both reclass dimension
columns and on each adjustment's Dimensions page. No posted ledger dimensions are
changed by this fix.

The test fixtures now use blank Division Code by default, exercising the source
defaults across transfer, shortage and A/A cases for both streams. The targeted
regression test checks AP on all three preview components and runs posting through
CATEGORY reconciliation. Production and test extension 1.0.0.4 compile against the
cached BC 28.1 symbols. Runtime tests have not executed; no sandbox is configured.

This correction supersedes the blank-division behavior documented for 1.0.0.68.
