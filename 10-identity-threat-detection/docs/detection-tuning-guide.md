# Detection Tuning Guide — Scenario 10
**IDSentinel Solutions | Identity Threat Detection Library**

This document covers threshold tuning, false positive suppression, and
lookup-based exclusions for all four detections. Update this document
whenever a suppression is added or a threshold is changed.

---

## General Tuning Principles

**Start high, tune down.** Set thresholds conservatively at first —
you'd rather miss a few low-confidence events than alert-fatigue the
SOC on day one. Track false positives for two weeks, then reduce
thresholds based on actual noise.

**Document every suppression.** Every exclusion added to a detection
creates a blind spot. Log them here with a date and justification so
they can be reviewed quarterly.

**Throttle aggressively in early deployment.** Splunk throttling
silences repeat triggers within a defined window. Use it — a sustained
attack should generate one alert per SLA window, not 50.

---

## D-01 — MFA Fatigue Tuning

### Current threshold
`count > 5 denials per user within 60 minutes`

### Tune down if:
- Your MFA push failure rate is low and you want earlier detection
- Move to `count > 3` after confirming your environment's baseline

### Tune up if:
- Users frequently miss push notifications and accidentally trigger
- Move to `count > 8` if the 5-denial threshold generates noise

### Known false positive sources
| Source | Description | Suppression |
|--------|-------------|-------------|
| Mobile app background refresh | Some apps retry MFA push on session expiry | Add `appDisplayName!="Microsoft Authenticator"` if pattern confirmed |
| Shared device accounts | Kiosk or shared accounts may see multiple users failing MFA | Add shared account UPNs to `mfa_fatigue_exclusions.csv` lookup |

### Exclusion lookup pattern
```spl
| lookup mfa_fatigue_exclusions.csv userPrincipalName AS userPrincipalName OUTPUT suppress
| where suppress != "true"
```

---

## D-02 — Impossible Travel Tuning

### Current threshold
`distance > 500 miles within 120 minutes`

### Tune down if:
- You want to catch shorter distances (e.g. same state anomalies)
- Move `distance_miles` threshold to `> 200`

### Tune up if:
- Users on transcontinental VPNs are causing frequent false positives
- Move time window from `120 minutes` to `60 minutes`

### Known false positive sources
| Source | Description | Suppression |
|--------|-------------|-------------|
| Corporate VPN | Egress from a VPN city different from user's actual location | Add VPN egress IPs to excluded_ips eval in the SPL |
| Cloud app proxies | Some M365 services proxy via regional PoPs | Filter `appDisplayName IN (...)` for known proxy apps |
| Executive travel | Frequent flyers on overnight flights | Add high-travel user UPNs to lookup with longer suppression window |

### Known VPN exclusion IPs — update this list
```
YOUR_CORP_VPN_EGRESS_IP_1
YOUR_CORP_VPN_EGRESS_IP_2
```

Update in the SPL `excluded_ips` eval line:
```spl
| eval excluded_ips = split("10.0.0.1,10.0.0.2,YOUR_ACTUAL_VPN_IP", ",")
```

---

## D-03 — After-Hours PIM Tuning

### Current threshold
`PIM activation between 22:00 and 06:00 local time (UTC-5)`

### Adjust timezone
Change the `UTC_OFFSET_HOURS` eval in the SPL to match your org:
- Eastern: `-5` (EST) / `-4` (EDT)
- Central: `-6` / `-5`
- Pacific: `-8` / `-7`
- UTC: `0`

### Known legitimate after-hours activation scenarios
| Scenario | Owner | Suppression Method |
|----------|-------|-------------------|
| On-call incident response | Security team | Add on-call UPNs to lookup for suppression during on-call window |
| Planned maintenance | IT Operations | Create a time-based suppression lookup for scheduled maintenance windows |

### On-call exclusion lookup pattern
```spl
| lookup oncall_users.csv userPrincipalName AS activated_by_upn OUTPUT oncall
| where oncall != "true"
```

---

## D-04 — Legacy Auth Spike Tuning

### Current threshold
`> 10 legacy auth attempts per source IP within 60 minutes`

### Pre-enforcement tuning
If the Scenario 01 CA block policy is not yet enforced, adjust:
```spl
| where total_legacy_attempts > 50    | Raise threshold significantly
  AND conditionalAccessStatus = "failure"  | Or filter to blocked-only
```

### Post-enforcement tuning
Once the CA block policy is enforced and your baseline is near zero:
```spl
| where total_legacy_attempts > 3    | Lower threshold — any spike is suspicious
```

### Known false positive sources
| Source | Description | Suppression |
|--------|-------------|-------------|
| On-premises SMTP relay | Internal mail server sends via Authenticated SMTP | Add relay IP to exclusion list |
| Legacy line-of-business apps | Apps still using Basic Auth during migration | Add source IP + clientAppUsed combination to suppression lookup |
| Fax/scan devices | Multifunction printers using SMTP scan-to-email | Add device IP to exclusion list |

### Known SMTP relay exclusion IPs — update this list
```
YOUR_ONPREM_SMTP_RELAY_IP
YOUR_MFP_SMTP_IP
```

---

## Quarterly Review Checklist

Run through these quarterly to keep detections accurate:

- [ ] Review all exclusion lookups — are suppressions still valid?
- [ ] Check false positive rate per detection — tune thresholds as needed
- [ ] Review alert throttle windows — are they still appropriate?
- [ ] Confirm ingestion is current — check last event timestamp in index
- [ ] Test all four detections with `Test-DetectionData.py`
- [ ] Update UTC offset if DST has changed
- [ ] Review corporate VPN egress IPs — have they changed?
- [ ] Review on-call user list for D-03 suppressions
