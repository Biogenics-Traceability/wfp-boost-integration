# wfp-boost-integration

Working Forest Planner ↔ BOOST validator integration. California Board of Forestry and Fire Protection, Joint Institute for Wood Products Innovation grant 9GA25804, Task 4. Built by ScaleCapacity under subcontract to Arbos; released under Apache-2.0 (subcontract §7.4).

| | |
|---|---|
| [`INTEGRATION_GUIDE.md`](INTEGRATION_GUIDE.md) | The interface: event, endpoint, authentication, field mapping, response contract, retry rules, acceptance test cases. |
| [`examples/wfp_completion_example.json`](examples/wfp_completion_example.json) | A completed-project record that validates against BOOST v3.4.2. CI checks it on every push. |
| [`scripts/validate_examples.py`](scripts/validate_examples.py) | The CI check, runnable locally against a BOOST checkout at the pinned tag. |
| Issues | One per acceptance criterion B1–B13 (subcontract Schedule B). Submissions for acceptance cite the issue. |
| Validator service | [`Biogenics-Traceability/boost-validator`, `api/`](https://github.com/Biogenics-Traceability/boost-validator/tree/main/api). |

WFP-side integration code lands in this repository under a directory ScaleCapacity names.
