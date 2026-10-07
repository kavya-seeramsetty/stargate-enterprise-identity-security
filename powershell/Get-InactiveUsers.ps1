# ============================================================
# StarGate - Inactive Account Audit
# File: Get-InactiveUsers.ps1
#
# Purpose:
# Identify Active Directory accounts that may require
# administrative review because of inactivity.
#
# IMPORTANT:
# This script is READ-ONLY.
# It does NOT disable, delete, move, or modify accounts.
# ============================================================

Import-Module ActiveDirectory -ErrorAction Stop

Clear-Host

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " STARGATE INACTIVE ACCOUNT AUDIT" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# 1. Verify Active Directory access
# ------------------------------------------------------------

try {
    Get-ADDomain -ErrorAction Stop | Out-Null
}
catch {
    Write-Host "ERROR: Unable to access Active Directory." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# ------------------------------------------------------------
# 2. Ask for inactivity threshold
# ------------------------------------------------------------

do {
    $InputDays = Read-Host "Enter inactivity threshold in days (for example, 90)"

    $Days = 0
    $ValidNumber = [int]::TryParse($InputDays, [ref]$Days)

    if (
        -not $ValidNumber -or
        $Days -lt 1 -or
        $Days -gt 3650
    ) {
        Write-Host ""
        Write-Host "ERROR: Enter a whole number between 1 and 3650." -ForegroundColor Red
        Write-Host ""
        $ValidInput = $false
    }
    else {
        $ValidInput = $true
    }

} until ($ValidInput)

# ------------------------------------------------------------
# 3. Calculate inactivity threshold
# ------------------------------------------------------------

$ThresholdDate = (Get-Date).AddDays(-$Days)

Write-Host ""
Write-Host "Audit threshold:" -ForegroundColor Yellow
Write-Host "Accounts with a recorded logon before $ThresholdDate will be considered inactive."
Write-Host ""

# ------------------------------------------------------------
# 4. Retrieve Active Directory users
# ------------------------------------------------------------

try {

    $Users = Get-ADUser -Filter * -Properties `
        SamAccountName,
        DisplayName,
        GivenName,
        Surname,
        LastLogonDate,
        Enabled,
        Department,
        Title,
        DistinguishedName,
        Description,
        PasswordLastSet,
        WhenCreated `
        -ErrorAction Stop

}
catch {

    Write-Host "ERROR: Unable to retrieve Active Directory users." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit

}

# ------------------------------------------------------------
# 5. Build audit results
# ------------------------------------------------------------

$Results = foreach ($User in $Users) {

    $LastLogon = $User.LastLogonDate

    if ($LastLogon) {
        $DaysSinceLogon = [math]::Floor(
            ((Get-Date) - $LastLogon).TotalDays
        )
    }
    else {
        $DaysSinceLogon = $null
    }

    # Determine account classification
    if (-not $User.Enabled) {

        $Classification = "Disabled Account"

    }
    elseif (-not $LastLogon) {

        $Classification = "Never Logged On"

    }
    elseif ($LastLogon -lt $ThresholdDate) {

        $Classification = "Inactive Enabled Account"

    }
    else {

        $Classification = "Recently Active"

    }

    [PSCustomObject]@{

        Username          = $User.SamAccountName
        FullName          = $User.DisplayName
        LastLogon         = if ($LastLogon) {
                                $LastLogon
                            }
                            else {
                                "Never Recorded"
                            }

        DaysSinceLogon    = if ($null -ne $DaysSinceLogon) {
                                $DaysSinceLogon
                            }
                            else {
                                "N/A"
                            }

        AccountStatus     = if ($User.Enabled) {
                                "Enabled"
                            }
                            else {
                                "Disabled"
                            }

        Department        = $User.Department
        JobTitle          = $User.Title

        Classification    = $Classification

        PasswordLastSet   = if ($User.PasswordLastSet) {
                                $User.PasswordLastSet
                            }
                            else {
                                "Never Recorded"
                            }

        AccountCreated    = $User.WhenCreated

        DistinguishedName = $User.DistinguishedName

    }
}

# ------------------------------------------------------------
# 6. Separate classifications
# ------------------------------------------------------------

$InactiveAccounts = @(
    $Results | Where-Object {
        $_.Classification -eq "Inactive Enabled Account"
    }
)

$NeverLoggedOn = @(
    $Results | Where-Object {
        $_.Classification -eq "Never Logged On"
    }
)

$DisabledAccounts = @(
    $Results | Where-Object {
        $_.Classification -eq "Disabled Account"
    }
)

$RecentlyActive = @(
    $Results | Where-Object {
        $_.Classification -eq "Recently Active"
    }
)

# ------------------------------------------------------------
# 7. Display summary
# ------------------------------------------------------------

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host " INACTIVE ACCOUNT AUDIT SUMMARY" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

Write-Host ""
Write-Host "Total accounts              : $($Results.Count)"
Write-Host "Recently active             : $($RecentlyActive.Count)"
Write-Host "Inactive enabled accounts   : $($InactiveAccounts.Count)"
Write-Host "Never logged on             : $($NeverLoggedOn.Count)"
Write-Host "Disabled accounts           : $($DisabledAccounts.Count)"

# ------------------------------------------------------------
# 8. Display inactive enabled accounts
# ------------------------------------------------------------

Write-Host ""
Write-Host "==================================================" -ForegroundColor Yellow
Write-Host " INACTIVE ENABLED ACCOUNTS" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Yellow

if ($InactiveAccounts.Count -eq 0) {

    Write-Host ""
    Write-Host "No enabled accounts meet the inactivity threshold." -ForegroundColor Green

}
else {

    $InactiveAccounts |
        Select-Object Username,
                      FullName,
                      LastLogon,
                      DaysSinceLogon,
                      AccountStatus,
                      Department,
                      JobTitle |
        Format-Table -AutoSize

}

# ------------------------------------------------------------
# 9. Display never-logged-on accounts
# ------------------------------------------------------------

Write-Host ""
Write-Host "==================================================" -ForegroundColor Yellow
Write-Host " ENABLED ACCOUNTS THAT HAVE NEVER LOGGED ON" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Yellow

if ($NeverLoggedOn.Count -eq 0) {

    Write-Host ""
    Write-Host "No enabled accounts without recorded logon history." -ForegroundColor Green

}
else {

    $NeverLoggedOn |
        Select-Object Username,
                      FullName,
                      AccountStatus,
                      Department,
                      JobTitle,
                      AccountCreated |
        Format-Table -AutoSize

}

# ------------------------------------------------------------
# 10. Create report folder
# ------------------------------------------------------------

$ReportFolder = "C:\StarGate\Logs\Inactive-Account-Reports"

try {

    if (-not (Test-Path $ReportFolder)) {

        New-Item -Path $ReportFolder `
                 -ItemType Directory `
                 -Force `
                 -ErrorAction Stop | Out-Null

    }

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to create report folder." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit

}

# ------------------------------------------------------------
# 11. Generate report filenames
# ------------------------------------------------------------

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$CsvReport = Join-Path `
    $ReportFolder `
    "Inactive-Users-$Timestamp.csv"

$TextReport = Join-Path `
    $ReportFolder `
    "Inactive-Users-$Timestamp.txt"

# ------------------------------------------------------------
# 12. Export CSV report
# ------------------------------------------------------------

try {

    $Results |
        Export-Csv `
            -Path $CsvReport `
            -NoTypeInformation `
            -Encoding UTF8 `
            -ErrorAction Stop

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to create CSV report." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit

}

# ------------------------------------------------------------
# 13. Generate detailed text report
# ------------------------------------------------------------

try {

    $ReportLines = @()

    $ReportLines += "=================================================="
    $ReportLines += " STARGATE INACTIVE ACCOUNT AUDIT"
    $ReportLines += "=================================================="
    $ReportLines += ""
    $ReportLines += "Audit Date              : $(Get-Date)"
    $ReportLines += "Inactivity Threshold    : $Days days"
    $ReportLines += "Threshold Date          : $ThresholdDate"
    $ReportLines += ""
    $ReportLines += "IMPORTANT:"
    $ReportLines += "This report identifies accounts requiring administrative review."
    $ReportLines += "It does not automatically disable or modify any account."
    $ReportLines += ""
    $ReportLines += "=================================================="
    $ReportLines += " SUMMARY"
    $ReportLines += "=================================================="
    $ReportLines += ""
    $ReportLines += "Total Accounts          : $($Results.Count)"
    $ReportLines += "Recently Active         : $($RecentlyActive.Count)"
    $ReportLines += "Inactive Enabled        : $($InactiveAccounts.Count)"
    $ReportLines += "Never Logged On         : $($NeverLoggedOn.Count)"
    $ReportLines += "Disabled Accounts       : $($DisabledAccounts.Count)"
    $ReportLines += ""

    $ReportLines += "=================================================="
    $ReportLines += " INACTIVE ENABLED ACCOUNTS"
    $ReportLines += "=================================================="
    $ReportLines += ""

    if ($InactiveAccounts.Count -eq 0) {

        $ReportLines += "None"

    }
    else {

        foreach ($Account in $InactiveAccounts) {

            $ReportLines += "Username       : $($Account.Username)"
            $ReportLines += "Full Name      : $($Account.FullName)"
            $ReportLines += "Last Logon     : $($Account.LastLogon)"
            $ReportLines += "Days Inactive  : $($Account.DaysSinceLogon)"
            $ReportLines += "Department     : $($Account.Department)"
            $ReportLines += "Job Title      : $($Account.JobTitle)"
            $ReportLines += "Status         : $($Account.AccountStatus)"
            $ReportLines += "Created        : $($Account.AccountCreated)"
            $ReportLines += "Location       : $($Account.DistinguishedName)"
            $ReportLines += "--------------------------------------------------"

        }

    }

    $ReportLines += ""
    $ReportLines += "=================================================="
    $ReportLines += " ENABLED ACCOUNTS THAT HAVE NEVER LOGGED ON"
    $ReportLines += "=================================================="
    $ReportLines += ""

    if ($NeverLoggedOn.Count -eq 0) {

        $ReportLines += "None"

    }
    else {

        foreach ($Account in $NeverLoggedOn) {

            $ReportLines += "Username       : $($Account.Username)"
            $ReportLines += "Full Name      : $($Account.FullName)"
            $ReportLines += "Department     : $($Account.Department)"
            $ReportLines += "Job Title      : $($Account.JobTitle)"
            $ReportLines += "Created        : $($Account.AccountCreated)"
            $ReportLines += "Location       : $($Account.DistinguishedName)"
            $ReportLines += "--------------------------------------------------"

        }

    }

    $ReportLines += ""
    $ReportLines += "=================================================="
    $ReportLines += " AUDIT CONCLUSION"
    $ReportLines += "=================================================="
    $ReportLines += ""
    $ReportLines += "Inactive enabled accounts should be reviewed by an administrator."
    $ReportLines += "Never-logged-on accounts should be reviewed to determine whether"
    $ReportLines += "they are legitimate new, unused, test, or stale accounts."
    $ReportLines += ""
    $ReportLines += "No accounts were modified by this script."

    $ReportLines |
        Out-File `
            -FilePath $TextReport `
            -Encoding UTF8 `
            -ErrorAction Stop

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to create text report." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit

}

# ------------------------------------------------------------
# 14. Verify report files
# ------------------------------------------------------------

$CsvExists = Test-Path $CsvReport
$TextExists = Test-Path $TextReport

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host " INACTIVE ACCOUNT AUDIT COMPLETE" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

Write-Host ""
Write-Host "Total accounts              : $($Results.Count)"
Write-Host "Recently active             : $($RecentlyActive.Count)"
Write-Host "Inactive enabled            : $($InactiveAccounts.Count)"
Write-Host "Never logged on             : $($NeverLoggedOn.Count)"
Write-Host "Disabled accounts           : $($DisabledAccounts.Count)"

Write-Host ""

if ($CsvExists) {

    Write-Host "CSV report created:" -ForegroundColor Green
    Write-Host $CsvReport

}
else {

    Write-Host "WARNING: CSV report was not created." -ForegroundColor Red

}

Write-Host ""

if ($TextExists) {

    Write-Host "Text report created:" -ForegroundColor Green
    Write-Host $TextReport

}
else {

    Write-Host "WARNING: Text report was not created." -ForegroundColor Red

}

Write-Host ""
Write-Host "No accounts were modified." -ForegroundColor Cyan