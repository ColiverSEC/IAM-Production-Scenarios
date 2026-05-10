# =============================================================================
# Get-IdentityRiskReport.py
# Description: Automates identity risk reporting via Microsoft Graph API
#              using OAuth2 Client Credentials flow. Generates three reports:
#              1. MFA Registration Status
#              2. Guest Account Inventory
#              3. Risky Users
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 06 - OAuth2 API Integration
# Requirements: pip install requests
# =============================================================================

import requests
import json
import csv
import os
from datetime import datetime

# =============================================================================
# CONFIGURATION
# =============================================================================
# Configure these values before running
# Store secrets in environment variables in production
# Never commit real credentials to source control
TENANT_ID     = "YOUR_TENANT_ID"
CLIENT_ID     = "YOUR_CLIENT_ID"  
CLIENT_SECRET = "YOUR_CLIENT_SECRET"

GRAPH_BASE    = "https://graph.microsoft.com"
TOKEN_URL     = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"
OUTPUT_DIR    = "./reports"
TIMESTAMP     = datetime.now().strftime("%Y%m%d_%H%M")

# =============================================================================
# AUTHENTICATE - OAuth2 Client Credentials Flow
# =============================================================================
def get_access_token():
    print("\n[*] Authenticating via OAuth2 Client Credentials flow...")
    
    payload = {
        "grant_type":    "client_credentials",
        "client_id":     CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "scope":         "https://graph.microsoft.com/.default"
    }
    
    response = requests.post(TOKEN_URL, data=payload)
    
    if response.status_code == 200:
        token = response.json().get("access_token")
        print("[+] Access token obtained successfully")
        print(f"    Token type: Bearer")
        print(f"    Expires in: {response.json().get('expires_in')} seconds")
        return token
    else:
        print(f"[!] Authentication failed: {response.status_code}")
        print(f"    {response.json()}")
        exit(1)

# =============================================================================
# GRAPH API HELPER
# =============================================================================
def graph_get(token, endpoint, use_beta=False):
    version = "beta" if use_beta else "v1.0"
    url = f"{GRAPH_BASE}/{version}/{endpoint}"
    headers = {"Authorization": f"Bearer {token}"}
    results = []
    
    while url:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            results.extend(data.get("value", []))
            url = data.get("@odata.nextLink")
        else:
            print(f"[!] API call failed: {response.status_code} - {endpoint}")
            print(f"    {response.json()}")
            break
    
    return results

# =============================================================================
# EXPORT TO CSV
# =============================================================================
def export_csv(data, filename, fieldnames):
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filepath = f"{OUTPUT_DIR}/{filename}_{TIMESTAMP}.csv"
    
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(data)
    
    print(f"[+] Report saved: {filepath}")
    return filepath

# =============================================================================
# REPORT 1 - MFA REGISTRATION STATUS
# =============================================================================
def report_mfa_registration(token):
    print("\n[1/3] Pulling MFA registration report...")
    
    data = graph_get(token, "reports/credentialUserRegistrationDetails", use_beta=True)
    
    if not data:
        print("    No data returned")
        return
    
    not_registered = [u for u in data if not u.get("isMfaRegistered", False)]
    registered     = [u for u in data if u.get("isMfaRegistered", False)]
    
    print(f"    Total users:       {len(data)}")
    print(f"    MFA registered:    {len(registered)}")
    print(f"    MFA NOT registered:{len(not_registered)}")
    
    report_data = [{
        "UserPrincipalName":  u.get("userPrincipalName", ""),
        "DisplayName":        u.get("userDisplayName", ""),
        "IsMFARegistered":    u.get("isMfaRegistered", False),
        "IsSSPRRegistered":   u.get("isSsprRegistered", False),
        "IsSSPREnabled":      u.get("isSsprEnabled", False),
        "AuthMethods":        ", ".join(u.get("authMethods", [])),
        "RiskLevel":          "HIGH" if not u.get("isMfaRegistered") else "LOW"
    } for u in data]
    
    export_csv(report_data, "MFA-Registration-Report",
        ["UserPrincipalName","DisplayName","IsMFARegistered",
         "IsSSPRRegistered","IsSSPREnabled","AuthMethods","RiskLevel"])
    
    if not_registered:
        print(f"\n    [!] Users without MFA (first 5):")
        for u in not_registered[:5]:
            print(f"        - {u.get('userPrincipalName')}")

# =============================================================================
# REPORT 2 - GUEST ACCOUNT INVENTORY
# =============================================================================
def report_guest_accounts(token):
    print("\n[2/3] Pulling guest account inventory...")
    
    data = graph_get(token,
        "users?$filter=userType eq 'Guest'"
        "&$select=displayName,userPrincipalName,createdDateTime,"
        "mail,accountEnabled,signInActivity")
    
    if not data:
        print("    No guest accounts found")
        return
    
    print(f"    Total guest accounts: {len(data)}")
    
    report_data = [{
        "DisplayName":        u.get("displayName", ""),
        "UserPrincipalName":  u.get("userPrincipalName", ""),
        "Mail":               u.get("mail", ""),
        "AccountEnabled":     u.get("accountEnabled", ""),
        "CreatedDateTime":    u.get("createdDateTime", ""),
        "LastSignIn":         u.get("signInActivity", {}).get("lastSignInDateTime", "Never") if u.get("signInActivity") else "Never",
        "RiskLevel":          "MEDIUM" if not u.get("signInActivity") else "LOW"
    } for u in data]
    
    export_csv(report_data, "Guest-Account-Inventory",
        ["DisplayName","UserPrincipalName","Mail",
         "AccountEnabled","CreatedDateTime","LastSignIn","RiskLevel"])
    
    never_signed_in = [u for u in data if not u.get("signInActivity")]
    if never_signed_in:
        print(f"    [!] {len(never_signed_in)} guests have never signed in")

# =============================================================================
# REPORT 3 - RISKY USERS
# =============================================================================
def report_risky_users(token):
    print("\n[3/3] Pulling risky users report...")
    
    data = graph_get(token, "identityProtection/riskyUsers")
    
    if not data:
        print("    [+] No risky users detected in tenant")
        print("        This confirms Identity Protection is active and monitoring")
        return
    
    print(f"    [!] {len(data)} risky users detected")
    
    report_data = [{
        "UserPrincipalName":  u.get("userPrincipalName", ""),
        "DisplayName":        u.get("userDisplayName", ""),
        "RiskLevel":          u.get("riskLevel", ""),
        "RiskState":          u.get("riskState", ""),
        "RiskLastUpdated":    u.get("riskLastUpdatedDateTime", ""),
        "IsDeleted":          u.get("isDeleted", False),
        "RecommendedAction":  "Investigate immediately" if u.get("riskLevel") == "high" else "Monitor"
    } for u in data]
    
    export_csv(report_data, "Risky-Users-Report",
        ["UserPrincipalName","DisplayName","RiskLevel",
         "RiskState","RiskLastUpdated","IsDeleted","RecommendedAction"])

# =============================================================================
# MAIN
# =============================================================================
def main():
    print("=" * 50)
    print(" IDSentinel Identity Risk Reporter")
    print(" Scenario 06 - OAuth2 API Integration")
    print("=" * 50)
    print(f" Run date: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    
    token = get_access_token()
    
    report_mfa_registration(token)
    report_guest_accounts(token)
    report_risky_users(token)
    
    print("\n" + "=" * 50)
    print(" REPORTING COMPLETE")
    print("=" * 50)
    print(f" Reports saved to: {OUTPUT_DIR}/")
    print(f" Timestamp: {TIMESTAMP}")
    print("\n[*] This script is schedulable via Task Scheduler")
    print("    for fully automated weekly execution.\n")

if __name__ == "__main__":
    main()