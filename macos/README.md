# macOS (work laptop)

MacBook Pro 14" (Apple Silicon), company-managed (MDM), Latin American keyboard, two
external 1080p monitors above the laptop. The goal is the Hyprland workflow from the rest of this
repo without weakening the machine: **SIP stays on, nothing touches MDM, no drivers, no root
daemons, and every install is checked first** (official Homebrew when possible).

This folder is **not** managed by chezmoi (`.chezmoiroot` is `home/`, which is Linux-only). It holds
copies of the live files, restored by hand (see [Restore](#restore)).

| File here | Lives at |
|---|---|
| `rift/config.toml`, `rift/fit-min-size.sh` | `~/.config/rift/` |
| `skhd/skhdrc` | `~/.skhdrc` |
| `skhd/screenshot.sh`, `skhd/screenshot-area.sh` | `~/.config/skhd/` |
| `kitty/kitty.conf`, `kitty/current-theme.conf` | `~/.config/kitty/` |
| `starship.toml` | `~/.config/starship.toml` |
| `zshrc` | `~/.zshrc` |
| `borders/bordersrc` | `~/.config/borders/bordersrc` |
| `fastfetch/config.jsonc`, `fastfetch/memory.sh` | `~/.config/fastfetch/` (put any PNG at `~/.config/fastfetch/logo.png`; the image is not in the repo) |

## What's installed

| Tool | Source | Permissions | Purpose |
|---|---|---|---|
| Kitty | cask `kitty` | none | terminal |
| starship, zsh-autosuggestions, zsh-syntax-highlighting, fzf, zoxide, eza, bat | Homebrew core | none | shell |
| JetBrains Mono Nerd Font | cask `font-jetbrains-mono-nerd-font` | none | font with icons |
| [Rift](https://github.com/acsandmann/rift) | `acsandmann/tap/rift` | Accessibility | tiling WM |
| skhd | `asmvik/formulae/skhd` | Accessibility, Screen Recording | app shortcuts, screenshots, mouse buttons |
| gh | Homebrew core | none | GitHub CLI |
| fastfetch | Homebrew core | none | system info + image when Kitty opens |
| btop | Homebrew core | none | resource monitor (CPU, memory, disks, network, processes) |
| The Unarchiver, unar | cask `the-unarchiver`, Homebrew core | none | RAR and other archives (GUI and `unar` / `lsar` CLI) |
| [JankyBorders](https://github.com/FelixKratz/JankyBorders) | `FelixKratz/formulae/borders` (built from source) | none | purple border on the focused window |
| NordPass | cask `nordpass` | none | passwords |

Music in the menu bar is native: System Settings → Menu Bar → Now Playing → Always Show in Menu Bar.

## Window manager: Rift

BSP (dwindle-like) tiling, 10 px gaps, animations, focus follows mouse and the mouse follows
keyboard focus (centred on the window, then hidden until it moves), 4 workspaces **per
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
| Opt+Shift+0 | balance sizes, then re-fit to minimum widths |
| Opt+Shift+. / Opt+Shift+, | grow / shrink (`=`/`-` are elsewhere on the Latin American layout) |
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
| Opt+L | sleep (`pmset sleepnow`; Ctrl+Cmd+Q only locks) |
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
- Keyboard → Text Input: Latin American + U.S. (for the external SK75), switched with Ctrl+Space
  (Keyboard Shortcuts → Input Sources, off by default here); the input menu shows the active one.

## Gotchas (all hit in practice)

- **Permissions follow the launching process.** A program started directly by skhd asks for
  privacy permissions *as skhd* (Kitty asked for Downloads as "skhd"). Launch apps with `open`.
- **Floating windows hide behind tiled ones** with focus-follows-mouse, because without SIP a window
  manager can't focus without raising. Open floating apps on an empty workspace.
- **JankyBorders with `order=above` is itself a window on top**, so picking a window (Space) in a
  screenshot captured the empty border. `screenshot-area.sh` sends it below while picking.
- **Rift raises windows over the screenshot picker** highlight; that is why Opt+Shift+S goes
  through `screenshot-area.sh` instead of the native shortcut.
- **Rift's BSP isn't quite dwindle**: a split keeps its orientation when a window closes, so
  closing the left window left two windows stacked full-width (rows). `fit-min-size.sh` also
  re-orients every split by its shape (wider than tall → side by side, else stacked) on each
  `windows_changed`, which is what Hyprland's dwindle does. Master-stack was tried and isn't
  dwindle (a 4th window stacks instead of splitting beside).
- **Minimum window sizes** (WhatsApp ~970 px wide, Claude ~600, Spotify ~600 px tall, more with
  its library expanded): a window that won't shrink spills off the display or over its neighbour.
  `fit-min-size.sh` runs on Rift's `windows_changed` event (`run_on_start`) and on Opt+Shift+0: it
  finds the window that overflows and grows it with `resize-grow` on that axis (focus-follows-mouse
  and mouse-follows-focus are paused meanwhile, so focus can be moved), which shrinks the neighbour.
  If a problem doesn't improve after a step, the two minimums can't fit together and it stops.
- **1080p externals look soft** on macOS (no font hinting, ~81–92 ppi). Nothing to tune in
  software; `AppleFontSmoothing 0` made no visible difference. The fix is a 4K 27" panel.
- Kitty: `macos_option_as_alt no`, otherwise Opt+Q can't type `@` in the terminal.
- **fastfetch on a new Kitty window** must wait until Rift finishes resizing it, or the image
  is drawn at the old size (squashed, text scrolled). `zshrc` waits until `stty size` is stable.
  `~/.hushlogin` hides the "Last login" line.

- Dimming or making inactive windows translucent (Hyprland `inactive_opacity`) needs SIP off.
  The focused window gets a border from JankyBorders instead.

### Tried and dropped

- **yabai + skhd** (from an earlier ChatGPT session): works without SIP but needed patches for
  minimum sizes, cross-display drags (Retina ↔ 1x resizing) and floating windows. Removed.
- **skhd.zig**: the cask is unnotarized and strips Gatekeeper quarantine. Not on a managed Mac.
- **AeroSpace**: most mature option, but no automatic dwindle splitting. Fallback if Rift gets buggy.
- **Native tiling only**: no focus-follows-mouse, and a Fill/restore toggle script was unreliable.

## Restore

```bash
brew install kitty starship zsh-autosuggestions zsh-syntax-highlighting fzf zoxide eza bat gh fastfetch btop unar
brew install --cask font-jetbrains-mono-nerd-font nordpass the-unarchiver
brew install acsandmann/tap/rift asmvik/formulae/skhd FelixKratz/formulae/borders

d=~/dotfiles/macos   # this folder
mkdir -p ~/.config/rift ~/.config/skhd ~/.config/kitty ~/.config/fastfetch ~/.config/borders
cp $d/rift/* ~/.config/rift/ && chmod +x ~/.config/rift/fit-min-size.sh
cp $d/skhd/skhdrc ~/.skhdrc && cp $d/skhd/*.sh ~/.config/skhd/ && chmod +x ~/.config/skhd/*.sh
cp $d/kitty/*.conf ~/.config/kitty/
cp $d/starship.toml ~/.config/ && cp $d/zshrc ~/.zshrc && touch ~/.hushlogin
cp $d/fastfetch/* ~/.config/fastfetch/   # plus your own logo.png

rift service install && rift service start   # then allow rift in Accessibility, `rift service restart`
skhd --start-service                         # allow skhd in Accessibility and Screen Recording
cp $d/borders/bordersrc ~/.config/borders/ && chmod +x ~/.config/borders/bordersrc
brew services start felixkratz/formulae/borders
```

After editing a live file, copy it back here so this folder stays current.
