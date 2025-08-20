#!/bin/bash
#set -e

# ============ Platform Detection =============
detect_platform() {
    case "$(uname -s)" in
        Darwin)
            OS="macOS"
            SHA_TOOL="shasum"
            OPEN_CMD="open"
            DATE_PARSER="mac"
            FILE_VMOPTIONS=".vmoptions"
            ;;
        Linux)
            OS="Linux"
            SHA_TOOL="sha1sum"
            OPEN_CMD="xdg-open"
            DATE_PARSER="linux"
            FILE_VMOPTIONS="64.vmoptions"
            ;;
        *)
            OS="Unknown"
            SHA_TOOL="sha1sum"
            OPEN_CMD="xdg-open"
            DATE_PARSER="linux"
            FILE_VMOPTIONS=".vmoptions"
            ;;
    esac
}
# Auto detect platform
detect_platform
# ============ Configuration =============
DEBUG=false
ENABLE_COLOR=true

URL_BASE="https://ckey.run"
#URL_BASE="http://192.168.31.254:10768"
URL_DOWNLOAD="${URL_BASE}/ja-netfilter"
URL_LICENSE="${URL_BASE}/generateLicense/file"

# Get original user and home directory
if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ]; then
    ORIGINAL_USER="$SUDO_USER"
    USER_HOME="/home/${SUDO_USER}"
else
    ORIGINAL_USER="$(whoami)"
    USER_HOME="${HOME}"
fi

# macOS user path correction
if [[ "$OS" == "macOS" ]]; then
    USER_HOME="/Users/${ORIGINAL_USER}"
fi

# Working path
dir_work="${USER_HOME}/.jb_run"
dir_config="${dir_work}/config"
dir_plugins="${dir_work}/plugins"
dir_backups="${dir_work}/backups"
file_netfilter_jar="${dir_work}/ja-netfilter.jar"

# JetBrains directory
if [[ "$OS" == "macOS" ]]; then
    dir_cache_jb="${USER_HOME}/Library/Caches/JetBrains"
    dir_config_jb="${USER_HOME}/Library/Application Support/JetBrains"
else
    dir_cache_jb="${USER_HOME}/.cache/JetBrains"
    dir_config_jb="${USER_HOME}/.config/JetBrains"
fi

# Log color settings
if $ENABLE_COLOR; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    GRAY='\033[38;5;240m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    GRAY=''
    NC=''
fi

# Product list
PRODUCTS='[
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
]'

# ============ Utility Functions =============

# ============ Date Validation =============
check_and_install_deps() {
    local deps=("curl" "jq")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        info "All dependencies are already installed."
        return
    fi

    warning "Missing dependencies: ${missing[*]}, attempting to install automatically..."

    # First detect system type
    case "$(uname -s)" in
        Darwin)
          # Check if Homebrew exists
          if ! command -v brew &>/dev/null; then
              warning "macOS detected but Homebrew is not installed"
              read -p "Do you want to install Homebrew automatically? (y/n) " install_brew
              if [[ "$install_brew" =~ [yY] ]]; then
                  info "Installing Homebrew..."
                  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

                  # Auto configure environment variables
                  if [ -x "/opt/homebrew/bin/brew" ]; then  # Apple Silicon
                      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
                      source ~/.zshrc
                  elif [ -x "/usr/local/bin/brew" ]; then  # Intel
                      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
                      source ~/.zshrc
                  fi

                  # Verify again
                  if ! command -v brew &>/dev/null; then
                      error "Homebrew is still not available after installation, please manually restart terminal and try again"
                      exit 1
                  fi
              else
                  error "Homebrew must be installed to continue!"
                  exit 1
              fi
          fi

          # Install dependencies
          brew install "${missing[@]}"
          ;;
        Linux)
            # Linux system (original logic)
            if command -v apt-get &>/dev/null; then
                sudo apt update && sudo apt install -y "${missing[@]}"
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y "${missing[@]}"
            elif command -v yum &>/dev/null; then
                sudo yum install -y "${missing[@]}"
            elif command -v pacman &>/dev/null; then
                sudo pacman -Sy --noconfirm "${missing[@]}"
            else
                error "Unrecognized Linux distribution, please manually install dependencies: ${missing[*]}"
                exit 1
            fi
            ;;
        *)
            error "Unsupported operating system"
            exit 1
            ;;
    esac

    # Verify installation results
    for dep in "${missing[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            error "Installation failed: $dep"
            exit 1
        fi
    done

    success "All dependencies installed successfully!"
}

# ============ Parse Product =============
parse_product_from_json() {
    local index="$1"
    local name=$(echo "$PRODUCTS" | jq -r ".[$index].name")
    local code=$(echo "$PRODUCTS" | jq -r ".[$index].productCode")
    echo "$name|$code"
}

# ============ Logging Functions =============
log() {
    local level="$1"
    local message="$2"
    local color=""
case "$level" in
    "INFO")
        color="$NC"
        ;;
    "DEBUG")
        [[ "$DEBUG" == true ]] || return
        color="$GRAY"
        ;;
    "WARNING")
        color="$YELLOW"
        ;;
    "ERROR")
        color="$RED"
        ;;
    "SUCCESS")
        color="$GREEN"
        ;;
    *)
        color="$NC"
        ;;
esac
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')][$level] ${message}${NC}"
}

debug()   { log "DEBUG" "$1"; }
info()    { log "INFO" "$1"; }
warning() { log "WARNING" "$1"; }
error()   { log "ERROR" "$1"; }
success() { log "SUCCESS" "$1"; }

# ============ ASCII Art =============
show_ascii_jb() {
    cat <<'EOF'
JJJJJJ   EEEEEEE   TTTTTTTT  BBBBBBB    RRRRRR    AAAAAA    IIIIIIII  NNNN   NN   SSSSSS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NNNNN  NN  SS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN NNN NN   SS
   JJ    EEEEE        TT     BBBBBBB    RRRRRR    AAAAAA       II     NN  NNNNN    SSSSS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN   NNNN         SS
 JJ JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN    NNN          SS
  JJJJ    EEEEEEE      TT     BBBBBBB    RR   RR   AA  AA    IIIIIIII  NN    NNN    SSSSSS
EOF
}

# ============ Clean Environment Variables =============
# Clean up other tool leftovers
remove_env_other(){
  OS_NAME=$(uname -s)
  JB_PRODUCTS="idea clion phpstorm goland pycharm webstorm webide rider datagrip rubymine appcode dataspell gateway jetbrains_client jetbrainsclient"

  KDE_ENV_DIR="${USER_HOME}/.config/plasma-workspace/env"

  PROFILE_PATH="${USER_HOME}/.profile"
  ZSH_PROFILE_PATH="${USER_HOME}/.zshrc"
  PLIST_PATH="${USER_HOME}/Library/LaunchAgents/jetbrains.vmoptions.plist"

  if [ $OS_NAME = "Darwin" ]; then
    BASH_PROFILE_PATH="${USER_HOME}/.bash_profile"
  else
    BASH_PROFILE_PATH="${USER_HOME}/.bashrc"
  fi

  touch "${PROFILE_PATH}"
  touch "${BASH_PROFILE_PATH}"
  touch "${ZSH_PROFILE_PATH}"

  MY_VMOPTIONS_SHELL_NAME="jetbrains.vmoptions.sh"
  MY_VMOPTIONS_SHELL_FILE="${USER_HOME}/.${MY_VMOPTIONS_SHELL_NAME}"

  rm -rf "${MY_VMOPTIONS_SHELL_FILE}"

  if [ $OS_NAME = "Darwin" ]; then
    for PRD in $JB_PRODUCTS; do
      ENV_NAME=$(echo $PRD | tr '[a-z]' '[A-Z]')"_VM_OPTIONS"

      launchctl unsetenv "${ENV_NAME}"
    done

    rm -rf "${PLIST_PATH}"
    sed -i '' '/___MY_VMOPTIONS_SHELL_FILE="${HOME}\/\.jetbrains\.vmoptions\.sh"; if /d' "${PROFILE_PATH}" >/dev/null 2>&1
    sed -i '' '/___MY_VMOPTIONS_SHELL_FILE="${HOME}\/\.jetbrains\.vmoptions\.sh"; if /d' "${BASH_PROFILE_PATH}" >/dev/null 2>&1
    sed -i '' '/___MY_VMOPTIONS_SHELL_FILE="${HOME}\/\.jetbrains\.vmoptions\.sh"; if /d' "${ZSH_PROFILE_PATH}" >/dev/null 2>&1
  else
    sed -i '/___MY_VMOPTIONS_SHELL_FILE="${HOME}\/\.jetbrains\.vmoptions\.sh"; if /d' "${PROFILE_PATH}" >/dev/null 2>&1
    sed -i '/___MY_VMOPTIONS_SHELL_FILE="${HOME}\/\.jetbrains\.vmoptions\.sh"; if /d' "${BASH_PROFILE_PATH}" >/dev/null 2>&1
    sed -i '/___MY_VMOPTIONS_SHELL_FILE="${HOME}\/\.jetbrains\.vmoptions\.sh"; if /d' "${ZSH_PROFILE_PATH}" >/dev/null 2>&1
    rm -rf "${KDE_ENV_DIR}/${MY_VMOPTIONS_SHELL_NAME}"
  fi
  debug "Cleaned up third-party tool environment variables"
}
remove_env_item_vars() {
    local shell_files=(
        "${USER_HOME}/.bash_profile"
        "${USER_HOME}/.bashrc"
        "${USER_HOME}/.zshrc"
        "${USER_HOME}/.profile"
    )

    # Parse products
    local index=0
    local product_count=$(echo "$PRODUCTS" | jq length)

    # First filter out existing files
    local existing_files=()
    for file in "${shell_files[@]}"; do
        [ -f "$file" ] && existing_files+=("$file")
    done

    # If no existing files found, return directly
    [ ${#existing_files[@]} -eq 0 ] && {
        debug "No environment variable files found, skipping"
        return
    }

    # Environment variable backup directory
    local dir_date_backup="$dir_backups/$(date +%s)"
    for file in "${existing_files[@]}"; do
      # Check if file contains specified environment variables
        if [ ! -w "$file" ]; then
            warning "File $file is not writable, skipping modification" >&2
            continue
        fi

        # Backup environment variable file to dir_backups/timestamp
        if [ ! -d "$dir_date_backup" ]; then
            mkdir -p "$dir_date_backup"
        fi

        cp "$file" "${dir_date_backup}/_$(basename ${file})"
        debug "Backed up environment variable file: $file, $dir_date_backup,_$(basename ${file})"

        # Detect environment variable configuration file
        local index=0
        while [ $index -lt $product_count ]; do
            IFS='|' read -r name code <<< "$(parse_product_from_json "$index")"

            if [ -z "$name" ]; then
                break
            fi

            local upper_key="$(echo "${name}" | tr '[:lower:]' '[:upper:]')_VM_OPTIONS"
            # Check if file contains upper_key
            if grep -q "^${upper_key}" "$file"; then
                sed -i -E "/${upper_key}/d" "$file"
                debug "Removed environment variable: $file,$upper_key"
            fi
            ((index++))
        done
        source "$file"
    done
}

remove_env_vars() {
    info "Starting to clean JetBrains related environment variables"
    remove_env_item_vars
    # Remove other activation tool leftovers
    remove_env_other
}

# ============ Read User License Information =============
validate_date_format() {
    local input="$1"

    # First step: check if it matches yyyy-MM-dd format
    if [[ ! "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        warning "Please enter standard format: yyyy-MM-dd (e.g., 2099-12-31)"
        return 1
    fi

    # Second step: return original value (no need to call date to verify authenticity)
    echo "$input"
    return 0
}
read_license_info() {
    read -p "Custom license name (press Enter for default ckey.run): " license_name
    license_name=${license_name:-ckey.run}

    local default_expiry="2099-12-31"
    local expiry_input
    local valid=false

    while [ "$valid" == "false" ]; do
        read -p "Custom license expiry date (press Enter for $default_expiry, format yyyy-MM-dd): " expiry_input
        expiry_input=${expiry_input:-$default_expiry}
        debug  "Entered license date: $expiry_input"
        if expiry=$(validate_date_format "$expiry_input"); then
            expiry="$expiry"
            valid=true
        else
            warning "Invalid date format, please enter correct yyyy-MM-dd format (e.g., 2099-12-31)"
        fi
    done

    LICENSE_JSON=$(cat <<EOF
{
  "assigneeName": "",
  "expiryDate": "$expiry",
  "licenseName": "$license_name",
  "productCode": ""
}
EOF
)
}

# ============ Create Working Directory =============
do_create_work_dir() {
    if [[ "${dir_work}" == "/" || -z "${dir_work}" ]]; then
        error "Detected illegal path: ${dir_work}, please check configuration."
        exit 1
    fi

    if [ -d "${dir_work}" ]; then
        rm -rf "${dir_plugins}" "${dir_config}" "${file_netfilter_jar}" || {
            error "Files are in use, please close all JetBrains IDEs before trying again!"
            exit 1
        }
    fi
    mkdir -p "${dir_config}" "${dir_plugins}" "${dir_backups}" || {
         error "Failed to create working directory: ${dir_config} or ${dir_plugins} or ${dir_backups}"
         exit 1
     }
    debug "Created working directory: ${dir_work}"
}

# ============ Download Files =============
download_one_file() {
    local url="$1"
    local file_save_path="$2"
    debug "\rDownloading: ${url} -> ${file_save_path}"
    curl -s -o "${file_save_path}" "${url}"

    if [ $? -ne 0 ]; then
        error "\rDownload failed: ${url}"
        exit 1
    fi

    if [[ "$file_save_path" == *.jar ]]; then
        local sha1_hash
        if command -v $SHA_TOOL &>/dev/null; then
            sha1_hash=$($SHA_TOOL "$file_save_path" | awk '{print $1}')
        else
            warning "$SHA_TOOL tool not found, skipping SHA-1 verification"
            return
        fi
        debug "sha1: $sha1_hash"
    fi
}

progress_bar() {
    local current=$1
    local total=$2
    local bar_length=30
    local percent=$((current * 100 / total))
    local filled=$((percent * bar_length / 100))
    local bar="["
    bar+=$(printf '#%.0s' $(seq 1 $filled))
    bar+=$(printf '.%.0s' $(seq 1 $((bar_length - filled))))
    bar+="]"
    printf "\rConfiguring ja-netfilter... %d/%d %s %d%%" "$current" "$total" "$bar" "$percent"
}

do_download_resources() {
    local resources=(
        "${URL_DOWNLOAD}/ja-netfilter.jar|${file_netfilter_jar}"
        "${URL_DOWNLOAD}/config/dns.conf|${dir_config}/dns.conf"
        "${URL_DOWNLOAD}/config/native.conf|${dir_config}/native.conf"
        "${URL_DOWNLOAD}/config/power.conf|${dir_config}/power.conf"
        "${URL_DOWNLOAD}/config/url.conf|${dir_config}/url.conf"

        "${URL_DOWNLOAD}/plugins/dns.jar|${dir_plugins}/dns.jar"
        "${URL_DOWNLOAD}/plugins/native.jar|${dir_plugins}/native.jar"
        "${URL_DOWNLOAD}/plugins/power.jar|${dir_plugins}/power.jar"
        "${URL_DOWNLOAD}/plugins/url.jar|${dir_plugins}/url.jar"
        "${URL_DOWNLOAD}/plugins/hideme.jar|${dir_plugins}/hideme.jar"
        "${URL_DOWNLOAD}/plugins/privacy.jar|${dir_plugins}/privacy.jar"
    )

    local total_files=${#resources[@]}
    local count=0

    debug  "Source ja-netfilter project address: https://gitee.com/ja-netfilter/ja-netfilter/releases/tag/2022.2.0"
    debug  "To check if the downloaded .jar has been tampered with, please verify that the sha1 value matches the source project files"
    for item in "${resources[@]}"; do
        IFS='|' read -r url path <<< "$item"
        download_one_file "$url" "$path"
        ((count++))
        progress_bar "$count" "$total_files"
    done
    echo -e "\n"
}

# ============ Clean and Update .vmoptions Files =============
clean_vmoptions() {
    local file="$1"
    if [ ! -f "$file" ]; then
        debug "Clean vm: File does not exist, skipping cleanup: $file"
        return 0
    fi

    local temp_lines=()
    local keywords=(
        "-javaagent"
        "--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED"
        "--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED"
    )

    while IFS= read -r line; do
        local matched=false
        for keyword in "${keywords[@]}"; do
            [[ "$line" == *"$keyword"* ]] && matched=true && break
        done
        [[ "$matched" == false ]] && temp_lines+=("$line")
    done < "$file"

    printf "%s\n" "${temp_lines[@]}" > "$file"
    debug "Clean vm: $file"
}

append_vmoptions() {
    local file="$1"
    if [ ! -f "$file" ]; then
        touch "$file" || {
            error "Generate vm: Failed to create: $file"
            return
        }
    fi

    cat >> "$file" <<EOF
--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED
--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
-javaagent:${file_netfilter_jar}
EOF

    debug "Generate vm: $file"
}

# ============ Generate Activation Code =============
generate_license() {
    local obj_product_name="$1"
    local obj_product_code="$2"
    local dir_product_name="$3"
    local file_license="${dir_config_jb}/${dir_product_name}/${obj_product_name}.key"

    [ -f "$file_license" ] && rm -f "$file_license"

    local json_body=$(jq --arg code "$obj_product_code" '.productCode = $code' <<< "$LICENSE_JSON")
    debug "URL_LICENSE:$URL_LICENSE,params:$json_body,save_path:$file_license"
    curl -s -X POST "$URL_LICENSE" \
        -H "Content-Type: application/json" \
        -d "$json_body" \
        -o "$file_license" > /dev/null

    if [ $? -eq 0 ]; then
        success "${dir_product_name} activation successful!"
    else
        warning "${dir_product_name} requires manual license key input!"
    fi
}

# ============ Handle Single JetBrains Product =============
handle_jetbrains_dir() {
    local dir="$1"
    local dir_product_name=$(basename "$dir")
    local obj_product_name=""
    local obj_product_code=""

    for ((i = 0; i < $(echo "$PRODUCTS" | jq length); i++)); do
        IFS='|' read -r name code <<< "$(parse_product_from_json "$i")"
        local lowercase_dir=$(echo "${dir_product_name}" | tr '[:upper:]' '[:lower:]')
        if [[ "$lowercase_dir" == *"$name"* ]]; then
            obj_product_name="$name"
            obj_product_code="$code"
            break
        fi
    done

    [ -z "$obj_product_name" ] && return

    info "Processing: ${dir_product_name}"

    local file_home="${dir}/.home"
    [ -f "$file_home" ] || {
        warning ".home file not found for ${dir_product_name}"
        return
    }

    debug ".home path: $file_home"

    local install_path=$(cat "$file_home")
    [ -d "$install_path" ] || {
        warning "Installation path not found for ${dir_product_name}!"
        return
    }

    debug ".home content: $install_path"

    local dir_bin="${install_path}/bin"
    [ -d "$dir_bin" ] || {
        warning "Bin directory does not exist for ${dir_product_name}, please confirm if it's properly installed!"
        return
    }

    local dir_config_product="${dir_config_jb}/${dir_product_name}"

    # First find all .vmoptions files
    files=("${dir_config_product}"/*${FILE_VMOPTIONS})

    # Check if files were actually found
    if [[ -f "${files[0]}" ]]; then
      for file_vmoption in "${files[@]}"; do
        clean_vmoptions "$file_vmoption"
        append_vmoptions "$file_vmoption"
      done
    else
      debug "No .vmoptions file found for ${dir_product_name}, will create a default one"
      append_vmoptions "${dir_config_product}/${obj_product_name}${FILE_VMOPTIONS}"
    fi

    # Check if ${dir_config_product}/jetbrains_client.vmoptions exists, if not create a default one
   local file_jetbrains_client="${dir_config_product}/jetbrains_client.vmoptions"
    if [ ! -f "${file_jetbrains_client}" ]; then
        append_vmoptions "${file_jetbrains_client}"
        else
        clean_vmoptions "${file_jetbrains_client}"
        append_vmoptions "${file_jetbrains_client}"
    fi

    generate_license "$obj_product_name" "$obj_product_code" "$dir_product_name"
}

# ============ Main Process =============
main() {
    clear
    show_ascii_jb
    info "\rWelcome to JetBrains Activation Tool | CodeKey Run"
    warning "Script date: 2025-8-1 11:00:35"
    error "Note: By default, the script will activate all products, regardless of whether they have been activated before!!!"
    warning "Please ensure that the software to be activated is closed, press Enter to continue..."
    read -r

    read_license_info

    info "Processing, please wait patiently..."

    check_and_install_deps

    if [ ! -d "${dir_config_jb}" ]; then
        error "${dir_config_jb} directory not found"
        exit 1
    fi

    debug "Config directory: ${dir_config_jb}"

    do_create_work_dir

    remove_env_vars

    do_download_resources

    for dir in "${dir_cache_jb}"/*; do
        [ -d "$dir" ] && handle_jetbrains_dir "$dir"
    done

    info "All items processing completed, if you need activation codes, please visit the website to get them!"
    sleep 1
    $OPEN_CMD "$URL_BASE" &>/dev/null
}

main "$@"
# Delete self
rm -f "${BASH_SOURCE[0]}"
󰣇 ~ ❯  