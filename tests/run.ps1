# Runs tests\run.lua on DmorphOcto's LuaHost with OctoBG's mock client.
#   powershell -ExecutionPolicy Bypass -File tests\run.ps1
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$exe = Join-Path $root "..\DmorphOcto\tools\LuaHost\bin\LuaHost.exe"
if (-not (Test-Path $exe)) { throw "LuaHost not built: run DmorphOcto\tools\run_tests.ps1 once" }
Push-Location $root
try { & $exe "tests/run.lua"; exit $LASTEXITCODE } finally { Pop-Location }
