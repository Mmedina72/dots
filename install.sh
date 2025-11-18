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
    
    # Update package lists
    echo "🔄 Updating package lists..."
    $UPDATE_CMD

    # Install GNU Stow
    if ! command -v stow >/dev/null 2>&1; then
      echo "📦 Installing GNU Stow..."
      $INSTALL_CMD stow
    fi
  fi

  # --- Install Homebrew for Linux (optional) ---
  if ! command -v brew >/dev/null 2>&1; then
    read -p "🍺 Install Homebrew for Linux? (y/N): " install_brew
    if [[ "$install_brew" =~ ^[Yy]$ ]]; then
      echo "🍺 Installing Homebrew for Linux..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      
      # Add brew to PATH
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
      echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.bashrc"
      echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    fi
  fi

  # --- Brewfile setup (if Homebrew is installed) ---
  if command -v brew >/dev/null 2>&1 && [[ -f "$DOTS_DIR/Brewfile" ]]; then
    echo "📦 Installing packages from Brewfile..."
    brew bundle --file="$DOTS_DIR/Brewfile"
  elif [[ -f "$DOTS_DIR/Brewfile" ]]; then
    echo "⚠️ Brewfile found but Homebrew not installed — skipping Homebrew bundle."
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
