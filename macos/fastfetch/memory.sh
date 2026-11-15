#!/bin/sh
# Memory line for fastfetch: total + macOS memory pressure (cache doesn't count as "used").
total=$(( $(sysctl -n hw.memsize) / 1073741824 ))
used=$(memory_pressure 2>/dev/null | awk '/free percentage/{gsub("%","",$NF); print 100-$NF}')
case $(sysctl -n kern.memorystatus_vm_pressure_level) in
  1) level="normal";   color=32 ;;   # green
  2) level="warning";  color=33 ;;   # yellow
  4) level="critical"; color=31 ;;   # red
  *) level="unknown";  color=37 ;;
esac
printf '%s GiB · pressure \033[%sm%s%%\033[0m (\033[%sm%s\033[0m)\n' "$total" "$color" "$used" "$color" "$level"
