function Show-FavoriteForm {

    $formFav = New-Object System.Windows.Forms.Form

    $formFav.Text = "Favoritos"
    $formFav.Width = 850
    $formFav.Height = 500
    $formFav.StartPosition = "CenterParent"
    $formFav.MaximizeBox = $false

    # ==================================
    # LISTA
    # ==================================

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object Drawing.Point(20,20)
    $list.Size = New-Object Drawing.Size(300,380)

    $formFav.Controls.Add($list)

    # ==================================
    # NOMBRE
    # ==================================

    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Text = "Nombre"
    $lblName.Location = New-Object Drawing.Point(360,20)

    $formFav.Controls.Add($lblName)

    $txtName = New-Object System.Windows.Forms.TextBox
    $txtName.Location = New-Object Drawing.Point(360,45)
    $txtName.Width = 400

    $formFav.Controls.Add($txtName)

    # ==================================
    # USUARIO
    # ==================================

    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = "Usuario"
    $lblUser.Location = New-Object Drawing.Point(360,90)

    $formFav.Controls.Add($lblUser)

    $cmbUser = New-Object System.Windows.Forms.ComboBox
    $cmbUser.Location = New-Object Drawing.Point(360,115)
    $cmbUser.Width = 250

    (Get-Users).users |
    ForEach-Object {

        [void]$cmbUser.Items.Add($_)

    }

    $formFav.Controls.Add($cmbUser)

    # ==================================
    # ENTORNO
    # ==================================

    $lblEnv = New-Object System.Windows.Forms.Label
    $lblEnv.Text = "Entorno"
    $lblEnv.Location = New-Object Drawing.Point(360,160)

    $formFav.Controls.Add($lblEnv)

    $cmbEnv = New-Object System.Windows.Forms.ComboBox
    $cmbEnv.Location = New-Object Drawing.Point(360,185)
    $cmbEnv.Width = 250

    @("DEV","QC","PROD") |
    ForEach-Object {

        [void]$cmbEnv.Items.Add($_)

    }

    $formFav.Controls.Add($cmbEnv)

    # ==================================
    # APLICACIÓN
    # ==================================

    $lblApp = New-Object System.Windows.Forms.Label
    $lblApp.Text = "Aplicación"
    $lblApp.Location = New-Object Drawing.Point(360,230)

    $formFav.Controls.Add($lblApp)

    $cmbApp = New-Object System.Windows.Forms.ComboBox
    $cmbApp.Location = New-Object Drawing.Point(360,255)
    $cmbApp.Width = 250

    @(
        "SSMS",
        "VisualStudio",
        "VSCode",
        "ReportBuilder"
    ) |
    ForEach-Object {

        [void]$cmbApp.Items.Add($_)

    }

    $formFav.Controls.Add($cmbApp)

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
                $null -eq $item.Name `
                -or
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
    # CARGAR DETALLE
    # ==================================

    $list.Add_SelectedIndexChanged({

        if($null -eq $list.SelectedItem){
            return
        }

        $selected =
            $list.SelectedItem.ToString()

        $favorite =
            (Get-Favorites).favorites |
            Where-Object {
                $_.Name -eq $selected
            } |
            Select-Object -First 1

        if($favorite){

            $txtName.Text       = $favorite.Name
            $cmbUser.Text       = $favorite.User
            $cmbEnv.Text        = $favorite.Environment
            $cmbApp.Text        = $favorite.Application

        }

    })

    # ==================================
    # NUEVO
    # ==================================

    $btnNew = New-Object System.Windows.Forms.Button
    $btnNew.Text = "Nuevo"
    $btnNew.Location = New-Object Drawing.Point(360,320)
    $btnNew.Size = New-Object Drawing.Size(120,35)

    $btnNew.Add_Click({

        $txtName.Clear()

        $cmbUser.SelectedIndex = -1
        $cmbEnv.SelectedIndex = -1
        $cmbApp.SelectedIndex = -1

        $list.ClearSelected()

    })

    $formFav.Controls.Add($btnNew)

    # ==================================
# GUARDAR
# ==================================

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Guardar"
$btnSave.Location = New-Object Drawing.Point(500,320)
$btnSave.Size = New-Object Drawing.Size(120,35)

$btnSave.Add_Click({

    if([string]::IsNullOrWhiteSpace($txtName.Text)){
        Show-Error "Nombre obligatorio."
        return
    }

    if([string]::IsNullOrWhiteSpace($cmbUser.Text)){
        Show-Error "Seleccione un usuario."
        return
    }

    if([string]::IsNullOrWhiteSpace($cmbEnv.Text)){
        Show-Error "Seleccione un entorno."
        return
    }

    if([string]::IsNullOrWhiteSpace($cmbApp.Text)){
        Show-Error "Seleccione una aplicación."
        return
    }

    $favorites = Get-Favorites

    if($null -eq $favorites.favorites){
        $favorites.favorites = @()
    }

    $favorites.favorites =
    @(
        $favorites.favorites |
        Where-Object {
            $_.Name -ne $txtName.Text
        }
    )

    $favorites.favorites +=
    [PSCustomObject]@{

        Name        = $txtName.Text.Trim()
        User        = $cmbUser.Text
        Environment = $cmbEnv.Text
        Application = $cmbApp.Text

    }

    Save-Favorites $favorites

    Refresh-Favorites

    Show-Info "Favorito guardado."

})

$formFav.Controls.Add($btnSave)

# ==================================
# ELIMINAR
# ==================================

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Eliminar"
$btnDelete.Location = New-Object Drawing.Point(640,320)
$btnDelete.Size = New-Object Drawing.Size(120,35)

$btnDelete.Add_Click({

    if([string]::IsNullOrWhiteSpace($txtName.Text)){
        return
    }

    Remove-Favorite $txtName.Text

    Refresh-Favorites

    $txtName.Clear()
    $cmbUser.SelectedIndex = -1
    $cmbEnv.SelectedIndex = -1
    $cmbApp.SelectedIndex = -1

    Show-Info "Favorito eliminado."

})

$formFav.Controls.Add($btnDelete)

# ==================================
# EJECUTAR
# ==================================

$btnLaunch = New-Object System.Windows.Forms.Button
$btnLaunch.Text = "Ejecutar"
$btnLaunch.Location = New-Object Drawing.Point(360,370)
$btnLaunch.Size = New-Object Drawing.Size(190,40)

$btnLaunch.Add_Click({

    try{

        Start-AONApplication `
            $cmbApp.Text `
            $cmbEnv.Text `
            $cmbUser.Text

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
$btnClose.Location = New-Object Drawing.Point(570,370)
$btnClose.Size = New-Object Drawing.Size(190,40)

$btnClose.Add_Click({

    $formFav.Close()

})

$formFav.Controls.Add($btnClose)

# ==================================
# SHOW
# ==================================

[void]$formFav.ShowDialog()

}