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

prev=""   # uuid:signo de la corrección anterior, para detectar ida y vuelta
for pass in 1 2 3; do
  changed=0
  for uuid in $($R query displays | $J -r '.[].uuid'); do
    d=$(delta_for "$uuid")
    case "$d" in 0|0.0|"") continue ;; esac
    sign=$(echo "$d" | cut -c1); [ "$sign" = "-" ] || sign="+"
    # Si ahora corrige al revés que antes, las dos apps no caben juntas: no insistir.
    case "$prev" in *"$uuid:"*) case "$prev" in *"$uuid:$sign"*) ;; *) continue ;; esac ;; esac
    prev="$prev $uuid:$sign"
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

# ---------- Columna derecha: alto mínimo (p. ej. WhatsApp sobre Kitty) ----------
# Si una ventana de la columna no se deja achicar en alto y se mete en la de abajo (o se sale
# por abajo), se le da más alto a ella con resize-grow vertical, que achica a su vecina.
vertical_culprit() {  # $1 = uuid → imprime el id JSON de la ventana a agrandar, o nada
  disp=$($R query displays | $J -c --arg u "$1" '.[] | select(.uuid == $u) | .frame')
  $R query workspaces --display "$1" | $J -c --argjson d "$disp" --argjson g "$GAP" '
    [ .[] | select(.is_active and .layout_mode == "master_stack" and .window_count >= 3) ][0]
    | if . == null then empty else
      ([ .windows[] | .frame.origin.x ] | min) as $mx
      | [ .windows[] | select(.frame.origin.x > $mx + 5) ] | sort_by(.frame.origin.y) as $s
      | ( [ range(0; ($s | length) - 1) as $i
            | select($s[$i].frame.origin.y + $s[$i].frame.size.height + $g - $s[$i+1].frame.origin.y > 2)
            | $s[$i].id ]
          + [ $s[-1] | select(.frame.origin.y + .frame.size.height + $g - ($d.origin.y + $d.size.height) > 2) | .id ]
        ) | first // empty
      end'
}

orig_win=$(for u in $($R query displays | $J -r '.[].uuid'); do
  $R query workspaces --display "$u" | $J -c '.[] | select(.is_active) | .windows[] | select(.is_focused) | .id'
done | head -1)
moved=0
for uuid in $($R query displays | $J -r '.[].uuid'); do
  for step in 1 2 3 4 5 6 7 8; do
    win=$(vertical_culprit "$uuid")
    [ -z "$win" ] && break
    if [ "$moved" = 0 ]; then
      $R execute config set-mouse-follows-focus false >/dev/null 2>&1; moved=1
    fi
    $R execute window focus --window-id "$win" >/dev/null 2>&1
    $R execute window resize-grow --orientation vertical >/dev/null 2>&1
    sleep 0.4
  done
done
if [ "$moved" = 1 ]; then
  [ -n "$orig_win" ] && $R execute window focus --window-id "$orig_win" >/dev/null 2>&1
  $R execute config set-mouse-follows-focus true >/dev/null 2>&1
fi
