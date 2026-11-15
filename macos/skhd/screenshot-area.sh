#!/bin/sh
# Option+Shift+S: captura de área (Espacio = elegir ventana) → portapapeles.
# - Pausa el "foco sigue al mouse" de Rift mientras eliges, para que no tape el resaltado.
# - Manda el borde de JankyBorders detrás de las ventanas: si está encima, el selector de
#   ventana (Espacio) captura el borde (una ventana vacía) en vez de la app.
R=/opt/homebrew/bin/rift-cli
B=/opt/homebrew/bin/borders
$R execute config set-focus-follows-mouse false >/dev/null 2>&1
$B order=below >/dev/null 2>&1
/usr/sbin/screencapture -i -c
$B order=above >/dev/null 2>&1
$R execute config set-focus-follows-mouse true >/dev/null 2>&1
