# MSI Modern 15 A5M

Ryzen 5 5500U laptop, Spanish (`es`) keyboard. Device key in `home/.chezmoidata/devices.yaml`: `msi-modern15`
(auto-detected from `/sys/class/dmi/id/product_name` = `Modern 15 A5M`).

## Fn keys

What each key sends, and what my config does with it. The binds are in
`home/dot_config/hypr/juandy.{lua,conf}.tmpl`, and the actions live in `~/.local/libexec/hw-keys/hw`.

| Key | Arrives as | Action |
|---|---|---|
| Fn + audio / brightness keys | `XF86Audio*`, `XF86MonBrightness*` | SwayOSD volume/brightness (only if swayosd is installed) |
| Fn+F4 | `Ctrl+Super+XF86TouchpadToggle` | `hw touchpad toggle`: disables the touchpad via Hyprland + OSD |
| Fn+F6 | nothing: the EC cuts the camera's USB power | `hw camera watch --osd` (autostart) shows an OSD when the camera appears/disappears |
| Fn+F7 (MSI Center key) | `XF86Launch1` | `hw profile`: cycles power-saver → balanced → performance (power-profiles-daemon) |
| Fn+F11 | `Super+P` | `hw display`: Laptop only / Duplicate / Extend / External only |
| Fn+F12 | `XF86RotateWindows` | `hw rotate`: rotates the built-in panel 180° |
| Fn+Print | `Super+Shift+S` | free for a screenshot picker (the desktop's own) |
| F10, F12 | plain keys | unbound from the desktop so apps get them |

The lid is handled by `~/.local/libexec/lid-lock`: closing it locks the session. On AC the screen turns off and work keeps running; on battery the laptop suspends.

## Hardware IDs (in `devices.yaml`)

| What | Value | How to find it again |
|---|---|---|
| Touchpad | `pnp0c50:0d-06cb:7e7e-touchpad` | `hyprctl devices` |
| Camera | USB `5986:211c` (Bison HD Webcam) | `lsusb` |
| AC adapter | `/sys/class/power_supply/ADP1/online` | `ls /sys/class/power_supply` |
| Lid | `/proc/acpi/button/lid/LID0/state` | `ls /proc/acpi/button/lid` |
| Built-in panel | `eDP-*`, scale 1.5 | `hyprctl monitors` |

## Checklist after a reinstall

1. `chezmoi apply`, then reload Hyprland (`hyprctl reload`, or log out and back in for the autostarts).
2. Press Fn+F4 twice (touchpad off/on + OSD), Fn+F7 (profile OSD), Fn+F12 twice (rotate and back), Fn+F6 (camera OSD).
3. With an external screen: Fn+F11, then try each mode.
4. Close the lid on AC: the session should be locked and the screen off, with music/agents still running. On battery the laptop should suspend.
5. `power-profiles-daemon` must be installed and running for Fn+F7: `systemctl status power-profiles-daemon`.

## System-level files

`system/` is for root-owned files (udev/hwdb, logind drop-ins) if this laptop ever needs them. It is empty today: everything works from user space.
