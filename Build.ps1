Install-Module ps2exe `
    -Scope CurrentUser `
    -Force

Invoke-PS2EXE `
    .\Launcher.ps1 `
    .\AONLauncher.exe `
    -noConsole