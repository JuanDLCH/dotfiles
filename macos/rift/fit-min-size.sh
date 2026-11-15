#!/bin/sh
# Rift: si una app no se deja achicar (WhatsApp ~970 px de ancho, Claude, Spotify…) y se sale
# del monitor o se mete encima de su vecina, le da más espacio a ESA ventana (resize-grow en el
# eje del problema), lo que achica a la vecina que sí se deja. Sirve para BSP y master-stack.
# Lo lanza Rift en "windows_changed" (run_on_start) y también ⌥⇧0.
R=/opt/homebrew/bin/rift-cli
J=/usr/bin/jq
GAP=10
MAX_STEPS=10

LOCK="/tmp/rift-fit-$(id -u).lock"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK"' EXIT INT TERM

sleep 0.45   # dejar que termine la animación de Rift

# Primer problema del monitor $1 → "<id JSON>\t<horizontal|vertical>\t<px>", o nada.
problem() {
  disp=$($R query displays | $J -c --arg u "$1" '.[] | select(.uuid == $u) | .frame')
  $R query workspaces --display "$1" | $J -r --argjson d "$disp" --argjson g "$GAP" '
    def ov(a0; a1; b0; b1): ([a1, b1] | min) - ([a0, b0] | max);
    ([ .[] | select(.is_active) ][0] // {windows: []})
    | [ .windows[] | select(.is_floating | not) ] as $w
    | [ $w[] as $a
        | ($a.frame.origin.x + $a.frame.size.width) as $ar
        | ($a.frame.origin.y + $a.frame.size.height) as $ab
        | ( ( $w[] | select(.id != $a.id) as $b
              | $b.frame.origin.x as $bx | $b.frame.origin.y as $by
              | ( select($a.frame.origin.x < $bx
                    and ov($a.frame.origin.y; $ab; $by; $by + $b.frame.size.height) > 20
                    and $ar + $g - $bx > 2)
                  | [$a.id, "horizontal", ($ar + $g - $bx)] ),
                ( select($a.frame.origin.y < $by
                    and ov($a.frame.origin.x; $ar; $bx; $bx + $b.frame.size.width) > 20
                    and $ab + $g - $by > 2)
                  | [$a.id, "vertical", ($ab + $g - $by)] ) ),
            ( select($ar + $g - ($d.origin.x + $d.size.width) > 2)
              | [$a.id, "horizontal", ($ar + $g - ($d.origin.x + $d.size.width))] ),
            ( select($ab + $g - ($d.origin.y + $d.size.height) > 2)
              | [$a.id, "vertical", ($ab + $g - ($d.origin.y + $d.size.height))] ) )
      ]
    | first // empty
    | "\(.[0] | tojson)\t\(.[1])\t\(.[2] | floor)"'
}

orig_win=""
for u in $($R query displays | $J -r '.[].uuid'); do
  w=$($R query workspaces --display "$u" | $J -c '.[] | select(.is_active) | .windows[] | select(.is_focused) | .id')
  [ -n "$w" ] && { orig_win=$w; break; }
done

paused=0
for uuid in $($R query displays | $J -r '.[].uuid'); do
  last_key=""; last_px=0; steps=0
  while [ $steps -lt $MAX_STEPS ]; do
    p=$(problem "$uuid")
    [ -z "$p" ] && break
    win=$(printf '%s' "$p" | cut -f1); axis=$(printf '%s' "$p" | cut -f2); px=$(printf '%s' "$p" | cut -f3)
    # El mismo problema no mejoró con el paso anterior → no caben juntas: dejarlo así.
    [ "$win $axis" = "$last_key" ] && [ "$px" -ge "$last_px" ] && break
    last_key="$win $axis"; last_px=$px
    if [ $paused = 0 ]; then
      # Pausar "foco sigue al mouse" (si no, el foco vuelve a la ventana bajo el cursor) y
      # "mouse sigue al foco" (para que el cursor no salte) mientras se ajusta.
      $R execute config set-focus-follows-mouse false >/dev/null 2>&1
      $R execute config set-mouse-follows-focus false >/dev/null 2>&1; paused=1
    fi
    $R execute window focus --window-id "$win" >/dev/null 2>&1
    $R execute window resize-grow --orientation "$axis" >/dev/null 2>&1
    steps=$((steps + 1))
    sleep 0.4
  done
done

if [ $paused = 1 ]; then
  [ -n "$orig_win" ] && $R execute window focus --window-id "$orig_win" >/dev/null 2>&1
  $R execute config set-mouse-follows-focus true >/dev/null 2>&1
  $R execute config set-focus-follows-mouse true >/dev/null 2>&1
fi
