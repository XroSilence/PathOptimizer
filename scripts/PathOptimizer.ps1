#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Comprehensive Windows PATH environment optimizer.
    
.DESCRIPTION
    PathOptimizer is an advanced tool that intelligently analyzes, cleans, and optimizes
    your Windows PATH environment variables. It detects and fixes common issues like duplicates,
    non-existent paths, ordering problems, and tool-specific issues.
    
.PARAMETER WhatIf
    Shows what changes would be made without actually making them.
    
.PARAMETER Verbose
    Provides detailed information about the operations being performed.
    
.PARAMETER Interactive
    Prompts for confirmation before making significant changes (default).
    
.PARAMETER NonInteractive
    Makes all changes without prompting (use with caution).
    
.PARAMETER LogFile
    Specifies a custom log file location. Default is in the same directory.
    
.PARAMETER SkipBackup
    Skips creating a backup of the current PATH (not recommended).
    
.PARAMETER CustomConfig
    Specifies a custom configuration file to override default settings.
    
.PARAMETER FixSpecificIssue
    Targets a specific issue type (Duplicates, Ordering, NonExistent, ToolSpecific).
    
.EXAMPLE
    .\PathOptimizer.ps1 -WhatIf
    Shows what changes would be made without applying them.
    
.EXAMPLE
    .\PathOptimizer.ps1 -Verbose
    Runs the optimizer with detailed logging of operations.
    
.EXAMPLE
    .\PathOptimizer.ps1 -NonInteractive
    Runs the optimizer without prompting for confirmation.
    
.EXAMPLE
    .\PathOptimizer.ps1 -FixSpecificIssue Duplicates
    Only fixes duplicate entries in the PATH.
    
.NOTES
    Author: xrosilence
    Version: 1.0
    Requires: PowerShell 5.1 or higher, Administrative privileges
#>

param(
    [switch]$WhatIf,
    [switch]$Verbose,
    [switch]$Interactive = $true,
    [switch]$NonInteractive,
    [string]$LogFile,
    [switch]$SkipBackup,
    [string]$CustomConfig,
    [ValidateSet("Duplicates", "Ordering", "NonExistent", "ToolSpecific", "All")]
    [string]$FixSpecificIssue = "All"
)

# Script paths setup
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path -Path $ScriptPath -ChildPath "modules"
$ConfigPath = Join-Path -Path $ScriptPath -ChildPath "config"

# Import modules
Import-Module (Join-Path -Path $ModulesPath -ChildPath "Analyzer.psm1") -Force
Import-Module (Join-Path -Path $ModulesPath -ChildPath "Cleaner.psm1") -Force
Import-Module (Join-Path -Path $ModulesPath -ChildPath "Optimizer.psm1") -Force
Import-Module (Join-Path -Path $ModulesPath -ChildPath "Validator.psm1") -Force
Import-Module (Join-Path -Path $ModulesPath -ChildPath "Logger.psm1") -Force

# Initialize logger
if (-not $LogFile) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogFile = Join-Path -Path $ScriptPath -ChildPath "PathOptimizer_$timestamp.log"
}
Initialize-Logger -LogFile $LogFile -Verbose:$Verbose

# Override interactive mode if specified
if ($NonInteractive) {
    $Interactive = $false
}

# Display welcome banner
$bannerText = @"
 ____       _   _     ___        _   _           _
|  _ \ __ _| |_| |__ / _ \ _ __ | |_(_)_ __ ___ (_)_______  _ __
| |_) / _` | __| '_ \ | | | '_ \| __| | '_ ` _ \| |_  / _ \| '__|
|  __/ (_| | |_| | | | |_| | |_) | |_| | | | | | | |/ / (_) | |
|_|   \__,_|\__|_| |_|\___/| .__/ \__|_|_| |_| |_|_/___\___/|_|
                           |_|
"@

Write-Host $bannerText -ForegroundColor Cyan
Write-Host "Windows PATH Environment Optimizer v1.0" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Log script start
Write-Log "PathOptimizer started with parameters: WhatIf=$WhatIf, Verbose=$Verbose, Interactive=$Interactive, FixSpecificIssue=$FixSpecificIssue"

# Create backup unless explicitly skipped
if (-not $SkipBackup) {
    $backupFile = Backup-PathEnvironment
    Write-Host "Backed up current PATH environment to: $backupFile" -ForegroundColor Green
    Write-Log "Created PATH backup at: $backupFile"
}

# Load configuration
$config = Load-Configuration -CustomConfig $CustomConfig -ConfigPath $ConfigPath
Write-Log "Loaded configuration: $(ConvertTo-Json -InputObject $config -Compress)"

# Admin check
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Error: This script requires Administrator privileges." -ForegroundColor Red
    Write-Log "Error: Script execution terminated. Administrator privileges required." -Level Error
    exit 1
}

try {
    # Step 1: Analyze current PATH environment
    Write-Host "Analyzing PATH environment..." -ForegroundColor Cyan
    $analysisResult = Analyze-PathEnvironment -Config $config
    
    # Output analysis summary
    Show-AnalysisSummary -Analysis $analysisResult
    
    # Step 2: Validate paths
    Write-Host "Validating paths..." -ForegroundColor Cyan
    $validationResult = Validate-Paths -Paths ($analysisResult.UserPaths + $analysisResult.SystemPaths) -Config $config
    
    # Output validation summary
    Show-ValidationSummary -Validation $validationResult
    
    # Step 3: Generate optimization plan
    Write-Host "Generating optimization plan..." -ForegroundColor Cyan
    $optimizationPlan = New-OptimizationPlan -Analysis $analysisResult -Validation $validationResult -Config $config -FixSpecificIssue $FixSpecificIssue
    
    # Output optimization plan summary
    Show-OptimizationPlan -Plan $optimizationPlan
    
    # Step 4: Apply or simulate changes
    if ($WhatIf) {
        Write-Host "WhatIf specified: No changes will be made." -ForegroundColor Yellow
        Write-Log "WhatIf mode enabled - simulated execution completed with no actual changes."
    }
    else {
        # Prompt for confirmation if in interactive mode
        $proceedWithChanges = $true
        if ($Interactive) {
            $confirmMessage = "Do you want to proceed with the changes described above? (yes/no)"
            $confirmation = Read-Host $confirmMessage
            $proceedWithChanges = $confirmation -eq "yes"
            
            Write-Log "User confirmation for changes: $confirmation"
        }
        
        if ($proceedWithChanges) {
            Write-Host "Applying changes..." -ForegroundColor Cyan
            $applyResult = Apply-PathChanges -Plan $optimizationPlan -WhatIf:$WhatIf
            
            # Output results
            if ($applyResult.Success) {
                Write-Host "PATH optimization completed successfully!" -ForegroundColor Green
                Write-Host "Summary of changes:" -ForegroundColor Green
                Write-Host "- User PATH entries: $($applyResult.UserPathCount) (removed $($applyResult.UserPathsRemoved))" -ForegroundColor Green
                Write-Host "- System PATH entries: $($applyResult.SystemPathCount) (reordered for optimal performance)" -ForegroundColor Green
                Write-Host "Please restart your terminal to apply the changes." -ForegroundColor Yellow
                
                Write-Log "PATH optimization completed successfully: User entries=$($applyResult.UserPathCount), System entries=$($applyResult.SystemPathCount)"
            }
            else {
                Write-Host "Error applying changes: $($applyResult.Error)" -ForegroundColor Red
                Write-Log "Error applying changes: $($applyResult.Error)" -Level Error
            }
        }
        else {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            Write-Log "Operation cancelled by user."
        }
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Log "Unhandled error occurred: $_`nStack Trace: $($_.ScriptStackTrace)" -Level Error
    
    # Attempt to restore from backup if an error occurs
    if (-not $SkipBackup -and -not $WhatIf) {
        Write-Host "Attempting to restore PATH from backup..." -ForegroundColor Yellow
        $restoreResult = Restore-PathFromBackup -BackupFile $backupFile
        
        if ($restoreResult.Success) {
            Write-Host "Successfully restored PATH from backup." -ForegroundColor Green
            Write-Log "Successfully restored PATH from backup: $backupFile"
        }
        else {
            Write-Host "Failed to restore PATH from backup: $($restoreResult.Error)" -ForegroundColor Red
            Write-Log "Failed to restore PATH from backup: $($restoreResult.Error)" -Level Error
        }
    }
}
finally {
    Write-Host "Log file created at: $LogFile" -ForegroundColor Yellow
    Write-Log "PathOptimizer execution completed."
}
