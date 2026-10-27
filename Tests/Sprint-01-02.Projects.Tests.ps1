. (Join-Path $PSScriptRoot "TestSupport.ps1")

Describe "Sprint 1: lanzador dinámico de proyectos" {

    BeforeEach {
        $script:testRoot = New-AONTestRoot
        . (Join-Path $script:AONTestRepositoryRoot "Modules\ProfileManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\ApplicationManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\LogManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\AppLauncher.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\ProjectLauncher.ps1")
        $Global:LogFile = Join-Path $Global:LogFolder "launcher.log"
    }

    AfterEach {
        Remove-AONTestRoot $script:testRoot
    }

    It "Rechaza perfiles sin acciones, entorno o usuario" {
        $project = [PSCustomObject]@{
            name = "Empty"
            environment = "DEV"
            user = "test-user"
            startupApps = @()
            solution = ""
            folder = ""
        }
        Save-JsonFile "projects.json" ([PSCustomObject]@{ projects = @($project) })

        (Test-AONThrows { Start-ProjectProfile -Project $project }) | Should Be $true

        $project.startupApps = @("SSMS")
        $project.environment = ""
        (Test-AONThrows { Start-ProjectProfile -Project $project }) | Should Be $true

        $project.environment = "DEV"
        $project.user = ""
        (Test-AONThrows { Start-ProjectProfile -Project $project }) | Should Be $true
    }

    It "Rechaza nombres duplicados y aplicaciones no soportadas" {
        $first = [PSCustomObject]@{ name = "Duplicate"; startupApps = @(); solution = ""; folder = $script:testRoot }
        $second = [PSCustomObject]@{ name = "Duplicate"; startupApps = @(); solution = ""; folder = $script:testRoot }
        Save-JsonFile "projects.json" ([PSCustomObject]@{ projects = @($first, $second) })

        (Test-AONThrows { Start-ProjectProfile -Project $first }) | Should Be $true

        $unsupported = [PSCustomObject]@{
            name = "Unsupported"
            environment = "DEV"
            user = "test-user"
            startupApps = @("NotAnApp")
            solution = ""
            folder = ""
        }
        Save-JsonFile "projects.json" ([PSCustomObject]@{ projects = @($unsupported) })
        (Test-AONThrows { Start-ProjectProfile -Project $unsupported }) | Should Be $true
    }

    It "Valida todas las rutas antes de iniciar una aplicación" {
        $application = New-AONTestFile (Join-Path $script:testRoot "apps\ssms.exe")
        $applications = Get-Applications
        $applications.SSMS = $application
        Save-Applications $applications

        $project = [PSCustomObject]@{
            name = "Invalid solution"
            environment = "DEV"
            user = "test-user"
            startupApps = @("SSMS")
            solution = Join-Path $script:testRoot "missing.sln"
            folder = ""
        }
        Save-JsonFile "projects.json" ([PSCustomObject]@{ projects = @($project) })
        Mock Start-AONApplication {}
        Mock Start-Process {}

        (Test-AONThrows { Start-ProjectProfile -Project $project }) | Should Be $true
        Assert-MockCalled Start-AONApplication -Times 0 -Scope It
        Assert-MockCalled Start-Process -Times 0 -Scope It
        (Get-LauncherLogs).Count | Should Be 0
    }

    It "Inicia un perfil solo de carpeta sin requerir entorno ni usuario" {
        $folder = Join-Path $script:testRoot "project-folder"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $project = [PSCustomObject]@{
            name = "Folder only"
            environment = ""
            user = ""
            startupApps = @()
            solution = ""
            folder = $folder
        }
        Save-JsonFile "projects.json" ([PSCustomObject]@{ projects = @($project) })
        Mock Start-Process {}

        Start-ProjectProfile -Project $project

        Assert-MockCalled Start-Process -Times 1 -Scope It -ParameterFilter {
            $FilePath -eq "explorer.exe" -and $ArgumentList -like "*$folder*"
        }
        (Get-LauncherDashboardMetrics -LogPath $Global:LogFile).LatestProject.Name | Should Be "Folder only"
    }

    It "Inicia las aplicaciones configuradas después de validar el perfil" {
        $application = New-AONTestFile (Join-Path $script:testRoot "apps\ssms.exe")
        $applications = Get-Applications
        $applications.SSMS = $application
        Save-Applications $applications
        $project = [PSCustomObject]@{
            name = "Application profile"
            environment = "DEV"
            user = "test-user"
            startupApps = @("SSMS")
            solution = ""
            folder = ""
        }
        Save-JsonFile "projects.json" ([PSCustomObject]@{ projects = @($project) })
        Mock Start-Sleep {}
        Mock Start-Process {}

        Start-ProjectProfile -Project $project

        Assert-MockCalled Start-Process -Times 1 -Scope It -ParameterFilter {
            $FilePath -eq "runas.exe" -and $ArgumentList -like "*/user:devaonnet\test-user*"
        }
        Assert-MockCalled Start-Sleep -Times 1 -Scope It
        $metrics = Get-LauncherDashboardMetrics -LogPath $Global:LogFile
        $metrics.LatestApplication.Name | Should Be "SSMS"
        $metrics.LatestProject.Name | Should Be "Application profile"
    }
}

Describe "Sprint 2: administración de proyectos" {

    BeforeEach {
    $script:testRoot = New-AONTestRoot
        . (Join-Path $script:AONTestRepositoryRoot "Modules\ProfileManager.ps1")
    }

    AfterEach {
        Remove-AONTestRoot $script:testRoot
    }

    It "Crea, actualiza y elimina perfiles persistidos" {
        Add-Project -Name "One" -Environment "DEV" -User "test-user" -Solution "" -Folder "" -StartupApps @("SSMS")
        (Get-Projects).projects[0].name | Should Be "One"

        Update-Project -OriginalName "One" -Name "Renamed" -Environment "QC" -User "another-user" -Solution "" -Folder "" -StartupApps @("VSCode")
        $updated = (Get-Projects).projects[0]
        $updated.name | Should Be "Renamed"
        $updated.environment | Should Be "QC"
        $updated.startupApps[0] | Should Be "VSCode"

        Remove-Project "Renamed"
        @((Get-Projects).projects).Count | Should Be 0
    }

    It "Rechaza proyectos duplicados al crear o renombrar" {
        Add-Project -Name "One" -Environment "DEV" -User "test-user" -Solution "" -Folder "" -StartupApps @("SSMS")
        Add-Project -Name "Two" -Environment "QC" -User "another-user" -Solution "" -Folder "" -StartupApps @("VSCode")

        (Test-AONThrows {
            Add-Project -Name "One" -Environment "DEV" -User "test-user" -Solution "" -Folder "" -StartupApps @("SSMS")
        }) | Should Be $true
        (Test-AONThrows {
            Update-Project -OriginalName "Two" -Name "One" -Environment "QC" -User "another-user" -Solution "" -Folder "" -StartupApps @("VSCode")
        }) | Should Be $true
        @((Get-Projects).projects).Count | Should Be 2
    }
}
