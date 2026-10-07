# ============================================================
# StarGate - Account Lockout Management Automation
# ============================================================
#
# Purpose:
# Investigate currently locked Active Directory user accounts,
# allow an authorized administrator to select an account,
# verify the employee identity, unlock the account, verify the
# result, and record the action in an audit CSV file.
#
# ============================================================

Import-Module ActiveDirectory

# ------------------------------------------------------------
# 1. Identify the current administrator
# ------------------------------------------------------------

$CurrentAdmin = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAR GATE ACCOUNT LOCKOUT MANAGEMENT" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Administrator: $CurrentAdmin"
Write-Host ""

# ------------------------------------------------------------
# 2. Check administrator authorization
# ------------------------------------------------------------

$AuthorizedAdmins = @(
    "STARGATE\adm.domain.admin",
    "STARGATE\adm.betty.gutierrez",
    "STARGATE\adm.identity.admin"
)

if ($AuthorizedAdmins -notcontains $CurrentAdmin) {

    Write-Host "ACCESS DENIED" -ForegroundColor Red
    Write-Host "You are not authorized to unlock user accounts."
    Write-Host ""

    exit
}

Write-Host "Authorization check: PASSED" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# 3. Find currently locked user accounts
# ------------------------------------------------------------

$LockedUsers = @(
    Search-ADAccount -LockedOut -UsersOnly |
    Get-ADUser -Properties `
        Enabled,
        LockedOut,
        LastLogonDate,
        PasswordLastSet,
        AccountExpirationDate,
        DistinguishedName
)

# ------------------------------------------------------------
# 4. Handle no locked accounts
# ------------------------------------------------------------

if ($LockedUsers.Count -eq 0) {

    Write-Host "No locked user accounts were found." -ForegroundColor Green
    Write-Host ""

    exit
}

# ------------------------------------------------------------
# 5. Display locked accounts
# ------------------------------------------------------------

Write-Host "Locked user accounts detected: $($LockedUsers.Count)" `
    -ForegroundColor Yellow

Write-Host ""

$AccountNumber = 1

foreach ($User in $LockedUsers) {

    Write-Host "[$AccountNumber] $($User.Name)" -ForegroundColor Yellow
    Write-Host "    Username : $($User.SamAccountName)"
    Write-Host "    Enabled  : $($User.Enabled)"
    Write-Host "    Locked   : $($User.LockedOut)"
    Write-Host ""

    $AccountNumber++
}

# ------------------------------------------------------------
# 6. Select the locked account
# ------------------------------------------------------------

if ($LockedUsers.Count -eq 1) {

    $SelectedUser = $LockedUsers[0]

    Write-Host "One locked account was found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Selected employee: $($SelectedUser.Name)"
    Write-Host ""

}
else {

    Write-Host "Multiple locked accounts were found." -ForegroundColor Yellow
    Write-Host ""

    $SelectionNumber = 0
    $ValidSelection = $false

    do {

        $Selection = Read-Host "Enter the employee number"

        $SelectionNumber = 0

        $IsNumber = [int]::TryParse(
            $Selection,
            [ref]$SelectionNumber
        )

        if ($IsNumber) {

            if (
                ($SelectionNumber -ge 1) -and
                ($SelectionNumber -le $LockedUsers.Count)
            ) {

                $ValidSelection = $true
            }
            else {

                $ValidSelection = $false
            }

        }
        else {

            $ValidSelection = $false
        }

        if (-not $ValidSelection) {

            Write-Host ""
            Write-Host "Invalid selection." -ForegroundColor Red
            Write-Host "Please enter a number between 1 and $($LockedUsers.Count)."
            Write-Host ""
        }

    }
    until ($ValidSelection)

    $SelectedUser = $LockedUsers[$SelectionNumber - 1]

    Write-Host ""
    Write-Host "Selected employee: $($SelectedUser.Name)" `
        -ForegroundColor Cyan
    Write-Host ""
}

# ------------------------------------------------------------
# 7. Display account investigation information
# ------------------------------------------------------------

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " ACCOUNT INVESTIGATION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Employee Name       : $($SelectedUser.Name)"
Write-Host "Username            : $($SelectedUser.SamAccountName)"
Write-Host "Account Enabled     : $($SelectedUser.Enabled)"
Write-Host "Account Locked      : $($SelectedUser.LockedOut)"
Write-Host "Last Logon          : $($SelectedUser.LastLogonDate)"
Write-Host "Password Last Set   : $($SelectedUser.PasswordLastSet)"
Write-Host "Account Expiration  : $($SelectedUser.AccountExpirationDate)"
Write-Host "Active Directory DN : $($SelectedUser.DistinguishedName)"

Write-Host ""

# ------------------------------------------------------------
# 8. Ask administrator whether to unlock
# ------------------------------------------------------------

$UnlockChoice = Read-Host "Do you want to unlock this account? (Y/N)"

if ($UnlockChoice -notmatch '^[Yy]$') {

    Write-Host ""
    Write-Host "No changes were made." -ForegroundColor Yellow
    Write-Host ""

    exit
}

# ------------------------------------------------------------
# 9. Warning before changing the account
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================" -ForegroundColor Red
Write-Host " WARNING" -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Red
Write-Host ""

Write-Host "You are about to unlock an employee account." `
    -ForegroundColor Red

Write-Host ""
Write-Host "Employee : $($SelectedUser.Name)" -ForegroundColor Yellow
Write-Host "Username : $($SelectedUser.SamAccountName)" -ForegroundColor Yellow
Write-Host ""

$WarningChoice = Read-Host "Do you want to continue? (Y/N)"

if ($WarningChoice -notmatch '^[Yy]$') {

    Write-Host ""
    Write-Host "Unlock operation cancelled." -ForegroundColor Yellow
    Write-Host ""

    exit
}

# ------------------------------------------------------------
# 10. Full-name identity verification
# ------------------------------------------------------------

Write-Host ""
Write-Host "Identity verification required." -ForegroundColor Cyan
Write-Host ""

$EnteredName = Read-Host "Enter the employee's FULL NAME"

if ($EnteredName.Trim() -ne $SelectedUser.Name.Trim()) {

    Write-Host ""
    Write-Host "IDENTITY VERIFICATION FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "The name entered does not match the selected employee."
    Write-Host "No changes were made."
    Write-Host ""

    exit
}

Write-Host ""
Write-Host "Identity verification: PASSED" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# 11. Prepare audit logging
# ------------------------------------------------------------

$ActionTime = Get-Date

$LogFolder = "C:\StarGate\Logs"
$LogFile = "$LogFolder\AccountLockout-Audit.csv"

New-Item `
    -Path $LogFolder `
    -ItemType Directory `
    -Force |
    Out-Null

# ------------------------------------------------------------
# 12. Unlock the account
# ------------------------------------------------------------

try {

    Unlock-ADAccount -Identity $SelectedUser.SamAccountName

    $ActionResult = "Success"

    Write-Host "Account unlock command completed." `
        -ForegroundColor Green

    Write-Host ""

}
catch {

    $ActionResult = "Failed"

    Write-Host "Account unlock FAILED." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""

    # --------------------------------------------------------
    # Record failed action
    # --------------------------------------------------------

    $AuditRecord = [PSCustomObject]@{
        DateTime           = $ActionTime
        Administrator      = $CurrentAdmin
        Employee           = $SelectedUser.Name
        Username           = $SelectedUser.SamAccountName
        Action             = "Account Unlock"
        Result             = $ActionResult
        FinalLockedStatus  = "Unknown"
    }

    $AuditRecord |
        Export-Csv `
            -Path $LogFile `
            -Append `
            -NoTypeInformation

    Write-Host "Failed action recorded in audit log." `
        -ForegroundColor Yellow

    exit
}

# ------------------------------------------------------------
# 13. Verify the account is unlocked
# ------------------------------------------------------------

$Verification = Get-ADUser `
    -Identity $SelectedUser.SamAccountName `
    -Properties LockedOut

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " VERIFICATION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Employee   : $($Verification.Name)"
Write-Host "Username   : $($Verification.SamAccountName)"
Write-Host "Locked Out : $($Verification.LockedOut)"
Write-Host ""

if ($Verification.LockedOut -eq $false) {

    $VerificationResult = "Success"

    Write-Host "SUCCESS: Account is no longer locked." `
        -ForegroundColor Green
}
else {

    $VerificationResult = "Verification Failed"

    Write-Host "WARNING: Account is still showing as locked." `
        -ForegroundColor Red
}

# ------------------------------------------------------------
# 14. Write audit record
# ------------------------------------------------------------

$AuditRecord = [PSCustomObject]@{
    DateTime           = $ActionTime
    Administrator      = $CurrentAdmin
    Employee           = $Verification.Name
    Username           = $Verification.SamAccountName
    Action             = "Account Unlock"
    Result             = $VerificationResult
    FinalLockedStatus  = $Verification.LockedOut
}

$AuditRecord |
    Export-Csv `
        -Path $LogFile `
        -Append `
        -NoTypeInformation

# ------------------------------------------------------------
# 15. Completion
# ------------------------------------------------------------

Write-Host ""
Write-Host "Audit record saved to:" -ForegroundColor Cyan
Write-Host $LogFile
Write-Host ""

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " OPERATION COMPLETE" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""