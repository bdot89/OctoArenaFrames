# Crops the release screenshots (15 Nov 2026, the user's /oaf test shots at 2560x1600) into docs\.
# Options window crops are 1:1; the frames are enlarged so they read on Discord.
#   powershell -ExecutionPolicy Bypass -File tools\MakeShots.ps1
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$shots = "C:\Games\OctoWoW\Screenshots"
$out = Join-Path $root "docs"
New-Item -ItemType Directory -Force $out | Out-Null
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$qp = New-Object System.Drawing.Imaging.EncoderParameters 1
$qp.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 92L

function Crop($file, $name, $x, $y, $w, $h, $scale) {
  $src = [System.Drawing.Image]::FromFile((Join-Path $shots $file))
  $ow = [int]($w * $scale); $oh = [int]($h * $scale)
  $bmp = New-Object System.Drawing.Bitmap $ow, $oh
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $ow, $oh), (New-Object System.Drawing.Rectangle $x, $y, $w, $h), [System.Drawing.GraphicsUnit]::Pixel)
  $bmp.Save((Join-Path $out $name), $codec, $qp)
  $g.Dispose(); $bmp.Dispose(); $src.Dispose()
  "$name  ${ow}x$oh"
}

# the options window, one page each (window at 1074,296 1070 x 966 in every shot)
Crop "WoWScrnShot_111526_115309_0.png" "page-match.jpg"     1074 296 1070 966 1
Crop "WoWScrnShot_111526_115323_0.png" "page-frames.jpg"    1074 296 1070 966 1
Crop "WoWScrnShot_111526_115325_0.png" "page-cooldowns.jpg" 1074 296 1070 966 1
Crop "WoWScrnShot_111526_115328_0.png" "page-strips.jpg"    1074 296 1070 966 1
Crop "WoWScrnShot_111526_115332_0.png" "page-spells.jpg"    1074 296 1070 966 1
Crop "WoWScrnShot_111526_115334_0.png" "page-alerts.jpg"    1074 296 1070 966 1
# the frames: a full 5v5, and two fights (crowd control, DR, kicks, casts)
Crop "WoWScrnShot_111526_115309_0.png" "frames-5v5.jpg"     612 80 330 708 2
Crop "WoWScrnShot_111526_115316_0.png" "frames-3v3.jpg"     612 80 330 420 2
Crop "WoWScrnShot_111526_115334_0.png" "frames-fight.jpg"   580 80 350 292 2.5
Crop "WoWScrnShot_111526_115325_0.png" "frames-fight2.jpg"  580 80 350 292 2.5
Crop "WoWScrnShot_111526_115328_0.png" "frames-channel.jpg" 580 80 350 292 2.5
