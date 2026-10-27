# Pruebas automatizadas de APPLauncher

## Ejecución

Desde la raíz del repositorio, con Windows PowerShell o PowerShell 7 y Pester instalado:

```powershell
.\Tests\Run-Tests.ps1
```

Para ejecutar una sola funcionalidad:

```powershell
.\Tests\Run-Tests.ps1 -Path .\Tests\Sprint-05.Credentials.Tests.ps1
```

Pester 3.4 o posterior es compatible con la sintaxis usada por esta suite. Las pruebas guardan configuración, logs, paquetes y respaldos en carpetas temporales; no modifican `Config`, `Logs` ni `Backups` del usuario.

## Organización

| Archivo | Alcance |
|---|---|
| `Base-Operational.Tests.ps1` | Inicialización/persistencia, respaldo, usuarios, favoritos, detección de aplicaciones, ejecución simulada, manejo seguro de errores y temas. |
| `Sprint-01-02.Projects.Tests.ps1` | Validación y lanzamiento dinámico, rutas previas al inicio, perfiles sin aplicaciones, CRUD y nombres duplicados. |
| `Sprint-03.Dashboard.Tests.ps1` | Métricas diarias/mensuales, actividad de aplicaciones/proyectos, logs inválidos y limpieza. |
| `Sprint-04.QuickLinks.Tests.ps1` | Normalización y validación de URLs, unicidad, persistencia y apertura simulada. |
| `Sprint-05.Credentials.Tests.ps1` | Vencimiento, estados, eliminación y cifrado DPAPI con datos ficticios. |
| `Sprint-06.ProfileTransfer.Tests.ps1` | Export/import ZIP, ausencia de secretos en claro, passphrase, validación, backup y recifrado DPAPI. |
| `Sprint-07.Updates.Tests.ps1` | Manifiestos, versión, SHA-256, traversal, publicación secuencial y EXE obsoleto. |
| `Windows-Forms.Tests.ps1` | Apertura minimizada, cierre automático, controles principales y aceptación de passphrase con creación de ZIP. |

## Límites de integración

La suite no inicia las aplicaciones corporativas ni `runas`; esas llamadas se simulan. Las credenciales DPAPI se crean durante la prueba y solo se pueden descifrar con el usuario de Windows que las generó.

Los formularios se abren en una sesión Windows interactiva, minimizados y cerrados por un timer. Se automatiza la ruta válida de passphrase/exportación. Los casos que muestran `MessageBox` de validación no se automatizan para evitar diálogos bloqueantes; sus reglas de negocio sí se prueban directamente en los módulos.

La publicación, detección y preparación del paquete de Sprint 7 se prueban en repositorios temporales. Falta una prueba de instalación/reinicio completa y una ejecución contra el recurso compartido corporativo real; requieren una ubicación de distribución y una instalación destino autorizadas.
