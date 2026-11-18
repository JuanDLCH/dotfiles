#!/bin/sh
# Option+Shift+S: captura de área (Espacio = elegir ventana) → portapapeles.
# - Pausa AutoRaise mientras eliges: si no, al pasar el mouse trae ventanas al frente.
# - Manda el borde de JankyBorders detrás de las ventanas: si está encima, el selector de
#   ventana (Espacio) captura el borde (una ventana vacía) en vez de la app.
B=/opt/homebrew/bin/borders
resume() { [ -e /tmp/edgesync-autoraise-paused ] || /usr/bin/pkill -CONT -x AutoRaise; $B order=above >/dev/null 2>&1; }
trap resume EXIT INT TERM
/usr/bin/pkill -STOP -x AutoRaise
$B order=below >/dev/null 2>&1
/usr/sbin/screencapture -i -c
