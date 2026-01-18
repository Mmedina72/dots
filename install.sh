#!/usr/bin/env bash
set -e

# ╔══════════════════════════════════════════════════════════════════╗
# ║                        CONFIGURATION                              ║
# ╚══════════════════════════════════════════════════════════════════╝

DOTS_DIR="$HOME/dots"

# OS-specific stow directories
MACOS_STOW_DIRS=(aerospace starship tmux wezterm zsh)
LINUX_STOW_DIRS=(starship tmux zsh)
WINDOWS_STOW_DIRS=(starship zsh)

# ╔══════════════════════════════════════════════════════════════════╗
# ║                      HELPER FUNCTIONS                             ║
# ╚══════════════════════════════════════════════════════════════════╝

# Color output helpers
print_header() { echo -e "\n\033[1;35m$1\033[0m"; }
print_success() { echo -e "\033[1;32m✓\033[0m $1"; }
print_warning() { echo -e "\033[1;33m⚠\033[0m $1"; }
print_error() { echo -e "\033[1;31m✗\033[0m $1"; }
print_info() { echo -e "\033[1;34m→\033[0m $1"; }

detect_os() {
  case "$(uname -s)" in
    Darwin*)  echo "macos" ;;
    Linux*)   echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)        echo "unknown" ;;
  esac
}

show_menu() {
  echo ""
  echo "=== Operating System Selection ==="
  echo "1) macOS"
  echo "2) Linux"
  echo "3) Windows (WSL/Git Bash)"
  echo "4) Auto-detect (current: $(detect_os))"
  echo ""
  read -p "Select your operating system [1-4] (default: 4): " os_choice
  os_choice=${os_choice:-4}

  case $os_choice in
    1) SELECTED_OS="macos" ;;
    2) SELECTED_OS="linux" ;;
    3) SELECTED_OS="windows" ;;
    4) SELECTED_OS=$(detect_os) ;;
    *)
      print_warning "Invalid selection. Using auto-detect."
      SELECTED_OS=$(detect_os)
      ;;
  esac

  print_success "Selected OS: $SELECTED_OS"
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                   LINUX PACKAGE HELPERS                           ║
# ╚══════════════════════════════════════════════════════════════════╝

# Package name lookup (works on all bash versions, avoids associative arrays)
# Maps Homebrew package names to Linux equivalents
get_linux_pkg() {
  case "$1" in
    bat|eza|fzf|git|lazygit|zoxide|stow|tmux) echo "$1" ;;
    *) echo "" ;;
  esac
}

# Check if package is macOS-only
is_macos_only() {
  case "$1" in
    aerospace|raycast|appcleaner|borders) return 0 ;;
    *) return 1 ;;
  esac
}

install_linux_packages() {
  local pkg_manager=$1
  local install_cmd=$2

  print_header "Installing packages using $pkg_manager..."

  if [[ ! -f "$DOTS_DIR/Brewfile" ]]; then
    print_warning "No Brewfile found at $DOTS_DIR/Brewfile"
    return
  fi

  local packages_to_install=()
  local skipped_macos_packages=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Skip taps (Homebrew-specific)
    [[ "$line" =~ ^[[:space:]]*tap ]] && continue

    # Skip vscode extensions
    [[ "$line" =~ ^[[:space:]]*vscode ]] && continue

    # Handle casks - check if macOS-only
    if [[ "$line" =~ ^[[:space:]]*cask[[:space:]]+\"([^\"]+)\" ]]; then
      local cask_name="${BASH_REMATCH[1]}"
      if is_macos_only "$cask_name"; then
        skipped_macos_packages+=("$cask_name")
      fi
      continue
    fi

    # Extract package name from "brew "package""
    if [[ "$line" =~ brew[[:space:]]+\"([^\"]+)\" ]]; then
      local brew_pkg="${BASH_REMATCH[1]}"
      # Handle packages with slashes (like felixkratz/formulae/borders)
      local brew_pkg_short="${brew_pkg##*/}"

      # Skip macOS-only packages
      if is_macos_only "$brew_pkg_short"; then
        skipped_macos_packages+=("$brew_pkg")
        continue
      fi

      # Check if package is in our mapping
      local linux_pkg
      linux_pkg=$(get_linux_pkg "$brew_pkg_short")
      if [[ -n "$linux_pkg" ]]; then
        if ! command -v "$brew_pkg_short" >/dev/null 2>&1; then
          packages_to_install+=("$linux_pkg")
        else
          print_success "$brew_pkg_short is already installed"
        fi
      else
        print_warning "No mapping found for: $brew_pkg_short (may need manual installation)"
      fi
    fi
  done < "$DOTS_DIR/Brewfile"

  # Show skipped macOS-only packages
  if [[ ${#skipped_macos_packages[@]} -gt 0 ]]; then
    print_info "Skipped macOS-only packages: ${skipped_macos_packages[*]}"
  fi

  # Install packages one by one to handle failures gracefully
  if [[ ${#packages_to_install[@]} -gt 0 ]]; then
    print_info "Installing packages..."
    local failed_packages=()
    for pkg in "${packages_to_install[@]}"; do
      print_info "Installing $pkg..."
      if $install_cmd "$pkg" 2>/dev/null; then
        print_success "$pkg installed successfully"
      else
        print_warning "$pkg not available in repositories, will try alternative method"
        failed_packages+=("$pkg")
      fi
    done

    # Try alternative installation methods for failed packages
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
      print_header "Attempting alternative installation methods for: ${failed_packages[*]}"
      install_fallback_packages "${failed_packages[@]}"
    fi
  else
    print_success "All mappable packages are already installed"
  fi

  # Install packages that typically need alternative methods
  install_special_packages
}

install_fallback_packages() {
  local packages=("$@")

  for pkg in "${packages[@]}"; do
    case $pkg in
      bat)
        print_info "Installing bat via cargo or downloading binary..."
        if command -v cargo >/dev/null 2>&1; then
          cargo install bat 2>/dev/null && print_success "bat installed via cargo" || print_warning "Failed to install bat"
        else
          print_warning "Install Rust/cargo to install bat, or download from: https://github.com/sharkdp/bat"
        fi
        ;;
      eza)
        print_info "Installing eza via cargo or downloading binary..."
        if command -v cargo >/dev/null 2>&1; then
          cargo install eza 2>/dev/null && print_success "eza installed via cargo" || print_warning "Failed to install eza"
        else
          print_warning "Install Rust/cargo to install eza, or download from: https://github.com/eza-community/eza"
        fi
        ;;
      lazygit)
        print_info "Installing lazygit..."
        local lazygit_version="0.41.0"
        local arch
        arch=$(uname -m)
        case $arch in
          x86_64) arch="x86_64" ;;
          aarch64|arm64) arch="arm64" ;;
          *) arch="x86_64" ;;
        esac
        local lazygit_url="https://github.com/jesseduffield/lazygit/releases/download/v${lazygit_version}/lazygit_${lazygit_version}_Linux_${arch}.tar.gz"
        if curl -fsSL "$lazygit_url" -o /tmp/lazygit.tar.gz 2>/dev/null; then
          mkdir -p "$HOME/.local/bin"
          tar -xzf /tmp/lazygit.tar.gz -C "$HOME/.local/bin" lazygit 2>/dev/null && {
            chmod +x "$HOME/.local/bin/lazygit"
            print_success "lazygit installed to ~/.local/bin"
          } || print_warning "Failed to extract lazygit"
          rm -f /tmp/lazygit.tar.gz
        else
          print_warning "Failed to download lazygit. Install manually from: https://github.com/jesseduffield/lazygit"
        fi
        ;;
      zoxide)
        print_info "Installing zoxide..."
        if command -v cargo >/dev/null 2>&1; then
          cargo install zoxide 2>/dev/null && print_success "zoxide installed via cargo" || print_warning "Failed to install zoxide"
        else
          curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
        fi
        ;;
      fzf)
        print_info "Installing fzf..."
        if [[ -d "$HOME/.fzf" ]]; then
          print_success "fzf already installed"
        else
          git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" 2>/dev/null && {
            "$HOME/.fzf/install" --bin --no-update-rc 2>/dev/null
            print_success "fzf installed"
          } || print_warning "Failed to install fzf"
        fi
        ;;
      *)
        print_warning "No fallback method for $pkg. Please install manually."
        ;;
    esac
  done
}

install_special_packages() {
  print_header "Installing packages that require special installation methods..."

  # Starship prompt
  if ! command -v starship >/dev/null 2>&1; then
    print_info "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  else
    print_success "Starship is already installed"
  fi

  # fnm (Fast Node Manager)
  if ! command -v fnm >/dev/null 2>&1; then
    print_info "Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --use-on-cd)" 2>/dev/null || true
  else
    print_success "fnm is already installed"
  fi

  # mise (universal runtime manager)
  if ! command -v mise >/dev/null 2>&1; then
    print_info "Installing mise..."
    curl https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
  else
    print_success "mise is already installed"
  fi
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                     TMUX PLUGIN SETUP                             ║
# ╚══════════════════════════════════════════════════════════════════╝

setup_tmux_plugins() {
  print_header "Setting up tmux plugins..."
  
  local tpm_dir="$HOME/.config/tmux/plugins/tpm"
  
  # TPM should be symlinked via stow as a submodule
  if [[ ! -d "$tpm_dir" ]]; then
    print_error "TPM not found at $tpm_dir"
    print_info "Ensure tmux configuration was stowed correctly"
    return 1
  fi
  
  # Check if TPM is actually usable (not just an empty directory)
  if [[ ! -f "$tpm_dir/tpm" ]]; then
    print_error "TPM directory exists but tpm executable not found"
    print_info "This likely means the git submodule wasn't initialized"
    print_info "Run: cd $DOTS_DIR && git submodule update --init --recursive"
    return 1
  fi
  
  # Install all plugins defined in tmux.conf via TPM
  print_info "Installing tmux plugins (catppuccin, tmux-sensible, tmux-resurrect)..."
  if "$tpm_dir/bin/install_plugins" 2>&1 | grep -q "download success\|Already installed"; then
    print_success "tmux plugins installed successfully!"
  else
    print_warning "Plugin installation may have encountered issues"
    print_info "You can manually install by opening tmux and pressing: Ctrl+a then Shift+I"
  fi
  
  print_info "To use tmux with the new configuration, run: tmux"
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                        macOS SETUP                                ║
# ╚══════════════════════════════════════════════════════════════════╝

setup_macos() {
  print_header "Setting up macOS..."

  # Check for Xcode Command Line Tools
  if ! xcode-select -p >/dev/null 2>&1; then
    print_info "Installing Xcode Command Line Tools..."
    xcode-select --install
    print_warning "Please rerun this script after installation finishes."
    exit 1
  fi

  # Install Homebrew if not installed
  if ! command -v brew >/dev/null 2>&1; then
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH (for Apple Silicon & Intel)
    if [[ "$(uname -m)" == "arm64" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    else
      eval "$(/usr/local/bin/brew shellenv)"
      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
    fi
  fi

  print_success "Homebrew installed and ready."

  # Install GNU Stow if not installed
  if ! command -v stow >/dev/null 2>&1; then
    print_info "Installing GNU Stow..."
    brew install stow
  fi

  # Brewfile setup
  if [[ -f "$DOTS_DIR/Brewfile" ]]; then
    print_info "Installing packages from Brewfile..."
    brew bundle --file="$DOTS_DIR/Brewfile"
  else
    print_warning "No Brewfile found at $DOTS_DIR/Brewfile - skipping Homebrew bundle."
  fi
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                        LINUX SETUP                                ║
# ╚══════════════════════════════════════════════════════════════════╝

setup_linux() {
  print_header "Setting up Linux..."

  # Detect Linux package manager
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
    UPDATE_CMD="sudo apt-get update"
    INSTALL_CMD="sudo apt-get install -y"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    UPDATE_CMD="sudo dnf check-update || true"
    INSTALL_CMD="sudo dnf install -y"
  elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
    UPDATE_CMD="sudo yum check-update || true"
    INSTALL_CMD="sudo yum install -y"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
    UPDATE_CMD="sudo pacman -Sy"
    INSTALL_CMD="sudo pacman -S --noconfirm"
  elif command -v zypper >/dev/null 2>&1; then
    PKG_MANAGER="zypper"
    UPDATE_CMD="sudo zypper refresh"
    INSTALL_CMD="sudo zypper install -y"
  else
    print_warning "Could not detect package manager. Please install GNU Stow manually."
    PKG_MANAGER="unknown"
  fi

  if [[ "$PKG_MANAGER" != "unknown" ]]; then
    print_info "Detected package manager: $PKG_MANAGER"

    # Ensure ~/.local/bin is in PATH
    mkdir -p "$HOME/.local/bin"
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
      export PATH="$HOME/.local/bin:$PATH"
      for shell_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [[ -f "$shell_file" ]] && ! grep -q '\.local/bin' "$shell_file" 2>/dev/null; then
          echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_file"
        fi
      done
    fi

    # Update package lists
    print_info "Updating package lists..."
    $UPDATE_CMD

    # Install GNU Stow
    if ! command -v stow >/dev/null 2>&1; then
      print_info "Installing GNU Stow..."
      $INSTALL_CMD stow
    fi

    # Install packages from Brewfile using native package manager
    install_linux_packages "$PKG_MANAGER" "$INSTALL_CMD"
  else
    print_warning "Cannot install packages automatically without a detected package manager"
  fi
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                       WINDOWS SETUP                               ║
# ╚══════════════════════════════════════════════════════════════════╝

setup_windows() {
  print_header "Setting up Windows..."

  # Check if running in WSL
  if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null || [[ -n "$WSL_DISTRO_NAME" ]]; then
    print_success "Running in WSL. Using Linux setup..."
    setup_linux
    return
  fi

  # Native Windows (Git Bash, MSYS2, etc.)
  print_warning "Native Windows detected. Some features may be limited."

  # Check for Chocolatey
  if command -v choco >/dev/null 2>&1; then
    print_info "Chocolatey detected."
    if ! command -v stow >/dev/null 2>&1; then
      print_info "Installing GNU Stow via Chocolatey..."
      choco install stow -y
    fi
  # Check for winget
  elif command -v winget >/dev/null 2>&1; then
    print_info "Windows Package Manager detected."
    if ! command -v stow >/dev/null 2>&1; then
      print_info "Installing GNU Stow via winget..."
      winget install --id=GnuWin32.Stow -e
    fi
  else
    print_warning "No package manager detected. Please install GNU Stow manually:"
    echo "   - Chocolatey: choco install stow"
    echo "   - winget: winget install --id=GnuWin32.Stow -e"
    echo "   - Or download from: https://www.gnu.org/software/stow/"
  fi

  if [[ -f "$DOTS_DIR/Brewfile" ]]; then
    print_info "Brewfile found but Homebrew is not typically used on Windows."
    echo "   Consider using Chocolatey or winget for package management."
  fi
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                      COMMON SETUP                                 ║
# ╚══════════════════════════════════════════════════════════════════╝

stow_dotfiles() {
  print_header "Linking configuration files using Stow..."
  cd "$DOTS_DIR" || exit 1

  # Select stow directories based on OS
  local stow_dirs=()
  case "$SELECTED_OS" in
    macos)   stow_dirs=("${MACOS_STOW_DIRS[@]}") ;;
    linux)   stow_dirs=("${LINUX_STOW_DIRS[@]}") ;;
    windows) stow_dirs=("${WINDOWS_STOW_DIRS[@]}") ;;
    *)       stow_dirs=("${LINUX_STOW_DIRS[@]}") ;;
  esac

  for dir in "${stow_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      print_info "Stowing $dir..."
      stow -v "$dir"
    else
      print_warning "Directory $dir not found, skipping..."
    fi
  done
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                         MAIN                                      ║
# ╚══════════════════════════════════════════════════════════════════╝

main() {
  # Show menu and get OS selection
  show_menu

  print_header "Starting setup for $SELECTED_OS..."

  # Run OS-specific setup
  case "$SELECTED_OS" in
    macos)   setup_macos ;;
    linux)   setup_linux ;;
    windows) setup_windows ;;
    *)
      print_error "Unknown operating system: $SELECTED_OS"
      print_warning "Attempting generic setup..."
      if ! command -v stow >/dev/null 2>&1; then
        print_error "GNU Stow not found. Please install it manually."
        exit 1
      fi
      ;;
  esac

  # Stow dotfiles (common to all OS)
  stow_dotfiles

  # Special package installations (common to all OS)
  install_special_packages

  # Setup tmux plugins via TPM
  setup_tmux_plugins

  # Final steps
  print_header "Setup complete!"
  case "$SELECTED_OS" in
    macos|linux)
      print_info "Open a new terminal session or run 'exec zsh' to load new configs."
      ;;
    windows)
      print_info "Restart your terminal or run 'source ~/.bashrc' to load new configs."
      ;;
  esac
}

# Run main function
main
