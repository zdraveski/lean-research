#!/bin/bash
# Exit 0 when bash, curl, Moli and Obscura are installed; else print where to get each missing one, exit 1.
have() { command -v "$1" >/dev/null || command -v "$1.exe" >/dev/null; }
case $(uname -s) in
  Linux)  os=linux;   arch=$(uname -m); [ "$arch" = aarch64 ] || arch=x86_64; asset="obscura-$arch-linux-stealth.tar.gz" ;;
  Darwin) os=macos;   arch=$(uname -m); [ "$arch" = arm64 ] && arch=aarch64; asset="obscura-$arch-macos-stealth.tar.gz" ;;
  MINGW*|MSYS*) os=windows; asset="obscura-x86_64-windows-stealth.zip" ;;
  *) os=other; asset="the stealth build for your system" ;;
esac
rel=https://github.com/h4ckf0r0day/obscura/releases/latest/download
rc=0
miss() { echo "missing: $1 ($2)"; shift 2; printf '  %s\n' "$@"; rc=1; }

have curl || miss curl "https://curl.se/" "install curl with your package manager"
if ! have moli; then
  if [ "$os" = windows ]; then
    cmd='powershell -ExecutionPolicy ByPass -c "irm https://github.com/lexmount/moli/releases/latest/download/moli-installer.ps1 | iex"'
  else
    cmd="curl --proto '=https' --tlsv1.2 -fsSL https://github.com/lexmount/moli/releases/latest/download/moli-installer.sh | sh"
  fi
  miss moli https://github.com/lexmount/moli "$cmd"
fi
if ! have obscura; then
  # Obscura has no signal that tells a stealth build from a plain one, so the asset name is the check.
  case $os in
    windows) cmd="curl -fsSLO $rel/$asset, then unzip it and put obscura.exe on PATH" ;;
    macos)   cmd="curl -fsSL $rel/$asset | tar xz, then: xattr -d com.apple.quarantine obscura; and put obscura on PATH" ;;
    *)       cmd="curl -fsSL $rel/$asset | tar xz, then put obscura on PATH" ;;
  esac
  miss obscura https://github.com/h4ckf0r0day/obscura "download the STEALTH build ($asset)" "$cmd"
fi
if ! have pdftotext; then
  echo "note: pdftotext not found, PDFs will be skipped"
  echo "  install poppler: apt install poppler-utils | brew install poppler | pacman -S mingw-w64-x86_64-poppler"
fi
exit $rc
