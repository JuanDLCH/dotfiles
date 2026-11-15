#!/bin/sh
# Captura el monitor donde está el mouse y la copia al portapapeles (sin yabai).
# Requiere que skhd tenga permiso de "Grabación de pantalla".
region=$(/usr/bin/osascript -l JavaScript <<'JS'
ObjC.import("AppKit");
function run() {
  const m = $.NSEvent.mouseLocation;
  const screens = $.NSScreen.screens;
  const mainH = screens.objectAtIndex(0).frame.size.height;
  for (let i = 0; i < screens.count; i++) {
    const f = screens.objectAtIndex(i).frame;
    if (m.x >= f.origin.x && m.x < f.origin.x + f.size.width &&
        m.y >= f.origin.y && m.y <= f.origin.y + f.size.height) {
      const top = mainH - (f.origin.y + f.size.height);   // Cocoa (abajo-izq) → pantalla (arriba-izq)
      return [f.origin.x, top, f.size.width, f.size.height].map(Math.round).join(",");
    }
  }
  return "";
}
JS
)
[ -z "$region" ] && exit 1
exec /usr/sbin/screencapture -c -R "$region"
