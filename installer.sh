#!/bin/sh
set -eu

info() { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }

die() { err "$*"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
need_root() { [ "$(id -u)" -eq 0 ]; }

# Linux only
[ "$(uname -s)" = "Linux" ] || die "This installer supports Linux only."

# Detect package manager
PM=""
if have apt-get; then PM=apt
elif have dnf; then PM=dnf
elif have pacman; then PM=pacman
elif have zypper; then PM=zypper
else die "Unsupported distribution (no apt/dnf/pacman/zypper found)."
fi

SUDO=""
if ! need_root; then
  if have sudo; then SUDO=sudo; else die "This installer needs root privileges to install packages. Please install sudo or run as root."; fi
fi

# Install packages with the detected PM
apt_install() {
  $SUDO apt-get update -y
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

dnf_install() {
  $SUDO dnf install -y "$@"
}

pacman_install() {
  $SUDO pacman -Sy --noconfirm
  $SUDO pacman -S --needed --noconfirm "$@"
}

zypper_install() {
  $SUDO zypper --non-interactive refresh
  $SUDO zypper --non-interactive install "$@"
}

install_pkgs() {
  case "$PM" in
    apt)
      apt_install git curl bash python3 python3-venv python3-pip mpv nodejs npm
      ;;
    dnf)
      dnf_install git curl bash python3 python3-pip python3-virtualenv mpv nodejs npm
      ;;
    pacman)
      pacman_install git curl bash python python-pip mpv nodejs npm
      ;;
    zypper)
      zypper_install git curl bash python3 python3-pip python3-virtualenv mpv nodejs npm
      ;;
  esac
}

info "Installing required system packages (git, curl, python, mpv, nodejs/npm)"
install_pkgs

# Ensure npm installs to user prefix to avoid sudo
export NPM_CONFIG_PREFIX="${HOME}/.local"
mkdir -p "${HOME}/.local/bin"
export PATH="${HOME}/.local/bin:${PATH}"

# Install peerflix if missing
if ! have peerflix; then
  info "Installing peerflix (per-user) via npm"
  npm install -g peerflix
else
  info "peerflix already installed"
fi

# Determine source directory (where this installer lives) and prefer local sources
# POSIX way to resolve script dir
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC_DIR="$SCRIPT_DIR"
LOCAL_MODE=0
if [ -f "$SRC_DIR/popcorn_cli.py" ]; then
  LOCAL_MODE=1
fi

# Clone or update repo under ~/.local/share (unless running from local sources)
DEST_DIR="${POPCORN_DIR:-"${HOME}/.local/share/popcorn_cli"}"
if [ "$LOCAL_MODE" -eq 1 ]; then
  info "Using local source at $SRC_DIR (no git clone)."
  DEST_DIR="$SRC_DIR"
elif [ -d "$DEST_DIR/.git" ]; then
  info "Updating existing installation at $DEST_DIR"
  git -C "$DEST_DIR" fetch --all --prune
  # Try main, then master
  if git -C "$DEST_DIR" rev-parse --verify origin/main >/dev/null 2>&1; then
    git -C "$DEST_DIR" checkout main
    git -C "$DEST_DIR" pull --ff-only origin main
  else
    git -C "$DEST_DIR" checkout master || true
    git -C "$DEST_DIR" pull --ff-only || true
  fi
else
  info "Cloning popcorn_cli to $DEST_DIR"
  git clone https://github.com/J0bot/popcorn_cli.git "$DEST_DIR"
fi

# Setup python venv and deps
info "Setting up Python virtual environment"
( cd "$DEST_DIR" && bash ./install.sh )

# Create launcher in ~/.local/bin
BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR"
LAUNCHER="$BIN_DIR/popcorn"
cat > "$LAUNCHER" <<EOF
#!/bin/sh
set -eu
APP_DIR="$DEST_DIR"
PY="\$APP_DIR/.venv/bin/python"
if [ ! -x "\$PY" ]; then
  echo "Python environment not found at \$PY. Re-running setup..." >&2
  bash "\$APP_DIR/install.sh"
fi
exec "\$PY" "\$APP_DIR/popcorn_cli.py" "\$@"
EOF
chmod +x "$LAUNCHER"

# Ensure ~/.local/bin is on PATH for future shells
PROFILE_UPDATED=false
if ! grep -qs 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
  PROFILE_UPDATED=true
fi
if ! grep -qs 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  PROFILE_UPDATED=true
fi

info "Installation complete."

cat <<MSG

Use the app:
  popcorn

If 'popcorn' is not found, ensure ~/.local/bin is in your PATH or open a new terminal.

One-liner for README (after you push installer.sh to main):
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/J0bot/popcorn_cli/main/installer.sh)"

Uninstall:
  rm -rf "${HOME}/.local/share/popcorn_cli" "${HOME}/.local/bin/popcorn"

MSG
