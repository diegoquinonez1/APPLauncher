$versionFile = Join-Path $PSScriptRoot "..\Launcher.version"
$versionText = [IO.File]::ReadAllText($versionFile).Trim()
$script:LauncherVersion = [version]::MinValue
if(-not [version]::TryParse($versionText, [ref]$script:LauncherVersion)){
    throw "Launcher.version no contiene una versión válida."
}

$script:AllowedLauncherUpdateRoots = @(
    "Launcher.ps1",
    "Launcher.version",
    "Launcher.bat",
    "LanzadorHerramientasAdm.bat",
    "APPLauncher.exe",
    "Build.ps1",
    "Modules",
    "Assets"
)

function Get-LauncherUpdateRelease {

    param(
        [string]$UpdateSource
    )

    if([string]::IsNullOrWhiteSpace($UpdateSource)){
        throw "Configure la ruta del repositorio compartido de actualizaciones."
    }

    $sourcePath = [IO.Path]::GetFullPath($UpdateSource)
    if(!(Test-Path -LiteralPath $sourcePath -PathType Container)){
        throw "No se encuentra el repositorio de actualizaciones: $sourcePath"
    }

    $versionFile = Join-Path $sourcePath "version.json"
    if(!(Test-Path -LiteralPath $versionFile -PathType Leaf)){
        throw "No se encontró version.json en el repositorio compartido."
    }

    try{
        $release = [IO.File]::ReadAllText($versionFile) | ConvertFrom-Json -ErrorAction Stop
    }
    catch{
        throw "version.json no contiene JSON válido."
    }

    $availableVersion = [version]::MinValue
    if(-not [version]::TryParse([string]$release.version, [ref]$availableVersion)){
        throw "version.json debe declarar una versión numérica, por ejemplo 4.5.0."
    }

    $packageName = [string]$release.package
    if(
        [string]::IsNullOrWhiteSpace($packageName) -or
        [IO.Path]::GetFileName($packageName) -cne $packageName -or
        $packageName -match '[:\\/]'
    ){
        throw "version.json contiene un nombre de paquete no permitido."
    }

    $expectedHash = [string]$release.sha256
    if($expectedHash -notmatch '^[A-Fa-f0-9]{64}$'){
        throw "version.json debe incluir el SHA-256 de 64 caracteres del paquete."
    }

    $packagePath = Join-Path $sourcePath $packageName
    if(!(Test-Path -LiteralPath $packagePath -PathType Leaf)){
        throw "No se encontró el paquete de actualización: $packageName"
    }

    return [PSCustomObject]@{
        SourcePath = $sourcePath
        Version = $availableVersion
        VersionText = $availableVersion.ToString(3)
        PackagePath = $packagePath
        PackageName = $packageName
        Sha256 = $expectedHash.ToLowerInvariant()
        IsUpdateAvailable = ($availableVersion -gt $script:LauncherVersion)
        CurrentVersion = $script:LauncherVersion
    }
}

function Get-SafeLauncherUpdateRelativePath {

    param(
        [string]$RelativePath
    )

    if([string]::IsNullOrWhiteSpace($RelativePath)){
        throw "El manifiesto contiene una ruta vacía."
    }

    $normalizedPath = $RelativePath.Replace("\", "/")
    if(
        $normalizedPath.StartsWith("/") -or
        $normalizedPath -match '^[A-Za-z]:' -or
        $normalizedPath -match '[<>:"|?*]' -or
        $normalizedPath -match '[\x00-\x1F]'
    ){
        throw "El paquete contiene una ruta de archivo no permitida."
    }

    $segments = @($normalizedPath.Split('/'))
    if($segments.Count -lt 1){
        throw "El paquete contiene una ruta de archivo no permitida."
    }
    foreach($segment in $segments){
        if(
            [string]::IsNullOrWhiteSpace($segment) -or
            $segment -eq "." -or
            $segment -eq ".."
        ){
            throw "El paquete contiene una ruta de archivo no permitida."
        }
    }

    if($segments[0] -notin $script:AllowedLauncherUpdateRoots){
        throw "El paquete intenta modificar una ruta fuera del Launcher: $RelativePath"
    }

    if(
        $segments.Count -eq 1 -and
        $segments[0] -in @("Modules", "Assets")
    ){
        throw "El manifiesto debe enumerar archivos, no directorios."
    }

    return ($segments -join "/")
}

function Expand-VerifiedLauncherUpdate {

    param(
        [object]$Release
    )

    $packageHash = (Get-FileHash -LiteralPath $Release.PackagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if($packageHash -cne $Release.Sha256){
        throw "El SHA-256 del paquete no coincide con version.json."
    }

    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
        "APPLauncherUpdate_" + [guid]::NewGuid().ToString("N")
    )
    $stagePath = Join-Path $temporaryRoot "stage"
    New-Item -ItemType Directory -Path $stagePath -Force | Out-Null

    try{
        Add-Type -AssemblyName System.IO.Compression
        $archive = [IO.Compression.ZipFile]::OpenRead($Release.PackagePath)
        try{
            if($archive.Entries.Count -lt 2 -or $archive.Entries.Count -gt 500){
                throw "El paquete no contiene una cantidad válida de archivos."
            }

            $entriesByName = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
            $totalUncompressedBytes = 0L
            foreach($entry in $archive.Entries){
                $entryName = $entry.FullName.Replace("\", "/")
                if(
                    $entryName.EndsWith("/") -or
                    $entriesByName.ContainsKey($entryName)
                ){
                    throw "El paquete contiene una entrada duplicada o un directorio explícito."
                }
                if($entry.Length -gt 104857600){
                    throw "Un archivo del paquete supera el límite de 100 MB."
                }
                $totalUncompressedBytes += $entry.Length
                if($totalUncompressedBytes -gt 536870912){
                    throw "El paquete supera el límite total de 512 MB descomprimidos."
                }
                $entriesByName.Add($entryName, $entry)
            }

            if(-not $entriesByName.ContainsKey("update.json")){
                throw "El paquete no contiene update.json."
            }

            $manifestStream = $entriesByName["update.json"].Open()
            $manifestReader = New-Object IO.StreamReader($manifestStream)
            try{
                $updateManifest = $manifestReader.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop
            }
            catch{
                throw "update.json no contiene JSON válido."
            }
            finally{
                $manifestReader.Dispose()
                $manifestStream.Dispose()
            }

            $manifestVersion = [version]::MinValue
            if(
                -not [version]::TryParse([string]$updateManifest.version, [ref]$manifestVersion) -or
                $manifestVersion -ne $Release.Version
            ){
                throw "La versión del paquete no coincide con version.json."
            }

            $manifestFiles = @($updateManifest.files)
            if($manifestFiles.Count -eq 0 -or $manifestFiles.Count -ne ($archive.Entries.Count - 1)){
                throw "update.json no describe exactamente los archivos del paquete."
            }

            $listedEntries = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
            foreach($file in $manifestFiles){
                $relativePath = Get-SafeLauncherUpdateRelativePath ([string]$file.path)
                $fileHash = [string]$file.sha256
                if($fileHash -notmatch '^[A-Fa-f0-9]{64}$'){
                    throw "update.json contiene un SHA-256 inválido para $relativePath."
                }
                if(
                    $relativePath -eq "update.json" -or
                    $listedEntries.ContainsKey($relativePath) -or
                    -not $entriesByName.ContainsKey($relativePath)
                ){
                    throw "update.json contiene una ruta duplicada o inexistente: $relativePath"
                }
                $listedEntries.Add($relativePath, $file)
            }

            foreach($entryName in $entriesByName.Keys){
                if($entryName -ne "update.json" -and -not $listedEntries.ContainsKey($entryName)){
                    throw "El paquete contiene un archivo no declarado: $entryName"
                }
            }

            foreach($relativePath in $listedEntries.Keys){
                $destinationPath = Join-Path $stagePath ($relativePath.Replace("/", [IO.Path]::DirectorySeparatorChar))
                $destinationDirectory = Split-Path -Parent $destinationPath
                New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null

                $inputStream = $entriesByName[$relativePath].Open()
                $outputStream = [IO.File]::Create($destinationPath)
                try{
                    $inputStream.CopyTo($outputStream)
                }
                finally{
                    $outputStream.Dispose()
                    $inputStream.Dispose()
                }

                $actualHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash.ToLowerInvariant()
                if($actualHash -cne $listedEntries[$relativePath].sha256){
                    throw "El hash del archivo $relativePath no coincide con update.json."
                }
            }

            [IO.File]::WriteAllText(
                (Join-Path $stagePath "update.json"),
                ($updateManifest | ConvertTo-Json -Depth 10),
                (New-Object System.Text.UTF8Encoding($false))
            )
        }
        finally{
            $archive.Dispose()
        }

        return [PSCustomObject]@{
            TemporaryRoot = $temporaryRoot
            StagePath = $stagePath
            Version = $Release.VersionText
            Files = @($listedEntries.Keys | Sort-Object)
        }
    }
    catch{
        if(Test-Path -LiteralPath $temporaryRoot){
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
        throw
    }
}

function Start-LauncherUpdate {

    param(
        [object]$PreparedUpdate,
        [string]$InstallRoot
    )

    $applyScript = Join-Path $InstallRoot "Modules\ApplyUpdate.ps1"
    if(!(Test-Path -LiteralPath $applyScript -PathType Leaf)){
        throw "No se encontró el instalador auxiliar: $applyScript"
    }

    $currentProcess = [Diagnostics.Process]::GetCurrentProcess()
    $restartScript = Join-Path $InstallRoot "Launcher.ps1"
    if(!(Test-Path -LiteralPath $restartScript -PathType Leaf)){
        throw "No se encontró Launcher.ps1 para reiniciar la versión actualizada."
    }

    $powerShellPath = Join-Path $PSHOME "powershell.exe"
    if(!(Test-Path -LiteralPath $powerShellPath -PathType Leaf)){
        $powerShellPath = Join-Path $PSHOME "pwsh.exe"
    }
    if(!(Test-Path -LiteralPath $powerShellPath -PathType Leaf)){
        $powerShellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
    }
    $restartArguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$restartScript`""

    $request = [PSCustomObject]@{
        installRoot = [IO.Path]::GetFullPath($InstallRoot)
        stagePath = [IO.Path]::GetFullPath($PreparedUpdate.StagePath)
        backupRoot = Join-Path $InstallRoot "Backups"
        parentProcessId = $currentProcess.Id
        restartExecutable = $powerShellPath
        restartArguments = $restartArguments
        version = $PreparedUpdate.Version
    } | ConvertTo-Json -Compress

    $requestBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($request))
    $escapedApplyScript = $applyScript.Replace("'", "''")
    $command = "& '$escapedApplyScript' -RequestBase64 '$requestBase64'"
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    Start-Process `
        -FilePath $powerShellPath `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand" `
        -WindowStyle Hidden
}
