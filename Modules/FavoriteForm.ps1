function Show-FavoriteForm {

    $formFav = New-Object System.Windows.Forms.Form

    $formFav.Text = "Favoritos"
    $formFav.Width = 700
    $formFav.Height = 450
    $formFav.StartPosition = "CenterParent"
    $formFav.MaximizeBox = $false

    # ==================================
    # LISTA
    # ==================================

    $list = New-Object System.Windows.Forms.ListBox

    $list.Location = New-Object Drawing.Point(20,20)
    $list.Size = New-Object Drawing.Size(420,330)

    $formFav.Controls.Add($list)

    # ==================================
    # REFRESH
    # ==================================

    function Refresh-Favorites {

        $list.Items.Clear()

        $favorites = Get-Favorites

        if($null -eq $favorites){
            return
        }

        if($null -eq $favorites.favorites){
            return
        }

        foreach($item in $favorites.favorites){

            if(
                $null -eq $item.Name -or
                [string]::IsNullOrWhiteSpace($item.Name)
            ){
                continue
            }

            [void]$list.Items.Add(
                $item.Name
            )
        }
    }

    Refresh-Favorites

    # ==================================
    # AGREGAR
    # ==================================

    $btnAdd = New-Object System.Windows.Forms.Button

    $btnAdd.Text = "Agregar"
    $btnAdd.Location = New-Object Drawing.Point(480,20)
    $btnAdd.Size = New-Object Drawing.Size(160,35)

    $btnAdd.Add_Click({

        $name = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Nombre del favorito",
            "Nuevo Favorito"
        )

        if([string]::IsNullOrWhiteSpace($name)){
            return
        }

        $name = $name.Trim()

        $favorites = Get-Favorites

        if($null -eq $favorites.favorites){
            $favorites.favorites = @()
        }

        $exists =
            $favorites.favorites |
            Where-Object {
                $_.Name -eq $name
            }

        if($exists){

            Show-Info "Ya existe un favorito con ese nombre."

            return
        }

        $user = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Usuario",
            "Usuario",
            "adm-A0836618"
        )

        if([string]::IsNullOrWhiteSpace($user)){
            return
        }

        $environment = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Entorno (DEV/QC/PROD)",
            "Entorno",
            "DEV"
        )

        if([string]::IsNullOrWhiteSpace($environment)){
            return
        }

        $environment = $environment.Trim().ToUpper()

        if(
            $environment -notin @(
                "DEV",
                "QC",
                "PROD"
            )
        ){
            Show-Error "Entorno inválido."
            return
        }

        $application = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Aplicación (SSMS, VisualStudio, VSCode, ReportBuilder)",
            "Aplicación",
            "SSMS"
        )

        if([string]::IsNullOrWhiteSpace($application)){
            return
        }

        $application = $application.Trim()

        if(
            $application -notin @(
                "SSMS",
                "VisualStudio",
                "VSCode",
                "ReportBuilder"
            )
        ){
            Show-Error "Aplicación inválida."
            return
        }

        $newItem = [PSCustomObject]@{

            Name        = $name
            Environment = $environment
            User        = $user
            Application = $application
        }

        $favorites.favorites += $newItem

        Save-Favorites $favorites

        Refresh-Favorites

        Show-Info "Favorito agregado."

    })

    $formFav.Controls.Add($btnAdd)

    # ==================================
    # ELIMINAR
    # ==================================

    $btnDelete = New-Object System.Windows.Forms.Button

    $btnDelete.Text = "Eliminar"
    $btnDelete.Location = New-Object Drawing.Point(480,70)
    $btnDelete.Size = New-Object Drawing.Size(160,35)

    $btnDelete.Add_Click({

        if($null -eq $list.SelectedItem){
            return
        }

        $selected =
            $list.SelectedItem.ToString()

        $favorites = Get-Favorites

        $favorites.favorites =
            @(
                $favorites.favorites |
                Where-Object {
                    $_.Name -ne $selected
                }
            )

        Save-Favorites $favorites

        Refresh-Favorites

        Show-Info "Favorito eliminado."

    })

    $formFav.Controls.Add($btnDelete)

    # ==================================
    # EJECUTAR
    # ==================================

    $btnLaunch = New-Object System.Windows.Forms.Button

    $btnLaunch.Text = "Ejecutar"
    $btnLaunch.Location = New-Object Drawing.Point(480,120)
    $btnLaunch.Size = New-Object Drawing.Size(160,35)

    $btnLaunch.Add_Click({

        if($null -eq $list.SelectedItem){
            return
        }

        $selected =
            $list.SelectedItem.ToString()

        $favorites = Get-Favorites

        $item =
            $favorites.favorites |
            Where-Object {
                $_.Name -eq $selected
            } |
            Select-Object -First 1

        if($null -eq $item){

            Show-Error "No se encontró el favorito."

            return
        }

        try{

            Start-AONApplication `
                $item.Application `
                $item.Environment `
                $item.User

        }
        catch{

            Show-Error $_.Exception.Message

        }

    })

    $formFav.Controls.Add($btnLaunch)

    # ==================================
    # CERRAR
    # ==================================

    $btnClose = New-Object System.Windows.Forms.Button

    $btnClose.Text = "Cerrar"
    $btnClose.Location = New-Object Drawing.Point(480,170)
    $btnClose.Size = New-Object Drawing.Size(160,35)

    $btnClose.Add_Click({

        $formFav.Close()

    })

    $formFav.Controls.Add($btnClose)

    # ==================================
    # SHOW
    # ==================================

    [void]$formFav.ShowDialog()
}