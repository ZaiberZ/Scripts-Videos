# ============================================
# VALIDACION: FFmpeg instalado
# ============================================
function Test-FFmpeg {
    return (Get-Command ffmpeg -ErrorAction SilentlyContinue) -ne $null
}

if (-not (Test-FFmpeg)) {
    Write-Host "FFmpeg no esta instalado." -ForegroundColor Yellow
    $resp = Read-Host "¿Deseas instalar FFmpeg usando winget? (S/N)"

    if ($resp -match '^[sS]') {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host "winget no esta disponible en este sistema." -ForegroundColor Red
            exit 1
        }

        winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements

        if (-not (Test-FFmpeg)) {
            Write-Host "FFmpeg no pudo instalarse." -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "No se puede continuar sin FFmpeg." -ForegroundColor Red
        exit 1
    }
}

# ============================================
# DETECTAR SOPORTE NVENC
# ============================================
$useNvenc = $false
$encoders = & ffmpeg -hide_banner -encoders 2>$null

if ($encoders -match 'h264_nvenc') {
    $useNvenc = $true
    Write-Host "NVENC detectado (GPU NVIDIA)" -ForegroundColor Green
}
else {
    Write-Host "NVENC no disponible, usando CPU (libx264)" -ForegroundColor Yellow
}

# ============================================
# Crear carpeta Comprimidas
# ============================================
$destDir = "Comprimidas"
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir | Out-Null
}

$convertedList = @()

# ============================================
# Procesar videos
# ============================================
Get-ChildItem -File *.mkv, *.mp4 | ForEach-Object {

    Write-Host "Procesando: $($_.Name)"
    $hasError = $false

    $created  = $_.CreationTime
    $modified = $_.LastWriteTime

    $outputName = Join-Path $destDir ($_.BaseName + ".mkv")

    # ============================================
    # CONVERSION
    # ============================================
    if ($useNvenc) {
        & ffmpeg -hide_banner -loglevel warning -stats `
          -i "$($_.FullName)" `
          -vf "scale=-1:720:force_original_aspect_ratio=decrease,setsar=1" `
          -c:v h264_nvenc -preset slow -rc vbr -cq 27 -b:v 0 `
          -map 0:v -map 0:a? -map 0:s? `
          -c:a copy -c:s copy `
          -map_metadata -1 "$outputName"
    }
    else {
        & ffmpeg -hide_banner -loglevel warning -stats `
          -i "$($_.FullName)" `
          -vf "scale=-1:720:force_original_aspect_ratio=decrease,setsar=1" `
          -c:v libx264 -preset slow -crf 23 `
          -map 0:v -map 0:a? -map 0:s? `
          -c:a copy -c:s copy `
          -map_metadata -1 "$outputName"
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Error en conversion" -ForegroundColor Red
        return
    }

    # ============================================
# VALIDACION
# ============================================

# Capturamos el error de ffmpeg
$ffmpegError = & ffmpeg -v error -i "$outputName" -f null - 2>&1

if ($LASTEXITCODE -ne 0) {

    Write-Host "Archivo con errores. Motivo:" -ForegroundColor Yellow
    Write-Host $ffmpegError -ForegroundColor DarkYellow

    Write-Host "Reparando archivo..." -ForegroundColor Yellow

    $fixed = "$outputName.fixed.mkv"

    $repairError = & ffmpeg -hide_banner -loglevel warning `
        -i "$outputName" `
        -map 0 -c copy -map_metadata -1 "$fixed" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Error al reparar el archivo" -ForegroundColor Red
        Write-Host $repairError -ForegroundColor DarkRed
        return
    }

    Move-Item -Force $fixed $outputName
    Write-Host "✓ Archivo reparado correctamente" -ForegroundColor Green
}
else {
    Write-Host "✓ Archivo validado sin errores" -ForegroundColor Green
}


    # ============================================
    # RESTAURAR FECHAS
    # ============================================
    $outItem = Get-Item $outputName
    $outItem.CreationTime  = $created
    $outItem.LastWriteTime = $modified

    $convertedList += $_.Name
    Write-Host "Conversion finalizada"
    Write-Host ""
}

# ============================================
# RESUMEN
# ============================================
Clear-Host
Write-Host "============================"
Write-Host "     VIDEOS CONVERTIDOS"
Write-Host "============================"
Write-Host ""

if ($convertedList.Count -gt 0) {
    $convertedList | ForEach-Object { Write-Host " - $_" }
}
else {
    Write-Host "(Ningun video fue convertido)"
}

Write-Host ""
Write-Host "Listo!"
Pause
