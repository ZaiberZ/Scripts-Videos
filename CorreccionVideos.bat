@echo off
setlocal enabledelayedexpansion

echo =======================================
echo   CORRIGIENDO METADATA DE ARCHIVOS MKV
echo =======================================
echo.

REM Crear carpeta de salida si no existe
if not exist "Corregidos" mkdir "Corregidos"

set "fixedList="

for %%A in ("*.mkv") do (
    echo Procesando: %%A

    REM Archivo de salida
    set "outfile=Corregidos\%%~nA_fixed.mkv"

    REM Reparar metadata sin recomprimir
    ffmpeg -hide_banner -loglevel warning -stats -i "%%A" ^
        -map 0 -c copy -map_metadata -1 "!outfile!"

    if !ERRORLEVEL! EQU 0 (
        echo Corregido: %%A
        set "fixedList=!fixedList!%%A;"
    ) else (
        echo ✗ ERROR corrigiendo: %%A
    )

    echo.
)

cls
echo =======================================
echo     ARCHIVOS MKV CORREGIDOS
echo =======================================
echo.

if defined fixedList (
    for %%B in (!fixedList!) do echo  - %%B
) else (
    echo (No se corrigió ningún archivo)
)

echo.
echo Listo!
pause
