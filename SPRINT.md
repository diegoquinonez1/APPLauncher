# Sprints del Proyecto

## Resumen

La evolución del Launcher se organizó en sprints secuenciales para entregar funcionalidad incremental y preparar la transición hacia una versión más robusta y configurable.

---

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

---

## Sprint 3
### ✅ Dashboard Avanzado
- Indicadores de actividad y uso.
- Seguimiento de últimas ejecuciones.
- Métricas por aplicación y proyecto.
- Base para reportes operativos.

---

## Sprint 4
### ✅ URLs Corporativas
- Nuevo módulo de accesos rápidos.
- Configuración de enlaces internos y corporativos.
- Soporte para herramientas como Azure DevOps, Jira, Confluence, GitHub, SharePoint y Teams.

---

## Sprint 5
### ✅ Expiración de Credenciales
- Control de vigencia por entorno.
- Estados de credencial: válida, próxima a expirar y expirada.
- Limpieza automática para reducir riesgo operativo.

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
- Base preparada para evolución hacia V4.2