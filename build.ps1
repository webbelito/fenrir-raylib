#!/usr/bin/env pwsh

# Fenrir Engine build script
param (
    [switch]$debug = $false,
    [switch]$run = $false,
    [switch]$verbose = $false,
    [switch]$no_color = $false
)

# Function to check if we can use ANSI colors
function Test-ANSIColorSupport {
    # Check if we're running in PowerShell Core (7+)
    $isPSCore = $PSVersionTable.PSEdition -eq 'Core'
    
    # Check if we're running in Windows Terminal, VS Code, or other modern terminal
    $isModernTerminal = $env:WT_SESSION -ne $null -or 
                         $env:TERM_PROGRAM -eq 'vscode' -or
                         $env:COLORTERM -eq 'truecolor' -or
                         $env:TERM -like '*256color'
    
    # Return true if we're in a compatible environment
    return $isPSCore -or $isModernTerminal
}

# Setup color support
$useANSI = (-not $no_color) -and (Test-ANSIColorSupport)

# Try to enable virtual terminal sequences if we're using colors
if ($useANSI) {
    try {
        # For Windows PowerShell, try to enable ANSI processing
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
            # Add Windows 10 ANSI support for older PowerShell
            $kernel32 = Add-Type -MemberDefinition '
                [DllImport("kernel32.dll", SetLastError=true)]
                public static extern bool SetConsoleMode(IntPtr hConsoleHandle, int mode);
                [DllImport("kernel32.dll", SetLastError=true)]
                public static extern IntPtr GetStdHandle(int handle);
                [DllImport("kernel32.dll", SetLastError=true)]
                public static extern bool GetConsoleMode(IntPtr handle, out int mode);
            ' -Name 'Win32' -Namespace 'Win32Functions' -PassThru
            
            $h = $kernel32::GetStdHandle(-11) # STD_OUTPUT_HANDLE
            $mode = 0
            $kernel32::GetConsoleMode($h, [ref]$mode)
            $mode = $mode -bor 4 # ENABLE_VIRTUAL_TERMINAL_PROCESSING
            $kernel32::SetConsoleMode($h, $mode)
        }
        
        # For PowerShell 7.2+
        if ($PSVersionTable.PSVersion -ge [Version]"7.2") {
            $PSStyle.OutputRendering = 'ANSI'
        }
        
        # Set output encoding to UTF-8
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {
        # If any of that fails, fall back to no colors
        $useANSI = $false
        Write-Host "Warning: ANSI color support could not be enabled. Using plain text output."
    }
}

# Define ANSI color codes or empty strings based on support
$Colors = @{
    Reset     = if ($useANSI) { "`e[0m" } else { "" }
    Black     = if ($useANSI) { "`e[30m" } else { "" }
    Red       = if ($useANSI) { "`e[31m" } else { "" }
    Green     = if ($useANSI) { "`e[32m" } else { "" }
    Yellow    = if ($useANSI) { "`e[33m" } else { "" }
    Blue      = if ($useANSI) { "`e[34m" } else { "" }
    Magenta   = if ($useANSI) { "`e[35m" } else { "" }
    Cyan      = if ($useANSI) { "`e[36m" } else { "" }
    White     = if ($useANSI) { "`e[37m" } else { "" }
    Bold      = if ($useANSI) { "`e[1m" } else { "" }
    Underline = if ($useANSI) { "`e[4m" } else { "" }
    Inverse   = if ($useANSI) { "`e[7m" } else { "" }
}

# Log levels and formatting similar to our Odin logging system
function Log-Build {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("INFO", "DEBUG", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$CallerFile = "build.ps1"
    )
    
    # Get current timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    
    # Map log levels to colors
    $levelColor = switch ($Level) {
        "DEBUG" { $Colors.Blue }
        "INFO" { $Colors.Green }
        "WARNING" { $Colors.Yellow }
        "ERROR" { $Colors.Red }
        "CRITICAL" { $Colors.Bold + $Colors.Red }
        default { $Colors.Reset }
    }
    
    # Format header with timestamp, category, and caller location
    $header = "[BUILD] [$timestamp] [$levelColor$Level$($Colors.Reset)] ($CallerFile)"
    
    # Output the formatted log message
    Write-Host $header
    Write-Host "    $Message"
    Write-Host ""
}

# Set build flags
$build_mode = if ($debug) { "debug" } else { "release" }
$build_flags = "-opt:3"

if ($debug) {
    $build_flags = "-debug"
    Log-Build -Level "DEBUG" -Message "Setting debug build flags: $build_flags"
} else {
    Log-Build -Level "INFO" -Message "Setting release build flags: $build_flags"
}

# Build the project
Log-Build -Level "INFO" -Message "Building Fenrir Engine in $build_mode mode..."

# Add verbose flag if requested
if ($verbose) {
    $build_flags += " -verbose-errors"
    Log-Build -Level "DEBUG" -Message "Enabling verbose error output"
}

# Build using shared raylib
$build_cmd = "odin build src -out:fenrir.exe $build_flags -define:RAYLIB_SHARED=true"
Log-Build -Level "DEBUG" -Message "Build command: $build_cmd"

try {
    # Execute the build command and capture output
    $output = Invoke-Expression $build_cmd 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Log-Build -Level "INFO" -Message "Build completed successfully"
        if ($verbose) {
            $output | ForEach-Object { Log-Build -Level "DEBUG" -Message $_ }
        }
    } else {
        Log-Build -Level "ERROR" -Message "Build failed with exit code: $LASTEXITCODE"
        $output | ForEach-Object { Log-Build -Level "ERROR" -Message $_ }
    }
} catch {
    Log-Build -Level "CRITICAL" -Message "Exception during build: $_"
}

# Run the project if requested
if ($run -and $LASTEXITCODE -eq 0) {
    Log-Build -Level "INFO" -Message "Running Fenrir Engine..."
    
    # Run with detailed error output
    try {
        $process = Start-Process -FilePath "./fenrir.exe" -PassThru -NoNewWindow -Wait
        Log-Build -Level "INFO" -Message "Process exited with code: $($process.ExitCode)"
        
        if ($process.ExitCode -ne 0) {
            Log-Build -Level "WARNING" -Message "Application exited with non-zero code: $($process.ExitCode)"
        }
    } catch {
        Log-Build -Level "CRITICAL" -Message "Error running the application: $_"
    }
} 