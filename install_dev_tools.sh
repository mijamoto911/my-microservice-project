#!/usr/bin/env bash
set -euo pipefail


if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script works only on Ubuntu/Debian (apt)."
  exit 1
fi

# Root privileges required
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Administrator rights required. Running via sudo..."
  exec sudo -E bash "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y

# Install Docker, Python, pip, venv
for pkg in docker.io python3 python3-pip python3-venv; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "$pkg is already installed."
  else
    echo "Installing $pkg..."
    apt-get install -y "$pkg"
  fi
done

# Install Docker Compose v2
if ! docker compose version >/dev/null 2>&1; then
  echo "Installing Docker Compose v2..."
  if ! apt-get install -y docker-compose-plugin >/dev/null 2>&1; then
    ARCH="$(uname -m)"
    case "$ARCH" in
      x86_64|amd64)  COMP_ARCH="x86_64" ;;
      aarch64|arm64) COMP_ARCH="aarch64" ;;
      *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
    esac
    DEST_DIR="/usr/local/lib/docker/cli-plugins"
    mkdir -p "$DEST_DIR"
    curl -fL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${COMP_ARCH}" \
      -o "${DEST_DIR}/docker-compose"
    chmod +x "${DEST_DIR}/docker-compose"
  fi
else
  echo "Docker Compose is already installed."
fi

# Install Django via pip у venv
VENV_DIR="$HOME/.venvs/devtools"
mkdir -p "$HOME/.venvs"
if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/python" -m pip install -U pip setuptools wheel
if ! "$VENV_DIR/bin/python" -m pip show django >/dev/null 2>&1; then
  "$VENV_DIR/bin/python" -m pip install -U django
else
  echo "Django is already installed in venv."
fi

# Versions
echo
echo "=== Versions ==="
python3 --version
python3 -m pip --version
docker --version
docker compose version
"$VENV_DIR/bin/django-admin" --version
echo "================"
echo "[✓] Installation complete."

