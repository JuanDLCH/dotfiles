# AGENTS.md: setting up a machine from this repo

You are configuring a freshly installed Linux for the owner of this repo. The goal is
their keybinds, laptop Fn keys, lid/idle policy, shell/git config and app suites on top
of whatever desktop the distro ships. **Do not replace the distro's desktop** (bars,
panels, themes, launchers): only add the include lines this repo manages.

## 0. Ground rules

- Never overwrite a distro-owned config (`hyprland.lua`, `hyprland.conf`, `hypridle.conf`,
  `kitty.conf`, `.zshrc`). This repo adds one include line to each (`run_after_20-includes.sh`).
- Preview before acting: `chezmoi diff`, `packages/install.sh --dry-run`.
- Ask the user before `sudo` actions they have not requested, and before choosing suites.
- No secrets in the repo. Git auth is `gh auth login && gh auth setup-git`.
- Edit templates in the repo (`home/...tmpl`), not the rendered files in `$HOME`. If the user
  edited a managed file live, use `chezmoi re-add` (non-template files) or port the change
  into the template by hand.

## 1. Detect the machine

```bash
. /etc/os-release; echo "$ID / $ID_LIKE"            # distro family: arch | debian | fedora
cat /sys/class/dmi/id/product_name                  # device -> match `dmi` in home/.chezmoidata/devices.yaml
ls ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.conf 2>/dev/null
command -v hyde-shell && echo HyDE                  # HyDE uses hyprland.lua
```

- `hyprland.lua` present → desktop `hyprland-lua`.
- Only `hyprland.conf` (CachyOS, Ryoku, vanilla Hyprland) → `hyprland-conf`. If the distro keeps
  user overrides in another file that the main config sources (e.g. `userprefs.conf`), set
  `hypr_main = "/full/path"` under `[data]` in `~/.config/chezmoi/chezmoi.toml` and re-apply.
- No Hyprland (GNOME, KDE…) → `none`: only dotfiles and packages apply; tell the user
  which Fn features are not covered (touchpad/rotate/projection binds are Hyprland-only).
- Unknown device → use `generic`, then offer to create a device entry (section 5).

## 2. Apply

```bash
git clone https://github.com/JuanDLCH/dotfiles ~/.local/share/chezmoi
~/.local/share/chezmoi/bootstrap.sh          # installs chezmoi, prompts, applies
```

Non-interactive (you already know the answers):

```bash
chezmoi init --apply --source ~/.local/share/chezmoi \
  --promptChoice Device=msi-modern15 --promptChoice Desktop=hyprland-conf \
  --promptString Suites=base/dev \
  --promptString 'Git name=Juan Diego' --promptString Git\ email=you@example.com
```

Prompt keys: `Device`, `Desktop` (`hyprland-lua|hyprland-conf|none`), `Suites` (names from `packages/suites/`, separated by spaces or `/`), `Git name`, `Git email`.
Defaults come from detection (device from DMI, desktop from the hypr config present).

### Migrating a machine that already has these settings inline

If the main Hyprland config already contains the old binds/autostarts (lines with
`libexec/lid-lock` or `libexec/hw-keys/hw`), the include script refuses to add itself to avoid
running lid-lock twice. Remove those old lines (Fn binds, `hw camera watch`, `lid-lock`, the
Super+L/F11/Super+F/OSD binds, `kb_layout`) from the main config, keep a backup, then run
`chezmoi apply` again.

## 3. Packages

```bash
~/.local/share/chezmoi/packages/install.sh --list
~/.local/share/chezmoi/packages/install.sh --suite base,dev --dry-run
~/.local/share/chezmoi/packages/install.sh --suite base,dev
```

Suites chosen at init are installed by `chezmoi apply` automatically (and again when a suite
file changes). Apps without a package for the distro fall back to flatpak or are reported as
skipped. Arch: uses `paru`/`yay` if present (AUR names in the manifests), else `pacman`. Gaming
on Arch needs `[multilib]` enabled.

## 4. Hypridle (manual merge)

`~/.config/juandy/hypridle.conf` holds the idle policy (dim 60 s, lock 120 s, screen off 300 s,
suspend 500 s on battery only). hypridle cannot include files, so merge its `listener` blocks
into the distro's `~/.config/hypr/hypridle.conf` (back it up first), replacing listeners with
the same purpose. Keep the distro's `lock_cmd` if it has one.

## 5. Verify

```bash
chezmoi verify && echo "dotfiles in sync"
hyprctl reload                         # then log out/in once so autostarts (lid-lock, camera watch) start
hyprctl binds -j | jq -r '.[] | select(.description // "" | test("Touchpad|Power|Display|Session|Window"))'
```

Then follow the checklist in `devices/<device>/README.md` with the user (Fn keys, lid).

## 6. Extending

- New device: `devices/_template/README.md`.
- New app/suite/distro column: `README.md` → "Adding things". Keep the manifest columns in order:
  `name | arch | debian | fedora | flatpak | note`.
- Test template changes without touching `$HOME`:
  ```bash
  chezmoi --source . --destination /tmp/cz-test apply --exclude scripts
  ```
- Lint: `shellcheck packages/install.sh packages/scripts/*.sh bootstrap.sh`.
