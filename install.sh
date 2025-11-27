#!/usr/bin/env bash
set -e

# === CONFIGURATION ===
DOTS_DIR="$HOME/dots"

# === OS DETECTION AND SELECTION ===
detect_os() {
  case "$(uname -s)" in
    Darwin*)
      echo "macos"
      ;;
    Linux*)
      echo "linux"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "windows"
      ;;
    *)
      echo "unknown"
      ;;
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
    1)
      SELECTED_OS="macos"
      ;;
    2)
      SELECTED_OS="linux"
      ;;
    3)
      SELECTED_OS="windows"
      ;;
    4)
      SELECTED_OS=$(detect_os)
      ;;
    *)
      echo "❌ Invalid selection. Using auto-detect."
      SELECTED_OS=$(detect_os)
      ;;
  esac
  
  echo "✅ Selected OS: $SELECTED_OS"
}

# Show menu and get OS selection
show_menu

echo "🚀 Starting setup for $SELECTED_OS..."

# === macOS SETUP ===
setup_macos() {
  # --- Check for Xcode Command Line Tools ---
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "📦 Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "➡️  Please rerun this script after installation finishes."
    exit 1
  fi

  # --- Install Homebrew if not installed ---
  if ! command -v brew >/dev/null 2>&1; then
    echo "🍺 Installing Homebrew..."
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

  echo "✅ Homebrew installed and ready."

  # --- Install GNU Stow if not installed ---
  if ! command -v stow >/dev/null 2>&1; then
    echo "📦 Installing GNU Stow..."
    brew install stow
  fi

  # --- Brewfile setup ---
  if [[ -f "$DOTS_DIR/Brewfile" ]]; then
    echo "📦 Installing packages from Brewfile..."
    brew bundle --file="$DOTS_DIR/Brewfile"
  else
    echo "⚠️ No Brewfile found at $DOTS_DIR/Brewfile — skipping Homebrew bundle."
  fi
}

# === LINUX SETUP ===
setup_linux() {
  # Detect Linux package manager
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
    UPDATE_CMD="sudo apt-get update"
    INSTALL_CMD="sudo apt-get install -y"
  elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
    UPDATE_CMD="sudo yum check-update || true"
    INSTALL_CMD="sudo yum install -y"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    UPDATE_CMD="sudo dnf check-update || true"
    INSTALL_CMD="sudo dnf install -y"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
    UPDATE_CMD="sudo pacman -Sy"
    INSTALL_CMD="sudo pacman -S --noconfirm"
  elif command -v zypper >/dev/null 2>&1; then
    PKG_MANAGER="zypper"
    UPDATE_CMD="sudo zypper refresh"
    INSTALL_CMD="sudo zypper install -y"
  else
    echo "⚠️  Could not detect package manager. Please install GNU Stow manually."
    PKG_MANAGER="unknown"
  fi

  if [[ "$PKG_MANAGER" != "unknown" ]]; then
    echo "📦 Detected package manager: $PKG_MANAGER"
    
    # Ensure ~/.local/bin is in PATH
    mkdir -p "$HOME/.local/bin"
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
      export PATH="$HOME/.local/bin:$PATH"
      # Add to shell config files if not already present
      for shell_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [[ -f "$shell_file" ]] && ! grep -q '\.local/bin' "$shell_file" 2>/dev/null; then
          echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_file"
        fi
      done
    fi
    
    # Update package lists
    echo "🔄 Updating package lists..."
    $UPDATE_CMD

    # Install GNU Stow
    if ! command -v stow >/dev/null 2>&1; then
      echo "📦 Installing GNU Stow..."
      $INSTALL_CMD stow
    fi
  fi

  # --- Install packages from Brewfile using native package manager ---
  install_linux_packages() {
    local pkg_manager=$1
    local install_cmd=$2
    
    echo "📦 Installing packages using $pkg_manager..."
    
    # Package mappings: Homebrew -> Linux package names
    # Common packages available in most distros
    declare -A pkg_map_apt=(
      ["bat"]="bat"
      ["eza"]="eza"
      ["fzf"]="fzf"
      ["git"]="git"
      ["lazygit"]="lazygit"
      ["zoxide"]="zoxide"
      ["stow"]="stow"
    )
    
    declare -A pkg_map_dnf=(
      ["bat"]="bat"
      ["eza"]="eza"
      ["fzf"]="fzf"
      ["git"]="git"
      ["lazygit"]="lazygit"
      ["zoxide"]="zoxide"
      ["stow"]="stow"
    )
    
    declare -A pkg_map_pacman=(
      ["bat"]="bat"
      ["eza"]="eza"
      ["fzf"]="fzf"
      ["git"]="git"
      ["lazygit"]="lazygit"
      ["zoxide"]="zoxide"
      ["stow"]="stow"
    )
    
    # Select the appropriate package map
    case $pkg_manager in
      apt)
        declare -n pkg_map=pkg_map_apt
        ;;
      dnf|yum)
        declare -n pkg_map=pkg_map_dnf
        ;;
      pacman)
        declare -n pkg_map=pkg_map_pacman
        ;;
      zypper)
        # zypper uses similar names, try apt mapping
        declare -n pkg_map=pkg_map_apt
        ;;
      *)
        echo "⚠️  Unsupported package manager for automatic package installation"
        return
        ;;
    esac
    
    # Read Brewfile and install packages
    if [[ -f "$DOTS_DIR/Brewfile" ]]; then
      local packages_to_install=()
      local skipped_macos_packages=()
      
      while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Skip taps (Homebrew-specific)
        if [[ "$line" =~ ^[[:space:]]*tap ]]; then
          continue
        fi
        
        # Skip specific macOS-only casks (aerospace, raycast, appcleaner)
        if [[ "$line" =~ ^[[:space:]]*cask[[:space:]]+\"([^\"]+)\" ]]; then
          local cask_name="${BASH_REMATCH[1]}"
          local macos_only_casks=("aerospace" "raycast" "appcleaner")
          if printf '%s\n' "${macos_only_casks[@]}" | grep -q "^${cask_name}$"; then
            skipped_macos_packages+=("$cask_name")
            continue
          fi
          # Other casks are allowed to continue (they may have Linux equivalents)
        fi
        
        # Skip vscode extensions (handled separately if needed)
        if [[ "$line" =~ ^[[:space:]]*vscode ]]; then
          continue
        fi
        
        # Extract package name from "brew "package""
        if [[ "$line" =~ brew[[:space:]]+\"([^\"]+)\" ]]; then
          local brew_pkg="${BASH_REMATCH[1]}"
          # Handle packages with slashes (like felixkratz/formulae/borders)
          local brew_pkg_short="${brew_pkg##*/}"
          
          # Skip known macOS-only packages (even if listed as brew packages)
          local macos_only_packages=("aerospace" "raycast" "appcleaner")
          if printf '%s\n' "${macos_only_packages[@]}" | grep -q "^${brew_pkg_short}$"; then
            skipped_macos_packages+=("$brew_pkg")
            continue
          fi
          
          # Check if package is in our mapping
          if [[ -n "${pkg_map[$brew_pkg_short]}" ]]; then
            local linux_pkg="${pkg_map[$brew_pkg_short]}"
            # Check if already installed
            if ! command -v "$brew_pkg_short" >/dev/null 2>&1; then
              packages_to_install+=("$linux_pkg")
            else
              echo "✅ $brew_pkg_short is already installed"
            fi
          else
            echo "⚠️  No mapping found for: $brew_pkg_short (may need manual installation)"
          fi
        fi
      done < "$DOTS_DIR/Brewfile"
      
      # Show skipped macOS-only packages
      if [[ ${#skipped_macos_packages[@]} -gt 0 ]]; then
        echo "🍎 Skipped macOS-only packages: ${skipped_macos_packages[*]}"
      fi
      
      # Install packages (try one by one to handle failures gracefully)
      if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        echo "📦 Installing packages..."
        local failed_packages=()
        for pkg in "${packages_to_install[@]}"; do
          echo "  → Installing $pkg..."
          if $install_cmd "$pkg" 2>/dev/null; then
            echo "  ✅ $pkg installed successfully"
          else
            echo "  ⚠️  $pkg not available in repositories, will try alternative method"
            failed_packages+=("$pkg")
          fi
        done
        
        # Try alternative installation methods for failed packages
        if [[ ${#failed_packages[@]} -gt 0 ]]; then
          echo "🔧 Attempting alternative installation methods for: ${failed_packages[*]}"
          install_fallback_packages "${failed_packages[@]}"
        fi
      else
        echo "✅ All mappable packages are already installed"
      fi
      
      # Install packages that typically need alternative methods
      install_special_packages
    else
      echo "⚠️  No Brewfile found at $DOTS_DIR/Brewfile"
    fi
  }
  
  # Fallback installation for packages not in repositories
  install_fallback_packages() {
    local packages=("$@")
    
    for pkg in "${packages[@]}"; do
      case $pkg in
        bat)
          echo "  📦 Installing bat via cargo or downloading binary..."
          if command -v cargo >/dev/null 2>&1; then
            cargo install bat 2>/dev/null && echo "  ✅ bat installed via cargo" || echo "  ⚠️  Failed to install bat"
          else
            echo "  ⚠️  Install Rust/cargo to install bat, or download from: https://github.com/sharkdp/bat"
          fi
          ;;
        eza)
          echo "  📦 Installing eza via cargo or downloading binary..."
          if command -v cargo >/dev/null 2>&1; then
            cargo install eza 2>/dev/null && echo "  ✅ eza installed via cargo" || echo "  ⚠️  Failed to install eza"
          else
            echo "  ⚠️  Install Rust/cargo to install eza, or download from: https://github.com/eza-community/eza"
          fi
          ;;
        lazygit)
          echo "  📦 Installing lazygit..."
          local lazygit_version="0.41.0"
          local arch=$(uname -m)
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
              echo "  ✅ lazygit installed to ~/.local/bin"
            } || echo "  ⚠️  Failed to extract lazygit"
            rm -f /tmp/lazygit.tar.gz
          else
            echo "  ⚠️  Failed to download lazygit. Install manually from: https://github.com/jesseduffield/lazygit"
          fi
          ;;
        zoxide)
          echo "  📦 Installing zoxide..."
          if command -v cargo >/dev/null 2>&1; then
            cargo install zoxide 2>/dev/null && echo "  ✅ zoxide installed via cargo" || echo "  ⚠️  Failed to install zoxide"
          else
            curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
          fi
          ;;
        fzf)
          echo "  📦 Installing fzf..."
          if [[ -d "$HOME/.fzf" ]]; then
            echo "  ✅ fzf already installed"
          else
            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" 2>/dev/null && {
              "$HOME/.fzf/install" --bin --no-update-rc 2>/dev/null
              echo "  ✅ fzf installed"
            } || echo "  ⚠️  Failed to install fzf"
          fi
          ;;
        *)
          echo "  ⚠️  No fallback method for $pkg. Please install manually."
          ;;
      esac
    done
  }
  
  # Install packages that need special installation methods
  install_special_packages() {
    echo "🔧 Installing packages that require special installation methods..."
    
    # Starship prompt
    if ! command -v starship >/dev/null 2>&1; then
      echo "📦 Installing Starship..."
      curl -sS https://starship.rs/install.sh | sh -s -- -y
    else
      echo "✅ Starship is already installed"
    fi
    
    # fnm (Fast Node Manager) - alternative to nvm
    if ! command -v fnm >/dev/null 2>&1; then
      echo "📦 Installing fnm..."
      curl -fsSL https://fnm.vercel.app/install | bash
      # Source fnm for current session
      export PATH="$HOME/.local/share/fnm:$PATH"
      eval "$(fnm env --use-on-cd)"
    else
      echo "✅ fnm is already installed"
    fi
    
    # mise (formerly rtx) - universal runtime manager
    if ! command -v mise >/dev/null 2>&1; then
      echo "📦 Installing mise..."
      curl https://mise.run | sh
      # Add to PATH for current session
      export PATH="$HOME/.local/bin:$PATH"
    else
      echo "✅ mise is already installed"
    fi
    
    # borders (from felixkratz/formulae) - may need manual installation
    if ! command -v borders >/dev/null 2>&1; then
      echo "⚠️  'borders' not found. You may need to install it manually from:"
      echo "   https://github.com/felixkratz/borders"
    fi
  }
  
  # Run package installation
  if [[ "$PKG_MANAGER" != "unknown" ]]; then
    install_linux_packages "$PKG_MANAGER" "$INSTALL_CMD"
  else
    echo "⚠️  Cannot install packages automatically without a detected package manager"
  fi
}

# === WINDOWS SETUP ===
setup_windows() {
  echo "🪟 Windows setup detected..."
  
  # Check if running in WSL
  if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null || [[ -n "$WSL_DISTRO_NAME" ]]; then
    echo "✅ Running in WSL. Using Linux setup..."
    setup_linux
    return
  fi

  # Native Windows (Git Bash, MSYS2, etc.)
  echo "⚠️  Native Windows detected. Some features may be limited."
  
  # Check for Chocolatey
  if command -v choco >/dev/null 2>&1; then
    echo "🍫 Chocolatey detected."
    if ! command -v stow >/dev/null 2>&1; then
      echo "📦 Installing GNU Stow via Chocolatey..."
      choco install stow -y
    fi
  # Check for winget
  elif command -v winget >/dev/null 2>&1; then
    echo "📦 Windows Package Manager detected."
    if ! command -v stow >/dev/null 2>&1; then
      echo "📦 Installing GNU Stow via winget..."
      winget install --id=GnuWin32.Stow -e
    fi
  else
    echo "⚠️  No package manager detected. Please install GNU Stow manually:"
    echo "   - Chocolatey: choco install stow"
    echo "   - winget: winget install --id=GnuWin32.Stow -e"
    echo "   - Or download from: https://www.gnu.org/software/stow/"
  fi

  # Note: Brewfile typically not used on Windows
  if [[ -f "$DOTS_DIR/Brewfile" ]]; then
    echo "ℹ️  Brewfile found but Homebrew is not typically used on Windows."
    echo "   Consider using Chocolatey or winget for package management."
  fi
}

# === RUN OS-SPECIFIC SETUP ===
case "$SELECTED_OS" in
  macos)
    setup_macos
    ;;
  linux)
    setup_linux
    ;;
  windows)
    setup_windows
    ;;
  *)
    echo "❌ Unknown operating system: $SELECTED_OS"
    echo "⚠️  Attempting generic setup..."
    if ! command -v stow >/dev/null 2>&1; then
      echo "❌ GNU Stow not found. Please install it manually."
      exit 1
    fi
    ;;
esac

# === STOW DOTFILES (COMMON TO ALL OS) ===
echo "🧩 Linking configuration files using Stow..."
cd "$DOTS_DIR" || exit 1

# You can list directories explicitly, or just loop through all
for dir in aerospace starship wezterm zsh; do
  if [[ -d "$dir" ]]; then
    echo "➡️  Stowing $dir..."
    stow -v "$dir"
  else
    echo "⚠️  Directory $dir not found, skipping..."
  fi
done

# === FINAL STEPS ===
echo "🎉 Setup complete!"
case "$SELECTED_OS" in
  macos|linux)
    echo "🪄 Open a new terminal session or run 'exec zsh' to load new configs."
    ;;
  windows)
    echo "🪄 Restart your terminal or run 'source ~/.bashrc' to load new configs."
    ;;
esac
