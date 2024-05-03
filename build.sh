#!/bin/sh
PROJECTNAME="DevSoundX"

set -e

echo Assembling...
rgbasm -o $PROJECTNAME.obj -p 255 Main.asm

echo Linking...
rgblink -p 255 -o $PROJECTNAME.gbc -n $PROJECTNAME.sym $PROJECTNAME.obj

echo Fixing...
rgbfix -v -p 255 $PROJECTNAME.gbc

echo Cleaning up...
rm $PROJECTNAME.obj

echo Build complete.

# unset vars
PROJECTNAME=
echo "** Build finished with no errors **"
