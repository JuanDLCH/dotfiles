#!/bin/sh
# Memory line for fastfetch, like Activity Monitor's "Memory Used" (app + wired + compressed;
# file cache doesn't count). The color follows macOS memory pressure, not the percentage.
ps=$(pagesize)
total=$(sysctl -n hw.memsize)
used=$(vm_stat | awk -v ps="$ps" '
  /Anonymous pages/            {gsub("\\.","",$NF); a=$NF}
  /Pages purgeable/            {gsub("\\.","",$NF); p=$NF}
  /wired down/                 {gsub("\\.","",$NF); w=$NF}
  /occupied by compressor/     {gsub("\\.","",$NF); c=$NF}
  END {print (a - p + w + c) * ps}')
case $(sysctl -n kern.memorystatus_vm_pressure_level) in
  1) color=32 ;;   # normal   → green
  2) color=33 ;;   # warning  → yellow
  4) color=31 ;;   # critical → red
  *) color=37 ;;
esac
awk -v u="$used" -v t="$total" -v c="$color" 'BEGIN {
  printf "%.2f GiB / %.2f GiB (\033[%sm%d%%\033[0m)\n", u/2^30, t/2^30, c, u/t*100 }'
