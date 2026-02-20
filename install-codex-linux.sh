#!/bin/bash
#
# Codex Linux Installer
# Automatically ports OpenAI Codex macOS app to Linux
#
# Usage: Place Codex.dmg in the same folder as this script, then run:
#   chmod +x install-codex-linux.sh
#   ./install-codex-linux.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

has_module_binding() {
    local module_dir="$1"
    local pattern="$2"
    find "${module_dir}" -type f -name "${pattern}" -print -quit 2>/dev/null | grep -q .
}

verify_native_bindings() {
    local root_dir="$1"
    local ok=0

    if ! has_module_binding "${root_dir}/node_modules/better-sqlite3" "better_sqlite3.node"; then
        warn "Missing native binding: better-sqlite3/better_sqlite3.node"
        ok=1
    fi

    if ! has_module_binding "${root_dir}/node_modules/node-pty" "*.node"; then
        warn "Missing native binding: node-pty/*.node"
        ok=1
    fi

    return "${ok}"
}

find_app_asar() {
    find "$SCRIPT_DIR/codex_extracted" -name "app.asar" -type f 2>/dev/null | head -1 || true
}

extract_dmg_direct() {
    "$SEVEN_ZIP" x "$DMG_FILE" -o"$SCRIPT_DIR/codex_extracted" -y >> "$SCRIPT_DIR/7z_output.log" 2>&1 || true
}

extract_nested_images() {
    local found_nested=0
    while IFS= read -r image_file; do
        found_nested=1
        "$SEVEN_ZIP" x "$image_file" -o"$SCRIPT_DIR/codex_extracted" -y >> "$SCRIPT_DIR/7z_output.log" 2>&1 || true
    done < <(find "$SCRIPT_DIR/codex_extracted" -maxdepth 4 -type f \( -name "*.hfs" -o -name "*.img" -o -name "*.dmg" \) 2>/dev/null || true)

    return $((1 - found_nested))
}

extract_via_dmg2img() {
    if ! command -v dmg2img &>/dev/null; then
        return 1
    fi

    local converted_img
    converted_img="$(mktemp /tmp/codex-dmg2img-XXXXXX.img)"
    if ! dmg2img "$DMG_FILE" "$converted_img" >> "$SCRIPT_DIR/7z_output.log" 2>&1; then
        rm -f "$converted_img"
        return 1
    fi

    "$SEVEN_ZIP" x "$converted_img" -o"$SCRIPT_DIR/codex_extracted" -y >> "$SCRIPT_DIR/7z_output.log" 2>&1 || true
    rm -f "$converted_img"
    return 0
}

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       Codex Linux Installer (Unofficial)          ║${NC}"
echo -e "${CYAN}║   Ports macOS Codex.dmg to run on Linux           ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────────────────────────
# Phase 1: Prerequisites
# ─────────────────────────────────────────────────────────────
log "Checking prerequisites..."

# Check for Codex.dmg
DMG_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -type f \( -name "*.dmg" -o -name "Codex.dmg" \) 2>/dev/null | head -1)
if [ -z "$DMG_FILE" ]; then
    error "Codex.dmg not found. Place it in: $SCRIPT_DIR"
fi
success "Found: $DMG_FILE"

# Check Node.js
if ! command -v node &> /dev/null; then
    error "Node.js not found. Install it first: https://nodejs.org"
fi
success "Node.js: $(node --version)"

# Check npm
if ! command -v npm &> /dev/null; then
    error "npm not found. Install Node.js properly."
fi
success "npm: $(npm --version)"

# ─────────────────────────────────────────────────────────────
# Phase 2: Get 7zip
# ─────────────────────────────────────────────────────────────
log "Setting up extraction tools..."

if command -v 7z &> /dev/null; then
    SEVEN_ZIP="7z"
elif command -v 7zz &> /dev/null; then
    SEVEN_ZIP="7zz"
elif [ -f "/tmp/7zz" ]; then
    SEVEN_ZIP="/tmp/7zz"
else
    log "Downloading portable 7zip..."
    curl -sL https://www.7-zip.org/a/7z2408-linux-x64.tar.xz -o /tmp/7z.tar.xz
    tar -xf /tmp/7z.tar.xz -C /tmp/
    SEVEN_ZIP="/tmp/7zz"
fi
success "7zip ready: $SEVEN_ZIP"

# ─────────────────────────────────────────────────────────────
# Phase 3: Extract DMG
# ─────────────────────────────────────────────────────────────
log "Extracting DMG (this may take a moment)..."

rm -rf "$SCRIPT_DIR/codex_extracted" 2>/dev/null || true
mkdir -p "$SCRIPT_DIR/codex_extracted"
: > "$SCRIPT_DIR/7z_output.log"

# Method 1: direct extraction
extract_dmg_direct
ASAR_PATH="$(find_app_asar)"

# Method 2: nested image extraction from direct output
if [ -z "$ASAR_PATH" ]; then
    warn "Direct extraction did not expose app.asar, trying nested image extraction..."
    extract_nested_images || true
    ASAR_PATH="$(find_app_asar)"
fi

# Method 3: dmg2img fallback (for some DMG layouts)
if [ -z "$ASAR_PATH" ]; then
    warn "Trying dmg2img fallback extraction..."
    rm -rf "$SCRIPT_DIR/codex_extracted" 2>/dev/null || true
    mkdir -p "$SCRIPT_DIR/codex_extracted"
    extract_via_dmg2img || true
    ASAR_PATH="$(find_app_asar)"
fi

if [ -z "$ASAR_PATH" ]; then
    warn "7z log tail:"
    tail -n 80 "$SCRIPT_DIR/7z_output.log" || true
    log "Contents of extracted folder:"
    find "$SCRIPT_DIR/codex_extracted" -maxdepth 4 -type d 2>/dev/null | head -20
    error "app.asar not found. Is this a valid Codex DMG?"
fi
success "Extracted DMG, found: $ASAR_PATH"

# ─────────────────────────────────────────────────────────────
# Phase 4: Extract ASAR
# ─────────────────────────────────────────────────────────────
log "Installing asar tool..."
if ! npm list -g @electron/asar &>/dev/null; then
    if ! sudo npm install -g @electron/asar; then
        warn "Global install failed, trying local..."
        npm install @electron/asar || error "Failed to install @electron/asar"
    fi
fi
success "asar tool ready"

log "Extracting application source..."
rm -rf "$SCRIPT_DIR/codex_app_src" 2>/dev/null || true
if ! npx @electron/asar extract "$ASAR_PATH" "$SCRIPT_DIR/codex_app_src"; then
    error "Failed to extract app.asar"
fi
success "Application source extracted"

# ─────────────────────────────────────────────────────────────
# Phase 5: Setup Linux Project
# ─────────────────────────────────────────────────────────────
log "Setting up Linux project structure..."

PROJECT_DIR="$SCRIPT_DIR/codex-linux"
rm -rf "$PROJECT_DIR" 2>/dev/null || true
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Copy source files
if [ ! -d "$SCRIPT_DIR/codex_app_src/.vite" ]; then
    error ".vite folder not found in extracted source"
fi
cp -r "$SCRIPT_DIR/codex_app_src/.vite" ./

if [ -d "$SCRIPT_DIR/codex_app_src/webview" ]; then
    cp -r "$SCRIPT_DIR/codex_app_src/webview" ./
else
    warn "webview not at root, searching..."
    WEBVIEW_PATH=$(find "$SCRIPT_DIR/codex_app_src" -type d -name "webview" 2>/dev/null | head -1)
    if [ -n "$WEBVIEW_PATH" ]; then
        cp -r "$WEBVIEW_PATH" ./
    else
        error "webview folder not found"
    fi
fi

cp -r "$SCRIPT_DIR/codex_app_src/native" ./ 2>/dev/null || mkdir -p native

success "Source files copied"

# ─────────────────────────────────────────────────────────────
# Phase 6: Install Dependencies
# ─────────────────────────────────────────────────────────────
log "Creating package.json..."

cat > package.json << 'PKGJSON'
{
  "name": "codex-linux",
  "productName": "Codex",
  "version": "1.0.0-linux",
  "main": ".vite/build/main.js",
  "scripts": {
    "start": "electron .",
    "start:debug": "electron . --enable-logging",
    "rebuild:native": "electron-rebuild -f -w better-sqlite3,node-pty"
  },
  "dependencies": {
    "better-sqlite3": "^12.4.6",
    "node-pty": "^1.1.0",
    "immer": "^10.1.1",
    "lodash": "^4.17.21",
    "memoizee": "^0.4.15",
    "mime-types": "^2.1.35",
    "shell-env": "^4.0.1",
    "shlex": "^3.0.0",
    "smol-toml": "^1.5.2",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "electron": "40.0.0",
    "@electron/rebuild": "^3.6.0"
  }
}
PKGJSON

log "Installing npm dependencies (this takes a few minutes)..."
if ! npm install; then
    error "npm install failed"
fi
success "Dependencies installed"

# ─────────────────────────────────────────────────────────────
# Phase 7: Rebuild Native Modules
# ─────────────────────────────────────────────────────────────
log "Rebuilding native modules for Electron..."
if ! npm run rebuild:native; then
    error "Native rebuild failed. Check network/build toolchain and rerun installer."
fi

if ! verify_native_bindings "$PROJECT_DIR"; then
    error "Native bindings are missing after rebuild. Installation aborted."
fi
success "Native modules rebuilt for Linux"

# ─────────────────────────────────────────────────────────────
# Phase 8: Stub macOS-only Modules
# ─────────────────────────────────────────────────────────────
log "Patching macOS-only modules..."

# Remove sparkle.node
rm -f native/sparkle.node 2>/dev/null || true

# Create electron-liquid-glass stub
mkdir -p node_modules/electron-liquid-glass

cat > node_modules/electron-liquid-glass/index.js << 'STUBJS'
const stub = {
  isGlassSupported: () => false,
  enable: () => {},
  disable: () => {},
  setOptions: () => {}
};
module.exports = stub;
module.exports.default = stub;
STUBJS

cat > node_modules/electron-liquid-glass/package.json << 'STUBPKG'
{"name":"electron-liquid-glass","version":"1.0.0","main":"index.js"}
STUBPKG

success "macOS modules stubbed"

# ─────────────────────────────────────────────────────────────
# Phase 9: Create Launcher
# ─────────────────────────────────────────────────────────────
log "Creating launcher script..."

cat > codex-linux.sh << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export ELECTRON_RENDERER_URL="file://${SCRIPT_DIR}/webview/index.html"
export CODEX_CLI_PATH="${CODEX_CLI_PATH:-$(which codex 2>/dev/null || echo /usr/local/bin/codex)}"

exec ./node_modules/.bin/electron . --no-sandbox "$@"
LAUNCHER

chmod +x codex-linux.sh
success "Launcher created"

# ─────────────────────────────────────────────────────────────
# Phase 10: Check for Codex CLI
# ─────────────────────────────────────────────────────────────
if ! command -v codex &> /dev/null; then
    warn "Codex CLI not found. Installing..."
    npm install -g @openai/codex > /dev/null 2>&1 || {
        warn "Could not install Codex CLI globally. You may need to run:"
        echo "    npm install -g @openai/codex"
    }
else
    success "Codex CLI found: $(which codex)"
fi

# ─────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────
log "Cleaning up temporary files..."
rm -rf "$SCRIPT_DIR/codex_extracted" 2>/dev/null || true
rm -rf "$SCRIPT_DIR/codex_app_src" 2>/dev/null || true
rm -f "$SCRIPT_DIR/7z_output.log" 2>/dev/null || true
success "Cleanup complete"

# ─────────────────────────────────────────────────────────────
# Done!
# ─────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Installation Complete!                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}To launch Codex:${NC}"
echo ""
echo "    cd $PROJECT_DIR"
echo "    ./codex-linux.sh"
echo ""
echo -e "  ${YELLOW}Note:${NC} If you haven't authenticated, run 'codex auth' first."
echo ""
