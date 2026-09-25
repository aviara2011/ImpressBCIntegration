# Customer multiple posting groups — 1.0.0.78

Invoice preparation enables Allow Multiple Posting Groups on the actual bill-to customer before validating the order's invoice-specific Customer Posting Group. It uses normal Customer field validation and Modify(true), and skips the write when already enabled. The customer's default posting group remains unchanged. Standard BC posting-group validation continues to run.

The update occurs inside the existing atomic posting transaction: successful posting persists the customer setting; posting failure and standard posting preview roll it back. No global Sales & Receivables Setup settings are changed.

Production compilation passed against cached BC 28.1 symbols. Runtime verification remains pending: preview and post an invoice for customer 10154 with the flag initially disabled; check the flag is preserved after preview and enabled after successful posting. Also check an order with distinct sell-to and bill-to customers uses the bill-to customer.
