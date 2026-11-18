#!/bin/sh
# Option+Shift+S: captura de área (Espacio = elegir ventana) → portapapeles.
# Manda el borde de JankyBorders detrás de las ventanas: si está encima, el selector de
# ventana (Espacio) captura el borde (una ventana vacía) en vez de la app.
# AutoRaise no roba el foco mientras eliges (stayFocusedBundleIds incluye screencaptureui).
B=/opt/homebrew/bin/borders
$B order=below >/dev/null 2>&1
/usr/sbin/screencapture -i -c
$B order=above >/dev/null 2>&1
