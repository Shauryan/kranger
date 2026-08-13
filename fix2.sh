#!/usr/bin/env bash
#
# fix-kranger-edge-routing.sh
#
# Fixes broken edge routing in kranger's compact renderer.
#
# ROOT CAUSE:
#   drawCompactRelation() in internal/render/compact_relationship.go
#   always assumes the target box is to the right of the source box:
#
#     fromX := from.X + 22      // always exits from the RIGHT edge
#     toX   := to.X              // always enters from the LEFT edge
#     midX  := fromX + 2
#     for x := midX; x < toX; x++ { ... }   // only ever walks rightward
#
#   When the target is NOT to the right (e.g. the Service group, which
#   sits directly BELOW the Pod group at the same X), midX ends up to
#   the right of toX, so the final horizontal leg's loop condition
#   (x < toX) is never true and never runs. The result is a dangling
#   vertical stub with no connecting horizontal segment, positioned a
#   couple of columns away from the separate Pod -> Node runtime
#   spine -- producing the doubled "|  |" vertical lines and the
#   Node box looking disconnected.
#
# FIX:
#   Replace drawCompactRelation with a direction-aware version that:
#     - picks entry/exit sides based on where the target actually is
#     - walks both horizontal legs with a direction-aware step
#     - handles the case where source/target overlap in X (e.g. one
#       sits directly above/below the other) by routing out to the
#       right and back in, instead of assuming a rightward target
#
# SAFETY:
#   - Only edits internal/render/compact_relationship.go
#   - Verifies the current drawCompactRelation function matches what
#     this script expects before changing anything; aborts with no
#     changes if it doesn't
#   - Backs up before editing
#   - Only replaces the binary if `go build` succeeds
#
# USAGE:
#   cd ~/projects/kranger
#   ./fix-kranger-edge-routing.sh
#
set -euo pipefail

PROJECT_ROOT="${1:-$HOME/projects/kranger}"
TARGET_FILE="$PROJECT_ROOT/internal/render/compact_relationship.go"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="${TARGET_FILE}.bak-edge-routing-fix-${TIMESTAMP}"

echo "== kranger edge-routing fix =="
echo "Project root: $PROJECT_ROOT"
echo

if [[ ! -f "$TARGET_FILE" ]]; then
    echo "ERROR: $TARGET_FILE not found." >&2
    echo "Pass the project root explicitly if it lives elsewhere:" >&2
    echo "  ./fix-kranger-edge-routing.sh /path/to/kranger" >&2
    exit 1
fi

python3 - "$TARGET_FILE" "$BACKUP_FILE" <<'PYEOF'
import re
import sys
import shutil

target_file, backup_file = sys.argv[1], sys.argv[2]

with open(target_file, "r") as f:
    content = f.read()

# Match the entire existing drawCompactRelation function, from its
# signature to the closing brace right before "func drawRuntimeToNode".
pattern = re.compile(
    r"func drawCompactRelation\(.*?\n\}\n(?=\nfunc drawRuntimeToNode)",
    re.DOTALL,
)

match = pattern.search(content)

if not match:
    print("ERROR: Could not find drawCompactRelation() as expected in")
    print(f"  {target_file}")
    print()
    print("The file may have already changed since this script was")
    print("written. Refusing to guess -- no changes made. Paste the")
    print("current contents of compact_relationship.go so the fix can")
    print("be adjusted.")
    sys.exit(2)

replacement = '''func drawCompactRelation(
	canvas *Canvas,
	from CompactPosition,
	to CompactPosition,
	style graph.EdgeStyle,
) {

	// Group boxes are 22 characters wide and 3 rows high.
	const boxWidth = 22

	fromY := from.Y + 1
	toY := to.Y + 1

	var horizontal, vertical, arrowRight, arrowLeft rune
	var color string

	switch style {

	case graph.EdgeTraffic:
		horizontal = DoubleHorizontal
		vertical = DoubleVertical
		arrowRight = ArrowRight
		arrowLeft = ArrowLeft
		color = BrightAqua

	case graph.EdgeRuntime:
		horizontal = DoubleHorizontal
		vertical = DoubleVertical
		arrowRight = ArrowRight
		arrowLeft = ArrowLeft
		color = Aqua

	default:
		horizontal = Horizontal
		vertical = Vertical
		arrowRight = ArrowRight
		arrowLeft = ArrowLeft
		color = White
	}

	// --------------------------------------------------
	// Same row: direction-aware straight line.
	// --------------------------------------------------

	if fromY == toY {

		fromX := from.X + boxWidth
		toX := to.X
		arrow := arrowRight
		step := 1

		if toX < fromX {
			// Target is to the left of source; exit from the
			// source's left edge and enter the target's right edge.
			fromX = from.X
			toX = to.X + boxWidth
			step = -1
			arrow = arrowLeft
		}

		for x := fromX; x != toX; x += step {
			canvas.Set(x, fromY, horizontal, color)
		}

		canvas.Set(toX, toY, arrow, color)
		return
	}

	// --------------------------------------------------
	// Different rows: route via a vertical channel chosen
	// relative to where the target actually is, instead of
	// always assuming it's to the right.
	// --------------------------------------------------

	fromLeft := from.X
	fromRight := from.X + boxWidth
	toLeft := to.X
	toRight := to.X + boxWidth

	var fromX, toX, midX int
	arrow := arrowRight

	switch {

	case toLeft >= fromRight:
		// Target is cleanly to the right.
		fromX = fromRight
		toX = toLeft
		midX = fromX + (toX-fromX)/2

	case toRight <= fromLeft:
		// Target is cleanly to the left.
		fromX = fromLeft
		toX = toRight
		midX = fromX - (fromX-toX)/2
		arrow = arrowLeft

	default:
		// Boxes overlap horizontally (e.g. one sits directly
		// above/below the other, same column). Route out past
		// whichever box extends furthest right, then back in.
		fromX = fromRight
		toX = toRight

		channel := fromRight
		if toRight > channel {
			channel = toRight
		}

		midX = channel + 2
	}

	hStep1 := 1
	if midX < fromX {
		hStep1 = -1
	}

	for x := fromX; x != midX; x += hStep1 {
		canvas.Set(x, fromY, horizontal, color)
	}

	vStep := 1
	if toY < fromY {
		vStep = -1
	}

	for y := fromY; y != toY; y += vStep {
		canvas.Set(midX, y, vertical, color)
	}

	hStep2 := 1
	if toX < midX {
		hStep2 = -1
	}

	for x := midX; x != toX; x += hStep2 {
		canvas.Set(x, toY, horizontal, color)
	}

	canvas.Set(toX, toY, arrow, color)
}
'''

new_content = content[: match.start()] + replacement + content[match.end():]

shutil.copy2(target_file, backup_file)
print(f"Backed up original to:\\n  {backup_file}")

with open(target_file, "w") as f:
    f.write(new_content)

print(f"Replaced drawCompactRelation() in:\\n  {target_file}")
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
    echo "Restore the backup with:" >&2
    echo "  cp \"$BACKUP_FILE\" \"$TARGET_FILE\"" >&2
    rm -f kranger.new
    exit 1
fi
