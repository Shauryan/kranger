cd ~/projects/kranger

cat > ~/kranger-compact-v4.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/projects/kranger"

echo "=========================================="
echo "       󰒋 KRANGER COMPACT RENDERER V4"
echo "=========================================="
echo

mkdir -p internal/render

# ==========================================================
# Compact resource grouping
# ==========================================================

cat > internal/render/group.go <<'GOEOF'
package render

import (
	"sort"

	"kranger/internal/graph"
	"kranger/internal/model"
)

type ResourceGroup struct {
	Kind      model.ResourceKind
	Namespace string

	Nodes []*graph.Node

	Label string
	Count int
}

func BuildGroups(
	g *graph.Graph,
) []*ResourceGroup {

	groups := make(map[string]*ResourceGroup)

	for _, node := range g.Nodes {

		// Namespace nodes are rendered as boundaries.
		if node.Kind == model.KindNamespace {
			continue
		}

		key := string(node.Kind) + "/" + node.Namespace

		group, exists := groups[key]

		if !exists {

			group = &ResourceGroup{
				Kind:      node.Kind,
				Namespace: node.Namespace,
			}

			groups[key] = group
		}

		group.Nodes = append(
			group.Nodes,
			node,
		)
	}

	result := make(
		[]*ResourceGroup,
		0,
		len(groups),
	)

	for _, group := range groups {

		sort.Slice(
			group.Nodes,
			func(i, j int) bool {
				return group.Nodes[i].Name <
					group.Nodes[j].Name
			},
		)

		group.Count = len(group.Nodes)

		if group.Count == 1 {
			group.Label = group.Nodes[0].Name
		} else {
			group.Label = compactKind(group.Kind)
		}

		result = append(
			result,
			group,
		)
	}

	sort.Slice(
		result,
		func(i, j int) bool {

			if result[i].Namespace != result[j].Namespace {
				return result[i].Namespace <
					result[j].Namespace
			}

			return string(result[i].Kind) <
				string(result[j].Kind)
		},
	)

	return result
}

func compactKind(
	kind model.ResourceKind,
) string {

	switch kind {

	case model.KindPod:
		return "Pods"

	case model.KindReplicaSet:
		return "ReplicaSets"

	case model.KindDeployment:
		return "Deployments"

	case model.KindService:
		return "Services"

	default:
		return string(kind)
	}
}

func IsControlPlane(
	node *graph.Node,
) bool {

	if node.Kind != model.KindPod {
		return false
	}

	name := node.Name

	switch {

	case contains(name, "kube-apiserver"):
		return true

	case contains(name, "kube-controller-manager"):
		return true

	case contains(name, "kube-scheduler"):
		return true

	case contains(name, "etcd"):
		return true

	case contains(name, "kube-proxy"):
		return true

	default:
		return false
	}
}

func contains(
	value string,
	substring string,
) bool {

	for i := 0; i+len(substring) <= len(value); i++ {

		if value[i:i+len(substring)] == substring {
			return true
		}
	}

	return false
}
GOEOF

# ==========================================================
# Compact canvas helpers
# ==========================================================

cat > internal/render/compact.go <<'GOEOF'
package render

import (
	"fmt"

	"kranger/internal/graph"
)

func compactNodeLabel(
	node *graph.Node,
) string {

	switch node.Kind {

	case "Pod":
		return fmt.Sprintf(
			"%s %s",
			node.Icon,
			"Pod",
		)

	case "ReplicaSet":
		return fmt.Sprintf(
			"%s RS",
			node.Icon,
		)

	case "Deployment":
		return fmt.Sprintf(
			"%s Deploy",
			node.Icon,
		)

	case "Service":
		return fmt.Sprintf(
			"%s SVC",
			node.Icon,
		)

	default:
		return fmt.Sprintf(
			"%s %s",
			node.Icon,
			node.Name,
		)
	}
}

func DrawCompactGroup(
	canvas *Canvas,
	group *ResourceGroup,
	x int,
	y int,
	width int,
) {

	node := group.Nodes[0]

	label := compactNodeLabel(node)

	if group.Count > 1 {
		label += fmt.Sprintf(
			" ×%d",
			group.Count,
		)
	}

	color := White

	canvas.Set(
		x,
		y,
		'╭',
		color,
	)

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
		'╮',
		color,
	)

	canvas.Set(
		x,
		y+1,
		Vertical,
		color,
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
		'╰',
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
		'╯',
		color,
	)
}

func DrawControlPlane(
	canvas *Canvas,
	nodes []*graph.Node,
	x int,
	y int,
	width int,
) {

	if len(nodes) == 0 {
		return
	}

	label := fmt.Sprintf(
		"⚙ Control Plane ×%d",
		len(nodes),
	)

	color := Gray

	canvas.Set(
		x,
		y,
		'[',
		color,
	)

	canvas.Write(
		x+1,
		y,
		label,
		color,
	)

	canvas.Set(
		x+1+len([]rune(label)),
		y,
		']',
		color,
	)
}
GOEOF

# ==========================================================
# Compact renderer
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
	// Compact mode intentionally does not render every
	// object independently.
	//
	// The graph remains complete internally.
	// Only the presentation is compressed.
	// --------------------------------------------------

	groups := BuildGroups(g)

	// --------------------------------------------------
	// Namespace boundaries
	// --------------------------------------------------

	for _, node := range g.Nodes {

		if node.Kind != model.KindNamespace {
			continue
		}

		DrawCompactNamespace(
			canvas,
			g,
			node,
			width,
		)
	}

	// --------------------------------------------------
	// Important relationships
	// --------------------------------------------------

	for _, edge := range g.Edges {

		// Namespace containment is represented by
		// the boundary.
		if edge.Relation == "contains" {
			continue
		}

		DrawEdge(
			canvas,
			edge,
		)
	}

	// --------------------------------------------------
	// Compact nodes
	// --------------------------------------------------

	for _, group := range groups {

		// Control-plane Pods are collapsed.
		if group.Kind == model.KindPod {

			controlPlane := make(
				[]*graph.Node,
				0,
			)

			for _, node := range group.Nodes {

				if IsControlPlane(node) {
					controlPlane = append(
						controlPlane,
						node,
					)
				}
			}

			if len(controlPlane) > 0 {

				DrawControlPlane(
					canvas,
					controlPlane,
					group.Nodes[0].X,
					group.Nodes[0].Y,
					width,
				)
			}

			// Render only workload pods.
			normal := make(
				[]*graph.Node,
				0,
			)

			for _, node := range group.Nodes {

				if !IsControlPlane(node) {
					normal = append(
						normal,
						node,
					)
				}
			}

			if len(normal) == 0 {
				continue
			}

			group.Nodes = normal
			group.Count = len(normal)
		}

		DrawCompactGroup(
			canvas,
			group,
			group.Nodes[0].X,
			group.Nodes[0].Y,
			22,
		)
	}

	// --------------------------------------------------
	// Status footer
	// --------------------------------------------------

	drawStatusBar(
		canvas,
		g,
		width,
		height-3,
	)

	return canvas.String()
}

func DrawCompactNamespace(
	canvas *Canvas,
	g *graph.Graph,
	namespace *graph.Node,
	width int,
) {

	// Compact fixed-height namespace boundary.
	//
	// This prevents namespaces from consuming the
	// entire vertical terminal.
	x := 1

	y := namespace.Y

	boxWidth := width - 4

	if boxWidth > 110 {
		boxWidth = 110
	}

	boxHeight := 11

	// Top
	canvas.Set(
		x,
		y,
		'╭',
		Gray,
	)

	title := "─ 󰆼 " + namespace.Name + " "

	canvas.Write(
		x+1,
		y,
		title,
		Gray,
	)

	for px := x + 1 + len([]rune(title)); px < x+boxWidth; px++ {

		canvas.Set(
			px,
			y,
			'─',
			Gray,
		)
	}

	canvas.Set(
		x+boxWidth,
		y,
		'╮',
		Gray,
	)

	// Sides
	for py := y + 1; py < y+boxHeight; py++ {

		canvas.Set(
			x,
			py,
			'│',
			Gray,
		)

		canvas.Set(
			x+boxWidth,
			py,
			'│',
			Gray,
		)
	}

	// Bottom
	canvas.Set(
		x,
		y+boxHeight,
		'╰',
		Gray,
	)

	for px := x + 1; px < x+boxWidth; px++ {

		canvas.Set(
			px,
			y+boxHeight,
			'─',
			Gray,
		)
	}

	canvas.Set(
		x+boxWidth,
		y+boxHeight,
		'╯',
		Gray,
	)

	_ = g
}

func drawStatusBar(
	canvas *Canvas,
	g *graph.Graph,
	width int,
	y int,
) {

	if y < 0 || y >= canvas.Height {
		return
	}

	text := " 󰒋 " +
		itoa(g.NodeCount()) +
		" resources · " +
		itoa(g.EdgeCount()) +
		" relationships · 🟢 LIVE "

	if len([]rune(text)) > width {
		text = string([]rune(text)[:width])
	}

	canvas.Write(
		0,
		y,
		text,
		Gray,
	)
}

func itoa(value int) string {

	if value == 0 {
		return "0"
	}

	result := ""

	for value > 0 {

		digit := value % 10

		result = string(rune('0'+digit)) + result

		value /= 10
	}

	return result
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
		120,
		35,
	)

	graph.Layout(
		clusterGraph,
		config,
	)

	fmt.Println()

	fmt.Println(
		render.Render(
			clusterGraph,
			120,
			35,
		),
	)

	fmt.Println()

	fmt.Printf(
		"%s● AQUA%s runtime / traffic   ",
		render.Aqua,
		render.Reset,
	)

	fmt.Printf(
		"%s─ STRUCTURE%s   ",
		render.White,
		render.Reset,
	)

	fmt.Printf(
		"%s· REFERENCE%s\n",
		render.Gray,
		render.Reset,
	)
}
GOEOF

# ==========================================================
# Format / test / build
# ==========================================================

echo "🎨 Formatting..."

gofmt -w \
	internal/render/*.go \
	main.go

echo
echo "🧪 Running tests..."

go test ./...

echo
echo "🔨 Building..."

go build -o kranger .

echo
echo "=========================================="
echo "       ✅ COMPACT RENDERER V4 READY"
echo "=========================================="
echo
echo "Default viewport: 120 × 35"
echo
echo "Run:"
echo "  ./kranger"
echo

EOF

chmod +x ~/kranger-compact-v4.sh
~/kranger-compact-v4.sh
