#!/usr/bin/env bash
# Compile Papyrus (.psc) to .pex for Skyrim SE/AE.
#
# Default: the open-source compiler by russo-2025 (MIT, native Linux build),
# type-checking against this kit's clean-room API stubs. Pass -H with your
# game's own script sources (Data/Source/Scripts, unpacked from Scripts.zip)
# to check against the real vanilla declarations instead.
#
# --official compiles with Bethesda's PapyrusCompiler.exe from the Creation Kit
# through Wine/Proton (needs the CK installed; see tools/modkit/README.md).
#
# -I adds an extra import directory on top of the headers, for scripts that call
# into another mod's scripts (its sources are type-checked but not compiled).
#
# Usage: build-papyrus.sh -i <src dir> -o <out dir> [-H <headers dir>]... [-I <import dir>]... [--official <CK dir>]
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILER_TAG="2026.03.15"
COMPILER_SHA256="d5e72c393ef85a3cd4f839b5bbda52b08bfb358832c36686043e61f5408f736e"
COMPILER_URL="https://github.com/russo-2025/papyrus-compiler/releases/download/${COMPILER_TAG}/papyrus-compiler-ubuntu.tar.gz"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/skyrim-modkit/papyrus-compiler/${COMPILER_TAG}"

SRC=""; OUT=""; HEADERS=(); IMPORTS=(); OFFICIAL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i) SRC="$2"; shift 2 ;;
    -o) OUT="$2"; shift 2 ;;
    -H) HEADERS+=("$2"); shift 2 ;;
    -I) IMPORTS+=("$(cd "$2" && pwd)"); shift 2 ;;
    --official) OFFICIAL="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$SRC" && -n "$OUT" ]] || { echo "usage: $0 -i <src> -o <out> [-H <headers>]" >&2; exit 2; }
mkdir -p "$OUT"
SRC="$(cd "$SRC" && pwd)"; OUT="$(cd "$OUT" && pwd)"
[[ ${#HEADERS[@]} -gt 0 ]] || HEADERS=("$KIT_DIR/papyrus-stubs")
HEADERS+=("${IMPORTS[@]}")

if [[ -n "$OFFICIAL" ]]; then
  # Bethesda compiler via Wine/Proton. CK layout: <CK dir>/Papyrus Compiler/PapyrusCompiler.exe
  exe="$OFFICIAL/Papyrus Compiler/PapyrusCompiler.exe"
  flags="$OFFICIAL/Data/Source/Scripts/TESV_Papyrus_Flags.flg"
  [[ -f "$exe" ]] || { echo "PapyrusCompiler.exe not found at: $exe" >&2; exit 1; }
  imports="$(winepath -w "$SRC")"
  for h in "${HEADERS[@]}"; do imports+=";$(winepath -w "$h")"; done
  wine "$exe" "$(winepath -w "$SRC")" -all -q -f="$(winepath -w "$flags")" -i="$imports" -o="$(winepath -w "$OUT")"
else
  compiler="${PAPYRUS_COMPILER:-$CACHE_DIR/papyrus-compiler/papyrus}"
  if [[ ! -x "$compiler" ]]; then
    echo "[papyrus] fetching open-source compiler ${COMPILER_TAG}"
    mkdir -p "$CACHE_DIR"
    curl -fsSL "$COMPILER_URL" -o "$CACHE_DIR/compiler.tar.gz"
    echo "${COMPILER_SHA256}  $CACHE_DIR/compiler.tar.gz" | sha256sum -c --quiet -
    tar xzf "$CACHE_DIR/compiler.tar.gz" -C "$CACHE_DIR"
    chmod +x "$compiler"
  fi
  hargs=(); for h in "${HEADERS[@]}"; do hargs+=(-h "$h"); done
  rm -f "$OUT"/*.pex
  log="$(mktemp)"
  if ! "$compiler" compile -nocache "${hargs[@]}" -i "$SRC" -o "$OUT" >"$log" 2>&1; then
    grep -vE '^(parse|check|gen|finish|used header)' "$log" >&2; rm -f "$log"
    echo "[papyrus] compilation failed" >&2; exit 1
  fi
  rm -f "$log"
  for psc in "$SRC"/*.psc; do
    n="$(basename "${psc%.psc}")"
    [[ -f "$OUT/$n.pex" ]] || { echo "[papyrus] FAILED: $n.pex was not produced" >&2; exit 1; }
  done
fi

python3 "$KIT_DIR/papyrus/pex_normalize.py" "$OUT"/*.pex
echo "[papyrus] $(ls "$OUT"/*.pex | wc -l) script(s) compiled to $OUT"
