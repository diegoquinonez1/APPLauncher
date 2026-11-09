function Set-EnvironmentTheme {

    param(
        [System.Windows.Forms.Form]$Form,
        [string]$Environment
    )

    if($null -eq $Form){
        return
    }

    $Form.BackColor = [System.Drawing.Color]::WhiteSmoke

    if(-not [string]::IsNullOrWhiteSpace($Environment)){
        $hash = 0
        foreach($char in [char[]][string]$Environment){
            $hash += [int][char]$char
        }

        $palette = @(
            [System.Drawing.Color]::WhiteSmoke,
            [System.Drawing.Color]::AliceBlue,
            [System.Drawing.Color]::Lavender,
            [System.Drawing.Color]::Honeydew,
            [System.Drawing.Color]::LemonChiffon
        )

        $selectedIndex = $hash % $palette.Count
        $Form.BackColor = $palette[$selectedIndex]
    }
}