# Validator.psm1
# Provides path validation functionality for the PathOptimizer

# Validate a list of paths
function Test-Paths {
    param (
        [string[]]$Paths,
        [hashtable]$Config
    )
    
    Write-Log "Validating $($Paths.Count) PATH entries" -Level "Info"
    
    $validationResults = @{
        ValidPaths = @()
        InvalidPaths = @()
        EmptyPaths = @()
        MalformedPaths = @()
        NonExistentPaths = @()
        QuotedPaths = @()
        PathsWithSpaces = @()
        TooLongPaths = @()
    }
    
    foreach ($path in $Paths) {
        $isValid = $true
        $issues = @()
        
        # Check for empty paths
        if ([string]::IsNullOrWhiteSpace($path)) {
            $validationResults.EmptyPaths += $path
            $isValid = $false
            $issues += "Empty"
            continue
        }
        
        # Check for malformed paths
        if ($path -eq ";" -or $path.Length -le 2 -or $path -match ";;") {
            $validationResults.MalformedPaths += $path
            $isValid = $false
            $issues += "Malformed"
        }
        
        # Check for non-existent paths
        if (-not (Test-Path -Path $path -ErrorAction SilentlyContinue)) {
            $validationResults.NonExistentPaths += $path
            $isValid = $false
            $issues += "NonExistent"
        }
        
        # Check for quoted paths
        if ($path -match '^".*"$' -or $path -match "^'.*'$") {
            $validationResults.QuotedPaths += $path
            $issues += "Quoted"
        }
        
        # Check for paths with spaces but no quotes
        if ($path -match " " -and -not ($path -match '^".*"$' -or $path -match "^'.*'$")) {
            $validationResults.PathsWithSpaces += $path
            $issues += "Spaces"
        }
        
        # Check for long paths
        if ($path.Length -gt 260) {
            $validationResults.TooLongPaths += $path
            $issues += "TooLong"
        }
        
        # Add to appropriate collection
        if ($isValid) {
            $validationResults.ValidPaths += @{
                Path = $path
                Issues = $issues
            }
        }
        else {
            $validationResults.InvalidPaths += @{
                Path = $path
                Issues = $issues
            }
        }
    }
    
    Write-Log "Validation complete: $($validationResults.ValidPaths.Count) valid, $($validationResults.InvalidPaths.Count) invalid" -Level "Info"
    
    return $validationResults
}

# Display a summary of the validation results
function Show-ValidationSummary {
    param (
        [hashtable]$Validation
    )
    
    Write-Host "`nPATH Validation Summary:" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan
    
    $validCount = $Validation.ValidPaths.Count
    $invalidCount = $Validation.InvalidPaths.Count
    $totalCount = $validCount + $invalidCount
    
    Write-Host "Paths analyzed: $totalCount" -ForegroundColor White
    Write-Host "  - Valid paths: $validCount" -ForegroundColor Green
    Write-Host "  - Invalid paths: $invalidCount" -ForegroundColor $(if ($invalidCount -gt 0) { "Yellow" } else { "Green" })
    
    if ($Validation.EmptyPaths.Count -gt 0) {
        Write-Host "  - Empty entries: $($Validation.EmptyPaths.Count)" -ForegroundColor Yellow
    }
    
    if ($Validation.MalformedPaths.Count -gt 0) {
        Write-Host "  - Malformed paths: $($Validation.MalformedPaths.Count)" -ForegroundColor Yellow
    }
    
    if ($Validation.NonExistentPaths.Count -gt 0) {
        Write-Host "  - Non-existent paths: $($Validation.NonExistentPaths.Count)" -ForegroundColor Yellow
    }
    
    if ($Validation.QuotedPaths.Count -gt 0) {
        Write-Host "  - Quoted paths: $($Validation.QuotedPaths.Count)" -ForegroundColor Cyan
    }
    
    if ($Validation.PathsWithSpaces.Count -gt 0) {
        Write-Host "  - Paths with spaces (unquoted): $($Validation.PathsWithSpaces.Count)" -ForegroundColor Cyan
    }
    
    if ($Validation.TooLongPaths.Count -gt 0) {
        Write-Host "  - Excessively long paths: $($Validation.TooLongPaths.Count)" -ForegroundColor Yellow
    }
    
    # Show paths with issues if verbose
    if ($Validation.InvalidPaths.Count -gt 0) {
        Write-Host "`nInvalid paths:" -ForegroundColor Yellow
        foreach ($invalidPath in $Validation.InvalidPaths) {
            Write-Host "  - $($invalidPath.Path)" -ForegroundColor Gray
            Write-Host "    Issues: $($invalidPath.Issues -join ", ")" -ForegroundColor Gray
        }
    }
}

# Validate a specific command's accessibility
function Test-CommandAccessibility {
    param (
        [string]$Command
    )
    
    try {
        $commandPath = (Get-Command $Command -ErrorAction Stop).Source
        return @{
            Accessible = $true
            Path = $commandPath
        }
    }
    catch {
        return @{
            Accessible = $false
            Error = $_.Exception.Message
        }
    }
}

# Validate the total length of PATH environment
function Test-PathLength {
    param (
        [string[]]$UserPaths,
        [string[]]$SystemPaths,
        [int]$MaxLength = 8191
    )
    
    $userPathString = $UserPaths -join ";"
    $systemPathString = $SystemPaths -join ";"
    $totalLength = $userPathString.Length + $systemPathString.Length
    
    return @{
        UserPathLength = $userPathString.Length
        SystemPathLength = $systemPathString.Length
        TotalLength = $totalLength
        ExceedsLimit = $totalLength -gt $MaxLength
        MaxLength = $MaxLength
        PercentUsed = [math]::Round(($totalLength / $MaxLength) * 100, 1)
    }
}

# Export module functions
Export-ModuleMember -Function Test-Paths, Show-ValidationSummary, Test-CommandAccessibility, Test-PathLength
