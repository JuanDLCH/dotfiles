#!/bin/sh
# Option+Shift+S (y el botón lateral del mouse): captura con la pantalla congelada (freeze-shot,
# del repo edgesync): clic = ventana, arrastrar = área, Esc = cancelar → portapapeles.
# Se pausa AutoRaise mientras tanto (si no, al pasar el mouse traería ventanas al frente).
resume() { [ -e /tmp/edgesync-autoraise-paused ] || /usr/bin/pkill -CONT -x AutoRaise; }
trap resume EXIT INT TERM
/usr/bin/pkill -STOP -x AutoRaise
"$HOME/.local/bin/freeze-shot"
