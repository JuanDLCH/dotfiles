#!/bin/sh
# Option+Shift+S: captura de área (Espacio = elegir ventana) → portapapeles.
# Pausa el "foco sigue al mouse" de Rift mientras eliges, para que no tape el resaltado.
R=/opt/homebrew/bin/rift-cli
$R execute config set-focus-follows-mouse false >/dev/null 2>&1
/usr/sbin/screencapture -i -c
$R execute config set-focus-follows-mouse true >/dev/null 2>&1
