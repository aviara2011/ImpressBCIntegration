# Alternative customer posting groups — 1.0.0.80

BC requires an Alternative Customer Posting Group relationship as well as the customer's Allow Multiple Posting Groups setting. Invoice preparation now resolves the IMC profile, ensures the current document group and bill-to customer's default group each permit that specific target, then performs normal Sales Header posting-group validation.

For the reported case this creates DOMESTIC -> IMC001. Subsequent invoices can create the required IMC-to-IMC relationship when an existing order already carries a previous invoice's profile. Existing relationships are reused, blank and identical source/target pairs are skipped, and no reverse relationships are added. Only valid integration IMC targets are accepted. The customer's default group and company-wide validation settings remain unchanged.

Alternative groups are shared BC setup, so the specific relationship is available to other documents using the same groups after successful posting. Creation stays inside the atomic invoice transaction: preview and failure roll it back; successful posting saves it.

Tests cover standard BC substitution validation before/after setup, retry without duplicates, no reverse/self relationship, and successive invoice profiles. Runtime execution remains pending.
