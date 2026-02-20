# Codex App for Linux (Unofficial)


Run OpenAI's Codex desktop app on Linux by extracting and patching the macOS version.

<img width="1915" height="976" alt="image" src="https://github.com/user-attachments/assets/f55dd00b-f301-436b-86ba-21b6683f361c" />

```
╔═══════════════════════════════════════════════════╗
║       Codex Linux Installer (Unofficial)          ║
╚═══════════════════════════════════════════════════╝
```

## Quick Start

1. Download `Codex.dmg` from [OpenAI](https://openai.com/codex)
2. Download `install-codex-linux.sh` from this repo
3. Put both files in the same folder
4. Run:

```bash
chmod +x install-codex-linux.sh
./install-codex-linux.sh
```

5. Launch:

```bash
cd codex-linux
./codex-linux.sh
```

## Build Linux Packages

Build release artifacts (`AppImage` + `tar.gz`):

```bash
./build-codex-linux-release.sh
```

Output directory:

```bash
codex-linux/dist
```

If `electron-builder` is unavailable (for example in offline mode), the build script creates a portable `tar.gz` package as fallback.

Install the latest built package (`AppImage` or portable `tar.gz`) into your user profile:

```bash
./install-codex-linux-appimage.sh
```

Or install a specific file:

```bash
./install-codex-linux-appimage.sh /path/to/Codex-1.0.0-linux-x86_64.AppImage
./install-codex-linux-appimage.sh /path/to/Codex-portable-1.0.0-linux-x86_64.tar.gz
```

## Open Source Notices

Generate a third-party dependencies notice file:

```bash
./generate-open-source-notices.sh
```

This writes `OPEN_SOURCE_NOTICES.md` in the repo root.

## Requirements

- Linux (tested on Ubuntu 22.04+, should work on most distros)
- Node.js 18+ and npm
- ~500MB disk space

## What This Does

The installer:

1. Extracts the DMG using 7zip
2. Unpacks the Electron app's `app.asar` archive
3. Installs Linux-compatible Electron runtime (v40)
4. Rebuilds native modules (`better-sqlite3`, `node-pty`) for Linux
5. Stubs macOS-only modules (`electron-liquid-glass`, `sparkle`)
6. Creates a launcher script

## How It Works

OpenAI's Codex app is built with Electron - a cross-platform framework that bundles Chromium and Node.js. While they only ship a macOS build, the core application is JavaScript/TypeScript that can run on any platform.

The main challenges for Linux:
- **Native modules** compiled for macOS (Mach-O binaries) need rebuilding for Linux (ELF binaries)
- **macOS-specific features** like the Sparkle auto-updater and liquid glass visual effects need to be stubbed

See [PORTING-GUIDE.md](PORTING-GUIDE.md) for the full technical breakdown.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Blank window | Verify `webview/index.html` exists |
| "CLI not found" | Run `npm install -g @openai/codex` |
| Auth issues | Run `codex auth` in terminal first |
| Sandbox errors | Script already uses `--no-sandbox` |
| `better_sqlite3.node` missing / app crashes at startup | Run `cd codex-linux && npm run rebuild:native` |
| `dlopen(): error loading libfuse.so.2` on AppImage | Re-run `./install-codex-linux-appimage.sh` (launcher has no-FUSE fallback) |

## Files

```
├── install-codex-linux.sh           # DMG -> runnable Linux app
├── build-codex-linux-release.sh     # Build AppImage + tar.gz
├── install-codex-linux-appimage.sh  # Install built AppImage/tar.gz
├── generate-open-source-notices.sh  # Generate OSS notices
├── OPEN_SOURCE_NOTICES.md           # Generated dependency notices
└── README.md                        # You are here
```

## Legal

This project provides **instructions only** - no OpenAI code is distributed. Users must obtain `Codex.dmg` directly from OpenAI.

For personal and educational use. Not affiliated with OpenAI.

## Credits

Reverse engineered with curiosity and caffeine.
