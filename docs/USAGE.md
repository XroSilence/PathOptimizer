# PathOptimizer Usage Guide

## Quick Start

1. Download the repository to your local machine
2. Run `Run-PathOptimizer.bat` as Administrator
3. Review the analysis and proposed changes
4. Confirm when prompted to apply changes
5. Restart your terminal or applications for changes to take effect

## Command Line Arguments

Both the batch file and PowerShell script support the following parameters:

| Parameter | Description |
|-----------|-------------|
| `-WhatIf` | Shows what changes would be made without applying them |
| `-Verbose` | Provides detailed information about operations |
| `-Interactive` | Prompts for confirmation before making changes (default) |
| `-NonInteractive` | Makes all changes without prompting (use with caution) |
| `-FixSpecificIssue <type>` | Targets only a specific issue type |
| `-CustomConfig <path>` | Specifies a custom configuration file |

### Issue Types

When using `-FixSpecificIssue`, you can specify one of the following types:

- `Duplicates`: Remove duplicate entries
- `Ordering`: Optimize the order of entries
- `NonExistent`: Remove non-existent paths
- `ToolSpecific`: Fix tool-specific issues (like FNM multishells)
- `All`: Fix all issues (default)

## Examples

### Preview Changes

```
.\Run-PathOptimizer.bat -WhatIf
```

This will analyze your PATH environment and show what changes would be made without actually making them.

### Fix Duplicates Only

```
.\Run-PathOptimizer.bat -FixSpecificIssue Duplicates
```

This will only remove duplicate entries from your PATH.

### Non-Interactive Mode

```
.\Run-PathOptimizer.bat -NonInteractive
```

This will apply all recommended changes without prompting for confirmation.

### Verbose Mode

```
.\Run-PathOptimizer.bat -Verbose
```

This will provide detailed information about each operation performed.

## Using the PowerShell Script Directly

If you prefer to use the PowerShell script directly:

```powershell
.\PathOptimizer.ps1 -WhatIf -Verbose
```

## Customizing Behavior

You can customize the behavior by:

1. Editing the JSON configuration files in the `config` directory
2. Creating your own configuration file and using `-CustomConfig`

See the [CONFIGURATION.md](CONFIGURATION.md) file for details on configuration options.

## Log and Backup Files

PathOptimizer creates the following files:

- A timestamped log file with detailed information about operations
- A backup of your current PATH environment before making changes

These files are stored in the same directory as the script and can be used to troubleshoot issues or restore your previous PATH configuration if necessary.

To restore from a backup, use the following PowerShell commands:

```powershell
$backupContent = Get-Content "path_backup_TIMESTAMP.txt"
$userPathLine = $backupContent.IndexOf("USER PATH:")
$systemPathLine = $backupContent.IndexOf("SYSTEM PATH:")
$userPath = $backupContent[$userPathLine + 1]
$systemPath = $backupContent[$systemPathLine + 1]
[Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
[Environment]::SetEnvironmentVariable('Path', $systemPath, 'Machine')
```

Replace `TIMESTAMP` with the actual timestamp in the backup filename.
