@echo off
rem Open the project in the Godot editor. Extra arguments are passed to Godot.
godot --path "%~dp0." -e %*
