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
    } else {
        Write-Host "No se puede continuar sin FFmpeg." -ForegroundColor Red
        exit 1
    }
}

# ============================================
# DETECTAR SOPORTE NVENC (GPU NVIDIA)
# ============================================
$useNvenc = $false
$encoders = & ffmpeg -hide_banner -encoders 2>$null

if ($encoders -match 'h264_nvenc') {
    $useNvenc = $true
    Write-Host "NVENC detectado (GPU NVIDIA)" -ForegroundColor Green
} else {
    Write-Host "NVENC no disponible, usando CPU (libx264)" -ForegroundColor Yellow
}

# ============================================
# Crear carpeta Comprimidas
# ============================================
$destDir = "Comprimidas"
if (-not (Test-Path $destDir)) {
