# Reel Estate · Maintenance Requests (DR-0002)

Salesforce Service Cloud + Experience Cloud solution for property maintenance requests, built from the
approved design produced by the agentic delivery pipeline (Analysis → Design → Build, with human gates).

- **What it does:** public web form → automatic skills-based routing to CSRs (Omni-Channel) → lifecycle,
  maintenance teams, information requests and reminders → customer portal (status, messages, rating) →
  escalation after 5 days, auto-close 6 weeks after a satisfactory rating, follow-up request on a low rating →
  manager reports and dashboard.
- **Design and build record:** `docs/delivery/DR-0002/` (requirements, design bundle, build report,
  deviations, traceability).
- **Source:** `force-app/` (generated declarative metadata comes from `tools/gen_*.py`; re-run them after
  editing), `demo-config/` (demo-org-only settings), `scripts/apex/` (demo data and post-deploy verification).

```bash
npm ci && npm run test:unit                       # LWC Jest
sf project deploy start --source-dir force-app -o <alias>
sf apex run test --test-level RunLocalTests --code-coverage -o <alias>
```
