# WFP → BOOST integration guide

**Status:** v0.2, 2026-11-20 (changes from v0.1 are listed in §9). Test endpoint, BOOST schema **v3.4.2**. Subcontract Schedule A item 0; acceptance criteria B1–B4 (one GitHub issue per criterion in this repository).

This guide is the interface documentation named in subcontract §3.2(b). It covers what the Working Forest Planner (WFP) sends, when, where, how it authenticates, what comes back, and what to do with it. The field mapping builds on ScaleCapacity's WFP → BOOST field population map of 2026-06-18, which remains the source for WFP column names.

## 1. The event

One `POST /validate` per **project completion**: the accepted RPF, or an administrator on the RPF's behalf, submits the completed-project record (item 5) with the attestation set. The record is permanent once submitted, so a project is sent once and the attestation timestamp identifies it. A second send of the same record happens only after a failed one (§5); it carries the same `traceableUnitId`. The validator is stateless, so repeats are harmless.

Nothing else triggers a send. Project creation, RPF claims and admin exports do not reach the validator.

## 2. The endpoint

| | Test |
|---|---|
| Base URL | `https://boost-validate-test-558287657500.us-central1.run.app` (test environment; a production URL follows acceptance) |
| Validate | `POST <base>/validate`, `Content-Type: application/json` |
| Health | `GET <base>/health` (no auth) |
| Schema pin | `GET <base>/version` → `{"boost_schema": "3.4.2", ...}` |
| Entities accepted | `GET <base>/entities` |
| OpenAPI | `GET <base>/docs` |

Source: [`Biogenics-Traceability/boost-validator`, `api/`](https://github.com/Biogenics-Traceability/boost-validator/tree/main/api). Apache-2.0.

## 3. Authentication (B4)

`Authorization: Bearer <token>`. One token per WFP environment (test, later production), issued by Arbos and delivered outside email. Keep it in server-side configuration (environment variable or secret store), never in client-visible code or the repository. To rotate, ask Arbos for a new token; both stay valid until the old one is retired.

No token, or a wrong one, returns **401**. Treat 401 as a configuration fault: alert an administrator; do not retry.

## 4. The payload

One JSON object keyed by BOOST entity name (snake_case, as in the BOOST `schema/` directory). Each value is one object or an array of objects. The completion record carries four entities:

```json
{
  "geographic_data": { ... },
  "organization":    [ { ... landowner ... }, { ... operator or RPF firm ... } ],
  "material":        { ... },
  "traceable_unit":  { ... }
}
```

The example that validates is [`examples/wfp_completion_example.json`](examples/wfp_completion_example.json); CI in this repository checks it against the pinned BOOST tag on every push. Copy its shape.

### 4.1 Conventions that bite

- **Identifiers are pattern-checked and upper-case.** `GEO-`, `ORG-`, `TRU-`, `MAT-`, `IM-` followed by `[A-Z0-9-_]+`. Upper-case any WFP id or slug before building an identifier; a UUID with lower-case hex fails. Hyphens inside a UUID are allowed and stay.
- **`organizationId` is at most 50 characters.** It is the only identifier in this record with a length cap. The prefixes in §4.3 leave room for a 36-character UUID.
- **`@context`, `@type`, `@id` are required on every entity.** Use the `@context` object from the corresponding BOOST example (`schema/<entity>/<entity>_example.json`), the `@type` shown below, and for `@id` any absolute `https://` URI under a WFP base, e.g. `https://wfp.placer.ca.gov/boost/tru/TRU-WFP-PRJ-2026-0412-COMPLETION`.
- **Timestamps are RFC 3339 date-time with a zone** (`2026-10-28T17:05:00Z`). Dates alone fail `format: date-time`.
- **Referenced ids must be in the document.** `harvesterId` names an `organizationId` that appears in `organization`; `harvestGeographicDataId` names the `geographicDataId` sent. The validator does not check cross-references at v3.4.2, but the record is useless without them and the next release will.
- **Quantities and units are stored as entered in WFP.** The record carries them verbatim in `attachedInformation` (§4.6) and a converted `totalVolumeM3`.

### 4.2 `geographic_data` (`@type: "GeographicData"`)

| BOOST field | Req | WFP source |
|---|---|---|
| `geographicDataId` | yes | `"GEO-WFP-PRJ-" + project id` |
| `geoJsonData` | yes | `ST_AsGeoJSON(user_property_data.geom)` in EPSG:4326, as a GeoJSON geometry object; `properties` may carry `name` and, when item 5 field 3 is filled, `acresTreated` |
| `dataType` | yes | const `"supply_base_area"`. WFP holds the property boundary as the landowner drew or imported it, not the treated unit, so the polygon is the ownership the material came from. The treated area is `acresTreated` and `wfp:acres_treated` (§4.6) |
| `description` | yes | `"Property boundary, "` + `project_profile.plss_description` / nearest city / APN |
| `coordinateSystem` | | const `"EPSG:4326"` |
| `administrativeRegion` | | county |
| `lastUpdated` | | attestation timestamp |

### 4.3 `organization` (`@type: "Organization"`, array)

Two entries. The landowner is the supplier; the second is the organization named as `harvesterId` (§4.5).

| BOOST field | Req | WFP source |
|---|---|---|
| `organizationId` | yes | landowner `"ORG-WFP-LO-" + user_id`; operator `"ORG-WFP-OP-LTO-" + LTO number`, or with no LTO number `"ORG-WFP-OP-" + name slug`; RPF firm `"ORG-WFP-RPF-" + rpf_id`. Ids are upper-cased and used whole, never trimmed |
| `organizationName` | yes | `user_data.first_name + last_name` / item 5 field 8 name / `rpf_data.company_name` |
| `organizationType` | yes | landowner `"supplier"`; operator or RPF firm `"harvester"` |
| `primaryGeographicDataId` | | the `geographicDataId` above (landowner) |
| `contactEmail`, `contactPhone` | | from WFP; `contactPhone` must be E.164 (`+15305551234`) or omitted |
| `californiaSRA`, `fireHazardZoneDesignation`, `calFireJurisdiction` | | if WFP holds them; `fireHazardZoneDesignation` is one of `Very High`, `High`, `Moderate`, `Low` |
| `lastUpdated` | | attestation timestamp |

The name slug is the operator name upper-cased, each run of characters outside `A–Z` and `0–9` replaced by one hyphen, cut to 39 characters, with any trailing hyphen dropped. `"Sierra Fuels Management Inc."` becomes `ORG-WFP-OP-SIERRA-FUELS-MANAGEMENT-INC`. With a 36-character UUID the landowner id is 47 characters and the RPF id 48.

Do not send the landowner's personal contact details unless the program has decided to; the schema does not require them.

### 4.4 `material` (`@type: "Material"`)

| BOOST field | Req | WFP source |
|---|---|---|
| `materialTypeId` | yes | `"MAT-WFP-" + category + "-" + product`, both upper-cased: category is `materialCategory` below, product is `productClassification` from §4.5. Twelve possible values, e.g. `MAT-WFP-SOFTWOOD-CHIPS`, `MAT-WFP-MIXED-BIOMASS` |
| `materialName` | yes | category and product in words, e.g. `"Softwood chips"`, `"Mixed biomass"` |
| `materialCategory` | yes | item 5 field 6: `softwood`, `hardwood`, `mixed`. If blank, send `"mixed"` and record `wfp:species=not_recorded` in `attachedInformation` |
| `typicalSpecies` | | the optional species list from field 6 |
| `applicablePlantParts` | | `["trunk", "branches", "bark"]` for fuel-reduction residue |
| `lastUpdated` | | attestation timestamp |

### 4.5 `traceable_unit` (`@type: "TraceableUnit"`)

| BOOST field | Req | WFP source |
|---|---|---|
| `traceableUnitId` | yes | `"TRU-WFP-PRJ-" + project id + "-COMPLETION"` |
| `unitType` | yes | const `"volume_aggregation"` |
| `uniqueIdentifier` | yes | free text: project id, APN, attestation timestamp |
| `identificationMethodId` | yes | const `"IM-WFP-PROJECT-RECORD"` (resolves June gap 1) |
| `identificationConfidence` | yes | const `85` (0–100; an attested RPF record, not a scale ticket; resolves June gap 2) |
| `methodReadinessLevel` | | const `5` |
| `totalVolumeM3` | yes | item 5 field 4 converted with the factor table in §4.7 |
| `harvestGeographicDataId`, `currentGeographicDataId` | yes / no | the `geographicDataId` sent |
| `createdTimestamp` | yes | attestation timestamp |
| `harvesterId` | yes | the operator organization from item 5 field 8; if blank, the RPF firm (resolves June gap 3) |
| `materialTypeId` | yes | the `materialTypeId` sent |
| `productClassification` | yes here | from item 5 field 5. Exactly one product with a quantity, and it is `sawlog`, `chips` or `firewood` → that product. Every other case → `"biomass"`: field 5 blank, field 5 filled by size class, the product `other`, or more than one product. The breakdown itself travels in §4.6 |
| `isMultiSpecies` | yes | `true` unless field 6 names exactly one species |
| `currentStatus` | | from the field 7 rows, first match wins: any row delivered to a facility → `"delivered"`; else any row chipped and scattered or pile-burned → `"processed"`; else any row left on site → `"active"`. If every row is `other`, omit the field |
| `attachedInformation` | | the item 5 record, §4.6 |
| `lastUpdated` | | attestation timestamp |

### 4.6 `attachedInformation`: the item 5 record

BOOST v3.4.2 has no field for treatment method, authorization, size-class quantities, disposition rows or the attestation itself (they are open v4.0.0 proposals: BOOST #324, #326, #327). Until the pin moves they travel as strings in `traceable_unit.attachedInformation`, one per item, in a fixed `wfp:<field>=<value>` form so they can be parsed later:

```
wfp:project_id=2026-0412
wfp:start_date=2026-09-14
wfp:completion_date=2026-10-28
wfp:treatment=thinning;mastication
wfp:acres_treated=38.5
wfp:geometry=property_boundary
wfp:biomass_removed=310 green_tons
wfp:biomass_by_size_class=0-4in:120 green_tons;4-6in:95 green_tons;6-9in:70 green_tons;9+in:25 green_tons
wfp:species=softwood;Pinus ponderosa,Pseudotsuga menziesii,Calocedrus decurrens
wfp:disposition=290 green_tons delivered_to Rio Bravo Rocklin, Rocklin;20 green_tons chipped_and_scattered
wfp:operator=Sierra Fuels Management Inc.;LTO A12345
wfp:authorization=exemption 4-26EX-00321-PLA
wfp:funding_source=CAL FIRE Wildfire Prevention Grant
wfp:rpf_attestation=true;RPF 2874;2026-10-28T17:05:00Z
wfp:submitted_by=rpf
wfp:volume_conversion=green_tons*1.13
```

Line by line, where the form allows more than the example shows:

| Line | Form |
|---|---|
| `wfp:treatment` | every treatment picked, separated by `;`. "Other" is written `other:<description>`, e.g. `thinning;other:hand piling` |
| `wfp:biomass_by_size_class` or `wfp:biomass_by_product` | whichever breakdown field 5 holds; never both. By product: `sawlog:40 green_tons;chips:250 green_tons;other:20 green_tons` |
| `wfp:disposition` | one entry per row: quantity, unit, then `delivered_to <facility name>, <city>`, `left_on_site`, `pile_burned`, `chipped_and_scattered` or `other:<description>`. No state; every WFP facility is in California |
| `wfp:start_date`, `wfp:funding_source` | the optional program fields, as entered |
| `wfp:geometry` | const `property_boundary` (§4.2) |
| `wfp:submitted_by` | `rpf`, or `admin_on_behalf` when an administrator completed the project for the RPF |

In any free-text value (descriptions, names, funding source) replace `;` with `,` and remove line breaks, so the separators stay parseable.

**Not sent:** the free-text notes, which can hold personal details, and the landowner's willingness to join a county-led project, which is program outreach data and stays in WFP.

Units are one of `green_tons`, `bone_dry_tons`, `ccf`, `cords`, as entered. Rows within a field are separated by `;`. Omit a line when the field is blank. When the schema pin moves to v4.0.0 these become structured fields and this section is replaced; nothing else in the record changes.

### 4.7 Volume conversion (provisional)

`totalVolumeM3` is solid-wood cubic metres. Convert the item 5 total with these factors and record the factor used in `wfp:volume_conversion`:

| Entered unit | × m³ |
|---|---|
| green ton (US short) | 1.13 |
| bone-dry ton (US short) | 2.2 |
| CCF | 2.832 |
| cord | 2.4 |

These are Arbos's working factors for mixed Sierra conifer and will be confirmed with the program; the as-entered quantity in `attachedInformation` is the figure of record, so a factor change never loses data.

## 5. Response contract (B2, B3)

| Status | Body | WFP's action |
|---|---|---|
| **200** | `{"status": "valid", "errors": []}` | Record accepted. Store the time and the `traceableUnitId` on the project; show "validated" to the RPF and admins. |
| **422** | `{"status": "invalid", "errors": [{"entity", "index", "path", "message", "validator"}, ...]}` | Validation failed. Store the errors with the project, show them to an administrator, mark the record "validation failed". **Do not retry automatically.** The form already checks the entries, so a 422 points at the mapping; once the mapping is corrected the same record is sent again. |
| **401** | `{"status": "unauthorized", ...}` | Token wrong or missing. Alert an administrator. **Do not retry.** |
| **5xx**, timeout, connection refused | any | Validator unavailable. **Retry with backoff**: 1 min, 5 min, 30 min, 2 h, then every 6 h for 3 days, then flag for an administrator. Keep the record queued; completion in WFP does not wait on the validator. |

`index` is the array position when an entity was sent as a list, otherwise `null`; `path` is the JSON path inside that object; `validator` is the schema keyword that failed (`required`, `type`, `enum`, `pattern`, `format`). Malformed JSON, an empty document, an unknown entity name and a non-object body all come back as 422 with the reason in `errors`, never as 500.

Nothing else comes back. The validator stores nothing and returns no data to WFP beyond the status (Schedule A item 0).

## 6. What WFP keeps

Per project: last send time, last status (`valid`, `invalid`, `unauthorized`, `queued`), the error list if any, the retry count, and the payload hash. This is what B2 and B3 are demonstrated from, and what an administrator needs when a send fails.

## 7. Test cases for acceptance (B2, B3, B4)

1. Complete a test project with all four required item 5 fields → 200; project shows validated.
2. Complete a project with a blank species field → 200 with `materialCategory: "mixed"`.
3. Complete a project whose operator name is blank → 200 with the RPF firm as `harvesterId`.
4. Set the test token to a wrong value → 401; administrator alert; no retry; restore the token.
5. Point the base URL at a closed port → queued, retries on the schedule, resumes on restore (base URL restored while a retry is pending) → 200.
6. Send a deliberately broken record from a test hook (`totalVolumeM3` as a string) → 422 with `traceable_unit / totalVolumeM3 / type` stored and shown; no retry.
7. Send a validated record a second time from the test hook → a second 200 with the same `traceableUnitId`.
8. Confirm no token appears in client-delivered JavaScript, HTML or the repository (B4).
9. Complete a project for a landowner whose WFP id is a UUID → 200; `organizationId` is 47 characters.
10. Complete a project whose only disposition row is "Other", with no product breakdown → 200 with `productClassification: "biomass"` and no `currentStatus`.

## 8. Change control

The schema pin is v3.4.2 on both sides. Arbos will give written notice before moving the test endpoint to a later BOOST release, with the field changes listed; WFP's integration should read the pin from `GET /version` and log it with each send so a mismatch is visible. Questions and gaps go on the issues in this repository, tagged with the criterion they affect.

## 9. Changes from v0.1

| Section | v0.1 | v0.2 |
|---|---|---|
| §1 | resend on edit and re-attestation | the record is permanent; one send per project, resend only after a failure |
| §4.2 | `dataType: "harvest_site"` | `"supply_base_area"`; the geometry is the property boundary |
| §4.3 | `ORG-WFP-LANDOWNER-`, `ORG-WFP-OPERATOR-` | `ORG-WFP-LO-`, `ORG-WFP-OP-`, with a slug rule, to fit the 50-character cap |
| §4.4 | `materialTypeId` from free-form category and product | category plus `productClassification`; `CONIFER` dropped |
| §4.5 | `productClassification` and `currentStatus` undefined for some inputs | rules for no product, several products, mixed rows and "Other" |
| §4.6 | twelve lines | adds `start_date`, `funding_source`, `geometry`, `submitted_by`, `biomass_by_product`; forms for several treatments and "Other"; facility without state; notes and landowner willingness named as not sent |
| §5 | 422: wait for edit and re-attestation | 422: correct the mapping, send again |
| §7 | eight tests | test 7 reworded; tests 9 and 10 added |
