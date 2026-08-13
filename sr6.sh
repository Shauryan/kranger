cd ~/projects/kranger

cat > ~/kranger-renderer-v2.sh <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$HOME/projects/kranger"
cd "$PROJECT_DIR"

echo "=========================================="
echo "       󰒋 KRANGER RENDERER V2"
echo "=========================================="
echo

mkdir -p internal/render

# ==========================================================
# ANSI visual system
# ==========================================================

cat > internal/render/color.go <<'GOEOF'
package render

const (
	Reset = "\033[0m"

	Bold = "\033[1m"

	// Semantic colours.
	Aqua      = "\033[38;5;51m"
	BrightAqua = "\033[38;5;87m"

	White = "\033[38;5;255m"
	Gray  = "\033[38;5;245m"

	Yellow = "\033[38;5;220m"
	Red    = "\033[38;5;196m"
	Green  = "\033[38;5;46m"
)

func EdgeColor(style string) string {

	switch style {

	case "runtime":
		return Aqua

	case "traffic":
		return BrightAqua

	case "reference":
		return Gray

	default:
		return White
	}
}
GOEOF

# ==========================================================
# ANSI canvas
# ==========================================================

cat > internal/render/canvas.go <<'GOEOF'
package render

import "strings"

type Cell struct {
	Char  rune
	Color string
}

type Canvas struct {
	Width  int
	Height int

	cells [][]Cell
}

func NewCanvas(width, height int) *Canvas {

	cells := make([][]Cell, height)

	for y := 0; y < height; y++ {

		cells[y] = make([]Cell, width)

		for x := 0; x < width; x++ {

			cells[y][x] = Cell{
				Char:  ' ',
				Color: Reset,
			}
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
	color string,
) {

	if x < 0 ||
		y < 0 ||
		x >= c.Width ||
		y >= c.Height {
		return
	}

	c.cells[y][x] = Cell{
		Char:  char,
		Color: color,
	}
}

func (c *Canvas) Write(
	x int,
	y int,
	text string,
	color string,
) {

	for index, char := range []rune(text) {

		c.Set(
			x+index,
			y,
			char,
			color,
		)
	}
}

func (c *Canvas) String() string {

	var builder strings.Builder

	for y := 0; y < c.Height; y++ {

		currentColor := ""

		for x := 0; x < c.Width; x++ {

			cell := c.cells[y][x]

			if cell.Color != currentColor {

				builder.WriteString(cell.Color)
				currentColor = cell.Color
			}

			builder.WriteRune(cell.Char)
		}

		builder.WriteString(Reset)

		if y < c.Height-1 {
			builder.WriteByte('\n')
		}
	}

	return builder.String()
}
GOEOF

# ==========================================================
# Primitive characters
# ==========================================================

cat > internal/render/primitives.go <<'GOEOF'
package render

const (
	Horizontal = '─'
	Vertical   = '│'

	DoubleHorizontal = '═'
	DoubleVertical   = '║'

	TopLeft     = '╭'
	TopRight    = '╮'
	BottomLeft  = '╰'
	BottomRight = '╯'

	ArrowRight = '▶'
	ArrowDown  = '▼'
	ArrowLeft  = '◀'
	ArrowUp    = '▲'
)
GOEOF

# ==========================================================
# Edge renderer
# ==========================================================

cat > internal/render/edge.go <<'GOEOF'
package render

import "kranger/internal/graph"

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
# Node renderer
# ==========================================================

cat > internal/render/node.go <<'GOEOF'
package render

import (
	"fmt"

	"kranger/internal/graph"
)

func nodeColor(node *graph.Node) string {

	switch node.Status {

	case "Running",
		"True":
		return Green

	case "Failed",
		"Error":
		return Red

	default:
		return White
	}
}

func DrawNode(
	canvas *Canvas,
	node *graph.Node,
) {

	switch node.Shape {

	case "circle":
		drawCircleNode(canvas, node)

	case "hexagon":
		drawHexagonNode(canvas, node)

	default:
		drawRectangleNode(canvas, node)
	}
}

func drawRectangleNode(
	canvas *Canvas,
	node *graph.Node,
) {

	x := node.X
	y := node.Y
	width := node.Width

	color := nodeColor(node)

	canvas.Set(x, y, TopLeft, color)

	for i := 1; i < width-1; i++ {
		canvas.Set(
			x+i,
			y,
			Horizontal,
			color,
		)
	}

	canvas.Set(
		x+width-1,
		y,
		TopRight,
		color,
	)

	canvas.Set(
		x,
		y+1,
		Vertical,
		color,
	)

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

	canvas.Write(
		x+1,
		y+1,
		string(runes),
		color,
	)

	canvas.Set(
		x+width-1,
		y+1,
		Vertical,
		color,
	)

	canvas.Set(
		x,
		y+2,
		BottomLeft,
		color,
	)

	for i := 1; i < width-1; i++ {

		canvas.Set(
			x+i,
			y+2,
			Horizontal,
			color,
		)
	}

	canvas.Set(
		x+width-1,
		y+2,
		BottomRight,
		color,
	)
}

func drawCircleNode(
	canvas *Canvas,
	node *graph.Node,
) {

	x := node.X
	y := node.Y

	color := Green

	canvas.Write(
		x+3,
		y,
		"╭──────╮",
		color,
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
		x+3,
		y+1,
		"("+string(runes)+")",
		color,
	)

	canvas.Write(
		x+3,
		y+2,
		"╰──────╯",
		color,
	)
}

func drawHexagonNode(
	canvas *Canvas,
	node *graph.Node,
) {

	x := node.X
	y := node.Y

	color := Aqua
	width := node.Width

	canvas.Write(
		x,
		y,
		"/"+repeat("─", width-2)+"\\",
		color,
	)

	label := fmt.Sprintf(
		"%s %s",
		node.Icon,
		node.Name,
	)

	runes := []rune(label)

	if len(runes) > width-2 {
		runes = runes[:width-2]
	}

	canvas.Write(
		x,
		y+1,
		"<"+string(runes)+">",
		color,
	)

	canvas.Write(
		x,
		y+2,
		"\\"+repeat("─", width-2)+"/",
		color,
	)
}

func repeat(char string, count int) string {

	result := ""

	for i := 0; i < count; i++ {
		result += char
	}

	return result
}
GOEOF

# ==========================================================
# Namespace boundary
# ==========================================================

cat > internal/render/namespace.go <<'GOEOF'
package render

import "kranger/internal/graph"

// Renderer V2 intentionally treats Namespace as a
// structural boundary rather than a normal node.
//
// Full bounding-box calculation will be added once
// the interactive renderer is introduced.
func DrawNamespace(
	canvas *Canvas,
	node *graph.Node,
) {

	x := node.X
	y := node.Y

	color := Gray

	title := "╭─ " +
		string(node.Icon) +
		" " +
		node.Name +
		" "

	canvas.Write(
		x,
		y,
		title,
		color,
	)
}
GOEOF

# ==========================================================
# Renderer
# ==========================================================

cat > internal/render/renderer.go <<'GOEOF'
package render

import "kranger/internal/graph"

func Render(
	g *graph.Graph,
	width int,
	height int,
) string {

	canvas := NewCanvas(
		width,
		height,
	)

	// Edges first.
	//
	// Nodes are drawn afterward so important
	// topology boxes remain readable.
	for _, edge := range g.Edges {

		DrawEdge(
			canvas,
			edge,
		)
	}

	// Nodes.
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

# ==========================================================
# Main
# ==========================================================

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

	config := graph.DefaultLayoutConfig(
		160,
		70,
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
	fmt.Printf(
		"%s● AQUA%s  runtime / traffic path\n",
		render.Aqua,
		render.Reset,
	)

	fmt.Printf(
		"%s─ STRUCTURAL%s  ownership / hierarchy\n",
		render.White,
		render.Reset,
	)

	fmt.Printf(
		"%s· REFERENCE%s  configuration / references\n",
		render.Gray,
		render.Reset,
	)
}
GOEOF

# ==========================================================
# Format
# ==========================================================

echo "🎨 Formatting..."

gofmt -w \
	internal/render/*.go \
	main.go

# ==========================================================
# Test
# ==========================================================

echo
echo "🧪 Running tests..."

go test ./...

# ==========================================================
# Build
# ==========================================================

echo
echo "🔨 Building..."

go build -o kranger .

echo
echo "=========================================="
echo "       ✅ RENDERER V2 READY"
echo "=========================================="
echo
echo "Aqua semantics:"
echo
echo "  runs-on   → AQUA"
echo "  selects   → BRIGHT AQUA"
echo "  owns      → WHITE"
echo "  contains  → GRAY"
echo "  reference → GRAY / dotted"
echo
echo "Run:"
echo
echo "  ./kranger"
echo

EOF

chmod +x ~/kranger-renderer-v2.sh
~/kranger-renderer-v2.sh
