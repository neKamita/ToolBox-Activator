# activator.ps1 - PowerShell script for JetBrains products activation on Windows
# Based on the original activator.sh with Windows adaptation

# ============ Platform Detection =============
function Detect-Platform {
    $global:OS = "Windows"
    $global:SHA_TOOL = "Get-FileHash"
    $global:OPEN_CMD = "start"
    $global:DATE_PARSER = "windows"
    $global:FILE_VMOPTIONS = "64.vmoptions"
    $global:POWERSHELL = $true
}

# Auto detect platform
Detect-Platform

# ============ Configuration =============
$global:DEBUG = $false
$global:ENABLE_COLOR = $true

$global:URL_BASE = "https://ckey.run"
# $global:URL_BASE = "http://192.168.31.254:10768"
$global:URL_DOWNLOAD = "$($global:URL_BASE)/ja-netfilter"
$global:URL_LICENSE = "$($global:URL_BASE)/generateLicense/file"

# Get original user and home directory
$global:ORIGINAL_USER = $env:USERNAME
$global:USER_HOME = $env:USERPROFILE

# Working path
$global:dir_work = Join-Path $global:USER_HOME ".jb_run"
$global:dir_config = Join-Path $global:dir_work "config"
$global:dir_plugins = Join-Path $global:dir_work "plugins"
$global:dir_backups = Join-Path $global:dir_work "backups"
$global:file_netfilter_jar = Join-Path $global:dir_work "ja-netfilter.jar"

# JetBrains directory
$global:dir_cache_jb = Join-Path $global:USER_HOME "AppData\Local\JetBrains"
$global:dir_config_jb = Join-Path $global:USER_HOME "AppData\Roaming\JetBrains"

# Log color settings
if ($global:ENABLE_COLOR) {
    $global:RED = "`e[0;31m"
    $global:GREEN = "`e[0;32m"
    $global:YELLOW = "`e[0;33m"
    $global:GRAY = "`e[38;5;240m"
    $global:NC = "`e[0m"  # No Color
} else {
    $global:RED = ""
    $global:GREEN = ""
    $global:YELLOW = ""
    $global:GRAY = ""
    $global:NC = ""
}

# Product list
$global:PRODUCTS = @'
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
'@

# ============ Logging Functions =============
function Write-Log {
    param (
        [string]$Level,
        [string]$Message
    )
    
    $color = ""
    switch ($Level) {
        "INFO" { $color = $global:NC }
        "DEBUG" { 
            if (-not $global:DEBUG) { return }
            $color = $global:GRAY 
        }
        "WARNING" { $color = $global:YELLOW }
        "ERROR" { $color = $global:RED }
        "SUCCESS" { $color = $global:GREEN }
        default { $color = $global:NC }
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "${color}[$timestamp][$Level] $Message${global:NC}"
}

function debug { Write-Log -Level "DEBUG" -Message $args[0] }
function info { Write-Log -Level "INFO" -Message $args[0] }
function warning { Write-Log -Level "WARNING" -Message $args[0] }
function error { Write-Log -Level "ERROR" -Message $args[0] }
function success { Write-Log -Level "SUCCESS" -Message $args[0] }

# ============ ASCII Art JetBrains =============
function Show-AsciiJB {
    @'
JJJJJJ   EEEEEEE   TTTTTTTT  BBBBBBB    RRRRRR    AAAAAA    IIIIIIII  NNNN   NN   SSSSSS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NNNNN  NN  SS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN NNN NN   SS
   JJ    EEEEE        TT     BBBBBBB    RRRRRR    AAAAAA       II     NN  NNNNN    SSSSS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN   NNNN         SS
 JJ JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN    NNN          SS
  JJJJ    EEEEEEE      TT     BBBBBBB    RR   RR   AA  AA    IIIIIIII  NN    NNN    SSSSSS
'@
}

# ============= Dependencies Functions =============
function Test-Dependencies {
    $deps = @("curl", "jq")
    $missing = @()
    
    foreach ($dep in $deps) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            $missing += $dep
        }
    }
    
    # Check clipboard (Windows has built-in support)
    # PowerShell has built-in commands for clipboard operations
    
    if ($missing.Count -eq 0) {
        info "All dependencies are already installed."
        return $true
    }
    
    warning "Missing dependencies: $($missing -join ', '), attempting to install automatically..."
    return $false
}

function Install-Dependencies {
    $deps = @("curl", "jq")
    $missing = @()
    
    foreach ($dep in $deps) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            $missing += $dep
        }
    }
    
    if ($missing.Count -eq 0) {
        return
    }
    
    warning "Missing dependencies: $($missing -join ', '), attempting to install automatically..."
    
    # Check for winget (Windows Package Manager)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        info "Using winget to install dependencies..."
        foreach ($dep in $missing) {
            try {
                winget install $dep -e --accept-package-agreements --accept-source-agreements
                info "Successfully installed: $dep"
            } catch {
                error "Failed to install $dep via winget"
            }
        }
    }
    # Alternative - Chocolatey
    elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        info "Using Chocolatey to install dependencies..."
        choco install $missing -y
    }
    # Alternative - Scoop
    elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        info "Using Scoop to install dependencies..."
        scoop install $missing
    } else {
        error "No package manager found. Please install dependencies manually: $($missing -join ', ')"
        exit 1
    }
    
    # Verify installation
    foreach ($dep in $missing) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            error "Installation failed: $dep"
            exit 1
        }
    }
    
    success "All dependencies installed successfully!"
}

# ============= Product Parsing Functions =============
function Get-ProductFromJson {
    param (
        [int]$Index
    )
    
    $products = $global:PRODUCTS | ConvertFrom-Json
    $product = $products[$Index]
    return "$($product.name)|$($product.productCode)"
}

# ============= Product Selection Functions =============
function Show-ProductMenu {
    $selected_products = @()
    $products = $global:PRODUCTS | ConvertFrom-Json
    $product_count = $products.Count
    
    Write-Host "Available JetBrains products:"
    Write-Host "--------------------------------"
    
    for ($i = 0; $i -lt $product_count; $i++) {
        $product_info = Get-ProductFromJson -Index $i
        $name, $code = $product_info.Split('|')
        Write-Host "$($i+1). $name"
    }
    
    Write-Host "--------------------------------"
    Write-Host "0. Select all products"
    Write-Host "--------------------------------"
    
    while ($true) {
        $selections = Read-Host "Enter product numbers (separated by spaces, or 0 for all)"
        
        # Validate input
        if ($selections -eq "0") {
            # Select all products
            for ($i = 0; $i -lt $product_count; $i++) {
                $selected_products += $i
            }
            break
        }
        
        # Parse individual selections
        $valid_selections = $true
        $selection_array = $selections.Split(' ') | Where-Object { $_.Trim() -ne "" }
        
        foreach ($selection in $selection_array) {
            if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $product_count) {
                $selected_products += [int]$selection -  1
            } else {
                Write-Host "Invalid selection: $selection. Please enter valid numbers."
                $valid_selections = $false
                break
            }
        }
        
        if ($valid_selections) {
            # Remove duplicates
            $selected_products = $selected_products | Sort-Object -Unique
            
            # Show selected products
            Write-Host "Selected products:"
            foreach ($index in $selected_products) {
                $product_info = Get-ProductFromJson -Index $index
                $name, $code = $product_info.Split('|')
                Write-Host "  - $name"
            }
            
            $confirm = Read-Host "Is this correct? (y/n)"
            if ($confirm -match '^[yY]$') {
                break
            } else {
                $selected_products = @()
            }
        }
    }
    
    return $selected_products
}

# ============= Date Validation Functions =============
function Test-DateFormat {
    param (
        [string]$Input
    )
    
    # Check if it matches yyyy-MM-dd format
    if ($Input -notmatch '^\d{4}-\d{2}-\d{2}$') {
        warning "Please enter standard format: yyyy-MM-dd (e.g., 2099-12-31)"
        return $false
    }
    
    # Additional date validation
    try {
        [datetime]::ParseExact($Input, 'yyyy-MM-dd', $null) | Out-Null
        return $true
    } catch {
        warning "Invalid date format, please enter correct yyyy-MM-dd format (e.g., 2099-12-31)"
        return $false
    }
}

# ============= License Information Reading Functions =============
function Read-LicenseInfo {
    $license_name = Read-Host "Custom license name (press Enter for default ckey.run)"
    $license_name = if ([string]::IsNullOrWhiteSpace($license_name)) { "ckey.run" } else { $license_name }
    
    $default_expiry = "2099-12-31"
    $expiry_input = Read-Host "Custom license expiry date (press Enter for $default_expiry, format yyyy-MM-dd)"
    $expiry_input = if ([string]::IsNullOrWhiteSpace($expiry_input)) { $default_expiry } else { $expiry_input }
    
    while (-not (Test-DateFormat -Input $expiry_input)) {
        $expiry_input = Read-Host "Custom license expiry date (press Enter for $default_expiry, format yyyy-MM-dd)"
        $expiry_input = if ([string]::IsNullOrWhiteSpace($expiry_input)) { $default_expiry } else { $expiry_input }
    }
    
    $global:LICENSE_JSON = @"
{
  "assigneeName": "",
  "expiryDate": "$expiry_input",
  "licenseName": "$license_name",
  "productCode": ""
}
"@
}

# ============= Working Directory Management Functions =============
function New-WorkDirectory {
    if ($global:dir_work -eq "/" -or [string]::IsNullOrWhiteSpace($global:dir_work)) {
        error "Detected illegal path: $($global:dir_work), please check configuration."
        exit 1
    }
    
    if (Test-Path $global:dir_work) {
        Remove-Item -Path $global:dir_plugins, $global:dir_config, $global:file_netfilter_jar -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $global:dir_plugins -or Test-Path $global:dir_config -or (Test-Path $global:file_netfilter_jar)) {
            error "Files are in use, please close all JetBrains IDEs before trying again!"
            exit 1
        }
    }
    
    New-Item -Path $global:dir_config, $global:dir_plugins, $global:dir_backups -ItemType Directory -Force | Out-Null
    debug "Created working directory: $($global:dir_work)"
}

# ============= File Download Functions =============
function Invoke-DownloadFile {
    param (
        [string]$Url,
        [string]$SavePath
    )
    
    debug "Downloading: $Url -> $SavePath"
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $SavePath -UseBasicParsing -ErrorAction Stop
    } catch {
        error "Download failed: $Url"
        exit 1
    }
    
    if ($SavePath.EndsWith('.jar')) {
        try {
            $sha1_hash = Get-FileHash -Path $SavePath -Algorithm SHA1 | Select-Object -ExpandProperty Hash
            debug "sha1: $sha1_hash"
        } catch {
            warning "SHA-1 tool not found, skipping SHA-1 verification"
        }
    }
}

function Show-ProgressBar {
    param (
        [int]$Current,
        [int]$Total
    )
    
    $bar_length = 30
    $percent = [math]::Round(($Current * 100 / $Total), 0)
    $filled = [math]::Round(($percent * $bar_length / 100), 0)
    $bar = "["
    
    for ($i = 0; $i -lt $filled; $i++) {
        $bar += "#"
    }
    
    for ($i = $filled; $i -lt $bar_length; $i++) {
        $bar += "."
    }
    
    $bar += "]"
    Write-Host -NoNewline "`rConfiguring ja-netfilter... $Current/$Total $bar $percent%"
}

function Invoke-DownloadResources {
    $resources = @(
        "$($global:URL_DOWNLOAD)/ja-netfilter.jar|$($global:file_netfilter_jar)"
        "$($global:URL_DOWNLOAD)/config/dns.conf|$($global:dir_config)/dns.conf"
        "$($global:URL_DOWNLOAD)/config/native.conf|$($global:dir_config)/native.conf"
        "$($global:URL_DOWNLOAD)/config/power.conf|$($global:dir_config)/power.conf"
        "$($global:URL_DOWNLOAD)/config/url.conf|$($global:dir_config)/url.conf"
        "$($global:URL_DOWNLOAD)/plugins/dns.jar|$($global:dir_plugins)/dns.jar"
        "$($global:URL_DOWNLOAD)/plugins/native.jar|$($global:dir_plugins)/native.jar"
        "$($global:URL_DOWNLOAD)/plugins/power.jar|$($global:dir_plugins)/power.jar"
        "$($global:URL_DOWNLOAD)/plugins/url.jar|$($global:dir_plugins)/url.jar"
        "$($global:URL_DOWNLOAD)/plugins/hideme.jar|$($global:dir_plugins)/hideme.jar"
        "$($global:URL_DOWNLOAD)/plugins/privacy.jar|$($global:dir_plugins)/privacy.jar"
    )
    
    $total_files = $resources.Count
    $count = 0
    
    debug "Source ja-netfilter project address: https://gitee.com/ja-netfilter/ja-netfilter/releases/tag/2022.2.0"
    debug "To check if the downloaded .jar has been tampered with, please verify that the sha1 value matches the source project files"
    
    foreach ($item in $resources) {
        $url, $path = $item.Split('|')
        Invoke-DownloadFile -Url $url -SavePath $path
        $count++
        Show-ProgressBar -Current $count -Total $total_files
    }
    
    Write-Host ""
}

# ============= .vmoptions File Functions =============
function Clear-VmOptions {
    param (
        [string]$File
    )
    
    if (-not (Test-Path $File)) {
        debug "Clean vm: File does not exist, skipping cleanup: $File"
        return
    }
    
    $keywords = @(
        "-javaagent"
        "--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED"
        "--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED"
    )
    
    $temp_lines = @()
    $content = Get-Content -Path $File
    
    foreach ($line in $content) {
        $matched = $false
        foreach ($keyword in $keywords) {
            if ($line -like "*$keyword*") {
                $matched = $true
                break
            }
        }
        
        if (-not $matched) {
            $temp_lines += $line
        }
    }
    
    $temp_lines | Set-Content -Path $File
    debug "Clean vm: $File"
}

function Add-VmOptions {
    param (
        [string]$File
    )
    
    if (-not (Test-Path $File)) {
        New-Item -Path $File -ItemType File -Force | Out-Null
        if (-not (Test-Path $File)) {
            error "Generate vm: Failed to create: $File"
            return
        }
    }
    
    Add-Content -Path $File @"
--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED
--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
-javaagent:$($global:file_netfilter_jar)
"@
    
    debug "Generate vm: $File"
}

# ============= Clipboard Functions =============
function Set-ClipboardText {
    param (
        [string]$Text
    )
    
    try {
        Set-Clipboard -Text $Text
        return $true
    } catch {
        return $false
    }
}

# ============= License Generation Functions =============
function New-License {
    param (
        [string]$ProductName,
        [string]$ProductCode,
        [string]$DirProductName
    )
    
    $file_license = Join-Path $global:dir_config_jb $DirProductName "$ProductName.key"
    
    if (Test-Path $file_license) {
        Remove-Item $file_license -Force
    }
    
    $json_body = $global:LICENSE_JSON | ConvertFrom-Json
    $json_body.productCode = $ProductCode
    $json_body = $json_body | ConvertTo-Json -Compress
    
    debug "URL_LICENSE:$($global:URL_LICENSE),params:$json_body,save_path:$file_license"
    
    try {
        Invoke-WebRequest -Uri $global:URL_LICENSE `
            -Method POST `
            -ContentType "application/json" `
            -Body $json_body `
            -OutFile $file_license `
            -UseBasicParsing `
            -ErrorAction Stop
        
        success "${DirProductName} activation successful!"
        
        # Read the generated license and copy to clipboard
        if (Test-Path $file_license) {
            $license_content = Get-Content -Path $file_license -Raw
            if (Set-ClipboardText -Text $license_content) {
                info "Activation code copied to clipboard for ${DirProductName}"
            } else {
                warning "Failed to copy activation code to clipboard for ${DirProductName}"
            }
        }
    } catch {
        warning "${DirProductName} requires manual license key input!"
    }
}

# ============= JetBrains Product Processing Functions =============
function Invoke-JetBrainsDirectory {
    param (
        [string]$Dir
    )
    
    $dir_product_name = Split-Path $Dir -Leaf
    $obj_product_name = ""
    $obj_product_code = ""
    
    $products = $global:PRODUCTS | ConvertFrom-Json
    foreach ($i in (0..($products.Count - 1))) {
        $product_info = Get-ProductFromJson -Index $i
        $name, $code = $product_info.Split('|')
        $lowercase_dir = $dir_product_name.ToLower()
        
        if ($lowercase_dir -like "*$name*") {
            $obj_product_name = $name
            $obj_product_code = $code
            break
        }
    }
    
    if ([string]::IsNullOrWhiteSpace($obj_product_name)) {
        return
    }
    
    info "Processing: ${dir_product_name}"
    
    $file_home = Join-Path $Dir ".home"
    if (-not (Test-Path $file_home)) {
        warning ".home file not found for ${dir_product_name}"
        return
    }
    
    debug ".home path: $file_home"
    
    $install_path = Get-Content -Path $file_home
    if (-not (Test-Path $install_path)) {
        warning "Installation path not found for ${dir_product_name}!"
        return
    }
    
    debug ".home content: $install_path"
    
    $dir_bin = Join-Path $install_path "bin"
    if (-not (Test-Path $dir_bin)) {
        warning "Bin directory does not exist for ${dir_product_name}, please confirm if it's properly installed!"
        return
    }
    
    $dir_config_product = Join-Path $global:dir_config_jb $dir_product_name
    
    # First find all .vmoptions files
    $vmoptions_files = Get-ChildItem -Path $dir_config_product -Filter "*$($global:FILE_VMOPTIONS)" -File
    
    # Check if files were actually found
    if ($vmoptions_files) {
        foreach ($file_vmoption in $vmoptions_files) {
            Clear-VmOptions -File $file_vmoption.FullName
            Add-VmOptions -File $file_vmoption.FullName
        }
    } else {
        debug "No .vmoptions file found for ${dir_product_name}, will create a default one"
        Add-VmOptions -File (Join-Path $dir_config_product "$($obj_product_name)$($global:FILE_VMOPTIONS)")
    }
    
    # Check if ${dir_config_product}/jetbrains_client.vmoptions exists, if not create a default one
    $file_jetbrains_client = Join-Path $dir_config_product "jetbrains_client.vmoptions"
    if (-not (Test-Path $file_jetbrains_client)) {
        Add-VmOptions -File $file_jetbrains_client
    } else {
        Clear-VmOptions -File $file_jetbrains_client
        Add-VmOptions -File $file_jetbrains_client
    }
    
    New-License -ProductName $obj_product_name -ProductCode $obj_product_code -DirProductName $dir_product_name
}

# ============= Main Function =============
function Invoke-Main {
    Clear-Host
    Show-AsciiJB
    info "`rWelcome to JetBrains Activation Tool | CodeKey Run"
    warning "Script date: 2025-8-1 11:00:35"
    error "Note: By default, the script will activate all products, regardless of whether they have been activated before!!!"
    warning "Please ensure that the software to be activated is closed, press Enter to continue..."
    Read-Host
    
    Read-LicenseInfo
    
    # Get product selection from user
    $choice = Read-Host "Do you want to activate all products or select specific ones? (all/select)"
    if ($choice -match '^[sS]$') {
        $selected_products = Show-ProductMenu
        if ($selected_products.Count -eq 0) {
            error "No products selected. Exiting."
            exit 1
        }
    } else {
        # Select all products
        $products = $global:PRODUCTS | ConvertFrom-Json
        $selected_products = 0..($products.Count - 1)
    }
    
    info "Processing, please wait patiently..."
    
    # Check and install dependencies
    if (-not (Test-Dependencies)) {
        Install-Dependencies
    }
    
    if (-not (Test-Path $global:dir_config_jb)) {
        error "${dir_config_jb} directory not found"
        exit 1
    }
    
    debug "Config directory: $($global:dir_config_jb)"
    
    New-WorkDirectory
    
    # Clean environment variables (adapted for Windows)
    Remove-EnvironmentVars
    
    Invoke-DownloadResources
    
    # Process selected products
    $activated_products = @()
    foreach ($product_index in $selected_products) {
        $product_info = Get-ProductFromJson -Index $product_index
        $product_name, $product_code = $product_info.Split('|')
        
        # Find and process the JetBrains directory for this product
        $jetbrains_dirs = Get-ChildItem -Path $global:dir_cache_jb -Directory
        foreach ($dir in $jetbrains_dirs) {
            $dir_product_name = $dir.Name
            $lowercase_dir = $dir_product_name.ToLower()
            
            if ($lowercase_dir -like "*$product_name*") {
                Invoke-JetBrainsDirectory -Dir $dir.FullName
                $activated_products += $dir_product_name
                break
            }
        }
    }
    
    if ($activated_products.Count -gt 0) {
        info "Activation completed for the following products:"
        foreach ($product in $activated_products) {
            info "  - $product"
        }
        info "Activation codes have been copied to clipboard for each product."
    } else {
        warning "No products were activated. Please check if JetBrains products are installed."
    }
    
    info "Activation process completed successfully!"
}

# ============= Environment Variable Cleanup Functions =============
function Remove-EnvironmentVars {
    info "Starting to clean JetBrains related environment variables"
    
    # Clean up product environment variables
    $shell_files = @(
        Join-Path $global:USER_HOME "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        Join-Path $global:USER_HOME "Documents\WindowsPowerShell\profile.ps1"
        Join-Path $global:USER_HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        Join-Path $global:USER_HOME "Documents\PowerShell\profile.ps1"
    )
    
    # Parse products
    $products = $global:PRODUCTS | ConvertFrom-Json
    $product_count = $products.Count
    
    # First filter out existing files
    $existing_files = @()
    foreach ($file in $shell_files) {
        if (Test-Path $file) {
            $existing_files += $file
        }
    }
    
    # If no existing files found, return directly
    if ($existing_files.Count -eq 0) {
        debug "No environment variable files found, skipping"
        return
    }
    
    # Environment variable backup directory
    $dir_date_backup = Join-Path $global:dir_backups (Get-Date -Format "yyyyMMddHHmmss")
    New-Item -Path $dir_date_backup -ItemType Directory -Force | Out-Null
    
    foreach ($file in $existing_files) {
        # Check if file contains specified environment variables
        if (-not (Test-Path $file -PathType Leaf)) {
            warning "File $file is not a file, skipping modification"
            continue
        }
        
        # Backup environment variable file
        Copy-Item -Path $file -Destination (Join-Path $dir_date_backup "_$(Split-Path $file -Leaf)") -Force
        
        debug "Backed up environment variable file: $file, $(Join-Path $dir_date_backup "_$(Split-Path $file -Leaf)")"
        
        # Detect environment variable configuration file
        for ($i = 0; $i -lt $product_count; $i++) {
            $product_info = Get-ProductFromJson -Index $i
            $name, $code = $product_info.Split('|')
            
            if ([string]::IsNullOrWhiteSpace($name)) {
                break
            }
            
            $upper_key = "$($name.ToUpper())_VM_OPTIONS"
            
            # Check if file contains upper_key
            $content = Get-Content -Path $file -Raw
            if ($content -match "^$upper_key") {
                $content = $content -replace "(?m)^$upper_key.*`r?`n?", ""
                $content | Set-Content -Path $file -NoNewline
                debug "Removed environment variable: $file,$upper_key"
            }
        }
    }
}

# ============= Execute Main Function =============
Invoke-Main

# Self-deletion is not supported in PowerShell as it is in bash
# This is more complex to implement on Windows, so it's omitted for security