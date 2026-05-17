# Alert Configuration Reference — Scenario 10
**IDSentinel Solutions | Identity Threat Detection Library**

This document is the step-by-step configuration guide for saving each
SPL detection as a scheduled Splunk alert. Follow these steps for each
detection after confirming the search returns results against test data.

---

## How to Create a Scheduled Alert in Splunk Enterprise

1. Open the SPL file in `splunk/searches/`
2. Paste the query into Splunk Search (Enterprise)
3. Click **Save As → Alert**
4. Configure fields per the table below
5. Click **Save**

---

## D-01 — MFA Fatigue

| Field | Value |
|-------|-------|
| Alert Name | `IDSentinel - MFA Fatigue Detected` |
| Alert Type | Scheduled |
| Run every | `15 minutes` |
| Time range | `-60m to now` |
| Trigger alert when | `Number of results is greater than 0` |
| Throttle | `1 hour` per `userPrincipalName` |
| **Actions** | |
| Add to Triggered Alerts | ✅ Enabled |
| Severity | `High` |
| **Optional** | |
| Email notification | SOC team DL |
| Webhook | SOAR / Teams / Slack endpoint if available |

**Throttle note:** Throttling per `userPrincipalName` prevents alert
flooding if an attacker sustains the spray for hours. The SOC still
sees the first trigger and subsequent ones appear in Triggered Alerts
after the throttle window expires.

**Test command (after saving):**
Run `Test-DetectionData.py` and verify the alert appears in
**Activity → Triggered Alerts** within the next 15-minute window.

---

## D-02 — Impossible Travel

| Field | Value |
|-------|-------|
| Alert Name | `IDSentinel - Impossible Travel Detected` |
| Alert Type | Scheduled |
| Run every | `30 minutes` |
| Time range | `-2h to now` |
| Trigger alert when | `Number of results is greater than 0` |
| Throttle | `2 hours` per `userPrincipalName` |
| **Actions** | |
| Add to Triggered Alerts | ✅ Enabled |
| Severity | `High` |

**False positive note:** Corporate VPN egress IPs will appear as
impossible travel if the same user connects from home AND routes
through a remote-city VPN exit. Add known VPN IPs to the exclusion
list in the SPL query. See `docs/detection-tuning-guide.md`.

---

## D-03 — After-Hours PIM Activation

| Field | Value |
|-------|-------|
| Alert Name | `IDSentinel - After-Hours PIM Activation` |
| Alert Type | Scheduled |
| Run every | `60 minutes` |
| Time range | `-60m to now` |
| Trigger alert when | `Number of results is greater than 0` |
| Throttle | `4 hours` per `activated_by_upn` |
| **Actions** | |
| Add to Triggered Alerts | ✅ Enabled |
| Severity | `Medium` |

**Tuning note:** If you have on-call staff who legitimately activate
roles after hours, add their UPNs to a lookup table and suppress in
the SPL. See `docs/detection-tuning-guide.md` for the lookup
exclusion pattern.

---

## D-04 — Legacy Auth Spike

| Field | Value |
|-------|-------|
| Alert Name | `IDSentinel - Legacy Auth Spike Detected` |
| Alert Type | Scheduled |
| Run every | `15 minutes` |
| Time range | `-60m to now` |
| Trigger alert when | `Number of results is greater than 0` |
| Throttle | `1 hour` per `ipAddress` |
| **Actions** | |
| Add to Triggered Alerts | ✅ Enabled |
| Severity | `High` |

**Dependency note:** This detection is most meaningful after the
Scenario 01 CA block policy is enforced. Pre-enforcement, the
`total_legacy_attempts > 10` threshold will fire frequently on
legitimate traffic. Either raise the threshold to `> 100` or filter
on `conditionalAccessStatus = "failure"` to see only blocked attempts.

---

## Verifying Alerts Are Working

After configuring all four alerts:

1. Run `python scripts/Test-DetectionData.py`
2. Wait up to 60 minutes (longest schedule window)
3. Navigate to **Activity → Triggered Alerts** in Splunk
4. All four alerts should appear with results from the test generator

Verify each result row contains:
- The correct `userPrincipalName` (`testuser@IDSentinelSolutions.com`)
- The expected severity
- The recommended action field populated

---

## Cleanup After Testing

Remove test events from the index:

```spl
index="idsentinel_identity" source="idsentinel:test"
| table _time, sourcetype, source
```

To delete (requires `can_delete` role in Splunk):
- Run the search above
- Click **Actions → Delete events**

Or leave them — the `source="idsentinel:test"` tag lets you exclude
them from production searches by adding `source!="idsentinel:test"`.
