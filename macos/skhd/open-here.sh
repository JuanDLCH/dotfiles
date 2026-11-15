#!/bin/sh
# Abre una app (mismos argumentos que `open`) y, si su ventana NUEVA aparece en otro monitor,
# la manda al monitor donde está el mouse. macOS abre cada app donde quiere (donde estuvo la
# última vez, junto a su otra ventana…), y eso desordena el otro monitor.
# Si la app ya estaba abierta y solo se activa (sin ventana nueva), no mueve nada.
R=/opt/homebrew/bin/rift-cli
J=/usr/bin/jq

# Ventanas de todos los monitores: "<window_server_id> <uuid del monitor> <id JSON>" por línea.
windows() {
  for u in $uuids; do
    $R query windows --display "$u" | $J -r --arg u "$u" '.[] | "\(.window_server_id) \($u) \(.id | tojson)"'
  done
}

# Mouse en coordenadas de pantalla (arriba-izquierda), como las de Rift.
mouse=$(/usr/bin/osascript -l JavaScript -e '
ObjC.import("AppKit");
const m = $.NSEvent.mouseLocation;
const h = $.NSScreen.screens.objectAtIndex(0).frame.size.height;
Math.round(m.x) + " " + Math.round(h - m.y)')
mx=${mouse% *}; my=${mouse#* }

displays=$($R query displays)
uuids=$(printf '%s' "$displays" | $J -r '.[].uuid')
# El frame de Rift empieza bajo la barra de menú: se amplía 40 px hacia arriba.
target=$(printf '%s' "$displays" | $J -r --argjson x "$mx" --argjson y "$my" '
  .[] | select($x >= .frame.origin.x and $x < .frame.origin.x + .frame.size.width
           and $y >= .frame.origin.y - 40 and $y < .frame.origin.y + .frame.size.height)
  | .uuid' | head -n1)

before=$(windows | cut -d' ' -f1)
open "$@"
[ -z "$target" ] && exit 0

i=0
while [ $i -lt 40 ]; do   # hasta ~4 s
  sleep 0.1; i=$((i + 1))
  new=$(windows | while read -r wsid uuid id; do
    printf '%s\n' "$before" | grep -qx "$wsid" || echo "$wsid $uuid $id"
  done)
  [ -z "$new" ] && continue
  printf '%s\n' "$new" | while read -r wsid uuid id; do
    [ "$uuid" = "$target" ] && continue
    idx=$(printf '%s' "$id" | $J -r .idx)
    $R execute display move-window --uuid "$target" --window-id "$idx" >/dev/null 2>&1
    $R execute window focus --window-id "$id" >/dev/null 2>&1
  done
  exit 0
done
