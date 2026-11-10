# Guía de configuración del Launcher

Este documento define cómo configurar el Launcher sin hardcodear dominios, ambientes ni colores de interfaz en el código.

## 0. Regla principal del repositorio

La carpeta `Config/` es local al entorno del cliente y no se versiona en Git. En el repositorio solo quedan archivos de ejemplo con sufijo `.example` (por ejemplo `settings.example.json`, `environments.example.json`, `projects.example.json`).

Esto significa que:

- no se suben nombres de cliente, dominios, usuarios, rutas reales ni credenciales;
- no se versiona `Config/*.json` reales ni `Logs/launcher.log`;
- al clonar el repositorio o abrir un nuevo cliente, se deben crear los archivos reales localmente a partir de las plantillas.

La aplicación y el hook de Git permiten este flujo sin romper el proyecto: si un archivo local no existe, el launcher lo crea con valores por defecto o la estructura base; si existe un cliente real, ese archivo vive sólo en la máquina local y nunca se sube al repositorio.

## 1. Archivo principal de ambientes

El archivo de referencia es `Config/environments.json`.

Ejemplo válido:

```json
[
  {
    "name": "ALPHA",
    "domain": "alpha.local",
    "safe": "SAFE_ALPHA",
    "color": "#FF6600",
    "default": true
  },
  {
    "name": "BETA",
    "domain": "beta.local",
    "safe": "SAFE_BETA",
    "color": "#00A676",
    "default": false
  }
]
```

Reglas:

- Cada ambiente debe incluir: `name`, `domain`, `safe`.
- `color` es opcional, pero si se usa debe ser un valor hexadecimal válido como `#FF6600`.
- El archivo puede tener uno o más ambientes; no se asume un número fijo de 3.
- Si el archivo está vacío, corrupto o con elementos incompletos, la aplicación bloquea el uso de la UI y muestra un mensaje de configuración faltante o inválida.
- El campo `default` o `isDefault` puede usarse para marcar el ambiente principal, pero no es obligatorio.

## 2. Colores por ambiente

Los colores se configuran por ambiente dentro del mismo JSON de entornos. Ejemplo:

```json
{
  "name": "BETA",
  "domain": "beta.local",
  "safe": "SAFE_UAT",
  "color": "#F18F01"
}
```

Esto asegura que la UI tome el color asociado al entorno sin depender de un valor fijo en el código. Si no llega un color configurado, el sistema usa un valor seguro por defecto y no rompe la experiencia.

## 3. Archivo de configuración general

El archivo `Config/settings.json` controla la sesión y la integración con CyberArk.

Ejemplo:

```json
{
  "selectedUser": "demo-user",
  "lastEnvironment": "ALPHA",
  "updateSource": "",
  "cyberArk": {
    "enabled": false,
    "baseUrl": "",
    "loginUrl": "https://example.com/privilegecloud/Accounts",
    "username": "",
    "password": "",
    "appId": "",
    "safe": "",
    "accountNameTemplate": "{environment}-{user}",
    "allowManualFallback": true,
    "authType": "Password",
    "interactiveLogin": true,
    "safeByEnvironment": {
      "ALPHA": "SAFE_ALPHA",
      "BETA": "SAFE_BETA"
    }
  }
}
```

> El mapa `safeByEnvironment` es opcional y debe reflejar los nombres reales definidos en `Config/environments.json`. La aplicación no asume 3 entornos fijos ni un cliente concreto; si el archivo de ambientes cambia, este mapeo también debe actualizarse para mantener la relación correcta con CyberArk.

## 4. Nuevo clon: cómo dejarlo listo

Cuando se clona el repositorio por primera vez, el proceso correcto es:

1. Verificar que la carpeta `Config/` contiene solo plantillas de ejemplo (`*.example.json`, `*.example.ini`).
2. Crear los archivos locales reales con los nombres esperados por la app, por ejemplo:
   - `Config/settings.json` a partir de `Config/settings.example.json`
   - `Config/environments.json` a partir de `Config/environments.example.json`
   - `Config/applications.json` a partir de `Config/applications.example.json`
   - `Config/projects.json` a partir de `Config/projects.example.json`
   - `Config/favorites.json` a partir de `Config/favorites.example.json`
   - `Config/links.json` a partir de `Config/links.example.json`
   - `Config/users.json` a partir de `Config/users.example.json`
   - `Config/credentials.json` si aplica, a partir de la plantilla `credentials.example.json`
3. Ajustar los valores reales del cliente, incluyendo: nombre de ambientes, dominio, safe de CyberArk, rutas locales de aplicaciones y usuarios del entorno.
4. Mantener `Logs/launcher.log` sin versionar; la app lo crea al ejecutarse y se ignora por Git.
5. No hacer `git add` ni `git commit` de ningún archivo local en `Config/` ni del log.

Ejemplo de copia rápida en PowerShell:

```powershell
Copy-Item .\Config\settings.example.json .\Config\settings.json
Copy-Item .\Config\environments.example.json .\Config\environments.json
Copy-Item .\Config\applications.example.json .\Config\applications.json
Copy-Item .\Config\projects.example.json .\Config\projects.json
Copy-Item .\Config\favorites.example.json .\Config\favorites.json
Copy-Item .\Config\links.example.json .\Config\links.json
Copy-Item .\Config\users.example.json .\Config\users.json
```

> Importante: los archivos reales deben quedar en el equipo local, no en el repositorio.

## 5. Nuevo cliente: qué cambiar siempre

Cuando llega un cliente nuevo, el proceso recomendado es:

1. Crear o actualizar `Config/environments.json` con los ambientes del cliente. No reutilizar nombres de ejemplo ni nombres de otros clientes.
2. Ajustar `Config/settings.json` para el usuario principal, entorno por defecto, `updateSource` y el bloque `cyberArk` con `safeByEnvironment` si aplica.
3. Ajustar `Config/applications.json` con las rutas reales del equipo del cliente y el último `LastScan` que corresponda.
4. Ajustar `Config/projects.json` y `Config/favorites.json` para reflejar los perfiles de proyecto y favoritos del cliente.
5. Revisar `Config/links.json` y `Config/users.json` para que no queden datos compartidos o mezclados entre clientes.
6. Mantener `credentials.json` solo localmente y nunca en el repositorio.

Un cliente nuevo nunca debe implicar tocar el código fuente para incorporar nombres, rutas, usuarios ni dominios. La configuración debe vivir en `Config/` y ser distinta por instalación/usuario.

## 6. Cómo abrir la configuración

La aplicación tiene una opción de administración para abrir el archivo de ambientes directamente y editarlo sin cambiar la UI ni la estructura visual del producto.

## 7. Reglas de validación

La aplicación valida lo siguiente:

- archivo inexistente o vacío: inválido
- JSON corrupto: inválido
- missing `name`/`domain`/`safe`: inválido
- menos de un ambiente: inválido
- `color` inválido: inválido

Cuando la validación falla, se debe bloquear el uso de la aplicación y pedir corregir la configuración antes de continuar.

## 8. Recomendación final para clientes

Para cada cliente, se recomienda mantener los valores reales del ambiente y no reutilizar nombres de ejemplo. La configuración debe vivir en archivos JSON dentro de `Config/` y no en código fuente ni valores literals en `Modules/`.

Regla definitiva:

- Repositorio: solo plantillas (`*.example.*`)
- Máquina local del cliente: archivos reales del entorno (`settings.json`, `environments.json`, `projects.json`, etc.)
- Log local: `Logs/launcher.log` (ignorado por Git)
