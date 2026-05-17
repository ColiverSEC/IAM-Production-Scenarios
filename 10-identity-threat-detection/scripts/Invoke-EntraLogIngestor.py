# =============================================================================
# Invoke-EntraLogIngestor.py
# Description: Pulls Entra ID sign-in logs and audit logs from Microsoft
#              Graph API using OAuth2 Client Credentials flow, then forwards
#              all events to Splunk via HTTP Event Collector (HEC).
#
#              Run on a schedule (Task Scheduler or cron) every 5 minutes
#              for continuous ingestion. State tracking via last_run.json
#              prevents duplicate events between runs.
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 10 - Identity Threat Detection Pipeline (Entra ID → Splunk)
#
# Requirements: pip install requests
# =============================================================================

import requests
import json
import os
import time
from datetime import datetime, timezone, timedelta

# =============================================================================
# CONFIGURATION — update all values before running
# Store CLIENT_SECRET in an environment variable in production:
#   $env:IDSENTINEL_CLIENT_SECRET = "your-secret"
# =============================================================================
TENANT_ID         = "YOUR_TENANT_ID"
CLIENT_ID         = "YOUR_CLIENT_ID"
CLIENT_SECRET     = os.environ.get("IDSENTINEL_CLIENT_SECRET", "YOUR_CLIENT_SECRET")

SPLUNK_HEC_URL    = "https://localhost:8088"          # Splunk HEC endpoint
SPLUNK_HEC_TOKEN  = "YOUR_HEC_TOKEN"                  # Generated in Splunk Settings
SPLUNK_INDEX      = "idsentinel_identity"
SPLUNK_VERIFY_SSL = False                              # Set True in production with valid cert

GRAPH_BASE        = "https://graph.microsoft.com"
TOKEN_URL         = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"
STATE_FILE        = "./last_run.json"
LOOKBACK_MINUTES  = 10                                # Default lookback if no state file

# =============================================================================
# STATE MANAGEMENT — track last successful run to prevent duplicates
# =============================================================================
def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    # First run — default to LOOKBACK_MINUTES ago
    cutoff = (datetime.now(timezone.utc) - timedelta(minutes=LOOKBACK_MINUTES))
    return {
        "last_signin_pull": cutoff.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "last_audit_pull":  cutoff.strftime("%Y-%m-%dT%H:%M:%SZ")
    }

def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)

# =============================================================================
# AUTHENTICATE — OAuth2 Client Credentials Flow
# =============================================================================
def get_access_token():
    print("\n[*] Authenticating via OAuth2 Client Credentials...")
    payload = {
        "grant_type":    "client_credentials",
        "client_id":     CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "scope":         "https://graph.microsoft.com/.default"
    }
    response = requests.post(TOKEN_URL, data=payload, timeout=30)
    if response.status_code == 200:
        print("[+] Access token obtained")
        return response.json()["access_token"]
    else:
        print(f"[!] Authentication failed: {response.status_code} — {response.text}")
        raise SystemExit(1)

# =============================================================================
# GRAPH API HELPER — handles pagination automatically
# =============================================================================
def graph_get(token, endpoint, version="v1.0"):
    url = f"{GRAPH_BASE}/{version}/{endpoint}"
    headers = {"Authorization": f"Bearer {token}"}
    results = []

    while url:
        response = requests.get(url, headers=headers, timeout=30)
        if response.status_code == 200:
            data = response.json()
            results.extend(data.get("value", []))
            url = data.get("@odata.nextLink")
        elif response.status_code == 429:
            # Throttled — back off and retry
            retry_after = int(response.headers.get("Retry-After", 30))
            print(f"    [!] Rate limited — waiting {retry_after}s...")
            time.sleep(retry_after)
        else:
            print(f"    [!] Graph API error {response.status_code}: {endpoint}")
            print(f"        {response.text[:300]}")
            break

    return results

# =============================================================================
# SPLUNK HEC FORWARDER — batch events to HEC endpoint
# =============================================================================
def send_to_splunk(events, sourcetype):
    if not events:
        return 0

    hec_url     = f"{SPLUNK_HEC_URL}/services/collector/event"
    headers     = {
        "Authorization": f"Splunk {SPLUNK_HEC_TOKEN}",
        "Content-Type":  "application/json"
    }

    # Build HEC payload — one JSON object per line (batch format)
    batch = ""
    for event in events:
        hec_event = {
            "time":       _parse_event_time(event),
            "host":       "entra-id",
            "source":     "microsoft:graph:api",
            "sourcetype": sourcetype,
            "index":      SPLUNK_INDEX,
            "event":      event
        }
        batch += json.dumps(hec_event) + "\n"

    response = requests.post(
        hec_url,
        data=batch,
        headers=headers,
        verify=SPLUNK_VERIFY_SSL,
        timeout=60
    )

    if response.status_code == 200:
        result = response.json()
        if result.get("text") == "Success":
            return len(events)
        else:
            print(f"    [!] HEC partial failure: {result}")
            return 0
    else:
        print(f"    [!] HEC send failed: {response.status_code} — {response.text[:300]}")
        return 0

def _parse_event_time(event):
    """Extract Unix timestamp from Graph API event for accurate Splunk _time."""
    for field in ["createdDateTime", "activityDateTime", "occurredDateTime"]:
        if field in event and event[field]:
            try:
                dt = datetime.fromisoformat(event[field].replace("Z", "+00:00"))
                return int(dt.timestamp())
            except (ValueError, AttributeError):
                pass
    return int(datetime.now(timezone.utc).timestamp())

# =============================================================================
# PULL SIGN-IN LOGS
# =============================================================================
def pull_signin_logs(token, since):
    print(f"\n[*] Pulling sign-in logs (since {since})...")

    # Select fields relevant to the four detections
    select_fields = ",".join([
    "id", "createdDateTime", "userDisplayName", "userPrincipalName",
    "appDisplayName", "clientAppUsed", "ipAddress", "location",
    "status", "conditionalAccessStatus", "riskLevelAggregated",
    "riskState", "mfaDetail", "deviceDetail", "resourceDisplayName",
    "isInteractive"
])
    endpoint = (
        f"auditLogs/signIns"
        f"?$filter=createdDateTime ge {since}"
        f"&$select={select_fields}"
        f"&$top=999"
        f"&$orderby=createdDateTime desc"
    )

    events = graph_get(token, endpoint)
    print(f"[+] {len(events)} sign-in events retrieved")
    return events

# =============================================================================
# PULL AUDIT LOGS (includes PIM activation events)
# =============================================================================
def pull_signin_logs(token, since):
    print(f"\n[*] Pulling sign-in logs (since {since})...")

    endpoint = (
        f"auditLogs/signIns"
        f"?$filter=createdDateTime ge {since}"
        f"&$select=id,createdDateTime,userDisplayName,userPrincipalName,"
        f"appDisplayName,clientAppUsed,ipAddress,location,status,"
        f"conditionalAccessStatus,riskLevelAggregated,riskState,"
        f"mfaDetail,deviceDetail,resourceDisplayName,isInteractive"
        f"&$top=999"
        f"&$orderby=createdDateTime desc"
    )

    events = graph_get(token, endpoint)
    print(f"[+] {len(events)} sign-in events retrieved")
    return events

# =============================================================================
# MAIN
# =============================================================================
def main():
    run_start = datetime.now(timezone.utc)
    run_ts    = run_start.strftime("%Y-%m-%dT%H:%M:%SZ")

    print("=" * 55)
    print("  IDSentinel — Entra ID → Splunk Log Ingestor")
    print("  Scenario 10 — Identity Threat Detection Pipeline")
    print("=" * 55)
    print(f"  Run time  : {run_ts}")
    print(f"  HEC target: {SPLUNK_HEC_URL}")
    print(f"  Index     : {SPLUNK_INDEX}")

    state = load_state()
    token = get_access_token()

    # --- SIGN-IN LOGS --------------------------------------------------------
    signin_events = pull_signin_logs(token, state["last_signin_pull"])

    if signin_events:
        print(f"[*] Forwarding {len(signin_events)} sign-in events to Splunk HEC...")
        sent = send_to_splunk(signin_events, sourcetype="azure:monitor:aad:signin")
        print(f"[+] {sent} sign-in events sent → index={SPLUNK_INDEX}")
    else:
        print("    No new sign-in events since last run")

    # --- AUDIT LOGS ----------------------------------------------------------
    audit_events = pull_audit_logs(token, state["last_audit_pull"])

    if audit_events:
        print(f"[*] Forwarding {len(audit_events)} audit events to Splunk HEC...")
        sent = send_to_splunk(audit_events, sourcetype="azure:monitor:aad:audit")
        print(f"[+] {sent} audit events sent → index={SPLUNK_INDEX}")
    else:
        print("    No new audit events since last run")

    # --- UPDATE STATE --------------------------------------------------------
    state["last_signin_pull"] = run_ts
    state["last_audit_pull"]  = run_ts
    save_state(state)

    # --- SUMMARY -------------------------------------------------------------
    total_events = len(signin_events) + len(audit_events)
    print("\n" + "=" * 55)
    print("  INGESTION COMPLETE")
    print("=" * 55)
    print(f"  Sign-in events ingested : {len(signin_events)}")
    print(f"  Audit events ingested   : {len(audit_events)}")
    print(f"  Total events forwarded  : {total_events}")
    print(f"  State file updated      : {STATE_FILE}")
    print(f"\n[*] Schedule this script every 5 minutes via Task Scheduler")
    print("    for continuous automated ingestion.\n")

if __name__ == "__main__":
    main()
