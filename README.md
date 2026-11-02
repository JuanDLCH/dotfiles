# my-linux-configs

Turn a fresh Linux install into *my* machine: keybinds, laptop Fn keys, lid/idle behaviour,
shell and git config, and the apps I use, split by **device** and **distro**.

The distro keeps its own desktop (panels, bar, theme, launcher). This repo only adds my
preferences on top: one include line in the distro's configs, never an overwrite. The
Quickshell/waybar desktop lives in a separate repo,
[hyde-quickshell-customizations](https://github.com/JuanDLCH/hyde-quickshell-customizations).

## Quick start

```bash
git clone https://github.com/JuanDLCH/my-linux-configs ~/.local/share/chezmoi
~/.local/share/chezmoi/bootstrap.sh
```

`bootstrap.sh` installs git and [chezmoi](https://chezmoi.io), then asks:

| Prompt | Choices | Detected from |
|---|---|---|
| device | `msi-modern15`, `generic`, … | `/sys/class/dmi/id/product_name` |
| desktop | `hyprland-lua` (HyDE), `hyprland-conf` (CachyOS, Ryoku, vanilla), `none` | `~/.config/hypr/hyprland.{lua,conf}` |
| suites | `base`, `dev`, `desktop-apps`, `gaming`, `peripherals` | default `base` |
| git name / email | | |

Answers are saved in `~/.config/chezmoi/chezmoi.toml`. To change them, run `chezmoi init --prompt`.

## What goes where

```
home/                       chezmoi source: everything that lands in $HOME
  .chezmoidata/devices.yaml   hardware facts per machine (ids, paths, layout)
  dot_config/hypr/            my-linux.lua / my-linux.conf: keybinds + Fn keys
  dot_config/my-linux/        kitty, zsh and hypridle snippets included from distro files
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

## Everyday use

```bash
chezmoi diff              # what would change in $HOME
chezmoi apply             # apply the repo
chezmoi re-add            # copy live edits of managed files back into the repo
chezmoi edit ~/.config/hypr/my-linux.lua   # edit the template, not the rendered file
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
- **A keybind for every machine:** edit both `home/dot_config/hypr/my-linux.lua.tmpl` and `my-linux.conf.tmpl`.

## Not included

Secrets (git credentials come from `gh auth`), wallpapers and themes, and the desktop shell itself.
