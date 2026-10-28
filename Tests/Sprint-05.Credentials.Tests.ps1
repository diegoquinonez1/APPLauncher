. (Join-Path $PSScriptRoot "TestSupport.ps1")

Describe "Sprint 5: expiración y protección de credenciales" {

    BeforeEach {
        $script:testRoot = New-APPLauncherTestRoot
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\CredentialManager.ps1")
        $script:now = [datetime]::ParseExact(
            "2026-10-23T12:00:00",
            "yyyy-MM-ddTHH:mm:ss",
            [Globalization.CultureInfo]::InvariantCulture
        )
    }

    AfterEach {
        Remove-APPLauncherTestRoot $script:testRoot
    }

    It "Clasifica válida, próxima a expirar y expirada usando la vigencia de ocho horas" {
        $valid = [PSCustomObject]@{updatedAt=$script:now.AddHours(-2).ToString("s")}
        $soon = [PSCustomObject]@{updatedAt=$script:now.AddHours(-7).AddMinutes(-30).ToString("s")}
        $expired = [PSCustomObject]@{updatedAt=$script:now.AddHours(-8).ToString("s")}

        (Get-CredentialExpiryInfo $valid $script:now).Status | Should Be "Válida"
        (Get-CredentialExpiryInfo $soon $script:now).Status | Should Be "Próxima a expirar"
        (Get-CredentialExpiryInfo $expired $script:now).Status | Should Be "Expirada"
    }

    It "Considera expirada una fecha ausente o inválida" {
        (Get-CredentialExpiryInfo ([PSCustomObject]@{}) $script:now).Status | Should Be "Expirada"
        (Get-CredentialExpiryInfo ([PSCustomObject]@{updatedAt="not-a-date"}) $script:now).Status | Should Be "Expirada"
    }

    It "Guarda la contraseña con DPAPI y la recupera solo para el usuario actual" {
        $password = "Test-only-secret-123!"
        Save-LauncherCredential -Environment "DEV" -User "test-user" -Password $password

        $stored = (Get-Credentials).credentials[0]
        $stored.password.Contains($password) | Should Be $false
        [IO.File]::ReadAllText((Join-Path $Global:ConfigFolder "credentials.json")) | Should Match '"updatedAt"\s*:\s*"\d{4}-\d{2}-\d{2}T'
        (Get-LauncherCredential "DEV" "test-user").Password | Should Be $password
        (Get-LauncherCredentialStatus "DEV" "test-user").Status | Should Be "Válida"
    }

    It "Distingue credencial no configurada por usuario y entorno" {
        (Get-LauncherCredentialStatus "QC" "test-user").Status | Should Be "No configurada"
        (Get-LauncherCredentialStatus "DEV" "another-user").Status | Should Be "No configurada"
    }

    It "Elimina solo credenciales expiradas y mantiene el estado expirada en sesión" {
        $expired = [PSCustomObject]@{
            environment = "DEV"
            user = "test-user"
            password = Protect-Password "expired-test-secret"
            updatedAt = $script:now.AddHours(-9).ToString("s")
        }
        $valid = [PSCustomObject]@{
            environment = "QC"
            user = "test-user"
            password = Protect-Password "valid-test-secret"
            updatedAt = (Get-Date).AddHours(-1).ToString("s")
        }
        Save-Credentials ([PSCustomObject]@{credentials=@($expired, $valid)})

        (Remove-ExpiredLauncherCredentials) | Should Be 1
        @((Get-Credentials).credentials).Count | Should Be 1
        (Get-Credentials).credentials[0].environment | Should Be "QC"
        (Get-LauncherCredentialStatus "DEV" "test-user").Status | Should Be "Expirada"
        (Get-LauncherCredentialStatus "QC" "test-user").Status | Should Be "Válida"
        (Test-LauncherCredential "DEV" "test-user") | Should Be $false
    }

    It "Elimina una credencial expirada al intentar recuperarla" {
        $expired = [PSCustomObject]@{
            environment = "PROD"
            user = "test-user"
            password = Protect-Password "expired-test-secret"
            updatedAt = $script:now.AddHours(-10).ToString("s")
        }
        Save-Credentials ([PSCustomObject]@{credentials=@($expired)})

        (Get-LauncherCredential "PROD" "test-user") | Should Be $null
        @((Get-Credentials).credentials).Count | Should Be 0
        (Get-LauncherCredentialStatus "PROD" "test-user").Status | Should Be "Expirada"
    }

    It "No trata la página HTML de login como contraseña y abre el navegador solo una vez" {
        $html = @'
<!DOCTYPE html>
<html>
<head><title>Idira Identity Login</title></head>
<body>Login</body>
</html>
'@

        Remove-Variable -Name CyberArkInteractiveLoginOpened -Scope Script -Force -ErrorAction SilentlyContinue
        $script:BrowserOpenCount = 0
        function Global:Start-Process {
            param([string]$FilePath)
            $script:BrowserOpenCount++
        }

        $settings = [PSCustomObject]@{
            cyberArk = [PSCustomObject]@{
                enabled = $true
                baseUrl = $null
                loginUrl = "https://aon.cyberark.cloud/privilegecloud/Accounts"
                username = $null
                password = $null
                appId = $null
                interactiveLogin = $true
                allowManualFallback = $true
            }
        }

        Save-JsonFile "settings.json" $settings

        $null = Get-CyberArkCredentialValue -Environment "DEV" -User "adm-A0836618"
        $null = Get-CyberArkCredentialValue -Environment "DEV" -User "adm-A0836618"

        $script:BrowserOpenCount | Should Be 1

        Remove-Item Function:\Start-Process -Force -ErrorAction SilentlyContinue
    }

    It "Abre el navegador antes de reportar login interactivo cuando no hay credenciales de servicio" {
        Remove-Variable -Name CyberArkInteractiveLoginOpened -Scope Script -ErrorAction SilentlyContinue
        $script:BrowserOpenCount = 0
        function Global:Start-Process {
            param([string]$FilePath)
            $script:BrowserOpenCount++
        }

        $settings = [PSCustomObject]@{
            cyberArk = [PSCustomObject]@{
                enabled = $true
                baseUrl = $null
                loginUrl = "https://aon.cyberark.cloud/privilegecloud/Accounts"
                username = $null
                password = $null
                appId = $null
                interactiveLogin = $true
                allowManualFallback = $true
            }
        }
        Save-JsonFile "settings.json" $settings

        $status = Get-LauncherCredentialStatus "DEV" "adm-A0836618"

        $script:BrowserOpenCount | Should Be 1
        $status.Status | Should Match "login interactivo|CyberArk|manual"

        Remove-Item Function:\Start-Process -Force -ErrorAction SilentlyContinue
    }

    It "Expone un estado explícito cuando CyberArk requiere login interactivo y no devuelve contraseña" {
        $settings = [PSCustomObject]@{
            cyberArk = [PSCustomObject]@{
                enabled = $true
                baseUrl = $null
                loginUrl = "https://aon.cyberark.cloud/privilegecloud/Accounts"
                username = $null
                password = $null
                appId = $null
                interactiveLogin = $true
                allowManualFallback = $true
            }
        }
        Save-JsonFile "settings.json" $settings

        $status = Get-LauncherCredentialStatus "DEV" "adm-A0836618"
        $status.Status | Should Match "login interactivo|CyberArk|manual"
        (Test-LauncherCredential "DEV" "adm-A0836618") | Should Be $false
        (Get-LauncherCredential "DEV" "adm-A0836618") | Should Be $null
    }

    It "Usa la credencial manual guardada aunque CyberArk esté habilitado con login interactivo" {
        $settings = [PSCustomObject]@{
            selectedUser = "adm-A0836618"
            lastEnvironment = "DEV"
            cyberArk = [PSCustomObject]@{
                enabled = $true
                baseUrl = $null
                loginUrl = "https://aon.cyberark.cloud/privilegecloud/Accounts"
                username = $null
                password = $null
                appId = $null
                interactiveLogin = $true
                allowManualFallback = $true
            }
        }
        Save-JsonFile "settings.json" $settings

        $manual = [PSCustomObject]@{
            environment = "DEV"
            user = "adm-A0836618"
            password = Protect-Password "manual-secret-123"
            updatedAt = (Get-Date).AddHours(-1).ToString("s")
        }
        Save-Credentials ([PSCustomObject]@{credentials=@($manual)})

        $status = Get-LauncherCredentialStatus "DEV" "adm-A0836618"
        $status.Status | Should Be "Válida"
        (Get-LauncherCredential "DEV" "adm-A0836618").Password | Should Be "manual-secret-123"
        (Test-LauncherCredential "DEV" "adm-A0836618") | Should Be $true
    }

    It "Normaliza settings.json cuando falta selectedUser o lastEnvironment" {
        $settings = [PSCustomObject]@{
            cyberArk = [PSCustomObject]@{
                enabled = $true
                loginUrl = "https://aon.cyberark.cloud/privilegecloud/Accounts"
                interactiveLogin = $true
                allowManualFallback = $true
            }
        }
        Save-JsonFile "settings.json" $settings

        $normalized = Get-JsonFile "settings.json"

        $normalized.selectedUser | Should Be "adm-A0836618"
        $normalized.lastEnvironment | Should Be "DEV"
        $normalized.cyberArk.enabled | Should Be $true
    }

    It "Resuelve el safe correcto por entorno y prioriza CyberArk con fallback manual" {
        $settings = Get-JsonFile "settings.json"
        if(-not ($settings.PSObject.Properties.Name -contains "cyberArk")){
            $settings | Add-Member -NotePropertyName "cyberArk" -NotePropertyValue ([PSCustomObject]@{
                enabled = $true
                baseUrl = "https://example.cyberark.local"
                username = "svc-launcher"
                appId = "APP-LAUNCHER"
                safeByEnvironment = [PSCustomObject]@{
                    DEV = "LATAM_TR_PPA_A0836618"
                    QC = "LATAM_EXTQC_PPA_A0836618"
                    PROD = "LATAM_UNTR_PPA_A0836618"
                }
                accountNameTemplate = "{user}"
                allowManualFallback = $true
            })
        }
        else{
            $settings.cyberArk = [PSCustomObject]@{
                enabled = $true
                baseUrl = "https://example.cyberark.local"
                username = "svc-launcher"
                appId = "APP-LAUNCHER"
                safeByEnvironment = [PSCustomObject]@{
                    DEV = "LATAM_TR_PPA_A0836618"
                    QC = "LATAM_EXTQC_PPA_A0836618"
                    PROD = "LATAM_UNTR_PPA_A0836618"
                }
                accountNameTemplate = "{user}"
                allowManualFallback = $true
            }
        }
        Save-JsonFile "settings.json" $settings

        $cyberArkConfig = Get-CyberArkSettings
        $cyberArkConfig.safeByEnvironment.DEV | Should Be "LATAM_TR_PPA_A0836618"
        $cyberArkConfig.safeByEnvironment.QC | Should Be "LATAM_EXTQC_PPA_A0836618"
        $cyberArkConfig.safeByEnvironment.PROD | Should Be "LATAM_UNTR_PPA_A0836618"

        function Global:Get-CyberArkCredentialValue {
            param(
                [string]$Environment,
                [string]$User
            )
            throw "CyberArk availability failure"
        }

        $manual = [PSCustomObject]@{
            environment = "DEV"
            user = "test-user"
            password = Protect-Password "manual-fallback-secret"
            updatedAt = (Get-Date).AddHours(-2).ToString("s")
        }
        Save-Credentials ([PSCustomObject]@{credentials=@($manual)})

        $resolved = Get-LauncherCredential "DEV" "test-user"
        $resolved.Password | Should Be "manual-fallback-secret"

        Remove-Item Function:\Get-CyberArkCredentialValue -Force -ErrorAction SilentlyContinue
    }
}
