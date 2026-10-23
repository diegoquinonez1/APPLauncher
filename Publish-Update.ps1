[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [string]$SourceRoot = $PSScriptRoot,

    [switch]$Force
)

$parsedVersion = [version]::MinValue
if(-not [version]::TryParse($Version, [ref]$parsedVersion)){
    throw "La versión debe ser numérica, por ejemplo 4.5.0."
}
$sourceRootPath = [IO.Path]::GetFullPath($SourceRoot)
$repositoryRoot = [IO.Path]::GetFullPath($RepositoryPath)
if(!(Test-Path -LiteralPath $sourceRootPath -PathType Container)){
    throw "No existe el directorio de origen: $sourceRootPath"
}

$launcherScript = Join-Path $sourceRootPath "Launcher.ps1"
$launcherVersionFile = Join-Path $sourceRootPath "Launcher.version"
$modulesDirectory = Join-Path $sourceRootPath "Modules"
if(
    !(Test-Path -LiteralPath $launcherScript -PathType Leaf) -or
    !(Test-Path -LiteralPath $launcherVersionFile -PathType Leaf) -or
    !(Test-Path -LiteralPath $modulesDirectory -PathType Container)
){
    throw "El origen no parece ser la raíz de AON Launcher."
}

$installedVersion = [version]::MinValue
if(-not [version]::TryParse([IO.File]::ReadAllText($launcherVersionFile).Trim(), [ref]$installedVersion)){
    throw "Launcher.version no contiene una versión instalada válida."
}
if($parsedVersion -le $installedVersion){
    throw "La versión publicada debe ser superior a la versión instalada $installedVersion."
}

if(!(Test-Path -LiteralPath $repositoryRoot -PathType Container)){
    New-Item -ItemType Directory -Path $repositoryRoot -Force | Out-Null
}

$packageName = "AONLauncher-$($parsedVersion.ToString(3)).zip"
$packagePath = Join-Path $repositoryRoot $packageName
$versionPath = Join-Path $repositoryRoot "version.json"
if(
    -not $Force -and
    (Test-Path -LiteralPath $packagePath)
){
    throw "Ya existe un paquete para esa versión. Use -Force solo si desea reemplazarlo."
}

if(Test-Path -LiteralPath $versionPath){
    try{
        $publishedManifest = [IO.File]::ReadAllText($versionPath) | ConvertFrom-Json -ErrorAction Stop
        $publishedVersion = [version]::MinValue
        if(-not [version]::TryParse([string]$publishedManifest.version, [ref]$publishedVersion)){
            throw "version.json existente no contiene una versión válida."
        }
    }
    catch{
        throw "No se puede validar la versión publicada actual: $($_.Exception.Message)"
    }

    if($parsedVersion -le $publishedVersion){
        throw "La versión nueva debe ser superior a la última publicada ($publishedVersion)."
    }
}

$temporaryRoot = Join-Path $repositoryRoot (".publish_" + [guid]::NewGuid().ToString("N"))
$packageRoot = Join-Path $temporaryRoot "package"
$temporaryArchive = Join-Path $repositoryRoot ("." + $packageName + ".tmp.zip")
$temporaryVersion = Join-Path $repositoryRoot (".version_" + [guid]::NewGuid().ToString("N") + ".tmp")

try{
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

    $sourceFiles = @((Get-Item -LiteralPath $launcherScript))
    foreach($rootFileName in @(
        "Launcher.bat",
        "LanzadorHerramientasAdm.bat",
        "Build.ps1"
    )){
        $rootFilePath = Join-Path $sourceRootPath $rootFileName
        if(Test-Path -LiteralPath $rootFilePath -PathType Leaf){
            $sourceFiles += Get-Item -LiteralPath $rootFilePath
        }
    }
    $sourceFiles += Get-ChildItem -LiteralPath $modulesDirectory -File -Recurse

    $assetsDirectory = Join-Path $sourceRootPath "Assets"
    if(Test-Path -LiteralPath $assetsDirectory -PathType Container){
        $sourceFiles += Get-ChildItem -LiteralPath $assetsDirectory -File -Recurse
    }

    $executablePath = Join-Path $sourceRootPath "AONLauncher.exe"
    if(Test-Path -LiteralPath $executablePath -PathType Leaf){
        $latestSourceTime = ($sourceFiles | Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum
        $executable = Get-Item -LiteralPath $executablePath
        if($executable.LastWriteTimeUtc -lt $latestSourceTime){
            throw "AONLauncher.exe es anterior a sus fuentes. Ejecute Build.ps1 antes de publicar una actualización."
        }
        $sourceFiles += Get-Item -LiteralPath $executablePath
    }

    $manifestFiles = @()
    foreach($sourceFile in $sourceFiles){
        if($sourceFile.Attributes -band [IO.FileAttributes]::ReparsePoint){
            throw "No se publican archivos de enlace o reparse point: $($sourceFile.FullName)"
        }

        $relativePath = $sourceFile.FullName.Substring($sourceRootPath.Length).TrimStart('\','/')
        $relativePath = $relativePath.Replace('\', '/')
        if(
            $relativePath -ne "Launcher.ps1" -and
            $relativePath -ne "Launcher.bat" -and
            $relativePath -ne "LanzadorHerramientasAdm.bat" -and
            $relativePath -ne "Build.ps1" -and
            $relativePath -ne "AONLauncher.exe" -and
            $relativePath -notlike "Modules/*" -and
            $relativePath -notlike "Assets/*"
        ){
            throw "Archivo fuera de las rutas permitidas: $relativePath"
        }

        $destinationPath = Join-Path $packageRoot ($relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
        $destinationDirectory = Split-Path -Parent $destinationPath
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        [IO.File]::Copy($sourceFile.FullName, $destinationPath, $true)

        $manifestFiles += [PSCustomObject]@{
            path = $relativePath
            sha256 = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }

    $packagedVersionPath = Join-Path $packageRoot "Launcher.version"
    [IO.File]::WriteAllText(
        $packagedVersionPath,
        $parsedVersion.ToString(3),
        (New-Object System.Text.UTF8Encoding($false))
    )
    $manifestFiles += [PSCustomObject]@{
        path = "Launcher.version"
        sha256 = (Get-FileHash -LiteralPath $packagedVersionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    if($manifestFiles.Count -eq 0){
        throw "No hay archivos que publicar."
    }

    $updateManifest = [PSCustomObject]@{
        formatVersion = 1
        version = $parsedVersion.ToString(3)
        files = @($manifestFiles | Sort-Object path)
    } | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText(
        (Join-Path $packageRoot "update.json"),
        $updateManifest,
        (New-Object System.Text.UTF8Encoding($false))
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory(
        $packageRoot,
        $temporaryArchive,
        [IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    $packageHash = (Get-FileHash -LiteralPath $temporaryArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    $versionManifest = [PSCustomObject]@{
        version = $parsedVersion.ToString(3)
        package = $packageName
        sha256 = $packageHash
    } | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText(
        $temporaryVersion,
        $versionManifest,
        (New-Object System.Text.UTF8Encoding($false))
    )

    Move-Item -LiteralPath $temporaryArchive -Destination $packagePath -Force
    Move-Item -LiteralPath $temporaryVersion -Destination $versionPath -Force

    [PSCustomObject]@{
        Version = $parsedVersion.ToString(3)
        PackagePath = $packagePath
        ManifestPath = $versionPath
        Sha256 = $packageHash
        FileCount = $manifestFiles.Count
    }
}
finally{
    foreach($temporaryPath in @($temporaryRoot, $temporaryArchive, $temporaryVersion)){
        if(Test-Path -LiteralPath $temporaryPath){
            Remove-Item -LiteralPath $temporaryPath -Recurse -Force
        }
    }
}
