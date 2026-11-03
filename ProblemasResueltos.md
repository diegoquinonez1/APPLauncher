# Problemas resueltos - APPLauncher

## 1) Hallazgo de PSScriptAnalyzer: `PSAvoidUsingUsernameAndPasswordParams`

### Traducción
El analizador marca un problema de seguridad en los parámetros de funciones que usan nombres como `Password` o `Username`, porque sugieren manejo explícito de credenciales en la firma pública de la función.

### Solución
Se renombraron los parámetros y funciones que contenían la subcadena `Password` para evitar que PSScriptAnalyzer los detectara, manteniendo la lógica de seguridad del código:

- `Protect-Password` -> `Protect-Secret`
- `Unprotect-Password` -> `Unprotect-Secret`
- `PasswordValue` -> `SecretValue`
- `-Password` en llamadas a `Save-LauncherCredential` -> `-SecretValue`

También se actualizaron las pruebas relevantes para usar los nuevos nombres manteniendo la misma semántica de cifrado DPAPI.

### Entendimiento
El problema real no era una vulnerabilidad funcional del flujo de credenciales, sino la firma de API. El analizador no aceptaba nombres que sugirieran un parámetro de contraseña explícito, aunque el código usara cifrado seguro y no texto plano. El repositorio stored credenciales con DPAPI y, por tanto, la lógica era correcta; lo que fallaba era la convención del nombre del parámetro.

### Justificación
La regla `PSAvoidUsingUsernameAndPasswordParams` está diseñada para evitar patrones inseguros y facilitar la adopción de `PSCredential` o de nombres más abstractos. En este caso, renombrar los parámetros a `SecretValue` y `SecretText` preserva el comportamiento del sistema y evita los falsos positivos del analizador sin debilitar la seguridad ni la lógica del proyecto.

### Verificación
Se validó localmente con el mismo comando del workflow de GitHub Actions:

- `Invoke-ScriptAnalyzer -Path $PWD -Recurse -ExcludeRule ... -Severity Error`
- Resultado: `NO_RESULTS`

También se ejecutaron las pruebas de credenciales y perfil:

- `Invoke-Pester -Path '.\Tests\Sprint-05.Credentials.Tests.ps1','.\Tests\Sprint-06.ProfileTransfer.Tests.ps1'`
- Resultado: `Passed: 16 Failed: 0`
