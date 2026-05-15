# =============================================================================
# cli-commands.sh
# Description: All AWS CLI commands for Scenario 09 in execution order.
#              Run these manually in your terminal — each command maps to
#              a screenshot step in the README.
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 09 - AWS IAM Least-Privilege & Role Assumption
#
# BEFORE YOU START:
#   1. Replace ACCOUNT_ID with your 12-digit AWS account ID
#   2. Ensure AWS CLI is installed: aws --version
#   3. Ensure boto3 is installed: pip install boto3
# =============================================================================

ACCOUNT_ID="635649352714"

# =============================================================================
# PHASE 1 — Configure CLI profile for service user
# Run after creating svc-idsentinel-reporter and downloading its access key
# =============================================================================

aws configure --profile idsentinel-reporter
# Enter when prompted:
#   AWS Access Key ID:     <from IAM console — access key you downloaded>
#   AWS Secret Access Key: <from IAM console>
#   Default region:        us-east-1
#   Default output format: json


# =============================================================================
# SCREENSHOT 07 — Baseline identity (user, before role assumption)
# =============================================================================

aws sts get-caller-identity --profile idsentinel-reporter


# =============================================================================
# SCREENSHOT 08 — Assume the role, capture temp credentials
# =============================================================================

aws sts assume-role \
  --role-arn "arn:aws:iam::${635649352714}:role/Role-IDSentinel-Auditor" \
  --role-session-name "IDSentinel-AuditSession-01" \
  --external-id "IDSentinel-Lab-2026" \
  --profile idsentinel-reporter


# =============================================================================
# Export temp credentials from the assume-role output above
# Copy AccessKeyId, SecretAccessKey, SessionToken from the JSON response
# =============================================================================

export AWS_ACCESS_KEY_ID="PASTE_AccessKeyId_HERE"
export AWS_SECRET_ACCESS_KEY="PASTE_SecretAccessKey_HERE"
export AWS_SESSION_TOKEN="PASTE_SessionToken_HERE"


# =============================================================================
# SCREENSHOT 09 — Post-assumption identity (should show role ARN, not user)
# =============================================================================

aws sts get-caller-identity


# =============================================================================
# SCREENSHOT 10 — Read access allowed (iam:ListUsers)
# =============================================================================

aws iam list-users


# =============================================================================
# SCREENSHOT 11 — Write access denied (iam:CreateUser — expect AccessDenied)
# =============================================================================

aws iam create-user --user-name test-deny-check


# =============================================================================
# PHASE 2 — Run the Python audit script (automates all of the above + CSV export)
# Run this AFTER completing the manual CLI steps above
# =============================================================================

# 1. Open scripts/Invoke-AWSIAMAudit.py
# 2. Replace ACCOUNT_ID at the top of the file with your actual account ID
# 3. Run:

pip install boto3
python scripts/Invoke-AWSIAMAudit.py


# =============================================================================
# PHASE 3 — Verify CloudTrail captured the AssumeRole event
# Wait ~5 minutes after running the CLI commands above, then run:
# =============================================================================

aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole \
  --max-results 5

# This should return your IDSentinel-AuditSession-01 event.
# Also check in the AWS Console:
#   CloudTrail → Event history → Filter: EventName = AssumeRole
