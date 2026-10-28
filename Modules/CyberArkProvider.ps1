function Get-CyberArkSettings {

    $settings = $null

    try{
        $settings = Get-JsonFile "settings.json"
    }
    catch{
        $settings = $null
    }

    $default = [PSCustomObject]@{
        enabled = $false
        baseUrl = ""
        loginUrl = ""
        username = ""
        password = ""
        appId = ""
        safe = ""
        accountNameTemplate = "{user}"
        allowManualFallback = $true
        authType = "Password"
        interactiveLogin = $true
        safeByEnvironment = [PSCustomObject]@{
            DEV = "LATAM_TR_PPA_A0836618"
            QC = "LATAM_EXTQC_PPA_A0836618"
            PROD = "LATAM_UNTR_PPA_A0836618"
        }
    }

    if($null -eq $settings){
        return $default
    }

    $cyberArk = $null

    if($settings.PSObject.Properties.Name -contains "cyberArk"){
        $cyberArk = $settings.cyberArk
    }
    elseif($settings.PSObject.Properties.Name -contains "CyberArk"){
        $cyberArk = $settings.CyberArk
    }
    else{
        $cyberArk = [PSCustomObject]@{}
    }

    if($null -eq $cyberArk){
        $cyberArk = [PSCustomObject]@{}
    }

    foreach($propertyName in @(
        "enabled",
        "baseUrl",
        "loginUrl",
        "username",
        "password",
        "appId",
        "safe",
        "accountNameTemplate",
        "allowManualFallback",
        "authType",
        "interactiveLogin",
        "safeByEnvironment"
    )){

        if($cyberArk.PSObject.Properties.Name -contains $propertyName){
            $default.$propertyName = $cyberArk.$propertyName
        }

    }

    foreach($propertyName in @(
        "CyberArkEnabled",
        "CyberArkBaseUrl",
        "CyberArkUsername",
        "CyberArkPassword",
        "CyberArkAppId",
        "CyberArkSafe"
    )){

        if($settings.PSObject.Properties.Name -contains $propertyName){
            $settingValue = $settings.$propertyName
            switch($propertyName){
                "CyberArkEnabled" { $default.enabled = [bool]$settingValue }
                "CyberArkBaseUrl" { $default.baseUrl = [string]$settingValue }
                "CyberArkUsername" { $default.username = [string]$settingValue }
                "CyberArkPassword" { $default.password = [string]$settingValue }
                "CyberArkAppId" { $default.appId = [string]$settingValue }
                "CyberArkSafe" { $default.safe = [string]$settingValue }
            }
        }

    }

    return $default

}

function Get-CyberArkInteractiveLoginUrl {

    $settings = Get-CyberArkSettings

    if($null -eq $settings){
        return $null
    }

    if(-not [string]::IsNullOrWhiteSpace([string]$settings.loginUrl)){
        return [string]$settings.loginUrl
    }

    if(-not [string]::IsNullOrWhiteSpace([string]$settings.baseUrl)){
        return "{0}/privilegecloud/Accounts" -f $settings.baseUrl.TrimEnd("/")
    }

    return $null

}

function Test-CyberArkIntegrationEnabled {

    $settings = Get-CyberArkSettings

    if($null -eq $settings){
        return $false
    }

    if(-not [bool]$settings.enabled){
        return $false
    }

    return -not [string]::IsNullOrWhiteSpace([string]$settings.baseUrl) -or
        -not [string]::IsNullOrWhiteSpace([string]$settings.loginUrl)

}

function Get-CyberArkAccountName {

    param(
        [string]$Environment,
        [string]$User,
        [string]$Template = "{user}"
    )

    $accountName = if([string]::IsNullOrWhiteSpace($Template)){
        "{user}"
    }
    else{
        $Template
    }

    return $accountName
        .Replace("{environment}", $Environment)
        .Replace("{user}", $User)
        .Replace("{Environment}", $Environment)
        .Replace("{User}", $User)

}

function Test-CyberArkHtmlLoginPage {

    param($Payload)

    if($null -eq $Payload){
        return $false
    }

    $text = [string]$Payload
    if([string]::IsNullOrWhiteSpace($text)){
        return $false
    }

    $trimmed = $text.Trim()

    return $trimmed -match '(?is)^(?:\s*<!DOCTYPE\s+html|\s*<html\b|\s*<body\b|.*Idira\s+Identity\s+Login.*)$'

}

function Get-CyberArkSecretValue {

    param($Payload)

    if($null -eq $Payload){
        return $null
    }

    if($Payload -is [string]){
        $trimmed = $Payload.Trim()
        if([string]::IsNullOrWhiteSpace($trimmed)){
            return $null
        }

        if(Test-CyberArkHtmlLoginPage -Payload $trimmed){
            return $null
        }

        return $trimmed
    }

    foreach($propertyName in @(
        "Password",
        "password",
        "secret",
        "Secret",
        "secretValue",
        "SecretValue",
        "value",
        "Value",
        "content",
        "Content"
    )){

        if($Payload -is [System.Collections.IDictionary]){
            if($Payload.Contains($propertyName)){
                $value = $Payload[$propertyName]
                if(-not [string]::IsNullOrWhiteSpace([string]$value)){
                    return [string]$value
                }
            }
        }

        if($Payload.PSObject.Properties.Name -contains $propertyName){
            $value = $Payload.$propertyName
            if(-not [string]::IsNullOrWhiteSpace([string]$value)){
                return [string]$value
            }
        }

    }

    if($Payload -is [System.Collections.IEnumerable] -and -not ($Payload -is [string])){
        foreach($item in $Payload){
            $found = Get-CyberArkSecretValue -Payload $item
            if(-not [string]::IsNullOrWhiteSpace([string]$found)){
                return [string]$found
            }
        }
    }

    return $null

}

function Invoke-CyberArkRequest {

    param(
        [string]$Uri,
        [hashtable]$Headers = @{},
        [string]$Method = "GET",
        [object]$Body = $null
    )

    $requestParams = @{
        Uri = $Uri
        Method = $Method
        Headers = $Headers
        ErrorAction = "Stop"
    }

    if($null -ne $Body){
        $requestParams["Body"] = $Body
    }

    return Invoke-RestMethod @requestParams

}

function Get-CyberArkCredentialValue {

    param(
        [string]$Environment,
        [string]$User
    )

    $settings = Get-CyberArkSettings

    if(-not (Test-CyberArkIntegrationEnabled)){
        return $null
    }

    $hasServiceCredentials = -not [string]::IsNullOrWhiteSpace([string]$settings.username) -or
        -not [string]::IsNullOrWhiteSpace([string]$settings.password) -or
        -not [string]::IsNullOrWhiteSpace([string]$settings.appId)

    if(-not $hasServiceCredentials -and $settings.PSObject.Properties.Name -contains "interactiveLogin" -and [bool]$settings.interactiveLogin){
        $loginUrl = Get-CyberArkInteractiveLoginUrl
        if(-not [string]::IsNullOrWhiteSpace([string]$loginUrl)){
            if(-not (Get-Variable -Name "CyberArkInteractiveLoginOpened" -Scope Script -ErrorAction SilentlyContinue)){
                $script:CyberArkInteractiveLoginOpened = $false
            }

            if(-not $script:CyberArkInteractiveLoginOpened){
                try{
                    $script:CyberArkInteractiveLoginOpened = $true
                    Start-Process $loginUrl
                }
                catch{
                    $script:CyberArkInteractiveLoginOpened = $false
                }
            }
        }
        return $null
    }

    $baseUrl = $null
    if(-not [string]::IsNullOrWhiteSpace([string]$settings.baseUrl)){
        $baseUrl = $settings.baseUrl.TrimEnd("/")
    }
    elseif(-not [string]::IsNullOrWhiteSpace([string]$settings.loginUrl)){
        $baseUrl = $settings.loginUrl.TrimEnd("/")
    }

    if([string]::IsNullOrWhiteSpace([string]$baseUrl) -and -not [string]::IsNullOrWhiteSpace([string]$settings.loginUrl)){
        $baseUrl = $settings.loginUrl.TrimEnd("/")
    }

    if([string]::IsNullOrWhiteSpace([string]$baseUrl) -and -not [string]::IsNullOrWhiteSpace([string]$settings.baseUrl)){
        $baseUrl = $settings.baseUrl.TrimEnd("/")
    }

    if([string]::IsNullOrWhiteSpace([string]$baseUrl)){
        return $null
    }

    $safeName = $settings.safe
    if($settings.PSObject.Properties.Name -contains "safeByEnvironment"){
        if($settings.safeByEnvironment -and $settings.safeByEnvironment.PSObject.Properties.Name -contains $Environment){
            $safeName = $settings.safeByEnvironment.$Environment
        }
    }

    $accountName = Get-CyberArkAccountName -Environment $Environment -User $User -Template $settings.accountNameTemplate
    $headers = @{}

    if(-not [string]::IsNullOrWhiteSpace([string]$settings.username) -and -not [string]::IsNullOrWhiteSpace([string]$settings.password)){
        $pair = "{0}:{1}" -f $settings.username, $settings.password
        $encoded = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
        $headers["Authorization"] = "Basic $encoded"
    }

    $candidateUris = @(
        "$baseUrl/PasswordVault/api/Accounts?Safe=$([uri]::EscapeDataString([string]$safeName))&search=$([uri]::EscapeDataString($accountName))",
        "$baseUrl/PasswordVault/api/Accounts?Safe=$([uri]::EscapeDataString([string]$safeName))&search=$([uri]::EscapeDataString($User))",
        "$baseUrl/PasswordVault/api/Accounts/$([uri]::EscapeDataString($accountName))",
        "$baseUrl/PasswordVault/WebServices/PIMServices.svc/Accounts?Safe=$([uri]::EscapeDataString([string]$safeName))&search=$([uri]::EscapeDataString($accountName))",
        "$baseUrl/PasswordVault/WebServices/PIMServices.svc/Accounts?Safe=$([uri]::EscapeDataString([string]$safeName))&search=$([uri]::EscapeDataString($User))",
        "$baseUrl/PasswordVault/WebServices/PIMServices.svc/Accounts/$([uri]::EscapeDataString($accountName))",
        "$baseUrl/api/Accounts?Safe=$([uri]::EscapeDataString([string]$safeName))&search=$([uri]::EscapeDataString($accountName))",
        "$baseUrl/api/Accounts/$([uri]::EscapeDataString($accountName))"
    )

    foreach($candidateUri in $candidateUris){

        try{
            $response = Invoke-CyberArkRequest -Uri $candidateUri -Headers $headers -Method "GET"
            $secretValue = Get-CyberArkSecretValue -Payload $response

            if(-not [string]::IsNullOrWhiteSpace([string]$secretValue)){
                return $secretValue
            }

            if($response -is [string]){
                $trimmed = $response.Trim()
                if(-not [string]::IsNullOrWhiteSpace($trimmed)){
                    return $trimmed
                }
            }

            if($response -and $response.PSObject.Properties.Name -contains "value"){
                $value = $response.value
                if(-not [string]::IsNullOrWhiteSpace([string]$value)){
                    return [string]$value
                }
            }
        }
        catch{
            continue
        }

    }

    return $null

}
