function Show-QuickLinksForm {

    $formLinks = New-Object System.Windows.Forms.Form
    $formLinks.Text = "Administración de Accesos Web"
    $formLinks.ClientSize = New-Object Drawing.Size(860,520)
    $formLinks.MinimumSize = New-Object Drawing.Size(760,480)
    $formLinks.StartPosition = "CenterParent"
    $formLinks.MaximizeBox = $true
    $formLinks.AutoScroll = $true
    $formLinks.AutoScrollMinSize = New-Object Drawing.Size(820,480)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object Drawing.Point(20,20)
    $list.Size = New-Object Drawing.Size(330,420)
    $list.Anchor = (
        [System.Windows.Forms.AnchorStyles]::Top -bor
        [System.Windows.Forms.AnchorStyles]::Bottom -bor
        [System.Windows.Forms.AnchorStyles]::Left
    )
    $formLinks.Controls.Add($list)

    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Text = "Nombre"
    $lblName.Location = New-Object Drawing.Point(380,25)
    $lblName.AutoSize = $true
    $formLinks.Controls.Add($lblName)

    $txtName = New-Object System.Windows.Forms.TextBox
    $txtName.Location = New-Object Drawing.Point(380,50)
    $txtName.Width = 420
    $txtName.Anchor = (
        [System.Windows.Forms.AnchorStyles]::Top -bor
        [System.Windows.Forms.AnchorStyles]::Left -bor
        [System.Windows.Forms.AnchorStyles]::Right
    )
    $formLinks.Controls.Add($txtName)

    $lblUrl = New-Object System.Windows.Forms.Label
    $lblUrl.Text = "URL (HTTP o HTTPS)"
    $lblUrl.Location = New-Object Drawing.Point(380,100)
    $lblUrl.AutoSize = $true
    $formLinks.Controls.Add($lblUrl)

    $txtUrl = New-Object System.Windows.Forms.TextBox
    $txtUrl.Location = New-Object Drawing.Point(380,125)
    $txtUrl.Width = 420
    $txtUrl.Anchor = (
        [System.Windows.Forms.AnchorStyles]::Top -bor
        [System.Windows.Forms.AnchorStyles]::Left -bor
        [System.Windows.Forms.AnchorStyles]::Right
    )
    $formLinks.Controls.Add($txtUrl)

    function Refresh-QuickLinksList {

        $links = @(Get-QuickLinks)
        $list.Items.Clear()
        $list.Tag = $links

        foreach($link in $links){

            $name = [string]$link.name
            if([string]::IsNullOrWhiteSpace($name)){
                $name = "(Sin nombre)"
            }

            [void]$list.Items.Add($name)
        }
    }

    function Clear-QuickLinkFields {

        $txtName.Clear()
        $txtUrl.Clear()
        $list.ClearSelected()
    }

    Refresh-QuickLinksList

    $list.Add_SelectedIndexChanged({

        if($list.SelectedIndex -lt 0){
            return
        }

        $links = @($list.Tag)
        $selected = $links[$list.SelectedIndex]
        $txtName.Text = [string]$selected.name
        $txtUrl.Text = [string]$selected.url
    })

    $btnNew = New-Object System.Windows.Forms.Button
    $btnNew.Text = "Nuevo"
    $btnNew.Location = New-Object Drawing.Point(380,190)
    $btnNew.Size = New-Object Drawing.Size(120,35)
    $btnNew.Add_Click({ Clear-QuickLinkFields })
    $formLinks.Controls.Add($btnNew)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Guardar"
    $btnSave.Location = New-Object Drawing.Point(520,190)
    $btnSave.Size = New-Object Drawing.Size(120,35)
    $btnSave.Add_Click({

        $link = [PSCustomObject]@{
            name = $txtName.Text
            url = $txtUrl.Text
        }

        try{

            $links = @($list.Tag)
            if($list.SelectedIndex -ge 0){
                $links[$list.SelectedIndex] = $link
            }
            else{
                $links += $link
            }

            Save-QuickLinks -Links $links
            Refresh-QuickLinksList
            Clear-QuickLinkFields
            Show-Info "Acceso web guardado."

        }
        catch{
            Show-Error $_.Exception.Message
        }
    })
    $formLinks.Controls.Add($btnSave)

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "Eliminar"
    $btnDelete.Location = New-Object Drawing.Point(660,190)
    $btnDelete.Size = New-Object Drawing.Size(120,35)
    $btnDelete.Add_Click({

        if($list.SelectedIndex -lt 0){
            Show-Error "Seleccione un acceso web para eliminar."
            return
        }

        try{

            $links = @($list.Tag)
            $remainingLinks = @()
            for($index = 0; $index -lt $links.Count; $index++){
                if($index -ne $list.SelectedIndex){
                    $remainingLinks += $links[$index]
                }
            }

            Save-QuickLinks -Links $remainingLinks
            Refresh-QuickLinksList
            Clear-QuickLinkFields
            Show-Info "Acceso web eliminado."

        }
        catch{
            Show-Error $_.Exception.Message
        }
    })
    $formLinks.Controls.Add($btnDelete)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Cerrar"
    $btnClose.Location = New-Object Drawing.Point(660,405)
    $btnClose.Size = New-Object Drawing.Size(120,35)
    $btnClose.Anchor = (
        [System.Windows.Forms.AnchorStyles]::Bottom -bor
        [System.Windows.Forms.AnchorStyles]::Right
    )
    $btnClose.Add_Click({ $formLinks.Close() })
    $formLinks.Controls.Add($btnClose)

    [void]$formLinks.ShowDialog()
}