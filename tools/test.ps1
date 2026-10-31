# Runs the headless test suite.
#   .\tools\test.ps1              run everything
#   .\tools\test.ps1 -Filter bull only tests whose file/method contains "bull"
# Fails if any test fails OR the engine printed a script/engine error.
param([string]$Filter = "")

$root = Split-Path -Parent $PSScriptRoot

# Refresh the import cache / global class registry (needed after adding class_name scripts).
# A brand-new script sometimes needs a second import pass before its class_name is
# registered, so verify every class_name made it into the cache.
$classNames = Get-ChildItem -Path $root -Recurse -Filter *.gd |
    Where-Object { $_.FullName -notmatch '\\\.godot\\' } |
    Select-String -Pattern '^class_name\s+(\w+)' |
    ForEach-Object { $_.Matches[0].Groups[1].Value }
$cache = Join-Path $root ".godot\global_script_class_cache.cfg"
for ($i = 0; $i -lt 3; $i++) {
    $null = & godot --headless --path $root --import 2>&1
    $cached = if (Test-Path $cache) { Get-Content $cache -Raw } else { "" }
    $missing = $classNames | Where-Object { $cached -notmatch "&`"$_`"" }
    if (-not $missing) { break }
}
if ($missing) { Write-Host "Classes not registered after import: $($missing -join ', ')" -ForegroundColor Red; exit 1 }

$godotArgs = @("--headless", "--fixed-fps", "60", "--path", $root, "res://tests/test_runner.tscn")
if ($Filter) { $godotArgs += @("--", "--filter=$Filter") }

$output = & godot @godotArgs 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
$output | ForEach-Object { Write-Host $_ }

$errors = $output | Where-Object { $_ -match "SCRIPT ERROR|^ERROR:|Parse Error|Invalid call|Invalid access" }
if ($errors) {
    Write-Host ""
    Write-Host "Engine errors detected:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    if ($code -eq 0) { $code = 1 }
}
exit $code
