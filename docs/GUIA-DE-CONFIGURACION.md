# Guía de configuración del Launcher

Este documento define cómo configurar el Launcher sin hardcodear dominios, ambientes ni colores de interfaz en el código.

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

## 4. Cómo abrir la configuración

La aplicación tiene una opción de administración para abrir el archivo de ambientes directamente y editarlo sin cambiar la UI ni la estructura visual del producto.

## 5. Reglas de validación

La aplicación valida lo siguiente:

- archivo inexistente o vacío: inválido
- JSON corrupto: inválido
- missing `name`/`domain`/`safe`: inválido
- menos de un ambiente: inválido
- `color` inválido: inválido

Cuando la validación falla, se debe bloquear el uso de la aplicación y pedir corregir la configuración antes de continuar.

## 6. Recomendación para clientes

Para cada cliente, se recomienda mantener los valores reales del ambiente y no reutilizar nombres de ejemplo. La configuración debe vivir en archivos JSON dentro de `Config/` y no en código fuente ni valores literals en `Modules/`.
