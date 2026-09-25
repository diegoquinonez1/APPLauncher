@echo off
setlocal EnableDelayedExpansion
title AON Tools Launcher v2.0

:: Directorios
set "ROOT=%~dp0"
set "CONFIG=%ROOT%Config"
set "LOGS=%ROOT%Logs"

if not exist "%CONFIG%" mkdir "%CONFIG%"
if not exist "%LOGS%" mkdir "%LOGS%"

:: Usuario por defecto
set "USUARIO=adm-A0836618"

:: Cargar último usuario
if exist "%CONFIG%\usuario.ini" (
    set /p USUARIO=<"%CONFIG%\usuario.ini"
)

goto MENU_USUARIO


:: ==========================================
:: LOGIN / USUARIO
:: ==========================================
:MENU_USUARIO

cls
echo ========================================
echo        AON TOOLS LAUNCHER
echo ========================================
echo.
echo Usuario actual:
echo %USUARIO%
echo.
echo 1 - Continuar
echo 2 - Cambiar usuario
echo 3 - Configurar credenciales CMDKEY
echo.
echo 0 - Salir
echo.

set /p op=

if "%op%"=="1" goto MENU_ENTORNO
if "%op%"=="2" goto CAMBIAR_USUARIO
if "%op%"=="3" goto CMDKEY
if "%op%"=="0" exit

goto MENU_USUARIO


:CAMBIAR_USUARIO

cls
echo Cambiar Usuario
echo.

set /p nuevo=Nuevo usuario:

if "%nuevo%"=="" goto CAMBIAR_USUARIO

set "USUARIO=%nuevo%"

echo %USUARIO%>"%CONFIG%\usuario.ini"

echo.
echo Usuario actualizado.
timeout /t 1 >nul

goto MENU_USUARIO


:: ==========================================
:: ENTORNO
:: ==========================================
:MENU_ENTORNO

cls

echo ========================================
echo ENTORNO
echo ========================================
echo.
echo 1 - Desarrollo
echo 2 - QC / Pruebas
echo 3 - Produccion
echo.
echo B - Regresar
echo 0 - Salir
echo.

set /p env=

if /i "%env%"=="B" goto MENU_USUARIO
if "%env%"=="0" exit

if "%env%"=="1" (
    set "DOMINIO=devaonnet"
    set "ENTORNO=DEV"
    goto MENU_APP
)

if "%env%"=="2" (
    set "DOMINIO=extadqc"
    set "ENTORNO=QC"
    goto MENU_APP
)

if "%env%"=="3" (
    set "DOMINIO=extad"
    set "ENTORNO=PROD"
    goto MENU_APP
)

goto MENU_ENTORNO


:: ==========================================
:: APLICACIONES
:: ==========================================
:MENU_APP

cls

echo ========================================
echo Aplicaciones
echo ========================================
echo.
echo Entorno : %ENTORNO%
echo Dominio : %DOMINIO%
echo Usuario : %USUARIO%
echo.
echo 1 - SSMS
echo 2 - Visual Studio
echo 3 - VS Code
echo 4 - Report Builder
echo.
echo B - Regresar
echo M - Menu principal
echo 0 - Salir
echo.

set /p APP=

if /i "%APP%"=="B" goto MENU_ENTORNO
if /i "%APP%"=="M" goto MENU_USUARIO
if "%APP%"=="0" exit

if "%APP%"=="1" (
    set "EXE=C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\SSMS.exe"
    set "NOMBRE=SSMS"
    goto EJECUTAR
)

if "%APP%"=="2" (
    set "EXE=C:\Program Files\Microsoft Visual Studio\18\Professional\Common7\IDE\devenv.exe"
    set "NOMBRE=Visual Studio"
    goto EJECUTAR
)

if "%APP%"=="3" (
    set "EXE=C:\Users\A0836618\AppData\Local\Programs\Microsoft VS Code\Code.exe"
    set "NOMBRE=VS Code"
    goto EJECUTAR
)

if "%APP%"=="4" (
    set "EXE=C:\Program Files\Microsoft Report Builder\MSReportBuilder.exe"
    set "NOMBRE=Report Builder"
    goto EJECUTAR
)

goto MENU_APP


:: ==========================================
:: EJECUTAR
:: ==========================================
:EJECUTAR

if not exist "%EXE%" (

    cls
    echo.
    echo ERROR:
    echo No existe la ruta:
    echo.
    echo %EXE%
    echo.
    pause
    goto MENU_APP
)

echo [%date% %time%] %ENTORNO% - %DOMINIO%\%USUARIO% - %NOMBRE% >> "%LOGS%\launcher.log"

echo.
echo Lanzando %NOMBRE%...
echo.

runas /netonly /noprofile /env /user:%DOMINIO%\%USUARIO% "%EXE%"

goto POST_EJECUCION


:: ==========================================
:: POST
:: ==========================================
:POST_EJECUCION

echo.
echo ========================================
echo 1 - Abrir otra aplicacion
echo 2 - Cambiar entorno
echo 3 - Menu principal
echo 0 - Salir
echo ========================================
echo.

set /p op=

if "%op%"=="1" goto MENU_APP
if "%op%"=="2" goto MENU_ENTORNO
if "%op%"=="3" goto MENU_USUARIO
if "%op%"=="0" exit

goto POST_EJECUCION


:: ==========================================
:: CMDKEY
:: ==========================================
:CMDKEY

cls

echo ========================================
echo Configuracion CMDKEY
echo ========================================
echo.
echo Esto permite almacenar credenciales para
echo evitar solicitarlas constantemente.
echo.
echo Dominio actual:
echo.
echo devaonnet
echo extadqc
echo extad
echo.
echo Se abrira el asistente.
echo.

pause

cmdkey

goto MENU_USUARIO