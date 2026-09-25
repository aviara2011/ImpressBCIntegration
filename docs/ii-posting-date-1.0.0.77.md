# Invoice posting date — 1.0.0.77

If the invoice staging G/L Post Date is blank, preview and posting derive it from the inventory transactions linked through the invoice lines' Related Inventory Transaction ID, scoped by Source Database. All linked transactions must have a populated, identical G/L Date. Missing links, missing dates or differing dates report an error. Invoice Date is not used as a fallback.

An existing invoice G/L Post Date is retained and the existing document validation still checks it against every linked transaction. The derived date is persisted with order preparation inside the atomic posting transaction. Preview and failed posting roll it back with the other preparation changes.

Production 1.0.0.77 and tests 1.0.0.9 compile successfully against cached BC 28.1 symbols. Four new tests cover consistent linked dates, conflicting dates, blank transaction dates and preservation of an existing posting date. Runtime execution in BC remains pending; nothing was published.
