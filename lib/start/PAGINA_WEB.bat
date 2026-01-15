@echo off
TITLE PAGINA WEB (PUERTO 80 - SIN :5000)
COLOR 0B

:: TRUCO PARA TU SERVIDOR
set NODE_SKIP_PLATFORM_CHECK=1

cd /d "%~dp0..\.."

echo =================================
echo   ABRIENDO WEB EN PUERTO ESTANDAR (80)
echo =================================

if not exist "build\web" (
    echo ERROR: Ejecuta "flutter build web --release --no-tree-shake-icons" primero.
    pause
    exit
)

echo Iniciando...
echo AVISO: Si falla, cierra este archivo, dale Clic Derecho y "Ejecutar como Administrador".

:: Abrimos navegador SIN puerto (automáticamente va al 80)
start http://localhost

:: Usamos el puerto 80
call npx serve -s build/web -l 80

pause