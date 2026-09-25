# Invoice line matching — 1.0.0.75

## Implemented behavior

The originating order is resolved through Sales Order staging scoped by Source Database and Source Sales Order No. Updated in 1.0.0.76: if staging is absent, its BC Document No. is blank, or its BC order no longer exists, create a new BC order from the invoice and ship/invoice it through the existing atomic posting path. A missing unposted prepared order can also be recreated. Ambiguous order staging, mismatched existing orders and duplicate/partial posting evidence still report errors. Historical postings on the originating order alone do not prevent a new invoice from using a new order. Clear the order record before insertion so a failed lookup cannot supply its old primary key to the new order.

Codeunit 80034 matches ITEM staging lines by the resolved order, Raw SKU, Size Position, BC Item No. and BC Variant Code. Blank variants are supported. Invoice Source Line No., Source Sequence, quantity and price do not select candidates. Multiple staging candidates report an ambiguity with BC line numbers and source detail IDs. A unique staged candidate must point to an existing BC Order line of the expected type, item and variant; its SystemId is checked when available.

When staging has no candidate, the matcher checks actual order lines. Explicit invoice entry correlation or saved invoice-staging BC line references can identify a retry. Available source database, raw SKU, size and source detail correlation must agree. Otherwise exactly one matching Item/Variant (or Resource) line can be reused. Multiple possible lines report an error; no line is selected by quantity, price or ordering. A missing or replaced saved target reports an error.

If there is no candidate, the matcher creates a validated order line at the last line number plus 10000, with source quantity and price and integration correlation. CHARGE/non-item lines use the existing EnsureChargeResource logic and Resource sales lines. The posting preparation applies source posting setup, description, invoice amounts, location and CATEGORY from the linked transaction Division Code (header division for charges). It records the resulting BC line number and SystemId on invoice staging.

Matching and posting eligibility are separate. A partial invoice reuses its existing line. Existing outstanding/shipped-not-invoiced checks run after matching and cannot cause a replacement line to be created. Multiple invoice lines resolving to one BC line fail explicitly in PrepareOrder.

Preparation and posting run inside the existing atomic posting runner with commits suppressed. A failed posting rolls back newly created lines and their correlation together. If a correlated line already exists, retry reuses it. Successful reconciliation clears temporary invoice tags on remaining order lines; source raw SKU and size remain.

## Validation

Production package 1.0.0.75 and test package 1.0.0.8 compile successfully against cached BC 28.1 symbols. The invoice matching test codeunit contains 17 cases, including the ten specified S142846 size mappings, partial quantities, duplicate staging, actual-line ambiguity, blank variants, stale references, Item/Resource creation and retry, cross-source rejection, explicit retry correlation and quantity/price-independent ambiguity.

These are compiled tests, not executed BC runtime results. The workspace test runner connection is unconfigured. Runtime acceptance must include new-line rollback after a later posting failure, subsequent retry, CATEGORY/dimensions, partial posting and multiple invoice lines targeting the same BC line. No package was published by this change.

## Required source-data audit

The supplied S142846 Sales Order line export has 38 lines but omits Raw SKU (and Source Sequence). It cannot establish whether duplicate Raw SKU + Size Position + mapped Item/Variant combinations occur across SORDERD rows. No source SQL extraction or source database connection is available in this workspace.

Audit the expanded source order lines grouped by Source Database, originating order, Raw SKU, Size Position, BC Item and BC Variant; report groups with more than one distinct SORDERD detail ID, including those IDs and BC line numbers. If duplicates exist, obtain a stable originating detail identifier from the invoice source. Until then, multiple staged candidates remain an error. The synthetic duplicate test verifies this rejection behavior; it does not prove source-data uniqueness.
