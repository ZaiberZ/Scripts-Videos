@echo off
setlocal enabledelayedexpansion

REM Crear carpeta Comprimidas si no existe
if not exist "Comprimidas" mkdir "Comprimidas"

set "convertedList="

REM Procesar archivos mkv y mp4
for %%A in ("*.mkv" "*.mp4") do (

    REM Evitar iteraciones vacías
    if not exist "%%A" (
        continue
    )

    echo -------------------------------------------
    echo Analizando: %%A

    REM ==============================================
    REM Obtener CÓDEC y RESOLUCIÓN con ffprobe
    REM ==============================================
    for /f "tokens=1,2,3 delims=," %%i in ('
        ffprobe -v error -select_streams v:0 ^
        -show_entries stream=codec_name,width,height ^
        -of csv=p=0 "%%A"
    ') do (
        set "vcodec=%%i"
        set "vwidth=%%j"
        set "vheight=%%k"
    )

    REM Quitar espacios si aparecieran
    set "vcodec=!vcodec: =!"
    set "vwidth=!vwidth: =!"
    set "vheight=!vheight: =!"

    echo   Codec: !vcodec!
    echo   Resolución: !vwidth!x!vheight!

    REM ==============================================
    REM Saltar si el video es HEVC / H265
    REM ==============================================
    if /i "!vcodec!"=="hevc" (
        echo   >> Saltado (Es H.265)
        echo.
        continue
    )
    if /i "!vcodec!"=="h265" (
        echo   >> Saltado (Es H.265)
        echo.
        continue
    )

    REM ==============================================
    REM Saltar si resolución es menor a 1080p
    REM ==============================================
    if !vheight! LSS 1080 (
        echo   >> Saltado (Resolución menor a 1080p)
        echo.
        continue
    )

    echo   OK para comprimir.
    echo.

    REM ==========================================
    REM 1. Obtener fechas originales (PowerShell)
    REM ==========================================
    for /f "usebackq tokens=1,2 delims=|" %%i in (`
        powershell -NoProfile -Command ^
        "(Get-Item '%%~fA').CreationTime.ToString('yyyy-MM-dd HH:mm:ss') + '|' + (Get-Item '%%~fA').LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')"
    `) do (
        set "CREATED_PS=%%i"
        set "MODIFIED_PS=%%j"
    )

    REM ==========================================
    REM Nombre de salida (siempre MKV)
    REM ==========================================
    set "outputName=Comprimidas\%%~nA.mkv"

    echo   Procesando: %%A
    ffmpeg -hide_banner -loglevel warning -stats -hwaccel cuda -i "%%A" ^
       -vf "scale=-1:720:force_original_aspect_ratio=decrease,setsar=1" ^
       -c:v h264_nvenc -preset slow -rc vbr -cq 27 -b:v 0 -map 0 -c:a copy -c:s copy "!outputName!"

    if !ERRORLEVEL! EQU 0 (
        echo ✓ Conversion exitosa: %%A
        set "convertedList=!convertedList!%%A;"

        REM ===============================================
        REM 2. Restaurar fechas originales al archivo final
        REM ===============================================
        powershell -NoProfile -Command ^
            "(Get-Item '!outputName!').CreationTime = ('!CREATED_PS!');" ^
            "(Get-Item '!outputName!').LastWriteTime = ('!MODIFIED_PS!');"
    ) else (
        echo ✗ ERROR con: %%A
    )

    echo.
)


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
