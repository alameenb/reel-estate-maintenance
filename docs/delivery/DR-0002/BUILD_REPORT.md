# DR-0002 · Property Management: build report

Built by Claude (acting as the pipeline's Build agent) from design bundle **v1**, approved at Gate 2 on 13 Oct 2026 16:47 AEDT (sha256 `8506667de225…`). Deployed to the Developer Edition org `orgfarm-3b22af62d2-dev-ed` and raised for Gate 3 review.

## Result

| Check | Result |
|---|---|
| Deploy to Dev org | Succeeded: 190 source components plus the Experience Cloud site |
| Apex tests (RunLocalTests) | **79 / 79 passed**, org-wide coverage **91%** |
| LWC Jest (intake form) | 5 / 5 passed |
| Rule-based sharing on real records (`scripts/apex/verify-sharing.apex`) | 36 / 36 checks passed |
| Customer portal | Live: https://orgfarm-3b22af62d2-dev-ed.develop.my.site.com/maintenance |

## Deviations from the approved design

| Component | Deviation | Why |
|---|---|---|
| CMP-026, 058, 093–095, 101, 102 | Email templates are Classic HTML templates, not Lightning templates. Apex merges them in memory from one query per template. | `Messaging.renderStoredEmailTemplate` costs queries per email and breaks the 200-record bulk requirement. |
| CMP-085 | `RequestAssignmentService` is `without sharing` (design: inherited sharing + SYSTEM_MODE DML). | Periods are system audit data written from the trigger for any user (team members, portal ratings); documented exception. |
| CMP-028, 049, 059 | Added `MaintenanceMessaging` (shared send/notify helper, system-mode read of the customer's contact details) and `MaintenanceCustomerMessageAction` (invocable used by the reminder flow instead of Send Email / Send Custom Notification elements). | One bulk-safe, failure-tolerant path for every customer message; a send failure never blocks a save. |
| CMP-006 (new: Maintenance_Routing__e) | Requests created by the site guest or a portal user are routed through a platform event (`Maintenance_Routing__e` + `MaintenanceRoutingTrigger`) that runs as the Automated Process user. | Guest and portal licences cannot access Omni-Channel objects, even in system mode; found when testing the real guest user. |
| CMP-018 | Sharing set grants **Edit** (design: Read). | CMP-117/119 require the customer to update their own rating; field-level security limits what they can change to the rating only. |
| CMP-030 | Before-save flow compares `RecordTypeId` to a looked-up record type instead of an entry formula on `RecordType.DeveloperName`. | Cross-object entry formulas are not evaluated on create in before-save flows. |
| CMP-062 | Link Customer & Property uses radio-button choice lists (linked properties first, then postcode matches) rather than data tables; street ‘contains’ filter not applied. | Keeps the flow declarative and deployable from source; behaviour otherwise as designed. |
| CMP-061, 111, 114 | Quick-action visibility filters (e.g. Send Reminder only when Awaiting Customer Information) are not set; each flow refuses with a clear message instead. | Dynamic action visibility needs Dynamic Actions configuration on the record page; follow-up item. |
| CMP-130, 076 | Team and supervisor access through criteria-based sharing rules is verified by `scripts/apex/verify-sharing.apex` against real records, not inside Apex tests. | This org calculates criteria-based rule shares asynchronously, so they are not visible inside a test transaction. Owner isolation and permission limits are still asserted in tests. |
| CMP-075 | Dashboard has the two bar charts and the overdue metric; the top-20 overdue table component is not included. | Table components on tabular reports need extra configuration; follow-up item. |
| CMP-046, new fields | Added `Notification_Rule__mdt.Excluded_Statuses__c` and `Notification_Title__c`, `Request_Setting__mdt.Portal_Url__c`, `Case.Portal_Link__c` (formula) and `Property_Customer__c.Property_Name__c` (formula). | Needed for single-notification precedence, portal links in emails without hardcoding, and flow choice labels. |
| Design TBCs | Issue categories, maintenance teams and file rules use demo values (see `tools/gen_metadata.py`). | The business has not supplied the values yet (open questions in the approved requirements). |
| Org setup | Added `Maintenance_Full_Access` permission set (admin/demo), Admin profile layout + default record type, Omni presence configuration by profile (`demo-config/`), Customer Service portal site customised from the retrieved ExperienceBundle. | Needed to run and demo the solution; not part of the reviewed component list. |
| Pending | Omni-Channel utility (widget) in the console app is added through Setup and will be pulled into source in a follow-up commit. | Its metadata component name could not be confirmed from the CLI. |

## Traceability (requirement → story → components)

| Requirement | Stories | Components |
|---|---|---|
| REQ-001 Customer shall be able to submit a maintenance request through an onli… | US-010, US-011 | CMP-001, CMP-003, CMP-009, CMP-013, CMP-020, CMP-033, CMP-034, CMP-035, CMP-036, CMP-037, CMP-038, CMP-039, CMP-041, CMP-042 … |
| REQ-002 The system shall receive each submitted request and assign it to a cus… | US-001 | CMP-001, CMP-002, CMP-003, CMP-004, CMP-005, CMP-006, CMP-007, CMP-008, CMP-009, CMP-010, CMP-016 |
| REQ-003 Customer service representative shall be able to review a request and … | US-028, US-029 | CMP-001, CMP-009, CMP-013, CMP-014, CMP-015, CMP-016, CMP-026, CMP-027, CMP-028, CMP-029, CMP-047, CMP-108, CMP-109, CMP-110 … |
| REQ-004 Customer service representative shall be able to assign a request to a… | US-002 | CMP-001, CMP-009, CMP-011, CMP-012, CMP-014, CMP-015, CMP-016 |
| REQ-005 The system shall send the customer an acknowledgement by email and as … | US-023 | CMP-009, CMP-027, CMP-046, CMP-047, CMP-049, CMP-050, CMP-093, CMP-096, CMP-099 |
| REQ-006 Customer shall be able to check the progress of their submitted reques… | US-014 | CMP-017, CMP-018, CMP-019, CMP-024, CMP-056, CMP-057 |
| REQ-007 Customer shall be able to respond to questions, provide additional inf… | US-015 | CMP-014, CMP-016, CMP-017, CMP-018, CMP-019, CMP-028, CMP-029 |
| REQ-008 The system shall allow the customer and the assigned representative to… | US-004, US-005 | CMP-001, CMP-009, CMP-013, CMP-014, CMP-016, CMP-017, CMP-018, CMP-019, CMP-020, CMP-026, CMP-027, CMP-028, CMP-029 |
| REQ-009 Customer service representative shall be able to move a request throug… | US-026 | CMP-001, CMP-009, CMP-013, CMP-014, CMP-015, CMP-016, CMP-024, CMP-025, CMP-106 |
| REQ-010 Customer service representative shall be able to record internal notes… | US-027 | CMP-009, CMP-013, CMP-014, CMP-016, CMP-017, CMP-018, CMP-019, CMP-028, CMP-029, CMP-068, CMP-107 |
| REQ-011 Customer service representative shall be able to send reminders to a c… | US-016 | CMP-009, CMP-014, CMP-015, CMP-016, CMP-024, CMP-027, CMP-058, CMP-059, CMP-060, CMP-061, CMP-064 |
| REQ-012 The system shall escalate a request to the designated escalation team … | US-017 | CMP-001, CMP-013, CMP-020, CMP-021, CMP-022, CMP-023, CMP-030, CMP-031 |
| REQ-013 Customer service representative shall be able to inform the customer t… | US-030, US-031 | CMP-009, CMP-013, CMP-014, CMP-015, CMP-016, CMP-017, CMP-018, CMP-019, CMP-024, CMP-025, CMP-027, CMP-049, CMP-050, CMP-068 … |
| REQ-014 The system shall create a new request, linked to the original closed r… | US-032 | CMP-001, CMP-006, CMP-007, CMP-008, CMP-009, CMP-013, CMP-014, CMP-015, CMP-017, CMP-018, CMP-019, CMP-024, CMP-025, CMP-030 … |
| REQ-015 The system shall notify the customer by email and on the portal when t… | US-024, US-025 | CMP-009, CMP-014, CMP-015, CMP-016, CMP-024, CMP-027, CMP-046, CMP-049, CMP-050, CMP-068, CMP-094, CMP-095, CMP-097, CMP-098 … |
| REQ-016 Company manager shall be able to view all requests.… | US-018 | CMP-001, CMP-009, CMP-013, CMP-014, CMP-066, CMP-067, CMP-068, CMP-069, CMP-076 |
| REQ-017 Company manager shall be able to monitor workloads.… | US-019 | CMP-001, CMP-011, CMP-024, CMP-066, CMP-068, CMP-071, CMP-072, CMP-073, CMP-075 |
| REQ-018 Company manager shall be able to identify overdue requests, being thos… | US-020 | CMP-001, CMP-009, CMP-020, CMP-021, CMP-024, CMP-030, CMP-065, CMP-066, CMP-068, CMP-070, CMP-071, CMP-074, CMP-075, CMP-076 |
| REQ-019 Company manager shall be able to track resolution times, measured from… | US-021 | CMP-007, CMP-008, CMP-009, CMP-011, CMP-066, CMP-067, CMP-068, CMP-071, CMP-077, CMP-078, CMP-079, CMP-080, CMP-081, CMP-082 … |
| REQ-020 Company manager shall be able to review customer satisfaction ratings … | US-022 | CMP-009, CMP-066, CMP-067, CMP-068, CMP-071, CMP-089, CMP-090, CMP-091, CMP-092, CMP-099 |
| REQ-021 The system shall maintain a history of customer interactions, status c… | US-003 | CMP-001, CMP-003, CMP-009, CMP-011, CMP-013, CMP-014, CMP-015, CMP-016 |
| REQ-022 The system shall restrict each customer to accessing only their own re… | US-034 | CMP-009, CMP-013, CMP-017, CMP-018, CMP-019, CMP-057, CMP-129 |
| REQ-023 The system shall give company employees access to requests based on th… | US-036 | CMP-009, CMP-011, CMP-013, CMP-016, CMP-066, CMP-067, CMP-068, CMP-126, CMP-127, CMP-128, CMP-130 |
| REQ-024 The system shall support multiple properties and multiple maintenance … | US-012 | CMP-001, CMP-009, CMP-013, CMP-033, CMP-034, CMP-035, CMP-036, CMP-037, CMP-038, CMP-039, CMP-040, CMP-041, CMP-047, CMP-054 … |
| REQ-025 Company employee shall be able to identify existing customers and prop… | US-013 | CMP-014, CMP-015, CMP-016, CMP-033, CMP-037, CMP-041, CMP-055, CMP-062, CMP-063 |
| REQ-026 The system shall allow the company to add new maintenance categories w… | US-006 | CMP-001, CMP-002, CMP-003, CMP-004, CMP-032 |
| REQ-027 The system shall allow the company to modify request statuses without … | US-007 | CMP-001, CMP-014, CMP-016, CMP-024, CMP-025, CMP-032 |
| REQ-028 The system shall allow the company to change escalation timeframes wit… | US-008 | CMP-001, CMP-007, CMP-009, CMP-020, CMP-021, CMP-022, CMP-023, CMP-030, CMP-031, CMP-032 |
| REQ-029 The system shall allow the company to update notification rules withou… | US-009 | CMP-009, CMP-026, CMP-027, CMP-032, CMP-046, CMP-049, CMP-050 |
| REQ-030 Customer shall be able to submit a satisfaction rating for their reque… | US-031 | CMP-009, CMP-017, CMP-018, CMP-019, CMP-068, CMP-089, CMP-090, CMP-091, CMP-092, CMP-115, CMP-116, CMP-117, CMP-118, CMP-119 … |
| REQ-031 The system shall automatically close a request 6 weeks after the custo… | US-033 | CMP-009, CMP-013, CMP-014, CMP-024, CMP-089, CMP-115, CMP-118, CMP-123, CMP-124 |
| REQ-032 Customer shall be able to access their requests only through the custo… | US-035 | CMP-009, CMP-017, CMP-019, CMP-027, CMP-053, CMP-057, CMP-125, CMP-129 |

## How to reproduce

```bash
sf project deploy start --source-dir force-app --target-org <alias>
sf apex run test --test-level RunLocalTests --code-coverage --target-org <alias>
# demo data (in order)
for f in scripts/apex/demo-users.apex scripts/apex/demo-omni-1-access.apex scripts/apex/demo-omni-2-skills.apex scripts/apex/demo-data-1-customers.apex scripts/apex/demo-data-2-portal-users.apex; do sf apex run -f $f -o <alias>; done
sf apex run -f scripts/apex/demo-data-3a-requests.apex -o <alias>   # run until it reports 0
for f in 3b-assign 3c-progress 3d-ratings; do sf apex run -f scripts/apex/demo-data-$f.apex -o <alias>; done
sf apex run -f scripts/apex/verify-sharing.apex -o <alias>
```
