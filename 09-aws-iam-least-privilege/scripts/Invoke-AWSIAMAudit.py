# =============================================================================
# Invoke-AWSIAMAudit.py
# Description: Validates the IDSentinel AWS IAM least-privilege scenario by:
#              1. Confirming caller identity pre- and post-role assumption
#              2. Assuming Role-IDSentinel-Auditor via STS with ExternalId
#              3. Validating read access is allowed (iam:ListUsers)
#              4. Validating write access is denied (iam:CreateUser)
#              5. Exporting a full audit report to CSV
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 09 - AWS IAM Least-Privilege & Role Assumption
# =============================================================================

# Requirements:
#   pip install boto3
#   AWS CLI configured with profile: idsentinel-reporter
#   Replace ACCOUNT_ID below before running

import boto3
import csv
import json
import datetime
from botocore.exceptions import ClientError

# =============================================================================
# CONFIGURATION — update ACCOUNT_ID before running
# =============================================================================
ACCOUNT_ID      = "ACCOUNT_ID"
ROLE_ARN        = f"arn:aws:iam::{635649352714}:role/Role-IDSentinel-Auditor"
SESSION_NAME    = "IDSentinel-AuditSession-01"
EXTERNAL_ID     = "IDSentinel-Lab-2026"
AWS_PROFILE     = "idsentinel-reporter"
OUTPUT_PATH     = f"./AWSIAMAuditReport_{datetime.datetime.now().strftime('%Y%m%d_%H%M')}.csv"

results = []

# =============================================================================
# HELPER
# =============================================================================
def log(status, check, detail):
    tag = "[+]" if status == "PASS" else "[!]" if status == "EXPECTED_DENY" else "[-]"
    color = "\033[92m" if status == "PASS" else "\033[93m" if status == "EXPECTED_DENY" else "\033[91m"
    reset = "\033[0m"
    print(f"  {color}{tag}{reset} {check}: {detail}")
    results.append({
        "Timestamp":  datetime.datetime.utcnow().isoformat() + "Z",
        "Status":     status,
        "Check":      check,
        "Detail":     detail
    })

# =============================================================================
# STEP 1 — BASELINE IDENTITY (user, before assumption)
# =============================================================================
print("\n" + "=" * 60)
print("  IDSentinel AWS IAM Audit — Scenario 09")
print("=" * 60)

print("\n[1/5] Confirming baseline identity (service user)...")

session = boto3.Session(profile_name=AWS_PROFILE)
sts_client = session.client("sts")

try:
    identity = sts_client.get_caller_identity()
    print(f"\n  Account : {identity['Account']}")
    print(f"  UserID  : {identity['UserId']}")
    print(f"  ARN     : {identity['Arn']}\n")
    log("PASS", "Baseline identity confirmed", identity["Arn"])
except ClientError as e:
    log("FAIL", "Baseline identity check failed", str(e))
    print("\n[!] Cannot connect to AWS. Check your CLI profile and credentials.")
    exit(1)

# =============================================================================
# STEP 2 — ASSUME ROLE VIA STS
# =============================================================================
print("\n[2/5] Assuming role via STS...")

try:
    assumed = sts_client.assume_role(
        RoleArn=ROLE_ARN,
        RoleSessionName=SESSION_NAME,
        ExternalId=EXTERNAL_ID
    )
    creds = assumed["Credentials"]
    expiry = creds["Expiration"].strftime("%Y-%m-%d %H:%M:%S UTC")

    print(f"\n  Role ARN     : {ROLE_ARN}")
    print(f"  Session Name : {SESSION_NAME}")
    print(f"  Expiration   : {expiry}")
    print(f"  AccessKeyId  : {creds['AccessKeyId'][:16]}... [truncated]\n")

    log("PASS", "STS AssumeRole succeeded", f"Session: {SESSION_NAME} | Expires: {expiry}")
except ClientError as e:
    log("FAIL", "STS AssumeRole failed", str(e))
    print("\n[!] Role assumption failed. Check ACCOUNT_ID, trust policy, and ExternalId.")
    exit(1)

# =============================================================================
# STEP 3 — CONFIRM POST-ASSUMPTION IDENTITY
# =============================================================================
print("\n[3/5] Confirming identity post-assumption (should show role ARN)...")

role_session = boto3.Session(
    aws_access_key_id=creds["AccessKeyId"],
    aws_secret_access_key=creds["SecretAccessKey"],
    aws_session_token=creds["SessionToken"]
)
sts_role = role_session.client("sts")

try:
    role_identity = sts_role.get_caller_identity()
    print(f"\n  Account : {role_identity['Account']}")
    print(f"  UserID  : {role_identity['UserId']}")
    print(f"  ARN     : {role_identity['Arn']}\n")

    if "Role-IDSentinel-Auditor" in role_identity["Arn"]:
        log("PASS", "Post-assumption identity confirmed", role_identity["Arn"])
    else:
        log("FAIL", "Post-assumption identity unexpected", role_identity["Arn"])
except ClientError as e:
    log("FAIL", "Post-assumption identity check failed", str(e))

# =============================================================================
# STEP 4 — VALIDATE READ ACCESS IS ALLOWED (iam:ListUsers)
# =============================================================================
print("\n[4/5] Validating read access (iam:ListUsers — should be ALLOWED)...")

iam_role = role_session.client("iam")

try:
    response = iam_role.list_users(MaxItems=5)
    user_count = len(response.get("Users", []))
    log("PASS", "iam:ListUsers allowed", f"{user_count} user(s) returned — read access confirmed")
    print(f"\n  Returned {user_count} IAM user(s) — read access confirmed\n")
except ClientError as e:
    log("FAIL", "iam:ListUsers unexpectedly denied", str(e))

# =============================================================================
# STEP 5 — VALIDATE WRITE ACCESS IS DENIED (iam:CreateUser)
# =============================================================================
print("\n[5/5] Validating write access (iam:CreateUser — should be DENIED)...")

try:
    iam_role.create_user(UserName="test-deny-check-DELETE-ME")
    # If we reach here, the deny failed — this is a problem
    log("FAIL", "iam:CreateUser was NOT denied — policy misconfiguration", "Write access should have been blocked")
    print("\n  [!] WARNING: Write access was NOT denied. Review your policy.\n")

    # Clean up the accidentally created user
    iam_role.delete_user(UserName="test-deny-check-DELETE-ME")
    print("  [*] Cleanup: test user deleted.\n")

except ClientError as e:
    error_code = e.response["Error"]["Code"]
    if error_code == "AccessDenied":
        log("EXPECTED_DENY", "iam:CreateUser denied — explicit Deny confirmed", f"Error: {error_code}")
        print(f"\n  AccessDenied received as expected — deny policy enforced\n")
    else:
        log("FAIL", "iam:CreateUser failed with unexpected error", str(e))

# =============================================================================
# EXPORT REPORT
# =============================================================================
print("\n[*] Exporting audit report to CSV...")

with open(OUTPUT_PATH, "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["Timestamp", "Status", "Check", "Detail"])
    writer.writeheader()
    writer.writerows(results)

print(f"[+] Report saved to: {OUTPUT_PATH}")

# =============================================================================
# SUMMARY
# =============================================================================
passed   = [r for r in results if r["Status"] == "PASS"]
denied   = [r for r in results if r["Status"] == "EXPECTED_DENY"]
failed   = [r for r in results if r["Status"] == "FAIL"]

print("\n" + "=" * 60)
print("  AUDIT SUMMARY")
print("=" * 60)
print(f"  Checks run      : {len(results)}")
print(f"  Passed          : {len(passed)}")
print(f"  Expected Denies : {len(denied)}")
print(f"  Failed          : {len(failed)}")
print(f"  Report exported : {OUTPUT_PATH}")

if len(failed) == 0:
    print("\n  [+] All checks passed — least-privilege controls validated.")
else:
    print(f"\n  [!] {len(failed)} check(s) failed — review output above.")

print("=" * 60 + "\n")
