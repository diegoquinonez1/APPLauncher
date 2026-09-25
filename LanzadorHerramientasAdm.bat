@echo off
setlocal EnableDelayedExpansion
title Lanzador de Herramientas AON

:: Usuario por defecto
set "USUARIO=adm-A0836618"

:MENU_USUARIO
cls
echo ==========================================
echo         LANZADOR DE HERRAMIENTAS
echo ==========================================
echo.
echo Usuario actual: %USUARIO%
echo.
echo 1. Continuar con este usuario
echo 2. Cambiar usuario
echo 0. Salir
echo.

set /p opcion="Seleccione una opcion: "

if "%opcion%"=="1" goto MENU_ENTORNO
if "%opcion%"=="2" goto CAMBIAR_USUARIO
if "%opcion%"=="0" goto FIN

echo.
echo Opcion invalida.
pause
goto MENU_USUARIO


:CAMBIAR_USUARIO
cls
echo ==========================================
echo          CAMBIAR USUARIO
echo ==========================================
echo.
set /p NUEVO_USUARIO="Ingrese el usuario: "

if "%NUEVO_USUARIO%"=="" (
    echo Debe ingresar un valor.
    pause
    goto CAMBIAR_USUARIO
)

set "USUARIO=%NUEVO_USUARIO%"
goto MENU_USUARIO


:MENU_ENTORNO
cls
echo ==========================================
echo          SELECCIONAR ENTORNO
echo ==========================================
echo.
echo Usuario: %USUARIO%
echo.
echo 1. Desarrollo
echo 2. Pruebas (QC)
echo 3. Produccion
echo.
echo B. Regresar
echo 0. Salir
echo.

set /p entorno="Seleccione una opcion: "

if /I "%entorno%"=="B" goto MENU_USUARIO
if "%entorno%"=="0" goto FIN

if "%entorno%"=="1" (
    set "DOMINIO=devaonnet"
    set "NOMBRE_ENTORNO=DEV"
    goto MENU_APLICACION
)

if "%entorno%"=="2" (
    set "DOMINIO=extadqc"
    set "NOMBRE_ENTORNO=QC"
    goto MENU_APLICACION
)

if "%entorno%"=="3" (
    set "DOMINIO=extad"
    set "NOMBRE_ENTORNO=PROD"
    goto MENU_APLICACION
)

echo.
echo Opcion invalida.
pause
goto MENU_ENTORNO


:MENU_APLICACION
cls
echo ==========================================
echo       SELECCIONAR APLICACION
echo ==========================================
echo.
echo Entorno : %NOMBRE_ENTORNO%
echo Dominio : %DOMINIO%
echo Usuario : %USUARIO%
echo.
echo 1. SQL Server Management Studio
echo 2. Visual Studio
echo 3. Visual Studio Code
echo 4. Microsoft Report Builder
echo.
echo B. Regresar
echo 0. Salir
echo.

set /p app="Seleccione una opcion: "

if /I "%app%"=="B" goto MENU_ENTORNO
if "%app%"=="0" goto FIN

if "%app%"=="1" goto SSMS
if "%app%"=="2" goto VISUALSTUDIO
if "%app%"=="3" goto VSCODE
if "%app%"=="4" goto REPORTBUILDER

echo.
echo Opcion invalida.
pause
goto MENU_APLICACION


:SSMS
cls
echo Abriendo SSMS con %DOMINIO%\%USUARIO%
runas /netonly /noprofile /env /user:%DOMINIO%\%USUARIO% "C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\SSMS.exe"
goto FIN_EJECUCION


:VISUALSTUDIO
cls
echo Abriendo Visual Studio con %DOMINIO%\%USUARIO%
runas /netonly /noprofile /env /user:%DOMINIO%\%USUARIO% "C:\Program Files\Microsoft Visual Studio\18\Professional\Common7\IDE\devenv.exe"
goto FIN_EJECUCION


:VSCODE
cls
echo Abriendo VS Code con %DOMINIO%\%USUARIO%
runas /netonly /noprofile /env /user:%DOMINIO%\%USUARIO% "C:\Users\A0836618\AppData\Local\Programs\Microsoft VS Code\Code.exe"
goto FIN_EJECUCION


:REPORTBUILDER
cls
echo Abriendo Report Builder con %DOMINIO%\%USUARIO%
runas /netonly /noprofile /env /user:%DOMINIO%\%USUARIO% "C:\Program Files\Microsoft Report Builder\MSReportBuilder.exe"
goto FIN_EJECUCION


:FIN_EJECUCION
echo.
echo ==========================================
echo La aplicacion fue lanzada.
echo ==========================================
echo.
echo 1. Volver al menu principal
echo 0. Salir
echo.

set /p volver="Seleccione una opcion: "

if "%volver%"=="1" goto MENU_USUARIO
if "%volver%"=="0" goto FIN

echo Opcion invalida.
pause
goto FIN_EJECUCION


:FIN
exit