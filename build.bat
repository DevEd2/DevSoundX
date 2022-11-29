@echo off
set PROJECTNAME="DevSoundX"

rem	Build ROM

echo Assembling...
rgbasm -o %PROJECTNAME%.obj -p 255 Main.asm
if errorlevel 1 goto :BuildError

echo Linking...
rgblink -p 255 -o %PROJECTNAME%.gbc -n %PROJECTNAME%.sym %PROJECTNAME%.obj
if errorlevel 1 goto :BuildError

echo Fixing...
rgbfix -v -p 255 %PROJECTNAME%.gbc

echo Cleaning up...
del %PROJECTNAME%.obj
echo Build complete.
goto :end

:BuildError
set PROJECTNAME=
echo Build failed, aborting...
goto:eof

:end
rem unset vars
set PROJECTNAME=
echo ** Build finished with no errors **
