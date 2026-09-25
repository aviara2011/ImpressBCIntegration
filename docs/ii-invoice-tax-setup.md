# Shared Impress tax setup and invoice reconciliation

Codeunit 80035 "Impress Tax Resolver" contains the common Tax Group, Tax Area,
Tax Jurisdiction, Tax Area Line, and Tax Detail rules previously embedded in
Sales Order codeunit 80016 and duplicated in invoice codeunit 80029. Both
processors now call the same setup functions through their own staging adapters.

Sales Orders retain their existing group validation, blank-field handling,
Order Date/WorkDate effective date, and header/line assignment behavior.
Invoices use only Sales Document header/line tax snapshots, with the resolved
G/L posting date. Existing matching resolves each actual Item or Resource line
before its staged Tax Group Code is applied. No source totals are rewritten.
Shipping classification comes from the staged line; Shipping Is Taxable is not
used to override that authoritative classification.

Existing rules are preserved: TAXABLE uses source rates; RES, NTS, GOV, NP, OOS
use zero. Other codes (including 6.0 and ES) can be stored but remain processing
errors, not inferred exemptions or substituted categories. Nonempty descriptions
and tax G/L accounts update existing setup as in the Sales Order implementation.
Existing area lines are not pruned. Matching effective rates are reused.

## BC-controlled difference validation

Codeunit 80032's manually bound posting scope captures the temporary invoice-
quantity Sales Line buffer supplied by Sales-Post.OnBeforeCalculateSalesTax.
After standard BC tax distribution, OnBeforePostSalesLines sums the calculated
buffer and validates against the staged Tax Total before sales lines are posted.
The VAT calculation branch reads the standard temporary VAT Amount Line buffer.
This uses BC's actual calculation for invoice quantities, including partial
orders, rather than recalculating tax using full order quantities.

The shared resolver calls standard Sales Tax Amount Line.CheckTaxDifference on
an unpersisted temporary record. That method enforces Sales & Receivables Setup
"Allow VAT Difference" and the applicable Currency "Max. VAT Difference Allowed";
local currency uses General Ledger Setup through Currency.InitRoundingPrecision.
Disabled differences require zero variance. A zero configured maximum remains
zero. No hard-coded tax tolerance or automatic adjustment is introduced.

Post-calculation reconciliation in codeunit 80033 uses the same BC tax check.
Net total retains the existing non-tax amount check against source invoice total
minus source tax; customer ledger amount is checked against actual posted gross.
Thus an allowed tax-only variance does not fail a second fixed gross-amount
check, while unrelated net/ledger variances remain errors. BC calculated tax and
gross amounts are posted unchanged; the source tax snapshot remains unchanged.
No tax-difference records or balancing G/L entries are generated.

All setup, validation, posting, and reconciliation retain the existing atomic
transaction and preview rollback boundary. No new commits or posting actions
were added. No SQL, transport, staging schema, API, matching, or inventory
processing changes are part of this refactor.

## Validation

Build production and tests with scripts/Build-TG.ps1 -IncludeTests. Existing
invoice tax setup tests cover no originating order, repeat setup, exemptions,
missing/invalid classification, rate history, and length rejection. Four added
cases cover local-currency limits in both directions, disabled differences,
zero limits, foreign-currency limits, and no persisted tax adjustment.

Compiled against cached BC 28.1 symbols. Runtime tests are not executed and no
package is published. Sandbox acceptance remains required for mixed Item/Resource
groups, partial invoice quantities, standard tax rounding, changed invoice tax
snapshots, preview rollback, and posting failure/retry. SQL staging and transport
are complete per the user's validated source contract; they were not modified.