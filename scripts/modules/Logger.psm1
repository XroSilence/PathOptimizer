# Logger.psm1
# Provides logging functionality for the PathOptimizer

# Initialize the logger
function Initialize-Logger {
    param (
        [string]$LogFile,
        [switch]$Verbose
    )
    
    $script:LogFilePath = $LogFile
    $script:VerboseLogging = $Verbose
    
    # Create log file with header
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $header = @"
PathOptimizer Log
=================
Started: $timestamp
System: $env:COMPUTERNAME
User: $env:USERNAME
PowerShell: $($PSVersionTable.PSVersion)
Windows: $([System.Environment]::OSVersion.Version)

"@
    
    $header | Out-File -FilePath $script:LogFilePath -Encoding utf8 -Force
    
    Write-Log "Logger initialized"
}

# Write to log file and optionally console
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "Info",
        [switch]$NoConsole
    )
    
    if (-not $script:LogFilePath) {
        # If not initialized, use a default location
        $defaultLogFile = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "PathOptimizer.log"
        Initialize-Logger -LogFile $defaultLogFile
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    $logEntry | Out-File -FilePath $script:LogFilePath -Append -Encoding utf8
    
    # Optionally display in console
    if (-not $NoConsole) {
        # Only show debug messages if verbose logging is enabled
        if ($Level -eq "Debug" -and -not $script:VerboseLogging) {
            return
        }
        
        switch ($Level) {
            "Error" { Write-Host $logEntry -ForegroundColor Red }
            "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
            "Success" { Write-Host $logEntry -ForegroundColor Green }
            "Debug" { Write-Host $logEntry -ForegroundColor Gray }
            default { Write-Host $logEntry }
        }
    }
}

# Backup the current PATH environment
function Backup-PathEnvironment {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path -Path (Split-Path -Parent $script:LogFilePath) -ChildPath "path_backup_$timestamp.txt"
    
    # Create backup file
    "USER PATH:" | Out-File $backupFile -Encoding utf8
    [Environment]::GetEnvironmentVariable('Path', 'User') | Out-File $backupFile -Append -Encoding utf8
    "SYSTEM PATH:" | Out-File $backupFile -Append -Encoding utf8
    [Environment]::GetEnvironmentVariable('Path', 'Machine') | Out-File $backupFile -Append -Encoding utf8
    
    Write-Log "Created PATH environment backup at $backupFile" -Level "Success"
    
    return $backupFile
}

# Restore PATH from backup
function Restore-PathFromBackup {
    param (
        [string]$BackupFile
    )
    
    try {
        if (-not (Test-Path $BackupFile)) {
            return @{
                Success = $false
                Error = "Backup file not found: $BackupFile"
            }
        }
        
        Write-Log "Attempting to restore PATH from backup: $BackupFile" -Level "Warning"
        
        $backupContent = Get-Content $BackupFile -Encoding utf8
        
        $userPathLine = $backupContent.IndexOf("USER PATH:")
        $systemPathLine = $backupContent.IndexOf("SYSTEM PATH:")
        
        if ($userPathLine -ge 0 -and $systemPathLine -gt $userPathLine) {
            $userPath = $backupContent[$userPathLine + 1]
            $systemPath = $backupContent[$systemPathLine + 1]
            
            # Restore the PATH variables
            [Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
            [Environment]::SetEnvironmentVariable('Path', $systemPath, 'Machine')
            
            Write-Log "Successfully restored PATH from backup" -Level "Success"
            
            return @{
                Success = $true
            }
        }
        else {
            return @{
                Success = $false
                Error = "Invalid backup file format"
            }
        }
    }
    catch {
        return @{
            Success = $false
            Error = "Error restoring from backup: $_"
        }
    }
}

# Load configuration
function Load-Configuration {
    param (
        [string]$CustomConfig,
        [string]$ConfigPath
    )
    
    try {
        # Default configuration
        $defaultConfig = @{
            CriticalPaths = @(
                "C:\Windows\system32",
                "C:\Windows",
                "C:\Windows\System32\Wbem",
                "C:\Windows\System32\WindowsPowerShell\v1.0",
                "C:\Windows\System32\OpenSSH"
            )
            IgnorePatterns = @(
                "\\Temp\\",
                "\\tmp\\",
                "\\AppData\\Local\\Temp\\"
            )
            ToolDetectionPatterns = @{
                "Node.js" = @("node.exe", "npm.cmd", "npx.cmd")
                "Python" = @("python.exe", "python3.exe", "pip.exe", "pip3.exe")
                "Git" = @("git.exe")
                "VS Code" = @("code.cmd", "code-insiders.cmd")
                "Java" = @("java.exe", "javac.exe")
                "DotNet" = @("dotnet.exe")
                "Rust" = @("cargo.exe", "rustc.exe")
                "Docker" = @("docker.exe", "docker-compose.exe")
                "PowerShell" = @("powershell.exe", "pwsh.exe")
            }
            KnownIssuePatterns = @{
                "FNM Multishells" = @"fnm_multishells"@
                "Temporary Node Paths" = @"node_modules\\.bin"@
                "Duplicate Windows Apps" = @"Microsoft\\WindowsApps"@
            }
            PathPriorities = @{
                WindowsSystem = 1000
                PowerShell = 900
                CommandLine = 800
                DevTools = 700
                ProgramFiles = 600
                Languages = 500
                LocalApps = 400
                WindowsApps = 300
                Custom = 200
                Unknown = 100
            }
            MaxPathLength = 8191  # Maximum size for all PATH environment variables combined
            RemoveEmptyPaths = $true
            RemoveDuplicates = $true
            RemoveNonexistent = $true
            PreserveOrder = $false
            OptimizeOrder = $true
            SeparateUserSystem = $true
        }
        
        # If custom config specified, load and merge it
        if ($CustomConfig -and (Test-Path $CustomConfig)) {
            Write-Log "Loading custom configuration from: $CustomConfig" -Level "Info"
            $customConfigData = Get-Content $CustomConfig -Raw | ConvertFrom-Json
            
            # Convert JSON to hashtable and merge with defaults
            $customConfigHash = @{}
            foreach ($property in $customConfigData.PSObject.Properties) {
                $customConfigHash[$property.Name] = $property.Value
            }
            
            # Merge configurations (custom overrides default)
            foreach ($key in $customConfigHash.Keys) {
                $defaultConfig[$key] = $customConfigHash[$key]
            }
        }
        else {
            # Try to load from config directory
            $criticalPathsFile = Join-Path -Path $ConfigPath -ChildPath "critical-paths.json"
            $devToolsFile = Join-Path -Path $ConfigPath -ChildPath "dev-tools.json"
            $knownIssuesFile = Join-Path -Path $ConfigPath -ChildPath "known-issues.json"
            $pathPriorityFile = Join-Path -Path $ConfigPath -ChildPath "path-priority.json"
            
            # Load each config file if it exists
            if (Test-Path $criticalPathsFile) {
                $defaultConfig.CriticalPaths = (Get-Content $criticalPathsFile -Raw | ConvertFrom-Json)
            }
            
            if (Test-Path $devToolsFile) {
                $defaultConfig.ToolDetectionPatterns = (Get-Content $devToolsFile -Raw | ConvertFrom-Json)
            }
            
            if (Test-Path $knownIssuesFile) {
                $defaultConfig.KnownIssuePatterns = (Get-Content $knownIssuesFile -Raw | ConvertFrom-Json)
            }
            
            if (Test-Path $pathPriorityFile) {
                $defaultConfig.PathPriorities = (Get-Content $pathPriorityFile -Raw | ConvertFrom-Json)
            }
        }
        
        Write-Log "Configuration loaded successfully" -Level "Success"
        return $defaultConfig
    }
    catch {
        Write-Log "Error loading configuration: $_" -Level "Error"
        # Return default config on error
        return $defaultConfig
    }
}

# Export module functions
Export-ModuleMember -Function Initialize-Logger, Write-Log, Backup-PathEnvironment, Restore-PathFromBackup, Load-Configuration
