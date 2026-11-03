# dotfiles

Turn a fresh Linux install into *my* machine: keybinds, laptop Fn keys, lid/idle behaviour,
shell and git config, and the apps I use, split by **device** and **distro**.

The distro keeps its own desktop (panels, bar, theme, launcher). This repo only adds my
preferences on top: one include line in the distro's configs, never an overwrite. The
Quickshell/waybar desktop lives in a separate repo,
[hyde-quickshell-customizations](https://github.com/JuanDLCH/hyde-quickshell-customizations).

## Quick start

```bash
git clone https://github.com/JuanDLCH/dotfiles ~/.local/share/chezmoi
~/.local/share/chezmoi/bootstrap.sh
```

With chezmoi already installed, `chezmoi init --apply JuanDLCH` does the same (it finds the
`dotfiles` repo by name). The clone can live anywhere: `bootstrap.sh` remembers its location.

`bootstrap.sh` installs git and [chezmoi](https://chezmoi.io), then asks:

| Prompt | Choices | Detected from |
|---|---|---|
| device | `msi-modern15`, `generic`, … | `/sys/class/dmi/id/product_name` |
| desktop | `ryoku`, `hyprland-lua` (HyDE), `hyprland-conf` (CachyOS default, vanilla), `none` | `ryoku-shell` on PATH, else `~/.config/hypr/hyprland.{lua,conf}` |
| suites | `base`, `dev`, `desktop-apps`, `gaming`, `peripherals` | the device's `suites` in `devices.yaml`, else `base` |
| git name / email | | |

Answers are saved in `~/.config/chezmoi/chezmoi.toml`. To change them, run `chezmoi init --prompt`.

## What goes where

```
home/                       chezmoi source: everything that lands in $HOME
  .chezmoidata/devices.yaml   hardware facts per machine (ids, paths, layout)
  dot_config/hypr/            juandy.lua / juandy.conf: keybinds + Fn keys
  dot_config/juandy/          kitty, zsh and hypridle snippets included from distro files
  dot_local/libexec/          hw (Fn-key actions), lid-lock
  run_after_20-includes.sh    adds the include lines to the distro's configs
  run_onchange_after_30-packages.sh   installs the chosen suites
packages/
  install.sh                one manifest, any distro (arch / debian / fedora / flatpak)
  suites/*.txt              app lists: name | arch | debian | fedora | flatpak | note
  scripts/*.sh              installers that are not a plain package (claude, vscode repo…)
devices/
  msi-modern15/README.md    Fn-key table, hardware ids, post-install checklist
  _template/                start here for a new PC
AGENTS.md                   instructions for an AI agent setting up a machine
```

## Ryoku

With `desktop = ryoku` the repo leans on Ryoku's own tools instead of mine: the include goes in
`~/.config/hypr/user.lua` (Ryoku replaces `hyprland.lua` on updates), volume/brightness OSD,
Super+P and the touchpad lock are Ryoku's, Super+L is `ryoku-shell suspend`, and the idle policy is
written with `ryoku-power idle set`. The lid uses Ryoku's `user_edits` overlay
(`~/.config/ryoku/user_edits/hypr/modules/lid.lua`) and `~/.local/libexec/ryoku-lid`. On AC with no
external display, closing the lid only locks and turns the screen off. Every other case goes to
`ryoku-clamshell`. `ryoku doctor` will report that overlay as a user edit; that is expected.

## Mouse (Razer Basilisk V3 Pro)

The extra buttons are mapped in Synapse to F13-F18, stored in the mouse's onboard memory, so they
work on every machine and over every link (USB, dongle, Bluetooth). The Hyprland binds in
`juandy.{lua,conf}.tmpl` bind them by keycode, because XKB turns F13-F18 into
`XF86Tools`/`XF86Launch5-9`.

| Button | Sends | Keycode | Action |
|---|---|---|---|
| Wheel tilt left | F13 | `code:191` | previous workspace |
| Wheel tilt right | F14 | `code:192` | next workspace |
| Hypershift + left click | F15 | `code:193` | toggle maximize (as Super+F) |
| Hypershift + right click | F16 | `code:194` | close window (as Super+Q) |
| Side forward | F17 | `code:195` | app launcher (as Super+Space) |
| Side back | F18 | `code:196` | music player (as Super+J; Ryotunes on Ryoku) |
| Hypershift + wheel tilt left / right / middle click | XF86AudioPrev / Next / Play | - | previous track / next track / play-pause (native, no binds) |
| Hypershift + scroll up / down | XF86AudioRaiseVolume / LowerVolume | - | volume up / down (native, no binds) |

On non-Ryoku desktops F17/F18 replay Super+Space / Super+J through `wtype` (only if installed), so
they follow whatever the desktop binds there.

**Bluetooth drops** (reconnecting every few seconds, `Connection Timeout (0x08)` in `btmon`, with a
MediaTek MT7921 controller): the cause was outdated mouse firmware. Update it with Razer's
Basilisk V3 Pro Firmware Updater (Windows, over the USB cable), then re-pair. Turning off WiFi
power save, ASPM or mt76 runtime PM didn't fix it.

## Everyday use

```bash
chezmoi diff              # what would change in $HOME
chezmoi apply             # apply the repo
chezmoi re-add            # copy live edits of managed files back into the repo
chezmoi edit ~/.config/hypr/juandy.lua   # edit the template, not the rendered file
chezmoi cd                # shell in the repo, then git commit/push
```

Install suites without chezmoi (on any distro, or to preview):

```bash
packages/install.sh --list
packages/install.sh --suite dev,gaming --dry-run
packages/install.sh --suite dev,gaming
```

## Adding things

- **An app:** add a line to a suite in `packages/suites/`. Leave a distro column empty to fall back to flatpak; use `@script:name` for installers in `packages/scripts/`.
- **A suite:** a new `packages/suites/<name>.txt` (first line `#: description`), then add the name to the list in `home/.chezmoi.toml.tmpl`.
- **A machine:** follow `devices/_template/README.md`.
- **A keybind for every machine:** edit both `home/dot_config/hypr/juandy.lua.tmpl` and `juandy.conf.tmpl`.

## Not included

Secrets (git credentials come from `gh auth`), wallpapers and themes, and the desktop shell itself.
