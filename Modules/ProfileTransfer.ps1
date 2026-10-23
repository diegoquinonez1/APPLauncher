$script:LauncherProfileConfigFiles = @(
    "settings.json",
    "users.json",
    "favorites.json",
    "applications.json",
    "projects.json",
    "links.json"
)

function Get-ProfilePassphraseText {

    param(
        [System.Security.SecureString]$Passphrase
    )

    if($null -eq $Passphrase -or $Passphrase.Length -lt 12){
        throw "La frase de paso debe tener al menos 12 caracteres."
    }

    $pointer = [IntPtr]::Zero
    try{
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Passphrase)
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally{
        if($pointer -ne [IntPtr]::Zero){
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
    }
}

function Protect-LauncherProfilePayload {

    param(
        [string]$PlainText,
        [System.Security.SecureString]$Passphrase
    )

    $passphraseText = Get-ProfilePassphraseText $Passphrase
    $salt = New-Object byte[] 16
    $iv = New-Object byte[] 16
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $derivedKey = $null
    $aes = $null
    $hmac = $null
    $deriveBytes = $null

    try{
        $random.GetBytes($salt)
        $random.GetBytes($iv)
        $deriveBytes = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
            $passphraseText,
            $salt,
            600000
        )
        $derivedKey = $deriveBytes.GetBytes(64)

        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = [byte[]]($derivedKey[32..63])
        $aes.IV = $iv

        $plainBytes = [Text.Encoding]::UTF8.GetBytes($PlainText)
        $encryptor = $aes.CreateEncryptor()
        try{
            $cipherBytes = $encryptor.TransformFinalBlock(
                $plainBytes,
                0,
                $plainBytes.Length
            )
        }
        finally{
            $encryptor.Dispose()
            [Array]::Clear($plainBytes, 0, $plainBytes.Length)
        }

        $saltText = [Convert]::ToBase64String($salt)
        $ivText = [Convert]::ToBase64String($iv)
        $cipherText = [Convert]::ToBase64String($cipherBytes)
        $authenticatedText = "AON-LAUNCHER-PROFILE-V1|600000|$saltText|$ivText|$cipherText"
        $hmac = [System.Security.Cryptography.HMACSHA256]::new(
            [byte[]]($derivedKey[0..31])
        )
        $mac = [Convert]::ToBase64String(
            $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($authenticatedText))
        )

        return [PSCustomObject]@{
            formatVersion = 1
            iterations = 600000
            salt = $saltText
            iv = $ivText
            ciphertext = $cipherText
            mac = $mac
        } | ConvertTo-Json -Compress
    }
    finally{
        $random.Dispose()
        if($null -ne $aes){ $aes.Dispose() }
        if($null -ne $hmac){ $hmac.Dispose() }
        if($null -ne $deriveBytes){ $deriveBytes.Dispose() }
        if($null -ne $derivedKey){ [Array]::Clear($derivedKey, 0, $derivedKey.Length) }
        $passphraseText = $null
    }
}

function Unprotect-LauncherProfilePayload {

    param(
        [string]$ProtectedText,
        [System.Security.SecureString]$Passphrase
    )

    $envelope = $ProtectedText | ConvertFrom-Json
    if(
        $envelope.formatVersion -ne 1 -or
        $envelope.iterations -lt 600000 -or
        $envelope.iterations -gt 1000000
    ){
        throw "El archivo de credenciales del perfil no tiene un formato compatible."
    }

    try{
        $salt = [Convert]::FromBase64String([string]$envelope.salt)
        $iv = [Convert]::FromBase64String([string]$envelope.iv)
        $cipherBytes = [Convert]::FromBase64String([string]$envelope.ciphertext)
        $suppliedMac = [Convert]::FromBase64String([string]$envelope.mac)
    }
    catch{
        throw "El archivo de credenciales del perfil está dañado."
    }

    if($salt.Length -ne 16 -or $iv.Length -ne 16 -or $suppliedMac.Length -ne 32){
        throw "El archivo de credenciales del perfil está dañado."
    }

    $passphraseText = Get-ProfilePassphraseText $Passphrase
    $derivedKey = $null
    $deriveBytes = $null
    $hmac = $null
    $aes = $null

    try{
        $deriveBytes = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
            $passphraseText,
            $salt,
            [int]$envelope.iterations
        )
        $derivedKey = $deriveBytes.GetBytes(64)
        $saltText = [Convert]::ToBase64String($salt)
        $ivText = [Convert]::ToBase64String($iv)
        $cipherText = [Convert]::ToBase64String($cipherBytes)
        $authenticatedText = "AON-LAUNCHER-PROFILE-V1|$($envelope.iterations)|$saltText|$ivText|$cipherText"
        $hmac = [System.Security.Cryptography.HMACSHA256]::new(
            [byte[]]($derivedKey[0..31])
        )
        $expectedMac = $hmac.ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($authenticatedText)
        )

        $difference = 0
        for($index = 0; $index -lt $expectedMac.Length; $index++){
            $difference = $difference -bor ($expectedMac[$index] -bxor $suppliedMac[$index])
        }
        if($difference -ne 0){
            throw "La frase de paso no es correcta o el archivo fue alterado."
        }

        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = [byte[]]($derivedKey[32..63])
        $aes.IV = $iv

        $decryptor = $aes.CreateDecryptor()
        try{
            $plainBytes = $decryptor.TransformFinalBlock(
                $cipherBytes,
                0,
                $cipherBytes.Length
            )
            return [Text.Encoding]::UTF8.GetString($plainBytes)
        }
        finally{
            $decryptor.Dispose()
            if($null -ne $plainBytes){ [Array]::Clear($plainBytes, 0, $plainBytes.Length) }
        }
    }
    finally{
        if($null -ne $aes){ $aes.Dispose() }
        if($null -ne $hmac){ $hmac.Dispose() }
        if($null -ne $deriveBytes){ $deriveBytes.Dispose() }
        if($null -ne $derivedKey){ [Array]::Clear($derivedKey, 0, $derivedKey.Length) }
        $passphraseText = $null
    }
}

function Show-LauncherProfilePassphraseDialog {

    param(
        [string]$Title,
        [bool]$ConfirmPassphrase,
        [System.Windows.Forms.IWin32Window]$Owner
    )

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $Title
    $dialog.ClientSize = New-Object Drawing.Size(440,210)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = "FixedDialog"
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Frase de paso (mínimo 12 caracteres)"
    $label.Location = New-Object Drawing.Point(20,20)
    $label.AutoSize = $true
    $dialog.Controls.Add($label)

    $passwordBox = New-Object System.Windows.Forms.TextBox
    $passwordBox.Location = New-Object Drawing.Point(20,45)
    $passwordBox.Size = New-Object Drawing.Size(395,25)
    $passwordBox.UseSystemPasswordChar = $true
    $dialog.Controls.Add($passwordBox)

    $confirmationBox = $null
    if($ConfirmPassphrase){
        $confirmationLabel = New-Object System.Windows.Forms.Label
        $confirmationLabel.Text = "Confirmar frase de paso"
        $confirmationLabel.Location = New-Object Drawing.Point(20,80)
        $confirmationLabel.AutoSize = $true
        $dialog.Controls.Add($confirmationLabel)

        $confirmationBox = New-Object System.Windows.Forms.TextBox
        $confirmationBox.Location = New-Object Drawing.Point(20,105)
        $confirmationBox.Size = New-Object Drawing.Size(395,25)
        $confirmationBox.UseSystemPasswordChar = $true
        $dialog.Controls.Add($confirmationBox)
    }

    $result = $null
    $acceptButton = New-Object System.Windows.Forms.Button
    $acceptButton.Text = "Aceptar"
    $acceptButton.Location = New-Object Drawing.Point(225,155)
    $acceptButton.Size = New-Object Drawing.Size(90,30)
    $acceptButton.Add_Click({
        if($passwordBox.Text.Length -lt 12){
            [void][System.Windows.Forms.MessageBox]::Show(
                "La frase de paso debe tener al menos 12 caracteres.",
                "Frase de paso",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }

        if(
            $ConfirmPassphrase -and
            $passwordBox.Text -cne $confirmationBox.Text
        ){
            [void][System.Windows.Forms.MessageBox]::Show(
                "Las frases de paso no coinciden.",
                "Frase de paso",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }

        $result = ConvertTo-SecureString $passwordBox.Text -AsPlainText -Force
        $passwordBox.Clear()
        if($null -ne $confirmationBox){ $confirmationBox.Clear() }
        $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })
    $dialog.Controls.Add($acceptButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancelar"
    $cancelButton.Location = New-Object Drawing.Point(325,155)
    $cancelButton.Size = New-Object Drawing.Size(90,30)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dialog.Controls.Add($cancelButton)
    $dialog.AcceptButton = $acceptButton
    $dialog.CancelButton = $cancelButton

    if($Owner){
        [void]$dialog.ShowDialog($Owner)
    }
    else{
        [void]$dialog.ShowDialog()
    }

    $passwordBox.Clear()
    if($null -ne $confirmationBox){ $confirmationBox.Clear() }
    $dialog.Dispose()
    return $result
}

function Export-LauncherProfile {

    param(
        [string]$DestinationPath,
        [System.Security.SecureString]$Passphrase
    )

    if([string]::IsNullOrWhiteSpace($DestinationPath)){
        throw "Debe especificar dónde guardar el perfil."
    }
    [void](Get-ProfilePassphraseText $Passphrase)

    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
        "AONLauncherProfile_" + [guid]::NewGuid().ToString("N")
    )
    $zipPath = "$temporaryRoot.zip"

    try{
        New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null

        foreach($fileName in $script:LauncherProfileConfigFiles){
            $sourcePath = Join-Path $Global:ConfigFolder $fileName
            if(!(Test-Path -LiteralPath $sourcePath -PathType Leaf)){
                throw "Falta el archivo de configuración $fileName."
            }

            $json = [IO.File]::ReadAllText($sourcePath)
            $null = $json | ConvertFrom-Json -ErrorAction Stop
            [IO.File]::WriteAllText(
                (Join-Path $temporaryRoot $fileName),
                $json,
                (New-Object System.Text.UTF8Encoding($false))
            )
        }

        $credentialStore = Get-Credentials
        $portableCredentials = @()
        foreach($credential in @($credentialStore.credentials)){
            if(
                [string]::IsNullOrWhiteSpace([string]$credential.password) -or
                [string]::IsNullOrWhiteSpace([string]$credential.user) -or
                [string]::IsNullOrWhiteSpace([string]$credential.environment)
            ){
                throw "Hay una credencial incompleta que no se puede exportar."
            }

            $plainPassword = Unprotect-Password $credential.password
            $portableCredentials += [PSCustomObject]@{
                environment = $credential.environment
                user = $credential.user
                password = $plainPassword
                updatedAt = $credential.updatedAt
            }
            $plainPassword = $null
        }

        $portableJson = ConvertTo-Json -InputObject ([PSCustomObject]@{
            credentials = @($portableCredentials)
        }) -Depth 10 -Compress
        $protectedCredentials = Protect-LauncherProfilePayload $portableJson $Passphrase
        [IO.File]::WriteAllText(
            (Join-Path $temporaryRoot "credentials.json.enc"),
            $protectedCredentials,
            (New-Object System.Text.UTF8Encoding($false))
        )
        $portableCredentials = @()
        $portableJson = $null
        $protectedCredentials = $null

        $manifest = [PSCustomObject]@{
            formatVersion = 1
            exportedAt = (Get-Date).ToString("o")
            files = @($script:LauncherProfileConfigFiles) + "credentials.json.enc"
        } | ConvertTo-Json -Depth 5 -Compress
        [IO.File]::WriteAllText(
            (Join-Path $temporaryRoot "profile.json"),
            $manifest,
            (New-Object System.Text.UTF8Encoding($false))
        )

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::CreateFromDirectory(
            $temporaryRoot,
            $zipPath,
            [IO.Compression.CompressionLevel]::Optimal,
            $false
        )

        $destinationDirectory = Split-Path -Parent $DestinationPath
        if(-not [string]::IsNullOrWhiteSpace($destinationDirectory)){
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        }
        Move-Item -LiteralPath $zipPath -Destination $DestinationPath -Force
    }
    finally{
        if(Test-Path -LiteralPath $temporaryRoot){
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
        if(Test-Path -LiteralPath $zipPath){
            Remove-Item -LiteralPath $zipPath -Force
        }
    }
}

function Test-LauncherProfileConfiguration {

    param(
        [string]$FileName,
        [object]$Data
    )

    switch($FileName){
        "settings.json" {
            if($null -eq $Data.PSObject.Properties["selectedUser"] -or
                $null -eq $Data.PSObject.Properties["lastEnvironment"]){
                throw "settings.json no tiene la estructura esperada."
            }
        }
        "users.json" {
            if($null -eq $Data.PSObject.Properties["users"]){
                throw "users.json no tiene la estructura esperada."
            }
        }
        "favorites.json" {
            if($null -eq $Data.PSObject.Properties["favorites"]){
                throw "favorites.json no tiene la estructura esperada."
            }
        }
        "applications.json" {
            foreach($property in @("SSMS", "VisualStudio", "VSCode", "ReportBuilder")){
                if($null -eq $Data.PSObject.Properties[$property]){
                    throw "applications.json no tiene la estructura esperada."
                }
            }
        }
        "projects.json" {
            if($null -eq $Data.PSObject.Properties["projects"]){
                throw "projects.json no tiene la estructura esperada."
            }
        }
        "links.json" {
            if($null -eq $Data.PSObject.Properties["links"]){
                throw "links.json no tiene la estructura esperada."
            }
        }
    }
}

function Import-LauncherProfile {

    param(
        [string]$SourcePath,
        [System.Security.SecureString]$Passphrase
    )

    if(!(Test-Path -LiteralPath $SourcePath -PathType Leaf)){
        throw "No existe el archivo de perfil seleccionado."
    }
    [void](Get-ProfilePassphraseText $Passphrase)

    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
        "AONLauncherImport_" + [guid]::NewGuid().ToString("N")
    )
    $extractedRoot = Join-Path $temporaryRoot "profile"
    $rollbackRoot = Join-Path $temporaryRoot "rollback"
    $importFileNames = @($script:LauncherProfileConfigFiles) + "credentials.json"
    $allowedEntries = @($script:LauncherProfileConfigFiles) + @(
        "credentials.json.enc",
        "profile.json"
    )
    $backupCreated = $false

    try{
        New-Item -ItemType Directory -Path $extractedRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $rollbackRoot -Force | Out-Null

        Add-Type -AssemblyName System.IO.Compression
        $archive = [IO.Compression.ZipFile]::OpenRead($SourcePath)
        try{
            if($archive.Entries.Count -ne $allowedEntries.Count){
                throw "El perfil contiene una cantidad de archivos inesperada."
            }

            $seenEntries = @{}
            $totalUncompressedBytes = 0L
            foreach($entry in $archive.Entries){
                if(
                    $entry.FullName -notin $allowedEntries -or
                    $entry.FullName.Contains("/") -or
                    $entry.FullName.Contains("\") -or
                    $seenEntries.ContainsKey($entry.FullName)
                ){
                    throw "El perfil contiene una ruta o archivo no permitido."
                }
                if($entry.Length -gt 10485760){
                    throw "Un archivo del perfil supera el tamaño permitido."
                }

                $seenEntries[$entry.FullName] = $true
                $totalUncompressedBytes += $entry.Length
                $destination = Join-Path $extractedRoot $entry.FullName
                $inputStream = $entry.Open()
                $outputStream = [IO.File]::Create($destination)
                try{
                    $inputStream.CopyTo($outputStream)
                }
                finally{
                    $outputStream.Dispose()
                    $inputStream.Dispose()
                }
            }
            if($totalUncompressedBytes -gt 52428800){
                throw "El perfil supera el tamaño total permitido."
            }
        }
        finally{
            $archive.Dispose()
        }

        $manifest = [IO.File]::ReadAllText((Join-Path $extractedRoot "profile.json")) |
            ConvertFrom-Json -ErrorAction Stop
        if($manifest.formatVersion -ne 1){
            throw "La versión del perfil no es compatible."
        }

        foreach($fileName in $script:LauncherProfileConfigFiles){
            $filePath = Join-Path $extractedRoot $fileName
            $data = [IO.File]::ReadAllText($filePath) | ConvertFrom-Json -ErrorAction Stop
            Test-LauncherProfileConfiguration $fileName $data
        }

        $protectedCredentials = [IO.File]::ReadAllText(
            (Join-Path $extractedRoot "credentials.json.enc")
        )
        $portableJson = Unprotect-LauncherProfilePayload $protectedCredentials $Passphrase
        $portableStore = $portableJson | ConvertFrom-Json -ErrorAction Stop
        if($null -eq $portableStore.PSObject.Properties["credentials"]){
            throw "El archivo de credenciales del perfil no tiene la estructura esperada."
        }

        $localCredentials = @()
        foreach($credential in @($portableStore.credentials)){
            if(
                [string]::IsNullOrWhiteSpace([string]$credential.environment) -or
                [string]::IsNullOrWhiteSpace([string]$credential.user) -or
                [string]::IsNullOrEmpty([string]$credential.password) -or
                [string]::IsNullOrWhiteSpace([string]$credential.updatedAt)
            ){
                throw "El perfil contiene una credencial incompleta."
            }

            $updatedAt = [datetime]::MinValue
            if(-not [datetime]::TryParse(
                [string]$credential.updatedAt,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AssumeLocal,
                [ref]$updatedAt
            )){
                throw "El perfil contiene una fecha de credencial inválida."
            }

            $localCredentials += [PSCustomObject]@{
                environment = [string]$credential.environment
                user = [string]$credential.user
                password = Protect-Password ([string]$credential.password)
                updatedAt = [string]$credential.updatedAt
            }
        }
        $portableJson = $null
        $protectedCredentials = $null

        $localCredentialsJson = ConvertTo-Json -InputObject ([PSCustomObject]@{
            credentials = @($localCredentials)
        }) -Depth 10
        [IO.File]::WriteAllText(
            (Join-Path $extractedRoot "credentials.json"),
            $localCredentialsJson,
            (New-Object System.Text.UTF8Encoding($false))
        )
        $localCredentials = @()
        $localCredentialsJson = $null

        $configData = @{}
        foreach($fileName in $script:LauncherProfileConfigFiles){
            $configData[$fileName] = [IO.File]::ReadAllText(
                (Join-Path $extractedRoot $fileName)
            ) | ConvertFrom-Json -ErrorAction Stop
        }

        Backup-Configuration
        $backupCreated = $true
        foreach($fileName in $importFileNames){
            $destination = Join-Path $Global:ConfigFolder $fileName
            if(Test-Path -LiteralPath $destination -PathType Leaf){
                Copy-Item -LiteralPath $destination -Destination (Join-Path $rollbackRoot $fileName) -Force
            }
        }

        try{
            foreach($fileName in $importFileNames){
                $source = Join-Path $extractedRoot $fileName
                $destination = Join-Path $Global:ConfigFolder $fileName
                Copy-Item -LiteralPath $source -Destination $destination -Force
            }
        }
        catch{
            foreach($fileName in $importFileNames){
                $previous = Join-Path $rollbackRoot $fileName
                $destination = Join-Path $Global:ConfigFolder $fileName
                if(Test-Path -LiteralPath $previous -PathType Leaf){
                    Copy-Item -LiteralPath $previous -Destination $destination -Force
                }
            }
            throw
        }

        $script:ExpiredLauncherCredentialStatuses = @()
        return [PSCustomObject]@{
            ImportedFiles = $importFileNames.Count
            BackupCreated = $backupCreated
        }
    }
    finally{
        if(Test-Path -LiteralPath $temporaryRoot){
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}