# <Device name>

Copy this folder to `devices/<device-key>/` and fill it in.

## 1. Add the device data

In `home/.chezmoidata/devices.yaml`:

```yaml
  <device-key>:
    description: <Brand Model, CPU>
    dmi: <cat /sys/class/dmi/id/product_name>   # enables auto-detection on init
    laptop: true|false        # true installs lid-lock (needs ac + lid)
    kb_layout: us
    fn_keys: false            # true only after the ids below are filled and binds are added
    # touchpad: <hyprctl devices>
    # camera_usb: "<vendor> <product>"   # lsusb
    # ac: /sys/class/power_supply/<AC|ADP1|ACAD>/online
    # lid: /proc/acpi/button/lid/<LID|LID0>/state
    # internal_scale: "1"
```

## 2. Find what the special keys send

```bash
wev                       # Wayland: press each Fn key, note the keysym (XF86...)
sudo evtest               # if wev shows nothing, check whether the kernel sees it
```

| Key | Arrives as | Action |
|---|---|---|
| | | |

## 3. Add binds that differ from the MSI

Shared Fn actions (touchpad, rotate, profile, display, camera) are in `hw` and only need
`fn_keys: true` and the ids. Keys unique to this device: add a block guarded by
`{{ if eq .device "<device-key>" }}` in `home/dot_config/hypr/my-linux.{lua,conf}.tmpl`.

## 4. Apply

```bash
chezmoi init --prompt     # pick the new device
chezmoi diff && chezmoi apply
```
