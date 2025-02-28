# PathOptimizer Configuration Guide

PathOptimizer can be customized through configuration files to adapt to specific environments and requirements.

## Configuration Files

The default configuration is stored in the `scripts/config` directory:

- `critical-paths.json`: Defines system paths that should never be removed
- `dev-tools.json`: Patterns for detecting development tools
- `known-issues.json`: Patterns for identifying common PATH issues
- `path-priority.json`: Priority values for different path categories

You can modify these files directly or create a custom configuration file.

## Custom Configuration

To use a custom configuration file:

```
.\Run-PathOptimizer.bat -CustomConfig "path\to\your-config.json"
```

A custom configuration file can override any or all of the default settings. It should be in JSON format with the following structure:

```json
{
  "CriticalPaths": [ 
    "C:\\Windows\\system32",
    "C:\\Windows"
  ],
  "IgnorePatterns": [
    "\\\\Temp\\\\",
    "\\\\tmp\\\\"
  ],
  "ToolDetectionPatterns": {
    "Node.js": ["node.exe", "npm.cmd"]
  },
  "KnownIssuePatterns": {
    "FNM Multishells": "fnm_multishells"
  },
  "PathPriorities": {
    "WindowsSystem": 1000,
    "DevTools": 700
  },
  "MaxPathLength": 8191,
  "RemoveEmptyPaths": true,
  "RemoveDuplicates": true,
  "RemoveNonexistent": true,
  "OptimizeOrder": true
}
```

You don't need to include all settings - only the ones you want to override.

## Configuration Options

### CriticalPaths

List of system paths that should never be removed and should appear at the beginning of the system PATH.

```json
"CriticalPaths": [
  "C:\\Windows\\system32",
  "C:\\Windows",
  "C:\\Windows\\System32\\Wbem",
  "C:\\Windows\\System32\\WindowsPowerShell\\v1.0",
  "C:\\Windows\\System32\\OpenSSH"
]
```

The order of paths in this list determines their priority and order in the final PATH.

### IgnorePatterns

Regular expression patterns for paths that should be ignored or removed.

```json
"IgnorePatterns": [
  "\\\\Temp\\\\",
  "\\\\tmp\\\\",
  "\\\\AppData\\\\Local\\\\Temp\\\\"
]
```

Any path matching these patterns will be considered temporary and removed during cleanup.

### ToolDetectionPatterns

Patterns for detecting development tools in PATH entries. Each tool can have multiple executable patterns.

```json
"ToolDetectionPatterns": {
  "Node.js": ["node.exe", "npm.cmd", "npx.cmd"],
  "Python": ["python.exe", "python3.exe", "pip.exe"],
  "Git": ["git.exe"]
}
```

These patterns are used to:
1. Identify which paths contain development tools
2. Resolve conflicts when multiple versions of the same tool exist
3. Prioritize paths based on the tools they contain

### KnownIssuePatterns

Regular expression patterns for known PATH issues.

```json
"KnownIssuePatterns": {
  "FNM Multishells": "fnm_multishells",
  "Temporary Node Paths": "node_modules\\\\.bin"
}
```

Each pattern has a descriptive name and a regular expression that matches problematic paths.

### PathPriorities

Priority values for different path categories. Higher values indicate higher priority.

```json
"PathPriorities": {
  "WindowsSystem": 1000,
  "PowerShell": 900,
  "CommandLine": 800,
  "DevTools": 700,
  "ProgramFiles": 600,
  "Languages": 500,
  "LocalApps": 400,
  "WindowsApps": 300,
  "Custom": 200,
  "Unknown": 100
}
```

These priorities determine the order of paths in the optimized PATH environment.

### Behavioral Settings

Control how PathOptimizer behaves:

```json
"MaxPathLength": 8191,       // Maximum allowed PATH length (8191 is Windows limit)
"RemoveEmptyPaths": true,    // Remove empty entries
"RemoveDuplicates": true,    // Remove duplicate entries
"RemoveNonexistent": true,   // Remove paths that don't exist
"PreserveOrder": false,      // Keep original order (overrides optimization)
"OptimizeOrder": true,       // Optimize path order based on priorities
"SeparateUserSystem": true   // Keep user and system paths separate
```

## Advanced Configuration Examples

### Preserving Specific Paths

If you want to ensure specific paths are preserved even if they match removal patterns:

```json
"PreservedPaths": [
  "C:\\Users\\username\\AppData\\Local\\Programs\\Custom Tool"
]
```

### Custom Tool Detection

Add your own tool patterns:

```json
"ToolDetectionPatterns": {
  "MyCustomTool": ["mytool.exe", "mytool-cli.cmd"]
}
```

### Customizing Path Categories

Define custom rules for categorizing paths:

```json
"PathCategoryRules": {
  "CustomCategory": ["\\\\MyCompany\\\\", "\\\\OurTools\\\\"]
}
```

Then assign a priority to your custom category:

```json
"PathPriorities": {
  "CustomCategory": 750
}
```

## Enterprise Configuration

For enterprise environments, you can create a central configuration that:

1. Preserves company-specific tools
2. Handles proprietary software paths
3. Maintains consistent PATH ordering across machines
4. Complies with IT security policies

Deploy this configuration using:

```
.\Run-PathOptimizer.bat -NonInteractive -CustomConfig "\\server\share\enterprise-path-config.json"
```
