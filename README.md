# LightburnToHPGL

This converts a Lightburn GCODE file (using the Marlin built in option) to a HPGL format compatible with my Redsail / Vinyl Express R Series 2 vinyl cutter.
This can output directly to your device, save to an HPGL file for sending seperately (you can use copy X.hpgl \\.\COMX) or do both at the same time (default but you are prompted)

Only tested on my Redsail/VinyExpressR2 but you can tweak the serial protocol settings, the scaling, and whether your machine takes X or Y first in the options.I compared the HPGL files generated by this with Lightburn to the ones from commerical software (both visually and via the outputs) and Lightburn seems fairly equivalent

In Lightburn
<li>Setup a device using the Marlin Option- set it to the X dimmensions of your device + an appropriately large Y</li>
<li>Make sure you are in absolute Coordinate mode in Lightburn</li>
<li>The layer settings really don't matter, the speeds/power aren't used - it expects the cutter to control these. One exception is the kerf settings you should bump this up to .2mm or so to better account for the knife vs laser spot size</li>
<li>When done with your design, use the save Gcode option to save a gc file</li>
<li>Run the powershell script - it will prompt for the file, test your cutter and send it as it converts it. You could also tweak this to monitor a directort in which case you can just save in Lightburn to that directory and have it auto convert/send (To be added)</li>

<br><b>

If you find this useful and it saves you from buying another piece of software, buy me a beer:<br>
[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.me/lawrencejeff/4)
