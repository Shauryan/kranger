#!/usr/bin/env bash
#
# fix-kranger-ghost-edges.sh
#
# Fixes the "ghost edge" rendering bug in kranger's compact renderer.
#
# ROOT CAUSE:
#   RenderCompact() in internal/render/compact_renderer.go draws edges
#   TWICE using two unrelated coordinate systems:
#
#     1. DrawCompactRelations(...)  -- correct, uses compact layout coords
#     2. for _, edge := range g.Edges { DrawEdge(canvas, edge) }
#                                    -- stale, uses the old full/lane-based
#                                       layout from internal/graph/layout.go
#
#   Both get drawn on the same canvas, producing doubled vertical lines,
#   edges that overshoot box borders, and a Node box that looks
#   disconnected from the topology.
#
# FIX:
#   Remove loop #2. DrawCompactRelations already covers every relationship
#   the compact renderer needs, including the dedicated Pod -> Node
#   runtime spine (drawRuntimeToNode).
#
# SAFETY:
#   - Only edits internal/render/compact_renderer.go
#   - Refuses to proceed if the expected block isn't found verbatim
#     (i.e. if the file has since changed), rather than guessing
#   - Makes a timestamped backup before editing
#   - Rebuilds and reports pass/fail; does NOT overwrite the old binary
#     if the build fails
#
# USAGE:
#   cd ~/projects/kranger
#   ./fix-kranger-ghost-edges.sh
#
set -euo pipefail

PROJECT_ROOT="${1:-$HOME/projects/kranger}"
TARGET_FILE="$PROJECT_ROOT/internal/render/compact_renderer.go"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="${TARGET_FILE}.bak-ghost-edge-fix-${TIMESTAMP}"

echo "== kranger ghost-edge fix =="
echo "Project root: $PROJECT_ROOT"
echo

if [[ ! -f "$TARGET_FILE" ]]; then
    echo "ERROR: $TARGET_FILE not found." >&2
    echo "Pass the project root explicitly if it lives elsewhere:" >&2
    echo "  ./fix-kranger-ghost-edges.sh /path/to/kranger" >&2
    exit 1
fi

# --------------------------------------------------------------------
# Locate the exact block to remove. We match on unique anchor lines
# rather than assuming exact whitespace, so this is a little more
# robust to minor formatting drift than a hardcoded diff.
# --------------------------------------------------------------------

python3 - "$TARGET_FILE" "$BACKUP_FILE" <<'PYEOF'
import re
import sys
import shutil

target_file, backup_file = sys.argv[1], sys.argv[2]

with open(target_file, "r") as f:
    content = f.read()

# Anchor pattern: the stale loop that draws g.Edges via DrawEdge.
# Matches regardless of minor whitespace differences.
pattern = re.compile(
    r"[ \t]*//\s*Important graph relationships\.\s*\n"
    r"[ \t]*//\s*\n"
    r"[ \t]*//\s*contains is represented by the namespace\s*\n"
    r"[ \t]*//\s*boundary and therefore isn't drawn\.\s*\n"
    r"[ \t]*for _, edge := range g\.Edges \{\s*\n"
    r"(?:.*\n)*?"
    r"[ \t]*DrawEdge\(\s*\n"
    r"[ \t]*canvas,\s*\n"
    r"[ \t]*edge,\s*\n"
    r"[ \t]*\)\s*\n"
    r"[ \t]*\}\s*\n",
    re.MULTILINE,
)

match = pattern.search(content)

if not match:
    print("ERROR: Could not find the expected ghost-edge block in")
    print(f"  {target_file}")
    print()
    print("This means the file has already changed (maybe you already")
    print("fixed this, or a different patch touched it). Refusing to")
    print("guess -- no changes made. Open the file and check manually")
    print("for a loop like:")
    print()
    print("    for _, edge := range g.Edges {")
    print("        if edge.Relation == \"contains\" {")
    print("            continue")
    print("        }")
    print("        DrawEdge(canvas, edge)")
    print("    }")
    sys.exit(2)

# Back up before touching anything.
shutil.copy2(target_file, backup_file)
print(f"Backed up original to:\n  {backup_file}")

new_content = content[: match.start()] + content[match.end():]

with open(target_file, "w") as f:
    f.write(new_content)

print(f"Removed the stale edge-drawing loop from:\n  {target_file}")
PYEOF

PYTHON_STATUS=$?

if [[ $PYTHON_STATUS -ne 0 ]]; then
    exit $PYTHON_STATUS
fi

echo
echo "== Rebuilding =="
cd "$PROJECT_ROOT"

if go build -o kranger.new .; then
    mv kranger.new kranger
    echo "Build succeeded. kranger has been updated in place."
    echo
    echo "Run it with:"
    echo "  ./kranger"
else
    echo
    echo "ERROR: go build failed after the edit." >&2
    echo "The source change is still in place; restore the backup with:" >&2
    echo "  cp \"$BACKUP_FILE\" \"$TARGET_FILE\"" >&2
    rm -f kranger.new
    exit 1
fi

echo
echo "== Optional cleanup =="
echo "internal/render/namespace.go, internal/render/node.go, and the"
echo "DrawEdge/edgeCharacters/shouldRenderEdge functions in edge.go now"
echo "belong to an old renderer path nothing calls. Consider removing"
echo "them once you've confirmed the fix looks right, to stop this bug"
echo "class from coming back:"
echo "  go vet ./..."
echo "  staticcheck ./...   # if installed"
