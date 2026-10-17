# Sprints del Proyecto

## Resumen

La evolución del Launcher se organizó en sprints secuenciales para entregar funcionalidad incremental y preparar la transición hacia una versión más robusta y configurable.

---

## Criterios transversales de interfaz
- Toda nueva funcionalidad, módulo o formulario debe mantener una interfaz ordenada, legible y visible dentro del área útil de la pantalla; los controles deben adaptarse al redimensionamiento o disponer de desplazamiento cuando sea necesario.
- Las listas y colecciones dinámicas deben seguir siendo utilizables al crecer, sin ocultar botones ni contenido y sin depender de una cantidad fija de elementos.
- Los textos de la interfaz deben conservar correctamente tildes y caracteres especiales. Los scripts PowerShell se guardan como UTF-8 con BOM para mantener compatibilidad con Windows PowerShell.

## Sprint 1
### ✅ Dynamic Project Launcher
- Eliminación de la dependencia de accesos hardcodeados.
- Generación dinámica de proyectos desde configuración.
- Preparación para soportar múltiples entornos y equipos.

### Flujo implementado
- Al iniciar, el Launcher lee `Config/projects.json` y genera un botón por cada proyecto válido.
- Cada botón ejecuta el perfil seleccionado, incluyendo sus aplicaciones de inicio, solución y carpeta configuradas.
- La lista admite cualquier cantidad de proyectos y muestra un estado vacío cuando no hay proyectos configurados.
- Los perfiles sin acciones, sin entorno o usuario requeridos, con nombres ambiguos o con rutas inexistentes se reportan como errores.

### Configuración de un perfil ejecutable
```json
{
	"projects": [
		{
			"name": "BAIS DEV",
			"environment": "DEV",
			"user": "adm-A0836618",
			"startupApps": ["SSMS", "VisualStudio", "VSCode"],
			"solution": "",
			"folder": ""
		}
	]
}
```

`name` es obligatorio. Para iniciar `startupApps` también se requieren `environment` y `user`; `solution` y `folder` son opcionales, pero cuando se configuran sus rutas deben existir. Un perfil debe incluir al menos una aplicación, una solución o una carpeta.

---

## Sprint 2
### ✅ Project Manager
- Administración visual de proyectos.
- Creación, edición y eliminación de proyectos.
- Configuración de soluciones, rutas y aplicaciones asociadas.

### Flujo implementado
- Se agregó un botón de gestión de proyectos desde la pantalla principal.
- El formulario permite listar los perfiles activos, crear uno nuevo, editar el seleccionado y eliminarlo.
- Cada proyecto guarda nombre, entorno, usuario, solución, carpeta y aplicaciones de inicio.
- Al guardar o eliminar un proyecto, la lista principal del launcher se refresca automáticamente para reflejar los cambios.

### Estructura del proyecto
```json
{
  "projects": [
    {
      "name": "BAIS DEV",
      "environment": "DEV",
      "user": "adm-A0836618",
      "solution": "C:\\ruta\\solucion.sln",
      "folder": "C:\\ruta\\proyecto",
      "startupApps": ["SSMS", "VisualStudio", "VSCode"]
    }
  ]
}
```

---

## Sprint 3
### ✅ Dashboard Avanzado
- Indicadores de actividad y uso.
- Seguimiento de últimas ejecuciones.
- Métricas por aplicación y proyecto.
- Base para reportes operativos.

### Implementación
- El dashboard muestra la última aplicación y el último proyecto iniciados, ambos con fecha y hora.
- Presenta la aplicación y el proyecto más utilizados, junto con sus cantidades, además de las aperturas de aplicaciones del día y del mes actual.
- `launcher.log` conserva los registros de aplicación existentes y agrega eventos `PROJECT` para los perfiles ejecutados desde el Launcher.
- Los logs anteriores no identificaban el perfil ejecutado, por lo que las métricas históricas de proyectos no se pueden reconstruir y comienzan con los nuevos eventos.
- Las aperturas de aplicaciones iniciadas como parte de un proyecto se cuentan como ejecuciones de aplicación; el evento de proyecto se usa para las métricas de proyectos y no duplica los totales diarios/mensuales.
- Los indicadores se refrescan después de iniciar aplicaciones o proyectos y al completar un escaneo.

---

## Sprint 4
### ✅ URLs Corporativas
- Nuevo módulo de accesos rápidos.
- Configuración de enlaces internos y corporativos.
- Soporte para herramientas como Azure DevOps, Jira, Confluence, GitHub, SharePoint y Teams.

### Implementación
- El panel `Accesos web` de la pantalla principal genera un botón por cada enlace válido y permite abrirlo en el navegador predeterminado.
- `Config/links.json` almacena la colección `links`; el Launcher crea el archivo con una lista vacía si todavía no existe.
- El gestor de accesos permite crear, editar y eliminar enlaces, con actualización inmediata del panel principal.
- Se requiere un nombre único y una URL absoluta `http` o `https`. Se rechazan esquemas distintos, URLs inválidas y URLs que incluyan credenciales.
- Los enlaces inválidos presentes en el JSON no se muestran ni se abren; se pueden corregir desde el gestor.
- La lista admite una cantidad variable de enlaces y dispone de desplazamiento.

### Configuración
```json
{
	"links": [
		{
			"name": "Azure DevOps",
			"url": "https://example.com/devops"
		},
		{
			"name": "Jira",
			"url": "https://example.com/jira"
		}
	]
}
```

---

## Sprint 5
### ✅ Expiración de Credenciales
- Vigencia calculada desde `updatedAt`: la credencial expira a las 8 horas.
- Estados por entorno para el usuario seleccionado: válida, próxima a expirar (última hora), expirada o no configurada.
- El dashboard principal muestra el estado de DEV, QC y PROD, y se actualiza al cambiar el usuario o volver desde el gestor de credenciales.
- El formulario de credenciales permite verificar el estado; las credenciales expiradas no se consideran utilizables.
- Las credenciales expiradas se eliminan al iniciar el Launcher y cada minuto mientras está abierto, además de al verificarlas, intentar usarlas o guardar una credencial. Las fechas ausentes o inválidas se consideran expiradas.
- El dashboard mantiene el estado "Expirada" durante la sesión después de eliminar el secreto; el marcador solo conserva usuario, entorno y fecha de vencimiento en memoria.
- Guardar nuevamente una credencial actualiza `updatedAt` y reinicia su período de vigencia.

---

## Sprint 6
### ✅ Export / Import de Perfil
- Exportación de configuración completa.
- Importación de perfil en otra máquina.
- Facilita migración, respaldo y cambio de equipo.

---

## Sprint 7
### ✅ Auto Update
- Validación de versión actual y disponible.
- Actualización desde repositorio compartido.
- Preparación para una distribución más controlada y corporativa.

---

## Versión actual
- AON Launcher V4.1.1

## Estado
- Producto estable
- Listo para uso diario
- Sprints 1 a 5 implementados