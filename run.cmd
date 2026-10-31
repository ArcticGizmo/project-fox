@echo off
rem Play the game. Extra arguments are passed to Godot, e.g. run --maximized
godot --path "%~dp0." %*
