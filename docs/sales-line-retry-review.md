# Sales line error isolation — 1.0.0.59

Each sales line runs in its own rollback boundary. The header and reserved staging line numbers are committed before the line runs. A failure leaves that line in Error and continues with the remaining entries; successful lines remain Processed. The header remains Error until every line succeeds. Failed lines cannot leave partially inserted sales lines or partially changed resources/setup from that attempt.

Existing BC Line No. values are retained. Missing numbers are reserved before processing, in Source Line No., Source Sequence, Size Position and Entry No. order. If existing staged/BC numbers surround missing lines, the missing lines receive available numbers between those anchors. Numbers belonging to another sales line are not silently replaced with numbers at the end. A document without sufficient free space for the missing positions reports a sequence error.

These paths share the implementation: codeunit 80016, staging sales order Process, selected orders, selected lines and Retry Errors. Header/setup failures still prevent processing a document whose header cannot be prepared.

## BC acceptance checks (not yet executed)

1. Stage three sales lines in sequence. The middle line references missing variant IND-SM for DC003; the first and third are valid. Process the order. Expect first and third Processed, middle Error with the missing-variant message, and header Error. All three staging rows must have reserved BC Line No. values.
2. Create IND-SM for DC003 and rerun 80016. Expect the middle line at its reserved number between the successful lines, no duplicates, and the header Processed.
3. Repeat with supplied BC Line No. values and with zero BC Line No. values. Verify source sequence is retained in both cases.
4. Fail a line after SalesLine.Insert, such as invalid line-specific CATEGORY setup. Expect no empty/partial BC line from the failed attempt; later valid lines must still process.
5. Test two failing lines followed by a valid line. Verify separate error messages and that the valid line processes.
6. Retry an order created with an earlier extension version whose successful staging rows already have BC Line No. values. Existing lines must retain their numbers; missing positions must be reserved without renumbering existing lines.
7. Place a different BC sales line at a staged line's reserved number. Expect that staging line to report a collision and later lines to continue, rather than append the failed line elsewhere.
8. Delete an open linked sales order, then recreate it through staging. Reserved line numbers must survive deletion and be reused.

Development validation: AL compilation against local BC 28.1 symbols. A BC runtime is not connected for executing these cases.
