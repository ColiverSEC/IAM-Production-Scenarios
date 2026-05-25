# =============================================================================
# audit-stale-assignments.ps1
# Description: Audits AWS IAM Identity Center for users whose Entra ID
#              accounts are disabled — identifies stale/orphaned access.
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 13 — SCIM Provisioning: Entra ID → AWS IAM Identity Center
# Requirements: Microsoft Graph PowerShell module, AWS CLI configured
# Usage: .\audit-stale-assignments.ps1
# =============================================================================

# --- Configuration ---
$IdentityStoreId = "d-9a6758588c"
$Region = "us-east-2"
$ExportPath = ".\evidence\stale-assignments-audit-$(Get-Date -Format 'yyyy-MM-dd').csv"

# --- Connect ---
Write-Host "`n[*] Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.Read.All" -NoWelcome

# --- Fetch IAM Identity Center Users ---
Write-Host "[*] Fetching users from AWS IAM Identity Center..." -ForegroundColor Cyan

$RawUsers = aws identitystore list-users `
    --identity-store-id $IdentityStoreId `
    --region $Region `
    --output json | ConvertFrom-Json

Write-Host "[+] $($RawUsers.Users.Count) users found in IAM Identity Center`n" -ForegroundColor Green

# --- Check each user against Entra ---
Write-Host "=== STALE ACCESS AUDIT ===" -ForegroundColor Cyan
Write-Host ""

$Results = @()

foreach ($User in $RawUsers.Users) {
    $Email = ($User.Emails | Where-Object { $_.Primary -eq $true }).Value
    if (-not $Email) { continue }

    $EntraUser = Get-MgUser -Filter "userPrincipalName eq '$Email'" `
        -Property "displayName,userPrincipalName,accountEnabled" `
        -ErrorAction SilentlyContinue

    $Status = if (-not $EntraUser) {
        "NOT FOUND IN ENTRA"
    } elseif ($EntraUser.AccountEnabled -eq $false) {
        "DISABLED IN ENTRA"
    } else {
        "Active"
    }

    $Color = switch ($Status) {
        "Active"             { "Green" }
        "DISABLED IN ENTRA"  { "Red" }
        "NOT FOUND IN ENTRA" { "Yellow" }
    }

    Write-Host "[$Status] $Email" -ForegroundColor $Color

    $Results += [PSCustomObject]@{
        UserName        = $User.UserName
        Email           = $Email
        DisplayName     = $EntraUser.DisplayName ?? "N/A"
        EntraStatus     = $Status
        AuditDate       = (Get-Date -Format "yyyy-MM-dd")
    }
}

# --- Summary ---
$Stale = $Results | Where-Object { $_.EntraStatus -ne "Active" }

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total IAM Identity Center users : $($Results.Count)"
Write-Host "Active in Entra                 : $(($Results | Where-Object { $_.EntraStatus -eq 'Active' }).Count)" -ForegroundColor Green
Write-Host "Disabled/missing in Entra       : $($Stale.Count)" -ForegroundColor $(if ($Stale.Count -gt 0) { "Red" } else { "Green" })

# --- Export ---
$Results | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "`n[+] Audit exported to: $ExportPath" -ForegroundColor Cyan

if ($Stale.Count -gt 0) {
    Write-Host "`n[!] ACTION REQUIRED: $($Stale.Count) stale assignment(s) found — review and remove." -ForegroundColor Red
} else {
    Write-Host "`n[PASS] No stale assignments found." -ForegroundColor Green
}