#!/bin/sh
# Memoria para fastfetch: total + presión real de macOS (no cuenta la caché como "usada").
total=$(( $(sysctl -n hw.memsize) / 1073741824 ))
used=$(memory_pressure 2>/dev/null | awk '/free percentage/{gsub("%","",$NF); print 100-$NF}')
case $(sysctl -n kern.memorystatus_vm_pressure_level) in
  1) level="normal" ;; 2) level="alta" ;; 4) level="crítica" ;; *) level="?" ;;
esac
echo "${total} GiB · presión ${used}% (${level})"
