#!/usr/bin/env bash
# Build Blackshield Codex: compile Papyrus (against the first-wave scripts), generate the plugin
# and SEQ file (checked against the vendored first-wave plugins), package the FOMOD.
#
#   ./build.sh                     # everything, archive goes to ./dist
#   ./build.sh -H "<Skyrim>/Data/Source/Scripts"   # type-check against the game's own script sources
#   DIST_DIR=/some/dir ./build.sh
#
# Needs: bash, curl, python3, .NET SDK 9, xmllint (optional, for FOMOD schema validation).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

NAME="BlackshieldCodex"
VERSION="$(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p' CHANGELOG.md | head -1)"
DIST_DIR="${DIST_DIR:-dist}"
KIT="tools/modkit"
BUILD="build"
STAGE="$BUILD/stage"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct 2>/dev/null || echo 315532800)}"

PAPYRUS_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -H) PAPYRUS_ARGS+=(-H "$2"); shift 2 ;;
    --official) PAPYRUS_ARGS+=(--official "$2"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

echo "== $NAME $VERSION"
rm -rf "$STAGE"
mkdir -p "$STAGE/00 Core/Scripts" "$STAGE/10 Papyrus Sources/Source/Scripts" "$DIST_DIR"

echo "== Masters"
(cd masters/plugins && sha256sum -c --quiet ../SHA256SUMS) && echo "[masters] vendored first-wave plugins match masters/SHA256SUMS"

echo "== Papyrus"
"$KIT/papyrus/build-papyrus.sh" -i src/papyrus -o "$STAGE/00 Core/Scripts" -I masters/scripts "${PAPYRUS_ARGS[@]}"
cp src/papyrus/*.psc "$STAGE/10 Papyrus Sources/Source/Scripts/"

echo "== Plugin"
dotnet run --project src/plugin/BlackshieldCodex.Generator -c Release -- \
  --out "$BUILD/plugin" --ids src/plugin/formids.json --papyrus src/papyrus --masters masters/plugins
python3 "$KIT/esp_check.py" "$BUILD/plugin/$NAME.esp"
# plugin + SEQ/
cp -r "$BUILD/plugin/." "$STAGE/00 Core/"

echo "== FOMOD"
ARCHIVE="$DIST_DIR/$NAME-$VERSION.zip"
python3 "$KIT/fomod/pack.py" --fomod fomod --stage "$STAGE" --version "$VERSION" --out "$ARCHIVE"
(cd "$DIST_DIR" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")
echo "== Done: $ARCHIVE"
