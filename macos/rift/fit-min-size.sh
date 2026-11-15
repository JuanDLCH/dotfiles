#!/bin/sh
# Rift (master_stack): si una app no se deja achicar (WhatsApp, Claude, Spotify…) y se sale de
# su lado o se mete en el otro, mueve la división izquierda/derecha lo justo para que quepa.
# Actúa sobre el escritorio activo de cada monitor. Lo lanza Rift en "windows_changed".
R=/opt/homebrew/bin/rift-cli
J=/usr/bin/jq
GAP=10

LOCK="/tmp/rift-fit-$(id -u).lock"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK"' EXIT INT TERM

sleep 0.45   # dejar que termine la animación de Rift

# Delta de proporción que necesita un monitor (0 = nada que corregir).
delta_for() {  # $1 = uuid del monitor
  disp=$($R query displays | $J -c --arg u "$1" '.[] | select(.uuid == $u) | .frame')
  $R query workspaces --display "$1" | $J -r --argjson d "$disp" --argjson g "$GAP" '
    [ .[] | select(.is_active and .layout_mode == "master_stack" and .window_count >= 2) ][0]
    | if . == null then 0 else
      [ .windows[] | .frame ] as $w
      | ($w | min_by(.origin.x)) as $m                                   # ventana principal (izquierda)
      | [ $w[] | select(.origin.x > $m.origin.x + 5) ] as $s             # columna derecha
      | if ($s | length) == 0 then 0 else
        ($d.size.width - 2 * $g) as $uw
        | ([ $s[] | .origin.x ] | min) as $sx
        | ($m.origin.x + $m.size.width + $g - $sx) as $over_master        # principal se mete a la derecha
        | ([ $s[] | .origin.x + .size.width - ($d.origin.x + $d.size.width - $g) ] | max) as $over_edge  # derecha se sale
        | if $over_master > 2 and $over_edge > 2 then 0                  # no caben las dos: no tocar
          elif $over_master > 2 then  ($over_master / $uw)
          elif $over_edge > 2   then -($over_edge / $uw)
          else 0 end
        end
      end'
}

focused=$($R query workspaces | $J -r '.[] | select(.is_focused) | .display_uuid' | head -1)

for pass in 1 2 3; do
  changed=0
  for uuid in $($R query displays | $J -r '.[].uuid'); do
    d=$(delta_for "$uuid")
    case "$d" in 0|0.0|"") continue ;; esac
    # adjust-master-ratio actúa sobre el monitor enfocado
    switched=0
    if [ "$uuid" != "$focused" ]; then
      $R execute display focus --uuid "$uuid" >/dev/null 2>&1; switched=1
    fi
    $R execute layout adjust-master-ratio -- "$d" >/dev/null 2>&1
    [ "$switched" = 1 ] && $R execute display focus --uuid "$focused" >/dev/null 2>&1
    changed=1
  done
  [ "$changed" = 0 ] && break
  sleep 0.45
done
