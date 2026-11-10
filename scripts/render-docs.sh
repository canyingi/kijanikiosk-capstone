#!/usr/bin/env bash
# Render a Markdown doc to PDF for submission (scope, reflection).
# Usage: scripts/render-docs.sh docs/scope.md   -> docs/scope.pdf
# Needs: pandoc + google-chrome (or chromium). Check the result is ONE page.
set -euo pipefail
SRC="${1:?markdown file required}"; OUT="${SRC%.md}.pdf"; TMP=$(mktemp -d)
CSS="$(cd "$(dirname "$0")" && pwd)/render/doc.css"
pandoc "$SRC" -s --metadata title=doc -c "$CSS" -o "$TMP/doc.html"
python3 - "$TMP/doc.html" <<'PY'
import re,sys; p=sys.argv[1]; s=open(p).read()
s=re.sub(r'<header id="title-block-header">.*?</header>','',s,flags=re.S)
s=re.sub(r'<colgroup>.*?</colgroup>','',s,flags=re.S)
s=re.sub(r'<!--.*?-->','',s,flags=re.S)
open(p,'w').write(s)
PY
CHROME=$(command -v google-chrome || command -v chromium || command -v chromium-browser)
"$CHROME" --headless --no-sandbox --disable-gpu --no-pdf-header-footer --print-to-pdf="$OUT" "file://$TMP/doc.html" 2>/dev/null
echo "wrote $OUT"
