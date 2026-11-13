# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal Linux setup repo (chezmoi + bash). `README.md` covers usage; `AGENTS.md` is the runbook for
**setting up a machine** from this repo: follow it when asked to configure a fresh install. This
file is about **changing the repo** itself.

## Architecture

Three axes, each resolved in a different place:

- **Device** (`msi-modern15`, `generic`, …): hardware facts in `home/.chezmoidata/devices.yaml`.
  Templates do `{{ $dev := index .devices .device }}` and read `$dev.laptop`, `$dev.fn_keys`,
  `$dev.touchpad`, etc. `home/.chezmoiignore` drops `hw` / `lid-lock` on devices without them.
  `$dev.suites` is the default answer of the Suites prompt (read with `get`, since `generic` has none).
- **Desktop** (`ryoku` | `hyprland-lua` | `hyprland-conf` | `none`): which keybind file gets installed
  (`home/dot_config/hypr/juandy.lua.tmpl` vs `juandy.conf.tmpl`). `ryoku` reuses the Lua file with
  `{{ if $ryoku }}` branches that defer to Ryoku's own commands (`ryoku-shell`, `ryoku wm act`,
  `ryoku-power`), includes from `user.lua`, and swaps `lid-lock` for the `user_edits` lid overlay +
  `ryoku-lid`. Ryoku sources were read from github.com/Ryoku-dev/ryoku (`ryoku/hyprland/`,
  `system/hardware/power/ryoku-{clamshell,idle,power}`); re-check them if Ryoku changes. It also switches how scripts
  talk to Hyprland: Lua-config Hyprland takes `hyprctl eval "hl.…"` and
  `hyprctl dispatch 'hl.dsp.…'`, while classic config takes `hyprctl keyword …` and `dispatch dpms on|off`.
  See `hypr()`, `mon_set()` and `tp_apply()` in `executable_hw.tmpl`, plus `screen()` in `lid-lock`.
- **Distro** (arch / debian / fedora): only `packages/install.sh` cares. It detects the family from
  `/etc/os-release` and picks the matching column of `packages/suites/*.txt`
  (`name | arch | debian | fedora | flatpak | note`). An empty cell falls back to flatpak, else
  skip. `@script:x` runs `packages/scripts/x.sh` with `FAMILY` and `YES` in the environment.

Wiring:
- `.chezmoiroot` = `home`, so the chezmoi source is `home/`, and the repo root holds docs, `packages/` and `devices/`.
- `home/.chezmoi.toml.tmpl` prompts once (device / desktop / suites / git name+email) and writes
  `sourceDir` so a clone outside `~/.local/share/chezmoi` keeps working.
- **Never overwrite distro-owned files.** `home/run_after_20-includes.sh.tmpl` appends one include
  line (`require("juandy")`, `source = …/juandy.conf`, kitty `include`, `.zshrc` source) on every
  apply. It refuses to add the Hyprland include if the main config still has old inline
  `libexec/lid-lock` / `hw-keys/hw` lines (that would double-start them).
- `home/run_onchange_after_30-packages.sh.tmpl` embeds a sha256 of each chosen suite file so it
  re-runs when a manifest changes.
- Desktop-shell things (Quickshell, waybar, media helpers like `hw cover`) are deliberately out of
  scope and belong to the separate `hyde-quickshell-customizations` repo. `hw` only forwards
  `cover|seek|focus-player` to a local `hw-media` or `hyde-qs-media`. That repo's waybar layout calls
  `~/.local/libexec/hw-keys/hw` for the camera/touchpad/profile indicators, so keep `hw`'s
  `camera watch`, `touchpad status` and `profile status` JSON output stable. The only HyDE-shell data
  kept here is personal: `~/.config/hyde-qs/location.json` and `~/.config/hyde/weather-location`
  (installed only for `hyprland-lua`).

## Owner preferences (don't undo)

- Suites stay minimal: what the owner actually uses. `desktop-apps` = kitty, Firefox, Chrome,
  ChatGPT, VLC. No PWAs/firefoxpwa, Spotify, OpenCode or Hermes; ask before adding apps.
- Peripherals: Razer Basilisk V3 Pro + Mouse Dock Pro (OpenRazer/Polychromatic) and a SteelSeries
  Arctis Nova headset (HeadsetControl, linux-arctis-manager). They only work over the USB
  dock/dongle, so the laptop (Bluetooth) doesn't get the `peripherals` suite; a desktop PC does.
- Keybinds: Super+F maximize, F11 fullscreen, Super+L lock + screen off, never suspends (AC or battery). On AC the lid and idle only
  lock and turn the screen off, so background work keeps running. They suspend only on battery.

## Commands

Render and test templates **without touching `$HOME`** (separate config, state and destination;
the `--prompt*` keys are the prompt texts):

```bash
T=/tmp/cz-test; mkdir -p $T/dest
chezmoi init --source "$PWD" --config $T/c.toml --no-tty \
  --promptChoice Device=msi-modern15 --promptChoice Desktop=hyprland-conf \
  --promptString Suites=base/dev --promptString 'Git name=X' --promptString 'Git email=x@y'
chezmoi --source "$PWD" --config $T/c.toml --destination $T/dest apply --exclude scripts
chezmoi --source "$PWD" --config $T/c.toml execute-template < home/run_after_20-includes.sh.tmpl
```

Against the live machine: `chezmoi diff`, `chezmoi apply`, `chezmoi verify --exclude scripts`
(plain `verify` always reports the `run_after_` script as pending).

```bash
packages/install.sh --list
packages/install.sh --suite base,dev --dry-run --family debian   # any family, from any distro
HW_DRY_RUN=1 ~/.local/libexec/hw-keys/hw rotate                  # print the hyprctl calls instead of running them
shellcheck packages/install.sh packages/scripts/*.sh bootstrap.sh
luac -p <rendered juandy.lua>                                    # syntax check of the Lua output
```

Shellcheck the *rendered* `hw` / `lid-lock` / includes script, not the `.tmpl` files.

## Gotchas (all hit in practice)

- `.chezmoidata/` is **not** loaded while `.chezmoi.toml.tmpl` renders. Read it there with
  `include ".chezmoidata/devices.yaml" | fromYaml`.
- `promptMultichoiceOnce` does not recognise the stored list and re-prompts or falls back to the default, so
  `suites` is stored as a comma string via `promptStringOnce`. Templates split it with
  `splitList "," .suites | compact`.
- Prompt texts double as CLI keys: keep them short and comma-free. Values can't contain commas
  either, which is why suites accept `/` or spaces.
- Sprig `regexReplaceAll REGEX INPUT REPL`: the input is the middle arg, so don't pipe into it.
- Anything appended to `hyprland.lua` must be valid Lua (the marker is `-- dotfiles`, not `#`).
- A keybind change for every machine goes in **both** `juandy.lua.tmpl` and `juandy.conf.tmpl`.
- New device: `devices/_template/README.md`. New suite: `packages/suites/<name>.txt` with a `#: description`
  first line, then add it to the "Available:" comment above the Suites prompt in `.chezmoi.toml.tmpl`.
