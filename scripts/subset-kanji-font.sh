#!/bin/sh
# Regenerates the Noto Serif JP 900 subset with the kanji in packages/design-tokens/kanji.txt.
# Needs fontTools: `pipx install fonttools` (or a venv). Usage: scripts/subset-kanji-font.sh [pyftsubset]
set -eu
cd "$(dirname "$0")/.."
PYFTSUBSET=${1:-pyftsubset}
URL="https://fonts.gstatic.com/s/notoserifjp/v34/xn71YHs72GKoTvER4Gn3b5eMRtWGkp6o7MjQ2byYPebA.ttf"
OUT=apps/ios/HTSKit/Sources/HTSDesign/Resources/Fonts/NotoSerifJP-Black.ttf
TMP=$(mktemp -d)
curl -sfL -o "$TMP/full.ttf" "$URL"
TEXT=$(grep -v '^#' packages/design-tokens/kanji.txt | tr -d '\n ')
"$PYFTSUBSET" "$TMP/full.ttf" --text="$TEXT" --output-file="$OUT" --layout-features='*' --name-IDs='*' \
  --name-languages='*' --notdef-outline
rm -rf "$TMP"
ls -la "$OUT"
