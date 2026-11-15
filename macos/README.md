# macOS (work laptop)

MacBook Pro 14" (Apple Silicon), company-managed (Kandji MDM), Latin American keyboard, two
external 1080p monitors above the laptop. The goal is the Hyprland workflow from the rest of this
repo without weakening the machine: **SIP stays on, nothing touches MDM, no drivers, no root
daemons, and every install is checked first** (official Homebrew when possible).

This folder is **not** managed by chezmoi (`.chezmoiroot` is `home/`, which is Linux-only). It holds
copies of the live files, restored by hand (see [Restore](#restore)).

| File here | Lives at |
|---|---|
| `rift/config.toml` | `~/.config/rift/config.toml` |
| `skhd/skhdrc` | `~/.skhdrc` |
| `skhd/screenshot.sh`, `skhd/screenshot-area.sh` | `~/.config/skhd/` |
| `kitty/kitty.conf`, `kitty/current-theme.conf` | `~/.config/kitty/` |
| `starship.toml` | `~/.config/starship.toml` |
| `zshrc` | `~/.zshrc` |

## What's installed

| Tool | Source | Permissions | Purpose |
|---|---|---|---|
| Kitty | cask `kitty` | none | terminal |
| starship, zsh-autosuggestions, zsh-syntax-highlighting, fzf, zoxide, eza, bat | Homebrew core | none | shell |
| JetBrains Mono Nerd Font | cask `font-jetbrains-mono-nerd-font` | none | font with icons |
| [Rift](https://github.com/acsandmann/rift) | `acsandmann/tap/rift` | Accessibility | tiling WM |
| skhd | `asmvik/formulae/skhd` | Accessibility, Screen Recording | app shortcuts, screenshots, mouse buttons |
| gh | Homebrew core | none | GitHub CLI |
| NordPass | cask `nordpass` | none | passwords |

Music in the menu bar is native: System Settings → Menu Bar → Now Playing → Always Show in Menu Bar.

## Window manager: Rift

BSP (dwindle-like) tiling, 10 px gaps, animations, focus follows mouse, 4 workspaces **per
display**, layout preview in the menu bar, 3-finger swipe between workspaces. Settings, Calculator,
Activity Monitor, Archive Utility and Finder dialogs float.

| Keys | Action |
|---|---|
| Ctrl+Opt + arrows | move focus |
| Ctrl+Opt+Shift + arrows | move the window within the display |
| Ctrl+Opt+Cmd + arrows | send the window to another display |
| Opt+1–4 / Opt+Shift+1–4 | go to workspace / send window to workspace (per display) |
| Opt+Tab | last workspace |
| Opt+F / Opt+Shift+F | maximize within gaps / without gaps |
| Opt+Shift+Space | float ↔ tile |
| Opt+Shift+J | toggle split orientation |
| Opt+Shift+= / Opt+Shift+- | grow / shrink |
| Opt + drag | move a window (drop in the centre to swap) |
| Opt+Z | pause Rift on the current space |

The config is hot-reloaded. `rift service restart` restarts it; `brew upgrade rift && rift service restart` updates it.

**Use only one native desktop per display**: Rift's workspaces replace them, and a window on a
second native desktop is invisible to Rift.

## Shortcuts: skhd

Opt = Option (⌥). On the Latin American layout **Opt+Q types `@`**, so it is never bound.

| Keys | Action |
|---|---|
| Opt+T | new Kitty window (`open -na … --single-instance`, see gotchas) |
| Opt+B / E / V / C / J | Safari / Finder (new window) / VS Code / Claude / Spotify |
| Opt+, | System Settings |
| Opt+S | screenshot of the display under the mouse → clipboard |
| Opt+Shift+S | area screenshot (Space = pick a window) → clipboard; pauses Rift's focus-follows-mouse while picking |

## Mouse (Razer Basilisk V3 Pro)

Same onboard mapping as on Linux ([README → Mouse](../README.md#mouse-razer-basilisk-v3-pro)),
bound in skhd. Synapse is not needed on the Mac.

| Button | Sends | Action |
|---|---|---|
| Wheel tilt left / right | F13 / F14 | previous / next Rift workspace |
| Hypershift + left click | F15 | maximize (Rift) |
| Hypershift + right click | F16 | close window |
| Side forward | F17 | area screenshot (as Opt+Shift+S) |
| Side back | F18 | Spotify |
| Hypershift + tilt / middle / scroll | media keys | prev / next / play-pause / volume (native) |

macOS uses F14/F15 for display brightness. If a tilt changes the brightness, untick both in
System Settings → Keyboard → Keyboard Shortcuts → Display. Free F-keys on macOS: F13, F16–F20.

## System Settings changes

- Keyboard Shortcuts → Screenshots: "Copy picture of selected area to the clipboard" = Opt+Shift+S,
  "Copy picture of the screen to the clipboard" = Opt+S (both shadowed by skhd, kept as fallback).
- Privacy & Security: Accessibility → rift, skhd; Screen & System Audio Recording → skhd.
- Desktop & Dock: Displays have separate Spaces = on (Rift needs it).

## Gotchas (all hit in practice)

- **Permissions follow the launching process.** A program started directly by skhd asks for
  privacy permissions *as skhd* (Kitty asked for Downloads as "skhd"). Launch apps with `open`.
- **Floating windows hide behind tiled ones** with focus-follows-mouse, because without SIP a window
  manager can't focus without raising. Open floating apps on an empty workspace.
- **Rift raises windows over the screenshot picker** highlight; that is why Opt+Shift+S goes
  through `screenshot-area.sh` instead of the native shortcut.
- **Minimum window sizes** (Claude ~600 px wide, Spotify ~600 px tall) make windows overlap in
  small tiles on the 1512 px laptop screen. Keep two windows per display there.
- **1080p externals look soft** on macOS (no font hinting, ~81–92 ppi). Nothing to tune in
  software; `AppleFontSmoothing 0` made no visible difference. The fix is a 4K 27" panel.
- Kitty: `macos_option_as_alt no`, otherwise Opt+Q can't type `@` in the terminal.

### Tried and dropped

- **yabai + skhd** (from an earlier ChatGPT session): works without SIP but needed patches for
  minimum sizes, cross-display drags (Retina ↔ 1x resizing) and floating windows. Removed.
- **skhd.zig**: the cask is unnotarized and strips Gatekeeper quarantine. Not on a managed Mac.
- **AeroSpace**: most mature option, but no automatic dwindle splitting. Fallback if Rift gets buggy.
- **Native tiling only**: no focus-follows-mouse, and a Fill/restore toggle script was unreliable.

## Restore

```bash
brew install kitty starship zsh-autosuggestions zsh-syntax-highlighting fzf zoxide eza bat gh
brew install --cask font-jetbrains-mono-nerd-font nordpass
brew install acsandmann/tap/rift asmvik/formulae/skhd

d=~/dotfiles/macos   # this folder
mkdir -p ~/.config/rift ~/.config/skhd ~/.config/kitty
cp $d/rift/config.toml ~/.config/rift/
cp $d/skhd/skhdrc ~/.skhdrc && cp $d/skhd/*.sh ~/.config/skhd/ && chmod +x ~/.config/skhd/*.sh
cp $d/kitty/*.conf ~/.config/kitty/
cp $d/starship.toml ~/.config/ && cp $d/zshrc ~/.zshrc

rift service install && rift service start   # then allow rift in Accessibility, `rift service restart`
skhd --start-service                         # allow skhd in Accessibility and Screen Recording
```

After editing a live file, copy it back here so this folder stays current.
