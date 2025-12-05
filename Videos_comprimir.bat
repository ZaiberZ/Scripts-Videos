@echo off
setlocal enabledelayedexpansion

REM Crear carpeta Comprimidas si no existe
if not exist "Comprimidas" mkdir "Comprimidas"

set "convertedList="

REM Procesar archivos mkv y mp4
for %%A in ("*.mkv" "*.mp4") do (
    cls
    echo Procesando: %%A

    REM Evitar pasar archivos inexistentes si un tipo no se encuentra
    if not exist "%%A" (
        continue
    )

    REM ==========================================
    REM 1. Obtener fechas originales con PowerShell
    REM ==========================================
    for /f "usebackq tokens=1,2 delims=|" %%i in (`
        powershell -NoProfile -Command ^
        "(Get-Item '%%~fA').CreationTime.ToString('yyyy-MM-dd HH:mm:ss') + '|' + (Get-Item '%%~fA').LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')"
    `) do (
        set "CREATED_PS=%%i"
        set "MODIFIED_PS=%%j"
    )

    REM ====================================================
    REM Generar nombre de salida SIEMPRE como MKV
    REM ====================================================
    set "outputName=Comprimidas\%%~nA.mkv"

    ffmpeg -hide_banner -loglevel warning -stats -hwaccel cuda -i "%%A" ^
       -vf "scale=-1:720:force_original_aspect_ratio=decrease,setsar=1" ^
       -c:v h264_nvenc -preset slow -rc vbr -cq 27 -b:v 0 -map 0 -c:a copy -c:s copy "!outputName!"

    if !ERRORLEVEL! EQU 0 (
        echo ✓ Conversion exitosa: %%A
        set "convertedList=!convertedList!%%A;"

        REM ==============================================
        REM 2. Restaurar fechas al archivo comprimido
        REM ==============================================
        powershell -NoProfile -Command ^
            "(Get-Item '!outputName!').CreationTime = ('!CREATED_PS!');" ^
            "(Get-Item '!outputName!').LastWriteTime = ('!MODIFIED_PS!');"
    ) else (
        echo ✗ ERROR con: %%A
    )

    echo.
)

cls
echo ============================
echo      VIDEOS CONVERTIDOS
echo ============================
echo.

if defined convertedList (
    for %%B in (!convertedList!) do echo  - %%B
) else (
    echo (Ningun video fue convertido)
)

echo.
echo Listo!
pause
