cat > ~/kranger-renderer-v3.sh <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

cd "$HOME/projects/kranger"

echo "=========================================="
echo "       󰒋 KRANGER RENDERER V3"
echo "=========================================="
echo

# ==========================================================
# Namespace container renderer
# ==========================================================

cat > internal/render/namespace.go <<'GOEOF'
package render

import (
	"fmt"

	"kranger/internal/graph"
	"kranger/internal/model"
)

type namespaceBounds struct {
	x1 int
	y1 int
	x2 int
	y2 int
}

func calculateNamespaceBounds(
	g *graph.Graph,
	namespace *graph.Node,
) namespaceBounds {

	paddingX := 3
	paddingY := 2

	// Start around the namespace label.
	minX := namespace.X
	minY := namespace.Y
	maxX := namespace.X + namespace.Width
	maxY := namespace.Y + 3

	foundChild := false

	for _, node := range g.Nodes {

		if node.Kind == model.KindNamespace {
			continue
		}

		if node.Namespace != namespace.Name {
			continue
		}

		foundChild = true

		if node.X-paddingX < minX {
			minX = node.X - paddingX
		}

		if node.Y-paddingY < minY {
			minY = node.Y - paddingY
		}

		if node.X+node.Width+paddingX > maxX {
			maxX = node.X + node.Width + paddingX
		}

		if node.Y+node.Height+paddingY > maxY {
			maxY = node.Y + node.Height + paddingY
		}
	}

	if !foundChild {
		return namespaceBounds{
			x1: namespace.X,
			y1: namespace.Y,
			x2: namespace.X + namespace.Width + 4,
			y2: namespace.Y + 4,
		}
	}

	return namespaceBounds{
		x1: minX,
		y1: minY,
		x2: maxX,
		y2: maxY,
	}
}

func DrawNamespace(
	canvas *Canvas,
	g *graph.Graph,
	namespace *graph.Node,
) {

	bounds := calculateNamespaceBounds(
		g,
		namespace,
	)

	color := Gray

	// --------------------------------------------------
	// Top border
	// --------------------------------------------------

	canvas.Set(
		bounds.x1,
		bounds.y1,
		'╭',
		color,
	)

	for x := bounds.x1 + 1; x < bounds.x2; x++ {
		canvas.Set(
			x,
			bounds.y1,
			'─',
			color,
		)
	}

	canvas.Set(
		bounds.x2,
		bounds.y1,
		'╮',
		color,
	)

	// --------------------------------------------------
	// Bottom border
	// --------------------------------------------------

	canvas.Set(
		bounds.x1,
		bounds.y2,
		'╰',
		color,
	)

	for x := bounds.x1 + 1; x < bounds.x2; x++ {
		canvas.Set(
			x,
			bounds.y2,
			'─',
			color,
		)
	}

	canvas.Set(
		bounds.x2,
		bounds.y2,
		'╯',
		color,
	)

	// --------------------------------------------------
	// Vertical borders
	// --------------------------------------------------

	for y := bounds.y1 + 1; y < bounds.y2; y++ {

		canvas.Set(
			bounds.x1,
			y,
			'│',
			color,
		)

		canvas.Set(
			bounds.x2,
			y,
			'│',
			color,
		)
	}

	// --------------------------------------------------
	// Namespace label
	// --------------------------------------------------

	label := fmt.Sprintf(
		" 󰆼 %s ",
		namespace.Name,
	)

	labelX := bounds.x1 + 2

	canvas.Write(
		labelX,
		bounds.y1,
		label,
		color,
	)
}
GOEOF

# ==========================================================
# Edge filtering
# ==========================================================

cat > internal/render/edge.go <<'GOEOF'
package render

import "kranger/internal/graph"

func shouldRenderEdge(
	edge *graph.Edge,
) bool {

	// Namespace containment is represented by the
	// namespace boundary itself.
	//
	// Drawing these edges creates the huge vertical
	// corridors that dominated Renderer V1/V2.
	if edge.Relation == "contains" {
		return false
	}

	return true
}

func edgeCharacters(
	style graph.EdgeStyle,
) (rune, rune, string) {

	switch style {

	case graph.EdgeRuntime:
		return DoubleHorizontal,
			DoubleVertical,
			Aqua

	case graph.EdgeTraffic:
		return DoubleHorizontal,
			DoubleVertical,
			BrightAqua

	case graph.EdgeReference:
		return '·',
			'⋮',
			Gray

	default:
		return Horizontal,
			Vertical,
			White
	}
}

func DrawEdge(
	canvas *Canvas,
	edge *graph.Edge,
) {

	if !shouldRenderEdge(edge) {
		return
	}

	points := edge.Path.Points

	if len(points) < 2 {
		return
	}

	horizontal,
		vertical,
		color :=
		edgeCharacters(edge.Style)

	for i := 0; i < len(points)-1; i++ {

		start := points[i]
		end := points[i+1]

		if start.Y == end.Y {

			step := 1

			if end.X < start.X {
				step = -1
			}

			for x := start.X; x != end.X; x += step {

				canvas.Set(
					x,
					start.Y,
					horizontal,
					color,
				)
			}

		} else if start.X == end.X {

			step := 1

			if end.Y < start.Y {
				step = -1
			}

			for y := start.Y; y != end.Y; y += step {

				canvas.Set(
					start.X,
					y,
					vertical,
					color,
				)
			}
		}
	}

	target := points[len(points)-1]
	previous := points[len(points)-2]

	var arrow rune

	switch {

	case target.X > previous.X:
		arrow = ArrowRight

	case target.X < previous.X:
		arrow = ArrowLeft

	case target.Y > previous.Y:
		arrow = ArrowDown

	default:
		arrow = ArrowUp
	}

	canvas.Set(
		target.X,
		target.Y,
		arrow,
		color,
	)
}
GOEOF

# ==========================================================
# Renderer ordering
# ==========================================================

cat > internal/render/renderer.go <<'GOEOF'
package render

import (
	"kranger/internal/graph"
	"kranger/internal/model"
)

func Render(
	g *graph.Graph,
	width int,
	height int,
) string {

	canvas := NewCanvas(
		width,
		height,
	)

	// --------------------------------------------------
	// 1. Namespace boundaries
	// --------------------------------------------------

	// Draw these first so topology remains visible
	// over the structural boundary.
	for _, node := range g.Nodes {

		if node.Kind != model.KindNamespace {
			continue
		}

		DrawNamespace(
			canvas,
			g,
			node,
		)
	}

	// --------------------------------------------------
	// 2. Relationships
	// --------------------------------------------------

	for _, edge := range g.Edges {

		DrawEdge(
			canvas,
			edge,
		)
	}

	// --------------------------------------------------
	// 3. Resource nodes
	// --------------------------------------------------

	for _, node := range g.Nodes {

		if node.Kind == model.KindNamespace {
			continue
		}

		DrawNode(
			canvas,
			node,
		)
	}

	return canvas.String()
}
GOEOF

# ==========================================================
# Tests
# ==========================================================

echo "🎨 Formatting..."

gofmt -w internal/render/*.go

echo
echo "🧪 Running tests..."

go test ./...

echo
echo "🔨 Building..."

go build -o kranger .

echo
echo "=========================================="
echo "       ✅ RENDERER V3 READY"
echo "=========================================="
echo
echo "Structural:"
echo "  contains  → namespace boundary"
echo "  owns      → normal line"
echo
echo "Runtime:"
echo "  runs-on   → AQUA"
echo "  selects   → BRIGHT AQUA"
echo
echo "Run:"
echo
echo "  ./kranger"
echo
EOF

chmod +x ~/kranger-renderer-v3.sh
~/kranger-renderer-v3.sh
