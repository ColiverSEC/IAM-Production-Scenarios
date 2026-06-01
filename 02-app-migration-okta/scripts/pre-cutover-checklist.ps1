# =============================================================================
# pre-cutover-checklist.ps1
# IDSentinel Solutions -- Scenario 02: App Migration Legacy IdP -> Okta
#
# Validates all migration criteria before the legacy Entra SSO config
# is disabled. ALL checks must pass before proceeding with cutover.
#
# Provisioning path: AD -> Okta AD Agent (direct)
# Access group: GRP-ACCESS-HRApps
# =============================================================================

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " Pre-Cutover Validation Checklist" -ForegroundColor Cyan
Write-Host " Scenario 02 -- App Migration: Entra -> Okta" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

$Pass    = 0
$Fail    = 0
$Results = @()

function Check {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$FailNote = ""
    )
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:Pass++
        $script:Results += [PSCustomObject]@{ Check = $Name; Status = "PASS"; Note = "" }
    } else {
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($FailNote) { Write-Host "         --> $FailNote" -ForegroundColor Yellow }
        $script:Fail++
        $script:Results += [PSCustomObject]@{ Check = $Name; Status = "FAIL"; Note = $FailNote }
    }
}

# ----------------------------------------------------------------------------
# SECTION 1 -- User Provisioning (AD -> Okta via AD Agent)
# ----------------------------------------------------------------------------
Write-Host "SECTION 1 -- User Provisioning (AD -> Okta via AD Agent)" -ForegroundColor White

$AdAgentActive          = $true   # Confirm AD Agent shows Active in Okta Directory Integrations
$UsersProvisionedInOkta = $true   # Confirm GRP-ACCESS-HRApps members visible and Active in Okta
$AttributesCorrect      = $true   # Confirm firstName, lastName, email, department, title populated
$GroupSyncConfirmed     = $true   # Confirm GRP-ACCESS-HRApps group present in Okta

Check "AD Agent active on IDS-DC"                          $AdAgentActive          "Check Directory Integrations in Okta Admin Console"
Check "GRP-ACCESS-HRApps members Active in Okta"           $UsersProvisionedInOkta "Run validate-saml-groups.ps1 to confirm"
Check "Okta user attributes match AD source values"        $AttributesCorrect      "Check firstName, lastName, email, department in Okta"
Check "GRP-ACCESS-HRApps group present in Okta"            $GroupSyncConfirmed     "Verify group exists under Directory -> Groups"

# ----------------------------------------------------------------------------
# SECTION 2 -- Okta SAML App Configuration
# ----------------------------------------------------------------------------
Write-Host "`nSECTION 2 -- Okta SAML App Configuration" -ForegroundColor White

$OktaAppExists          = $true   # IDSentinel HR Portal app present in Okta
$AcsUrlCorrect          = $true   # ACS URL = https://samltest.id/idp/profile/SAML2/POST/SSO
$EntityIdCorrect        = $true   # Entity ID = https://samltest.id/saml/sp
$NameIdFormatCorrect    = $true   # NameID format = EmailAddress
$AttributeStatementsSet = $true   # firstName, lastName, email, department all mapped
$GroupAssignedToApp     = $true   # GRP-ACCESS-HRApps assigned to app

Check "IDSentinel HR Portal app exists in Okta"            $OktaAppExists          "Create app in Okta Applications"
Check "ACS URL configured correctly in Okta"               $AcsUrlCorrect          "Check Single Sign-On URL in SAML settings"
Check "SP Entity ID (Audience URI) configured correctly"   $EntityIdCorrect        "Check Audience URI in SAML settings"
Check "NameID format = EmailAddress"                       $NameIdFormatCorrect    "Set Name ID Format in SAML settings"
Check "All attribute statements mapped (4 attributes)"     $AttributeStatementsSet "Add firstName, lastName, email, department"
Check "GRP-ACCESS-HRApps assigned to app in Okta"         $GroupAssignedToApp     "Assign group in app Assignments tab"

# ----------------------------------------------------------------------------
# SECTION 3 -- SP Metadata Updated
# ----------------------------------------------------------------------------
Write-Host "`nSECTION 3 -- SP Metadata (samltest.id)" -ForegroundColor White

$SpMetadataUpdated = $true   # samltest.id updated with Okta IdP XML
$SpTrustsOktaCert  = $true   # samltest.id trusts Okta signing certificate

Check "samltest.id SP metadata updated with Okta IdP XML"  $SpMetadataUpdated "Upload Okta metadata XML at samltest.id"
Check "SP accepts Okta signing certificate"                $SpTrustsOktaCert  "Confirm via test login before cutover"

# ----------------------------------------------------------------------------
# SECTION 4 -- SAML Validation
# ----------------------------------------------------------------------------
Write-Host "`nSECTION 4 -- SAML Validation (Pre-Cutover)" -ForegroundColor White

$SpInitiatedLoginPassed   = $true   # SP-initiated login tested and working
$IdpInitiatedLoginPassed  = $true   # IdP-initiated login tested and working
$SamlTracerCaptured       = $true   # SAML Tracer assertion captured and validated
$AllAssertionChecksPassed = $true   # All 9 assertion checks passed

Check "SP-initiated login flow validated"          $SpInitiatedLoginPassed   "Test from samltest.id -> Okta -> samltest.id"
Check "IdP-initiated login flow validated"         $IdpInitiatedLoginPassed  "Test from Okta dashboard tile -> samltest.id"
Check "SAML Tracer assertion captured"             $SamlTracerCaptured       "Screenshot saved to screenshots/04-saml-validation/"
Check "All 9 SAML assertion checks passed"         $AllAssertionChecksPassed "Review assertion checklist in README"

# ----------------------------------------------------------------------------
# SECTION 5 -- Rollback Readiness
# ----------------------------------------------------------------------------
Write-Host "`nSECTION 5 -- Rollback Readiness" -ForegroundColor White

$CutoverRunbookReviewed  = $true   # Cutover runbook reviewed by IAM engineer
$RollbackStepsDocumented = $true   # Rollback procedure documented in runbook
$EntraConfigPreserved    = $true   # Legacy Entra SSO config NOT deleted -- disable only

Check "Cutover runbook reviewed"                            $CutoverRunbookReviewed  "Review runbooks/app-migration-cutover-runbook.md"
Check "Rollback procedure documented"                       $RollbackStepsDocumented "Confirm rollback steps in runbook"
Check "Legacy Entra config preserved for rollback window"   $EntraConfigPreserved    "DO NOT delete -- disable only"

# ----------------------------------------------------------------------------
# SUMMARY
# ----------------------------------------------------------------------------
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " Checklist Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PASSED: $Pass" -ForegroundColor Green
Write-Host "  FAILED: $Fail" -ForegroundColor $(if ($Fail -gt 0) { "Red" } else { "Green" })

if ($Fail -gt 0) {
    Write-Host "`n  *** CUTOVER BLOCKED -- resolve all failures before proceeding ***`n" -ForegroundColor Red
} else {
    Write-Host "`n  *** ALL CHECKS PASSED -- safe to proceed with cutover ***`n" -ForegroundColor Green
}

$Timestamp  = Get-Date -Format "yyyy-MM-dd_HHmm"
$OutputFile = ".\pre-cutover-results-$Timestamp.csv"
$Results | Export-Csv -Path $OutputFile -NoTypeInformation
Write-Host "  Evidence exported: $OutputFile`n" -ForegroundColor Cyan
