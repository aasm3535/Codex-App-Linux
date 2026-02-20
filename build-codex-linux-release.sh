#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/codex-linux"
DIST_DIR="${APP_DIR}/dist"

has_module_binding() {
  local module_dir="$1"
  local pattern="$2"
  find "${module_dir}" -type f -name "${pattern}" -print -quit 2>/dev/null | grep -q .
}

verify_native_bindings() {
  local ok=0

  if ! has_module_binding "${APP_DIR}/node_modules/better-sqlite3" "better_sqlite3.node"; then
    echo "[!] Missing native binding: better-sqlite3/better_sqlite3.node"
    ok=1
  fi

  if ! has_module_binding "${APP_DIR}/node_modules/node-pty" "*.node"; then
    echo "[!] Missing native binding: node-pty/*.node"
    ok=1
  fi

  return "${ok}"
}

build_portable_tarball() {
  local version arch outfile tmpfile
  version="$(node -p "require('./package.json').version")"
  arch="$(uname -m)"
  mkdir -p "${DIST_DIR}"
  outfile="${DIST_DIR}/Codex-portable-${version}-${arch}.tar.gz"
  tmpfile="$(mktemp "/tmp/codex-portable-${version}-${arch}-XXXXXX.tar.gz")"

  echo "[*] Building portable tar.gz..."
  tar \
    --exclude='./codex-linux/dist' \
    --exclude='./codex-linux/.git' \
    --exclude='./codex-linux/*.log' \
    -czf "${tmpfile}" \
    -C "${SCRIPT_DIR}" \
    codex-linux

  mv -f "${tmpfile}" "${outfile}"

  echo "[✓] Portable artifact: ${outfile}"
}

if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm is required."
  exit 1
fi

if [ ! -d "${APP_DIR}" ]; then
  echo "Error: app directory not found: ${APP_DIR}"
  exit 1
fi

cd "${APP_DIR}"

if [ ! -d node_modules ]; then
  echo "[*] Installing dependencies..."
  npm install
fi

if [ "${SKIP_REBUILD:-0}" != "1" ]; then
  echo "[*] Rebuilding native modules for Electron..."
  if ! npm run rebuild:native; then
    echo "[!] Native rebuild failed."
  fi
fi

if ! verify_native_bindings; then
  echo ""
  echo "Error: required native modules are missing."
  echo "Fix:"
  echo "  1) Ensure internet access (for Electron headers/downloads)"
  echo "  2) Run: cd codex-linux && npm run rebuild:native"
  echo "  3) Re-run: ./build-codex-linux-release.sh"
  exit 1
fi

if [ -x "${APP_DIR}/node_modules/.bin/electron-builder" ]; then
  echo "[*] Building AppImage with electron-builder..."
  npm run build:appimage
  build_portable_tarball
else
  echo "[!] electron-builder not found in node_modules."
  echo "[!] AppImage build skipped."
  build_portable_tarball
fi

echo ""
echo "[✓] Build complete."
echo "Artifacts are in: ${APP_DIR}/dist"
