# =============================================================================
# Get-LegacyAuthReport.ps1
# Description: Audits legacy authentication sign-ins from Entra ID sign-in logs
#              via Microsoft Graph API. Run BEFORE enforcing CA policy to
#              baseline legacy auth volume and identify impacted users.
#
# Author: Cleveland Oliver | IDSentinel Solutions
# Scenario: 01 - MFA Bypass via Legacy Authentication
# =============================================================================

# Requirements: Microsoft.Graph PowerShell module
# Install: Install-Module Microsoft.Graph -Scope CurrentUser

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Reports

# =============================================================================
# CONNECT TO GRAPH
# =============================================================================
Write-Host "`n[*] Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "AuditLog.Read.All", "Directory.Read.All"

# =============================================================================
# CONFIGURATION
# =============================================================================
$DaysBack   = 7       # How many days of sign-in logs to analyze
$OutputPath = ".\LegacyAuthReport_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
$StartDate  = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-ddTHH:mm:ssZ")

# Legacy auth client app values in Entra sign-in logs
$LegacyClientApps = @(
    "Exchange ActiveSync",
    "IMAP",
    "MAPI",
    "POP3",
    "SMTP",
    "Other clients",
    "Authenticated SMTP",
    "Autodiscover",
    "Exchange Online PowerShell",
    "Exchange Web Services",
    "Legacy Authentication Clients"
)

# =============================================================================
# PULL SIGN-IN LOGS
# =============================================================================
Write-Host "[*] Pulling sign-in logs for the last $DaysBack days..." -ForegroundColor Cyan
Write-Host "    This may take a moment for large tenants...`n" -ForegroundColor Gray

$Filter = "createdDateTime ge $StartDate"

try {
    $SignInLogs = Get-MgAuditLogSignIn -Filter $Filter -All -Property `
        UserPrincipalName, UserDisplayName, AppDisplayName, `
        ClientAppUsed, IpAddress, Location, CreatedDateTime, `
        ConditionalAccessStatus, Status, RiskLevelDuringSignIn

    Write-Host "[+] Retrieved $($SignInLogs.Count) total sign-in events" -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to retrieve sign-in logs: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# =============================================================================
# FILTER FOR LEGACY AUTH
# =============================================================================
Write-Host "[*] Filtering for legacy authentication events..." -ForegroundColor Cyan

$LegacySignIns = $SignInLogs | Where-Object {
    $_.ClientAppUsed -in $LegacyClientApps -or
    $_.ClientAppUsed -like "*legacy*" -or
    $_.ClientAppUsed -eq "Other clients"
}

Write-Host "[+] Found $($LegacySignIns.Count) legacy auth sign-in events`n" -ForegroundColor Yellow

# =============================================================================
# ANALYZE RESULTS
# =============================================================================

# Unique users using legacy auth
$UniqueUsers = $LegacySignIns | Select-Object -ExpandProperty UserPrincipalName -Unique
Write-Host "Unique users authenticating via legacy protocols: $($UniqueUsers.Count)" -ForegroundColor White

# Break down by protocol
Write-Host "`nLegacy Auth by Protocol:" -ForegroundColor Cyan
$LegacySignIns | Group-Object ClientAppUsed | Sort-Object Count -Descending |
    Format-Table Name, Count -AutoSize

# Break down by success vs failure
Write-Host "Authentication Results:" -ForegroundColor Cyan
$LegacySignIns | Group-Object { $_.Status.ErrorCode -eq 0 } |
    ForEach-Object {
        $Result = if ($_.Name -eq "True") { "Success" } else { "Failure" }
        Write-Host "  $Result : $($_.Count)"
    }

# Top 10 impacted users
Write-Host "`nTop 10 Users by Legacy Auth Volume:" -ForegroundColor Cyan
$LegacySignIns | Group-Object UserPrincipalName |
    Sort-Object Count -Descending |
    Select-Object -First 10 |
    Format-Table Name, Count -AutoSize

# =============================================================================
# EXPORT TO CSV
# =============================================================================
Write-Host "[*] Exporting full report to CSV..." -ForegroundColor Cyan

$LegacySignIns | Select-Object `
    UserPrincipalName,
    UserDisplayName,
    ClientAppUsed,
    AppDisplayName,
    @{N='SignInTime';   E={ $_.CreatedDateTime }},
    @{N='IPAddress';    E={ $_.IpAddress }},
    @{N='Country';      E={ $_.Location.CountryOrRegion }},
    @{N='City';         E={ $_.Location.City }},
    @{N='CAStatus';     E={ $_.ConditionalAccessStatus }},
    @{N='RiskLevel';    E={ $_.RiskLevelDuringSignIn }},
    @{N='ResultCode';   E={ $_.Status.ErrorCode }},
    @{N='FailureReason';E={ $_.Status.FailureReason }} |
    Export-Csv -Path $OutputPath -NoTypeInformation

Write-Host "[+] Report saved to: $OutputPath" -ForegroundColor Green

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " LEGACY AUTH AUDIT SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Period analyzed  : Last $DaysBack days" -ForegroundColor White
Write-Host " Total sign-ins   : $($SignInLogs.Count)" -ForegroundColor White
Write-Host " Legacy auth hits : $($LegacySignIns.Count)" -ForegroundColor White
Write-Host " Unique users     : $($UniqueUsers.Count)" -ForegroundColor White
Write-Host " Report exported  : $OutputPath" -ForegroundColor White
Write-Host "`n[!] Review the CSV before enforcing the CA policy." -ForegroundColor Yellow
Write-Host "    Users in this report will be blocked by the policy.`n" -ForegroundColor Yellow

Disconnect-MgGraph