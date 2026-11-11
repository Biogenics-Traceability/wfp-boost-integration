#!/usr/bin/env bash
# One GitHub issue per subcontract Schedule B acceptance criterion. Run once, from anywhere.
set -euo pipefail
R=Biogenics-Traceability/wfp-boost-integration
for l in "workstream-1:0E8A16:WFP↔BOOST integration (item 0)" "workstream-2:1D76DB:WFP / FID enhancements (items 1, 4, 5)" "general:BFD4F2:Applies to every deliverable" "acceptance-criterion:5319E7:Subcontract Schedule B"; do
  IFS=: read -r name color desc <<<"$l"; gh label create "$name" -R "$R" --color "$color" --description "$desc" --force >/dev/null
done
mk() { gh issue create -R "$R" --title "$1" --label "acceptance-criterion,$2" --body "$3" >/dev/null && echo "opened: $1"; }
W1="Workstream 1, item 0. Met when demonstrated to Arbos in the test environment (Schedule B). Acceptance follows subcontract §5.2: the submission names this criterion. Interface: INTEGRATION_GUIDE.md."
W2="Workstream 2. Met when demonstrated to Arbos in the test environment (Schedule B). Acceptance follows subcontract §5.2: the submission names this criterion."
G="General. Acceptance follows subcontract §5.2."
mk "B1 — Documented WFP→BOOST field mapping delivered and accepted" workstream-1 "$W1

A documented WFP→BOOST field mapping is delivered and accepted by Arbos, covering the WFP fields available today that correspond to BOOST schema elements. Starting point: ScaleCapacity's map of 2026-06-18 as carried into INTEGRATION_GUIDE.md §4."
mk "B2 — On project completion WFP transmits a BOOST-shaped record to /validate; receipt confirmed" workstream-1 "$W1

On a WFP project-completion event, WFP transmits a BOOST-shaped record to the validator /validate endpoint, and receipt is confirmed. Guide §1, §4, §5; test cases 1–3 and 7 in §7."
mk "B3 — WFP handles success and failure responses with the agreed retry-versus-failure behavior" workstream-1 "$W1

WFP correctly handles both a success and a failure response from the validator (demonstrated via test cases), applying the agreed retry-versus-failure behavior. Guide §5, §6; test cases 4–6 in §7."
mk "B4 — Service-to-service authentication; no credentials in client-visible code" workstream-1 "$W1

The integration authenticates to the validator API using the agreed service-to-service credentialing (bearer token per environment), with no credentials hard-coded in client-visible code. Guide §3; test case 8 in §7."
mk "B5 — An RPF can claim an existing business listing; the claim is reflected in the listing (item 1)" workstream-2 "$W2

Open question from the 2026-11-05 check-in: whether a self-registered RPF can claim a listing an administrator did not upload. The criterion says \"existing listing\"."
mk "B6 — Administrator export of landowner information, complete and well-formed (item 4)" workstream-2 "$W2

An authorized administrator can export landowner information in the agreed machine-readable format; the export is complete and well-formed against a sample dataset."
mk "B7 — Administrator can view and bulk download user records across WFP and FID (item 4)" workstream-2 "$W2

RPFs, landowners and users, across the WFP and the FID."
mk "B8 — Administrator can disable and re-enable a login; a disabled user cannot authenticate (item 4)" workstream-2 "$W2"
mk "B9 — An RPF can enter a completed-project record and it is retrievable (item 5)" workstream-2 "$W2

Field list as circulated 2026-11-05 (ten fields, four required: completion date, biomass removed, disposition, RPF attestation; notes field retained). No comments were received by the 2026-11-10 deadline, so that list is the build."
mk "B10 — Administrative functions B6–B8 are restricted to authorized administrators" workstream-2 "$W2"
mk "B11 — Each deliverable includes brief operating documentation" general "$G

Sufficient for Arbos to verify and operate the deliverable."
mk "B12 — Operating documentation records the email-address recovery path (Schedule A.4)" general "$G

Where a user's email address is incorrect or has changed, including whether completed-project history can be carried to a replacement account."
mk "B13 — Acceptance follows §5: 15 business days to accept or notice nonconformity; 15 to cure" general "$G

Tracking issue for the acceptance process itself. Stakeholder test-release review (five business days, review group of six) is an input to it, not a substitute."
