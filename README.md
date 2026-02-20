# Codex App for Linux (Unofficial)

Run OpenAI Codex Desktop on Linux with an AppImage release or local build scripts.

## Install From Releases (Recommended)

1. Open the releases page: `https://github.com/aasm3535/Codex-App-Linux/releases`
2. Download:
   - `Codex-*-x86_64.AppImage` (recommended), or
   - `Codex-portable-*.tar.gz`
3. Install the package with:

```bash
chmod +x install-codex-linux-appimage.sh
./install-codex-linux-appimage.sh /path/to/Codex-1.0.0-linux-x86_64.AppImage
```

4. Run:

```bash
codex-linux
```

Notes:
- The launcher includes a no-FUSE fallback. If `libfuse.so.2` is missing, it auto-extracts and runs the AppImage.
- Desktop entry is created at `~/.local/share/applications/codex-linux.desktop`.

## Build Release Artifacts Locally

From repository root:

```bash
./build-codex-linux-release.sh
```

Output:

```bash
codex-linux/dist/Codex-1.0.0-linux-x86_64.AppImage
codex-linux/dist/Codex-portable-1.0.0-linux-x86_64.tar.gz
```

## Port From Codex.dmg (Generate Linux Project)

If you want to rebuild the Linux project from the original macOS package:

1. Download `Codex.dmg` from OpenAI.
2. Place `Codex.dmg` next to `install-codex-linux.sh`.
3. Run:

```bash
chmod +x install-codex-linux.sh
./install-codex-linux.sh
```

4. Launch local unpacked app:

```bash
cd codex-linux
./codex-linux.sh
```

## Open Source Notices

Generate third-party notices:

```bash
./generate-open-source-notices.sh
```

This writes `OPEN_SOURCE_NOTICES.md` in the repository root.

## Troubleshooting

| Issue | Fix |
|---|---|
| `dlopen(): error loading libfuse.so.2` | Re-run `./install-codex-linux-appimage.sh` (launcher has no-FUSE fallback). |
| `better_sqlite3.node` missing / startup crash | Run `cd codex-linux && npm run rebuild:native` and rebuild package. |
| `Unable to locate the Codex CLI binary` | Ensure `codex` is installed and available in `PATH` (`npm i -g @openai/codex`). |
| Blank window | Verify `webview/index.html` exists in unpacked project. |

## Repository Files

```text
install-codex-linux.sh             # DMG -> runnable Linux app
build-codex-linux-release.sh       # Build AppImage + portable tar.gz
install-codex-linux-appimage.sh    # Install AppImage/tar.gz into ~/.local
generate-open-source-notices.sh    # Generate OSS notices
OPEN_SOURCE_NOTICES.md             # Generated dependency notices
```

## Legal

This repository does not redistribute OpenAI proprietary app code. Users must obtain `Codex.dmg` from OpenAI directly.
