# Seguridad de credenciales en el repositorio

## Qué hemos dejado hecho

Se aplicó una política de seguridad en tres capas:

1. Excluir los archivos reales del repositorio con [.gitignore](../.gitignore)
2. Usar plantillas de ejemplo en la carpeta Config para no subir valores reales
3. Añadir escaneo automático de secretos con GitHub Actions y Gitleaks

Los archivos reales que se excluyen son:

- Config/credentials.json
- Config/settings.json
- Config/users.json

Los archivos de ejemplo disponibles son:

- Config/credentials.example.json
- Config/settings.example.json

## 1. Excluir los reales y dejar plantillas

El patrón correcto es:

- no guardar secretos en el repositorio
- dejar un archivo de ejemplo con placeholders
- mantener los valores reales solo en entorno local, variables de entorno o vault

Ejemplo de estructura recomendada:

```text
Config/
  credentials.example.json
  settings.example.json
  credentials.json        # ignorado localmente, nunca se sube
  settings.json            # ignorado localmente, nunca se sube
```

Importante: si un archivo ya fue rastreado por Git, hay que sacarlo del índice con:

```bash
git rm --cached Config/credentials.json Config/settings.json Config/users.json
```

Y luego confirmar:

```bash
git add .gitignore Config/credentials.example.json Config/settings.example.json
git commit -m "Exclude secret config files and add examples"
```

## 2. Activar el hook local para bloquear commits

En la raíz del repo:

```bash
git config --local core.hooksPath .githooks
```

Esto hace que cada commit valide antes de salir con el script de detección de secretos.

## 3. Secret scanning en GitHub (CI/CD)

### Paso 1: revisar la protección del repositorio

En GitHub:

1. Abre el repositorio
2. Ve a Settings
3. Entra a Security
4. Revisa la sección Secret scanning
5. Activa Secret scanning
6. Activa Push protection si aparece disponible

> Si el repositorio es privado, normalmente requiere GitHub Advanced Security o la licencia adecuada. En repositorios públicos, la funcionalidad suele estar disponible con algunas limitaciones.

### Paso 2: añade el workflow de análisis

Ya quedó creado en [.github/workflows/secret-scan.yml](../.github/workflows/secret-scan.yml)

Este workflow usa Gitleaks para revisar cada push y cada pull request.

### Paso 3: hacer push para activar la validación

```bash
git add .gitignore .github/workflows/secret-scan.yml Config/credentials.example.json Config/settings.example.json
git commit -m "Add secret scanning and example config templates"
git push origin <tu-rama>
```

Luego, en GitHub, revisa la pestaña Actions y confirma que el job Secret scan corre.

### Paso 4: validar en Pull Request

Haz una rama nueva, modifica un archivo y crea un PR.

Si en cualquier archivo aparece una cadena sospechosa como:

- password
- token
- secret
- api_key
- connection string
- private key

GitHub y Gitleaks lo marcarán como riesgo.

### Paso 5: si detecta un secreto real

Cuando ocurra esto:

1. Rotar la credencial inmediatamente
2. Revocar la clave comprometida
3. Eliminarla del historial Git si ya fue subida
4. Revisar si alguien la copió en una rama remota

Comandos clave:

```bash
git rm --cached <archivo>
```

Si ya fue comprometida antes y necesita limpieza del historial:

```bash
git filter-branch --force --index-filter "git rm --cached --ignore-unmatch <archivo>" -- --all
```

> Eso es serio y requiere coordinación; normalmente se recomienda rotar la clave y hacer una limpieza controlada del historial.

## 4. Otras opciones válidas además de excluir

### Variables de entorno

```bash
export API_KEY="valor-secreto"
```

### Gestor de secretos

- Azure Key Vault
- AWS Secrets Manager
- HashiCorp Vault
- Doppler

### Archivos de ejemplo

Mantener solo valores ficticios en:

- Config/credentials.example.json
- Config/settings.example.json

## 5. Recomendación final

La mejor combinación para este repositorio es:

- ignorar los archivos reales,
- dejar plantillas con placeholders,
- ejecutar hook local antes del commit,
- activar GitHub secret scanning + push protection,
- revisar cada PR con un scan automático,
- mantener todas las credenciales fuera del repositorio.

Esto evita que un archivo aparentemente "cifrado" siga siendo un secreto que se pueda subir accidentalmente.
