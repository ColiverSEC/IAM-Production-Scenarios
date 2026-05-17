# =============================================================================
# Test-DetectionData.py
# Description: Generates synthetic Entra ID-shaped log events and sends them
#              directly to Splunk HEC to validate all four detection alerts
#              fire correctly before promoting to production schedules.
#
#              Run this BEFORE enabling scheduled alerts to confirm each SPL
#              query triggers as expected. All test events are tagged with
#              source="idsentinel:test" for easy cleanup.
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 10 - Identity Threat Detection Pipeline (Entra ID → Splunk)
# =============================================================================

import requests
import json
import time
import random
import string
from datetime import datetime, timezone, timedelta

# =============================================================================
# CONFIGURATION
# =============================================================================
SPLUNK_HEC_URL    = "https://localhost:8088"
SPLUNK_HEC_TOKEN  = "YOUR_HEC_TOKEN"
SPLUNK_INDEX      = "idsentinel_identity"
SPLUNK_VERIFY_SSL = False
TEST_USER_UPN     = "testuser@IDSentinelSolutions.com"
TEST_SOURCE       = "idsentinel:test"    # Tag for easy cleanup after testing

# =============================================================================
# HEC SENDER
# =============================================================================
def send_hec_events(events, sourcetype):
    hec_url = f"{SPLUNK_HEC_URL}/services/collector/event"
    headers = {
        "Authorization": f"Splunk {SPLUNK_HEC_TOKEN}",
        "Content-Type":  "application/json"
    }
    batch = ""
    for ev in events:
        hec_event = {
            "time":       int(datetime.now(timezone.utc).timestamp()),
            "host":       "idsentinel-test-generator",
            "source":     TEST_SOURCE,
            "sourcetype": sourcetype,
            "index":      SPLUNK_INDEX,
            "event":      ev
        }
        batch += json.dumps(hec_event) + "\n"

    r = requests.post(hec_url, data=batch, headers=headers,
                      verify=SPLUNK_VERIFY_SSL, timeout=30)
    return r.status_code == 200

def ts_offset(minutes_ago=0):
    """Return ISO8601 timestamp offset by minutes_ago from now."""
    dt = datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

# =============================================================================
# TEST D-01 — MFA FATIGUE
# Sends 7 MFA push denial sign-ins from the same user within 10 minutes
# Expected: D-01 alert fires (threshold is >5 denials / 60min)
# =============================================================================
def test_mfa_fatigue():
    print("\n[D-01] Generating MFA fatigue test events...")
    events = []
    for i in range(7):
        events.append({
            "createdDateTime":       ts_offset(minutes_ago=random.randint(0, 9)),
            "userPrincipalName":     TEST_USER_UPN,
            "userDisplayName":       "Test User",
            "appDisplayName":        "Microsoft Office 365",
            "clientAppUsed":         "Browser",
            "ipAddress":             "198.51.100.42",
            "location": {
                "city":            "Atlanta",
                "countryOrRegion": "US"
            },
            "status": {
                "errorCode":     500121,
                "failureReason": "Authentication failed during strong authentication request."
            },
            "authenticationRequirement": "multiFactorAuthentication",
            "mfaDetail": {
                "authMethod":  "Phone app notification",
                "authDetail":  "MFA denied; user did not respond to mobile app notification."
            },
            "conditionalAccessStatus": "failure",
            "isInteractive":           True,
            "test_tag":                "D-01-MFA-FATIGUE"
        })
    sent = send_hec_events(events, sourcetype="azure:monitor:aad:signin")
    status = "[+] SENT" if sent else "[!] FAILED"
    print(f"    {status} — 7 MFA denial events for {TEST_USER_UPN}")
    print("    Expected: D-01 alert fires within next 15-minute schedule window")

# =============================================================================
# TEST D-02 — IMPOSSIBLE TRAVEL
# Sends two successful sign-ins from cities 1,300+ miles apart within 30 min
# Expected: D-02 alert fires (threshold is 500mi apart / 2hr window)
# =============================================================================
def test_impossible_travel():
    print("\n[D-02] Generating impossible travel test events...")

    signin_new_york = {
        "createdDateTime":       ts_offset(minutes_ago=30),
        "userPrincipalName":     TEST_USER_UPN,
        "userDisplayName":       "Test User",
        "appDisplayName":        "Microsoft Teams",
        "clientAppUsed":         "Mobile Apps and Desktop clients",
        "ipAddress":             "72.229.28.185",
        "location": {
            "city":            "New York",
            "state":           "New York",
            "countryOrRegion": "US",
            "geoCoordinates": {
                "latitude":  40.7128,
                "longitude": -74.0060
            }
        },
        "status":       {"errorCode": 0},
        "isInteractive": True,
        "test_tag":      "D-02-IMPOSSIBLE-TRAVEL-LEG1"
    }

    signin_seattle = {
        "createdDateTime":       ts_offset(minutes_ago=5),
        "userPrincipalName":     TEST_USER_UPN,
        "userDisplayName":       "Test User",
        "appDisplayName":        "Microsoft Teams",
        "clientAppUsed":         "Mobile Apps and Desktop clients",
        "ipAddress":             "73.181.147.22",
        "location": {
            "city":            "Seattle",
            "state":           "Washington",
            "countryOrRegion": "US",
            "geoCoordinates": {
                "latitude":  47.6062,
                "longitude": -122.3321
            }
        },
        "status":       {"errorCode": 0},
        "isInteractive": True,
        "test_tag":      "D-02-IMPOSSIBLE-TRAVEL-LEG2"
    }

    sent = send_hec_events([signin_new_york, signin_seattle],
                           sourcetype="azure:monitor:aad:signin")
    status = "[+] SENT" if sent else "[!] FAILED"
    print(f"    {status} — New York (T-30min) + Seattle (T-5min) for {TEST_USER_UPN}")
    print("    Expected: D-02 alert fires within next 30-minute schedule window")

# =============================================================================
# TEST D-03 — AFTER-HOURS PIM ACTIVATION
# Sends a synthetic PIM role activation audit event timestamped at 2:00am
# Expected: D-03 alert fires (any PIM activation 10pm-6am)
# =============================================================================
def test_afterhours_pim():
    print("\n[D-03] Generating after-hours PIM activation test event...")

    # Build a 2am timestamp for today
    now_utc  = datetime.now(timezone.utc)
    two_am   = now_utc.replace(hour=2, minute=15, second=0, microsecond=0)
    two_am_s = two_am.strftime("%Y-%m-%dT%H:%M:%SZ")

    event = {
        "activityDateTime":    two_am_s,
        "activityDisplayName": "Add member to role completed (PIM activation)",
        "category":            "RoleManagement",
        "operationType":       "Assign",
        "result":              "success",
        "loggedByService":     "PIM",
        "initiatedBy": {
            "user": {
                "userPrincipalName": TEST_USER_UPN,
                "displayName":       "Test User"
            }
        },
        "targetResources": [
            {
                "displayName":      "Security Administrator",
                "type":             "Role",
                "modifiedProperties": [
                    {
                        "displayName": "Role.DisplayName",
                        "newValue":    "Security Administrator"
                    }
                ]
            }
        ],
        "additionalDetails": [
            {"key": "RoleDefinitionId",      "value": "194ae4cb-b126-40b2-bd5b-6091b380977d"},
            {"key": "PIMActivationDuration", "value": "PT1H"},
            {"key": "Justification",         "value": "Emergency access — testing after-hours detection"}
        ],
        "test_tag": "D-03-AFTERHOURS-PIM"
    }

    sent = send_hec_events([event], sourcetype="azure:monitor:aad:audit")
    status = "[+] SENT" if sent else "[!] FAILED"
    print(f"    {status} — PIM activation event timestamped 02:15 UTC for {TEST_USER_UPN}")
    print("    Expected: D-03 alert fires within next 60-minute schedule window")

# =============================================================================
# TEST D-04 — LEGACY AUTH SPIKE
# Sends 12 legacy auth sign-in attempts from same source IP within 5 minutes
# Expected: D-04 alert fires (threshold is >10 legacy attempts / 1hr)
# =============================================================================
def test_legacy_auth_spike():
    print("\n[D-04] Generating legacy auth spike test events...")

    legacy_clients = [
        "Exchange ActiveSync", "IMAP", "SMTP", "POP3",
        "Other clients", "Authenticated SMTP", "Legacy Authentication Clients"
    ]

    events = []
    for i in range(12):
        events.append({
            "createdDateTime":     ts_offset(minutes_ago=random.randint(0, 4)),
            "userPrincipalName":   f"user{i+1:02d}@IDSentinelSolutions.com",
            "userDisplayName":     f"Test User {i+1:02d}",
            "appDisplayName":      "Office 365 Exchange Online",
            "clientAppUsed":       random.choice(legacy_clients),
            "ipAddress":           "185.220.101.55",   # Known Tor exit node range
            "location": {
                "city":            "Unknown",
                "countryOrRegion": "NL"
            },
            "status": {
                "errorCode":     50126,
                "failureReason": "Invalid username or password or Invalid on-premises username or password."
            },
            "conditionalAccessStatus": "notApplied",
            "isInteractive":           False,
            "test_tag":                "D-04-LEGACY-AUTH-SPIKE"
        })

    sent = send_hec_events(events, sourcetype="azure:monitor:aad:signin")
    status = "[+] SENT" if sent else "[!] FAILED"
    print(f"    {status} — 12 legacy auth events from 185.220.101.55 (NL)")
    print("    Expected: D-04 alert fires within next 15-minute schedule window")

# =============================================================================
# CLEANUP QUERY — print SPL to remove all test events after validation
# =============================================================================
def print_cleanup_instructions():
    print("\n" + "=" * 60)
    print("  CLEANUP — Remove test events after validation")
    print("=" * 60)
    print("\n  Run this SPL in Splunk to find all test events:")
    print(f'\n  index="{SPLUNK_INDEX}" source="{TEST_SOURCE}"')
    print(f'  | table _time, sourcetype, event.userPrincipalName, event.test_tag')
    print("\n  Note: Splunk Free/Enterprise does not support delete by search")
    print("  unless the 'can_delete' role is assigned to your user.")
    print("  To delete: index AND source filter → Actions → Delete")
    print("  Or simply note the test_tag field to filter out in dashboards.\n")

# =============================================================================
# MAIN
# =============================================================================
def main():
    print("=" * 60)
    print("  IDSentinel — Detection Test Data Generator")
    print("  Scenario 10 — Identity Threat Detection Pipeline")
    print("=" * 60)
    print(f"\n  Target HEC : {SPLUNK_HEC_URL}")
    print(f"  Index      : {SPLUNK_INDEX}")
    print(f"  Test user  : {TEST_USER_UPN}")
    print(f"  Source tag : {TEST_SOURCE}")
    print("\n  Sending test events for all four detections...\n")

    test_mfa_fatigue()
    time.sleep(1)

    test_impossible_travel()
    time.sleep(1)

    test_afterhours_pim()
    time.sleep(1)

    test_legacy_auth_spike()

    print("\n" + "=" * 60)
    print("  ALL TEST EVENTS SENT")
    print("=" * 60)
    print("\n  Wait for the next scheduled alert window, then verify:")
    print("  D-01 MFA Fatigue        → fires within 15 minutes")
    print("  D-02 Impossible Travel  → fires within 30 minutes")
    print("  D-03 After-Hours PIM    → fires within 60 minutes")
    print("  D-04 Legacy Auth Spike  → fires within 15 minutes")

    print_cleanup_instructions()

if __name__ == "__main__":
    main()
