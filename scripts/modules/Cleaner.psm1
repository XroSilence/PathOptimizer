# Cleaner.psm1
# Provides path cleaning functionality for the PathOptimizer

# Normalize a path string
function Get-NormalizedPath {
    param (
        [string]$Path
    )
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    
    # Remove leading/trailing whitespace, quotes, and trailing backslashes
    $normalizedPath = $Path.Trim().Trim('"', "'").TrimEnd('\')
    
    # Add trailing slash for drive roots if missing
    if ($normalizedPath -match '^[A-Za-z]:$') {
        $normalizedPath = "$normalizedPath\"
    }
    
    return $normalizedPath
}

# Remove duplicate paths
function Remove-DuplicatePaths {
    param (
        [string[]]$Paths
    )
    
    $uniquePaths = @{}
    $result = @()
    
    foreach ($path in $Paths) {
        $normalizedPath = Get-NormalizedPath $path
        
        if ($normalizedPath -and -not $uniquePaths.ContainsKey($normalizedPath.ToLower())) {
            $uniquePaths[$normalizedPath.ToLower()] = $true
            $result += $normalizedPath
        }
    }
    
    return $result
}

# Remove empty or invalid paths
function Remove-EmptyPaths {
    param (
        [string[]]$Paths
    )
    
    return $Paths | Where-Object { 
        -not [string]::IsNullOrWhiteSpace($_) -and 
        -not ($_ -eq ";") -and
        -not ($_.Length -le 2) -and
        -not ($_ -match ';;')
    }
}

# Remove non-existent paths
function Remove-NonExistentPaths {
    param (
        [string[]]$Paths
    )
    
    return $Paths | Where-Object { Test-Path -Path $_ -ErrorAction SilentlyContinue }
}

# Remove temporary or unwanted paths based on patterns
function Remove-TemporaryPaths {
    param (
        [string[]]$Paths,
        [string[]]$IgnorePatterns
    )
    
    return $Paths | Where-Object {
        $path = $_
        -not ($IgnorePatterns | Where-Object { $path -match $_ })
    }
}

# Remove paths matching specific known issues
function Remove-KnownIssuePaths {
    param (
        [string[]]$Paths,
        [hashtable]$KnownIssuePatterns,
        [string[]]$IssueTypes
    )
    
    # If issue types are specified, only remove those types
    $patternsToCheck = @{}
    
    if ($IssueTypes -and $IssueTypes.Count -gt 0 -and -not ($IssueTypes -contains "All")) {
        foreach ($issueType in $IssueTypes) {
            if ($KnownIssuePatterns.ContainsKey($issueType)) {
                $patternsToCheck[$issueType] = $KnownIssuePatterns[$issueType]
            }
        }
    }
    else {
        $patternsToCheck = $KnownIssuePatterns
    }
    
    return $Paths | Where-Object {
        $path = $_
        $remove = $false
        
        foreach ($pattern in $patternsToCheck.Values) {
            if ($path -match $pattern) {
                $remove = $true
                break
            }
        }
        
        -not $remove
    }
}

# Remove tool path duplicates while preserving the most appropriate version
function Remove-ToolDuplicates {
    param (
        [string[]]$Paths,
        [hashtable]$ToolAnalysis,
        [hashtable]$Config
    )
    
    $result = @()
    $toolPaths = @{}
    $remainingPaths = @()
    
    # Group paths by the tools they contain
    foreach ($path in $Paths) {
        $isToolPath = $false
        
        foreach ($toolName in $ToolAnalysis.Keys) {
            if ($ToolAnalysis[$toolName].Paths -contains $path) {
                if (-not $toolPaths.ContainsKey($toolName)) {
                    $toolPaths[$toolName] = @()
                }
                
                $toolPaths[$toolName] += $path
                $isToolPath = $true
            }
        }
        
        if (-not $isToolPath) {
            $remainingPaths += $path
        }
    }
    
    # For each tool, keep only the best path(s)
    foreach ($toolName in $toolPaths.Keys) {
        $toolPathsArray = $toolPaths[$toolName]
        
        # If only one path, keep it
        if ($toolPathsArray.Count -eq 1) {
            $result += $toolPathsArray[0]
            continue
        }
        
        # Score each path
        $scoredPaths = @()
        foreach ($toolPath in $toolPathsArray) {
            $category = Get-PathCategory -Path $toolPath -Config $Config
            $priority = Get-PathPriority -Path $toolPath -Category $category -Config $Config
            
            # Check if path is LTS or stable
            $isLTS = $toolPath -match "(lts|LTS|stable|release)"
            
            # Check for version numbers in the path
            $versionMatch = $toolPath -match "(\d+\.\d+\.\d+|\d+\.\d+|v\d+)"
            $version = if ($Matches) { $Matches[0] } else { $null }
            
            # Executable count
            $exeCount = 0
            if (Test-Path $toolPath -ErrorAction SilentlyContinue) {
                $toolPatterns = $Config.ToolDetectionPatterns[$toolName]
                foreach ($pattern in $toolPatterns) {
                    $exePath = Join-Path -Path $toolPath -ChildPath $pattern
                    if (Test-Path -Path $exePath -ErrorAction SilentlyContinue) {
                        $exeCount++
                    }
                }
            }
            
            $scoredPaths += @{
                Path = $toolPath
                Priority = $priority
                IsLTS = $isLTS
                Version = $version
                ExeCount = $exeCount
            }
        }
        
        # Sort by LTS status, then priority, then version, then executable count
        $sortedPaths = $scoredPaths | Sort-Object -Property @{
            Expression = { $_.IsLTS }; Descending = $true
        }, @{
            Expression = { $_.Priority }; Descending = $true
        }, @{
            Expression = { $_.Version }; Descending = $true
        }, @{
            Expression = { $_.ExeCount }; Descending = $true
        }
        
        # Keep the top path
        $result += $sortedPaths[0].Path
        
        # Log what's being kept vs removed
        Write-Log "Tool '$toolName' found in multiple paths. Keeping: $($sortedPaths[0].Path)" -Level "Info"
        foreach ($discardedPath in $sortedPaths[1..($sortedPaths.Count-1)]) {
            Write-Log "  Removing duplicate: $($discardedPath.Path)" -Level "Debug"
        }
    }
    
    # Add remaining non-tool paths
    $result += $remainingPaths
    
    return $result
}

# Ensure critical paths are present
function Ensure-CriticalPaths {
    param (
        [string[]]$Paths,
        [string[]]$CriticalPaths
    )
    
    $result = @($Paths)
    
    foreach ($criticalPath in $CriticalPaths) {
        $fullPath = if ($criticalPath -match "^[A-Za-z]:\\") { $criticalPath } else { "C:$criticalPath" }
        $found = $false
        
        foreach ($path in $Paths) {
            if ($path -like "*$criticalPath*") {
                $found = $true
                break
            }
        }
        
        if (-not $found -and (Test-Path $fullPath)) {
            Write-Log "Adding missing critical path: $fullPath" -Level "Warning"
            $result = @($fullPath) + $result  # Add to the beginning
        }
    }
    
    return $result
}

# Clean a set of paths using all appropriate methods
function Clean-Paths {
    param (
        [string[]]$Paths,
        [hashtable]$ToolAnalysis,
        [hashtable]$Config,
        [string[]]$FixTypes = @("All")
    )
    
    $result = $Paths
    
    # Apply the appropriate fixes based on the fix types
    if ($FixTypes -contains "All" -or $FixTypes -contains "EmptyPaths") {
        if ($Config.RemoveEmptyPaths) {
            $result = Remove-EmptyPaths -Paths $result
            Write-Log "Removed empty paths. Remaining: $($result.Count)" -Level "Info"
        }
    }
    
    if ($FixTypes -contains "All" -or $FixTypes -contains "Duplicates") {
        if ($Config.RemoveDuplicates) {
            $result = Remove-DuplicatePaths -Paths $result
            Write-Log "Removed duplicate paths. Remaining: $($result.Count)" -Level "Info"
        }
    }
    
    if ($FixTypes -contains "All" -or $FixTypes -contains "NonExistent") {
        if ($Config.RemoveNonexistent) {
            $result = Remove-NonExistentPaths -Paths $result
            Write-Log "Removed non-existent paths. Remaining: $($result.Count)" -Level "Info"
        }
    }
    
    if ($FixTypes -contains "All" -or $FixTypes -contains "TemporaryPaths") {
        $result = Remove-TemporaryPaths -Paths $result -IgnorePatterns $Config.IgnorePatterns
        Write-Log "Removed temporary paths. Remaining: $($result.Count)" -Level "Info"
    }
    
    if ($FixTypes -contains "All" -or $FixTypes -contains "KnownIssues") {
        $result = Remove-KnownIssuePaths -Paths $result -KnownIssuePatterns $Config.KnownIssuePatterns
        Write-Log "Removed known issue paths. Remaining: $($result.Count)" -Level "Info"
    }
    
    if ($FixTypes -contains "All" -or $FixTypes -contains "ToolDuplicates") {
        $result = Remove-ToolDuplicates -Paths $result -ToolAnalysis $ToolAnalysis -Config $Config
        Write-Log "Removed tool duplicates. Remaining: $($result.Count)" -Level "Info"
    }
    
    return $result
}

# Export module functions
Export-ModuleMember -Function Get-NormalizedPath, Remove-DuplicatePaths, Remove-EmptyPaths, Remove-NonExistentPaths, Remove-TemporaryPaths, Remove-KnownIssuePaths, Remove-ToolDuplicates, Ensure-CriticalPaths, Clean-Paths
