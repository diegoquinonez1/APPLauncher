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
        $script:envPrimary = (Get-LauncherEnvironmentDefinitions | Select-Object -First 1).name
        $script:envSecondary = (Get-LauncherEnvironmentDefinitions | Select-Object -Skip 1 | Select-Object -First 1).name
        $script:envTertiary = (Get-LauncherEnvironmentDefinitions | Select-Object -Skip 2 | Select-Object -First 1).name
        if([string]::IsNullOrWhiteSpace($script:envSecondary)){ $script:envSecondary = $script:envPrimary }
        if([string]::IsNullOrWhiteSpace($script:envTertiary)){ $script:envTertiary = $script:envPrimary }
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
        $password = "example-value-123!"
        Save-LauncherCredential -Environment $script:envPrimary -User "test-user" -SecretValue $password

        $stored = (Get-Credentials).credentials[0]
        $stored.password.Contains($password) | Should Be $false
        [IO.File]::ReadAllText((Join-Path $Global:ConfigFolder "credentials.json")) | Should Match '"updatedAt"\s*:\s*"\d{4}-\d{2}-\d{2}T'
        (Get-LauncherCredential $script:envPrimary "test-user").Password | Should Be $password
        (Get-LauncherCredentialStatus $script:envPrimary "test-user").Status | Should Be "Válida"
    }

    It "Distingue credencial no configurada por usuario y entorno" {
        (Get-LauncherCredentialStatus $script:envSecondary "test-user").Status | Should Be "No configurada"
        (Get-LauncherCredentialStatus $script:envPrimary "another-user").Status | Should Be "No configurada"
    }

    It "Elimina solo credenciales expiradas y mantiene el estado expirada en sesión" {
        $expired = [PSCustomObject]@{
            environment = $script:envPrimary
            user = "test-user"
            password = Protect-Secret "sample-expired-demo"
            updatedAt = $script:now.AddHours(-9).ToString("s")
        }
        $valid = [PSCustomObject]@{
            environment = $script:envSecondary
            user = "test-user"
            password = Protect-Secret "sample-valid-demo"
            updatedAt = (Get-Date).AddHours(-1).ToString("s")
        }
        Save-Credentials ([PSCustomObject]@{credentials=@($expired, $valid)})

        (Remove-ExpiredLauncherCredentials) | Should Be 1
        @((Get-Credentials).credentials).Count | Should Be 1
        (Get-Credentials).credentials[0].environment | Should Be $script:envSecondary
        (Get-LauncherCredentialStatus $script:envPrimary "test-user").Status | Should Be "Expirada"
        (Get-LauncherCredentialStatus $script:envSecondary "test-user").Status | Should Be "Válida"
        (Test-LauncherCredential $script:envPrimary "test-user") | Should Be $false
    }

    It "Elimina una credencial expirada al intentar recuperarla" {
        $expired = [PSCustomObject]@{
            environment = $script:envTertiary
            user = "test-user"
            password = Protect-Secret "sample-expired-demo"
            updatedAt = $script:now.AddHours(-10).ToString("s")
        }
        Save-Credentials ([PSCustomObject]@{credentials=@($expired)})

        (Get-LauncherCredential $script:envTertiary "test-user") | Should Be $null
        @((Get-Credentials).credentials).Count | Should Be 0
        (Get-LauncherCredentialStatus $script:envTertiary "test-user").Status | Should Be "Expirada"
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
                loginUrl = "https://example.cyberark.example/privilegecloud/Accounts"
                username = $null
                password = $null
                appId = $null
                interactiveLogin = $true
                allowManualFallback = $true
            }
        }

        Save-JsonFile "settings.json" $settings

        $null = Get-CyberArkCredentialValue -Environment $script:envPrimary -User "demo-user"
        $null = Get-CyberArkCredentialValue -Environment $script:envPrimary -User "demo-user"

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
                loginUrl = "https://example.cyberark.example/privilegecloud/Accounts"
                username = $null
                password = $null
                appId = $null
                interactiveLogin = $true
                allowManualFallback = $true
            }
        }
        Save-JsonFile "settings.json" $settings

        $status = Get-LauncherCredentialStatus $script:envPrimary "demo-user"

        $script:BrowserOpenCount | Should Be 1
        $status.Status | Should Match "login interactivo|CyberArk|manual"

        Remove-Item Function:\Start-Process -Force -ErrorAction SilentlyContinue
    }

    It "Expone un estado explícito cuando CyberArk requiere login interactivo y no devuelve contraseña" {
        $settings = [PSCustomObject]@{
            cyberArk = [PSCustomObject]@{
                enabled = $true
                baseUrl = $null
                loginUrl = "https://example.cyberark.example/privilegecloud/Accounts"
                username = $null
                password = $null
                appId = $null
                interactiveLogin = $true
                allowManualFallback = $true
            }
        }
        Save-JsonFile "settings.json" $settings

        $status = Get-LauncherCredentialStatus $script:envPrimary "demo-user"
        $status.Status | Should Match "login interactivo|CyberArk|manual"
        (Test-LauncherCredential $script:envPrimary "demo-user") | Should Be $false
        (Get-LauncherCredential $script:envPrimary "demo-user") | Should Be $null
    }

    It "Mantiene el flujo interactivo cuando CyberArk requiere login y no entrega contraseña" {
        $settings = [PSCustomObject]@{
            selectedUser = "demo-user"
            lastEnvironment = $script:envPrimary
            cyberArk = [PSCustomObject]@{
                enabled = $true
                baseUrl = $null
                loginUrl = "https://example.cyberark.example/privilegecloud/Accounts"
                username = $null
                password = $null
                appId = $null
                interactiveLogin = $true
                allowManualFallback = $true
            }
        }
        Save-JsonFile "settings.json" $settings

        $manual = [PSCustomObject]@{
            environment = $script:envPrimary
            user = "demo-user"
            password = Protect-Secret "demo-manual-123"
            updatedAt = (Get-Date).AddHours(-1).ToString("s")
        }
        Save-Credentials ([PSCustomObject]@{credentials=@($manual)})

        $status = Get-LauncherCredentialStatus $script:envPrimary "demo-user"
        $status.Status | Should Match "login interactivo|CyberArk|manual"
        (Get-LauncherCredential $script:envPrimary "demo-user") | Should Be $null
        (Test-LauncherCredential $script:envPrimary "demo-user") | Should Be $false
    }

    It "Normaliza settings.json cuando falta selectedUser o lastEnvironment" {
        $settings = [PSCustomObject]@{
            cyberArk = [PSCustomObject]@{
                enabled = $true
                loginUrl = "https://example.cyberark.example/privilegecloud/Accounts"
                interactiveLogin = $true
                allowManualFallback = $true
            }
        }
        Save-JsonFile "settings.json" $settings

        $normalized = Get-JsonFile "settings.json"

        $normalized.selectedUser | Should Be "demo-user"
        $normalized.lastEnvironment | Should Be "ENV-01"
        $normalized.cyberArk.enabled | Should Be $true
    }

    It "Resuelve el safe correcto por entorno y prioriza la configuración del archivo de ambientes" {
        $envOne = $script:envPrimary
        $envTwo = $script:envSecondary
        $envThree = $script:envTertiary
        $settings = Get-JsonFile "settings.json"
        if(-not ($settings.PSObject.Properties.Name -contains "cyberArk")){
            $settings | Add-Member -NotePropertyName "cyberArk" -NotePropertyValue ([PSCustomObject]@{
                enabled = $true
                baseUrl = "https://example.cyberark.local"
                username = "svc-launcher-demo"
                appId = "APP-LAUNCHER-DEMO"
                safeByEnvironment = [PSCustomObject]@{
                    $envOne = "SAFE_DEMO_1"
                    $envTwo = "SAFE_DEMO_2"
                    $envThree = "SAFE_DEMO_3"
                }
                accountNameTemplate = "{user}"
                allowManualFallback = $true
            })
        }
        else{
            $settings.cyberArk = [PSCustomObject]@{
                enabled = $true
                baseUrl = "https://example.cyberark.local"
                username = "svc-launcher-demo"
                appId = "APP-LAUNCHER-DEMO"
                safeByEnvironment = [PSCustomObject]@{
                    $envOne = "SAFE_DEMO_1"
                    $envTwo = "SAFE_DEMO_2"
                    $envThree = "SAFE_DEMO_3"
                }
                accountNameTemplate = "{user}"
                allowManualFallback = $true
            }
        }
        Save-JsonFile "settings.json" $settings

        $cyberArkConfig = Get-CyberArkSettings
        $cyberArkConfig.safeByEnvironment.PSObject.Properties[$envOne].Value | Should Be "SAFE_DEMO_1"
        $cyberArkConfig.safeByEnvironment.PSObject.Properties[$envTwo].Value | Should Be "SAFE_DEMO_2"
        $cyberArkConfig.safeByEnvironment.PSObject.Properties[$envThree].Value | Should Be "SAFE_DEMO_3"

        function Global:Get-CyberArkCredentialValue {
            param(
                [string]$Environment,
                [string]$User
            )
            throw "CyberArk availability failure"
        }

        $manual = [PSCustomObject]@{
            environment = $envOne
            user = "test-user"
            password = Protect-Secret "demo-fallback-456"
            updatedAt = (Get-Date).AddHours(-2).ToString("s")
        }
        Save-Credentials ([PSCustomObject]@{credentials=@($manual)})

        $resolved = Get-LauncherCredential $envOne "test-user"
        $resolved.Password | Should Be "demo-fallback-456"

        Remove-Item Function:\Get-CyberArkCredentialValue -Force -ErrorAction SilentlyContinue
    }
}
