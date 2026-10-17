# AON Launcher - Roadmap de Evolución

## Resumen ejecutivo

El Launcher ha consolidado una base sólida en la versión 4.1 y está preparado para evolucionar hacia una plataforma más configurable, segura y escalable. El enfoque principal de las próximas versiones es reducir configuraciones hardcodeadas, mejorar la gestión de credenciales y completar un modelo de operación más robusto para equipos corporativos.

## Estado actual

### Versión actual
- AON Launcher V4.1.1
- Estado: Producto estable, listo para uso diario.
- Base preparada para la evolución hacia V4.2.

---

## ✅ V4.1 - Base operativa cerrada

La versión 4.1 dejó una base sólida para el crecimiento futuro del Launcher.

### Funcionalidades implementadas

#### 1. Gestión de usuarios
- Administración de usuarios de ejecución.
- Persistencia en `users.json`.
- Selección de usuario desde la interfaz principal.

#### 2. Gestión de credenciales
- Administración de credenciales por usuario y entorno (`DEV`, `QC`, `PROD`).
- Almacenamiento seguro en `credentials.json`.
- Contraseñas cifradas mediante DPAPI (`ConvertFrom-SecureString`).
- Verificación de existencia de credenciales.
- Eliminación de credenciales.

#### 3. Gestión de favoritos
- Alta y administración de favoritos.
- Persistencia en `favorites.json`.

#### 4. Dashboard principal
- Usuario actual.
- Entorno seleccionado.
- Aplicaciones detectadas.
- Número de proyectos configurados.
- Número de favoritos configurados.
- Fecha del último escaneo.

#### 5. Gestión de aplicaciones
Detección automática de:
- SQL Server Management Studio
- Visual Studio
- VS Code
- Report Builder

#### 6. Temas dinámicos
Cambio automático de colores según el entorno:
- DEV
- QC
- PROD

#### 7. Logs
- Registro automático de ejecuciones en `Logs/launcher.log`.

#### 8. Perfiles de proyecto
- Inicio de perfiles preconfigurados.
- Integración con BAIS.

---

## ✅ V4.1.1 - Mejoras de credenciales

### Objetivo
Adaptar el manejo de credenciales a restricciones corporativas sin comprometer la compatibilidad actual.

### Restricciones aplicadas
- No se utiliza Windows Credential Manager.
- No se utiliza `cmdkey` para almacenamiento.
- Se mantiene el uso de PowerShell y `runas /netonly` para autenticación remota.

### Nuevas funcionalidades

#### Copiar contraseña
Permite:
1. Obtener la credencial almacenada en texto plano.
2. Copiarla.
3. Ejecutar la aplicación.
4. Pegarla en `RUNAS`.

#### Compatibilidad con CyberArk
Flujo de trabajo:
1. Obtener la contraseña en texto plano.
2. Copiar contraseña desde CyberArk.
3. Guardar la credencial en el Launcher.
4. Copiar desde el Launcher.
5. Pegar en `RUNAS`.

### Seguridad
- Contraseñas cifradas en disco.
- No se almacenan en texto plano.
- No se utilizan credenciales persistentes de Windows.

### Resultado
Se mantiene el uso de `RUNAS /NETONLY` sin comprometer la compatibilidad del flujo actual.

---

## 🚀 V4.2 - Plataforma configurable

### Objetivo general
Eliminar dependencias de código para administrar proyectos y convertir el Launcher en una plataforma configurable.

### Prioridad 1: Dynamic Project Launcher
#### Estado: ✅ Implementado en Sprint 1

El Launcher genera un botón por cada proyecto de `Config/projects.json`. Al seleccionar uno, inicia únicamente el perfil asociado al botón, con sus aplicaciones, entorno, usuario, solución y carpeta configurados. Una configuración vacía muestra un estado vacío; perfiles incompletos o rutas inválidas producen un error visible.

#### Ejemplo
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

Para perfiles con `startupApps`, también se deben indicar `environment` y `user`. Cada perfil debe configurar al menos una aplicación, una solución o una carpeta; las rutas configuradas deben existir.

#### Beneficios
- Agregar proyectos desde configuración sin modificar `Launcher.ps1`.
- Mantener definiciones separadas por entorno y equipo.
- Facilitar la incorporación de nuevos equipos.

### Prioridad 2: Project Manager
#### Estado: ✅ Implementado en Sprint 2

Administración visual de Proyectos.

#### Funcionalidades
- Crear proyecto
  - Nombre
  - Solución
  - Ruta
  - Aplicaciones asociadas
- Editar proyecto
- Eliminar proyecto
- Configurar aplicaciones de inicio

El formulario queda accesible desde la pantalla principal y actualiza la lista de proyectos del launcher de forma inmediata tras guardar o borrar un registro.

#### Ejemplo de aplicaciones
- Visual Studio
- SSMS
- VS Code

#### Beneficios
- Eliminación de edición manual de JSON.
- Administración completa desde la interfaz.

### Prioridad 3: Dashboard avanzado
#### Nuevos indicadores
##### Actividad
- Última aplicación ejecutada
- Último proyecto iniciado

##### Estadísticas
- Aplicación más utilizada
- Proyecto más utilizado

##### Consumo
- Cantidad de ejecuciones del día
- Cantidad de ejecuciones del mes

#### Fuente de información
Utilización de `launcher.log` como origen de métricas.

### Prioridad 4: Accesos corporativos
#### Nuevo módulo
Accesos Rápidos

#### Destinos configurables
- Azure DevOps
- Jira
- Confluence
- CyberArk
- SharePoint
- GitHub
- Teams

#### Configuración
Desde archivo JSON.

#### Ejemplo
```json
{
  "links": [
    {
      "name": "Azure DevOps",
      "url": "https://..."
    }
  ]
}
```

---

## 🚀 V4.3 - Expiración automática de credenciales

### Estado actual
Actualmente se registra un campo como:

```json
{
  "updatedAt": "2026-09-30T09:00:00"
}
```

### Objetivo
Implementar expiración automática de credenciales a 8 horas.

### Estados
- Válida
- Próxima a expirar
- Expirada

### Dashboard de credenciales
Visualización esperada:
- DEV → Válida
- QC → Válida
- PROD → Expirada

### Beneficios
- Mayor visibilidad.
- Menor riesgo operativo.

### Limpieza automática
Eliminar credenciales expiradas del repositorio local.

#### Regla
`updatedAt + 8 horas`

---

## 🚀 V4.4 - Exportación e importación de perfil

### Exportación de perfil
Exportar toda la configuración:
- Usuarios
- Favoritos
- Credenciales
- Proyectos
- Configuración

Formato esperado:
- `usuario.profile.zip`

### Importación de perfil
Restaurar la configuración completa en otra máquina.

### Casos de uso
- Cambio de equipo.
- Migración de desarrolladores.
- Respaldo.

---

## 🚀 V5.0 - Plataforma de equipo

La evolución final del Launcher.

### Actualización automática
Archivo objetivo:
- `version.json`

Validaciones:
- Versión actual
- Versión disponible

Se contempla una actualización desde un repositorio compartido.

### Arquitectura de plugins
Posibilidad de agregar:
- Proyectos
- Menús
- Acciones
- Integraciones

Sin modificar el núcleo del Launcher.

### Distribución corporativa
Instalador formal:
- `AON Launcher Setup.exe`

Con:
- Instalación automática.
- Accesos directos.
- Actualizaciones controladas.

---

## Estado final

El producto actual se encuentra en una etapa de madurez operativa y está preparado para evolucionar hacia una plataforma más modular, segura y escalable.

### Versión actual
- AON Launcher V4.1.1

### Estado
- Producto estable
- Listo para uso diario
- Base preparada para evolución hacia V4.2
