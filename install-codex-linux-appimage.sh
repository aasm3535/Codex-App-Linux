#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/codex-linux/dist"
PACKAGE_INPUT="${1:-}"

if [ -z "${PACKAGE_INPUT}" ]; then
  PACKAGE_INPUT="$(ls -1t "${DIST_DIR}"/*.AppImage "${DIST_DIR}"/*.tar.gz 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${PACKAGE_INPUT}" ] || [ ! -f "${PACKAGE_INPUT}" ]; then
  echo "Error: package not found."
  echo "Usage: $0 /path/to/Codex-*.AppImage"
  echo "   or: $0 /path/to/Codex-portable-*.tar.gz"
  exit 1
fi

APP_NAME="codex-linux"
XDG_DATA_HOME_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}"
APPIMAGE_INSTALL_DIR="${XDG_DATA_HOME_DIR}/codex-linux"
PORTABLE_INSTALL_DIR="${HOME}/.local/opt/codex-linux"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${XDG_DATA_HOME_DIR}/applications"
ICON_DIR="${XDG_DATA_HOME_DIR}/icons/hicolor/256x256/apps"
ICON_TARGET="${ICON_DIR}/${APP_NAME}.png"
LAUNCHER_PATH="${BIN_DIR}/${APP_NAME}"
DESKTOP_PATH="${DESKTOP_DIR}/${APP_NAME}.desktop"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

has_module_binding() {
  local module_dir="$1"
  local pattern="$2"
  find "${module_dir}" -type f -name "${pattern}" -print -quit 2>/dev/null | grep -q .
}

verify_portable_native_bindings() {
  local root_dir="$1"
  local ok=0

  if ! has_module_binding "${root_dir}/node_modules/better-sqlite3" "better_sqlite3.node"; then
    echo "[!] Missing better-sqlite3 native binding."
    ok=1
  fi

  if ! has_module_binding "${root_dir}/node_modules/node-pty" "*.node"; then
    echo "[!] Missing node-pty native binding."
    ok=1
  fi

  return "${ok}"
}

repair_portable_native_bindings() {
  local root_dir="$1"

  if ! command -v npm >/dev/null 2>&1; then
    return 1
  fi

  if [ ! -x "${root_dir}/node_modules/.bin/electron-rebuild" ]; then
    return 1
  fi

  echo "[*] Attempting to repair native modules..."
  (
    cd "${root_dir}"
    npm run rebuild:native
  )
}

mkdir -p "${BIN_DIR}" "${DESKTOP_DIR}" "${ICON_DIR}" "${APPIMAGE_INSTALL_DIR}" "${PORTABLE_INSTALL_DIR}"

install_appimage() {
  local appimage_target="${APPIMAGE_INSTALL_DIR}/Codex.AppImage"

  echo "[*] Installing AppImage..."
  cp "${PACKAGE_INPUT}" "${appimage_target}"
  chmod +x "${appimage_target}"

  echo "[*] Extracting icon from AppImage..."
  (
    cd "${TMP_DIR}"
    "${appimage_target}" --appimage-extract .DirIcon >/dev/null 2>&1 || true
    if [ -f "${TMP_DIR}/squashfs-root/.DirIcon" ]; then
      cp "${TMP_DIR}/squashfs-root/.DirIcon" "${ICON_TARGET}"
    fi
  )

  echo "[*] Creating launcher..."
  cat > "${LAUNCHER_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

APPIMAGE_PATH="${appimage_target}"
APPIMAGE_HOME="${APPIMAGE_INSTALL_DIR}"
EXTRACTED_ROOT="${APPIMAGE_INSTALL_DIR}/squashfs-root"

if [ -z "\${CODEX_CLI_PATH:-}" ]; then
  CODEX_CLI_PATH="\$(command -v codex 2>/dev/null || true)"
  if [ -z "\${CODEX_CLI_PATH}" ] && [ -x "/usr/local/bin/codex" ]; then
    CODEX_CLI_PATH="/usr/local/bin/codex"
  fi
  if [ -n "\${CODEX_CLI_PATH}" ]; then
    export CODEX_CLI_PATH
  fi
fi

has_fuse2() {
  if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -q 'libfuse\\.so\\.2'; then
    return 0
  fi

  for candidate in \
    /lib/libfuse.so.2 \
    /usr/lib/libfuse.so.2 \
    /lib64/libfuse.so.2 \
    /usr/lib64/libfuse.so.2 \
    /lib/x86_64-linux-gnu/libfuse.so.2 \
    /usr/lib/x86_64-linux-gnu/libfuse.so.2; do
    if [ -e "\${candidate}" ]; then
      return 0
    fi
  done

  return 1
}

run_extracted() {
  if [ ! -x "\${EXTRACTED_ROOT}/AppRun" ] || [ "\${APPIMAGE_PATH}" -nt "\${EXTRACTED_ROOT}/AppRun" ]; then
    tmp_extract_dir="\$(mktemp -d "\${APPIMAGE_HOME}/.extract-XXXXXX")"
    (
      cd "\${tmp_extract_dir}"
      "\${APPIMAGE_PATH}" --appimage-extract >/dev/null
    )
    rm -rf "\${EXTRACTED_ROOT}"
    mv "\${tmp_extract_dir}/squashfs-root" "\${EXTRACTED_ROOT}"
    rm -rf "\${tmp_extract_dir}"
  fi

  APPDIR="\${EXTRACTED_ROOT}" APPIMAGE="\${APPIMAGE_PATH}" exec "\${EXTRACTED_ROOT}/AppRun" --no-sandbox "\$@"
}

if has_fuse2; then
  exec "\${APPIMAGE_PATH}" --no-sandbox "\$@"
else
  run_extracted "\$@"
fi
EOF
  chmod +x "${LAUNCHER_PATH}"
}

install_portable_tarball() {
  local extract_dir="${TMP_DIR}/extract"
  local root_dir portable_launcher fallback_icon

  echo "[*] Installing portable tar.gz..."
  mkdir -p "${extract_dir}"
  tar -xzf "${PACKAGE_INPUT}" -C "${extract_dir}"
  root_dir="$(find "${extract_dir}" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"

  if [ -z "${root_dir}" ]; then
    echo "Error: unexpected tar.gz layout."
    exit 1
  fi

  if ! verify_portable_native_bindings "${root_dir}"; then
    if ! repair_portable_native_bindings "${root_dir}"; then
      echo "Error: portable package is missing required native modules."
      echo "Run manually after fixing network/build deps:"
      echo "  cd ${root_dir} && npm run rebuild:native"
      exit 1
    fi

    if ! verify_portable_native_bindings "${root_dir}"; then
      echo "Error: native module repair failed."
      echo "Run manually for logs:"
      echo "  cd ${root_dir} && npm run rebuild:native"
      exit 1
    fi
  fi

  rm -rf "${PORTABLE_INSTALL_DIR}"
  mkdir -p "${PORTABLE_INSTALL_DIR}"
  cp -a "${root_dir}/." "${PORTABLE_INSTALL_DIR}/"

  portable_launcher="${PORTABLE_INSTALL_DIR}/codex-linux.sh"
  if [ ! -f "${portable_launcher}" ]; then
    echo "Error: codex-linux.sh not found in portable package."
    exit 1
  fi

  fallback_icon="$(find "${PORTABLE_INSTALL_DIR}/webview/assets" -maxdepth 1 -type f -name 'app-*.png' | head -n 1 || true)"
  if [ -n "${fallback_icon}" ] && [ -f "${fallback_icon}" ]; then
    cp "${fallback_icon}" "${ICON_TARGET}"
  fi

  echo "[*] Creating launcher..."
  cat > "${LAUNCHER_PATH}" <<EOF
#!/usr/bin/env bash
exec "${portable_launcher}" "\$@"
EOF
  chmod +x "${LAUNCHER_PATH}"
}

case "${PACKAGE_INPUT}" in
  *.AppImage)
    install_appimage
    ;;
  *.tar.gz)
    install_portable_tarball
    ;;
  *)
    echo "Error: unsupported package format: ${PACKAGE_INPUT}"
    exit 1
    ;;
esac

echo "[*] Creating desktop entry..."
cat > "${DESKTOP_PATH}" <<EOF
[Desktop Entry]
Name=Codex
Comment=Codex for Linux
Exec=${LAUNCHER_PATH}
Terminal=false
Type=Application
Categories=Development;
Icon=${APP_NAME}
StartupWMClass=Codex
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${DESKTOP_DIR}" >/dev/null 2>&1 || true
fi

echo ""
echo "[✓] Installed."
echo "Run with: ${APP_NAME}"
