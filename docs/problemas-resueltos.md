# Problemas y soluciones

## Problema 1: ambientes y dominios hardcodeados

### Traducción
Se requería eliminar valores fijos del cliente (DEV, QC, PROD y sus dominios) del código para que el launcher soporte configuraciones específicas del cliente sin cambios de código.

### Solución
Se centralizó la definición de ambientes en [Modules/ConfigManager.ps1](../Modules/ConfigManager.ps1), se añadieron helpers para leer y guardar entornos, y se sustituyó la resolución de dominio por consultas basadas en configuración desde [Modules/AppLauncher.ps1](../Modules/AppLauncher.ps1), [Modules/Credentials.ps1](../Modules/Credentials.ps1) y [Modules/CyberArkProvider.ps1](../Modules/CyberArkProvider.ps1).

Además, la UI se mantuvo estable y solo se añadió un botón en la sección Administrar en [Launcher.ps1](../Launcher.ps1) para abrir la configuración de ambientes.

### Entendimiento
El problema raíz era que varios módulos dependían de nombres de entorno y dominios codificados, evitando personalizar la solución por cliente y creando riesgo de desalineación con dominios reales o entornos adicionales.

### Justificación
La solución mínima y segura fue tratar los ambientes como metadata configurada, no como constantes de código. Esto permite adaptarlo por cliente, mantiene compatibilidad con valores heredados y no altera la interfaz aprobada.

---

## Problema 2: dependencias de entorno no cargadas en pruebas y módulos aislados

### Traducción
Cuando los módulos se cargaban de forma aislada en pruebas o en ejecución parcial, faltaban las funciones de configuración de ambientes y el flujo de dominio no estaba disponible.

### Solución
Se añadieron cargas defensivas de [Modules/ConfigManager.ps1](../Modules/ConfigManager.ps1) al iniciar los módulos dependientes y se reforzó la compatibilidad global en [Tests/TestSupport.ps1](../Tests/TestSupport.ps1).

### Entendimiento
La causa era un acoplamiento de carga: muchos módulos asumían que ConfigManager ya estaba cargado, pero la suite de pruebas y la ejecución aislada no siempre lo hacía.

### Justificación
La corrección resuelve la falla en forma real y en validación con Pester sin introducir un cambio de comportamiento visible en la interfaz de usuario.

---

## Problema 3: bloqueo cuando la configuración de ambientes está vacía o corrupta

### Traducción
La aplicación debe impedir el uso si el archivo de configuración de ambientes no está definido, está vacío o tiene una estructura inválida; no debe suponer valores por defecto de cliente en código ni seguir ejecutando con datos ficticios.

### Solución
Se reforzó la validación en [Modules/ConfigManager.ps1](../Modules/ConfigManager.ps1) para detectar archivos vacíos o desestructurados y devolver un error explícito. Además, [Launcher.ps1](../Launcher.ps1) bloquea el arranque y abre el archivo de configuración si no hay al menos un ambiente válido.

### Entendimiento
La causa raíz del problema era una estrategia de fallback implícita: el código intentaba resolver valores `DEV/QC/PROD` o un mapa por defecto aunque el cliente no hubiera configurado nada. Eso viola el requisito de que el archivo de configuración sea la única fuente de verdad.

### Justificación
La validación funcional ahora confirma el comportamiento requerido: un archivo vacío se marca como no configurado y un JSON válido se lee dinámicamente sin hardcodeos ni defaults ocultos.

---

## Verificación final

Se validó directamente en PowerShell el comportamiento requerido:

- Archivo vacío: se bloquea con mensaje de configuración pendiente.
- JSON válido con dos ambientes: se leen dinámicamente como `DEV,QC`.

Esta evidencia confirma que la lógica ya no depende de valores fijos en el código y que el arranque queda bloqueado cuando la configuración no es válida.
