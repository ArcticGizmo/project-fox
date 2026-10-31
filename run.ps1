# Play the game. Extra arguments are passed to Godot, e.g. .\run.ps1 --maximized
& godot --path $PSScriptRoot @args
exit $LASTEXITCODE
