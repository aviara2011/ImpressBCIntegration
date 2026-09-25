# I/I source identity verification

Status (2026-09-15): the user's implementation specification supersedes the original matching proposal below. Version 1.0.0.75 matches ITEM lines by source database, originating order, Raw SKU, size position and mapped Item/Variant. Invoice line/sequence, quantity and price are not identity. Production and test packages compile; BC runtime acceptance and a source-wide duplicate-SKU audit remain pending. See [current implementation and validation](ii-line-matching-1.0.0.75.md).

## Historical investigation (superseded matching proposal)

The required match is Source Line No. + Source Sequence + Size Position, scoped to the original source database and Sales Order. Resolve the original staged Sales Order line first; then use its BC Line No. to locate the resulting BC Sales Line. Sales Document Entry No. scopes the invoice staging records only. It is not an original Sales Order line key.

ITEM expansion must retain one line per populated size position. CHARGE/non-item expansion must retain one line per source SORDERD row with Size Position = 0. No alternative match by BC Line No., item, variant, quantity, description, or ordering is permitted.

## Repository evidence

- Table 80010 stores all three identity fields as Integer. Its unique source key is Source Database + Source Sales Order Detail ID + Size Position. Its SourceOrder index includes Source Sales Order ID and the three requested identity fields, but does not enforce uniqueness of that composite.
- Table 80014 stores the same three fields as Integer. Its unique source key is Sales Document Entry No. + Source Line No. + Source Sequence + Size Position.
- API pages 80021 and 80028 bind sourceLineNo, sourceSequence, and sizePosition directly to their respective staging fields. Neither API computes those values or demonstrates which underlying SQL columns supplied them.
- Codeunit 80016 uses the three source fields to order existing staged Sales Order lines when reserving BC line numbers. This does not prove equivalence of the two SQL extractions.
- The draft ResolveStagedOrderLine in codeunit 80029 filters by the source database, original Source Sales Order ID, and the three source identity fields, requires exactly one result, and only then reads BC Line No. The draft has not yet been integrated into the transaction processor or validated by compilation/runtime testing.
- A repository search, including hidden and ignored files, found no SQL extraction scripts. No configured Impress query tool is available in this session. Therefore, no upstream field discrepancy has been established, and equivalence cannot yet be verified.

## Evidence still required

Obtain both extraction queries/views/procedures, including ITEM size expansion and CHARGE/non-item projection, and compare the underlying expressions for each identity field. Check that the original Sales Order scope is retained and that the composite resolves exactly one staged Sales Order line.

Query the actual header and all invoice lines for invoice 341759, together with the original staged Sales Order S143822 lines and their source identities. The known inventory activity dated 2026-05-01 includes D120ART SM -1, MD -6, LG -2, 2X -2 and A120GRV SM -5. These rows do not establish invoice prices, discounts, tax, non-item lines, or the stated 1,298.29 total. Do not synthesize those amounts as evidence for this invoice.

## Supplied example: invoice 341760 / Sales Order S142846

Reviewed `C:\Users\aviara\Downloads\S142846 Example.xlsx`. It contains five sheets: inventory transactions, invoice header, invoice lines, Sales Order header, and Sales Order lines. The invoice header identifies ImpressTest, customer 10154, original order S142846, and staging entry 4. The Sales Order header identifies source order ID 172639 and BC order SO05546.

Observed source-line discrepancy (product comparison is diagnostic evidence, not an authorized matching fallback):

| Product | Invoice Source Line No. | Invoice Source Sequence | Invoice Size Positions | Sales Order Source Line No. | Sales Order Detail ID |
| --- | --- | --- | --- | --- | --- |
| A004IND | 1 | 1 | 1–5 | 3 | 657487 |
| A603MRB | 2 | 2 | 1–5 | 5 | 657489 |

Sales Order line 1 instead contains A094BAU, and line 2 contains A094LAV. Source Sequence is absent from the Sales Order line export. The invoice's apparent document-local numbering cannot establish the original Sales Order identity; the SQL expressions remain unknown. Do not join these records using the unverified composite or any item-based fallback.

The invoice has ten ITEM rows linked individually to inventory IDs 8762743–8762752. Each linked inventory row has matching item and variant, the opposite quantity, location WIP, date 2026-05-01, and related sales document entry 4. Invoice item quantities total 64. Item amounts total 997.00. One CHARGE row has source line/sequence 3/3, Size Position 0, BC Item No. SHIP, quantity 1, amount 155.19, and related inventory ID 0. Thus the exported line amounts total 1,152.19, matching the header, whose Tax Total is 0. This proves arithmetic consistency of this example only, not BC posting or invoice 341759.

Additional constraints observed:

- The order line export contains 38 ITEM rows and no CHARGE row corresponding to invoice shipping. No exact original staged charge-line identity can be established from this export.
- Invoice A603MRB 2X quantity is 1; the order's corresponding product/size row has quantity 2. Invoice quantities must control invoicing after source identity is established.
- Invoice header G/L Post Date is blank, although Invoice Date and inventory G/L dates are 2026-05-01. The current draft requires a populated G/L Post Date; do not silently infer one without an established date rule.
- The order header location is M while the related invoice inventory rows are WIP. Actual BC Sales Line locations are not included in this workbook.
- Invoice line staging Entry No., Sales Document Entry No., and source database columns are absent from the exported invoice line sheet. Its association with the invoice is supplied by workbook context and linked transaction evidence, not those omitted columns.

Required next evidence: both source extraction projections and joins, including how the invoice source line/sequence relates to SORDERD and its detail ID; the Sales Order lines with Source Sequence; and the rule/source relationship for invoice-only shipping charges. No matching algorithm changes were made in response to this workbook.
