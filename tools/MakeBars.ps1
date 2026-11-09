# Writes the two bar textures in media\ (white, shaded top to bottom; coloured in game).
#   powershell -ExecutionPolicy Bypass -File tools\MakeBars.ps1
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function Write-Bar($name, [scriptblock]$shade) {
  $w = 64; $h = 16
  $bytes = New-Object byte[] (18 + $w * $h * 4)
  $bytes[2] = 2                      # uncompressed true colour
  $bytes[12] = $w; $bytes[14] = $h
  $bytes[16] = 32                    # bits per pixel
  $bytes[17] = 0x28                  # 8 alpha bits, top-left origin
  $i = 18
  for ($y = 0; $y -lt $h; $y++) {
    $t = $y / ($h - 1)
    $v = [Math]::Max(0, [Math]::Min(255, [int](255 * (& $shade $t))))
    for ($x = 0; $x -lt $w; $x++) {
      $bytes[$i] = $v; $bytes[$i + 1] = $v; $bytes[$i + 2] = $v; $bytes[$i + 3] = 255
      $i += 4
    }
  }
  [IO.File]::WriteAllBytes((Join-Path $root "media\$name.tga"), $bytes)
}
# a soft fall from top to bottom
Write-Bar "bar-smooth" { param($t) 1.0 - 0.28 * $t }
# a bright top half with a line of light, a darker bottom half
Write-Bar "bar-gloss" { param($t) if ($t -lt 0.5) { 1.0 - 0.14 * ($t * 2) } else { 0.78 - 0.12 * (($t - 0.5) * 2) } }
