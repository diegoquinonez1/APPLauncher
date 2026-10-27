. (Join-Path $PSScriptRoot "TestSupport.ps1")

Describe "Base operativa: configuración y persistencia" {

    BeforeEach {
        $script:testRoot = New-AONTestRoot
    }

    AfterEach {
        Remove-AONTestRoot $script:testRoot
    }

    It "Inicializa la configuración en un directorio aislado y crea todos los archivos base" {
        $isolatedRoot = Join-Path $script:testRoot "isolated-launcher"
        $isolatedModules = Join-Path $isolatedRoot "Modules"
        New-Item -ItemType Directory -Path $isolatedModules -Force | Out-Null
        Copy-Item `
            -LiteralPath (Join-Path $script:AONTestRepositoryRoot "Modules\ConfigManager.ps1") `
            -Destination (Join-Path $isolatedModules "ConfigManager.ps1")

        . (Join-Path $isolatedModules "ConfigManager.ps1")

        foreach($fileName in @(
            "settings.json",
            "users.json",
            "favorites.json",
            "applications.json",
            "projects.json",
            "links.json",
            "credentials.json"
        )){
            Test-Path -LiteralPath (Join-Path $Global:ConfigFolder $fileName) | Should Be $true
        }
        Test-Path -LiteralPath $Global:LogFile | Should Be $true
        Test-Path -LiteralPath $Global:BackupFolder | Should Be $true
    }

    It "Guarda y lee JSON preservando colecciones" {
        $data = [PSCustomObject]@{ values = @("uno", "dos") }
        Save-JsonFile -FileName "roundtrip.json" -Data $data
        $actual = Get-JsonFile "roundtrip.json"

        @($actual.values).Count | Should Be 2
        $actual.values[1] | Should Be "dos"
    }

    It "Crea una copia de seguridad de los archivos de configuración" {
        $backupPath = Backup-Configuration

        Test-Path -LiteralPath (Join-Path $backupPath "users.json") | Should Be $true
        [IO.File]::ReadAllText((Join-Path $backupPath "users.json")) | Should Match 'test-user'
    }
}

Describe "Base operativa: usuarios y favoritos" {

    BeforeEach {
        $script:testRoot = New-AONTestRoot
        . (Join-Path $script:AONTestRepositoryRoot "Modules\UserManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\FavoriteManager.ps1")
    }

    AfterEach {
        Remove-AONTestRoot $script:testRoot
    }

    It "Agrega, modifica y elimina usuarios sin permitir alterar el usuario predeterminado" {
        Add-LauncherUser "new-user"
        (Get-Users).users -contains "new-user" | Should Be $true

        Update-LauncherUser -OldUser "another-user" -NewUser "renamed-user"
        (Get-Users).users -contains "renamed-user" | Should Be $true

        (Test-AONThrows { Remove-LauncherUser "test-user" }) | Should Be $true
        (Test-AONThrows { Update-LauncherUser -OldUser "test-user" -NewUser "other-name" }) | Should Be $true
        (Test-AONThrows { Add-LauncherUser "new-user" }) | Should Be $true

        Remove-LauncherUser "renamed-user"
        (Get-Users).users -contains "renamed-user" | Should Be $false
    }

    It "Rechaza un destino de usuario duplicado y una actualización duplicada" {
        (Test-AONThrows { Update-LauncherUser -OldUser "another-user" -NewUser "test-user" }) | Should Be $true
        (Get-Users).users -contains "another-user" | Should Be $true
    }

    It "Guarda y elimina favoritos" {
        Add-Favorite -Name "Dev SSMS" -User "test-user" -Environment "DEV" -Application "SSMS"
        $favorites = Get-Favorites
        @($favorites.favorites).Count | Should Be 1
        $favorites.favorites[0].Application | Should Be "SSMS"

        Remove-Favorite "Dev SSMS"
        @((Get-Favorites).favorites).Count | Should Be 0
    }
}

Describe "Base operativa: aplicaciones y ejecución" {

    BeforeEach {
        $script:testRoot = New-AONTestRoot
        . (Join-Path $script:AONTestRepositoryRoot "Modules\ApplicationManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\LogManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\AppLauncher.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\UiHelpers.ps1")
        $Global:LogFile = Join-Path $Global:LogFolder "launcher.log"
        $script:applicationPath = New-AONTestFile (Join-Path $script:testRoot "apps\ssms.exe")
        $apps = Get-Applications
        $apps.SSMS = $script:applicationPath
        Save-Applications $apps
    }

    AfterEach {
        Remove-AONTestRoot $script:testRoot
    }

    It "Asigna el dominio correcto a cada entorno y rechaza entornos desconocidos" {
        (Get-DomainByEnvironment "DEV") | Should Be "devaonnet"
        (Get-DomainByEnvironment "QC") | Should Be "extadqc"
        (Get-DomainByEnvironment "PROD") | Should Be "extad"
        (Test-AONThrows { Get-DomainByEnvironment "UNKNOWN" }) | Should Be $true
    }

    It "Inicia la aplicación validada con runas y registra el evento después" {
        Mock Start-Process {}
        Mock Write-LauncherLog {}

        Start-AONApplication -ApplicationName "SSMS" -Environment "DEV" -User "test-user"

        Assert-MockCalled Start-Process -Times 1 -ParameterFilter {
            $FilePath -eq "runas.exe" -and $ArgumentList -like "*/user:devaonnet\test-user*"
        }
        Assert-MockCalled Write-LauncherLog -Times 1 -ParameterFilter {
            $Environment -eq "DEV" -and $User -eq "devaonnet\test-user" -and $Application -eq "SSMS"
        }
    }

    It "No ejecuta ni registra aplicaciones con ruta o entorno inválido" {
        Mock Start-Process {}
        Mock Write-LauncherLog {}

        (Test-AONThrows { Start-AONApplication -ApplicationName "Unknown" -Environment "DEV" -User "test-user" }) | Should Be $true
        (Test-AONThrows { Start-AONApplication -ApplicationName "SSMS" -Environment "UNKNOWN" -User "test-user" }) | Should Be $true

        Assert-MockCalled Start-Process -Times 0 -Scope It
        Assert-MockCalled Write-LauncherLog -Times 0 -Scope It
    }

    It "Escanea y persiste los resultados de detección" {
        Mock Find-SSMS { "C:\Apps\SSMS.exe" }
        Mock Find-VisualStudio { "C:\Apps\devenv.exe" }
        Mock Find-VSCode { "C:\Apps\Code.exe" }
        Mock Find-ReportBuilder { "C:\Apps\ReportBuilder.exe" }

        $result = Scan-Applications

        $result.SSMS | Should Be "C:\Apps\SSMS.exe"
        $result.VSCode | Should Be "C:\Apps\Code.exe"
        [string]::IsNullOrWhiteSpace($result.LastScan) | Should Be $false
        (Get-Applications).ReportBuilder | Should Be "C:\Apps\ReportBuilder.exe"
    }

    It "Enruta excepciones de acciones seguras al manejador de errores" {
        Mock Show-Error {}

        Invoke-Safely { throw "expected failure" }

        Assert-MockCalled Show-Error -Times 1 -ParameterFilter {
            $Message -eq "expected failure"
        }
    }
}

Describe "Base operativa: tema por entorno" {

    BeforeEach {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        . (Join-Path $script:AONTestRepositoryRoot "Modules\ThemeManager.ps1")
        $script:form = New-Object System.Windows.Forms.Form
    }

    AfterEach {
        $script:form.Dispose()
    }

    It "Aplica colores diferenciados para DEV, QC, PROD y el valor predeterminado" {
        Set-EnvironmentTheme $script:form "DEV"
        $script:form.BackColor | Should Be ([System.Drawing.Color]::Honeydew)
        Set-EnvironmentTheme $script:form "QC"
        $script:form.BackColor | Should Be ([System.Drawing.Color]::LemonChiffon)
        Set-EnvironmentTheme $script:form "PROD"
        $script:form.BackColor | Should Be ([System.Drawing.Color]::MistyRose)
        Set-EnvironmentTheme $script:form "unknown"
        $script:form.BackColor | Should Be ([System.Drawing.Color]::WhiteSmoke)
    }
}
