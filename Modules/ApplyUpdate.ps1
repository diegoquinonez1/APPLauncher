param(
    [Parameter(Mandatory = $true)]
    [string]$RequestBase64
)

function Show-UpdateMessage {

    param(
        [string]$Message,
        [string]$Title,
        [System.Windows.Forms.MessageBoxIcon]$Icon
    )

    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $Icon
    )
}

function Get-SafeUpdateRelativePath {

    param(
        [string]$RelativePath
    )

    if([string]::IsNullOrWhiteSpace($RelativePath)){
        throw "El manifiesto del paquete contiene una ruta vacía."
    }

    $normalizedPath = $RelativePath.Replace("\", "/")
    if(
        $normalizedPath.StartsWith("/") -or
        $normalizedPath -match '^[A-Za-z]:' -or
        $normalizedPath -match '[<>:"|?*]' -or
        $normalizedPath -match '[\x00-\x1F]'
    ){
        throw "El manifiesto contiene una ruta no permitida."
    }

    $segments = @($normalizedPath.Split('/'))
    foreach($segment in $segments){
        if(
            [string]::IsNullOrWhiteSpace($segment) -or
            $segment -eq "." -or
            $segment -eq ".."
        ){
            throw "El manifiesto contiene una ruta no permitida."
        }
    }

    if($segments[0] -notin @(
        "Launcher.ps1",
        "Launcher.version",
        "Launcher.bat",
        "LanzadorHerramientasAdm.bat",
        "APPLauncher.exe",
        "Build.ps1",
        "Modules",
        "Assets"
    )){
        throw "El paquete intenta modificar archivos fuera del Launcher."
    }

    if(
        $segments.Count -eq 1 -and
        $segments[0] -in @("Modules", "Assets")
    ){
        throw "El manifiesto debe enumerar archivos, no directorios."
    }

    return ($segments -join "/")
}

function Resolve-UpdateDestination {

    param(
        [string]$InstallRoot,
        [string]$RelativePath
    )

    $fullRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\') + '\'
    $destination = [IO.Path]::GetFullPath(
        (Join-Path $fullRoot ($RelativePath.Replace("/", [IO.Path]::DirectorySeparatorChar)))
    )
    if(-not $destination.StartsWith($fullRoot, [StringComparison]::OrdinalIgnoreCase)){
        throw "La ruta de destino sale del directorio del Launcher."
    }

    return $destination
}

$temporaryRoot = $null
$appliedFiles = @()
$updateSucceeded = $false
$backupPath = $null

try{
    $requestJson = [Text.Encoding]::UTF8.GetString(
        [Convert]::FromBase64String($RequestBase64)
    )
    $request = $requestJson | ConvertFrom-Json -ErrorAction Stop
    $installRoot = [IO.Path]::GetFullPath([string]$request.installRoot)
    $stageRoot = [IO.Path]::GetFullPath([string]$request.stagePath)
    $temporaryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $stageRoot))
    $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'

    if(!(Test-Path -LiteralPath $installRoot -PathType Container)){
        throw "No se encuentra el directorio de instalación."
    }
    if(-not $temporaryRoot.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase)){
        throw "El área temporal de actualización no es válida."
    }
    if(!(Test-Path -LiteralPath $stageRoot -PathType Container)){
        throw "No se encuentra el paquete preparado para actualizar."
    }

    $manifestPath = Join-Path $stageRoot "update.json"
    $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json -ErrorAction Stop
    if([string]$manifest.version -cne [string]$request.version){
        throw "La versión del paquete preparado no coincide con la solicitud."
    }

    $manifestFiles = @($manifest.files)
    if($manifestFiles.Count -eq 0 -or $manifestFiles.Count -gt 500){
        throw "El manifiesto no contiene una cantidad válida de archivos."
    }

    $seenPaths = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
    foreach($file in $manifestFiles){
        $relativePath = Get-SafeUpdateRelativePath ([string]$file.path)
        $stagedFile = Join-Path $stageRoot ($relativePath.Replace("/", [IO.Path]::DirectorySeparatorChar))
        if(
            $seenPaths.ContainsKey($relativePath) -or
            !(Test-Path -LiteralPath $stagedFile -PathType Leaf) -or
            [string]$file.sha256 -notmatch '^[A-Fa-f0-9]{64}$'
        ){
            throw "El manifiesto del paquete preparado no es válido."
        }

        $actualHash = (Get-FileHash -LiteralPath $stagedFile -Algorithm SHA256).Hash.ToLowerInvariant()
        if($actualHash -cne [string]$file.sha256){
            throw "El archivo preparado fue alterado: $relativePath"
        }
        $seenPaths.Add($relativePath, $file)
    }

    if($seenPaths.Count -ne ($manifestFiles | Measure-Object).Count){
        throw "El manifiesto contiene archivos duplicados."
    }

    if(Get-Process -Id ([int]$request.parentProcessId) -ErrorAction SilentlyContinue){
        Wait-Process -Id ([int]$request.parentProcessId) -Timeout 120 -ErrorAction SilentlyContinue
    }
    if(Get-Process -Id ([int]$request.parentProcessId) -ErrorAction SilentlyContinue){
        throw "El Launcher sigue abierto; no se aplicó la actualización."
    }

    $backupPath = Join-Path ([string]$request.backupRoot) (
        "Update_" + (Get-Date -Format "yyyyMMdd_HHmmss_fff")
    )
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    try{
        foreach($relativePath in $seenPaths.Keys){
            $destination = Resolve-UpdateDestination $installRoot $relativePath
            $stagedFile = Join-Path $stageRoot ($relativePath.Replace("/", [IO.Path]::DirectorySeparatorChar))
            $backupFile = Join-Path $backupPath ($relativePath.Replace("/", [IO.Path]::DirectorySeparatorChar))
            $destinationDirectory = Split-Path -Parent $destination
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null

            $existedBefore = Test-Path -LiteralPath $destination -PathType Leaf
            if($existedBefore){
                $backupDirectory = Split-Path -Parent $backupFile
                New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
                Copy-Item -LiteralPath $destination -Destination $backupFile -Force
            }

            $appliedFiles += [PSCustomObject]@{
                Destination = $destination
                Backup = $backupFile
                ExistedBefore = $existedBefore
            }
            Copy-Item -LiteralPath $stagedFile -Destination $destination -Force
        }
        $updateSucceeded = $true
    }
    catch{
        for($index = $appliedFiles.Count - 1; $index -ge 0; $index--){
            $applied = $appliedFiles[$index]
            if($applied.ExistedBefore -and (Test-Path -LiteralPath $applied.Backup -PathType Leaf)){
                Copy-Item -LiteralPath $applied.Backup -Destination $applied.Destination -Force
            }
            elseif(Test-Path -LiteralPath $applied.Destination -PathType Leaf){
                Remove-Item -LiteralPath $applied.Destination -Force
            }
        }
        throw
    }

    Show-UpdateMessage `
        "Se instaló la versión $($request.version). El Launcher se reiniciará." `
        "Actualización completada" `
        ([System.Windows.Forms.MessageBoxIcon]::Information)

    try{
        Start-Process `
            -FilePath ([string]$request.restartExecutable) `
            -ArgumentList ([string]$request.restartArguments) `
            -WindowStyle Hidden | Out-Null
    }
    catch{
        Show-UpdateMessage `
            "La versión $($request.version) quedó instalada, pero no se pudo reiniciar automáticamente. Inicie el Launcher manualmente." `
            "Actualización aplicada" `
            ([System.Windows.Forms.MessageBoxIcon]::Warning)
    }
}
catch{
    $failureMessage = $_.Exception.Message
    if(-not $updateSucceeded -and $appliedFiles.Count -gt 0){
        for($index = $appliedFiles.Count - 1; $index -ge 0; $index--){
            $applied = $appliedFiles[$index]
            try{
                if($applied.ExistedBefore -and (Test-Path -LiteralPath $applied.Backup -PathType Leaf)){
                    Copy-Item -LiteralPath $applied.Backup -Destination $applied.Destination -Force
                }
                elseif(Test-Path -LiteralPath $applied.Destination -PathType Leaf){
                    Remove-Item -LiteralPath $applied.Destination -Force
                }
            }
            catch{
                $failureMessage += "`nNo se pudo restaurar $($applied.Destination): $($_.Exception.Message)"
            }
        }
    }

    Show-UpdateMessage `
        "No se pudo completar la actualización. No se inició una nueva versión.`n`n$failureMessage" `
        "Error de actualización" `
        ([System.Windows.Forms.MessageBoxIcon]::Error)
}
finally{
    if($temporaryRoot -and (Test-Path -LiteralPath $temporaryRoot)){
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
