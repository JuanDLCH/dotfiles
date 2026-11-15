#!/bin/sh
# Memory line for fastfetch based on macOS memory pressure: "used" is the part of RAM macOS
# can't free right away (100% - memory_pressure's free %). Cache doesn't count.
# The color follows the pressure level (green normal, yellow warning, red critical).
total=$(sysctl -n hw.memsize)
free_pct=$(memory_pressure 2>/dev/null | awk '/free percentage/{gsub("%","",$NF); print $NF}')
case $(sysctl -n kern.memorystatus_vm_pressure_level) in
  1) color=32 ;; 2) color=33 ;; 4) color=31 ;; *) color=37 ;;
esac
awk -v t="$total" -v f="$free_pct" -v c="$color" 'BEGIN {
  u = 100 - f
  printf "%.2f GiB / %.2f GiB (\033[%sm%d%%\033[0m)\n", t*u/100/2^30, t/2^30, c, u }'
