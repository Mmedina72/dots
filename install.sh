#!/usr/bin/env bash
set -e

# === CONFIGURATION ===
DOTS_DIR="$HOME/dots"

echo "🚀 Starting setup..."

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

# --- Brewfile setup ---
if [[ -f "$DOTS_DIR/Brewfile" ]]; then
  echo "📦 Installing packages from Brewfile..."
  brew bundle --file="$DOTS_DIR/Brewfile"
else
  echo "⚠️ No Brewfile found at $DOTS_DIR/Brewfile — skipping Homebrew bundle."
fi

# --- Install GNU Stow if not installed ---
if ! command -v stow >/dev/null 2>&1; then
  echo "📦 Installing GNU Stow..."
  brew install stow
fi

# --- Stow dotfiles ---
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

# --- Final steps ---
echo "🎉 Setup complete!"
echo "🪄 Open a new terminal session or run 'exec zsh' to load new configs."
