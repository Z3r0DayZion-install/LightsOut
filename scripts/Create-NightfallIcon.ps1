#Requires -Version 5.1
<#
.SYNOPSIS
    Generate Lights Out / Sleep Timer multi-size .ico and .png
#>
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$assets = Join-Path $root 'assets'
New-Item -ItemType Directory -Path $assets -Force | Out-Null

function Draw-IconBitmap {
    param([int]$Size)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(14, 14, 18))

    $pad = [math]::Max(2, [int]($Size * 0.1))
    $rect = New-Object System.Drawing.Rectangle $pad, $pad, ($Size - 2 * $pad), ($Size - 2 * $pad)
    $w = [math]::Max(2, [int]($Size / 7.5))

    $track = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(34, 34, 46)), $w
    $g.DrawArc($track, $rect, 0, 360)
    $track.Dispose()

    $amber = [System.Drawing.Color]::FromArgb(237, 175, 88)
    $arc = New-Object System.Drawing.Pen $amber, $w
    $arc.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $arc.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawArc($arc, $rect, -90, 300)
    $arc.Dispose()

    # Moon crescent
    $moonBrush = New-Object System.Drawing.SolidBrush $amber
    $cx = [int]($Size * 0.5)
    $cy = [int]($Size * 0.52)
    $mr = [int]($Size * 0.14)
    $g.FillEllipse($moonBrush, ($cx - $mr), ($cy - $mr), (2 * $mr), (2 * $mr))
    $cut = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(14, 14, 18))
    $g.FillEllipse($cut, ($cx - [int]($mr * 0.35)), ($cy - $mr - 1), (2 * $mr), (2 * $mr))
    $moonBrush.Dispose()
    $cut.Dispose()
    $g.Dispose()
    return $bmp
}

$master = Draw-IconBitmap 256
$png = Join-Path $assets 'SleepTimer.png'
$master.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)

$hIcon = $master.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($hIcon)
foreach ($name in @('SleepTimer.ico', 'LightsOut.ico', 'Nightfall.ico')) {
    $fs = [System.IO.File]::Create((Join-Path $assets $name))
    $icon.Save($fs)
    $fs.Close()
}
$icon.Dispose()
$master.Dispose()
Write-Host "Icons: $assets\SleepTimer.ico, LightsOut.ico, SleepTimer.png"
