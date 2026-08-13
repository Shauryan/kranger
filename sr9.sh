cd ~/projects/kranger

cat > ~/kranger-v5.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/projects/kranger"

echo "=========================================="
echo "       󰒋 KRANGER COMPACT LAYOUT V5"
echo "=========================================="
echo

mkdir -p internal/render

cat > internal/render/compact_model.go <<'GO'
package render

import (
	"sort"

	"kranger/internal/graph"
	"kranger/internal/model"
)

type CompactGroup struct {
	Kind      model.ResourceKind
	Namespace string
	Nodes     []*graph.Node
	Count     int
	Label     string
}

type CompactNamespace struct {
	Name   string
	Groups []*CompactGroup
}

type CompactModel struct {
	Namespaces []*CompactNamespace
	Node       *graph.Node
}

func BuildCompactModel(g *graph.Graph) *CompactModel {

	namespaceMap := map[string]*CompactNamespace{}

	var node *graph.Node

	for _, n := range g.Nodes {

		if n.Kind == model.KindNode {
			node = n
			continue
		}

		if n.Kind == model.KindNamespace {

			if _, ok := namespaceMap[n.Name]; !ok {
				namespaceMap[n.Name] = &CompactNamespace{
					Name: n.Name,
				}
			}

			continue
		}

		ns := n.Namespace

		if _, ok := namespaceMap[ns]; !ok {
			namespaceMap[ns] = &CompactNamespace{
				Name: ns,
			}
		}
	}

	groupMap := map[string]*CompactGroup{}

	for _, n := range g.Nodes {

		if n.Kind == model.KindNamespace ||
			n.Kind == model.KindNode {
			continue
		}

		key := n.Namespace + "/" + string(n.Kind)

		group, ok := groupMap[key]

		if !ok {
			group = &CompactGroup{
				Kind:      n.Kind,
				Namespace: n.Namespace,
			}

			groupMap[key] = group
		}

		group.Nodes = append(group.Nodes, n)
	}

	for _, group := range groupMap {

		group.Count = len(group.Nodes)

		sort.Slice(group.Nodes, func(i, j int) bool {
			return group.Nodes[i].Name < group.Nodes[j].Name
		})

		group.Label = compactLabel(group)
	}

	for _, group := range groupMap {

		ns := namespaceMap[group.Namespace]

		ns.Groups = append(
			ns.Groups,
			group,
		)
	}

	namespaces := make(
		[]*CompactNamespace,
		0,
		len(namespaceMap),
	)

	for _, ns := range namespaceMap {

		sort.Slice(ns.Groups, func(i, j int) bool {
			return compactPriority(ns.Groups[i].Kind) <
				compactPriority(ns.Groups[j].Kind)
		})

		namespaces = append(namespaces, ns)
	}

	sort.Slice(namespaces, func(i, j int) bool {
		return namespaces[i].Name < namespaces[j].Name
	})

	return &CompactModel{
		Namespaces: namespaces,
		Node:       node,
	}
}

func compactLabel(g *CompactGroup) string {

	icon := ""

	if len(g.Nodes) > 0 {
		icon = g.Nodes[0].Icon
	}

	switch g.Kind {

	case model.KindDeployment:
		return icon + " Deploy"

	case model.KindReplicaSet:
		return icon + " RS"

	case model.KindPod:
		return icon + " Pods"

	case model.KindService:
		return icon + " SVC"

	default:
		return icon + " " + string(g.Kind)
	}
}

func compactPriority(kind model.ResourceKind) int {

	switch kind {

	case model.KindDeployment:
		return 1

	case model.KindReplicaSet:
		return 2

	case model.KindService:
		return 3

	case model.KindPod:
		return 4

	default:
		return 10
	}
}
GO

cat > internal/render/compact_layout.go <<'GO'
package render

type CompactLayoutConfig struct {
	Width int

	Left int
	Top  int

	GroupWidth int
	GroupGap   int

	NamespaceGap int
	NamespacePad int

	NodeGap int
}

func DefaultCompactLayout(width int) CompactLayoutConfig {

	return CompactLayoutConfig{
		Width: width,

		Left: 2,
		Top: 1,

		GroupWidth: 22,
		GroupGap:   4,

		NamespaceGap: 2,
		NamespacePad: 1,

		NodeGap: 2,
	}
}

type CompactPosition struct {
	X int
	Y int
}

type CompactLayout struct {
	Namespaces map[string]CompactPosition

	Groups map[*CompactGroup]CompactPosition

	Node CompactPosition

	Height int
}

func LayoutCompact(
	model *CompactModel,
	config CompactLayoutConfig,
) CompactLayout {

	layout := CompactLayout{
		Namespaces: map[string]CompactPosition{},
		Groups:     map[*CompactGroup]CompactPosition{},
	}

	y := config.Top

	for _, ns := range model.Namespaces {

		layout.Namespaces[ns.Name] =
			CompactPosition{
				X: config.Left,
				Y: y,
			}

		// Empty namespaces remain compact.
		if len(ns.Groups) == 0 {
			y += 4
			continue
		}

		groupX := config.Left + 3
		groupY := y + 2

		for _, group := range ns.Groups {

			layout.Groups[group] =
				CompactPosition{
					X: groupX,
					Y: groupY,
				}

			groupX +=
				config.GroupWidth +
					config.GroupGap

			// Wrap groups if necessary.
			if groupX+config.GroupWidth >= config.Width-4 {

				groupX = config.Left + 3
				groupY += 4
			}
		}

		y = groupY + 4 + config.NamespaceGap
	}

	if model.Node != nil {

		layout.Node = CompactPosition{
			X: config.Width - 24,
			Y: y,
		}

		y += 5
	}

	layout.Height = y + 2

	return layout
}
GO

cat > internal/render/compact_renderer.go <<'GO'
package render

import (
	"fmt"

	"kranger/internal/graph"
)

func RenderCompact(
	g *graph.Graph,
	width int,
	height int,
) string {

	model := BuildCompactModel(g)

	config := DefaultCompactLayout(width)

	layout := LayoutCompact(
		model,
		config,
	)

	if layout.Height > height {
		height = layout.Height
	}

	canvas := NewCanvas(
		width,
		height,
	)

	// Namespace containers.
	for _, ns := range model.Namespaces {

		pos := layout.Namespaces[ns.Name]

		drawCompactNamespace(
			canvas,
			ns,
			pos,
			layout,
			config,
		)
	}

	// Compact resource groups.
	for group, pos := range layout.Groups {

		DrawCompactGroup(
			canvas,
			group,
			pos.X,
			pos.Y,
			config.GroupWidth,
		)
	}

	// Important graph relationships.
	//
	// contains is represented by the namespace
	// boundary and therefore isn't drawn.
	for _, edge := range g.Edges {

		if edge.Relation == "contains" {
			continue
		}

		DrawEdge(
			canvas,
			edge,
		)
	}

	// Node.
	if model.Node != nil {

		pos := layout.Node

		drawCompactNode(
			canvas,
			model.Node,
			pos.X,
			pos.Y,
		)
	}

	drawCompactStatus(
		canvas,
		g,
		width,
		height-1,
	)

	return canvas.String()
}

func drawCompactNamespace(
	canvas *Canvas,
	ns *CompactNamespace,
	pos CompactPosition,
	layout CompactLayout,
	config CompactLayoutConfig,
) {

	width := config.Width - 4

	if width > 110 {
		width = 110
	}

	height := 5

	if len(ns.Groups) > 3 {
		height += 4
	}

	x := pos.X
	y := pos.Y

	// Top.
	canvas.Set(x, y, '╭', Gray)

	title := "─ 󰆼 " + ns.Name + " "

	canvas.Write(
		x+1,
		y,
		title,
		Gray,
	)

	for px := x + 1 + len([]rune(title)); px < x+width; px++ {
		canvas.Set(px, y, '─', Gray)
	}

	canvas.Set(x+width, y, '╮', Gray)

	// Sides.
	for py := y + 1; py < y+height; py++ {

		canvas.Set(x, py, '│', Gray)
		canvas.Set(x+width, py, '│', Gray)
	}

	// Bottom.
	canvas.Set(x, y+height, '╰', Gray)

	for px := x + 1; px < x+width; px++ {
		canvas.Set(px, y+height, '─', Gray)
	}

	canvas.Set(x+width, y+height, '╯', Gray)
}

func drawCompactNode(
	canvas *Canvas,
	node *graph.Node,
	x int,
	y int,
) {

	color := Green

	canvas.Write(
		x,
		y,
		"╭──────────────╮",
		color,
	)

	label := fmt.Sprintf(
		"│ %s Node      │",
		node.Icon,
	)

	canvas.Write(
		x,
		y+1,
		label,
		color,
	)

	canvas.Write(
		x,
		y+2,
		"╰──────────────╯",
		color,
	)
}

func drawCompactStatus(
	canvas *Canvas,
	g *graph.Graph,
	width int,
	y int,
) {

	if y < 0 || y >= canvas.Height {
		return
	}

	text := fmt.Sprintf(
		"󰒋 %d resources · %d relationships · ",
		g.NodeCount(),
		g.EdgeCount(),
	)

	text += "🟢 LIVE"

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
GO

# Replace main with compact renderer only.

cat > main.go <<'GO'
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

	g := graph.Build(state)

	// The full graph is still built and retained.
	// Compact mode has its own layout.
	output := render.RenderCompact(
		g,
		110,
		32,
	)

	fmt.Println()
	fmt.Println(output)
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
GO

echo "🎨 Formatting..."

gofmt -w internal/render/*.go main.go

echo
echo "🧪 Running tests..."

go test ./...

echo
echo "🔨 Building..."

go build -o kranger .

echo
echo "=========================================="
echo "       ✅ COMPACT V5 READY"
echo "=========================================="
echo
echo "Run:"
echo "  ./kranger"
echo

EOF

chmod +x ~/kranger-v5.sh
~/kranger-v5.sh
