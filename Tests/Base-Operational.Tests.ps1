. (Join-Path $PSScriptRoot "TestSupport.ps1")

Describe "Base operativa: configuración y persistencia" {

    BeforeEach {
        $script:testRoot = New-APPLauncherTestRoot
    }

    AfterEach {
        Remove-APPLauncherTestRoot $script:testRoot
    }

    It "Inicializa la configuración en un directorio aislado y crea todos los archivos base" {
        $isolatedRoot = Join-Path $script:testRoot "isolated-launcher"
        $isolatedModules = Join-Path $isolatedRoot "Modules"
        New-Item -ItemType Directory -Path $isolatedModules -Force | Out-Null
        Copy-Item `
            -LiteralPath (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\ConfigManager.ps1") `
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

    It "Crea y utiliza la configuración de ambientes y dominios sin hardcode del cliente" {
        $environmentConfig = Get-LauncherEnvironments
        @($environmentConfig).Count | Should BeGreaterThan 0
        ($environmentConfig[0].PSObject.Properties.Name -contains "name") | Should Be $true
        ($environmentConfig[0].PSObject.Properties.Name -contains "domain") | Should Be $true
        ($environmentConfig[0].PSObject.Properties.Name -contains "safe") | Should Be $true
        ($environmentConfig[0].PSObject.Properties.Name -contains "color") | Should Be $true
        (Get-DomainByEnvironment $environmentConfig[0].name) | Should Be $environmentConfig[0].domain

        Save-LauncherEnvironments @(
            [PSCustomObject]@{ name = "INT"; domain = "corp-int"; safe = "SAFE_INT"; color = "#00A676"; default = $true },
            [PSCustomObject]@{ name = "PRD"; domain = "corp-prd"; safe = "SAFE_PRD"; color = "#FF6B35" }
        )

        (Get-DomainByEnvironment "INT") | Should Be "corp-int"
        (Get-DomainByEnvironment "PRD") | Should Be "corp-prd"
        (Get-LauncherEnvironmentName "INT") | Should Be "INT"
        ((Get-LauncherEnvironmentNames) -contains "INT") | Should Be $true
        ((Get-LauncherEnvironmentNames) -contains "PRD") | Should Be $true
    }

    It "Rechaza una configuración vacía o con estructura inválida y acepta más de un ambiente" {
        $file = Join-Path $Global:ConfigFolder "environments.json"
        $original = [IO.File]::ReadAllText($file)

        try {
            Set-Content -LiteralPath $file -Value "" -Encoding UTF8
            $empty = Test-LauncherEnvironmentConfiguration
            $empty.IsValid | Should Be $false
            $empty.Error | Should Match "configurac|vacía|al menos un ambiente"

            Set-Content -LiteralPath $file -Value '[{"name":"INT","domain":"corp-int","safe":"SAFE_INT"},{"name":"PRD","domain":"corp-prd","safe":"SAFE_PRD"}]' -Encoding UTF8
            $valid = Get-LauncherEnvironmentDefinitions
            @($valid).Count | Should Be 2
            ((@($valid | ForEach-Object { $_.name }) -contains "INT")) | Should Be $true
            ((@($valid | ForEach-Object { $_.name }) -contains "PRD")) | Should Be $true
        }
        finally {
            if($original.Length -gt 0){
                Set-Content -LiteralPath $file -Value $original -Encoding UTF8
            }
            else {
                Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It "Crea una copia de seguridad de los archivos de configuración" {
        $backupPath = Backup-Configuration

        Test-Path -LiteralPath (Join-Path $backupPath "users.json") | Should Be $true
        [IO.File]::ReadAllText((Join-Path $backupPath "users.json")) | Should Match 'test-user'
    }
}

Describe "Base operativa: usuarios y favoritos" {

    BeforeEach {
        $script:testRoot = New-APPLauncherTestRoot
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\UserManager.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\FavoriteManager.ps1")
    }

    AfterEach {
        Remove-APPLauncherTestRoot $script:testRoot
    }

    It "Agrega, modifica y elimina usuarios sin permitir alterar el usuario predeterminado" {
        Add-LauncherUser "new-user"
        (Get-Users).users -contains "new-user" | Should Be $true

        Update-LauncherUser -OldUser "another-user" -NewUser "renamed-user"
        (Get-Users).users -contains "renamed-user" | Should Be $true

        (Test-APPLauncherThrows { Remove-LauncherUser "test-user" }) | Should Be $true
        (Test-APPLauncherThrows { Update-LauncherUser -OldUser "test-user" -NewUser "other-name" }) | Should Be $true
        (Test-APPLauncherThrows { Add-LauncherUser "new-user" }) | Should Be $true

        Remove-LauncherUser "renamed-user"
        (Get-Users).users -contains "renamed-user" | Should Be $false
    }

    It "Rechaza un destino de usuario duplicado y una actualización duplicada" {
        (Test-APPLauncherThrows { Update-LauncherUser -OldUser "another-user" -NewUser "test-user" }) | Should Be $true
        (Get-Users).users -contains "another-user" | Should Be $true
    }

    It "Guarda y elimina favoritos" {
        $environmentName = (Get-LauncherEnvironmentDefinitions | Select-Object -First 1).name
        Add-Favorite -Name "Dev SSMS" -User "test-user" -Environment $environmentName -Application "SSMS"
        $favorites = Get-Favorites
        @($favorites.favorites).Count | Should Be 1
        $favorites.favorites[0].Application | Should Be "SSMS"

        Remove-Favorite "Dev SSMS"
        @((Get-Favorites).favorites).Count | Should Be 0
    }
}

Describe "Base operativa: aplicaciones y ejecución" {

    BeforeEach {
        $script:testRoot = New-APPLauncherTestRoot
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\ApplicationManager.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\LogManager.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\AppLauncher.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\UiHelpers.ps1")
        $Global:LogFile = Join-Path $Global:LogFolder "launcher.log"
        $script:applicationPath = New-APPLauncherTestFile (Join-Path $script:testRoot "apps\ssms.exe")
        $apps = Get-Applications
        $apps.SSMS = $script:applicationPath
        Save-Applications $apps
    }

    AfterEach {
        Remove-APPLauncherTestRoot $script:testRoot
    }

    It "Asigna el dominio correcto a cada entorno y rechaza entornos desconocidos" {
        $definitions = Get-LauncherEnvironmentDefinitions
        $definitions.Count | Should BeGreaterThan 0

        foreach($item in $definitions){
            $resolved = Get-DomainByEnvironment $item.name
            $resolved | Should Be $item.domain
        }

        $unknownEnvironment = "UNKNOWN-" + [guid]::NewGuid().ToString("N")
        (Test-APPLauncherThrows { Get-DomainByEnvironment $unknownEnvironment }) | Should Be $true
    }

    It "Inicia la aplicación validada con runas y registra el evento después" {
        Mock Start-Process {}
        Mock Write-LauncherLog {}

        $environmentName = (Get-LauncherEnvironmentDefinitions | Select-Object -First 1).name
        $domain = Get-DomainByEnvironment $environmentName

        Start-AppLauncherApplication -ApplicationName "SSMS" -Environment $environmentName -User "test-user"

        Assert-MockCalled Start-Process -Times 1 -ParameterFilter {
            $FilePath -eq "runas.exe" -and $ArgumentList -like "*/user:$domain\test-user*"
        }
        Assert-MockCalled Write-LauncherLog -Times 1 -ParameterFilter {
            $Environment -eq $environmentName -and $User -eq "$domain\test-user" -and $Application -eq "SSMS"
        }
    }

    It "No ejecuta ni registra aplicaciones con ruta o entorno inválido" {
        Mock Start-Process {}
        Mock Write-LauncherLog {}

        $environmentName = (Get-LauncherEnvironmentDefinitions | Select-Object -First 1).name
        $unknownEnvironment = "UNKNOWN-" + [guid]::NewGuid().ToString("N")
        (Test-APPLauncherThrows { Start-AppLauncherApplication -ApplicationName "Unknown" -Environment $environmentName -User "test-user" }) | Should Be $true
        (Test-APPLauncherThrows { Start-AppLauncherApplication -ApplicationName "SSMS" -Environment $unknownEnvironment -User "test-user" }) | Should Be $true

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
        $script:testRoot = New-APPLauncherTestRoot
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\ConfigManager.ps1")
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\ThemeManager.ps1")
        $script:form = New-Object System.Windows.Forms.Form
    }

    AfterEach {
        $script:form.Dispose()
        Remove-APPLauncherTestRoot $script:testRoot
    }

    It "Aplica colores por entorno desde la configuración y usa un valor seguro cuando no existe color" {
        Save-LauncherEnvironments @(
            [PSCustomObject]@{ name = "ALPHA"; domain = "alpha.local"; safe = "SAFE_ALPHA"; color = "#FF6600"; default = $true },
            [PSCustomObject]@{ name = "BETA"; domain = "beta.local"; safe = "SAFE_BETA"; color = "#00A676" }
        )

        Set-EnvironmentTheme $script:form "ALPHA"
        $script:form.BackColor.ToArgb() | Should Be ([System.Drawing.ColorTranslator]::FromHtml("#FF6600")).ToArgb()

        Set-EnvironmentTheme $script:form "BETA"
        $script:form.BackColor.ToArgb() | Should Be ([System.Drawing.ColorTranslator]::FromHtml("#00A676")).ToArgb()

        Set-EnvironmentTheme $script:form "unknown"
        $script:form.BackColor.ToArgb() | Should Be ([System.Drawing.Color]::WhiteSmoke).ToArgb()
    }
}
