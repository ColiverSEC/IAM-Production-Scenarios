# =============================================================================
# Validate-ZeroTrustPosture.ps1
# Description: Validates Zero Trust implementation by checking:
#              1. CA policies are enabled and correctly configured
#              2. PIM eligible role assignments are in place
#              3. No permanent privileged role assignments outside break-glass
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 04 - Zero Trust Rollout
# =============================================================================

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Identity.SignIns
Import-Module Microsoft.Graph.Identity.Governance

Write-Host "`n[*] Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Policy.Read.All", "RoleManagement.Read.Directory", "Directory.Read.All"

$PassCount = 0
$FailCount = 0
$Results   = [System.Collections.Generic.List[PSObject]]::new()

function Add-Result {
    param($Check, $Status, $Detail)
    $Results.Add([PSCustomObject]@{
        Check  = $Check
        Status = $Status
        Detail = $Detail
    })
    if ($Status -eq "PASS") { $script:PassCount++ }
    else { $script:FailCount++ }
}

# =============================================================================
# CHECK 1 - CONDITIONAL ACCESS POLICIES
# =============================================================================
Write-Host "`n[1/3] Validating Conditional Access policies..." -ForegroundColor Yellow

$ExpectedPolicies = @(
    "Block Legacy Authentication - All Users",
    "Block High Risk Sign-ins - All Users",
    "Require MFA - All Users",
    "Restrict Admin Portal Access - Privileged Users Only"
)

$CAPolicies = Get-MgIdentityConditionalAccessPolicy -All

foreach ($Expected in $ExpectedPolicies) {
    $Policy = $CAPolicies | Where-Object { $_.DisplayName -like "*$($Expected.Split('-')[0].Trim())*" }
    if ($Policy) {
        $State = $Policy.State
        $Status = if ($State -in @("enabled","enabledForReportingButNotEnforced")) { "PASS" } else { "FAIL" }
        Add-Result -Check "CA Policy: $Expected" -Status $Status -Detail "State: $State"
        Write-Host "  [$Status] $Expected — $State" -ForegroundColor $(if ($Status -eq "PASS") { "Green" } else { "Red" })
    } else {
        Add-Result -Check "CA Policy: $Expected" -Status "FAIL" -Detail "Policy not found"
        Write-Host "  [FAIL] $Expected — NOT FOUND" -ForegroundColor Red
    }
}

# =============================================================================
# CHECK 2 - PIM ELIGIBLE ASSIGNMENTS
# =============================================================================
Write-Host "`n[2/3] Validating PIM eligible role assignments..." -ForegroundColor Yellow

$ExpectedRoles = @(
    "Security Administrator",
    "Identity Administrator",
    "Conditional Access Administrator",
    "Helpdesk Administrator",
    "User Administrator",
    "Billing Administrator",
    "Application Administrator"
)

try {
    $EligibleAssignments = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All `
        -ExpandProperty "principal,roleDefinition" -ErrorAction Stop

    foreach ($Role in $ExpectedRoles) {
        $Assignment = $EligibleAssignments | Where-Object {
            $_.RoleDefinition.DisplayName -eq $Role
        }
        if ($Assignment) {
            $PrincipalCount = ($Assignment | Measure-Object).Count
            Add-Result -Check "PIM Eligible: $Role" -Status "PASS" -Detail "$PrincipalCount eligible assignment(s)"
            Write-Host "  [PASS] $Role — $PrincipalCount eligible assignment(s)" -ForegroundColor Green
        } else {
            Add-Result -Check "PIM Eligible: $Role" -Status "FAIL" -Detail "No eligible assignments found"
            Write-Host "  [FAIL] $Role — No eligible assignments" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "  [!] Could not retrieve PIM assignments: $($_.Exception.Message)" -ForegroundColor Yellow
}

# =============================================================================
# CHECK 3 - NO PERMANENT PRIVILEGED ASSIGNMENTS OUTSIDE BREAK-GLASS
# =============================================================================
Write-Host "`n[3/3] Checking for permanent privileged role assignments..." -ForegroundColor Yellow

$PrivilegedRoles = @(
    "Global Administrator",
    "Security Administrator",
    "Identity Administrator",
    "Conditional Access Administrator"
)

$BreakGlassAccounts = @(
    "BreakGlassAdmin01@IDSentinelSolutions.com",
    "Coliver@IDSentinelSolutions.com"
)

try {
    $ActiveAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All `
        -ExpandProperty "principal,roleDefinition" -ErrorAction Stop

    foreach ($Role in $PrivilegedRoles) {
        $Assignments = $ActiveAssignments | Where-Object {
            $_.RoleDefinition.DisplayName -eq $Role
        }

        $NonBreakGlass = $Assignments | Where-Object {
            $_.Principal.AdditionalProperties.userPrincipalName -notin $BreakGlassAccounts
        }

        if ($NonBreakGlass.Count -eq 0) {
            Add-Result -Check "Permanent Assignment: $Role" -Status "PASS" `
                -Detail "No permanent assignments outside break-glass"
            Write-Host "  [PASS] $Role — No unauthorized permanent assignments" -ForegroundColor Green
        } else {
            $Users = ($NonBreakGlass | ForEach-Object {
                $_.Principal.AdditionalProperties.userPrincipalName
            }) -join ", "
            Add-Result -Check "Permanent Assignment: $Role" -Status "WARN" `
                -Detail "Permanent assignment found: $Users"
            Write-Host "  [WARN] $Role — Permanent assignment: $Users" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  [!] Could not retrieve role assignments: $($_.Exception.Message)" -ForegroundColor Yellow
}

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " ZERO TRUST VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Date        : $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor White
Write-Host " Total Checks: $($PassCount + $FailCount)" -ForegroundColor White
Write-Host " PASS        : $PassCount" -ForegroundColor Green
Write-Host " FAIL        : $FailCount" -ForegroundColor Red

Write-Host "`nDetailed Results:" -ForegroundColor White
$Results | Format-Table Check, Status, Detail -AutoSize -Wrap

Disconnect-MgGraph