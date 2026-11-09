$Global:ConfigFolder = Join-Path $PSScriptRoot "..\Config"
$Global:BackupFolder = Join-Path $PSScriptRoot "..\Backups"
$Global:LogFolder = Join-Path $PSScriptRoot "..\Logs"

function Initialize-LauncherConfiguration {

    # ===============================
    # FOLDERS
    # ===============================

    foreach($folder in @(
        $Global:ConfigFolder,
        $Global:BackupFolder,
        $Global:LogFolder
    )){

        if(!(Test-Path $folder)){

            New-Item `
                -ItemType Directory `
                -Path $folder `
                -Force | Out-Null

        }

    }

    # ===============================
    # environments.json
    # ===============================

    $environmentConfigFile =
        Join-Path $Global:ConfigFolder "environments.json"

    if(!(Test-Path $environmentConfigFile)){

        @() |
        ConvertTo-Json -Depth 20 |
        Set-Content `
            $environmentConfigFile `
            -Encoding UTF8

    }

    # ===============================
    # settings.json
    # ===============================

    $settingsFile =
        Join-Path $Global:ConfigFolder "settings.json"

    if(!(Test-Path $settingsFile)){

        @{
            selectedUser   = "demo-user"
            lastEnvironment = ""
            updateSource = ""
            cyberArk = @{
                enabled = $false
                baseUrl = ""
                username = ""
                password = ""
                appId = ""
                safe = ""
                accountNameTemplate = "{environment}-{user}"
                allowManualFallback = $true
                authType = "Password"
            }
        } |
        ConvertTo-Json -Depth 20 |
        Set-Content `
            $settingsFile `
            -Encoding UTF8

    }

    # ===============================
    # users.json
    # ===============================

    $usersFile =
        Join-Path $Global:ConfigFolder "users.json"

    if(!(Test-Path $usersFile)){

        @{
            defaultUser = "demo-user"
            users = @(
                "demo-user"
            )
        } |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            $usersFile `
            -Encoding UTF8

    }

    # ===============================
    # favorites.json
    # ===============================

    $favoritesFile =
        Join-Path $Global:ConfigFolder "favorites.json"

    if(!(Test-Path $favoritesFile)){

        @{
            favorites = @()
        } |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            $favoritesFile `
            -Encoding UTF8

    }

    # ===============================
    # applications.json
    # ===============================

    $applicationsFile =
        Join-Path $Global:ConfigFolder "applications.json"

    if(!(Test-Path $applicationsFile)){

        @{
            SSMS = ""
            VisualStudio = ""
            VSCode = ""
            ReportBuilder = ""
            LastScan = ""
        } |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            $applicationsFile `
            -Encoding UTF8

    }

    # ===============================
    # projects.json
    # ===============================

    $projectsFile =
        Join-Path $Global:ConfigFolder "projects.json"

    if(!(Test-Path $projectsFile)){

        @{
            projects = @()
        } |
        ConvertTo-Json -Depth 10 |
        Set-Content `
            $projectsFile `
            -Encoding UTF8

    }

    # ===============================
    # links.json
    # ===============================

    $linksFile =
        Join-Path $Global:ConfigFolder "links.json"

    if(!(Test-Path $linksFile)){

        @{
            links = @()
        } |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            $linksFile `
            -Encoding UTF8

    }

    # ===============================
    # launcher.log
    # ===============================

    $logFile =
        Join-Path $Global:LogFolder "launcher.log"

    if(!(Test-Path $logFile)){

        New-Item `
            -ItemType File `
            -Path $logFile `
            -Force | Out-Null

    }

    # ===============================
    # credentials.json
    # ===============================

    $credentialsFile =
        Join-Path $Global:ConfigFolder "credentials.json"

    if(!(Test-Path $credentialsFile)){

        @{
            credentials = @()
        } |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            $credentialsFile `
            -Encoding UTF8

    }

}

function Get-LauncherEnvironments {
    return Get-LauncherEnvironmentDefinitions
}

function Test-LauncherEnvironmentConfiguration {

    $file = Join-Path $Global:ConfigFolder "environments.json"

    if(!(Test-Path $file)){
        Initialize-LauncherConfiguration
    }

    try{
        $rawData = Get-Content -LiteralPath $file -Raw
    }
    catch{
        return [PSCustomObject]@{
            IsValid = $false
            Error = "Aún no se ha configurado el cliente. Debe definir al menos un ambiente en el archivo de configuración."
            Environments = @()
        }
    }

    if([string]::IsNullOrWhiteSpace($rawData)){
        return [PSCustomObject]@{
            IsValid = $false
            Error = "Aún no se ha configurado el cliente. Debe definir al menos un ambiente en el archivo de configuración."
            Environments = @()
        }
    }

    try{
        $jsonData = $rawData | ConvertFrom-Json
    }
    catch{
        return [PSCustomObject]@{
            IsValid = $false
            Error = "La configuración de ambientes es inválida o está corrupta. Revise el archivo environments.json."
            Environments = @()
        }
    }

    if($null -eq $jsonData){
        return [PSCustomObject]@{
            IsValid = $false
            Error = "La configuración de ambientes es inválida o está vacía. Revise el archivo environments.json."
            Environments = @()
        }
    }

    if($jsonData -is [System.Collections.IEnumerable] -and -not ($jsonData -is [string])){
        $items = @($jsonData)
    }
    elseif($jsonData.PSObject.Properties.Name -contains "environments"){
        $items = @($jsonData.environments)
    }
    else{
        $items = @($jsonData)
    }

    $normalized = @()
    foreach($item in @($items)){
        if($null -eq $item){
            continue
        }

        $name = [string]$item.name
        $domain = [string]$item.domain
        $safe = [string]$item.safe
        $color = [string]$item.color
        $isDefault = [bool]$item.default
        if($null -ne $item.PSObject.Properties["isDefault"]){
            $isDefault = [bool]$item.isDefault
        }

        if([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($domain) -or [string]::IsNullOrWhiteSpace($safe)){
            return [PSCustomObject]@{
                IsValid = $false
                Error = "La configuración de ambientes tiene una estructura inválida. Cada ambiente debe incluir nombre, dominio y safe."
                Environments = @()
            }
        }

        if(-not [string]::IsNullOrWhiteSpace($color)){
            try {
                [void][System.Drawing.ColorTranslator]::FromHtml($color)
            }
            catch {
                return [PSCustomObject]@{
                    IsValid = $false
                    Error = "La configuración de ambientes tiene un color inválido. Usa un valor hexadecimal como #FF6600."
                    Environments = @()
                }
            }
        }

        $normalized += [pscustomobject]@{
            name = $name
            domain = $domain
            safe = $safe
            color = $color
            default = $isDefault
        }
    }

    if($normalized.Count -eq 0){
        return [PSCustomObject]@{
            IsValid = $false
            Error = "Aún no se ha configurado el cliente. Debe definir al menos un ambiente en el archivo de configuración."
            Environments = @()
        }
    }

    return [PSCustomObject]@{
        IsValid = $true
        Error = $null
        Environments = $normalized
    }

}

function Get-LauncherEnvironmentDefinitions {

    $result = Test-LauncherEnvironmentConfiguration
    if(-not $result.IsValid){
        return @()
    }

    return @($result.Environments)

}

function Save-LauncherEnvironments {

    param(
        [object[]]$Environments
    )

    if($null -eq $Environments -or $Environments.Count -eq 0){
        throw "No se puede guardar una configuración vacía. Debe existir al menos un ambiente."
    }

    $normalized = @()
    foreach($item in @($Environments)){
        if($null -eq $item){
            continue
        }

        $name = [string]$item.name
        $domain = [string]$item.domain
        $safe = [string]$item.safe
        $color = [string]$item.color
        $isDefault = [bool]$item.default
        if($null -ne $item.PSObject.Properties["isDefault"]){
            $isDefault = [bool]$item.isDefault
        }

        if([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($domain) -or [string]::IsNullOrWhiteSpace($safe)){
            throw "La configuración de ambientes tiene una estructura inválida. Cada ambiente debe incluir nombre, dominio y safe."
        }

        if(-not [string]::IsNullOrWhiteSpace($color)){
            try {
                [void][System.Drawing.ColorTranslator]::FromHtml($color)
            }
            catch {
                throw "La configuración de ambientes tiene un color inválido. Usa un valor hexadecimal como #FF6600."
            }
        }

        $normalized += [pscustomobject]@{
            name = $name
            domain = $domain
            safe = $safe
            color = $color
            default = $isDefault
        }
    }

    if($normalized.Count -eq 0){
        throw "No se puede guardar una configuración vacía. Debe existir al menos un ambiente."
    }

    Save-JsonFile "environments.json" $normalized
    return $normalized

}

function Get-LauncherEnvironmentColor {

    param(
        [string]$Environment
    )

    $definition = Get-LauncherEnvironmentByName -Environment $Environment
    if($null -eq $definition){
        return $null
    }

    foreach($candidate in @($definition.color, $definition.themeColor, $definition.backgroundColor, $definition.hexColor)){
        if(-not [string]::IsNullOrWhiteSpace([string]$candidate)){
            try {
                return [System.Drawing.ColorTranslator]::FromHtml([string]$candidate)
            }
            catch {
                continue
            }
        }
    }

    return $null

}

function Get-LauncherEnvironmentByName {

    param(
        [string]$Environment
    )

    if([string]::IsNullOrWhiteSpace($Environment)){
        return $null
    }

    foreach($item in Get-LauncherEnvironmentDefinitions){
        if($item.name -ieq $Environment){
            return $item
        }
    }

    return $null

}

function Get-LauncherEnvironmentName {

    param(
        [string]$Environment
    )

    $definition = Get-LauncherEnvironmentByName -Environment $Environment
    if($null -ne $definition){
        return [string]$definition.name
    }

    return [string]$Environment

}

function Get-LauncherEnvironmentDomain {

    param(
        [string]$Environment
    )

    $definition = Get-LauncherEnvironmentByName -Environment $Environment
    if($null -ne $definition -and -not [string]::IsNullOrWhiteSpace([string]$definition.domain)){
        return [string]$definition.domain
    }

    return $null

}

function Get-LauncherEnvironmentSafe {

    param(
        [string]$Environment
    )

    $definition = Get-LauncherEnvironmentByName -Environment $Environment
    if($null -ne $definition -and -not [string]::IsNullOrWhiteSpace([string]$definition.safe)){
        return [string]$definition.safe
    }

    $settings = $null
    try{
        $settings = Get-JsonFile "settings.json"
    }
    catch{
        $settings = $null
    }

    if($null -ne $settings -and $settings.PSObject.Properties.Name -contains "cyberArk"){
        $cyberArk = $settings.cyberArk
        if($null -ne $cyberArk -and $cyberArk.PSObject.Properties.Name -contains "safeByEnvironment"){
            $safeMap = $cyberArk.safeByEnvironment
            if($null -ne $safeMap -and $safeMap.PSObject.Properties.Name -contains $Environment){
                return [string]$safeMap.$Environment
            }
        }
    }

    return $null

}

function Get-LauncherEnvironmentNames {

    $names = @()
    foreach($item in Get-LauncherEnvironmentDefinitions){
        if(-not [string]::IsNullOrWhiteSpace([string]$item.name)){
            $names += [string]$item.name
        }
    }

    return $names

}

function Open-LauncherEnvironmentConfiguration {

    $file = Join-Path $Global:ConfigFolder "environments.json"

    if(!(Test-Path $file)){
        $null = Get-LauncherEnvironmentDefinitions
    }

    if($IsWindows){
        Start-Process notepad.exe $file | Out-Null
    }
    else{
        Start-Process $file | Out-Null
    }

    return $file

}

function Ensure-LauncherSettingsShape {

    param(
        [Parameter(Mandatory = $true)]
        [object]$Settings
    )

    if($null -eq $Settings){
        $Settings = [pscustomobject]@{}
    }

    $defaultValues = @{
        selectedUser = "demo-user"
        lastEnvironment = ""
        updateSource = ""
    }

    foreach($property in $defaultValues.Keys){
        if($null -eq $Settings.PSObject.Properties[$property]){
            $Settings | Add-Member -Force -NotePropertyName $property -NotePropertyValue $defaultValues[$property]
        }
    }

    if($null -eq $Settings.PSObject.Properties["cyberArk"]){
        $Settings | Add-Member -Force -NotePropertyName "cyberArk" -NotePropertyValue ([pscustomobject]@{
            enabled = $false
            baseUrl = ""
            loginUrl = "https://example.cyberark.example/privilegecloud/Accounts"
            username = ""
            password = ""
            appId = ""
            safe = ""
            accountNameTemplate = "{environment}-{user}"
            allowManualFallback = $true
            authType = "Password"
            interactiveLogin = $true
        })
    }

    $cyberArk = $Settings.cyberArk
    if($null -eq $cyberArk){
        $cyberArk = [pscustomobject]@{}
        $Settings.cyberArk = $cyberArk
    }

    $cyberArkDefaults = @{
        enabled = $false
        baseUrl = ""
        loginUrl = "https://example.cyberark.example/privilegecloud/Accounts"
        username = ""
        password = ""
        appId = ""
        safe = ""
        accountNameTemplate = "{environment}-{user}"
        allowManualFallback = $true
        authType = "Password"
        interactiveLogin = $true
    }

    foreach($property in $cyberArkDefaults.Keys){
        if($null -eq $cyberArk.PSObject.Properties[$property]){
            $cyberArk | Add-Member -Force -NotePropertyName $property -NotePropertyValue $cyberArkDefaults[$property]
        }
    }

    return $Settings
}

function Get-JsonFile {

    param(
        [string]$FileName
    )

    $file =
        Join-Path `
            $Global:ConfigFolder `
            $FileName

    if(!(Test-Path $file)){

        Initialize-LauncherConfiguration

    }

    $data = Get-Content `
        $file `
        -Raw |
    ConvertFrom-Json

    if($FileName -eq "settings.json"){
        $normalized = Ensure-LauncherSettingsShape -Settings $data
        $normalized | ConvertTo-Json -Depth 20 | Set-Content $file -Encoding UTF8
        return $normalized
    }

    return $data

}

function Save-JsonFile {

    param(
        [string]$FileName,
        [object]$Data
    )

    $file =
        Join-Path `
            $Global:ConfigFolder `
            $FileName

    $Data |
        ConvertTo-Json -Depth 20 |
        Set-Content `
            $file `
            -Encoding UTF8

}

function Backup-Configuration {

    $timestamp =
        Get-Date `
            -Format "yyyyMMdd_HHmmss"

    $backupPath =
        Join-Path `
            $Global:BackupFolder `
            $timestamp

    New-Item `
        -ItemType Directory `
        -Path $backupPath `
        -Force | Out-Null

    Copy-Item `
        "$Global:ConfigFolder\*" `
        $backupPath `
        -Recurse `
        -Force

}

Initialize-LauncherConfiguration