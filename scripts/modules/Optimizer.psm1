# Optimizer.psm1
# Provides path optimization functionality for the PathOptimizer

# Create a new optimization plan based on analysis results
function New-OptimizationPlan {
    param (
        [hashtable]$Analysis,
        [hashtable]$Validation,
        [hashtable]$Config,
        [string]$FixSpecificIssue = "All"
    )
    
    Write-Log "Creating optimization plan for PATH environment" -Level "Info"
    
    # Determine which fix types to apply
    $fixTypes = @()
    
    if ($FixSpecificIssue -eq "All") {
        $fixTypes = @("All")
    }
    else {
        switch ($FixSpecificIssue) {
            "Duplicates" { $fixTypes = @("Duplicates", "EmptyPaths") }
            "Ordering" { $fixTypes = @("Ordering") }
            "NonExistent" { $fixTypes = @("NonExistent") }
            "ToolSpecific" { $fixTypes = @("ToolDuplicates", "KnownIssues") }
            default { $fixTypes = @("All") }
        }
    }
    
    # Clean the paths based on analysis and configuration
    $cleanedUserPaths = Clean-Paths -Paths $Analysis.UserPaths -ToolAnalysis $Analysis.ToolAnalysis -Config $Config -FixTypes $fixTypes
    $cleanedSystemPaths = Clean-Paths -Paths $Analysis.SystemPaths -ToolAnalysis $Analysis.ToolAnalysis -Config $Config -FixTypes $fixTypes
    
    # Ensure critical paths are included in system paths
    $updatedSystemPaths = Ensure-CriticalPaths -Paths $cleanedSystemPaths -CriticalPaths $Config.CriticalPaths
    
    # Optimize the ordering if requested
    if ($Config.OptimizeOrder -and ($fixTypes -contains "All" -or $fixTypes -contains "Ordering")) {
        $orderedUserPaths = Optimize-PathOrder -Paths $cleanedUserPaths -Config $Config -IsSystemPath $false
        $orderedSystemPaths = Optimize-PathOrder -Paths $updatedSystemPaths -Config $Config -IsSystemPath $true
        
        Write-Log "Optimized path order" -Level "Info"
    }
    else {
        $orderedUserPaths = $cleanedUserPaths
        $orderedSystemPaths = $updatedSystemPaths
    }
    
    # Calculate the differences
    $userPathsRemoved = Compare-PathLists -Original $Analysis.UserPaths -New $orderedUserPaths
    $systemPathsRemoved = Compare-PathLists -Original $Analysis.SystemPaths -New $orderedSystemPaths
    
    $userPathCount = $orderedUserPaths.Count
    $systemPathCount = $orderedSystemPaths.Count
    $totalPathCount = $userPathCount + $systemPathCount
    
    # Create the optimization plan
    $plan = @{
        OriginalUserPaths = $Analysis.UserPaths
        OriginalSystemPaths = $Analysis.SystemPaths
        NewUserPaths = $orderedUserPaths
        NewSystemPaths = $orderedSystemPaths
        UserPathsRemoved = $userPathsRemoved
        SystemPathsRemoved = $systemPathsRemoved
        UserPathCount = $userPathCount
        SystemPathCount = $systemPathCount
        TotalPathCount = $totalPathCount
        FixTypes = $fixTypes
    }
    
    return $plan
}

# Optimize the order of paths based on priority
function Optimize-PathOrder {
    param (
        [string[]]$Paths,
        [hashtable]$Config,
        [bool]$IsSystemPath
    )
    
    $scoredPaths = @()
    
    # Score each path
    foreach ($path in $Paths) {
        $category = Get-PathCategory -Path $path -Config $Config
        $priority = Get-PathPriority -Path $path -Category $category -Config $Config
        
        $scoredPaths += @{
            Path = $path
            Category = $category
            Priority = $priority
        }
    }
    
    # Sort paths by priority (highest first)
    $sortedPaths = $scoredPaths | Sort-Object -Property Priority -Descending | ForEach-Object { $_.Path }
    
    # If it's the system path, ensure critical paths are in the correct order
    if ($IsSystemPath) {
        $criticalOrderedPaths = @()
        $nonCriticalPaths = @()
        
        # First, add critical paths in their defined order
        foreach ($criticalPath in $Config.CriticalPaths) {
            foreach ($path in $sortedPaths) {
                if ($path -like "*$criticalPath*") {
                    $criticalOrderedPaths += $path
                    break
                }
            }
        }
        
        # Add non-critical paths
        foreach ($path in $sortedPaths) {
            $isCritical = $false
            foreach ($criticalPath in $Config.CriticalPaths) {
                if ($path -like "*$criticalPath*") {
                    $isCritical = $true
                    break
                }
            }
            
            if (-not $isCritical) {
                $nonCriticalPaths += $path
            }
        }
        
        # Combine critical and non-critical paths
        $result = $criticalOrderedPaths + $nonCriticalPaths
        return $result
    }
    
    return $sortedPaths
}

# Compare two lists of paths and return the paths that were removed
function Compare-PathLists {
    param (
        [string[]]$Original,
        [string[]]$New
    )
    
    $normalizedOriginal = $Original | ForEach-Object { (Get-NormalizedPath $_).ToLower() }
    $normalizedNew = $New | ForEach-Object { (Get-NormalizedPath $_).ToLower() }
    
    $removed = @()
    
    foreach ($path in $normalizedOriginal) {
        if (-not ($normalizedNew -contains $path)) {
            $originalIndex = [array]::IndexOf($normalizedOriginal, $path)
            $removed += $Original[$originalIndex]
        }
    }
    
    return $removed
}

# Display the optimization plan
function Show-OptimizationPlan {
    param (
        [hashtable]$Plan
    )
    
    Write-Host "`nOptimization Plan:" -ForegroundColor Cyan
    Write-Host "-------------------" -ForegroundColor Cyan
    
    # Summary of changes
    $userPathsRemovedCount = $Plan.UserPathsRemoved.Count
    $systemPathsRemovedCount = $Plan.SystemPathsRemoved.Count
    $totalRemovedCount = $userPathsRemovedCount + $systemPathsRemovedCount
    
    Write-Host "Changes to be made:" -ForegroundColor White
    Write-Host "  - User PATH: $($Plan.OriginalUserPaths.Count) entries → $($Plan.UserPathCount) entries" -ForegroundColor $(if ($userPathsRemovedCount -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  - System PATH: $($Plan.OriginalSystemPaths.Count) entries → $($Plan.SystemPathCount) entries" -ForegroundColor $(if ($systemPathsRemovedCount -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  - Total entries removed: $totalRemovedCount" -ForegroundColor $(if ($totalRemovedCount -gt 0) { "Yellow" } else { "Green" })
    
    # Show what will be removed
    if ($userPathsRemovedCount -gt 0) {
        Write-Host "`nUser PATH entries to be removed:" -ForegroundColor Yellow
        foreach ($path in $Plan.UserPathsRemoved) {
            Write-Host "  - $path" -ForegroundColor Gray
        }
    }
    
    if ($systemPathsRemovedCount -gt 0) {
        Write-Host "`nSystem PATH entries to be removed:" -ForegroundColor Yellow
        foreach ($path in $Plan.SystemPathsRemoved) {
            Write-Host "  - $path" -ForegroundColor Gray
        }
    }
    
    # Show the new ordering
    Write-Host "`nNew PATH environment ordering:" -ForegroundColor Cyan
    Write-Host "  System PATH:" -ForegroundColor Blue
    foreach ($path in $Plan.NewSystemPaths) {
        Write-Host "  - $path" -ForegroundColor Gray
    }
    
    Write-Host "`n  User PATH:" -ForegroundColor Blue
    foreach ($path in $Plan.NewUserPaths) {
        Write-Host "  - $path" -ForegroundColor Gray
    }
}

# Apply the optimization plan to the PATH environment
function Set-PathChanges {
    param (
        [hashtable]$Plan,
        [switch]$WhatIf
    )
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf specified - would update PATH environment variables" -Level "Info"
            
            return @{
                Success = $true
                UserPathCount = $Plan.UserPathCount
                SystemPathCount = $Plan.SystemPathCount
                UserPathsRemoved = $Plan.UserPathsRemoved.Count
                SystemPathsRemoved = $Plan.SystemPathsRemoved.Count
            }
        }
        
        # Update the PATH environment variables
        $userPathString = $Plan.NewUserPaths -join ";"
        $systemPathString = $Plan.NewSystemPaths -join ";"
        
        Write-Log "Updating User PATH to $($Plan.UserPathCount) entries" -Level "Info"
        [Environment]::SetEnvironmentVariable('Path', $userPathString, 'User')
        
        Write-Log "Updating System PATH to $($Plan.SystemPathCount) entries" -Level "Info"
        [Environment]::SetEnvironmentVariable('Path', $systemPathString, 'Machine')
        
        return @{
            Success = $true
            UserPathCount = $Plan.UserPathCount
            SystemPathCount = $Plan.SystemPathCount
            UserPathsRemoved = $Plan.UserPathsRemoved.Count
            SystemPathsRemoved = $Plan.SystemPathsRemoved.Count
        }
    }
    catch {
        Write-Log "Error applying PATH changes: $_" -Level "Error"
        
        return @{
            Success = $false
            Error = $_
        }
    }
}

# Export module functions
Export-ModuleMember -Function New-OptimizationPlan, Optimize-PathOrder, Compare-PathLists, Show-OptimizationPlan, Set-PathChanges
