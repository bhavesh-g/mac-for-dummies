#!/bin/bash
set -Eeuo pipefail

# macOS Local AI setup
# No emoji characters are used in script output.
# Idempotent: checks before installing, and verifies each component.
# Installs:
#   Homebrew, Python 3 + pip, uv, Ollama, Qwen3-Coder-Next (when appropriate),
#   VS Code, Claude Code.
#
# It does NOT authenticate Claude Code or configure Claude Code to use Ollama.

MODEL="qwen3-coder-next:q4_K_M"
MIN_FREE_GB=70

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

intro() {
  printf '%s\n' "============================================================"
  printf '%s\n' "                    LOCAL AI SETUP"
  printf '%s\n' "============================================================"
  printf '%s\n\n' "A little setup gift. I will check first, install only what is missing, and verify everything before moving on."
}

intro

trap 'die "Setup failed at line $LINENO. No further changes were made."' ERR

[[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS only."

ARCH="$(uname -m)"
case "$ARCH" in
  arm64|x86_64) ;;
  *) die "Unsupported CPU architecture: $ARCH" ;;
esac

log "Checking macOS"
sw_vers
ok "macOS detected ($ARCH)"
printf '%s\n' "Okay, this is a suspiciously good setup."

# Xcode Command Line Tools are required by Homebrew on supported macOS installs.
if ! xcode-select -p >/dev/null 2>&1; then
  warn "Xcode Command Line Tools are missing."
  xcode-select --install || true
  die "Install the Xcode Command Line Tools, then run this script again."
else
  ok "Xcode Command Line Tools present"
fi

# Homebrew
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew already installed: $(brew --version | head -1)"
else
  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ "$ARCH" == "arm64" ]]; then
  BREW_PREFIX="/opt/homebrew"
else
  BREW_PREFIX="/usr/local"
fi

CHIP_NAME="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)"
if [[ "$CHIP_NAME" == *"Apple"* ]]; then
  printf '%s\n' "Apple Silicon detected. Very respectable."
fi

if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
elif command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
else
  die "Homebrew installation could not be verified."
fi

brew --version >/dev/null
ok "Homebrew usable: $(brew --version | head -1)"

# Refresh Homebrew metadata so every requested package/cask resolves to the
# current stable release available from the configured Homebrew repositories.
log "Refreshing Homebrew package metadata"
brew update

# Persist Homebrew's shell environment without duplicating it.
SHELL_RC="$HOME/.zprofile"
touch "$SHELL_RC"
if ! grep -Fq 'brew shellenv' "$SHELL_RC"; then
  printf '\n# Homebrew\n' >> "$SHELL_RC"
  printf 'eval "$(%s/bin/brew shellenv)"\n' "$BREW_PREFIX" >> "$SHELL_RC"
fi

# Python + pip
# Homebrew's "python" formula tracks the current stable Python 3 release.
if brew list --formula python >/dev/null 2>&1; then
  log "Updating Python 3 to the current stable Homebrew release"
  if brew outdated --formula python >/dev/null 2>&1; then brew upgrade python; else ok "Python is already current"; fi
else
  log "Installing Python 3 (current stable Homebrew release)"
  brew install python
fi

command -v python3 >/dev/null || die "python3 was not found after installation."
python3 --version >/dev/null
python3 -m pip --version >/dev/null
ok "Python verified: $(python3 --version)"
ok "pip verified: $(python3 -m pip --version)"
printf '%s\n' "Python is ready. Look at you, being prepared."

# uv
if brew list --formula uv >/dev/null 2>&1; then
  log "Updating uv to the current stable Homebrew release"
  if brew outdated --formula uv >/dev/null 2>&1; then brew upgrade uv; else ok "uv is already current"; fi
else
  log "Installing uv (current stable Homebrew release)"
  brew install uv
fi
command -v uv >/dev/null || die "uv was not found after installation."
uv --version >/dev/null
ok "uv verified: $(uv --version)"
printf '%s\n' "That was quick. I like this pace."

# Ollama
if brew list --formula ollama >/dev/null 2>&1; then
  log "Updating Ollama to the current stable Homebrew release"
  if brew outdated --formula ollama >/dev/null 2>&1; then brew upgrade ollama; else ok "Ollama is already current"; fi
else
  log "Installing Ollama (current stable Homebrew release)"
  brew install ollama
fi
command -v ollama >/dev/null || die "Ollama was not found after installation."
ollama --version >/dev/null
ok "Ollama verified: $(ollama --version 2>&1 | head -1)"

# Ensure Ollama server is reachable.
if ! curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
  log "Starting Ollama as a Homebrew service"
  brew services start ollama
  for _ in {1..30}; do
    if curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1; then break; fi
    sleep 1
  done
fi
curl -fsS http://127.0.0.1:11434/api/version >/dev/null || die "Ollama server is not reachable."
ok "Ollama server is running"
printf '%s\n' "The llamas are awake."

# Hardware / storage gate for the selected Qwen model.
MEM_BYTES="$(sysctl -n hw.memsize)"
MEM_GB=$((MEM_BYTES / 1024 / 1024 / 1024))
FREE_GB="$(df -Pk "$HOME" | awk 'NR==2 {printf "%d", $4/1024/1024}')"

printf "Detected memory: %s GB\n" "$MEM_GB"
printf "Free space on home volume: %s GB\n" "$FREE_GB"
if (( MEM_GB >= 64 )); then
  printf '%s\n' "64 GB detected. Okay, show-off."
fi

# Qwen3-Coder-Next Q4_K_M is about 52 GB in Ollama. Keep headroom for the OS/runtime.
if (( MEM_GB >= 64 )); then
  if (( FREE_GB >= MIN_FREE_GB )); then
    if ollama list | awk 'NR>1 {print $1}' | grep -Fxq "$MODEL"; then
      ok "Qwen model already installed: $MODEL"
    else
      log "Downloading Qwen model: $MODEL"
      printf '%s\n' "This one is big. Go get some water. I promise to behave."
      ollama pull "$MODEL"
      ollama list | awk 'NR>1 {print $1}' | grep -Fxq "$MODEL" || die "Qwen model download completed but model verification failed."
      ok "Qwen model verified: $MODEL"
    fi
  else
    warn "Less than ${MIN_FREE_GB} GB free; skipping the ~52 GB Qwen model download."
    warn "Free space available: ${FREE_GB} GB."
  fi
else
  warn "Detected ${MEM_GB} GB RAM. Skipping qwen3-coder-next:q4_K_M because this setup targets 64 GB+ Macs."
  warn "Ollama is installed and ready; choose a smaller model later."
fi

# VS Code
if brew list --cask visual-studio-code >/dev/null 2>&1 || [[ -d "/Applications/Visual Studio Code.app" ]]; then
  log "Updating VS Code to the current stable Homebrew cask release"
  if brew outdated --cask visual-studio-code >/dev/null 2>&1; then brew upgrade --cask visual-studio-code; else ok "VS Code is already current"; fi
else
  log "Installing VS Code (current stable release)"
  brew install --cask visual-studio-code
fi
[[ -d "/Applications/Visual Studio Code.app" ]] || die "VS Code installation could not be verified."
ok "VS Code verified"
printf '%s\n' "Making things unnecessarily sophisticated. As one does."

# Claude Code
# Homebrew provides the current stable Claude Code cask. We install/update only;
# no login, authentication, or Claude/Ollama configuration is performed.
if brew list --cask claude-code >/dev/null 2>&1 || command -v claude >/dev/null 2>&1; then
  log "Updating Claude Code to the current stable Homebrew cask release"
  if brew outdated --cask claude-code >/dev/null 2>&1; then brew upgrade --cask claude-code; else ok "Claude Code is already current"; fi
else
  log "Installing Claude Code (current stable release)"
  brew install --cask claude-code
fi
command -v claude >/dev/null || die "Claude Code executable was not found after installation."
ok "Claude Code verified: $(claude --version 2>&1 | head -1)"
printf '%s\n' "Adding another coding assistant. Apparently one was not enough."

# Final verification
log "Final verification"
printf '%s\n' "Asking the computer to prove it actually did what we asked."
printf "Architecture : %s\n" "$ARCH"
printf "Memory       : %s GB\n" "$MEM_GB"
printf "Python       : %s\n" "$(python3 --version)"
printf "pip          : %s\n" "$(python3 -m pip --version)"
printf "uv           : %s\n" "$(uv --version)"
printf "Ollama       : %s\n" "$(ollama --version 2>&1 | head -1)"
printf "VS Code      : installed\n"
printf "Claude Code  : %s\n" "$(claude --version 2>&1 | head -1)"
printf "Qwen model   : "
if ollama list | awk 'NR>1 {print $1}' | grep -Fxq "$MODEL"; then
  printf "%s\n" "$MODEL"
else
  printf "not installed (see warning above)\n"
fi

log "Setup complete"
printf '%s\n' "Everything checked. Nothing unnecessary was reinstalled."
printf '%s\n' "Claude authentication and Claude/Ollama configuration were intentionally left for later."
printf '%s\n' "Open a new Terminal window before using newly installed commands."
printf '%s\n' ""
printf '%s\n' "You may now proceed to be dangerously productive."
printf '%s\n' "Please try not to become too powerful."
printf '%s\n' "============================================================"
