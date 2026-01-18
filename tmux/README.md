# tmux Configuration

Catppuccin Mocha themed tmux setup with Vim-style navigation and sensible defaults.

## Features

- **Custom prefix:** `Ctrl+a` (easier to reach than `Ctrl+b`)
- **Vim-style pane navigation:** `h/j/k/l` for left/down/up/right
- **Intuitive splits:** `|` for horizontal, `-` for vertical
- **Mouse support** for scrolling and pane selection
- **Catppuccin Mocha theme** with rounded window tabs
- **Session persistence** with tmux-resurrect

## Plugins (managed by TPM)

- **tmux-sensible:** Sensible tmux defaults
- **tmux-resurrect:** Save and restore tmux sessions  
  - Save: `Ctrl+a` then `Ctrl+s`
  - Restore: `Ctrl+a` then `Ctrl+r`
- **catppuccin/tmux:** Beautiful Catppuccin Mocha color scheme

## Installation

### Using install.sh (Recommended)

Run the dotfiles installer which handles everything automatically:

```bash
cd ~/dots
./install.sh
```

This will:
1. Install tmux via Homebrew/package manager
2. Initialize TPM git submodule
3. Stow the tmux configuration
4. Install all plugins via TPM

### Manual Installation

If you prefer to set up manually:

```bash
# 1. Ensure tmux is installed
brew install tmux  # macOS
# OR
sudo apt install tmux  # Ubuntu/Debian

# 2. Initialize TPM submodule (if not already done)
cd ~/dots
git submodule update --init --recursive

# 3. Stow the configuration
stow tmux

# 4. Install plugins
~/.config/tmux/plugins/tpm/bin/install_plugins

# 5. Start tmux
tmux
```

## Keybindings Reference

### Basic Commands

| Action | Keybinding |
|--------|------------|
| Prefix | `Ctrl+a` |
| Split horizontal | `Ctrl+a` then `\|` |
| Split vertical | `Ctrl+a` then `-` |
| Navigate left | `Ctrl+a` then `h` |
| Navigate down | `Ctrl+a` then `j` |
| Navigate up | `Ctrl+a` then `k` |
| Navigate right | `Ctrl+a` then `l` |
| Reload config | `Ctrl+a` then `:source ~/.config/tmux/tmux.conf` |

### Plugin Management (TPM)

| Action | Keybinding |
|--------|------------|
| Install plugins | `Ctrl+a` then `Shift+I` |
| Update plugins | `Ctrl+a` then `Shift+U` |
| Remove unused | `Ctrl+a` then `Alt+u` |

### Session Management (tmux-resurrect)

| Action | Keybinding |
|--------|------------|
| Save session | `Ctrl+a` then `Ctrl+s` |
| Restore session | `Ctrl+a` then `Ctrl+r` |

## Customization

All configuration is in `tmux.conf`. Key sections:

- **Terminal settings** (lines 3-5): Color support
- **Sensible defaults** (lines 7-12): Mouse, indexing, history
- **Keybindings** (lines 14-27): Prefix and custom bindings
- **Plugins** (lines 29-33): TPM-managed plugins
- **Catppuccin theme** (lines 35-62): Color scheme customization

## Troubleshooting

### Plugins not installing

```bash
# Manually run TPM install
~/.config/tmux/plugins/tpm/bin/install_plugins

# Or inside tmux: Ctrl+a then Shift+I
```

### Colors not working

Ensure your terminal supports true color:
```bash
echo $TERM  # Should be something like "screen-256color" or "tmux-256color"
```

### Catppuccin theme not loading

```bash
# Check if catppuccin plugin is installed
ls ~/.config/tmux/plugins/tmux/

# If missing, reinstall
rm -rf ~/.config/tmux/plugins/tmux
~/.config/tmux/plugins/tpm/bin/install_plugins
```

## Resources

- [tmux Documentation](https://github.com/tmux/tmux/wiki)
- [TPM (Tmux Plugin Manager)](https://github.com/tmux-plugins/tpm)
- [Catppuccin tmux Theme](https://github.com/catppuccin/tmux)
- [tmux-resurrect Plugin](https://github.com/tmux-plugins/tmux-resurrect)
