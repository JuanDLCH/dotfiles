#!/bin/sh
# Option+Shift+S (y el botón lateral del mouse): captura de área con Shottr, que congela la
# pantalla mientras eliges. Shottr debe estar abierto (vive en la barra de menú).
pgrep -xq Shottr || { open -g /Applications/Shottr.app; sleep 1; }
open -g "shottr://grab/area"
