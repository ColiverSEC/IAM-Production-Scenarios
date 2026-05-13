# =============================================================================
# Invoke-IdentityRiskContainment.ps1
# IDSentinel Solutions — IAM Production Scenarios
# Scenario 07 — Identity Risk Response Playbook
#
# Description:
#   Executes containment and remediation actions against a risky user account
#   identified by Entra Identity Protection. Actions include account disable,
#   session revocation, account re-enable, and risk dismissal via Graph API.
#
# Usage:
#   1. Connect to Microsoft Graph with app credentials before running:
#      $secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
#      $credential = New-Object System.Management.Automation.PSCredential($clientId, $secureSecret)
#      Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $credential
#
#   2. Set the $userId variable to the target user's Entra Object ID
#
# Permissions Required (Application):
#   - User.ReadWrite.All
#   - IdentityRiskyUser.ReadWrite.All
#
# =============================================================================

# --- CONFIGURATION -----------------------------------------------------------

$userId = "ce8c4411-564f-4bcc-8231-9132f4c12c28"   # wking object ID
$incidentId = "INC-2026-007"

Write-Output "============================================================"
Write-Output "IDSentinel Solutions — Identity Risk Containment"
Write-Output "Incident: $incidentId"
Write-Output "Target User Object ID: $userId"
Write-Output "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"
Write-Output "============================================================"

# --- PHASE 1: CONTAINMENT ----------------------------------------------------

Write-Output ""
Write-Output "[ CONTAINMENT ] Disabling account..."

$body = @{ accountEnabled = $false } | ConvertTo-Json

Invoke-MgGraphRequest -Method PATCH `
    -Uri "https://graph.microsoft.com/v1.0/users/$userId" `
    -Body $body `
    -ContentType "application/json"

Write-Output "Account disabled: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"

Write-Output ""
Write-Output "[ CONTAINMENT ] Revoking all active sessions..."

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/users/$userId/revokeSignInSessions"

Write-Output "Sessions revoked: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"

# --- PHASE 2: REMEDIATION ----------------------------------------------------

Write-Output ""
Write-Output "[ REMEDIATION ] Re-enabling account post password reset..."

# NOTE: Password reset performed manually via Active Directory Users and
# Computers (ADUC) on the domain controller — wking is a directory-synced
# user. Passwords are mastered on-prem and cannot be reset via Graph API.
# Re-enable the account after confirming the on-prem password reset is complete.

$body = @{ accountEnabled = $true } | ConvertTo-Json

Invoke-MgGraphRequest -Method PATCH `
    -Uri "https://graph.microsoft.com/v1.0/users/$userId" `
    -Body $body `
    -ContentType "application/json"

Write-Output "Account re-enabled: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"

# --- PHASE 3: RISK DISMISSAL -------------------------------------------------

Write-Output ""
Write-Output "[ REMEDIATION ] Dismissing user risk in Identity Protection..."

$dismissBody = @{
    userIds = @($userId)
} | ConvertTo-Json

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers/dismiss" `
    -Body $dismissBody `
    -ContentType "application/json"

Write-Output "Risk dismissed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"

# --- CONFIRM FINAL STATE -----------------------------------------------------

Write-Output ""
Write-Output "[ VERIFICATION ] Confirming final risk state..."

$riskState = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers/$userId"

Write-Output "Final riskState: $($riskState.riskState)"
Write-Output "Final riskLevel: $($riskState.riskLevel)"

Write-Output ""
Write-Output "============================================================"
Write-Output "Containment and remediation complete."
Write-Output "Document actions in RCA template: templates/RCA-Template.md"
Write-Output "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"
Write-Output "============================================================"