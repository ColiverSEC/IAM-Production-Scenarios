# =============================================================================
# Get-OrphanedAccessReport.ps1
# Description: Audits Entra ID for four categories of orphaned access:
#              1. Disabled accounts with active group memberships
#              2. Stale guest accounts inactive 30+ days
#              3. Ownerless groups with active members
#              4. Accounts with no sign-in activity in 90+ days
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 03 - Orphaned Access Audit
# Requirements: Microsoft.Graph PowerShell module
# =============================================================================

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Reports

# =============================================================================
# CONNECT
# =============================================================================
Write-Host "`n[*] Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes `
    "User.Read.All",
    "Group.Read.All",
    "AuditLog.Read.All",
    "Directory.Read.All"

# =============================================================================
# CONFIGURATION
# =============================================================================
$StaleGuestDays    = 30
$InactiveDays      = 90
$ReportPath        = ".\OrphanedAccessReport_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
$StaleGuestCutoff  = (Get-Date).AddDays(-$StaleGuestDays)
$InactiveCutoff    = (Get-Date).AddDays(-$InactiveDays)

$Results = [System.Collections.Generic.List[PSObject]]::new()

Write-Host "[*] Audit started: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "[*] Stale guest threshold  : $StaleGuestDays days" -ForegroundColor Gray
Write-Host "[*] Inactive user threshold: $InactiveDays days`n" -ForegroundColor Gray

# =============================================================================
# CATEGORY 1 - DISABLED ACCOUNTS WITH ACTIVE GROUP MEMBERSHIPS
# =============================================================================
Write-Host "[1/4] Checking disabled accounts with active group memberships..." -ForegroundColor Yellow

$DisabledUsers = Get-MgUser -All `
    -Property Id, DisplayName, UserPrincipalName, AccountEnabled, `
               OnPremisesSyncEnabled, OnPremisesLastSyncDateTime |
    Where-Object { $_.AccountEnabled -eq $false -and $_.OnPremisesSyncEnabled -eq $true }

Write-Host "      Found $($DisabledUsers.Count) disabled synced accounts" -ForegroundColor Gray

$DisabledWithAccess = 0
foreach ($User in $DisabledUsers) {
    $Groups = Get-MgUserMemberOf -UserId $User.Id -All -ErrorAction SilentlyContinue
    if ($Groups.Count -gt 0) {
        $DisabledWithAccess++
        $Results.Add([PSCustomObject]@{
            Category          = "Disabled Account - Active Group Membership"
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            AccountEnabled    = $User.AccountEnabled
            GroupCount        = $Groups.Count
            Groups            = ($Groups | Select-Object -ExpandProperty AdditionalProperties |
                                  ForEach-Object { $_.displayName }) -join "; "
            LastSignIn        = "N/A"
            DaysSinceSignIn   = "N/A"
            RiskLevel         = "HIGH"
            RecommendedAction = "Remove from all groups and revoke sessions immediately"
        })
    }
}
Write-Host "      [!] $DisabledWithAccess disabled accounts still have active group memberships" -ForegroundColor Red

# =============================================================================
# CATEGORY 2 - STALE GUEST ACCOUNTS
# =============================================================================
Write-Host "`n[2/4] Checking stale guest accounts (inactive $StaleGuestDays+ days)..." -ForegroundColor Yellow

$GuestUsers = Get-MgUser -All `
    -Filter "userType eq 'Guest'" `
    -Property Id, DisplayName, UserPrincipalName, SignInActivity, CreatedDateTime |
    Where-Object {
        $_.SignInActivity.LastSignInDateTime -lt $StaleGuestCutoff -or
        $_.SignInActivity.LastSignInDateTime -eq $null
    }

Write-Host "      Found $($GuestUsers.Count) stale guest accounts" -ForegroundColor Gray

foreach ($Guest in $GuestUsers) {
    $LastSignIn = $Guest.SignInActivity.LastSignInDateTime
    $DaysInactive = if ($LastSignIn) {
        [math]::Round(((Get-Date) - $LastSignIn).TotalDays)
    } else { "Never signed in" }

    $Groups = Get-MgUserMemberOf -UserId $Guest.Id -All -ErrorAction SilentlyContinue

    $Results.Add([PSCustomObject]@{
        Category          = "Stale Guest Account"
        DisplayName       = $Guest.DisplayName
        UserPrincipalName = $Guest.UserPrincipalName
        AccountEnabled    = "Guest"
        GroupCount        = $Groups.Count
        Groups            = ($Groups | Select-Object -ExpandProperty AdditionalProperties |
                              ForEach-Object { $_.displayName }) -join "; "
        LastSignIn        = if ($LastSignIn) { $LastSignIn } else { "Never" }
        DaysSinceSignIn   = $DaysInactive
        RiskLevel         = "MEDIUM"
        RecommendedAction = "Review and remove if no longer needed"
    })
}
Write-Host "      [!] $($GuestUsers.Count) stale guest accounts flagged" -ForegroundColor Yellow

# =============================================================================
# CATEGORY 3 - OWNERLESS GROUPS
# =============================================================================
Write-Host "`n[3/4] Checking for ownerless groups with active members..." -ForegroundColor Yellow

$AllGroups = Get-MgGroup -All `
    -Property Id, DisplayName, GroupTypes, MembershipRule, Members |
    Where-Object { $_.DisplayName -like "GRP-*" }

$OwnerlessCount = 0
foreach ($Group in $AllGroups) {
    $Owners = Get-MgGroupOwner -GroupId $Group.Id -All -ErrorAction SilentlyContinue
    $Members = Get-MgGroupMember -GroupId $Group.Id -All -ErrorAction SilentlyContinue

    if ($Owners.Count -eq 0 -and $Members.Count -gt 0) {
        $OwnerlessCount++
        $Results.Add([PSCustomObject]@{
            Category          = "Ownerless Group"
            DisplayName       = $Group.DisplayName
            UserPrincipalName = "N/A - Group Object"
            AccountEnabled    = "N/A"
            GroupCount        = $Members.Count
            Groups            = "N/A"
            LastSignIn        = "N/A"
            DaysSinceSignIn   = "N/A"
            RiskLevel         = "MEDIUM"
            RecommendedAction = "Assign group owner and schedule access review"
        })
    }
}
Write-Host "      [!] $OwnerlessCount ownerless groups with active members found" -ForegroundColor Yellow

# =============================================================================
# CATEGORY 4 - INACTIVE ACCOUNTS 90+ DAYS
# =============================================================================
Write-Host "`n[4/4] Checking accounts inactive for $InactiveDays+ days..." -ForegroundColor Yellow

$InactiveUsers = Get-MgUser -All `
    -Filter "userType eq 'Member'" `
    -Property Id, DisplayName, UserPrincipalName, `
               AccountEnabled, SignInActivity, OnPremisesSyncEnabled |
    Where-Object {
        $_.AccountEnabled -eq $true -and
        $_.SignInActivity.LastSignInDateTime -ne $null -and
        $_.SignInActivity.LastSignInDateTime -lt $InactiveCutoff
    }

Write-Host "      Found $($InactiveUsers.Count) accounts inactive 90+ days" -ForegroundColor Gray

foreach ($User in $InactiveUsers) {
    $LastSignIn = $User.SignInActivity.LastSignInDateTime
    $DaysInactive = [math]::Round(((Get-Date) - $LastSignIn).TotalDays)

    $Groups = Get-MgUserMemberOf -UserId $User.Id -All -ErrorAction SilentlyContinue

    $Results.Add([PSCustomObject]@{
        Category          = "Inactive Account 90+ Days"
        DisplayName       = $User.DisplayName
        UserPrincipalName = $User.UserPrincipalName
        AccountEnabled    = $User.AccountEnabled
        GroupCount        = $Groups.Count
        Groups            = ($Groups | Select-Object -ExpandProperty AdditionalProperties |
                              ForEach-Object { $_.displayName }) -join "; "
        LastSignIn        = $LastSignIn
        DaysSinceSignIn   = $DaysInactive
        RiskLevel         = if ($DaysInactive -gt 180) { "HIGH" } else { "MEDIUM" }
        RecommendedAction = "Confirm employment status — disable if no longer active"
    })
}
Write-Host "      [!] $($InactiveUsers.Count) inactive accounts flagged" -ForegroundColor Yellow

# =============================================================================
# EXPORT REPORT
# =============================================================================
Write-Host "`n[*] Exporting report to CSV..." -ForegroundColor Cyan
$Results | Export-Csv -Path $ReportPath -NoTypeInformation
Write-Host "[+] Report saved to: $ReportPath" -ForegroundColor Green

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " ORPHANED ACCESS AUDIT SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Audit Date        : $(Get-Date -Format 'yyyy-MM-dd')" -ForegroundColor White
Write-Host " Total Findings    : $($Results.Count)" -ForegroundColor White

$HighRisk = $Results | Where-Object { $_.RiskLevel -eq "HIGH" }
$MedRisk  = $Results | Where-Object { $_.RiskLevel -eq "MEDIUM" }

Write-Host " HIGH Risk Items   : $($HighRisk.Count)" -ForegroundColor Red
Write-Host " MEDIUM Risk Items : $($MedRisk.Count)" -ForegroundColor Yellow
Write-Host "`n Findings by Category:" -ForegroundColor White

$Results | Group-Object Category | Sort-Object Count -Descending |
    ForEach-Object {
        Write-Host ("  {0,-45} {1} findings" -f $_.Name, $_.Count) -ForegroundColor White
    }

Write-Host "`n[!] Review the CSV report and remediate HIGH risk items within 24 hours." -ForegroundColor Yellow
Write-Host "[!] MEDIUM risk items should be reviewed within 7 days.`n" -ForegroundColor Yellow

Disconnect-MgGraph