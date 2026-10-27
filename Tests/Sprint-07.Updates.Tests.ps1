. (Join-Path $PSScriptRoot "TestSupport.ps1")

function New-APPLauncherUpdateFixture {

    param(
        [string]$Root,
        [string]$Version = "4.5.0",
        [string]$RelativePath = "Launcher.ps1",
        [string]$Content = "updated launcher"
    )

    $repository = Join-Path $Root "repository"
    $stage = Join-Path $Root "package-stage"
    New-Item -ItemType Directory -Path $repository,$stage -Force | Out-Null

    $stagedFile = Join-Path $stage ($RelativePath.Replace("/", [IO.Path]::DirectorySeparatorChar))
    New-APPLauncherTestFile -Path $stagedFile -Content $Content | Out-Null
    $fileHash = (Get-FileHash -LiteralPath $stagedFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $updateManifest = [PSCustomObject]@{
        formatVersion = 1
        version = $Version
        files = @([PSCustomObject]@{path=$RelativePath;sha256=$fileHash})
    } | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText((Join-Path $stage "update.json"), $updateManifest)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $packageName = "APPLauncher-$Version.zip"
    $packagePath = Join-Path $repository $packageName
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $packagePath)
    $packageHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $versionManifest = [PSCustomObject]@{
        version = $Version
        package = $packageName
        sha256 = $packageHash
    } | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText((Join-Path $repository "version.json"), $versionManifest)

    return [PSCustomObject]@{
        Repository = $repository
        PackagePath = $packagePath
        Stage = $stage
        PackageName = $packageName
        Content = $Content
    }
}

Describe "Sprint 7: comprobación y publicación de actualizaciones" {

    BeforeEach {
        $script:testRoot = New-APPLauncherTestRoot
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        . (Join-Path $script:APPLauncherTestRepositoryRoot "Modules\UpdateManager.ps1")
    }

    AfterEach {
        Remove-APPLauncherTestRoot $script:testRoot
    }

    It "Detecta una versión superior y verifica el ZIP y los archivos al preparar el paquete" {
        $fixture = New-APPLauncherUpdateFixture -Root $script:testRoot
        $release = Get-LauncherUpdateRelease -UpdateSource $fixture.Repository

        $release.IsUpdateAvailable | Should Be $true
        $release.VersionText | Should Be "4.5.0"
        $prepared = Expand-VerifiedLauncherUpdate -Release $release
        try{
            $prepared.Version | Should Be "4.5.0"
            [IO.File]::ReadAllText((Join-Path $prepared.StagePath "Launcher.ps1")) | Should Be $fixture.Content
            $prepared.Files.Count | Should Be 1
        }
        finally{
            Remove-APPLauncherTestRoot $prepared.TemporaryRoot
        }
    }

    It "Indica que no hay actualización cuando la versión disponible no es superior" {
        $fixture = New-APPLauncherUpdateFixture -Root $script:testRoot -Version "4.4.0"

        (Get-LauncherUpdateRelease -UpdateSource $fixture.Repository).IsUpdateAvailable | Should Be $false
    }

    It "Rechaza un hash externo incorrecto y un hash de archivo manipulado" {
        $fixture = New-APPLauncherUpdateFixture -Root $script:testRoot
        $manifestPath = Join-Path $fixture.Repository "version.json"
        $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
        $manifest.sha256 = "0" * 64
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json))

        $release = Get-LauncherUpdateRelease -UpdateSource $fixture.Repository
        (Test-APPLauncherThrows { Expand-VerifiedLauncherUpdate -Release $release }) | Should Be $true

        $fixture = New-APPLauncherUpdateFixture -Root (Join-Path $script:testRoot "tampered")
        $archive = [IO.Compression.ZipFile]::Open($fixture.PackagePath, [IO.Compression.ZipArchiveMode]::Update)
        try{
            $entry = $archive.GetEntry("Launcher.ps1")
            $entry.Delete()
            $replacement = $archive.CreateEntry("Launcher.ps1")
            $writer = New-Object IO.StreamWriter($replacement.Open())
            try{
                $writer.Write("tampered content")
            }
            finally{
                $writer.Dispose()
            }
        }
        finally{
            $archive.Dispose()
        }

        $manifestPath = Join-Path $fixture.Repository "version.json"
        $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
        $manifest.sha256 = (Get-FileHash -LiteralPath $fixture.PackagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json))
        $release = Get-LauncherUpdateRelease -UpdateSource $fixture.Repository

        (Test-APPLauncherThrows { Expand-VerifiedLauncherUpdate -Release $release }) | Should Be $true
    }

    It "Rechaza rutas fuera de los directorios permitidos" {
        foreach($path in @(
            "../Config/credentials.json",
            "Modules/../../Config/settings.json",
            "C:/Windows/win.ini",
            "Config/settings.json"
        )){
            (Test-APPLauncherThrows { Get-SafeLauncherUpdateRelativePath $path }) | Should Be $true
        }

        (Get-SafeLauncherUpdateRelativePath "Modules/Launcher.ps1") | Should Be "Modules/Launcher.ps1"
    }

    It "Publica varias versiones en el mismo repositorio y rechaza downgrade" {
        $source = Join-Path $script:testRoot "source"
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:APPLauncherTestRepositoryRoot "Launcher.ps1") -Destination $source
        Copy-Item -LiteralPath (Join-Path $script:APPLauncherTestRepositoryRoot "Launcher.version") -Destination $source
        Copy-Item -LiteralPath (Join-Path $script:APPLauncherTestRepositoryRoot "Publish-Update.ps1") -Destination $script:testRoot
        Copy-Item -LiteralPath (Join-Path $script:APPLauncherTestRepositoryRoot "Modules") -Destination $source -Recurse
        $repository = Join-Path $script:testRoot "published"
        $publisher = Join-Path $script:testRoot "Publish-Update.ps1"

        $first = & $publisher -Version "4.5.0" -RepositoryPath $repository -SourceRoot $source
        $second = & $publisher -Version "4.6.0" -RepositoryPath $repository -SourceRoot $source

        $first.Version | Should Be "4.5.0"
        $second.Version | Should Be "4.6.0"
        Test-Path -LiteralPath (Join-Path $repository "APPLauncher-4.5.0.zip") | Should Be $true
        (([IO.File]::ReadAllText((Join-Path $repository "version.json")) | ConvertFrom-Json).version) | Should Be "4.6.0"
        (Test-APPLauncherThrows {
            & $publisher -Version "4.4.9" -RepositoryPath $repository -SourceRoot $source | Out-Null
        }) | Should Be $true
    }

    It "Rechaza un APPLauncher.exe anterior a sus fuentes" {
        $source = Join-Path $script:testRoot "stale-source"
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:APPLauncherTestRepositoryRoot "Launcher.ps1") -Destination $source
        Copy-Item -LiteralPath (Join-Path $script:APPLauncherTestRepositoryRoot "Launcher.version") -Destination $source
        Copy-Item -LiteralPath (Join-Path $script:APPLauncherTestRepositoryRoot "Modules") -Destination $source -Recurse
        $staleExe = New-APPLauncherTestFile (Join-Path $source "APPLauncher.exe") "old executable"
        (Get-Item -LiteralPath $staleExe).LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-2)
        $publisher = Join-Path $script:APPLauncherTestRepositoryRoot "Publish-Update.ps1"

        (Test-APPLauncherThrows {
            & $publisher -Version "4.5.0" -RepositoryPath (Join-Path $script:testRoot "stale-published") -SourceRoot $source | Out-Null
        }) | Should Be $true
    }
}
