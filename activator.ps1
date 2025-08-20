#Requires -Version 5.1

<#
.SYNOPSIS
    Скрипт для активации продуктов JetBrains на Windows

.DESCRIPTION
    Этот скрипт выполняет автоматическую активацию продуктов JetBrains с использованием ja-netfilter.
    Он обнаруживает установленные продукты, загружает необходимые ресурсы, обрабатывает .vmoptions файлы
    и генерирует лицензионные ключи.

.NOTES
    Имя файла:     activator.ps1
    Автор:          neKamita
    Версия:        1.0
    Создано:       $(Get-Date -Format "yyyy-MM-dd")
    Требования:    PowerShell 5.1+, Windows 10/11
#>

# ============ Определение платформы =============
function Detect-Platform {
    <#
    .SYNOPSIS
        Определяет платформу и настраивает переменные окружения
    #>
    
    # Windows - единственная поддерживаемая платформа
    $global:OS = "Windows"
    $global:SHA_TOOL = "Get-FileHash"
    $global:OPEN_CMD = "Start-Process"
    $global:DATE_PARSER = "windows"
    $global:FILE_VMOPTIONS = "64.vmoptions"
    
    Write-Debug "Платформа определена: $OS"
}

# Автоматическое определение платформы
Detect-Platform

# ============ Конфигурация =============
$global:DEBUG = $false
$global:ENABLE_COLOR = $true

# URL для загрузки ресурсов
$global:URL_BASE = "https://ckey.run"
$global:URL_DOWNLOAD = "${URL_BASE}/ja-netfilter"
$global:URL_LICENSE = "${URL_BASE}/generateLicense/file"

# Получение оригинального пользователя и домашней директории
function Get-UserAndHome {
    <#
    .SYNOPSIS
        Получает информацию о текущем пользователе и домашней директории
    #>
    
    if ([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) {
        # Запущен от имени SYSTEM
        $global:ORIGINAL_USER = "$env:USERNAME"
        $global:USER_HOME = "$env:USERPROFILE"
    } else {
        # Запущен обычным пользователем
        $global:ORIGINAL_USER = "$env:USERNAME"
        $global:USER_HOME = "$env:USERPROFILE"
    }
    
    Write-Debug "Пользователь: $ORIGINAL_USER, Домашняя директория: $USER_HOME"
}

Get-UserAndHome

# Рабочие пути для Windows
$global:dir_work = "${USER_HOME}\.jb_run"
$global:dir_config = "${dir_work}\config"
$global:dir_plugins = "${dir_work}\plugins"
$global:dir_backups = "${dir_work}\backups"
$global:file_netfilter_jar = "${dir_work}\ja-netfilter.jar"

# Директории JetBrains для Windows
$global:dir_cache_jb = "${USER_HOME}\.cache\JetBrains"
$global:dir_config_jb = "${USER_HOME}\.config\JetBrains"

# Настройки цветов для логирования
if ($ENABLE_COLOR) {
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

# Список продуктов JetBrains
$global:PRODUCTS = @(
    @{name="idea"; productCode="II,PCWMP,PSI"},
    @{name="clion"; productCode="CL,PSI,PCWMP"},
    @{name="phpstorm"; productCode="PS,PCWMP,PSI"},
    @{name="goland"; productCode="GO,PSI,PCWMP"},
    @{name="pycharm"; productCode="PC,PSI,PCWMP"},
    @{name="webstorm"; productCode="WS,PCWMP,PSI"},
    @{name="rider"; productCode="RD,PDB,PSI,PCWMP"},
    @{name="datagrip"; productCode="DB,PSI,PDB"},
    @{name="rubymine"; productCode="RM,PCWMP,PSI"},
    @{name="appcode"; productCode="AC,PCWMP,PSI"},
    @{name="dataspell"; productCode="DS,PSI,PDB,PCWMP"},
    @{name="dotmemory"; productCode="DM"},
    @{name="rustrover"; productCode="RR,PSI,PCWP"}
)

# ============ Вспомогательные функции =============
function Write-Log {
    <#
    .SYNOPSIS
        Записывает сообщение в лог с указанным уровнем
    .PARAMETER Level
        Уровень логирования (INFO, DEBUG, WARNING, ERROR, SUCCESS)
    .PARAMETER Message
        Сообщение для записи в лог
    #>
    param(
        [string]$Level,
        [string]$Message
    )
    
    $color = ""
    switch ($Level) {
        "INFO" { $color = $NC }
        "DEBUG" { 
            if (-not $DEBUG) { return }
            $color = $GRAY 
        }
        "WARNING" { $color = $YELLOW }
        "ERROR" { $color = $RED }
        "SUCCESS" { $color = $GREEN }
        default { $color = $NC }
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "${color}[$timestamp][$Level] $Message${NC}"
}

function Write-Debug { Write-Log -Level "DEBUG" -Message $args[0] }
function Write-Info { Write-Log -Level "INFO" -Message $args[0] }
function Write-Warning { Write-Log -Level "WARNING" -Message $args[0] }
function Write-Error { Write-Log -Level "ERROR" -Message $args[0] }
function Write-Success { Write-Log -Level "SUCCESS" -Message $args[0] }

function Show-AsciiJB {
    <#
    .SYNOPSIS
        Отображает ASCII art логотип JetBrains
    #>
    
    @"
JJJJJJ   EEEEEEE   TTTTTTTT  BBBBBBB    RRRRRR    AAAAAA    IIIIIIII  NNNN   NN   SSSSSS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NNNNN  NN  SS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN NNN NN   SS
   JJ    EEEEE        TT     BBBBBBB    RRRRRR    AAAAAA       II     NN  NNNNN    SSSSS
   JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN   NNNN         SS
 JJ JJ    EE           TT     BB    BB   RR   RR   AA  AA       II     NN    NNN          SS
  JJJJ    EEEEEEE      TT     BBBBBBB    RR   RR   AA  AA    IIIIIIII  NN    NNN    SSSSSS
"@
}

# ============ Проверка и установка зависимостей =============
function Test-CommandExists {
    <#
    .SYNOPSIS
        Проверяет, существует ли команда
    .PARAMETER CommandName
        Имя команды для проверки
    #>
    param([string]$CommandName)
    $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Install-Dependencies {
    <#
    .SYNOPSIS
        Устанавливает необходимые зависимости (curl, jq)
    #>
    
    $dependencies = @("curl", "jq")
    $missing = @()
    
    foreach ($dep in $dependencies) {
        if (-not (Test-CommandExists $dep)) {
            $missing += $dep
        }
    }
    
    if ($missing.Count -eq 0) {
        Write-Info "Все зависимости уже установлены."
        return
    }
    
    Write-Warning "Отсутствующие зависимости: $($missing -join ', '), попытка автоматической установки..."
    
    # Сначала проверяем наличие winget
    if (Test-CommandExists "winget") {
        Write-Info "Используется winget для установки зависимостей..."
        foreach ($dep in $missing) {
            try {
                winget install --id $dep --accept-package-agreements --accept-source-agreements -s winget
                Write-Success "Успешно установлен: $dep"
            }
            catch {
                Write-Error "Ошибка установки $dep через winget: $_"
            }
        }
    }
    # Затем проверяем наличие Chocolatey
    elseif (Test-CommandExists "choco") {
        Write-Info "Используется Chocolatey для установки зависимостей..."
        foreach ($dep in $missing) {
            try {
                choco install $dep -y
                Write-Success "Успешно установлен: $dep"
            }
            catch {
                Write-Error "Ошибка установки $dep через Chocolatey: $_"
            }
        }
    }
    else {
        Write-Error "Не найден ни winget, ни Chocolatey. Пожалуйста, установите зависимости вручную: $($missing -join ', ')"
        exit 1
    }
    
    # Проверяем результат установки
    foreach ($dep in $missing) {
        if (-not (Test-CommandExists $dep)) {
            Write-Error "Установка не удалась: $dep"
            exit 1
        }
    }
    
    Write-Success "Все зависимости успешно установлены!"
}

# ============ Разбор продукта из JSON =============
function Get-ProductFromJson {
    <#
    .SYNOPSIS
        Возвращает информацию о продукте по индексу
    .PARAMETER Index
        Индекс продукта в списке
    #>
    param([int]$Index)
    
    if ($Index -ge 0 -and $Index -lt $PRODUCTS.Count) {
        $product = $PRODUCTS[$Index]
        "$($product.name)|$($product.productCode)"
    }
}

# ============ Очистка переменных окружения =============
function Remove-EnvVars {
    <#
    .SYNOPSIS
        Очищает переменные окружения, связанные с JetBrains
    #>
    
    Write-Info "Начало очистки переменных окружения JetBrains..."
    
    # Пути к файлам конфигурации оболочки
    $shellFiles = @(
        "${USER_HOME}\.bash_profile",
        "${USER_HOME}\.bashrc",
        "${USER_HOME}\.zshrc",
        "${USER_HOME}\.profile"
    )
    
    # Фильтруем существующие файлы
    $existingFiles = $shellFiles | Where-Object { Test-Path $_ }
    
    if ($existingFiles.Count -eq 0) {
        Write-Debug "Файлы конфигурации оболочки не найдены, пропуск"
        return
    }
    
    # Директория для резервного копирования
    $backupDir = "${dir_backups}\$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    foreach ($file in $existingFiles) {
        if (-not (Test-Path $file -PathType Leaf)) {
            Write-Warning "Файл $file не является файлом, пропуск"
            continue
        }
        
        if (-not (Test-Path $file -Writable)) {
            Write-Warning "Файл $file не доступен для записи, пропуск"
            continue
        }
        
        # Резервное копирование файла
        Copy-Item $file "${backupDir}\$(Split-Path $file -Leaf)"
        Write-Debug "Создана резервная копия: $file в $backupDir"
        
        # Обработка переменных окружения для каждого продукта
        for ($i = 0; $i -lt $PRODUCTS.Count; $i++) {
            $productInfo = Get-ProductFromJson $i
            if (-not $productInfo) { continue }
            
            $name, $code = $productInfo.Split('|')
            $upperKey = ($name.ToUpper() + "_VM_OPTIONS")
            
            # Проверяем и удаляем переменную окружения
            $content = Get-Content $file -Raw
            if ($content -match "^${upperKey}") {
                $content -replace "^${upperKey}.*`r?`n?", "" | Set-Content $file -NoNewline
                Write-Debug "Удалена переменная окружения: $file, $upperKey"
            }
        }
    }
    
    Write-Debug "Очистка переменных окружения других инструментов"
    
    # Дополнительно очищаем переменные окружения
    $jbProducts = @("idea", "clion", "phpstorm", "goland", "pycharm", "webstorm", "webide", 
                   "rider", "datagrip", "rubymine", "appcode", "dataspell", "gateway", 
                   "jetbrains_client", "jetbrainsclient")
    
    foreach ($prd in $jbProducts) {
        $envName = $prd.ToUpper() + "_VM_OPTIONS"
        [Environment]::SetEnvironmentVariable($envName, $null, "User")
    }
    
    Write-Debug "Очистка завершена"
}

# ============ Чтение информации о лицензии =============
function Test-DateFormat {
    <#
    .SYNOPSIS
        Проверяет формат даты
    .PARAMETER Input
        Входная дата для проверки
    #>
    param([string]$Input)
    
    # Проверяем соответствует ли формат yyyy-MM-dd
    if ($Input -notmatch "^\d{4}-\d{2}-\d{2}$") {
        Write-Warning "Пожалуйста, введите стандартный формат: yyyy-MM-dd (например: 2099-12-31)"
        return $false
    }
    
    return $true
}

function Read-LicenseInfo {
    <#
    .SYNOPSIS
        Читает информацию о лицензии от пользователя
    #>
    
    $licenseName = Read-Host "Пользовательское имя лицензии (нажмите Enter для значения по умолчанию: ckey.run)"
    $licenseName = if ([string]::IsNullOrWhiteSpace($licenseName)) { "ckey.run" } else { $licenseName }
    
    $defaultExpiry = "2099-12-31"
    $expiryInput = ""
    $valid = $false
    
    while (-not $valid) {
        $expiryInput = Read-Host "Пользовательская дата лицензии (нажмите Enter для $defaultExpiry, формат yyyy-MM-dd)"
        $expiryInput = if ([string]::IsNullOrWhiteSpace($expiryInput)) { $defaultExpiry } else { $expiryInput }
        
        Write-Debug "Введена дата лицензии: $expiryInput"
        
        if ((Test-DateFormat $expiryInput)) {
            $global:expiry = $expiryInput
            $valid = $true
        } else {
            Write-Warning "Неверный формат даты, пожалуйста, введите правильный формат yyyy-MM-dd (например: 2099-12-31)"
        }
    }
    
    $global:LICENSE_JSON = @"
{
  "assigneeName": "",
  "expiryDate": "$expiry",
  "licenseName": "$licenseName",
  "productCode": ""
}
"@
}

# ============ Создание рабочей директории =============
function New-WorkDirectory {
    <#
    .SYNOPSIS
        Создает рабочую директорию и необходимые поддиректории
    #>
    
    if ($dir_work -eq "\" -or [string]::IsNullOrWhiteSpace($dir_work)) {
        Write-Error "Обнаружен некорректный путь: $dir_work, пожалуйста, проверьте конфигурацию."
        exit 1
    }
    
    if (Test-Path $dir_work) {
        Remove-Item -Path "$dir_plugins", "$dir_config", "$file_netfilter_jar" -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $dir_plugins -or Test-Path $dir_config -or Test-Path $file_netfilter_jar) {
            Write-Error "Файлы используются, пожалуйста, закройте все IDE JetBrains перед повторной попыткой!"
            exit 1
        }
    }
    
    New-Item -ItemType Directory -Path $dir_config, $dir_plugins, $dir_backups -Force | Out-Null
    Write-Debug "Создана рабочая директория: $dir_work"
}

# ============ Загрузка файлов =============
function Get-DownloadProgress {
    <#
    .SYNOPSIS
        Отображает прогресс загрузки
    .PARAMETER Current
        Текущее значение прогресса
    .PARAMETER Total
        Общее значение прогресса
    #>
    param([int]$Current, [int]$Total)
    
    $barLength = 30
    $percent = [math]::Round(($Current * 100 / $Total), 0)
    $filled = [math]::Round(($percent * $barLength / 100), 0)
    $bar = "["
    $bar += '#' * $filled
    $bar += '.' * ($barLength - $filled)
    $bar += "]"
    
    Write-Host "`rКонфигурация ja-netfilter... $Current/$Total $bar $percent%" -NoNewline
}

function Invoke-DownloadFile {
    <#
    .SYNOPSIS
        Загружает один файл
    .PARAMETER Url
        URL для загрузки
    .PARAMETER SavePath
        Путь для сохранения файла
    #>
    param([string]$Url, [string]$SavePath)
    
    Write-Debug "`rЗагрузка: $Url -> $SavePath"
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $SavePath -UseBasicParsing -ErrorAction Stop
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "`rОшибка загрузки: $Url"
            exit 1
        }
        
        # Проверка SHA-1 для .jar файлов
        if ($SavePath.EndsWith(".jar")) {
            if (Test-CommandExists "Get-FileHash") {
                $hash = (Get-FileHash -Path $SavePath -Algorithm SHA1).Hash
                Write-Debug "sha1: $hash"
            } else {
                Write-Warning "Инструмент Get-FileHash не найден, проверка SHA-1 пропущена"
            }
        }
    }
    catch {
        Write-Error "`rОшибка загрузки: $Url - $_"
        exit 1
    }
}

function Get-DownloadResources {
    <#
    .SYNOPSIS
        Загружает все необходимые ресурсы
    #>
    
    $resources = @(
        "${URL_DOWNLOAD}/ja-netfilter.jar|$file_netfilter_jar",
        "${URL_DOWNLOAD}/config/dns.conf|${dir_config}\dns.conf",
        "${URL_DOWNLOAD}/config/native.conf|${dir_config}\native.conf",
        "${URL_DOWNLOAD}/config/power.conf|${dir_config}\power.conf",
        "${URL_DOWNLOAD}/config/url.conf|${dir_config}\url.conf",
        
        "${URL_DOWNLOAD}/plugins/dns.jar|${dir_plugins}\dns.jar",
        "${URL_DOWNLOAD}/plugins/native.jar|${dir_plugins}\native.jar",
        "${URL_DOWNLOAD}/plugins/power.jar|${dir_plugins}\power.jar",
        "${URL_DOWNLOAD}/plugins/url.jar|${dir_plugins}\url.jar",
        "${URL_DOWNLOAD}/plugins/hideme.jar|${dir_plugins}\hideme.jar",
        "${URL_DOWNLOAD}/plugins/privacy.jar|${dir_plugins}\privacy.jar"
    )
    
    $totalFiles = $resources.Count
    $count = 0
    
    Write-Debug "Адрес проекта ja-netfilter: https://gitee.com/ja-netfilter/ja-netfilter/releases/tag/2022.2.0"
    Write-Debug "Чтобы проверить, был ли загруженный .jar файл изменен, убедитесь, что значение sha1 соответствует файлу исходного проекта"
    
    foreach ($item in $resources) {
        $url, $path = $item.Split('|')
        Invoke-DownloadFile -Url $url -SavePath $path
        $count++
        Get-DownloadProgress -Current $count -Total $totalFiles
    }
    
    Write-Host ""
}

# ============ Обработка .vmoptions файлов =============
function Clean-VmOptions {
    <#
    .SYNOPSIS
        Очищает .vmoptions файл от старых записей
    .PARAMETER File
        Путь к .vmoptions файлу
    #>
    param([string]$File)
    
    if (-not (Test-Path $File)) {
        Write-Debug "Очистка vm: Файл не существует, пропуск очистки: $File"
        return 0
    }
    
    $keywords = @(
        "-javaagent",
        "--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED",
        "--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED"
    )
    
    $tempLines = @()
    $content = Get-Content $File -Raw
    
    $lines = $content -split "`r?`n"
    foreach ($line in $lines) {
        $matched = $false
        foreach ($keyword in $keywords) {
            if ($line -match [regex]::Escape($keyword)) {
                $matched = $true
                break
            }
        }
        if (-not $matched) {
            $tempLines += $line
        }
    }
    
    $tempLines | Set-Content $File -NoNewline
    Write-Debug "Очистка vm: $File"
}

function Add-VmOptions {
    <#
    .SYNOPSIS
        Добавляет необходимые параметры в .vmoptions файл
    .PARAMETER File
        Путь к .vmoptions файлу
    #>
    param([string]$File)
    
    if (-not (Test-Path $File)) {
        New-Item -Path $File -ItemType File -Force | Out-Null
        if (-not (Test-Path $File)) {
            Write-Error "Генерация vm: Не удалось создать: $File"
            return
        }
    }
    
    Add-Content -Path $File @"
--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED
--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
-javaagent:${file_netfilter_jar}
"@
    
    Write-Debug "Генерация vm: $File"
}

# ============ Генерация лицензионных ключей =============
function Get-LicenseKey {
    <#
    .SYNOPSIS
        Получает ключ активации для продукта
    .PARAMETER ProductName
        Имя продукта
    .PARAMETER ProductCode
        Код продукта
    .PARAMETER DirName
        Имя директории продукта
    #>
    param([string]$ProductName, [string]$ProductCode, [string]$DirName)
    
    Write-Debug "Получение кода активации для $DirName..."
    
    try {
        # Формируем данные запроса
        $jsonBody = $LICENSE_JSON | ConvertFrom-Json
        $jsonBody.productCode = $ProductCode
        $jsonBody = $jsonBody | ConvertTo-Json -Compress
        
        # Отправляем запрос для получения кода активации
        $response = Invoke-WebRequest -Uri $URL_LICENSE -Method POST -ContentType "application/json" -Body $jsonBody -UseBasicParsing
        
        if ($response.StatusCode -eq 200 -and $response.Content) {
            # Пытаемся разобрать JSON ответ
            $responseJson = $response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            $licenseKey = $responseJson.licenseKey
            
            if ($licenseKey) {
                Write-Output $licenseKey
                return 0
            }
            
            # Если разбор JSON не удался, пытаемся извлечь код активации напрямую из текста
            # Код активации обычно представляет собой строку символов, может содержать буквы, цифры и символы
            $extractedKey = [regex]::Matches($response.Content, '[A-Za-z0-9\-]{20,}').Value | Select-Object -First 1
            if ($extractedKey) {
                Write-Output $extractedKey
                return 0
            }
        }
    }
    catch {
        Write-Debug "Ошибка при получении кода активации для $DirName: $_"
    }
    
    Write-Debug "Не удалось получить код активации для $DirName"
    return 1
}

function Show-LicenseKey {
    <#
    .SYNOPSIS
        Отображает ключ активации
    .PARAMETER ProductName
        Имя продукта
    .PARAMETER LicenseKey
        Ключ активации
    #>
    param([string]$ProductName, [string]$LicenseKey)
    
    if ($LicenseKey) {
        Write-Host ""
        Write-Info "=== Код активации $ProductName ==="
        Write-Host "${GREEN}${LicenseKey}${NC}"
        Write-Host "================================="
        Write-Host ""
        
        # Пытаемся скопировать в буфер обмена (если поддерживается)
        try {
            Set-Clipboard -Value $LicenseKey -ErrorAction SilentlyContinue
            Write-Debug "Код активации скопирован в буфер обмена"
        }
        catch {
            Write-Debug "Не удалось скопировать код активации в буфер обмена"
        }
    } else {
        Write-Warning "Не удалось получить код активации для $ProductName"
    }
}

function New-License {
    <#
    .SYNOPSIS
        Генерирует файл лицензии для продукта
    .PARAMETER ProductName
        Имя продукта
    .PARAMETER ProductCode
        Код продукта
    .PARAMETER DirName
        Имя директории продукта
    #>
    param([string]$ProductName, [string]$ProductCode, [string]$DirName)
    
    $fileLicense = "${dir_config_jb}\${DirName}\${ProductName}.key"
    
    if (Test-Path $fileLicense) {
        Remove-Item $fileLicense -Force
    }
    
    $jsonBody = $LICENSE_JSON | ConvertFrom-Json
    $jsonBody.productCode = $ProductCode
    $jsonBody = $jsonBody | ConvertTo-Json -Compress
    
    Write-Debug "URL_LICENSE:$URL_LICENSE,params:$jsonBody,save_path:$fileLicense"
    
    try {
        Invoke-WebRequest -Uri $URL_LICENSE -Method POST -ContentType "application/json" -Body $jsonBody -OutFile $fileLicense -UseBasicParsing
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Активация $DirName успешна!"
        } else {
            Write-Warning "$DirName требует ручного ввода кода активации!"
        }
    }
    catch {
        Write-Warning "$DirName требует ручного ввода кода активации!"
    }
}

# ==== Обработка отдельного продукта JetBrains =============
function Invoke-JetbrainsDir {
    <#
    .SYNOPSIS
        Обрабатывает отдельную директорию JetBrains продукта
    .PARAMETER Dir
        Путь к директории продукта
    #>
    param([string]$Dir)
    
    $dirProductName = (Get-Item $Dir).Name
    $productName = ""
    $productCode = ""
    
    # Находим соответствующий продукт
    for ($i = 0; $i -lt $PRODUCTS.Count; $i++) {
        $productInfo = Get-ProductFromJson $i
        if (-not $productInfo) { continue }
        
        $name, $code = $productInfo.Split('|')
        $lowercaseDir = $dirProductName.ToLower()
        
        if ($lowercaseDir -match $name) {
            $productName = $name
            $productCode = $code
            break
        }
    }
    
    if (-not $productName) { return }
    
    Write-Info "Обработка: $dirProductName"
    
    $fileHome = "${Dir}\.home"
    if (-not (Test-Path $fileHome)) {
        Write-Warning "Файл .home не найден для $dirProductName"
        return
    }
    
    Write-Debug "Путь .home: $fileHome"
    
    $installPath = Get-Content $fileHome
    if (-not (Test-Path $installPath)) {
        Write-Warning "Путь установки не найден для $dirProductName!"
        return
    }
    
    Write-Debug "Содержимое .home: $installPath"
    
    $dirBin = "${installPath}\bin"
    if (-not (Test-Path $dirBin)) {
        Write-Warning "Директория bin не существует для $dirProductName, пожалуйста, подтвердите, что продукт правильно установлен!"
        return
    }
    
    $dirConfigProduct = "${dir_config_jb}\${dirProductName}"
    
    # Сначала находим все .vmoptions файлы
    $vmOptionsFiles = Get-ChildItem -Path $dirConfigProduct -Filter "*$FILE_VMOPTIONS" -File
    
    # Проверяем, были ли найдены файлы
    if ($vmOptionsFiles.Count -gt 0) {
        foreach ($fileVmoption in $vmOptionsFiles) {
            Clean-VmOptions -File $fileVmoption.FullName
            Add-VmOptions -File $fileVmoption.FullName
        }
    } else {
        Write-Debug "Файл .vmoptions не найден для $dirProductName, будет создан файл по умолчанию"
        Add-VmOptions -File "${dirConfigProduct}\${productName}${FILE_VMOPTIONS}"
    }
    
    # Проверяем, существует ли ${dirConfigProduct}\jetbrains_client.vmoptions, если нет, создаем по умолчанию
    $fileJetbrainsClient = "${dirConfigProduct}\jetbrains_client.vmoptions"
    if (-not (Test-Path $fileJetbrainsClient)) {
        Add-VmOptions -File $fileJetbrainsClient
    } else {
        Clean-VmOptions -File $fileJetbrainsClient
        Add-VmOptions -File $fileJetbrainsClient
    }
    
    # Настраиваем продукт, код активации будет получен в конце
    New-License -ProductName $productName -ProductCode $productCode -DirName $dirProductName
}

# ==== Проверка установленного продукта =============
function Test-InstalledProduct {
    <#
    .SYNOPSIS
        Проверяет, установлен ли продукт
    .PARAMETER Dir
        Путь к директории продукта
    #>
    param([string]$Dir)
    
    $dirProductName = (Get-Item $Dir).Name
    $productName = ""
    $productCode = ""
    
    # Находим соответствующий продукт
    for ($i = 0; $i -lt $PRODUCTS.Count; $i++) {
        $productInfo = Get-ProductFromJson $i
        if (-not $productInfo) { continue }
        
        $name, $code = $productInfo.Split('|')
        $lowercaseDir = $dirProductName.ToLower()
        
        if ($lowercaseDir -match $name) {
            $productName = $name
            $productCode = $code
            break
        }
    }
    
    # Если соответствующий продукт не найден, возвращаем 1
    if (-not $productName) { return 1 }
    
    # Проверяем, действительно ли продукт установлен
    $fileHome = "${Dir}\.home"
    if (-not (Test-Path $fileHome)) {
        Write-Debug "Продукт $dirProductName не имеет файла .home, пропуск"
        return 1
    }
    
    $installPath = Get-Content $fileHome
    if (-not (Test-Path $installPath)) {
        Write-Debug "Путь установки для продукта $dirProductName не существует, пропуск"
        return 1
    }
    
    $dirBin = "${installPath}\bin"
    if (-not (Test-Path $dirBin)) {
        Write-Debug "Директория bin для продукта $dirProductName не существует, пропуск"
        return 1
    }
    
    # Возвращаем информацию о продукте
    Write-Output "${productName}|${productCode}|${dirProductName}|${Dir}"
    return 0
}

# ==== Получение списка всех установленных продуктов =============
function Get-InstalledProducts {
    <#
    .SYNOPSIS
        Получает список всех установленных продуктов JetBrains
    #>
    
    $installedProducts = @()
    
    if (-not (Test-Path $dir_cache_jb)) {
        Write-Warning "Директория кэша JetBrains не найдена: $dir_cache_jb"
        return 1
    }
    
    foreach ($dir in Get-ChildItem -Path $dir_cache_jb -Directory) {
        $productInfo = Test-InstalledProduct -Dir $dir.FullName
        if ($? -eq 0 -and $productInfo) {
            $installedProducts += $productInfo
        }
    }
    
    # Возвращаем список установленных продуктов
    if ($installedProducts.Count -gt 0) {
        $installedProducts
        return 0
    } else {
        Write-Warning "Продукты JetBrains не найдены"
        return 1
    }
}

# ==== Получение кодов активации только для установленных продуктов =============
function Get-LicensesForInstalledOnly {
    <#
    .SYNOPSIS
        Получает коды активации только для установленных продуктов
    #>
    
    Write-Info "Получение кодов активации для установленных продуктов..."
    
    $successCount = 0
    $totalCount = 0
    
    # Получаем список установленных продуктов
    $installedProductsList = Get-InstalledProducts
    if ($? -ne 0) {
        Write-Warning "Установленные продукты не найдены, невозможно получить коды активации"
        return 1
    }
    
    # Обрабатываем установленные продукты
    foreach ($productInfo in $installedProductsList) {
        if ($productInfo) {
            $productName, $productCode, $dirProductName, $dirPath = $productInfo.Split('|')
            $totalCount++
            
            # Получаем код активации
            $licenseKey = Get-LicenseKey -ProductName $productName -ProductCode $productCode -DirName $dirProductName
            if ($? -eq 0) {
                Show-LicenseKey -ProductName $dirProductName -LicenseKey $licenseKey
                $successCount++
            } else {
                Write-Warning "Не удалось получить код активации для $dirProductName"
            }
        }
    }
    
    Write-Info "Получение кодов активации для установленных продуктов завершено: $successCount/$totalCount продуктов успешно"
}

# ==== Получение всех кодов активации =============
function Get-AllLicenseKeys {
    <#
    .SYNOPSIS
        Получает коды активации для всех продуктов
    #>
    
    Write-Info "Получение кодов активации для всех продуктов..."
    
    $successCount = 0
    $totalCount = 0
    
    # Итерируемся по всем продуктам
    for ($i = 0; $i -lt $PRODUCTS.Count; $i++) {
        $productInfo = Get-ProductFromJson $i
        if (-not $productInfo) { continue }
        
        $name, $code = $productInfo.Split('|')
        $totalCount++
        
        # Получаем код активации
        $licenseKey = Get-LicenseKey -ProductName $name -ProductCode $code -DirName $name
        if ($? -eq 0) {
            Show-LicenseKey -ProductName $name -LicenseKey $licenseKey
            $successCount++
        } else {
            Write-Warning "Не удалось получить код активации для $name"
        }
    }
    
    Write-Info "Получение кодов активации завершено: $successCount/$totalCount продуктов успешно"
}

# ==== Основной процесс =============
function Invoke-Main {
    <#
    .SYNOPSIS
        Основная функция, объединяющая весь функционал
    #>
    
    Clear-Host
    Show-AsciiJB
    Write-Info "`rДобро пожаловать в Инструмент Активации JetBrains | CodeKey Run"
    Write-Warning "Дата скрипта: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Error "Примечание: При запуске этого скрипта по умолчанию будут активированы все продукты, независимо от того, были ли они ранее активированы!!!"
    Write-Warning "Убедитесь, что программное обеспечение для активации закрыто, нажмите Enter для продолжения..."
    Read-Host
    
    Read-LicenseInfo
    
    Write-Info "Обработка, пожалуйста, подождите..."
    
    Install-Dependencies
    
    if (-not (Test-Path $dir_config_jb)) {
        Write-Error "Директория конфигурации не найдена: $dir_config_jb"
        exit 1
    }
    
    Write-Debug "Директория конфигурации: $dir_config_jb"
    
    New-WorkDirectory
    
    Remove-EnvVars
    
    Get-DownloadResources
    
    foreach ($dir in Get-ChildItem -Path $dir_cache_jb -Directory) {
        Invoke-JetbrainsDir -Dir $dir.FullName
    }
    
    Write-Info "Обработка всех элементов завершена, автоматическое получение кодов активации..."
    Get-LicensesForInstalledOnly
}

# Запуск основной функции
Invoke-Main