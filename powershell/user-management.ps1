<#
.SYNOPSIS
    Local User Account Management Script

.DESCRIPTION
    Manages local user accounts: create, delete, enable, disable, and list users.
    Also includes password management and user group operations.

.PARAMETER Action
    Action to perform: List, Create, Delete, Enable, Disable, ResetPassword, AddToGroup, RemoveFromGroup

.PARAMETER UserName
    Target username for the operation

.PARAMETER NewUserName
    New username for rename operations

.PARAMETER Password
    Password for new users or password resets

.PARAMETER Description
    User account description

.PARAMETER GroupName
    Group name for group operations

.PARAMETER Export
    Export user list to CSV file

.PARAMETER AllUsers
    Operate on all users (use with caution)

.EXAMPLE
    .\user-management.ps1 -Action List

.EXAMPLE
    .\user-management.ps1 -Action Create -UserName "johndoe" -Password "secure123" -Description "Developer account"

.EXAMPLE
    .\user-management.ps1 -Action ResetPassword -UserName "johndoe" -Password "newpassword"
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("List", "Create", "Delete", "Enable", "Disable", "ResetPassword", "AddToGroup", "RemoveFromGroup", "Rename")]
    [string]$Action,
    
    [string]$UserName,
    [string]$NewUserName,
    [string]$Password,
    [string]$Description,
    [string]$GroupName,
    [string]$Export,
    [switch]$AllUsers
)

# Function to write colored output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# Function to check if running as administrator
function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsPrincipal]::Administrator)
}

# Function to list all local users
function Get-LocalUsers {
    try {
        return Get-LocalUser -ErrorAction Stop
    }
    catch {
        Write-ColorOutput "Error retrieving local users: $($_.Exception.Message)" "Red"
        return $null
    }
}

# Function to display user information
function Show-UserInfo {
    param($Users)
    
    Write-Host "`n" + "="*100
    Write-Host "LOCAL USER ACCOUNTS" -ForegroundColor Cyan
    Write-Host "="*100
    Write-Host "Generated: $(Get-Date)"
    Write-Host "Total Users: $($Users.Count)"
    Write-Host "`n"
    
    Write-Host "Username".PadRight(20) "Full Name".PadRight(25) "Enabled".PadRight(10) "Last Logon".PadRight(20) "Description"
    Write-Host "-"*100
    
    foreach ($user in $Users) {
        $enabledColor = if ($user.Enabled) { "Green" } else { "Red" }
        $lastLogon = if ($user.LastLogon) { $user.LastLogon.ToString("yyyy-MM-dd HH:mm") } else { "Never" }
        
        Write-Host $user.Name.PadRight(20) -NoNewline
        Write-Host $user.FullName.PadRight(25) -NoNewline
        Write-Host $user.Enabled.PadRight(10) -NoNewline -ForegroundColor $enabledColor
        Write-Host $lastLogon.PadRight(20) -NoNewline
        Write-Host $user.Description
    }
    
    Write-Host "`n" + "="*100
}

# Function to create a new local user
function New-LocalUserAccount {
    param([string]$Name, [string]$UserPassword, [string]$UserDescription)
    
    try {
        # Check if user already exists
        if (Get-LocalUser -Name $Name -ErrorAction SilentlyContinue) {
            Write-ColorOutput "User '$Name' already exists!" "Yellow"
            return $false
        }
        
        $securePassword = ConvertTo-SecureString -String $UserPassword -AsPlainText -Force
        
        $userParams = @{
            Name = $Name
            Password = $securePassword
            Description = $UserDescription
            AccountNeverExpires = $true
            PasswordNeverExpires = $false
        }
        
        New-LocalUser @userParams -ErrorAction Stop
        
        # Add user to Users group
        Add-LocalGroupMember -Group "Users" -Member $Name -ErrorAction SilentlyContinue
        
        Write-ColorOutput "Successfully created user: $Name" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Error creating user '$Name': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to delete a local user
function Remove-LocalUserAccount {
    param([string]$Name)
    
    try {
        Remove-LocalUser -Name $Name -ErrorAction Stop
        Write-ColorOutput "Successfully deleted user: $Name" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Error deleting user '$Name': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to reset user password
function Reset-UserPassword {
    param([string]$Name, [string]$NewPassword)
    
    try {
        $securePassword = ConvertTo-SecureString -String $NewPassword -AsPlainText -Force
        Set-LocalUser -Name $Name -Password $securePassword -ErrorAction Stop
        Write-ColorOutput "Password reset successfully for user: $Name" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Error resetting password for '$Name': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to manage user group membership
function Manage-UserGroup {
    param([string]$Name, [string]$Group, [string]$Operation)
    
    try {
        $groupObj = Get-LocalGroup -Name $Group -ErrorAction Stop
        
        if ($Operation -eq "AddToGroup") {
            Add-LocalGroupMember -Group $Group -Member $Name -ErrorAction Stop
            Write-ColorOutput "User '$Name' added to group '$Group'" "Green"
        }
        elseif ($Operation -eq "RemoveFromGroup") {
            Remove-LocalGroupMember -Group $Group -Member $Name -ErrorAction Stop
            Write-ColorOutput "User '$Name' removed from group '$Group'" "Green"
        }
        
        return $true
    }
    catch {
        Write-ColorOutput "Error in group operation for '$Name': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to rename user
function Rename-LocalUser {
    param([string]$OldName, [string]$NewName)
    
    try {
        Rename-LocalUser -Name $OldName -NewName $NewName -ErrorAction Stop
        Write-ColorOutput "User renamed from '$OldName' to '$NewName'" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Error renaming user '$OldName': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Main execution
try {
    # Check administrator privileges for most actions
    if ($Action -ne "List" -and -not (Test-Administrator)) {
        Write-ColorOutput "This action requires Administrator privileges!" "Red"
        exit 1
    }
    
    switch ($Action) {
        "List" {
            $users = Get-LocalUsers
            if ($users) {
                Show-UserInfo -Users $users
                
                if ($Export) {
                    $users | Select-Object Name, FullName, Enabled, LastLogon, Description | 
                    Export-Csv -Path $Export -NoTypeInformation
                    Write-ColorOutput "User list exported to: $Export" "Green"
                }
            }
        }
        
        "Create" {
            if (-not $UserName -or -not $Password) {
                Write-ColorOutput "UserName and Password are required for Create action" "Red"
                exit 1
            }
            
            New-LocalUserAccount -Name $UserName -UserPassword $Password -UserDescription $Description
        }
        
        "Delete" {
            if (-not $UserName -and -not $AllUsers) {
                Write-ColorOutput "UserName or -AllUsers parameter is required for Delete action" "Red"
                exit 1
            }
            
            if ($AllUsers) {
                $users = Get-LocalUsers | Where-Object { $_.Name -notlike "Administrator" -and $_.Name -notlike "Guest" }
                foreach ($user in $users) {
                    Remove-LocalUserAccount -Name $user.Name
                }
            }
            else {
                Remove-LocalUserAccount -Name $UserName
            }
        }
        
        "Enable" {
            if (-not $UserName) {
                Write-ColorOutput "UserName is required for Enable action" "Red"
                exit 1
            }
            
            Enable-LocalUser -Name $UserName -ErrorAction Stop
            Write-ColorOutput "User '$UserName' enabled" "Green"
        }
        
        "Disable" {
            if (-not $UserName) {
                Write-ColorOutput "UserName is required for Disable action" "Red"
                exit 1
            }
            
            Disable-LocalUser -Name $UserName -ErrorAction Stop
            Write-ColorOutput "User '$UserName' disabled" "Yellow"
        }
        
        "ResetPassword" {
            if (-not $UserName -or -not $Password) {
                Write-ColorOutput "UserName and Password are required for ResetPassword action" "Red"
                exit 1
            }
            
            Reset-UserPassword -Name $UserName -NewPassword $Password
        }
        
        "AddToGroup" {
            if (-not $UserName -or -not $GroupName) {
                Write-ColorOutput "UserName and GroupName are required for AddToGroup action" "Red"
                exit 1
            }
            
            Manage-UserGroup -Name $UserName -Group $GroupName -Operation "AddToGroup"
        }
        
        "RemoveFromGroup" {
            if (-not $UserName -or -not $GroupName) {
                Write-ColorOutput "UserName and GroupName are required for RemoveFromGroup action" "Red"
                exit 1
            }
            
            Manage-UserGroup -Name $UserName -Group $GroupName -Operation "RemoveFromGroup"
        }
        
        "Rename" {
            if (-not $UserName -or -not $NewUserName) {
                Write-ColorOutput "UserName and NewUserName are required for Rename action" "Red"
                exit 1
            }
            
            Rename-LocalUser -OldName $UserName -NewName $NewUserName
        }
    }
}
catch {
    Write-ColorOutput "Script error: $($_.Exception.Message)" "Red"
    exit 1
}

Write-Host "`nOperation completed!" -ForegroundColor Cyan
