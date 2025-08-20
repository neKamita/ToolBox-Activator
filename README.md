# JetBrains Activation Tool

A comprehensive activation tool for JetBrains IDEs using ja-netfilter. This tool automates the process of activating all JetBrains products including IntelliJ IDEA, PyCharm, WebStorm, GoLand, and many others.

## 🚀 Features

- **Multi-platform Support**: Works on Linux, macOS, and Windows
- **Automatic Detection**: Detects all installed JetBrains products automatically
- **Dependency Management**: Automatically installs required dependencies (curl, jq)
- **License Generation**: Generates activation codes for all supported products
- **Environment Cleanup**: Removes conflicting environment variables from other activation tools
- **Progress Tracking**: Real-time progress bars and colored output

## 📋 Supported Products

- IntelliJ IDEA
- CLion
- PhpStorm
- GoLand
- PyCharm
- WebStorm
- Rider
- DataGrip
- RubyMine
- AppCode
- DataSpell
- DotMemory
- RustRover

## 🔧 System Requirements

### Linux/macOS
- Bash shell
- curl
- jq
- Java (for JetBrains IDEs)
- Internet connection

### Windows
- Windows 10 or later
- PowerShell 5.1 or later
- Internet connection
- Administrator privileges (for dependency installation)

## 📦 Installation

1. **Clone or download** the repository
2. **Choose the appropriate script** for your operating system:
   - Linux/macOS: `activate.sh`
   - Windows: `activate.ps1`

## 🚀 Usage

### For Linux/macOS

1. **Open Terminal** and navigate to the script directory
2. **Make the script executable** (if needed):
   ```bash
   chmod +x activate.sh
   ```
3. **Run the script**:
   ```bash
   ./activate.sh
   ```
4. **Follow the on-screen instructions**:
   - Enter custom license name (or press Enter for default "ckey.run")
   - Enter custom expiry date (or press Enter for default "2099-12-31")
   - Press Enter to continue when prompted

### For Windows

1. **Open PowerShell as Administrator**
2. **Navigate to the script directory**:
   ```powershell
   cd "C:\Path\To\Script\Directory"
   ```
3. **Run the script**:
   ```powershell
   .\activate.ps1
   ```
4. **Follow the on-screen instructions**:
   - Enter custom license name (or press Enter for default "ckey.run")
   - Enter custom expiry date (or press Enter for default "2099-12-31")
   - Press Enter to continue when prompted

## ⚙️ How It Works

1. **Platform Detection**: Automatically detects your operating system
2. **Dependency Check**: Verifies and installs required tools (curl, jq)
3. **Environment Cleanup**: Removes conflicting environment variables
4. **Resource Download**: Downloads ja-netfilter JAR files and configuration
5. **VM Options Configuration**: Updates .vmoptions files for all JetBrains products
6. **License Generation**: Creates activation codes for each product
7. **Activation**: Applies the activation to all detected products

## 🔍 Script Process

The script will:
- ✅ Check for required dependencies and install if missing
- ✅ Create working directories in `~/.jb_run` (Linux/macOS) or `%USERPROFILE%\.jb_run` (Windows)
- ✅ Download necessary JAR files and configuration files
- ✅ Clean up existing environment variables
- ✅ Configure .vmoptions files for all installed JetBrains products
- ✅ Generate license keys for each product
- ✅ Display license keys for manual activation if needed

## 🎯 Important Notes

- **Close all JetBrains IDEs** before running the script
- **Administrator privileges may be required** on Windows
- **Internet connection is required** for downloading resources and generating licenses
- **The script will activate ALL detected products** regardless of previous activation status
- **License keys are displayed in the terminal** - copy them for manual activation if needed

## 🔧 Configuration

### Custom URLs (Optional)

You can modify the base URLs in the script if needed:

```bash
# For Linux/macOS (activate.sh)
URL_BASE="https://your-custom-url.com"

# For Windows (activate.ps1)
$URL_BASE = "https://your-custom-url.com"
```

### Debug Mode

Enable debug output by setting the DEBUG environment variable:

**Linux/macOS:**
```bash
DEBUG=true ./activate.sh
```

**Windows:**
```powershell
$env:DEBUG = "true"
.\activate.ps1
```

## 🛠️ Troubleshooting

### Common Issues

1. **Permission Denied**
   - **Linux/macOS**: Run with `sudo` or fix file permissions
   - **Windows**: Run PowerShell as Administrator

2. **Dependencies Not Found**
   - The script will attempt to install missing dependencies automatically
   - If installation fails, install manually:
     - Ubuntu/Debian: `sudo apt install curl jq`
     - CentOS/RHEL: `sudo yum install curl jq`
     - macOS: Install Homebrew, then `brew install curl jq`
     - Windows: Install via winget or Chocolatey

3. **Java Not Found**
   - Ensure Java is installed and JAVA_HOME is set
   - JetBrains IDEs require Java to run

4. **Network Issues**
   - Check internet connection
   - Verify firewall settings allow script access to required URLs
   - Consider using a VPN if access is restricted

5. **Activation Failed**
   - Ensure all JetBrains IDEs are closed during activation
   - Check if the product is properly installed
   - Verify that .home files exist in the installation directories

### Manual Verification

To verify the installation:

**Linux/macOS:**
```bash
# Check if ja-netfilter is working
find ~/.jb_run -name "*.jar" -type f

# Check .vmoptions files
find ~/.config/JetBrains -name "*.vmoptions" -exec grep -l "ja-netfilter" {} \;
```

**Windows:**
```powershell
# Check if ja-netfilter is working
Get-ChildItem -Path "$env:USERPROFILE\.jb_run" -Filter "*.jar" -Recurse

# Check .vmoptions files
Get-ChildItem -Path "$env:APPDATA\JetBrains" -Filter "*.vmoptions" -Recurse | Get-Content | Select-String "ja-netfilter"
```

## 📝 License Information

- This tool is provided for educational and testing purposes
- Users are responsible for complying with JetBrains software license agreements
- The tool uses ja-netfilter, an open-source project for Java agent-based activation

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 Disclaimer

This tool is not officially affiliated with JetBrains. Use at your own risk and ensure compliance with all applicable software license agreements.

## 🔗 Links

- [Original ja-netfilter Project](https://gitee.com/ja-netfilter/ja-netfilter)
- [JetBrains Official Website](https://www.jetbrains.com/)
- [CodeKey Run](https://ckey.run)

---

**Last Updated**: August 20, 2025
