# R/P CATEGORY assignment — 1.0.0.97

R/P receipt preparation previously resolved posting groups and location without
assigning CATEGORY. It now applies the shared source/division mapping to the
receiving purchase line after location validation and before standard release:

| Source | Division | CATEGORY |
| --- | --- | --- |
| ImpressTest | Any | AP |
| StickersTest | Blank or STK | ST |
| StickersTest | HG | HG |

The configured Category Dimension Code is required. Other dimensions are
preserved, and standard Dimension Set ID validation updates shortcut dimensions.
The mapped value is checked again after release, before posting. Other purchase
lines retain their own categories. Already posted entries are not modified.

Production 1.0.0.97 and test extension 1.0.0.23 compile against cached BC symbols.
The regression test covers AP/ST/HG, replacing an existing category on subsequent
receipts, and preserving an unrelated dimension. Runtime tests have not run.
