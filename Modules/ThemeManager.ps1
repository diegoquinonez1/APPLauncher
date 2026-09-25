function Set-EnvironmentTheme {

    param(
        [System.Windows.Forms.Form]$Form,
        [string]$Environment
    )

    switch($Environment){

        "DEV" {

            $Form.BackColor =
                [System.Drawing.Color]::Honeydew
        }

        "QC" {

            $Form.BackColor =
                [System.Drawing.Color]::LemonChiffon
        }

        "PROD" {

            $Form.BackColor =
                [System.Drawing.Color]::MistyRose
        }

        default {

            $Form.BackColor =
                [System.Drawing.Color]::WhiteSmoke
        }
    }
}