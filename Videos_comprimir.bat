@echo off
setlocal enabledelayedexpansion

if not exist "Comprimidas" mkdir "Comprimidas"

set "convertedList="

for %%A in ("*.mkv" "*.mp4") do (
    if not exist "%%A" (
        echo Saltando archivo inexistente
    ) else (
        echo Procesando: %%A
        set "HAS_ERROR=0"

        REM === Obtener fechas ===
        for /f "usebackq tokens=1,2 delims=|" %%i in (`
            powershell -NoProfile -Command ^
            "(Get-Item '%%~fA').CreationTime.ToString('yyyy-MM-dd HH:mm:ss') + '|' + (Get-Item '%%~fA').LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')"
        `) do (
            set "CREATED_PS=%%i"
            set "MODIFIED_PS=%%j"
        )

        set "outputName=Comprimidas\%%~nA.mkv"

        REM === Conversion segura ===
        ffmpeg -hide_banner -loglevel warning -stats ^
          -i "%%A" ^
          -vf "scale=-1:720:force_original_aspect_ratio=decrease,setsar=1" ^
          -c:v h264_nvenc -preset slow -rc vbr -cq 27 -b:v 0 ^
          -map 0:v -map 0:a? -map 0:s? ^
          -c:a copy -c:s copy ^
          -map_metadata -1 "!outputName!"

        if errorlevel 1 (
            echo ✗ Error en conversion
            set "HAS_ERROR=1"
        )

        REM === Validacion ===
        if "!HAS_ERROR!"=="0" (
            ffmpeg -v error -i "!outputName!" -f null - >nul 2>&1
            if errorlevel 1 (
                echo ⚠ Archivo con errores, reparando...

                ffmpeg -hide_banner -loglevel warning ^
                  -i "!outputName!" ^
                  -map 0 -c copy -map_metadata -1 "!outputName!.fixed.mkv"

                if errorlevel 1 (
                    echo ✗ Error al reparar
                    set "HAS_ERROR=1"
                ) else (
                    move /Y "!outputName!.fixed.mkv" "!outputName!" >nul
                    echo ✓ Archivo reparado
                )
            ) else (
                echo ✓ Archivo validado
            )
        )

        REM === Restaurar fechas ===
        if "!HAS_ERROR!"=="0" (
            powershell -NoProfile -Command ^
                "(Get-Item '!outputName!').CreationTime = ('!CREATED_PS!');" ^
                "(Get-Item '!outputName!').LastWriteTime = ('!MODIFIED_PS!');"

            set "convertedList=!convertedList!"%%A" "
            echo ✓ Conversion finalizada
        )

        echo.
    )
)

cls
echo ============================
echo      VIDEOS CONVERTIDOS
echo ============================
echo.

if defined convertedList (
    for %%B in (!convertedList!) do echo  - %%~B
) else (
    echo (Ningun video fue convertido)
)

echo.
echo Listo!
pause
