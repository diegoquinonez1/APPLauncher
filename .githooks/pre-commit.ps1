$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$stagedFiles = git diff --cached --name-only --diff-filter=ACMR
if (-not $stagedFiles) {
    Write-Host 'No hay archivos staged para revisar.'
    exit 0
}

$blockedFiles = @()
$patterns = @(
    '(?i)(?<![A-Za-z0-9_])(?:password|passwd|pwd|api[_-]?key|client[_-]?secret|access[_-]?key|token|secret|connectionstring)(?![A-Za-z0-9_])\s*[:=]\s*["\'']?[A-Za-z0-9/+=._:@${}{\\-]{3,}',
    '(?i)BEGIN (RSA|EC|DSA|OPENSSH|PGP) PRIVATE KEY'
)

foreach ($file in $stagedFiles) {
    if (-not $file) { continue }
    if (-not (Test-Path $file)) { continue }

    if ($file -like '.github/*' -or $file -like 'docs/*') {
        continue
    }

    $extension = [IO.Path]::GetExtension($file).ToLowerInvariant()
    $binaryExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico', '.pdf', '.zip', '.jar', '.exe', '.dll', '.pdb', '.woff', '.woff2', '.ttf')
    if ($binaryExtensions -contains $extension) { continue }

    try {
        $content = Get-Content -Path $file -Raw -ErrorAction Stop
    }
    catch {
        continue
    }

    if (-not $content) { continue }

    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            $blockedFiles += $file
            break
        }
    }
}

if ($blockedFiles.Count -gt 0) {
    Write-Host 'ERROR: Se detectaron posibles credenciales o secretos en archivos staged.' -ForegroundColor Red
    foreach ($file in $blockedFiles) {
        Write-Host " - $file" -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host 'Recomendaciones:' -ForegroundColor Cyan
    Write-Host '  1. Mueve las credenciales a variables de entorno o un gestor de secretos.'
    Write-Host '  2. Usa archivos .sample/.example con valores ficticios.'
    Write-Host '  3. Si ya se subio al repositorio, elimina el archivo del index con: git rm --cached <archivo>'
    Write-Host '  4. Revisa si el archivo realmente debe mantenerse en el repo.'
    exit 1
}

Write-Host 'No se detectaron secretos en los archivos staged.' -ForegroundColor Green
exit 0
