function Get-DomainByEnvironment {

    param($Environment)

    switch ($Environment) {

        "DEV"  { "devaonnet" }
        "QC"   { "extadqc" }
        "PROD" { "extad" }

    }
}

function Add-Credential {

    param(
        $Environment,
        $User,
        $Password
    )

    $domain = Get-DomainByEnvironment $Environment

    $target = "AON_{0}_{1}" -f $Environment,$User

    cmdkey `
      /add:$target `
      /user:$domain\$User `
      /pass:$Password
}

function Remove-Credential {

    param(
        $Environment,
        $User
    )

    $target = "AON_{0}_{1}" -f $Environment,$User

    cmdkey /delete:$target
}