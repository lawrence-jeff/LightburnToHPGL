# LightburnToHPGL

This converts a Lightburn GCODE file (using the Marlin built in option) to a HPGL format compatible with my Redsail / Vinyl Express R Series 2 vinyl cutter.
This can output directly to a serial port, save to an HPGL file for sending (you can use copy X.hpgl \\.\COMX) or both

Only tested on my Redsail/VinyExpressR2 but you can tweak the serial protocol settings, the scaling, and whether your machine takes X or Y first in the options.
