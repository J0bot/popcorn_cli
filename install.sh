#!/usr/bin/env bash
set -euo pipefail


PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${VENV_DIR:-"$PROJECT_DIR/.venv"}"
PY_BIN="${PY_BIN:-python3}"
REQ_FILE="${REQ_FILE:-"$PROJECT_DIR/requirements.txt"}"

info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERR ]\033[0m $*"; }

# Detect Python
if ! command -v "$PY_BIN" >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    PY_BIN=python
  else
    err "Python interpreter not found (looked for python3 and python). Install Python and retry."
    exit 1
  fi
fi

info "Using Python: $(command -v "$PY_BIN")"

# Create venv if missing
if [[ ! -d "$VENV_DIR" ]]; then
  info "Creating virtual environment at $VENV_DIR"
  "$PY_BIN" -m venv "$VENV_DIR"
else
  info "Virtual environment already exists at $VENV_DIR"
fi

# Activate venv
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

info "Upgrading pip, setuptools, wheel"
python -m pip install --upgrade pip setuptools wheel

# Install dependencies
if [[ -f "$REQ_FILE" ]]; then
  info "Installing Python dependencies from $REQ_FILE"
  python -m pip install -r "$REQ_FILE"
else
  warn "No requirements.txt found at $REQ_FILE — skipping Python dependency install"
fi

# External tools checks
missing=false
if ! command -v mpv >/dev/null 2>&1; then
  missing=true
  warn "mpv not found. Install it via your package manager, e.g.:"
  echo "  sudo apt update && sudo apt install -y mpv    # Debian/Ubuntu"
  echo "  sudo dnf install -y mpv                        # Fedora/RHEL"
  echo "  sudo pacman -S mpv                             # Arch"
fi

if ! command -v peerflix >/dev/null 2>&1; then
  missing=true
  warn "peerflix not found. Install it via npm (Node.js required):"
  echo "  npm install -g peerflix"
fi

if [[ "$missing" == false ]]; then
  info "All external tools detected (mpv, peerflix)."
fi

cat <<EOF

Done.

To activate the virtual environment and run the app:
  source "$VENV_DIR/bin/activate"
  python "$PROJECT_DIR/popcorn_cli.py"

EOF
