function Set-EnvironmentTheme {

    param(
        [System.Windows.Forms.Form]$Form,
        [string]$Environment
    )

    if($null -eq $Form){
        return
    }

    $Form.BackColor = [System.Drawing.Color]::WhiteSmoke

    if($null -ne (Get-Command -Name Get-LauncherEnvironmentColor -ErrorAction SilentlyContinue)){
        $configuredColor = Get-LauncherEnvironmentColor -Environment $Environment
        if($null -ne $configuredColor){
            $Form.BackColor = $configuredColor
            return
        }
    }

    if(-not [string]::IsNullOrWhiteSpace($Environment) -and $null -ne (Get-Command -Name Get-LauncherEnvironmentColor -ErrorAction SilentlyContinue)){
        $Form.BackColor = [System.Drawing.Color]::WhiteSmoke
    }
}