[CmdletBinding()]
param(
    # Accept a single string (comma/space/newline separated) so it works
    # consistently when invoked via `powershell -File ...`.
    [Parameter(Mandatory = $true)]
    [string]$Users,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile,

    [int]$Cols = 6,
    [double]$CellCm = 2.5,
    [int]$Dpi = 300,
    [int]$GapPx = 12,
    [int]$PadPx = 16,
    [string]$CacheDir = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# Split on commas, whitespace and newlines.
$rawUsers = $Users -split '[,\s]+'

# Normalize usernames: strip leading '@', drop empties, dedupe (preserving order).
$seen = New-Object System.Collections.Generic.HashSet[string]
$names = New-Object System.Collections.Generic.List[string]
foreach ($u in $rawUsers) {
    if (-not $u) { continue }
    $name = $u.Trim().TrimStart('@')
    if (-not $name) { continue }
    if ($seen.Add($name)) { [void]$names.Add($name) }
}
if ($names.Count -eq 0) { throw "No usernames provided." }

# Cache dir for downloaded avatars.
if (-not $CacheDir) {
    $CacheDir = Join-Path ([System.IO.Path]::GetTempPath()) "karmada-contributors-cache"
}
if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
}

# Download avatars from https://github.com/<user>.png if not already cached.
foreach ($name in $names) {
    $dest = Join-Path $CacheDir ("{0}.png" -f $name)
    if (Test-Path $dest) { continue }
    $url = "https://github.com/$name.png"
    Write-Host "Downloading $url"
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -MaximumRedirection 5
    } catch {
        throw "Failed to download avatar for '$name' from $url : $($_.Exception.Message)"
    }
}

# Cell size in pixels for 2.5 cm at the requested DPI (1 inch = 2.54 cm).
$cell = [int][Math]::Round($CellCm / 2.54 * $Dpi)
$rows = [int][Math]::Ceiling($names.Count / [double]$Cols)
$width  = $PadPx * 2 + $Cols * $cell + ($Cols - 1) * $GapPx
$height = $PadPx * 2 + $rows * $cell + ($rows - 1) * $GapPx

$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([System.Drawing.Color]::White)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

try {
    for ($i = 0; $i -lt $names.Count; $i++) {
        $imgPath = Join-Path $CacheDir ("{0}.png" -f $names[$i])
        $image = [System.Drawing.Image]::FromFile($imgPath)
        try {
            # Use Floor; [int](a/b) would *round* (e.g. [int](5/6) -> 1).
            $row = [int][Math]::Floor($i / $Cols)
            $col = $i % $Cols
            $x = $PadPx + $col * ($cell + $GapPx)
            $y = $PadPx + $row * ($cell + $GapPx)
            $graphics.DrawImage($image, $x, $y, $cell, $cell)
        } finally {
            $image.Dispose()
        }
    }

    $outDir = Split-Path -Parent ([System.IO.Path]::GetFullPath($OutputFile))
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    $bitmap.Save($OutputFile, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}

Write-Host ("Generated: {0} ({1} contributors, {2}x{3}px)" -f $OutputFile, $names.Count, $width, $height)

