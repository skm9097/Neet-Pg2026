#!/usr/bin/env bash
# Cross-compiles the Windows installer from Linux.
# Requires: rustup target x86_64-pc-windows-msvc, cargo-xwin, clang/lld-link, nsis.
set -euo pipefail
cd "$(dirname "$0")"

npm run build
npx tauri build --runner cargo-xwin --target x86_64-pc-windows-msvc --bundles nsis "$@"

echo
echo "Installer: src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis/"
ls -lh src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis/ 2>/dev/null || true
