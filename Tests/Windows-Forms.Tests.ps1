. (Join-Path $PSScriptRoot "TestSupport.ps1")

Describe "Windows Forms: smoke tests de pantallas por funcionalidad" {

    BeforeEach {
        $script:testRoot = New-AONTestRoot
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        . (Join-Path $script:AONTestRepositoryRoot "Modules\UserManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\FavoriteManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\QuickLinks.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\ProfileManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\ProjectsForm.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\UsersForm.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\FavoriteForm.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\QuickLinksForm.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\CredentialManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\CredentialForm.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\LogManager.ps1")
        . (Join-Path $script:AONTestRepositoryRoot "Modules\UiHelpers.ps1")
        $Global:LogFile = Join-Path $Global:LogFolder "launcher.log"
    }

    AfterEach {
        if($script:clipboardTimer){
            $script:clipboardTimer.Stop()
            $script:clipboardTimer.Dispose()
            $script:clipboardTimer = $null
        }
        Remove-AONTestRoot $script:testRoot
    }

    It "La pantalla de usuarios abre con lista, entrada, comandos e información de usuario predeterminado" {
        $mainUserCombo = New-Object System.Windows.Forms.ComboBox
        $Global:AONTestFormSnapshot = $null
        Invoke-AONWinFormsDialog `
            -Title "Administración de Usuarios" `
            -ShowForm { Show-UsersForm $mainUserCombo } `
            -OnShown {
                param($form)
                $controls = @([AONLauncherTestControlWalker]::GetDescendants($form))
                $Global:AONTestFormSnapshot = [PSCustomObject]@{
                    ControlCount = $controls.Count
                    HasUserList = @($controls | Where-Object {$_ -is [System.Windows.Forms.ListBox]}).Count -gt 0
                    HasSaveButton = @($controls | Where-Object {$_.Text -eq "Guardar"}).Count -gt 0
                    HasDefaultUserInfo = @($controls | Where-Object {$_.Text -like "*usuario predeterminado*"}).Count -gt 0
                }
            } | Out-Null

        $Global:AONTestFormSnapshot.HasUserList | Should Be $true
        $Global:AONTestFormSnapshot.HasSaveButton | Should Be $true
        $Global:AONTestFormSnapshot.HasDefaultUserInfo | Should Be $true
    }

    It "La pantalla de favoritos muestra selección de usuario, entorno y aplicación" {
        $Global:AONTestFormSnapshot = $null
        Invoke-AONWinFormsDialog `
            -Title "Favoritos" `
            -ShowForm { Show-FavoriteForm } `
            -OnShown {
                param($form)
                $controls = @([AONLauncherTestControlWalker]::GetDescendants($form))
                $Global:AONTestFormSnapshot = [PSCustomObject]@{
                    ComboCount = @($controls | Where-Object {$_ -is [System.Windows.Forms.ComboBox]}).Count
                    HasLaunchButton = @($controls | Where-Object {$_.Text -eq "Ejecutar"}).Count -gt 0
                    HasSaveButton = @($controls | Where-Object {$_.Text -eq "Guardar"}).Count -gt 0
                }
            } | Out-Null

        $Global:AONTestFormSnapshot.ComboCount | Should Be 3
        $Global:AONTestFormSnapshot.HasLaunchButton | Should Be $true
        $Global:AONTestFormSnapshot.HasSaveButton | Should Be $true
    }

    It "La pantalla de proyectos presenta acciones configurables y lista dinámica" {
        $Global:AONTestFormSnapshot = $null
        Invoke-AONWinFormsDialog `
            -Title "Administración de Proyectos" `
            -ShowForm { Show-ProjectsForm } `
            -OnShown {
                param($form)
                $controls = @([AONLauncherTestControlWalker]::GetDescendants($form))
                $Global:AONTestFormSnapshot = [PSCustomObject]@{
                    HasProjectList = @($controls | Where-Object {$_ -is [System.Windows.Forms.ListBox]}).Count -gt 0
                    StartupApps = @($controls | Where-Object {$_ -is [System.Windows.Forms.CheckBox]}).Count
                    HasSaveButton = @($controls | Where-Object {$_.Text -eq "Guardar"}).Count -gt 0
                    HasDeleteButton = @($controls | Where-Object {$_.Text -eq "Eliminar"}).Count -gt 0
                }
            } | Out-Null

        $Global:AONTestFormSnapshot.HasProjectList | Should Be $true
        $Global:AONTestFormSnapshot.StartupApps | Should Be 4
        $Global:AONTestFormSnapshot.HasSaveButton | Should Be $true
        $Global:AONTestFormSnapshot.HasDeleteButton | Should Be $true
    }

    It "La pantalla de accesos web conserva desplazamiento y comandos de gestión" {
        $Global:AONTestFormSnapshot = $null
        Invoke-AONWinFormsDialog `
            -Title "Administración de Accesos Web" `
            -ShowForm { Show-QuickLinksForm } `
            -OnShown {
                param($form)
                $controls = @([AONLauncherTestControlWalker]::GetDescendants($form))
                $Global:AONTestFormSnapshot = [PSCustomObject]@{
                    AutoScroll = $form.AutoScroll
                    HasList = @($controls | Where-Object {$_ -is [System.Windows.Forms.ListBox]}).Count -gt 0
                    HasSaveButton = @($controls | Where-Object {$_.Text -eq "Guardar"}).Count -gt 0
                    HasDeleteButton = @($controls | Where-Object {$_.Text -eq "Eliminar"}).Count -gt 0
                }
            } | Out-Null

        $Global:AONTestFormSnapshot.AutoScroll | Should Be $true
        $Global:AONTestFormSnapshot.HasList | Should Be $true
        $Global:AONTestFormSnapshot.HasSaveButton | Should Be $true
        $Global:AONTestFormSnapshot.HasDeleteButton | Should Be $true
    }

    It "La pantalla de credenciales tiene campos protegidos y acciones esperadas" {
        $Global:AONTestFormSnapshot = $null
        Invoke-AONWinFormsDialog `
            -Title "Administración de Credenciales" `
            -ShowForm { Show-CredentialForm -Users @("test-user") -Owner $null } `
            -OnShown {
                param($form)
                $controls = @([AONLauncherTestControlWalker]::GetDescendants($form))
                $passwordBox = @($controls | Where-Object {$_ -is [System.Windows.Forms.TextBox]})[0]
                $Global:AONTestFormSnapshot = [PSCustomObject]@{
                    PasswordMasked = $passwordBox.UseSystemPasswordChar
                    HasVerify = @($controls | Where-Object {$_.Text -eq "Verificar"}).Count -gt 0
                    HasCopy = @($controls | Where-Object {$_.Text -eq "Copiar Contraseña"}).Count -gt 0
                    HasDelete = @($controls | Where-Object {$_.Text -eq "Eliminar"}).Count -gt 0
                }
            } | Out-Null

        $Global:AONTestFormSnapshot.PasswordMasked | Should Be $true
        $Global:AONTestFormSnapshot.HasVerify | Should Be $true
        $Global:AONTestFormSnapshot.HasCopy | Should Be $true
        $Global:AONTestFormSnapshot.HasDelete | Should Be $true
    }
}
