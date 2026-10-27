function Show-Info {

    param(
        [string]$Message
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "APPLauncher",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

}

function Show-Warning {

    param(
        [string]$Message
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "Advertencia",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

}

function Show-Error {

    param(
        [string]$Message
    )

    Write-ErrorLog $Message

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )

}

function Invoke-Safely {

    param(
        [scriptblock]$Action
    )

    try {

        & $Action

    }
    catch {

        Show-Error $_.Exception.Message

    }

}