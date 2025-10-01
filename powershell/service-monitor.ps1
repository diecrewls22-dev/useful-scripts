<#
.SYNOPSIS
    Windows Service Monitor and Management Script

.DESCRIPTION
    Monitors Windows services, checks their status, and can restart failed services.
    Provides both real-time monitoring and one-time status checks.

.PARAMETER ServiceName
    Specific service name to monitor (supports wildcards)

.PARAMETER Monitor
    Enable continuous monitoring mode

.PARAMETER Interval
    Monitoring interval in seconds (default: 30)

.PARAMETER RestartFailed
    Automatically restart services that are stopped

.PARAMETER LogFile
    Path to log file for monitoring results

.PARAMETER Export
    Export service status to CSV file

.EXAMPLE
    .\service-monitor.ps1 -ServiceName "Spooler" -Monitor -RestartFailed

.EXAMPLE
    .\service-monitor.ps1 -Export "C:\services.csv"
#>

param(
    [string]$ServiceName = "*",
    [switch]$Monitor,
    [int]$Interval = 30,
    [switch]$RestartFailed,
    [string]$LogFile,
    [string]$Export
)

# Function to write log messages
function Write-LogMessage {
    param([string]$Message, [string]$Type = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Type] $Message"
    
    Write-Host $logEntry -ForegroundColor $(if ($Type -eq "ERROR") { "Red" } elseif ($Type -eq "WARNING") { "Yellow" } else { "White" })
    
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logEntry
    }
}

# Function to get service status with color coding
function Get-ServiceStatus {
    param([string]$Filter = "*")
    
    $services = Get-Service -Name $Filter -ErrorAction SilentlyContinue
    
    if (-not $services) {
        Write-LogMessage "No services found matching filter: $Filter" "WARNING"
        return
    }
    
    $serviceData = @()
    
    foreach ($service in $services) {
        $statusColor = switch ($service.Status) {
            "Running" { "Green" }
            "Stopped" { "Red" }
            "StartPending" { "Yellow" }
            "StopPending" { "Yellow" }
            default { "Gray" }
        }
        
        $serviceData += [PSCustomObject]@{
            Name = $service.Name
            DisplayName = $service.DisplayName
            Status = $service.Status
            StartType = (Get-CimInstance -ClassName Win32_Service -Filter "Name='$($service.Name)'").StartMode
            Color = $statusColor
        }
    }
    
    return $serviceData
}

# Function to display service status
function Show-ServiceStatus {
    param($ServiceData)
    
    Write-Host "`n" + "="*80
    Write-Host "WINDOWS SERVICE STATUS" -ForegroundColor Cyan
    Write-Host "="*80
    Write-Host "Generated: $(Get-Date)"
    Write-Host "Total Services: $($ServiceData.Count)"
    Write-Host "`n"
    
    Write-Host "Service Name".PadRight(35) "Display Name".PadRight(35) "Status".PadRight(15) "Start Type"
    Write-Host "-"*80
    
    $runningCount = 0
    $stoppedCount = 0
    
    foreach ($service in $ServiceData) {
        Write-Host $service.Name.PadRight(35) -NoNewline
        Write-Host $service.DisplayName.PadRight(35) -NoNewline
        Write-Host $service.Status.PadRight(15) -NoNewline -ForegroundColor $service.Color
        Write-Host $service.StartType
        
        if ($service.Status -eq "Running") { $runningCount++ }
        if ($service.Status -eq "Stopped") { $stoppedCount++ }
    }
    
    Write-Host "`n" + "-"*80
    Write-Host "Summary: $runningCount Running, $stoppedCount Stopped" -ForegroundColor Cyan
    Write-Host "="*80
}

# Function to restart stopped services
function Restart-StoppedServices {
    param($ServiceData)
    
    $stoppedServices = $ServiceData | Where-Object { $_.Status -eq "Stopped" -and $_.StartType -eq "Auto" }
    
    if (-not $stoppedServices) {
        Write-LogMessage "No auto-start services are stopped"
        return
    }
    
    foreach ($service in $stoppedServices) {
        try {
            Write-LogMessage "Attempting to start service: $($service.Name)"
            Start-Service -Name $service.Name -ErrorAction Stop
            Write-LogMessage "Successfully started service: $($service.Name)" "INFO"
        }
        catch {
            Write-LogMessage "Failed to start service $($service.Name): $($_.Exception.Message)" "ERROR"
        }
    }
}

# Function to monitor services continuously
function Start-ServiceMonitoring {
    param([string]$Filter, [int]$CheckInterval, [bool]$AutoRestart)
    
    Write-LogMessage "Starting service monitoring (Interval: ${CheckInterval}s, Filter: $Filter)"
    if ($AutoRestart) {
        Write-LogMessage "Auto-restart is ENABLED for stopped auto-start services"
    }
    
    try {
        while ($true) {
            $services = Get-ServiceStatus -Filter $Filter
            $stoppedServices = $services | Where-Object { $_.Status -eq "Stopped" -and $_.StartType -eq "Auto" }
            
            if ($stoppedServices -and $AutoRestart) {
                Write-LogMessage "Found $($stoppedServices.Count) stopped auto-start services"
                Restart-StoppedServices -ServiceData $stoppedServices
            }
            
            Write-LogMessage "Monitoring check completed. Next check in ${CheckInterval} seconds..."
            Start-Sleep -Seconds $CheckInterval
        }
    }
    catch {
        Write-LogMessage "Monitoring interrupted: $($_.Exception.Message)" "ERROR"
    }
}

# Main execution
try {
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    
    if ((-not $isAdmin) -and ($RestartFailed -or $Monitor)) {
        Write-LogMessage "Warning: Administrator privileges recommended for service management" "WARNING"
    }
    
    # Export service status if requested
    if ($Export) {
        $services = Get-ServiceStatus -Filter $ServiceName
        $services | Select-Object Name, DisplayName, Status, StartType | Export-Csv -Path $Export -NoTypeInformation
        Write-LogMessage "Service status exported to: $Export"
    }
    
    # Continuous monitoring mode
    if ($Monitor) {
        Start-ServiceMonitoring -Filter $ServiceName -CheckInterval $Interval -AutoRestart $RestartFailed
    }
    else {
        # One-time status check
        $services = Get-ServiceStatus -Filter $ServiceName
        Show-ServiceStatus -ServiceData $services
        
        if ($RestartFailed) {
            Restart-StoppedServices -ServiceData $services
        }
    }
}
catch {
    Write-LogMessage "Script error: $($_.Exception.Message)" "ERROR"
    exit 1
}
