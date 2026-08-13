cat > ~/kranger-renderer-v1.sh <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$HOME/projects/kranger"
cd "$PROJECT_DIR"

echo "=========================================="
echo "        󰒋 KRANGER RENDERER V1"
echo "=========================================="
echo

mkdir -p internal/render

# ==================================================
# Canvas
# ==================================================

cat > internal/render/canvas.go <<'GOEOF'
package render

import (
	"strings"
)

type Canvas struct {
	Width  int
	Height int

	cells [][]rune
}

func NewCanvas(width, height int) *Canvas {

	cells := make(
		[][]rune,
		height,
	)

	for y := 0; y < height; y++ {

		cells[y] = make(
			[]rune,
			width,
		)

		for x := 0; x < width; x++ {
			cells[y][x] = ' '
		}
	}

	return &Canvas{
		Width:  width,
		Height: height,
		cells:  cells,
	}
}

func (c *Canvas) Set(
	x int,
	y int,
	char rune,
) {

	if x < 0 ||
		y < 0 ||
		x >= c.Width ||
		y >= c.Height {
		return
	}

	c.cells[y][x] = char
}

func (c *Canvas) Get(
	x int,
	y int,
) rune {

	if x < 0 ||
		y < 0 ||
		x >= c.Width ||
		y >= c.Height {
		return ' '
	}

	return c.cells[y][x]
}

func (c *Canvas) Write(
	x int,
	y int,
	text string,
) {

	for index, char := range []rune(text) {

		c.Set(
			x+index,
			y,
			char,
		)
	}
}

func (c *Canvas) String() string {

	var builder strings.Builder

	for y := 0; y < c.Height; y++ {

		builder.WriteString(
			string(c.cells[y]),
		)

		if y < c.Height-1 {
			builder.WriteByte('\n')
		}
	}

	return builder.String()
}
GOEOF

# ==================================================
# Terminal primitives
# ==================================================

cat > internal/render/primitives.go <<'GOEOF'
package render

type LineKind int

const (
	LineHorizontal LineKind = iota
	LineVertical
)

const (
	Horizontal = '─'
	Vertical   = '│'

	TopLeft     = '┌'
	TopRight    = '┐'
	BottomLeft  = '└'
	BottomRight = '┘'

	LeftT   = '├'
	RightT  = '┤'
	TopT    = '┬'
	BottomT = '┴'

	Cross = '┼'

	DoubleHorizontal = '═'
	DoubleVertical   = '║'

	ArrowRight = '>'
	ArrowDown  = '▼'
	ArrowLeft  = '<'
	ArrowUp    = '▲'
)
GOEOF

# ==================================================
# Edge renderer
# ==================================================

cat > internal/render/edge.go <<'GOEOF'
package render

import (
	"kranger/internal/graph"
)

func edgeCharacters(
	style graph.EdgeStyle,
) (rune, rune) {

	switch style {

	case graph.EdgeRuntime:
		return DoubleHorizontal, DoubleVertical

	case graph.EdgeTraffic:
		return DoubleHorizontal, DoubleVertical

	case graph.EdgeReference:
		return '·', '⋮'

	default:
		return Horizontal, Vertical
	}
}

func DrawEdge(
	canvas *Canvas,
	edge *graph.Edge,
) {

	points := edge.Path.Points

	if len(points) < 2 {
		return
	}

	horizontal, vertical :=
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
				)
			}
		}
	}

	// Arrow at target.
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
	)
}
GOEOF

# ==================================================
# Node renderer
# ==================================================

cat > internal/render/node.go <<'GOEOF'
package render

import (
	"fmt"
	"strings"

	"kranger/internal/graph"
)

func DrawNode(
	canvas *Canvas,
	node *graph.Node,
) {

	x := node.X
	y := node.Y

	width := node.Width
	height := node.Height

	if width < 8 {
		width = 8
	}

	if height < 3 {
		height = 3
	}

	switch node.Shape {

	case "circle":
		drawCircleNode(
			canvas,
			node,
		)

	case "hexagon":
		drawHexagonNode(
			canvas,
			node,
		)

	default:
		drawRectangleNode(
			canvas,
			node,
		)
	}

	_ = x
	_ = y
}

func drawRectangleNode(
	canvas *Canvas,
	node *graph.Node,
) {

	x := node.X
	y := node.Y

	width := node.Width

	// Top
	canvas.Set(x, y, TopLeft)

	for i := 1; i < width-1; i++ {
		canvas.Set(
			x+i,
			y,
			Horizontal,
		)
	}

	canvas.Set(
		x+width-1,
		y,
		TopRight,
	)

	// Middle
	canvas.Set(x, y+1, Vertical)

	label := fmt.Sprintf(
		"%s %s",
		node.Icon,
		node.Name,
	)

	maxLength := width - 2

	runes := []rune(label)

	if len(runes) > maxLength {
		runes = runes[:maxLength]
	}

	label = string(runes)

	canvas.Write(
		x+1,
		y+1,
		label,
	)

	canvas.Set(
		x+width-1,
		y+1,
		Vertical,
	)

	// Bottom
	canvas.Set(
		x,
		y+2,
		BottomLeft,
	)

	for i := 1; i < width-1; i++ {
		canvas.Set(
			x+i,
			y+2,
			Horizontal,
		)
	}

	canvas.Set(
		x+width-1,
		y+2,
		BottomRight,
	)
}

func drawCircleNode(
	canvas *Canvas,
	node *graph.Node,
) {

	x := node.X
	y := node.Y

	canvas.Set(
		x+4,
		y,
		'╭',
	)

	canvas.Write(
		x+5,
		y,
		"──────",
	)

	canvas.Set(
		x+11,
		y,
		'╮',
	)

	canvas.Set(
		x+3,
		y+1,
		'(',
	)

	label := fmt.Sprintf(
		"%s %s",
		node.Icon,
		node.Name,
	)

	runes := []rune(label)

	if len(runes) > 8 {
		runes = runes[:8]
	}

	canvas.Write(
		x+4,
		y+1,
		string(runes),
	)

	canvas.Set(
		x+12,
		y+1,
		')',
	)

	canvas.Set(
		x+4,
		y+2,
		'╰',
	)

	canvas.Write(
		x+5,
		y+2,
		"──────",
	)

	canvas.Set(
		x+11,
		y+2,
		'╯',
	)
}

func drawHexagonNode(
	canvas *Canvas,
	node *graph.Node,
) {

	x := node.X
	y := node.Y

	width := node.Width

	canvas.Write(
		x,
		y,
		"/",
	)

	canvas.Write(
		x+1,
		y,
		strings.Repeat("─", width-2),
	)

	canvas.Write(
		x+width-1,
		y,
		"\\",
	)

	canvas.Write(
		x,
		y+1,
		"<",
	)

	label := fmt.Sprintf(
		"%s %s",
		node.Icon,
		node.Name,
	)

	runes := []rune(label)

	maxLength := width - 2

	if len(runes) > maxLength {
		runes = runes[:maxLength]
	}

	canvas.Write(
		x+1,
		y+1,
		string(runes),
	)

	canvas.Write(
		x+width-1,
		y+1,
		">",
	)

	canvas.Write(
		x,
		y+2,
		"\\",
	)

	canvas.Write(
		x+1,
		y+2,
		strings.Repeat("─", width-2),
	)

	canvas.Write(
		x+width-1,
		y+2,
		"/",
	)
}
GOEOF

# ==================================================
# Namespace boundary
# ==================================================

cat > internal/render/namespace.go <<'GOEOF'
package render

import (
	"fmt"

	"kranger/internal/graph"
)

func DrawNamespace(
	canvas *Canvas,
	node *graph.Node,
) {

	x := node.X
	y := node.Y

	width := node.Width

	title := fmt.Sprintf(
		"%s %s",
		node.Icon,
		node.Name,
	)

	canvas.Write(
		x,
		y,
		"╭─ "+title+" ",
	)

	remaining := width - len([]rune(title)) - 4

	if remaining < 2 {
		remaining = 2
	}

	for i := 0; i < remaining; i++ {
		canvas.Set(
			x+len([]rune("╭─ "+title+" "))+i,
			y,
			'─',
		)
	}

	canvas.Set(
		x+width,
		y,
		'╮',
	)
}
GOEOF

# ==================================================
# Renderer
# ==================================================

cat > internal/render/renderer.go <<'GOEOF'
package render

import (
	"kranger/internal/graph"
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

	// Draw edges first so nodes appear above them.
	for _, edge := range g.Edges {
		DrawEdge(
			canvas,
			edge,
		)
	}

	// Draw nodes afterward.
	for _, node := range g.Nodes {

		if node.Kind == "Namespace" {
			DrawNamespace(
				canvas,
				node,
			)

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

# ==================================================
# Renderer test
# ==================================================

cat > internal/render/renderer_test.go <<'GOEOF'
package render

import (
	"strings"
	"testing"
)

func TestCanvas(t *testing.T) {

	canvas := NewCanvas(20, 5)

	canvas.Write(
		2,
		2,
		"KRANGER",
	)

	result := canvas.String()

	if !strings.Contains(
		result,
		"KRANGER",
	) {
		t.Fatal(
			"canvas did not contain expected text",
		)
	}
}
GOEOF

# ==================================================
# Update main
# ==================================================

cat > main.go <<'GOEOF'
package main

import (
	"context"
	"fmt"
	"log"

	"kranger/internal/graph"
	"kranger/internal/k8s"
	"kranger/internal/render"
)

func main() {

	client, err := k8s.NewClient()

	if err != nil {
		log.Fatalf(
			"❌ Kubernetes connection failed: %v",
			err,
		)
	}

	discovery := k8s.NewDiscovery(client)

	state, err := discovery.Discover(
		context.Background(),
	)

	if err != nil {
		log.Fatalf(
			"❌ Resource discovery failed: %v",
			err,
		)
	}

	clusterGraph := graph.Build(state)

	// Temporary renderer dimensions.
	//
	// Bubble Tea will replace these with the
	// actual terminal dimensions later.
	config := graph.DefaultLayoutConfig(
		160,
		50,
	)

	graph.Layout(
		clusterGraph,
		config,
	)

	fmt.Println()

	fmt.Println(
		render.Render(
			clusterGraph,
			160,
			70,
		),
	)

	fmt.Println()
}
GOEOF

# ==================================================
# Format
# ==================================================

echo "🎨 Formatting..."

gofmt -w \
	internal/render/*.go \
	main.go

# ==================================================
# Test
# ==================================================

echo
echo "🧪 Running tests..."

go test ./...

# ==================================================
# Build
# ==================================================

echo
echo "🔨 Building..."

go build -o kranger .

echo
echo "=========================================="
echo "       ✅ RENDERER V1 READY"
echo "=========================================="
echo
echo "Run:"
echo
echo "    ./kranger"
echo
EOF

chmod +x ~/kranger-renderer-v1.sh
~/kranger-renderer-v1.sh
