#Requires -Version 5.1

<#
.SYNOPSIS
    JetBrains IDE Activation Script for Windows

.DESCRIPTION
    This script activates all installed JetBrains IDEs using ja-netfilter.
    It downloads necessary files, configures .vmoptions, and generates license keys.

.NOTES
    Author: CodeKey Run
    Date: 2025-08-20
#>

# ============ Configuration =============
$ErrorActionPreference = "Stop"
$DebugPreference = if ($env:DEBUG -eq "true") { "Continue" } else { "SilentlyContinue" }

# Colors for output
$Colors = @{
    Red = [ConsoleColor]::Red
    Green = [ConsoleColor]::Green
    Yellow = [ConsoleColor]::Yellow
    Gray = [ConsoleColor]::Gray
    White = [ConsoleColor]::White
    Cyan = [ConsoleColor]::Cyan
}

# Enable colors
$EnableColor = $true

# Base URLs
$URL_BASE = "https://ckey.run"
#$URL_BASE = "http://192.168.31.254:10768"
$URL_DOWNLOAD = "$URL_BASE/ja-netfilter"
$URL_LICENSE = "$URL_BASE/generateLicense/file"

# Get user directories
$USER_HOME = $env:USERPROFILE
$APPDATA = $env:APPDATA
$LOCALAPPDATA = $env:LOCALAPPDATA

# Working directories
$dir_work = Join-Path $USER_HOME ".jb_run"
$dir_config = Join-Path $dir_work "config"
$dir_plugins = Join-Path $dir_work "plugins"
$dir_backups = Join-Path $dir_work "backups"
$file_netfilter_jar = Join-Path $dir_work "ja-netfilter.jar"

# JetBrains directories
$dir_cache_jb = Join-Path $LOCALAPPDATA "JetBrains"
$dir_config_jb = Join-Path $APPDATA "JetBrains"

# Product list
$PRODUCTS = @'
[
    {"name":"idea","productCode":"II,PCWMP,PSI"},
    {"name":"clion","productCode":"CL,PSI,PCWMP"},
    {"name":"phpstorm","productCode":"PS,PCWMP,PSI"},
    {"name":"goland","productCode":"GO,PSI,PCWMP"},
    {"name":"pycharm","productCode":"PC,PSI,PCWMP"},
    {"name":"webstorm","productCode":"WS,PCWMP,PSI"},
    {"name":"rider","productCode":"RD,PDB,PSI,PCWMP"},
    {"name":"datagrip","productCode":"DB,PSI,PDB"},
    {"name":"rubymine","productCode":"RM,PCWMP,PSI"},
    {"name":"appcode","productCode":"AC,PCWMP,PSI"},
    {"name":"dataspell","productCode":"DS,PSI,PDB,PCWMP"},
    {"name":"dotmemory","productCode":"DM"},
    {"name":"rustrover","productCode":"RR,PSI,PCWP"}
]
'@ | ConvertFrom-Json

# License JSON template
$LICENSE_JSON = $null

# ============ Logging Functions =============
function Write-ColoredMessage {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    if ($EnableColor) {
        Write-Host $Message -ForegroundColor $Color
    } else {
        Write-Host $Message
    }
}

function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp][$Level] $Message"

    switch ($Level) {
        "DEBUG" {
            if ($env:DEBUG -eq "true") {
                Write-ColoredMessage $logMessage $Colors.Gray
            }
        }
        "INFO" { Write-ColoredMessage $logMessage $Colors.White }
        "WARNING" { Write-ColoredMessage $logMessage $Colors.Yellow }
        "ERROR" { Write-ColoredMessage $logMessage $Colors.Red }
        "SUCCESS" { Write-ColoredMessage $logMessage $Colors.Green }
    }
}

function Write-Debug { param([string]$Message) Write-Log "DEBUG" $Message }
function Write-Info { param([string]$Message) Write-Log "INFO" $Message }
function Write-Warning { param([string]$Message) Write-Log "WARNING" $Message }
function Write-Error { param([string]$Message) Write-Log "ERROR" $Message }
function Write-Success { param([string]$Message) Write-Log "SUCCESS" $Message }

# ============ ASCII Art =============
function Show-ASCIIJB {
    $art = @'
JJJJJJ   EEEEEEE   TTTTTTTT  BBBBBBB    RRRRRR    AAAAAA    IIIIIIII  NNNN   NN   SSSSSS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NNNNN  NN  SS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN NNN NN   SS
   JJ    EEEEE        TT     BBBBBBB    RRRRRR    AAAAAA       II     NN  NNNNN    SSSSS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN   NNNN         SS
JJ JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN    NNN          SS
 JJJJ    EEEEEEE      TT     BBBBBBB    RR   RR   AA  AA    IIIIIIII  NN    NNN    SSSSSS
'@
    Write-ColoredMessage $art $Colors.Cyan
}

# ============ Dependency Check and Installation =============
function Test-Dependencies {
    $deps = @("curl", "jq")
    $missing = @()

    foreach ($dep in $deps) {
        try {
            $null = Get-Command $dep -ErrorAction Stop
        } catch {
            $missing += $dep
        }
    }

    return $missing
}

function Install-Dependencies {
    param([array]$MissingDeps)

    if ($MissingDeps.Count -eq 0) {
        Write-Info "All dependencies are already installed."
        return
    }

    Write-Warning "Missing dependencies: $($MissingDeps -join ', '), attempting automatic installation..."

    # Try winget first, then chocolatey
    $packageManager = $null

    # Check for winget
    try {
        $null = Get-Command winget -ErrorAction Stop
        $packageManager = "winget"
    } catch {
        # Check for chocolatey
        try {
            $null = Get-Command choco -ErrorAction Stop
            $packageManager = "choco"
        } catch {
            Write-Error "No package manager found. Please install winget or Chocolatey manually."
            exit 1
        }
    }

    foreach ($dep in $MissingDeps) {
        Write-Info "Installing $dep..."
        try {
            switch ($packageManager) {
                "winget" {
                    switch ($dep) {
                        "curl" { winget install -e --id cURL.cURL }
                        "jq" { winget install -e --id jqlang.jq }
                    }
                }
                "choco" {
                    switch ($dep) {
                        "curl" { choco install curl -y }
                        "jq" { choco install jq -y }
                    }
                }
            }
        } catch {
            Write-Error "Failed to install $dep"
            exit 1
        }
    }

    Write-Success "All dependencies have been successfully installed!"
}

# ============ Environment Variable Cleanup =============
function Remove-EnvironmentVariables {
    Write-Info "Starting cleanup of JetBrains related environment variables"

    # Clean up other activation tools' residues
    Remove-ThirdPartyEnvVars

    $shellFiles = @(
        (Join-Path $USER_HOME ".bash_profile"),
        (Join-Path $USER_HOME ".bashrc"),
        (Join-Path $USER_HOME ".zshrc"),
        (Join-Path $USER_HOME ".profile")
    )

    $existingFiles = $shellFiles | Where-Object { Test-Path $_ }

    if ($existingFiles.Count -eq 0) {
        Write-Debug "No environment variable files found, skipping"
        return
    }

    # Create backup directory with timestamp
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $backupDir = Join-Path $dir_backups $timestamp

    foreach ($file in $existingFiles) {
        if (-not (Test-Path -PathType Leaf $file)) {
            continue
        }

        # Create backup
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }

        $backupFile = Join-Path $backupDir "_$(Split-Path $file -Leaf)"
        Copy-Item $file $backupFile -Force
        Write-Debug "Backup environment variable file: $file to $backupFile"

        # Clean up JetBrains environment variables
        $content = Get-Content $file -Raw
        foreach ($product in $PRODUCTS) {
            $envVar = "$($product.name.ToUpper())_VM_OPTIONS"
            $pattern = "^${envVar}=.*$"
            $content = $content -replace $pattern, ""
            Write-Debug "Removed environment variable: $envVar from $file"
        }

        # Write back to file
        Set-Content -Path $file -Value $content
    }
}

function Remove-ThirdPartyEnvVars {
    $jbProducts = @("idea", "clion", "phpstorm", "goland", "pycharm", "webstorm", "webide", "rider", "datagrip", "rubymine", "appcode", "dataspell", "gateway", "jetbrains_client", "jetbrainsclient")

    foreach ($prd in $jbProducts) {
        $envName = "$($prd.ToUpper())_VM_OPTIONS"
        [Environment]::SetEnvironmentVariable($envName, $null, "User")
    }

    # Remove script files
    $scriptFiles = @(
        (Join-Path $USER_HOME ".jetbrains.vmoptions.sh"),
        (Join-Path $env:ProgramData "jetbrains.vmoptions.sh")
    )

    foreach ($file in $scriptFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
        }
    }

    Write-Debug "Third-party tool environment variables cleanup completed"
}

# ============ Date Validation =============
function Test-DateFormat {
    param([string]$InputDate)

    $pattern = '^\d{4}-\d{2}-\d{2}$'
    if ($InputDate -match $pattern) {
        return $true
    }
    Write-Warning "Please enter standard format: yyyy-MM-dd (example: 2099-12-31)"
    return $false
}

# ============ User License Information Input =============
function Read-LicenseInfo {
    $license_name = Read-Host "Custom license name (Enter for default ckey.run)"
    if ([string]::IsNullOrWhiteSpace($license_name)) {
        $license_name = "ckey.run"
    }

    $default_expiry = "2099-12-31"
    $valid = $false

    while (-not $valid) {
        $expiry_input = Read-Host "Custom license date (Enter for default $default_expiry, format yyyy-MM-dd)"
        if ([string]::IsNullOrWhiteSpace($expiry_input)) {
            $expiry_input = $default_expiry
        }

        Write-Debug "Input license date: $expiry_input"
        if (Test-DateFormat $expiry_input) {
            $script:LICENSE_JSON = @{
                assigneeName = ""
                expiryDate = $expiry_input
                licenseName = $license_name
                productCode = ""
            } | ConvertTo-Json
            $valid = $true
        } else {
            Write-Warning "Date format is invalid, please enter correct yyyy-MM-dd format (example: 2099-12-31)"
        }
    }
}

# ============ Create Working Directory =============
function New-WorkingDirectory {
    if (-not $dir_work -or $dir_work -eq "/" -or $dir_work -eq "\") {
        Write-Error "Illegal path detected: $dir_work, please check configuration."
        exit 1
    }

    if (Test-Path $dir_work) {
        # Kill any JetBrains processes
        Get-Process | Where-Object { $_.ProcessName -like "*jetbrains*" -or $_.ProcessName -like "*idea*" -or $_.ProcessName -like "*pycharm*" -or $_.ProcessName -like "*webstorm*" } | Stop-Process -Force -ErrorAction SilentlyContinue

        # Remove existing directories
        Remove-Item $dir_plugins -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $dir_config -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $file_netfilter_jar -Force -ErrorAction SilentlyContinue
    }

    # Create directories
    New-Item -ItemType Directory -Path $dir_config, $dir_plugins, $dir_backups -Force | Out-Null
    Write-Debug "Created working directory: $dir_work"
}

# ============ Download Files =============
function Get-FileFromUrl {
    param(
        [string]$Url,
        [string]$OutputPath
    )

    Write-Debug "Downloading: $Url -> $OutputPath"

    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
    } catch {
        Write-Error "Download failed: $Url"
        exit 1
    }

    # Verify JAR files with SHA-1
    if ($OutputPath -like "*.jar") {
        try {
            $sha1 = Get-FileHash $OutputPath -Algorithm SHA1
            Write-Debug "SHA1: $($sha1.Hash.ToLower())"
        } catch {
            Write-Warning "Could not calculate SHA-1 hash for $OutputPath"
        }
    }
}

function Show-ProgressBar {
    param(
        [int]$Current,
        [int]$Total
    )

    $percent = [math]::Round(($Current / $Total) * 100)
    $filled = [math]::Round(($percent / 100) * 30)
    $bar = "[" + ("#" * $filled) + ("." * (30 - $filled)) + "]"

    Write-Host "`rConfiguring ja-netfilter... $Current/$Total $bar $percent%" -NoNewline
}

function Get-Resources {
    $resources = @(
        "$URL_DOWNLOAD/ja-netfilter.jar|$file_netfilter_jar",
        "$URL_DOWNLOAD/config/dns.conf|$(Join-Path $dir_config 'dns.conf')",
        "$URL_DOWNLOAD/config/native.conf|$(Join-Path $dir_config 'native.conf')",
        "$URL_DOWNLOAD/config/power.conf|$(Join-Path $dir_config 'power.conf')",
        "$URL_DOWNLOAD/config/url.conf|$(Join-Path $dir_config 'url.conf')",
        "$URL_DOWNLOAD/plugins/dns.jar|$(Join-Path $dir_plugins 'dns.jar')",
        "$URL_DOWNLOAD/plugins/native.jar|$(Join-Path $dir_plugins 'native.jar')",
        "$URL_DOWNLOAD/plugins/power.jar|$(Join-Path $dir_plugins 'power.jar')",
        "$URL_DOWNLOAD/plugins/url.jar|$(Join-Path $dir_plugins 'url.jar')",
        "$URL_DOWNLOAD/plugins/hideme.jar|$(Join-Path $dir_plugins 'hideme.jar')",
        "$URL_DOWNLOAD/plugins/privacy.jar|$(Join-Path $dir_plugins 'privacy.jar')"
    )

    $totalFiles = $resources.Count
    $count = 0

    Write-Debug "Original ja-netfilter project address: https://gitee.com/ja-netfilter/ja-netfilter/releases/tag/2022.2.0"
    Write-Debug "If you need to check if downloaded .jar files have been tampered with, please verify SHA-1 values match the original project files"

    foreach ($item in $resources) {
        $parts = $item -split '\|'
        $url = $parts[0]
        $path = $parts[1]

        Get-FileFromUrl $url $path
        $count++
        Show-ProgressBar $count $totalFiles
    }
    Write-Host ""
}

# ============ Clean and Update .vmoptions Files =============
function Clear-VMOptions {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        Write-Debug "Clean vm: File does not exist, skipping cleanup: $FilePath"
        return
    }

    $keywords = @(
        "-javaagent",
        "--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED",
        "--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED"
    )

    $lines = Get-Content $FilePath
    $filteredLines = @()

    foreach ($line in $lines) {
        $matched = $false
        foreach ($keyword in $keywords) {
            if ($line -like "*$keyword*") {
                $matched = $true
                break
            }
        }
        if (-not $matched) {
            $filteredLines += $line
        }
    }

    $filteredLines | Set-Content $FilePath -Force
    Write-Debug "Clean vm: $FilePath"
}

function Add-VMOptions {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        New-Item -ItemType File -Path $FilePath -Force | Out-Null
    }

    $vmOptions = @(
        "--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED",
        "--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED",
        "-javaagent:$file_netfilter_jar"
    )

    Add-Content $FilePath ($vmOptions -join "`n")
    Write-Debug "Generate vm: $FilePath"
}

# ============ Generate License Key =============
# ============ Generate License Key - FIXED VERSION =============
function New-License {
    param(
        [string]$ProductName,
        [string]$ProductCode,
        [string]$ProductDir
    )

    $licenseFile = Join-Path $dir_config_jb "$ProductDir\$ProductName.key"

    if (Test-Path $licenseFile) {
        Remove-Item $licenseFile -Force
    }

    # FIX 1: Properly construct JSON with UTF-8 encoding
    $licenseObj = @{
        assigneeName = ""
        expiryDate = ($LICENSE_JSON | ConvertFrom-Json).expiryDate
        licenseName = ($LICENSE_JSON | ConvertFrom-Json).licenseName
        productCode = $ProductCode
    }
    
    # FIX 2: Convert to JSON with proper depth and encoding
    $jsonBody = $licenseObj | ConvertTo-Json -Depth 10 -Compress

    Write-Debug "URL_LICENSE: $URL_LICENSE"
    Write-Debug "JSON Body: $jsonBody"
    Write-Debug "Save Path: $licenseFile"

    try {
        # FIX 3: Use WebRequest instead of RestMethod for better control
        $headers = @{
            'Content-Type' = 'application/json; charset=utf-8'
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }

        # FIX 4: Explicit UTF-8 encoding for the request body
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
        
        $response = Invoke-WebRequest -Uri $URL_LICENSE -Method Post -Body $bodyBytes -Headers $headers -UseBasicParsing

        # FIX 5: Save response content with proper encoding
        [System.IO.File]::WriteAllText($licenseFile, $response.Content, [System.Text.Encoding]::UTF8)

        if (Test-Path $licenseFile -and (Get-Item $licenseFile).Length -gt 0) {
            Write-Success "$ProductDir activation successful!"

            # Show license key in terminal
            Write-Info "=== LICENSE KEY FOR $ProductDir ==="
            $licenseContent = Get-Content $licenseFile -Raw -Encoding UTF8
            Write-ColoredMessage $licenseContent $Colors.Green
            Write-Info "Copy the key above and use it to activate $ProductDir"
            Write-Host ""
        } else {
            Write-Warning "$ProductDir license file is empty or creation failed!"
            Write-Debug "Response Status: $($response.StatusCode)"
            Write-Debug "Response Content: $($response.Content)"
        }
    } catch {
        Write-Warning "$ProductDir license generation failed: $($_.Exception.Message)"
        Write-Debug "Full Error: $($_.Exception | ConvertTo-Json -Depth 3)"
        
        # FIX 6: Fallback method using curl if available
        if (Get-Command curl -ErrorAction SilentlyContinue) {
            Write-Info "Trying fallback method with curl..."
            try {
                $tempFile = [System.IO.Path]::GetTempFileName()
                Set-Content -Path $tempFile -Value $jsonBody -Encoding UTF8
                
                $curlArgs = @(
                    '-s', '-X', 'POST', $URL_LICENSE,
                    '-H', 'Content-Type: application/json',
                    '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                    '-d', "@$tempFile",
                    '-o', $licenseFile
                )
                
                & curl @curlArgs
                
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                
                if (Test-Path $licenseFile -and (Get-Item $licenseFile).Length -gt 0) {
                    Write-Success "$ProductDir activation successful (via curl)!"
                    Write-Info "=== LICENSE KEY FOR $ProductDir ==="
                    $licenseContent = Get-Content $licenseFile -Raw -Encoding UTF8
                    Write-ColoredMessage $licenseContent $Colors.Green
                    Write-Info "Copy the key above and use it to activate $ProductDir"
                    Write-Host ""
                } else {
                    Write-Warning "$ProductDir requires manual license key entry!"
                }
            } catch {
                Write-Warning "$ProductDir requires manual license key entry!"
            }
        } else {
            Write-Warning "$ProductDir requires manual license key entry!"
        }
    }
}
# ============ Process Individual JetBrains Product =============
function Install-JetBrainsProduct {
    param([string]$ProductDir)

    $productDirName = Split-Path $ProductDir -Leaf
    $objProductName = ""
    $objProductCode = ""

    foreach ($product in $PRODUCTS) {
        if ($productDirName.ToLower() -like "*$($product.name)*") {
            $objProductName = $product.name
            $objProductCode = $product.productCode
            break
        }
    }

    if ([string]::IsNullOrEmpty($objProductName)) {
        return
    }

    Write-Info "Processing: $productDirName"

    $homeFile = Join-Path $ProductDir ".home"
    if (-not (Test-Path $homeFile)) {
        Write-Warning ".home file not found for $productDirName"
        return
    }

    Write-Debug ".home path: $homeFile"

    $installPath = Get-Content $homeFile -Raw
    if (-not (Test-Path $installPath)) {
        Write-Warning "Installation path not found for $productDirName!"
        return
    }

    Write-Debug ".home content: $installPath"

    $binDir = Join-Path $installPath "bin"
    if (-not (Test-Path $binDir)) {
        Write-Warning "$productDirName bin directory does not exist, please confirm proper installation!"
        return
    }

    $productConfigDir = Join-Path $dir_config_jb $productDirName

    # Handle .vmoptions files
    $vmOptionsPattern = "*$objProductName.vmoptions"
    $vmOptionsFiles = Get-ChildItem -Path $productConfigDir -Filter $vmOptionsPattern -ErrorAction SilentlyContinue

    if ($vmOptionsFiles) {
        foreach ($vmFile in $vmOptionsFiles) {
            Clear-VMOptions $vmFile.FullName
            Add-VMOptions $vmFile.FullName
        }
    } else {
        Write-Debug "No .vmoptions file found for $productDirName, will create a default one"
        $defaultVMFile = Join-Path $productConfigDir "$objProductName.vmoptions"
        Add-VMOptions $defaultVMFile
    }

    # Handle jetbrains_client.vmoptions
    $clientVMFile = Join-Path $productConfigDir "jetbrains_client.vmoptions"
    if (Test-Path $clientVMFile) {
        Clear-VMOptions $clientVMFile
        Add-VMOptions $clientVMFile
    } else {
        Add-VMOptions $clientVMFile
    }

    New-License $objProductName $objProductCode $productDirName
}

# ============ Main Process =============
function Main {
    Clear-Host
    Show-ASCIIJB
    Write-Info "Welcome to JetBrains Activation Tool | CodeKey Run"
    Write-Warning "Script date: 2025-08-20"
    Write-Error "Note: The script will activate ALL products by default, regardless of previous activation status!!!"
    Write-Warning "Please ensure all software is closed, press Enter to continue..."
    Read-Host

    Read-LicenseInfo

    Write-Info "Processing, please wait..."

    # Check and install dependencies
    $missingDeps = Test-Dependencies
    Install-Dependencies $missingDeps

    if (-not (Test-Path $dir_config_jb)) {
        Write-Error "Directory not found: $dir_config_jb"
        exit 1
    }

    Write-Debug "Config directory: $dir_config_jb"

    New-WorkingDirectory
    Remove-EnvironmentVariables
    Get-Resources

    # Process all JetBrains products
    $productDirs = Get-ChildItem -Path $dir_cache_jb -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $productDirs) {
        Install-JetBrainsProduct $dir.FullName
    }

    Write-Info "All items processed!"
    Write-Info "License keys are shown above. Copy them and use for activation."
    Write-Info "Enjoy using JetBrains IDE!"
}

# Run main function
Main
