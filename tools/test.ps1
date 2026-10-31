# Runs the headless test suite.
#   .\tools\test.ps1              run everything
#   .\tools\test.ps1 -Filter bull only tests whose file/method contains "bull"
# Fails if any test fails OR the engine printed a script/engine error.
param([string]$Filter = "")

$root = Split-Path -Parent $PSScriptRoot

# Refresh the import cache / global class registry (needed after adding class_name scripts).
$null = & godot --headless --path $root --import 2>&1

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
