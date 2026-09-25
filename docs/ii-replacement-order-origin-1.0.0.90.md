# Explicit invoice origins on replacement orders — 1.0.0.90

Invoice 341789 exposed a regression in 1.0.0.89: ResolveOrder correctly reported a missing original BC order and PostDocumentAtomic created a replacement, but the matcher then rejected the populated originating line because order staging had intentionally been cleared.

Codeunit 80029 PrepareOrder now calls Codeunit 80034 ResolveForNewOrder only when ExistingOrder is false (the branch where PostDocumentAtomic just created the header). Existing orders continue through Resolve and retain strict originating staged-line validation. The matcher shares its implementation through ResolveInternal; the new entry point checks the order's integration posting ID and source against the invoice. Originating line metadata remains on invoice staging.

On a newly created order, lines are built from the invoice using the existing validated item/resource creation path. Candidate reuse requires the same invoice staging Entry No. correlation; another invoice line with the same SKU and size cannot be accidentally reused. References to physical lines on a deleted order do not constrain its newly created replacement. Existing-order reference and SystemId checks are unchanged. Duplicate-posting evidence checks, rollback, tax, posting profiles and transaction-derived locations are unchanged.

Changed objects: Codeunit 80029, Codeunit 80034, test Codeunit 80095. App version 1.0.0.90. Production and test package 1.0.0.16 compile successfully against cached BC symbols; BC runtime tests have not run. The added test covers populated origins on the new-order path, stale deleted-order references, distinct repeated-SKU invoice lines, correlation reuse, and continued rejection on the existing-order path. Existing explicit-origin tests continue to compile.

No SQL or PowerShell files were changed. No extension was published and no invoices were processed. After publishing, manually preview invoice 341789 and confirm the replacement order lines, IMP posting profiles and transaction locations before processing. Invoice 341781 on an existing order should continue to resolve explicit origin 35 to BC line 1590000.
