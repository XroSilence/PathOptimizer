# Analyzer.psm1
# Provides path analysis functionality for the PathOptimizer

# Analyze the current PATH environment
function Analyze-PathEnvironment {
    param (
        [hashtable]$Config
    )
    
    Write-Log "Starting PATH environment analysis" -Level "Info"
    
    # Get current paths
    $userPaths = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ -and $_.Trim() }
    $systemPaths = [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | Where-Object { $_ -and $_.Trim() }
    
    Write-Log "Found $($userPaths.Count) user PATH entries and $($systemPaths.Count) system PATH entries" -Level "Info"
    
    # Analyze path issues
    $duplicates = @()
    $emptyPaths = @()
    $nonExistentPaths = @()
    $tempPaths = @()
    $knownIssues = @{}
    $allPaths = @($userPaths) + @($systemPaths)
    
    # Track all paths for duplicate detection
    $normalizedPaths = @{}
    
    # Initialize known issues tracking
    foreach ($issueName in $Config.KnownIssuePatterns.Keys) {
        $knownIssues[$issueName] = @{
            Count = 0
            Paths = @()
        }
    }
    
    # Analyze each path
    foreach ($path in $allPaths) {
        # Skip empty paths
        if ([string]::IsNullOrWhiteSpace($path)) {
            $emptyPaths += $path
            continue
        }
        
        # Normalize path for duplicate detection
        $normalizedPath = $path.Trim('\').Trim('"').Trim("'").ToLower()
        
        # Check for duplicates
        if ($normalizedPaths.ContainsKey($normalizedPath)) {
            $duplicates += $path
            $normalizedPaths[$normalizedPath] += 1
        }
        else {
            $normalizedPaths[$normalizedPath] = 1
        }
        
        # Check for non-existent paths
        if (-not (Test-Path -Path $path -ErrorAction SilentlyContinue)) {
            $nonExistentPaths += $path
        }
        
        # Check for temporary paths
        foreach ($pattern in $Config.IgnorePatterns) {
            if ($path -match $pattern) {
                $tempPaths += $path
                break
            }
        }
        
        # Check for known issue patterns
        foreach ($issueName in $Config.KnownIssuePatterns.Keys) {
            $pattern = $Config.KnownIssuePatterns[$issueName]
            if ($path -match $pattern) {
                $knownIssues[$issueName].Count++
                $knownIssues[$issueName].Paths += $path
            }
        }
    }
    
    # Analyze tool presence
    $toolAnalysis = @{}
    foreach ($toolName in $Config.ToolDetectionPatterns.Keys) {
        $toolAnalysis[$toolName] = @{
            Detected = $false
            Paths = @()
            ExecutablesFound = @()
        }
        
        $toolPatterns = $Config.ToolDetectionPatterns[$toolName]
        
        foreach ($path in $allPaths) {
            if (-not (Test-Path -Path $path -ErrorAction SilentlyContinue)) {
                continue
            }
            
            $foundExecutables = @()
            foreach ($pattern in $toolPatterns) {
                $exePath = Join-Path -Path $path -ChildPath $pattern
                if (Test-Path -Path $exePath -ErrorAction SilentlyContinue) {
                    $foundExecutables += $pattern
                    $toolAnalysis[$toolName].Detected = $true
                }
            }
            
            if ($foundExecutables.Count -gt 0) {
                $toolAnalysis[$toolName].Paths += $path
                $toolAnalysis[$toolName].ExecutablesFound += $foundExecutables
            }
        }
    }
    
    # Check critical paths
    $missingCriticalPaths = @()
    foreach ($criticalPath in $Config.CriticalPaths) {
        $found = $false
        
        foreach ($path in $systemPaths) {
            if ($path -like "*$criticalPath*") {
                $found = $true
                break
            }
        }
        
        if (-not $found) {
            $missingCriticalPaths += $criticalPath
        }
    }
    
    # Calculate total PATH length
    $userPathString = $userPaths -join ';'
    $systemPathString = $systemPaths -join ';'
    $totalPathLength = $userPathString.Length + $systemPathString.Length
    $maxLengthExceeded = $totalPathLength -gt $Config.MaxPathLength
    
    Write-Log "Analysis completed: Found $($duplicates.Count) duplicates, $($emptyPaths.Count) empty entries, $($nonExistentPaths.Count) non-existent paths" -Level "Info"
    
    # Return analysis results
    return @{
        UserPaths = $userPaths
        SystemPaths = $systemPaths
        Duplicates = $duplicates
        EmptyPaths = $emptyPaths
        NonExistentPaths = $nonExistentPaths
        TemporaryPaths = $tempPaths
        KnownIssues = $knownIssues
        ToolAnalysis = $toolAnalysis
        MissingCriticalPaths = $missingCriticalPaths
        TotalPathLength = $totalPathLength
        MaxLengthExceeded = $maxLengthExceeded
        NormalizedPaths = $normalizedPaths
    }
}

# Display a summary of the analysis results
function Show-AnalysisSummary {
    param (
        [hashtable]$Analysis
    )
    
    Write-Host "`nPATH Analysis Summary:" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan
    
    # Basic counts
    Write-Host "Total PATH entries: $($Analysis.UserPaths.Count + $Analysis.SystemPaths.Count)" -ForegroundColor White
    Write-Host "  - User PATH: $($Analysis.UserPaths.Count) entries" -ForegroundColor White
    Write-Host "  - System PATH: $($Analysis.SystemPaths.Count) entries" -ForegroundColor White
    
    # Issues found
    $issueCount = $Analysis.Duplicates.Count + $Analysis.EmptyPaths.Count + $Analysis.NonExistentPaths.Count + $Analysis.TemporaryPaths.Count
    
    Write-Host "`nIssues detected: $issueCount" -ForegroundColor $(if ($issueCount -gt 0) { "Yellow" } else { "Green" })
    
    if ($Analysis.Duplicates.Count -gt 0) {
        Write-Host "  - Duplicate entries: $($Analysis.Duplicates.Count)" -ForegroundColor Yellow
    }
    
    if ($Analysis.EmptyPaths.Count -gt 0) {
        Write-Host "  - Empty entries: $($Analysis.EmptyPaths.Count)" -ForegroundColor Yellow
    }
    
    if ($Analysis.NonExistentPaths.Count -gt 0) {
        Write-Host "  - Non-existent paths: $($Analysis.NonExistentPaths.Count)" -ForegroundColor Yellow
    }
    
    if ($Analysis.TemporaryPaths.Count -gt 0) {
        Write-Host "  - Temporary paths: $($Analysis.TemporaryPaths.Count)" -ForegroundColor Yellow
    }
    
    # Known issues
    $knownIssueCount = 0
    foreach ($issueName in $Analysis.KnownIssues.Keys) {
        $count = $Analysis.KnownIssues[$issueName].Count
        $knownIssueCount += $count
        
        if ($count -gt 0) {
            Write-Host "  - $issueName: $count entries" -ForegroundColor Yellow
        }
    }
    
    if ($knownIssueCount -gt 0) {
        Write-Host "  - Total known issues: $knownIssueCount" -ForegroundColor Yellow
    }
    
    # Tools detected
    $toolsDetected = @($Analysis.ToolAnalysis.Keys | Where-Object { $Analysis.ToolAnalysis[$_].Detected }).Count
    Write-Host "`nDevelopment tools detected: $toolsDetected" -ForegroundColor White
    
    foreach ($toolName in $Analysis.ToolAnalysis.Keys) {
        if ($Analysis.ToolAnalysis[$toolName].Detected) {
            $pathCount = $Analysis.ToolAnalysis[$toolName].Paths.Count
            $exeCount = $Analysis.ToolAnalysis[$toolName].ExecutablesFound.Count
            
            Write-Host "  - $toolName found in $pathCount $(if ($pathCount -eq 1) { "path" } else { "paths" })" -ForegroundColor $(if ($pathCount -gt 1) { "Yellow" } else { "Green" })
        }
    }
    
    # Critical paths
    if ($Analysis.MissingCriticalPaths.Count -gt 0) {
        Write-Host "`nWARNING: Missing critical system paths: $($Analysis.MissingCriticalPaths.Count)" -ForegroundColor Red
        
        foreach ($path in $Analysis.MissingCriticalPaths) {
            Write-Host "  - $path" -ForegroundColor Red
        }
    }
    
    # Path length
    $percentUsed = [math]::Round(($Analysis.TotalPathLength / 8191) * 100, 1)
    Write-Host "`nPATH environment size: $($Analysis.TotalPathLength) characters ($percentUsed% of maximum)" -ForegroundColor $(if ($Analysis.MaxLengthExceeded) { "Red" } elseif ($percentUsed -gt 75) { "Yellow" } else { "Green" })
    
    if ($Analysis.MaxLengthExceeded) {
        Write-Host "  WARNING: Exceeds maximum recommended length of $($Analysis.MaxPathLength) characters!" -ForegroundColor Red
    }
}

# Gets the category of a path based on its content and configuration
function Get-PathCategory {
    param (
        [string]$Path,
        [hashtable]$Config
    )
    
    # Check for Windows system paths
    foreach ($criticalPath in $Config.CriticalPaths) {
        if ($Path -like "*$criticalPath*") {
            return "WindowsSystem"
        }
    }
    
    # Check for PowerShell paths
    if ($Path -like "*PowerShell*") {
        return "PowerShell"
    }
    
    # Check for program files
    if ($Path -like "C:\Program Files*") {
        return "ProgramFiles"
    }
    
    # Check for Windows apps
    if ($Path -like "*WindowsApps*") {
        return "WindowsApps"
    }
    
    # Check for development tools
    foreach ($toolName in $Config.ToolDetectionPatterns.Keys) {
        foreach ($pattern in $Config.ToolDetectionPatterns[$toolName]) {
            $exePath = Join-Path -Path $Path -ChildPath $pattern
            if (Test-Path -Path $exePath -ErrorAction SilentlyContinue) {
                return "DevTools"
            }
        }
    }
    
    # Check for programming languages
    if ($Path -like "*Python*" -or $Path -like "*Java*" -or $Path -like "*\Ruby*" -or $Path -like "*\Go*" -or $Path -like "*\node*") {
        return "Languages"
    }
    
    # Check for local apps
    if ($Path -like "*\AppData\Local*") {
        return "LocalApps"
    }
    
    # Default to unknown
    return "Unknown"
}

# Get the priority of a path
function Get-PathPriority {
    param (
        [string]$Path,
        [string]$Category,
        [hashtable]$Config
    )
    
    # Base priority on category
    $basePriority = $Config.PathPriorities[$Category]
    
    # Adjust priority based on specific factors
    $adjustedPriority = $basePriority
    
    # Higher priority for paths with executables
    if (Test-Path $Path -ErrorAction SilentlyContinue) {
        $exeCount = (Get-ChildItem -Path $Path -Filter "*.exe" -ErrorAction SilentlyContinue).Count
        $cmdCount = (Get-ChildItem -Path $Path -Filter "*.cmd" -ErrorAction SilentlyContinue).Count
        $batCount = (Get-ChildItem -Path $Path -Filter "*.bat" -ErrorAction SilentlyContinue).Count
        
        $executableBonus = [Math]::Min(($exeCount + $cmdCount + $batCount) * 5, 50)
        $adjustedPriority += $executableBonus
    }
    
    # Critical system paths get highest priority
    if ($Category -eq "WindowsSystem") {
        foreach ($criticalPath in $Config.CriticalPaths) {
            if ($Path -like "*$criticalPath*") {
                # Give different priorities based on the order in the critical paths list
                $index = [array]::IndexOf($Config.CriticalPaths, $criticalPath)
                $criticalBonus = 100 - ($index * 10)  # Higher bonus for earlier entries
                $adjustedPriority += $criticalBonus
                break
            }
        }
    }
    
    # LTS/stable versions get higher priority
    if ($Path -match "(lts|LTS|stable|release)") {
        $adjustedPriority += 25
    }
    
    return $adjustedPriority
}

# Export module functions
Export-ModuleMember -Function Analyze-PathEnvironment, Show-AnalysisSummary, Get-PathCategory, Get-PathPriority
