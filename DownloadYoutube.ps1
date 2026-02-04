Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " Descarga YouTube WhatsApp (fallback 720p)"
Write-Host "========================================="

# -----------------------------
# 1. Pedir URL
# -----------------------------
$url = Read-Host "`nIngresa la URL del video"
if ([string]::IsNullOrWhiteSpace($url)) {
    throw "URL invalida."
}

# -----------------------------
# 2. Obtener informacion
# -----------------------------
Write-Host "`nAnalizando informacion del video..."

function Get-VideoInfo {
    param ($args, $label)

    Write-Host "Intentando obtener informacion ($label)..."

    try {
        $json = yt-dlp -J "$url" $args 2>$null
        if ($json) {
            return $json | ConvertFrom-Json
        }
    } catch {}
    return $null
}

$info = Get-VideoInfo '--extractor-args "youtube:player_client=ios"' "cliente iOS"

if (-not $info) {
    $info = Get-VideoInfo '--extractor-args "youtube:player_client=web"' "cliente web"
}

if (-not $info) {
    $info = Get-VideoInfo '--cookies-from-browser chrome' "cookies Chrome"
}

if (-not $info) {
    throw "No se pudo obtener informacion del video (bloqueado por YouTube)."
}


# -----------------------------
# 3. Detectar SHORT
# -----------------------------
if ($info.duration -and $info.duration -le 60) {
    Write-Host "Video SHORT detectado ($($info.duration) segundos)"
}

# -----------------------------
# 4. Filtrar formatos validos
# -----------------------------
$formats = $info.formats | Where-Object {
    $_.vcodec -ne "none" -and
    $_.acodec -ne "none" -and
    $_.height -ne $null -and
    $_.width -ne $null -and
    $_.vcodec -notmatch "av01"
}

if (-not $formats) {
    throw "No hay formatos validos con audio y video."
}

# -----------------------------
# 5. Resolver altura (720 -> 480)
# -----------------------------
$targetHeights = @(720, 480)

$selectedHeight = $null
foreach ($h in $targetHeights) {
    if ($formats.height -contains $h) {
        $selectedHeight = $h
        break
    }
}

if (-not $selectedHeight) {
    $selectedHeight = ($formats.height | Sort-Object -Descending | Select-Object -First 1)
    Write-Host "720p y 480p no disponibles. Usando $selectedHeight p"
} elseif ($selectedHeight -eq 480) {
    Write-Host "720p no disponible. Fallback automatico a 480p"
}

$selectedFormat = $formats |
    Where-Object { $_.height -eq $selectedHeight } |
    Sort-Object filesize -Descending |
    Select-Object -First 1

$codec = "H.264"
if ($selectedFormat.vcodec -match "vp9") { $codec = "VP9" }

Write-Host "`nDescargando $($selectedFormat.width)x$selectedHeight ($codec) -> convirtiendo a H.264"

# -----------------------------
# 6. Función de descarga
# -----------------------------
function Try-Download($extraArgs, $label) {
    Write-Host "Intentando descarga ($label)..."

    yt-dlp `
        "$url" `
        -f "bestvideo*[height=$selectedHeight][vcodec!=av01]+bestaudio/best[height=$selectedHeight]" `
        --merge-output-format mkv `
        --concurrent-fragments 1 `
        --retries 5 `
        --fragment-retries 5 `
        $extraArgs `
        -o "%(title)s_source.%(ext)s"

    return (Get-ChildItem "*_source.*" -ErrorAction SilentlyContinue | Select-Object -First 1)
}

# -----------------------------
# 7. Intentos escalonados
# -----------------------------
$source = Try-Download '--extractor-args "youtube:player_client=ios"' "cliente iOS"

if (-not $source) {
    $source = Try-Download '--extractor-args "youtube:player_client=web"' "cliente web"
}

if (-not $source) {
    Write-Host "Intentando con cookies del navegador..."
    $source = Try-Download '--cookies-from-browser chrome' "cookies Chrome"
}

if (-not $source) {
    throw "Video bloqueado definitivamente (403). No se pudo descargar."
}

# -----------------------------
# 8. Convertir sin reescalar
# -----------------------------
$output = ($source.Name -replace "_source\..+$", ".mp4")

Write-Host "`nConvirtiendo a MP4 (H.264 + AAC)..."

$ffmpegArgs = @(
    "-y",
    "-i", $source.Name,
    "-c:v", "libx264",
    "-profile:v", "high",
    "-level", "4.1",
    "-pix_fmt", "yuv420p",
    "-preset", "slow",
    "-crf", "23",
    "-movflags", "+faststart",
    "-c:a", "aac",
    "-b:a", "128k",
    "-progress", "pipe:1",
    "-nostats",
    "-loglevel", "error",
    $output
)

$process = Start-Process ffmpeg `
    -ArgumentList $ffmpegArgs `
    -NoNewWindow `
    -RedirectStandardOutput pipe `
    -PassThru

while (-not $process.HasExited) {
    $line = $process.StandardOutput.ReadLine()
    if ($line -match "out_time_ms") {
        Write-Host "." -NoNewline
    }
}

Write-Host "`nConversion finalizada."

# -----------------------------
# 9. Limpiar
# -----------------------------
Remove-Item $source.FullName -Force
Write-Host "Archivo temporal eliminado."
Write-Host "`nProceso completado con exito."
