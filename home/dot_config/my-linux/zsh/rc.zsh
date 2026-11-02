# my-linux-configs: personal zsh settings, sourced from ~/.zshrc
# (the source line is added by chezmoi; the distro's .zshrc is left as is).

# ~/.local/bin first (claude, chezmoi, user scripts).
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
