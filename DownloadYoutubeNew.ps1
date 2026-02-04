Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " Descarga de video con yt-dlp (MP4 H.264)"
Write-Host "========================================="

try {
    # 1. Verificar yt-dlp
    if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
        Write-Host "yt-dlp no esta instalado."

        $resp = Read-Host "Deseas instalar yt-dlp con winget? (s/n)"
        if ($resp -ne "s") {
            throw "yt-dlp es requerido. Proceso cancelado."
        }

        Write-Host "Instalando yt-dlp..."
        winget install -e --id yt-dlp.yt-dlp

        if ($LASTEXITCODE -ne 0) {
            throw "Error al instalar yt-dlp con winget."
        }

        Write-Host "yt-dlp instalado correctamente."
    }

    # 2. Pedir URL
    $url = Read-Host "`nIngresa la URL del video"
    if ([string]::IsNullOrWhiteSpace($url)) {
        throw "URL invalida."
    }

    # 3. Descargar
    Write-Host "`nDescargando video..."

    yt-dlp `
        "$url" `
        -f "bv*[vcodec=h264][ext=mp4]+ba[acodec=aac]/b" `
        --merge-output-format mp4

    if ($LASTEXITCODE -ne 0) {
        throw "yt-dlp fallo al descargar el video."
    }

    Write-Host "`nDescarga finalizada correctamente."
}
catch {
    Write-Host "`nERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
finally {
    Write-Host "`nPresiona ENTER para cerrar..."
    Read-Host
}
