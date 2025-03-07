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
    #Requires -Version 5.1
    #Requires -RunAsAdministrator
#>

#Requires -RunAsAdministrator

param(
    [switch]$WhatIf,
    [switch]$Verbose,
    [switch]$NonInteractive,
    [string]$LogFile,
    [switch]$SkipBackup,
    [string]$CustomConfig,
    [ValidateSet("Duplicates", "Ordering", "NonExistent", "ToolSpecific", "All")]
    [string]$FixSpecificIssue = "All"
)

# Admin check
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Error: This script requires Administrator privileges." -ForegroundColor Red
    exit 1
}

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

if (-not $NonInteractive -and -not $Interactive) {
    $Interactive = $true
}
elseif ($NonInteractive) {
    $Interactive = $false
}

# Display welcome banner
$bannerText = @"
 ____       _   _      ___        _   _           _
|  _ \ __ _| |_| |__  / _ \ _ __ | |_(_)_ __ ___ (_)_______  _ __
| |_) / _` | __| '_ \| | | | '_ \| __| | '_ ` _ \| |_  / _ \| '__|
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
$config = Get-Configuration -CustomConfig $CustomConfig -ConfigPath $ConfigPath
Write-Log "Loaded configuration: $(ConvertTo-Json -InputObject $config -Compress)"

# Begin processing
try {
    $analysisResult = Start-PathEnvironmentAnalysis -Config $config
    $validationResult = ValidatePathsStep -Paths $analysisResult.Paths -Config $config
    $optimizationPlan = GenerateOptimizationPlanStep -Analysis $analysisResult -Validation $validationResult -Config $config -FixSpecificIssue $FixSpecificIssue
    ApplyOrSimulateChangesStep -OptimizationPlan $optimizationPlan -WhatIf $WhatIf -Interactive $Interactive
}
catch {
    HandleError $_ $SkipBackup $WhatIf $backupFile
}
finally {
    Write-Host "Log file created at: $LogFile" -ForegroundColor Yellow
    Write-Log "PathOptimizer execution completed."
}

function Start-PathEnvironmentAnalysis {
    <#
    .SYNOPSIS
        Analyzes the current PATH environment.
        
    .DESCRIPTION
        This function analyzes the current PATH environment and returns the analysis results.
        
    .PARAMETER Config
        The configuration settings to use for the analysis.
        
    .OUTPUTS
        Hashtable containing the analysis results.
        
    .EXAMPLE
        $analysisResult = Start-PathEnvironmentAnalysis -Config $config
    #>
    param (
        [Parameter(Mandatory=$true)]
        [object]$Config
    )
    
    Write-Host "Analyzing PATH environment..." -ForegroundColor Cyan
    $analysisResult = Analyze-PathEnvironment -Config $Config
    Show-AnalysisSummary -Analysis $analysisResult
    return $analysisResult
}

function ValidatePathsStep {
    <#
    .SYNOPSIS
        Validates the paths in the PATH environment.
        
    .DESCRIPTION
        This function validates the paths in the PATH environment and returns the validation results.
        
    .PARAMETER Paths
        The paths to validate.
        
    .PARAMETER Config
        The configuration settings to use for the validation.
        
    .OUTPUTS
        Hashtable containing the validation results.
        
    .EXAMPLE
        $validationResult = ValidatePathsStep -Paths $analysisResult.Paths -Config $config
    #>
    param (
        [Parameter(Mandatory=$true)]
        [array]$Paths,
        [Parameter(Mandatory=$true)]
        [object]$Config
    )
    Write-Host "Validating paths..." -ForegroundColor Cyan
    $validationResult = Validate-Paths -Paths $Paths -Config $Config
    Show-ValidationSummary -Validation $validationResult
    return $validationResult
}

function GenerateOptimizationPlanStep {
    <#
    .SYNOPSIS
        Generates an optimization plan for the PATH environment.
        
    .DESCRIPTION
        This function generates an optimization plan based on the analysis and validation results.
        
    .PARAMETER Analysis
        The analysis results.
        
    .PARAMETER Validation
        The validation results.
        
    .PARAMETER Config
        The configuration settings to use for the optimization.
        
    .PARAMETER FixSpecificIssue
        The specific issue to fix.
        
    .OUTPUTS
        Hashtable containing the optimization plan.
        
    .EXAMPLE
        $optimizationPlan = GenerateOptimizationPlanStep -Analysis $analysisResult -Validation $validationResult -Config $config -FixSpecificIssue "All"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [object]$Analysis,
        [Parameter(Mandatory=$true)]
        [object]$Validation,
        [Parameter(Mandatory=$true)]
        [object]$Config,
        [Parameter(Mandatory=$true)]
        [string]$FixSpecificIssue
    )
    Write-Host "Generating optimization plan..." -ForegroundColor Cyan
    $optimizationPlan = New-OptimizationPlan -Analysis $Analysis -Validation $Validation -Config $Config -FixSpecificIssue $FixSpecificIssue
    Show-OptimizationPlan -Plan $optimizationPlan
    return $optimizationPlan
}

function ApplyOrSimulateChangesStep {
    <#
    .SYNOPSIS
        Applies or simulates the changes based on the optimization plan.
        
    .DESCRIPTION
        This function applies or simulates the changes based on the optimization plan.
        
    .PARAMETER OptimizationPlan
        The optimization plan to apply or simulate.
        
    .PARAMETER WhatIf
        If specified, simulates the changes without applying them.
        
    .PARAMETER Interactive
        If specified, prompts for confirmation before applying changes.
        
    .OUTPUTS
        None.
        
    .EXAMPLE
        ApplyOrSimulateChangesStep -OptimizationPlan $optimizationPlan -WhatIf -Interactive
    #>
    param (
        [Parameter(Mandatory=$true)]
        [object]$OptimizationPlan,
        [Parameter(Mandatory=$true)]
        [switch]$WhatIf,
        [Parameter(Mandatory=$true)]
        [switch]$Interactive
    )
    if ($WhatIf) {
        Write-Host "WhatIf specified: No changes will be made." -ForegroundColor Yellow
        Write-Log "WhatIf mode enabled - simulated execution completed with no actual changes."
    }
    else {
        $proceedWithChanges = $true
        if ($Interactive) {
            $confirmMessage = "Do you want to proceed with the changes described above? (yes/no)"
            $confirmation = Read-Host $confirmMessage
            $proceedWithChanges = $confirmation -eq "yes"
        }
        
        if ($proceedWithChanges) {
            Write-Host "Applying changes..." -ForegroundColor Cyan
            $applyResult = Apply-OptimizationPlan -OptimizationPlan $OptimizationPlan
            if ($applyResult.Success) {
                Write-Host "PATH optimization completed successfully!" -ForegroundColor Green
                Write-Host "Summary of changes:" -ForegroundColor Green
                Write-Host "- User PATH entries: $($applyResult.UserPathCount) (removed $($applyResult.UserPathsRemoved))" -ForegroundColor Green
                Write-Host "- System PATH entries: $($applyResult.SystemPathCount) (reordered for optimal performance)" -ForegroundColor Green
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

function HandleError {
    <#
    .SYNOPSIS
        Handles errors that occur during the script execution.
        
    .DESCRIPTION
        This function handles errors that occur during the script execution and attempts to restore the PATH from backup if necessary.
        
    .PARAMETER Error
        The error object.
        
    .PARAMETER SkipBackup
        If specified, skips restoring the PATH from backup.
        
    .PARAMETER WhatIf
        If specified, indicates that the script was run in WhatIf mode.
        
    .PARAMETER BackupFile
        The backup file to restore from.
        
    .OUTPUTS
        None.
        
    .EXAMPLE
        HandleError -Error $_ -SkipBackup -WhatIf -BackupFile $backupFile
    #>
    param (
        [Parameter(Mandatory=$true)]
        [object]$Error,
        [Parameter(Mandatory=$true)]
        [switch]$SkipBackup,
        [Parameter(Mandatory=$true)]
        [switch]$WhatIf,
        [Parameter(Mandatory=$true)]
        [string]$BackupFile
    )
    Write-Host "Error: $Error" -ForegroundColor Red
    Write-Host "Stack Trace: $($Error.ScriptStackTrace)" -ForegroundColor Red
    Write-Log "Unhandled error occurred: $Error`nStack Trace: $($Error.ScriptStackTrace)" -Level Error
    
    if (-not $SkipBackup -and -not $WhatIf) {
        Write-Host "Attempting to restore PATH from backup..." -ForegroundColor Yellow
        $restoreResult = Restore-PathFromBackup -BackupFile $BackupFile
        if ($restoreResult.Success) {
            Write-Host "Successfully restored PATH from backup." -ForegroundColor Green
            Write-Log "Successfully restored PATH from backup: $BackupFile"
        }
        else {
            Write-Host "Failed to restore PATH from backup: $($restoreResult.Error)" -ForegroundColor Red
            Write-Log "Failed to restore PATH from backup: $($restoreResult.Error)" -Level Error
        }
    }
}

function Get-Configuration {
    <#
    .SYNOPSIS
        Loads the configuration settings.
        
    .DESCRIPTION
        This function loads the configuration settings from the specified custom configuration file or the default configuration file.
        
    .PARAMETER CustomConfig
        The custom configuration file to load.
        
    .PARAMETER ConfigPath
        The path to the configuration directory.
        
    .OUTPUTS
        Hashtable containing the configuration settings.
        
    .EXAMPLE
        $config = Get-Configuration -CustomConfig "customConfig.xml" -ConfigPath "config"
    #>
    param (
        [string]$CustomConfig,
        [string]$ConfigPath
    )
    Write-Host "Loading configuration..." -ForegroundColor Cyan
    if ($CustomConfig) {
        if (Test-Path -Path $CustomConfig) {
            return Import-Clixml -Path $CustomConfig
        }
        else {
            Write-Host "Custom configuration file not found: $CustomConfig" -ForegroundColor Red
            return $null
        }
    }
    else {
        $defaultConfigFile = Join-Path -Path $ConfigPath -ChildPath "defaultConfig.xml"
        if (Test-Path -Path $defaultConfigFile) {
            return Import-Clixml -Path $defaultConfigFile
        }
        else {
            Write-Host "Default configuration file not found: $defaultConfigFile" -ForegroundColor Red
            return $null
        }
    }
}

# End of script