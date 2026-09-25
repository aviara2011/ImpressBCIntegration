# I/I shipment-date message suppression — 1.0.0.84

Suppress the informational "Shipment Date ... is before work date ..." message while preparing and posting an I/I invoice's Sales Order, including preview. The manual posting scope now binds before PrepareOrder, so Sales Line buffers used by standard header validation are covered too. The subscriber handles only OnBeforeCheckShipmentDateBeforeWorkDate and only for the active order. Date values and other validations are unchanged. Ordinary sales processing outside the bound scope retains the standard warning.

The reported System ID mismatch for invoice 341760 is separate. No identity checks or posted-invoice reconciliation rules were changed. The user's report that the invoice was already posted requires checking the actual posted invoice and its Integration Posting ID against the staging header SystemId; no live BC records were inspected.

Validation: production package compiled successfully against local BC 28.1 symbols. Runtime verification remains pending: process and preview a historical I/I invoice; confirm no shipment-date popup, other errors remain visible, and ordinary sales entry still shows its standard warning.
