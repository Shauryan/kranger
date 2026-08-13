cat > ~/fix-kranger-v5.sh <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

PROJECT="$HOME/projects/kranger"

echo "=========================================="
echo "       󰒋 KRANGER V5 REPAIR"
echo "=========================================="
echo

cd "$PROJECT"

echo "🔧 Fixing ui.Icon → string..."

python3 - <<'PY'
from pathlib import Path

p = Path("internal/render/compact_model.go")
s = p.read_text()

old = 'icon = g.Nodes[0].Icon'
new = 'icon = string(g.Nodes[0].Icon)'

if old in s:
    s = s.replace(old, new)
    p.write_text(s)
    print("✅ Icon conversion fixed")
elif new in s:
    print("🟢 Icon conversion already fixed")
else:
    print("❌ Could not find Icon assignment")
    raise SystemExit(1)
PY

echo
echo "🔧 Fixing CompactGroup type..."

python3 - <<'PY'
from pathlib import Path

p = Path("internal/render/compact.go")
s = p.read_text()

old = 'group *ResourceGroup'
new = 'group *CompactGroup'

if old in s:
    s = s.replace(old, new)
    p.write_text(s)
    print("✅ ResourceGroup → CompactGroup fixed")
elif new in s:
    print("🟢 CompactGroup type already fixed")
else:
    print("❌ Could not find DrawCompactGroup type")
    raise SystemExit(1)
PY

echo
echo "🔍 Verifying source..."

if grep -q 'icon = g.Nodes\[0\]\.Icon' \
    internal/render/compact_model.go; then

    echo "❌ Old Icon assignment still exists"
    exit 1
fi

if grep -q 'group \*ResourceGroup' \
    internal/render/compact.go; then

    echo "❌ Old ResourceGroup type still exists"
    exit 1
fi

echo "✅ Source verification passed"

echo
echo "🎨 Formatting..."

gofmt -w \
    internal/render/*.go \
    main.go

echo "✅ Formatting complete"

echo
echo "🧪 Running tests..."

if ! go test ./...; then
    echo
    echo "❌ Tests failed"
    echo
    echo "Relevant definitions:"
    grep -R "func DrawCompactGroup" -A5 \
        internal/render/ || true
    echo
    grep -n "icon =" \
        internal/render/compact_model.go || true
    exit 1
fi

echo
echo "🔨 Building..."

if ! go build -o kranger .; then
    echo "❌ Build failed"
    exit 1
fi

echo
echo "=========================================="
echo "       ✅ KRANGER V5 REPAIR COMPLETE"
echo "=========================================="
echo
echo "Binary:"
ls -lh kranger
echo
echo "Run:"
echo "  cd ~/projects/kranger"
echo "  ./kranger"
echo
EOF

chmod +x ~/fix-kranger-v5.sh

~/fix-kranger-v5.sh
