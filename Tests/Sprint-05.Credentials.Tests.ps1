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
}
