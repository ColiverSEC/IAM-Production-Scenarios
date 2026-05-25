# =============================================================================
# validate-scim-pipeline.ps1
# Description: Validates SCIM provisioning state — confirms group membership
#              in Entra ID matches user presence in AWS IAM Identity Center.
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 13 — SCIM Provisioning: Entra ID → AWS IAM Identity Center
# Requirements: Microsoft Graph PowerShell module, AWS CLI configured
# Usage: .\validate-scim-pipeline.ps1
# =============================================================================

# --- Configuration ---
$Groups = @(
    "GRP-AWS-Engineering",
    "GRP-AWS-DevOps",
    "GRP-AWS-Security"
)

$IdentityStoreId = "d-9a6758588c"  # Your Identity Store ID from IAM Identity Center
$Region = "us-east-2"

# --- Connect to Microsoft Graph ---
Write-Host "`n[*] Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All" -NoWelcome

Write-Host "[*] Fetching Entra group members for scoped AWS groups...`n" -ForegroundColor Cyan

$EntraMembers = @{}

foreach ($GroupName in $Groups) {
    $Group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue
    if (-not $Group) {
        Write-Warning "Group not found in Entra: $GroupName"
        continue
    }

    $Members = Get-MgGroupMember -GroupId $Group.Id -All |
        ForEach-Object { Get-MgUser -UserId $_.Id -ErrorAction SilentlyContinue } |
        Where-Object { $_ -ne $null }

    foreach ($Member in $Members) {
        $EntraMembers[$Member.UserPrincipalName.ToLower()] = $GroupName
    }

    Write-Host "[+] $GroupName — $($Members.Count) members found in Entra" -ForegroundColor Green
}

# --- Fetch IAM Identity Center Users via AWS CLI ---
Write-Host "`n[*] Fetching users from AWS IAM Identity Center..." -ForegroundColor Cyan

$RawUsers = aws identitystore list-users `
    --identity-store-id $IdentityStoreId `
    --region $Region `
    --output json | ConvertFrom-Json

$AWSUsers = @{}
foreach ($User in $RawUsers.Users) {
    $Email = ($User.Emails | Where-Object { $_.Primary -eq $true }).Value
    if ($Email) {
        $AWSUsers[$Email.ToLower()] = $User.UserName
    }
}

Write-Host "[+] $($AWSUsers.Count) users found in IAM Identity Center`n" -ForegroundColor Green

# --- Compare ---
Write-Host "=== VALIDATION RESULTS ===" -ForegroundColor Cyan
Write-Host ""

$Missing = @()
$Matched = @()

foreach ($UPN in $EntraMembers.Keys) {
    if ($AWSUsers.ContainsKey($UPN)) {
        $Matched += $UPN
        Write-Host "[OK]     $UPN" -ForegroundColor Green
    } else {
        $Missing += $UPN
        Write-Host "[MISSING] $UPN — in Entra group $($EntraMembers[$UPN]) but NOT in IAM Identity Center" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Entra scoped members : $($EntraMembers.Count)"
Write-Host "Matched in AWS       : $($Matched.Count)" -ForegroundColor Green
Write-Host "Missing from AWS     : $($Missing.Count)" -ForegroundColor $(if ($Missing.Count -gt 0) { "Red" } else { "Green" })

if ($Missing.Count -eq 0) {
    Write-Host "`n[PASS] SCIM pipeline validated — all Entra members present in IAM Identity Center." -ForegroundColor Green
} else {
    Write-Host "`n[FAIL] $($Missing.Count) user(s) missing from IAM Identity Center — check provisioning logs." -ForegroundColor Red
}