#!/usr/bin/env bash
set -u

PKG="/home/deck/LocalAIProject/open-webui-venv/lib/python3.12/site-packages/open_webui"
OUT="/tmp/openwebui-diagnostic.txt"

{
    echo "=== OPEN WEBUI MODEL PARAMETER SCHEMA ==="
    python3 - "$PKG/models/models.py" <<'PY'
import re
import sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text()
m = re.search(
    r"^class ModelParams\b.*?(?=^class |\Z)",
    text, re.M | re.S
)
if m:
    print(m.group(0))
else:
    print("ModelParams class not found")
PY

    echo
    echo "=== API RESTRICTION REFERENCES (LIMITED) ==="
    grep -R -n -i -E \
      'API_KEY.*ENDPOINT|ENDPOINT.*RESTRICTION|ALLOWED_ENDPOINTS|endpoint.*restriction' \
      "$PKG" --include='*.py' 2>/dev/null | head -n 60

    echo
    echo "=== MODEL UPDATE FORM FIELDS ==="
    sed -n '242,255p' "$PKG/models/models.py"
    sed -n '1143,1205p' "$PKG/routers/models.py"
} > "$OUT" 2>&1

printf 'Diagnostic saved to: %s\n' "$OUT"
printf 'Lines written: '
wc -l < "$OUT"
