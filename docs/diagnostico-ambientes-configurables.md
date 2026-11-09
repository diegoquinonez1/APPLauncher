# Diagnóstico del requerimiento: ambientes y dominios configurables por cliente

## Traducción

El problema actual es que el launcher asume de forma fija que cada cliente tendrá exactamente los ambientes DEV, QC y PROD, y que cada uno estará asociado a un dominio concreto como devaonnet, extadqc y extad. Eso rompe el modelo cuando un cliente usa nombres diferentes, menos ambientes o dominios distintos, porque la lógica de autenticación, configuración y UI está acoplada a un cliente en particular.

## Entendimiento

La base del problema no está solo en la UI. Está en la capa de dominio y configuración del sistema:

- El selector de entorno en [Launcher.ps1](../Launcher.ps1) crea radios fijos para DEV, QC y PROD.
- La función `Get-DomainByEnvironment` en [Modules/AppLauncher.ps1](../Modules/AppLauncher.ps1) y en [Modules/Credentials.ps1](../Modules/Credentials.ps1) hace un switch con dominios fijos.
- El bloque `safeByEnvironment` en [Modules/CyberArkProvider.ps1](../Modules/CyberArkProvider.ps1) y el ejemplo de configuración en [Config/settings.example.json](../Config/settings.example.json) codifican los mismos nombres.
- Los formularios de proyectos y favoritos en [Modules/ProjectsForm.ps1](../Modules/ProjectsForm.ps1) y [Modules/FavoriteForm.ps1](../Modules/FavoriteForm.ps1) usan listas estáticas con esos tres valores.

Esto significa que cada cliente nuevo exige cambios de código o de configuración manual, no solo una configuración de datos.

## Diagnóstico del impacto

### 1. Impacto funcional

- Un cliente con ambientes `INT`, `UAT`, `PRD` o incluso solo `DEV` y `PROD` no puede usarse sin tocar código.
- Un dominio distinto para un mismo ambiente rompe la autenticación con `runas.exe` y `netonly`.
- El valor de `safeByEnvironment` puede quedar inconsistente con el dominio real del cliente.
- Los proyectos, favoritos y credenciales con ambiente fijo no admiten nombres dinámicos.

### 2. Impacto de seguridad y operación

- La credencial se valida contra un dominio que puede no corresponder al cliente real.
- CyberArk puede apuntar a un safe equivocado si el nombre del ambiente no coincide con el mapeo esperado.
- La operación se vuelve dependiente del conocimiento del cliente, no de la configuración de la instancia.

### 3. Impacto técnico y de mantenimiento

- Hay dos mapeos redundantes de dominio: uno en AppLauncher y otro en Credentials.
- Hay varios hardcodes dispersos en la base de código, por lo que la corrección no es local ni aislada.
- El proceso de onboarding de un nuevo cliente requiere editar código en vez de ajustar un archivo de configuración.
- Las pruebas existentes están sesgadas al modelo actual y no resisten nombres o cantidades diferentes de entorno.

### 4. Impacto en UX

- El usuario no puede administrar los ambientes reales del cliente desde una vista simple.
- La UI limita la capacidad de trabajar con el nombre que el cliente conoce, aunque la plataforma lo haga de otra forma.
- El problema se percibe como una falla de configuración, no como una limitación del diseño.

## Análisis profundo

El problema no es solo de dominios; es un problema de modelado de datos.

El sistema hoy asume que:

1. todos los clientes usan exactamente tres ambientes;
2. esos ambientes siempre se llaman DEV, QC y PROD;
3. cada ambiente tiene un dominio fijo y único;
4. el archivo de configuración solo sirve para valores auxiliares, no para los metadatos del entorno.

Eso convierte al launcher en una herramienta específica para un cliente, no una herramienta configurada por cliente.

La solución correcta es tratar cada ambiente como un dato de configuración y no como una regla de código. En otras palabras:

- el nombre del ambiente debe salir de un archivo de configuración;
- el dominio asociado debe salir del mismo archivo;
- los valores de CyberArk por entorno deben ser derivados del mismo origen;
- la UI debe cargar esos valores dinámicamente y no fijarse en un conjunto duro.

Esto reduce el acoplamiento, hace que la configuración sea la fuente de verdad y permite que cada cliente defina su propia topología sin cambios de código.

## Solución propuesta

### Opción recomendada (mínimo impacto y máxima simplicidad)

No crear un módulo completo de parametrización. La mejor solución para este caso es:

- crear un archivo JSON en Config, por ejemplo `environments.json`;
- agregar un botón en la sección "Administrar" que abra ese archivo con el editor predeterminado;
- cargar sus valores desde el archivo en lugar de usar literales `DEV/QC/PROD` en la lógica.

Ejemplo de estructura sugerida:

```json
[
  {
    "name": "DEV",
    "domain": "devaonnet",
    "safe": "SAFE_DEV",
    "isDefault": true
  },
  {
    "name": "UAT",
    "domain": "ad-uat",
    "safe": "SAFE_UAT"
  },
  {
    "name": "PRD",
    "domain": "ad-prd",
    "safe": "SAFE_PRD"
  }
]
```

### Reglas de diseño

- El archivo se configura una vez por cliente.
- El entorno por defecto se marca con `isDefault`.
- El nombre del ambiente y su dominio no se codifican en código.
- La validación debe asegurar:
  - nombres únicos;
  - dominios únicos o no repetidos;
  - al menos un ambiente por defecto;
  - valores no vacíos para nombre y dominio.

### Ajuste mínimo en la UX

- El botón en la sección Administrar puede llamarse: "Configurar ambientes".
- Al hacer click se abre el archivo JSON en el Bloc de notas o editor por defecto.
- Los formularios que hoy llenan opciones con `@("DEV","QC","PROD")` deben reemplazarse por una carga desde la lista configurada en una función auxiliar.
- El selector de entorno se renderiza a partir de la lista configurada, no a partir de hardcodes.

## Justificación

Este cambio es correcto porque resuelve la causa raíz del problema: el sistema codifica la topología del cliente en la aplicación. El requisito pide que esos ambientes y dominios sean una configuración del cliente, no una decisión de desarrollo. Por eso, la opción más eficiente es un archivo de configuración con un botón en Administrar: simple, mantenible, compatible con la realidad del negocio y sin complejidad innecesaria.

## Cierre recomendado

Siguiente paso sugerido: implementar esta estructura de configuración y actualizar la lógica de selección de entornos sin tocar el resto del comportamiento ya funcional del launcher.
