# ============================================================
# StarGate - Privileged Group Audit
# Script: Audit-PrivilegedGroups.ps1
#
# Purpose:
# Audit privileged Active Directory group membership and
# identify unexpected administrative access.
#
# IMPORTANT:
# This script is READ-ONLY.
# It does NOT add, remove, disable, or modify accounts.
# ============================================================

Clear-Host

Import-Module ActiveDirectory -ErrorAction Stop

# ============================================================
# CONFIGURATION
# ============================================================

$ReportFolder = "C:\StarGate\Logs\Privileged-Group-Audit"

# These are the ACTUAL privileged group names found in
# the StarGate Active Directory environment.

$PrivilegedGroups = @(
    "SG-Computer-Account-Adminstrators",
    "SG-Domain-Administrators",
    "SG-Group-Administrators",
    "SG-Helpdesk-Administrators",
    "SG-Identity-Administrators",
    "SG-IT-Administrators",
    "SG-Infrastructure-Administrators",
    "SG-Network-Administrators"
)

# ============================================================
# APPROVED STAR GATE ADMINISTRATIVE ACCOUNTS
# ============================================================
#
# These accounts represent the administrative identities
# already established in the StarGate administrative
# separation model.
#
# The script uses these accounts to determine whether a
# privileged membership is expected.
#
# Domain Admin:
# adm.heather.ortiz
#
# Helpdesk:
# adm.betty.gutierrez
#
# Identity:
# adm.identity.admin
#
# Group:
# adm.group.admin
#
# Computer:
# adm.computer.admin
#
# Infrastructure:
# adm.joshua.chavez
#
# Network:
# adm.rebecca.myers
#
# IT:
# No separate IT administrator account was previously
# established in the StarGate model.
# Any membership here will therefore require review.
#
# ============================================================

$ApprovedMemberships = @{
    "SG-Computer-Account-Adminstrators" = @(
        "adm.computer.admin"
    )

    "SG-Domain-Administrators" = @(
        "adm.heather.ortiz"
    )

    "SG-Group-Administrators" = @(
        "adm.group.admin"
    )

    "SG-Helpdesk-Administrators" = @(
        "adm.betty.gutierrez"
    )

    "SG-Identity-Administrators" = @(
        "adm.identity.admin"
    )

    "SG-IT-Administrators" = @(
        # No approved administrator currently defined.
    )

    "SG-Infrastructure-Administrators" = @(
        "adm.joshua.chavez"
    )

    "SG-Network-Administrators" = @(
        "adm.rebecca.myers"
    )
}

# ============================================================
# START
# ============================================================

Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "             STARGATE PRIVILEGED GROUP AUDIT" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Purpose:"
Write-Host "Review privileged Active Directory group membership and"
Write-Host "identify memberships that do not match the approved"
Write-Host "StarGate administrative access model."
Write-Host ""

Write-Host "IMPORTANT:"
Write-Host "This script is READ-ONLY."
Write-Host "No accounts or group memberships will be changed."
Write-Host ""

# ============================================================
# IDENTIFY CURRENT ADMINISTRATOR
# ============================================================

try {

    $CurrentAdmin = whoami

    Write-Host "Administrator running audit : $CurrentAdmin"

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to identify current administrator." `
        -ForegroundColor Red

    exit
}

# ============================================================
# CHECK ACTIVE DIRECTORY CONNECTION
# ============================================================

Write-Host ""
Write-Host "Checking Active Directory connection..."

try {

    $Domain = Get-ADDomain -ErrorAction Stop

    Write-Host "Active Directory connection : SUCCESS" `
        -ForegroundColor Green

    Write-Host "Domain                     : $($Domain.DNSRoot)"

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to connect to Active Directory." `
        -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor Red

    exit
}

# ============================================================
# CREATE REPORT DIRECTORY
# ============================================================

try {

    if (-not (Test-Path $ReportFolder)) {

        New-Item `
            -Path $ReportFolder `
            -ItemType Directory `
            -Force `
            -ErrorAction Stop |
            Out-Null
    }

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to create report folder." `
        -ForegroundColor Red

    Write-Host "Path: $ReportFolder"
    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor Red

    exit
}

# ============================================================
# AUDIT VARIABLES
# ============================================================

$AuditResults = @()
$GroupErrors = @()

$AuditStart = Get-Date

# ============================================================
# AUDIT EACH PRIVILEGED GROUP
# ============================================================

foreach ($GroupName in $PrivilegedGroups) {

    Write-Host ""
    Write-Host "==============================================================" `
        -ForegroundColor Cyan

    Write-Host "GROUP: $GroupName" -ForegroundColor Cyan

    Write-Host "==============================================================" `
        -ForegroundColor Cyan

    try {

        # ------------------------------------------------------
        # Find the group
        # ------------------------------------------------------

        $Group = Get-ADGroup `
            -Identity $GroupName `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Group found successfully." `
            -ForegroundColor Green

        # ------------------------------------------------------
        # Get direct members
        # ------------------------------------------------------

        $Members = @(
            Get-ADGroupMember `
                -Identity $GroupName `
                -ErrorAction Stop
        )

        # ------------------------------------------------------
        # Handle group with no members
        # ------------------------------------------------------

        if ($Members.Count -eq 0) {

            Write-Host ""
            Write-Host "No members currently exist in this group."

            continue
        }

        # ------------------------------------------------------
        # Process every member
        # ------------------------------------------------------

        foreach ($Member in $Members) {

            $MemberName = $Member.Name
            $SamAccountName = $Member.SamAccountName
            $AccountType = $Member.ObjectClass

            # --------------------------------------------------
            # Determine whether membership is approved
            # --------------------------------------------------

            $ExpectedMembers = $ApprovedMemberships[$GroupName]

            $IsExpected = $false

            if ($null -ne $ExpectedMembers) {

                if ($ExpectedMembers -contains $SamAccountName) {

                    $IsExpected = $true
                }
            }

            if ($IsExpected) {

                $Status = "Expected"

                Write-Host ""
                Write-Host "Member       : $MemberName"
                Write-Host "Username     : $SamAccountName"
                Write-Host "Account Type : $AccountType"
                Write-Host "Status       : EXPECTED" `
                    -ForegroundColor Green

            }
            else {

                $Status = "UNEXPECTED"

                Write-Host ""
                Write-Host "Member       : $MemberName"
                Write-Host "Username     : $SamAccountName"
                Write-Host "Account Type : $AccountType"
                Write-Host "Status       : UNEXPECTED" `
                    -ForegroundColor Red
            }

            # --------------------------------------------------
            # Save audit result
            # --------------------------------------------------

            $AuditResults += [PSCustomObject]@{

                Timestamp = Get-Date

                Group = $GroupName

                Member = $MemberName

                Username = $SamAccountName

                AccountType = $AccountType

                ExpectedMembership = if ($IsExpected) {
                    "Yes"
                }
                else {
                    "No"
                }

                Status = $Status

                DistinguishedName = $Member.DistinguishedName
            }
        }

    }
    catch {

        Write-Host ""
        Write-Host "ERROR auditing group: $GroupName" `
            -ForegroundColor Red

        Write-Host "Details: $($_.Exception.Message)" `
            -ForegroundColor Red

        $GroupErrors += [PSCustomObject]@{

            Group = $GroupName

            Error = $_.Exception.Message
        }
    }
}

# ============================================================
# CALCULATE RESULTS
# ============================================================

$AuditEnd = Get-Date

$ExpectedMemberships = @(
    $AuditResults |
        Where-Object {
            $_.Status -eq "Expected"
        }
)

$UnexpectedMemberships = @(
    $AuditResults |
        Where-Object {
            $_.Status -eq "UNEXPECTED"
        }
)

# ============================================================
# DISPLAY SUMMARY
# ============================================================

Write-Host ""
Write-Host "==============================================================" `
    -ForegroundColor Cyan

Write-Host "                    AUDIT SUMMARY" `
    -ForegroundColor Cyan

Write-Host "==============================================================" `
    -ForegroundColor Cyan

Write-Host ""

Write-Host "Administrator              : $CurrentAdmin"
Write-Host "Domain                     : $($Domain.DNSRoot)"
Write-Host "Groups audited             : $($PrivilegedGroups.Count)"
Write-Host "Expected memberships       : $($ExpectedMemberships.Count)"
Write-Host "Unexpected memberships     : $($UnexpectedMemberships.Count)"
Write-Host "Group errors               : $($GroupErrors.Count)"

# ============================================================
# UNEXPECTED MEMBERSHIP REPORT
# ============================================================

Write-Host ""
Write-Host "==============================================================" `
    -ForegroundColor Cyan

Write-Host "             UNEXPECTED PRIVILEGED MEMBERS" `
    -ForegroundColor Cyan

Write-Host "==============================================================" `
    -ForegroundColor Cyan

Write-Host ""

if ($UnexpectedMemberships.Count -eq 0) {

    Write-Host "No unexpected privileged memberships detected." `
        -ForegroundColor Green

}
else {

    Write-Host "WARNING: Review the following memberships:" `
        -ForegroundColor Red

    Write-Host ""

    $UnexpectedMemberships |
        Select-Object Group, Member, Username, AccountType, Status |
        Format-Table -AutoSize
}

# ============================================================
# EXPECTED MEMBERSHIP REPORT
# ============================================================

Write-Host ""
Write-Host "==============================================================" `
    -ForegroundColor Cyan

Write-Host "                 EXPECTED MEMBERS" `
    -ForegroundColor Cyan

Write-Host "==============================================================" `
    -ForegroundColor Cyan

Write-Host ""

if ($ExpectedMemberships.Count -eq 0) {

    Write-Host "No expected memberships were detected." `
        -ForegroundColor Yellow

}
else {

    $ExpectedMemberships |
        Select-Object Group, Member, Username, AccountType, Status |
        Format-Table -AutoSize
}

# ============================================================
# CREATE REPORT FILENAMES
# ============================================================

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$CsvReport = Join-Path `
    $ReportFolder `
    "Privileged-Group-Audit-$Timestamp.csv"

$TxtReport = Join-Path `
    $ReportFolder `
    "Privileged-Group-Audit-$Timestamp.txt"

# ============================================================
# EXPORT CSV
# ============================================================

try {

    $AuditResults |
        Sort-Object Group, Username |
        Export-Csv `
            -Path $CsvReport `
            -NoTypeInformation `
            -Encoding UTF8 `
            -ErrorAction Stop

    Write-Host ""
    Write-Host "CSV report created successfully." `
        -ForegroundColor Green

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to create CSV report." `
        -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor Red
}

# ============================================================
# CREATE TEXT REPORT
# ============================================================

try {

    $ReportLines = @()

    $ReportLines += "=============================================================="
    $ReportLines += "STARGATE PRIVILEGED GROUP AUDIT"
    $ReportLines += "=============================================================="
    $ReportLines += ""

    $ReportLines += "Audit Started       : $AuditStart"
    $ReportLines += "Audit Completed     : $AuditEnd"
    $ReportLines += "Administrator       : $CurrentAdmin"
    $ReportLines += "Domain              : $($Domain.DNSRoot)"
    $ReportLines += ""

    $ReportLines += "Groups Audited      : $($PrivilegedGroups.Count)"
    $ReportLines += "Expected Membership : $($ExpectedMemberships.Count)"
    $ReportLines += "Unexpected Members  : $($UnexpectedMemberships.Count)"
    $ReportLines += "Group Errors        : $($GroupErrors.Count)"

    $ReportLines += ""

    $ReportLines += "IMPORTANT:"
    $ReportLines += "This audit is READ-ONLY."
    $ReportLines += "No Active Directory changes were performed."

    $ReportLines += ""

    $ReportLines += "=============================================================="
    $ReportLines += "PRIVILEGED GROUP MEMBERSHIP RESULTS"
    $ReportLines += "=============================================================="

    foreach ($Result in ($AuditResults | Sort-Object Group, Username)) {

        $ReportLines += ""

        $ReportLines += "Group                : $($Result.Group)"
        $ReportLines += "Member               : $($Result.Member)"
        $ReportLines += "Username             : $($Result.Username)"
        $ReportLines += "Account Type         : $($Result.AccountType)"
        $ReportLines += "Expected Membership  : $($Result.ExpectedMembership)"
        $ReportLines += "Status               : $($Result.Status)"
        $ReportLines += "Distinguished Name   : $($Result.DistinguishedName)"
        $ReportLines += "Timestamp             : $($Result.Timestamp)"
    }

    $ReportLines += ""

    $ReportLines += "=============================================================="
    $ReportLines += "AUDIT INTERPRETATION"
    $ReportLines += "=============================================================="

    $ReportLines += ""

    $ReportLines += "EXPECTED:"
    $ReportLines += "The membership matches the approved StarGate"
    $ReportLines += "administrative access model."

    $ReportLines += ""

    $ReportLines += "UNEXPECTED:"
    $ReportLines += "The account is a member of a privileged group but"
    $ReportLines += "is not listed as an approved member in the StarGate"
    $ReportLines += "administrative access model."
    $ReportLines += "Administrator investigation is required."

    $ReportLines += ""

    $ReportLines += "No automatic remediation was performed."

    if ($GroupErrors.Count -gt 0) {

        $ReportLines += ""

        $ReportLines += "=============================================================="
        $ReportLines += "GROUP AUDIT ERRORS"
        $ReportLines += "=============================================================="

        foreach ($ErrorRecord in $GroupErrors) {

            $ReportLines += ""
            $ReportLines += "Group : $($ErrorRecord.Group)"
            $ReportLines += "Error : $($ErrorRecord.Error)"
        }
    }

    $ReportLines |
        Out-File `
            -FilePath $TxtReport `
            -Encoding UTF8 `
            -ErrorAction Stop

    Write-Host ""
    Write-Host "TXT report created successfully." `
        -ForegroundColor Green

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to create TXT report." `
        -ForegroundColor Red

    Write-Host "Details: $($_.Exception.Message)" `
        -ForegroundColor Red
}

# ============================================================
# VERIFY REPORT FILES
# ============================================================

Write-Host ""
Write-Host "==============================================================" `
    -ForegroundColor Cyan

Write-Host "                  REPORT VALIDATION" `
    -ForegroundColor Cyan

Write-Host "==============================================================" `
    -ForegroundColor Cyan

Write-Host ""

if (Test-Path $CsvReport) {

    Write-Host "CSV report : SUCCESS" -ForegroundColor Green
    Write-Host "Location   : $CsvReport"

}
else {

    Write-Host "CSV report : FAILED" -ForegroundColor Red
}

Write-Host ""

if (Test-Path $TxtReport) {

    Write-Host "TXT report : SUCCESS" -ForegroundColor Green
    Write-Host "Location   : $TxtReport"

}
else {

    Write-Host "TXT report : FAILED" -ForegroundColor Red
}

# ============================================================
# FINAL RESULT
# ============================================================

Write-Host ""
Write-Host "==============================================================" `
    -ForegroundColor Cyan

Write-Host "                    FINAL RESULT" `
    -ForegroundColor Cyan

Write-Host "==============================================================" `
    -ForegroundColor Cyan

Write-Host ""

if ($GroupErrors.Count -gt 0) {

    Write-Host "AUDIT COMPLETED WITH ERRORS." `
        -ForegroundColor Yellow

    Write-Host "Review the group errors before considering the audit complete."

}
elseif ($UnexpectedMemberships.Count -eq 0) {

    Write-Host "AUDIT RESULT: CLEAN" `
        -ForegroundColor Green

    Write-Host "No unexpected privileged memberships were detected."

}
else {

    Write-Host "AUDIT RESULT: REVIEW REQUIRED" `
        -ForegroundColor Yellow

    Write-Host "$($UnexpectedMemberships.Count) unexpected privileged membership(s) detected."

}

Write-Host ""
Write-Host "No Active Directory changes were made."
Write-Host ""
Write-Host "Privileged Group Audit complete."