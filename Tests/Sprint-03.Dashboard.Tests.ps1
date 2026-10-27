. (Join-Path $PSScriptRoot "TestSupport.ps1")

Describe "Sprint 3: dashboard y métricas de actividad" {

    BeforeEach {
        $script:testRoot = New-AONTestRoot
        . (Join-Path $script:AONTestRepositoryRoot "Modules\LogManager.ps1")
        $Global:LogFile = Join-Path $Global:LogFolder "launcher.log"
    }

    AfterEach {
        Remove-AONTestRoot $script:testRoot
    }

    It "Calcula última y más usada aplicación, y cuenta día y mes" {
        $lines = @(
            "2026-10-22 09:00:00 | INFO | DEV | user-a | VSCode",
            "2026-10-23 08:00:00 | INFO | DEV | user-a | SSMS",
            "2026-10-23 10:00:00 | INFO | QC | user-b | SSMS",
            "2026-09-23 11:00:00 | INFO | PROD | user-c | SSMS"
        )
        [IO.File]::WriteAllLines($Global:LogFile, $lines)
        $now = [datetime]::ParseExact(
            "2026-10-23 12:00:00",
            "yyyy-MM-dd HH:mm:ss",
            [Globalization.CultureInfo]::InvariantCulture
        )

        $metrics = Get-LauncherDashboardMetrics -Now $now -LogPath $Global:LogFile

        $metrics.LatestApplication.Name | Should Be "SSMS"
        $metrics.LatestApplication.Timestamp.Hour | Should Be 10
        $metrics.MostUsedApplication.Name | Should Be "SSMS"
        $metrics.MostUsedApplication.Count | Should Be 3
        $metrics.ExecutionsToday | Should Be 2
        $metrics.ExecutionsThisMonth | Should Be 3
    }

    It "Cuenta eventos de proyecto aparte de las aperturas de aplicaciones" {
        $lines = @(
            "2026-10-23 09:00:00 | INFO | DEV | user-a | SSMS",
            "2026-10-23 09:00:02 | PROJECT | DEV | user-a | BAIS DEV",
            "2026-10-23 10:00:00 | PROJECT | - | - | Folder only",
            "2026-10-22 10:00:00 | PROJECT | QC | user-b | BAIS DEV"
        )
        [IO.File]::WriteAllLines($Global:LogFile, $lines)
        $now = [datetime]::ParseExact(
            "2026-10-23 12:00:00",
            "yyyy-MM-dd HH:mm:ss",
            [Globalization.CultureInfo]::InvariantCulture
        )

        $metrics = Get-LauncherDashboardMetrics -Now $now -LogPath $Global:LogFile

        $metrics.LatestProject.Name | Should Be "Folder only"
        $metrics.MostUsedProject.Name | Should Be "BAIS DEV"
        $metrics.MostUsedProject.Count | Should Be 2
        $metrics.ExecutionsToday | Should Be 1
        $metrics.ExecutionsThisMonth | Should Be 1
    }

    It "Ignora líneas malformadas, fechas inválidas y eventos sin nombre" {
        $lines = @(
            "not a log line",
            "2026-99-99 25:61:61 | INFO | DEV | user-a | Invalid date",
            "2026-10-23 09:00:00 | INFO | DEV | user-a | ",
            "2026-10-23 09:01:00 | PROJECT | DEV | user-a | Valid project"
        )
        [IO.File]::WriteAllLines($Global:LogFile, $lines)

        $metrics = Get-LauncherDashboardMetrics `
            -Now ([datetime]::Parse("2026-10-23")) `
            -LogPath $Global:LogFile

        $metrics.LatestApplication | Should Be $null
        $metrics.LatestProject.Name | Should Be "Valid project"
        $metrics.ExecutionsToday | Should Be 0
    }

    It "Escribe proyectos sin entorno/usuario en un formato que el dashboard puede parsear" {
        Write-ProjectLog -Environment "" -User "" -Project "Folder | only"

        $line = [IO.File]::ReadAllText($Global:LogFile).Trim()
        $line | Should Match '\| PROJECT \| - \| - \| Folder / only$'
        (Get-LauncherDashboardMetrics -LogPath $Global:LogFile).LatestProject.Name | Should Be "Folder / only"
    }

    It "Limpia los logs sin borrar archivos de configuración" {
        Write-LauncherLog -Environment "DEV" -User "test-user" -Application "SSMS"
        Clear-LauncherLogs

        [string]::IsNullOrWhiteSpace([IO.File]::ReadAllText($Global:LogFile)) | Should Be $true
        Test-Path -LiteralPath (Join-Path $Global:ConfigFolder "users.json") | Should Be $true
    }
}
