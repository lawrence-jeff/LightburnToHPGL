# LightburnToHPGL

This converts a Lightburn GCODE file (using the Marlin built in option) to a HPGL format compatible with my Redsail / Vinyl Express R Series 2 vinyl cutter.
This can output directly to a serial port, save to an HPGL file for sending (you can use copy X.hpgl \\.\COMX) or both

Only tested on my Redsail/VinyExpressR2 but you can tweak the serial protocol settings, the scaling, and whether your machine takes X or Y first in the options.

In Lightburn
*Setup a device using the Marlin Option- set it to the X dimmensions of your device + an appropriately large Y
*Make sure you are in absolute Coordinate mode in Lightburn
*The layer settings really don't matter, the speeds/power aren't used - it expects the cutter to control these
*When done with your design, use the save Gcode option to save a gc file
*Run the powershell script - it will prompt for the file, test your cutter and send it as it converts it
