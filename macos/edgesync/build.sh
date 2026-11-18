#!/bin/sh
# Compila EdgeSync y lo instala en ~/Applications (luego: Accesibilidad → + → EdgeSync.app).
set -e
cd "$(dirname "$0")"
A=~/Applications/EdgeSync.app/Contents
swiftc -O -o /tmp/EdgeSync main.swift
rm -rf ~/Applications/EdgeSync.app && mkdir -p "$A/MacOS"
mv /tmp/EdgeSync "$A/MacOS/"
cat > "$A/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.edgesync</string>
  <key>CFBundleName</key><string>EdgeSync</string>
  <key>CFBundleExecutable</key><string>EdgeSync</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PL
# Firma: con el certificado local "EdgeSync Local" (llavero de inicio de sesión) el permiso de
# Accesibilidad sobrevive a las recompilaciones; sin él, firma ad hoc y hay que volver a darlo.
if security find-certificate -c "EdgeSync Local" >/dev/null 2>&1; then
  codesign --force --sign "EdgeSync Local" ~/Applications/EdgeSync.app
else
  codesign --force --sign - ~/Applications/EdgeSync.app
fi
