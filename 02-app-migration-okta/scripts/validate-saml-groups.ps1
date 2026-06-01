# =============================================================================
# validate-saml-groups.ps1
# IDSentinel Solutions -- Scenario 02
#
# Compares GRP-ACCESS-HRApps membership between Active Directory and Okta
# to confirm all users are correctly provisioned before cutover.
#
# Provisioning path: AD -> Okta AD Agent (direct)
#
# Prerequisites:
#   - ActiveDirectory PowerShell module (RSAT)
#   - Okta API token with Read Users permission
# =============================================================================

# ---- Configuration ----------------------------------------------------------
$AdGroupName   = "GRP-ACCESS-HRApps"
$OktaGroupName = "GRP-ACCESS-HRApps"
$OktaDomain    = "idsentinelsolutions-integrator-9249015.okta.com"
$OktaApiToken  = "your-okta-api-token"   # Replace with your Okta API token
# -----------------------------------------------------------------------------

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " SAML Group Sync Validation" -ForegroundColor Cyan
Write-Host " AD -> Okta (AD Agent)" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

# --- AD: Get group members ---
Write-Host "Fetching AD group members..." -ForegroundColor Yellow

Import-Module ActiveDirectory
$AdMembers = Get-ADGroupMember -Identity $AdGroupName -Recursive |
    ForEach-Object { (Get-ADUser $_.SamAccountName -Properties UserPrincipalName).UserPrincipalName }

Write-Host "  AD members found: $($AdMembers.Count)" -ForegroundColor White

# --- OKTA: Get group members via Okta API ---
Write-Host "`nFetching Okta group members..." -ForegroundColor Yellow

$Headers = @{
    "Authorization" = "SSWS $OktaApiToken"
    "Content-Type"  = "application/json"
}

$GroupsUrl  = "https://$OktaDomain/api/v1/groups?q=$OktaGroupName"
$OktaGroups = Invoke-RestMethod -Uri $GroupsUrl -Headers $Headers -Method GET
$OktaGroup  = $OktaGroups | Where-Object { $_.profile.name -eq $OktaGroupName } | Select-Object -First 1

$MembersUrl  = "https://$OktaDomain/api/v1/groups/$($OktaGroup.id)/users"
$OktaUsers   = Invoke-RestMethod -Uri $MembersUrl -Headers $Headers -Method GET
$OktaMembers = $OktaUsers | ForEach-Object { $_.profile.login }

Write-Host "  Okta members found: $($OktaMembers.Count)" -ForegroundColor White

# --- COMPARISON ---
Write-Host "`n--- Comparison Results ---" -ForegroundColor Cyan

$MissingFromOkta = $AdMembers   | Where-Object { $_ -notin $OktaMembers }
$ExtraInOkta     = $OktaMembers | Where-Object { $_ -notin $AdMembers }

if ($MissingFromOkta.Count -eq 0) {
    Write-Host "  [PASS] All AD members present in Okta" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Users in AD NOT in Okta ($($MissingFromOkta.Count)):" -ForegroundColor Red
    $MissingFromOkta | ForEach-Object { Write-Host "         - $_" -ForegroundColor Red }
}

if ($ExtraInOkta.Count -eq 0) {
    Write-Host "  [PASS] No unexpected users in Okta group" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Users in Okta NOT in AD ($($ExtraInOkta.Count)):" -ForegroundColor Yellow
    $ExtraInOkta | ForEach-Object { Write-Host "         - $_" -ForegroundColor Yellow }
}

Write-Host "`n  AD count  : $($AdMembers.Count)"
Write-Host "  Okta count: $($OktaMembers.Count)"

$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
[PSCustomObject]@{
    AdCount         = $AdMembers.Count
    OktaCount       = $OktaMembers.Count
    MissingFromOkta = $MissingFromOkta -join ", "
    ExtraInOkta     = $ExtraInOkta -join ", "
    RunAt           = $Timestamp
} | Export-Csv -Path ".\group-sync-report-$Timestamp.csv" -NoTypeInformation

Write-Host "`n  Report saved: group-sync-report-$Timestamp.csv`n" -ForegroundColor Cyan
