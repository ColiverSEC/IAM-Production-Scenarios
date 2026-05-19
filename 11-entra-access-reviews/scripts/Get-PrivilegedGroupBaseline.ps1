# ==============================================================================
# Get-PrivilegedGroupBaseline.ps1
# Scenario 11 — Entra Access Reviews
# IDSentinel Solutions | Cleveland Oliver
#
# Purpose:
#   Audits current membership of GRP-SEC-PrivilegedUsers before an Access
#   Review launches. Exports a CSV snapshot as SOC 2 "before" evidence.
#   Optionally checks manager attribute population for reviewer routing.
#
# Usage:
#   .\Get-PrivilegedGroupBaseline.ps1
#   .\Get-PrivilegedGroupBaseline.ps1 -CheckManagers
#
# Requirements:
#   - Microsoft.Graph PowerShell module
#   - Group.Read.All, User.Read.All delegated or app permissions
# ==============================================================================

param(
    [switch]$CheckManagers
)

# ── Config ────────────────────────────────────────────────────────────────────
$GroupDisplayName = "GRP-SEC-PrivilegedUsers"
$OutputDir        = "$PSScriptRoot\..\audit-exports"
$Timestamp        = Get-Date -Format "yyyy-MM-dd_HHmm"
$BaselineFile     = "$OutputDir\privileged-group-baseline_$Timestamp.csv"

# ── Connect ───────────────────────────────────────────────────────────────────
Write-Host "`n[*] Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Group.Read.All","User.Read.All","Directory.Read.All" -NoWelcome

# ── Get Group ─────────────────────────────────────────────────────────────────
Write-Host "[*] Resolving group: $GroupDisplayName" -ForegroundColor Cyan
$Group = Get-MgGroup -Filter "displayName eq '$GroupDisplayName'" -Property "Id,DisplayName,Description"

if (-not $Group) {
    Write-Host "[!] Group '$GroupDisplayName' not found. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "[+] Found group: $($Group.DisplayName) — ID: $($Group.Id)" -ForegroundColor Green

# ── Get Members (batch — typed endpoint returns user properties directly) ──────
Write-Host "[*] Retrieving group members..." -ForegroundColor Cyan

# Get-MgGroupMemberAsUser returns user objects with properties in one call
# avoiding a separate Get-MgUser per member (much faster for large groups)
$Members = Get-MgGroupMemberAsUser -GroupId $Group.Id -All `
    -Property "Id,DisplayName,UserPrincipalName,Department,JobTitle,AccountEnabled"

if ($Members.Count -eq 0) {
    Write-Host "[!] Group has no members. Review scope will be empty." -ForegroundColor Yellow
    exit 0
}

Write-Host "[+] Member count: $($Members.Count)" -ForegroundColor Green

# ── Enrich Member Data ────────────────────────────────────────────────────────
$BaselineReport = @()
$i = 0

foreach ($User in $Members) {
    $i++
    Write-Progress -Activity "Building baseline" `
        -Status "Processing $i of $($Members.Count): $($User.DisplayName)" `
        -PercentComplete (($i / $Members.Count) * 100)

    $ManagerName = "N/A"
    $ManagerUPN  = "N/A"
    $ManagerSet  = $false

    if ($CheckManagers) {
        try {
            $Mgr = Get-MgUserManager -UserId $User.Id -ErrorAction Stop
            $MgrDetails  = Get-MgUser -UserId $Mgr.Id -Property "DisplayName,UserPrincipalName"
            $ManagerName = $MgrDetails.DisplayName
            $ManagerUPN  = $MgrDetails.UserPrincipalName
            $ManagerSet  = $true
        } catch {
            $ManagerName = "NOT SET"
            $ManagerUPN  = "NOT SET"
            $ManagerSet  = $false
        }
    }

    $BaselineReport += [PSCustomObject]@{
        DisplayName         = $User.DisplayName
        UserPrincipalName   = $User.UserPrincipalName
        Department          = $User.Department
        JobTitle            = $User.JobTitle
        AccountEnabled      = $User.AccountEnabled
        LastSignIn          = "See Entra Sign-in Logs"
        ManagerDisplayName  = $ManagerName
        ManagerUPN          = $ManagerUPN
        ManagerAttributeSet = $ManagerSet
        SnapshotDate        = (Get-Date -Format "yyyy-MM-dd HH:mm")
        GroupName           = $Group.DisplayName
    }
}

Write-Progress -Activity "Building baseline" -Completed

# ── Output to Console ─────────────────────────────────────────────────────────
Write-Host "`n── Privileged Group Baseline ─────────────────────────────────" -ForegroundColor Cyan
$BaselineReport | Format-Table DisplayName, Department, JobTitle, AccountEnabled, LastSignIn -AutoSize

if ($CheckManagers) {
    Write-Host "`n── Manager Attribute Check ───────────────────────────────────" -ForegroundColor Cyan
    $BaselineReport | Format-Table DisplayName, ManagerDisplayName, ManagerUPN, ManagerAttributeSet -AutoSize

    $NoManager = $BaselineReport | Where-Object { -not $_.ManagerAttributeSet }
    if ($NoManager.Count -gt 0) {
        Write-Host "[!] WARNING — $($NoManager.Count) member(s) have no manager set." -ForegroundColor Yellow
        Write-Host "    These users will fall to the fallback reviewer (group owner)." -ForegroundColor Yellow
        $NoManager | ForEach-Object {
            Write-Host "    → $($_.DisplayName) ($($_.UserPrincipalName))" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[+] All members have manager attribute set. Review routing is complete." -ForegroundColor Green
    }
}

# ── Export CSV ────────────────────────────────────────────────────────────────
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
$BaselineReport | Export-Csv -Path $BaselineFile -NoTypeInformation -Encoding UTF8

Write-Host "`n[+] Baseline exported: $BaselineFile" -ForegroundColor Green
Write-Host "[+] Member count: $($BaselineReport.Count)" -ForegroundColor Green
Write-Host "[i] Use this file as SOC 2 'before' evidence for the access review cycle.`n" -ForegroundColor DarkCyan