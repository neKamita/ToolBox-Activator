#!/bin/bash
#set -e

# ============ 平台检测 =============
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
# 自动检测平台
detect_platform
# ============ 配置 =============
DEBUG=false
ENABLE_COLOR=true

URL_BASE="https://ckey.run"
#URL_BASE="http://192.168.31.254:10768"
URL_DOWNLOAD="${URL_BASE}/ja-netfilter"
URL_LICENSE="${URL_BASE}/generateLicense/file"

# 获取原始用户和家目录
if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ]; then
    ORIGINAL_USER="$SUDO_USER"
    USER_HOME="/home/${SUDO_USER}"
else
    ORIGINAL_USER="$(whoami)"
    USER_HOME="${HOME}"
fi

# macOS 用户路径修正
if [[ "$OS" == "macOS" ]]; then
    USER_HOME="/Users/${ORIGINAL_USER}"
fi

# 工作路径
dir_work="${USER_HOME}/.jb_run"
dir_config="${dir_work}/config"
dir_plugins="${dir_work}/plugins"
dir_backups="${dir_work}/backups"
file_netfilter_jar="${dir_work}/ja-netfilter.jar"

# JetBrains 目录
if [[ "$OS" == "macOS" ]]; then
    dir_cache_jb="${USER_HOME}/Library/Caches/JetBrains"
    dir_config_jb="${USER_HOME}/Library/Application Support/JetBrains"
else
    dir_cache_jb="${USER_HOME}/.cache/JetBrains"
    dir_config_jb="${USER_HOME}/.config/JetBrains"
fi

# 日志颜色设置
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

# 产品列表
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

# ============ 工具函数 =============

# ============ 日期验证 =============
check_and_install_deps() {
    local deps=("curl" "jq")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        info "所有依赖已安装。"
        return
    fi

    warning "缺少以下依赖：${missing[*]}，正在尝试自动安装..."

    # 先检测系统类型
    case "$(uname -s)" in
        Darwin)
          # 检测 Homebrew 是否存在
          if ! command -v brew &>/dev/null; then
              warning "检测到 macOS但未安装 Homebrew"
              read -p "是否要自动安装 Homebrew?(y/n) " install_brew
              if [[ "$install_brew" =~ [yY] ]]; then
                  info "正在安装 Homebrew..."
                  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

                  # 自动配置环境变量
                  if [ -x "/opt/homebrew/bin/brew" ]; then  # Apple Silicon
                      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
                      source ~/.zshrc
                  elif [ -x "/usr/local/bin/brew" ]; then  # Intel
                      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
                      source ~/.zshrc
                  fi

                  # 再次验证
                  if ! command -v brew &>/dev/null; then
                      error "Homebrew 安装后仍不可用，请手动重启终端后重试"
                      exit 1
                  fi
              else
                  error "必须安装 Homebrew 才能继续!"
                  exit 1
              fi
          fi

          # 安装依赖
          brew install "${missing[@]}"
          ;;
        Linux)
            # Linux 系统 (原逻辑)
            if command -v apt-get &>/dev/null; then
                sudo apt update && sudo apt install -y "${missing[@]}"
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y "${missing[@]}"
            elif command -v yum &>/dev/null; then
                sudo yum install -y "${missing[@]}"
            elif command -v pacman &>/dev/null; then
                sudo pacman -Sy --noconfirm "${missing[@]}"
            else
                error "无法识别的 Linux 发行版，请手动安装依赖：${missing[*]}"
                exit 1
            fi
            ;;
        *)
            error "不支持的操作系统"
            exit 1
            ;;
    esac

    # 验证安装结果
    for dep in "${missing[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            error "安装失败：$dep"
            exit 1
        fi
    done

    success "所有依赖已成功安装！"
}

# ============ 解析产品 =============
parse_product_from_json() {
    local index="$1"
    local name=$(echo "$PRODUCTS" | jq -r ".[$index].name")
    local code=$(echo "$PRODUCTS" | jq -r ".[$index].productCode")
    echo "$name|$code"
}

# ============ 日志函数 =============
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

# ============ 清理环境变量 =============
#清理其它工具产留
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
  debug "清理三方工具环境变量完成"
}
remove_env_item_vars() {
    local shell_files=(
        "${USER_HOME}/.bash_profile"
        "${USER_HOME}/.bashrc"
        "${USER_HOME}/.zshrc"
        "${USER_HOME}/.profile"
    )

    # 解析产品
    local index=0
    local product_count=$(echo "$PRODUCTS" | jq length)

    # 先过滤出实际存在的文件
    local existing_files=()
    for file in "${shell_files[@]}"; do
        [ -f "$file" ] && existing_files+=("$file")
    done

    # 如果没有存在的文件则直接返回
    [ ${#existing_files[@]} -eq 0 ] && {
        debug "未找到任何环境变量文件,跳过"
        return
    }

    # 环境变量备份目录
    local dir_date_backup="$dir_backups/$(date +%s)"
    for file in "${existing_files[@]}"; do
      # 判断文件中是否包含指定环境变量
        if [ ! -w "$file" ]; then
            warning "文件 $file 不可写，跳过修改" >&2
            continue
        fi

        # 备份环境变量文件到dir_backups/时间
        if [ ! -d "$dir_date_backup" ]; then
            mkdir -p "$dir_date_backup"
        fi

        cp "$file" "${dir_date_backup}/_$(basename ${file})"
        debug "备份环境变量文件: $file, $dir_date_backup,_$(basename ${file})"

        # 检测环境变量配置文件
        local index=0
        while [ $index -lt $product_count ]; do
            IFS='|' read -r name code <<< "$(parse_product_from_json "$index")"

            if [ -z "$name" ]; then
                break
            fi

            local upper_key="$(echo "${name}" | tr '[:lower:]' '[:upper:]')_VM_OPTIONS"
            # 判断file里面是否包含upper_key
            if grep -q "^${upper_key}" "$file"; then
                sed -i -E "/${upper_key}/d" "$file"
                debug "删除环境变量: $file,$upper_key"
            fi
            ((index++))
        done
        source "$file"
    done
}

remove_env_vars() {
    info "开始清理 JetBrains 相关环境变量"
    remove_env_item_vars
    # 删除其它激活工具残留
    remove_env_other
}

# ============ 用户输入授权信息 =============
validate_date_format() {
    local input="$1"

    # 第一步：检查是否符合 yyyy-MM-dd 格式
    if [[ ! "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        warning "请输入标准格式：yyyy-MM-dd（例如：2099-12-31）"
        return 1
    fi

    # 第二步：直接返回原值（无需调用 date 验证真实性）
    echo "$input"
    return 0
}
read_license_info() {
    read -p "自定义授权名称 (回车默认 ckey.run): " license_name
    license_name=${license_name:-ckey.run}

    local default_expiry="2099-12-31"
    local expiry_input
    local valid=false

    while [ "$valid" == "false" ]; do
        read -p "自定义授权日期 (回车默认 $default_expiry, 格式 yyyy-MM-dd): " expiry_input
        expiry_input=${expiry_input:-$default_expiry}
        debug  "输入的授权日期: $expiry_input"
        if expiry=$(validate_date_format "$expiry_input"); then
            expiry="$expiry"
            valid=true
        else
            warning "日期格式不合法，请输入正确的 yyyy-MM-dd 格式(例如：2099-12-31)"
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

# ============ 创建工作目录 =============
do_create_work_dir() {
    if [[ "${dir_work}" == "/" || -z "${dir_work}" ]]; then
        error "检测到非法路径: ${dir_work}，请检查配置。"
        exit 1
    fi

    if [ -d "${dir_work}" ]; then
        rm -rf "${dir_plugins}" "${dir_config}" "${file_netfilter_jar}" || {
            error "文件被占用，请先关闭所有Jetbrains IDE后再试！"
            exit 1
        }
    fi
    mkdir -p "${dir_config}" "${dir_plugins}" "${dir_backups}" || {
         error "创建工作目录失败: ${dir_config} 或 ${dir_plugins} 或 ${dir_backups}"
         exit 1
     }
    debug "创建工作目录: ${dir_work}"
}

# ============ 下载文件 =============
download_one_file() {
    local url="$1"
    local file_save_path="$2"
    debug "\r正在下载: ${url} -> ${file_save_path}"
    curl -s -o "${file_save_path}" "${url}"

    if [ $? -ne 0 ]; then
        error "\r下载失败: ${url}"
        exit 1
    fi

    if [[ "$file_save_path" == *.jar ]]; then
        local sha1_hash
        if command -v $SHA_TOOL &>/dev/null; then
            sha1_hash=$($SHA_TOOL "$file_save_path" | awk '{print $1}')
        else
            warning "未找到 $SHA_TOOL 工具，跳过 SHA-1 校验"
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
    printf "\r配置 ja-netfilter... %d/%d %s %d%%" "$current" "$total" "$bar" "$percent"
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

    debug  "源ja-netfilter项目地址: https://gitee.com/ja-netfilter/ja-netfilter/releases/tag/2022.2.0"
    debug  "如需检查下载的.jar是否被篡改请核对sha1的值是否与源项目文件一致"
    for item in "${resources[@]}"; do
        IFS='|' read -r url path <<< "$item"
        download_one_file "$url" "$path"
        ((count++))
        progress_bar "$count" "$total_files"
    done
    echo -e "\n"
}

# ============ 清理并更新 .vmoptions 文件 =============
clean_vmoptions() {
    local file="$1"
    if [ ! -f "$file" ]; then
        debug "清理vm: 文件不存在，跳过清理: $file"
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
    debug "清理vm: $file"
}

append_vmoptions() {
    local file="$1"
    if [ ! -f "$file" ]; then
        touch "$file" || {
            error "生成vm: 创建失败: $file"
            return
        }
    fi

    cat >> "$file" <<EOF
--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED
--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
-javaagent:${file_netfilter_jar}
EOF

    debug "生成vm: $file"
}

# ============ 生成激活码 =============
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
        success "${dir_product_name} 激活成功！"
    else
        warning "${dir_product_name} 需要手动输入激活码！"
    fi
}

# ============ 处理单个 Jetbrains 产品 =============
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

    info "处理: ${dir_product_name}"

    local file_home="${dir}/.home"
    [ -f "$file_home" ] || {
        warning "未找到 ${dir_product_name} 的 .home 文件"
        return
    }

    debug ".home路径: $file_home"

    local install_path=$(cat "$file_home")
    [ -d "$install_path" ] || {
        warning "未找到 ${dir_product_name} 的安装路径！"
        return
    }

    debug ".home内容: $install_path"

    local dir_bin="${install_path}/bin"
    [ -d "$dir_bin" ] || {
        warning "${dir_product_name} 的 bin 目录不存在，请确认是否正确安装！"
        return
    }

    local dir_config_product="${dir_config_jb}/${dir_product_name}"

    # 先查找所有 .vmoptions 文件
    files=("${dir_config_product}"/*${FILE_VMOPTIONS})

    # 判断是否真的找到了文件
    if [[ -f "${files[0]}" ]]; then
      for file_vmoption in "${files[@]}"; do
        clean_vmoptions "$file_vmoption"
        append_vmoptions "$file_vmoption"
      done
    else
      debug "未找到${dir_product_name} 的.vmoptions文件，将创建一个默认的"
      append_vmoptions "${dir_config_product}/${obj_product_name}${FILE_VMOPTIONS}"
    fi

    # 判断${dir_config_product}/jetbrains_client.vmoptions是否存在，如果不存在则创建一个默认的
   local file_jetbrains_client="${dir_config_product}/jetbrains_client.vmoptions"
    if [ ! -f "${file_jetbrains_client}" ]; then
        append_vmoptions "${file_jetbrains_client}"
        else
        clean_vmoptions "${file_jetbrains_client}"
        append_vmoptions "${file_jetbrains_client}"
    fi

    generate_license "$obj_product_name" "$obj_product_code" "$dir_product_name"
}

# ============ 主流程 =============
main() {
    clear
    show_ascii_jb
    info "\r欢迎使用 JetBrains 激活工具 | CodeKey Run"
    warning "脚本日期：2025-8-1 11:00:35"
    error "注意，执行脚本默认会将所有产品全部激活一遍，无论之前是否激活过！！！"
    warning "请确保激活的软件处于关闭状态，请按回车继续..."
    read -r

    read_license_info

    info "处理中，请耐心等待..."

    check_and_install_deps

    if [ ! -d "${dir_config_jb}" ]; then
        error "未找到${dir_config_jb}目录"
        exit 1
    fi

    debug "config目录：${dir_config_jb}"

    do_create_work_dir

    remove_env_vars

    do_download_resources

    for dir in "${dir_cache_jb}"/*; do
        [ -d "$dir" ] && handle_jetbrains_dir "$dir"
    done

    info "所有项处理结束，如需要激活码，请前往网站获取！"
    sleep 1
    $OPEN_CMD "$URL_BASE" &>/dev/null
}

main "$@"
# 删除自己
rm -f "${BASH_SOURCE[0]}"
󰣇 ~ ❯  
