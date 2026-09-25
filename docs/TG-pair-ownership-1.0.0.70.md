# Adjacent pair ownership — 1.0.0.70

The 1.0.0.69 matcher counted both adjacent source rows based on movement fields,
even if one row already belonged to another logical transaction. For consecutive
identical pairs, the preceding pair's receipt can match the next pair's outbound
row as well as its real receipt does. This can produce the reported two-match error.
The telemetry alone does not establish the actual ownership of 8762386/8762388.

Codeunit 80021 now excludes candidates with a conflicting GUID or with a GUID owned
by a third staging row. This applies to posted transactions and unposted previews.
Processed rows lacking a GUID are also ineligible for a new pairing. The selected
row's existing GUID still takes priority, with full pair and ownership validation
afterwards. One-sided GUID recovery remains supported.

SourceDatabase isolation, adjacent SKUTRANS_ID matching, movement field validation,
source ordering, CATEGORY and posting behavior are unchanged. Two genuinely
unclaimed matching neighbours still stop rather than guessing a partner.

Tests cover consecutive identical pairs with a posted preceding pair, a previewed
preceding pair (which still blocks later processing through sequence validation),
two genuinely unclaimed matches, and one-sided posted-GUID recovery without reposting.

Install 1.0.0.70 and retry the selected transaction. This fix requires no deletion
of valid previews and no staging resets. If ambiguity remains, inspect source rows
8762385–8762388, including quantities, locations, processing status and GUIDs.

Production and test extension 1.0.0.5 are built against cached BC 28.1 symbols.
No sandbox runtime tests or live postings were performed.
