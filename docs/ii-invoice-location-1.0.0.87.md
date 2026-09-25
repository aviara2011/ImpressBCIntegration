# Invoice transaction location — 1.0.0.87

Invoice 341760 (ImpressTest) failed because existing Sales Order SO05546 line 110000 had location M, while the linked inventory transaction's BC Location Code was WIP. The confirmed business rule is that the linked invoice inventory transaction determines the shipment location.

Codeunit 80029 PrepareLine now validates the sales line's Location Code against the linked transaction's BC Location Code whenever they differ, for both existing and new lines. It previously required an existing line's location to already match. WIP is not hard-coded. Inventory posting setup continues to use the same transaction location. Standard BC validation and the existing shipped-not-invoiced and outstanding-quantity checks remain in force. Preparation remains inside the posting/preview transaction boundary.

Retest in ImpressTest after installing 1.0.0.87: preview invoice 341760, then process it once. Confirm the affected shipment/invoice item lines and item ledger entries use WIP, and that unrelated order lines are not shipped. If standard BC location validation rejects reservations, warehouse activity, or prior shipment state, resolve that specific condition; this change does not bypass standard validation. A repeated process must reconcile the same posted invoice without duplicate posting.

Local validation: production package compilation. BC runtime preview/posting has not been executed from this workspace; no live records were changed.
