cd ~/projects/kranger

cat > ~/kranger-layout-v2.sh <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$HOME/projects/kranger"

cd "$PROJECT_DIR"

echo "=========================================="
echo "       󰒋 KRANGER LAYOUT ENGINE V2"
echo "=========================================="
echo

mkdir -p internal/graph

# ==================================================
# 1. Geometry primitives
# ==================================================

cat > internal/graph/geometry.go <<'GOEOF'
package graph

type Point struct {
	X int
	Y int
}

type EdgePath struct {
	Points []Point
}
GOEOF

# ==================================================
# 2. Improved layout configuration
# ==================================================

cat > internal/graph/layout.go <<'GOEOF'
package graph

import (
	"sort"

	"kranger/internal/model"
)

type Lane int

const (
	LaneNamespace Lane = iota
	LaneGateway
	LaneWorkload
	LaneReplica
	LaneService
	LanePod
	LaneRuntime
	LaneStorage
	LaneCount
)

type LayoutConfig struct {
	TerminalWidth  int
	TerminalHeight int

	NodeWidth  int
	NodeHeight int

	HorizontalGap int
	VerticalGap   int

	LeftPadding int
	TopPadding  int

	LaneHeight int
}

func DefaultLayoutConfig(width, height int) LayoutConfig {
	nodeWidth := 24

	// Compact nodes when terminal is narrow.
	switch {
	case width < 100:
		nodeWidth = 16
	case width < 130:
		nodeWidth = 20
	case width >= 160:
		nodeWidth = 24
	}

	return LayoutConfig{
		TerminalWidth:  width,
		TerminalHeight: height,

		NodeWidth:  nodeWidth,
		NodeHeight: 3,

		HorizontalGap: 4,
		VerticalGap:   2,

		LeftPadding: 2,
		TopPadding:  2,

		LaneHeight: 7,
	}
}

func laneFor(kind model.ResourceKind) Lane {
	switch kind {

	case model.KindNamespace:
		return LaneNamespace

	case model.KindIngress:
		return LaneGateway

	case model.KindDeployment,
		model.KindDaemonSet,
		model.KindStatefulSet:
		return LaneWorkload

	case model.KindReplicaSet:
		return LaneReplica

	case model.KindService:
		return LaneService

	case model.KindPod:
		return LanePod

	case model.KindContainer,
		model.KindNode:
		return LaneRuntime

	case model.KindPVC,
		model.KindPV:
		return LaneStorage

	default:
		return LaneWorkload
	}
}

// Layout arranges resources into semantic horizontal lanes.
//
// The horizontal axis represents architectural flow:
//
// Namespace → Workload → ReplicaSet → Pod → Runtime
//
// Services and gateways are placed into their own lanes so
// network relationships can be rendered separately.
func Layout(g *Graph, config LayoutConfig) {

	if len(g.Nodes) == 0 {
		return
	}

	assignLanes(g)
	assignLaneCoordinates(g, config)
	buildEdgePaths(g)
}

func assignLanes(g *Graph) {

	for _, node := range g.Nodes {
		node.X = 0
		node.Y = 0
	}

	laneNodes := make(map[Lane][]*Node)

	for _, node := range g.Nodes {
		lane := laneFor(node.Kind)
		laneNodes[lane] = append(laneNodes[lane], node)
	}

	for lane := Lane(0); lane < LaneCount; lane++ {

		nodes := laneNodes[lane]

		sort.Slice(
			nodes,
			func(i, j int) bool {
				return nodes[i].ID < nodes[j].ID
			},
		)

		for _, node := range nodes {

			// Store lane temporarily in Y.
			node.Y = int(lane)
		}
	}
}

func assignLaneCoordinates(
	g *Graph,
	config LayoutConfig,
) {
	laneNodes := make(map[Lane][]*Node)

	for _, node := range g.Nodes {
		lane := Lane(node.Y)
		laneNodes[lane] = append(laneNodes[lane], node)
	}

	// Calculate available horizontal space.
	availableWidth :=
		config.TerminalWidth -
			config.LeftPadding*2

	step :=
		config.NodeWidth +
			config.HorizontalGap

	columns := 1

	if step > 0 {
		columns = availableWidth / step
	}

	if columns < 1 {
		columns = 1
	}

	// Each semantic lane occupies a horizontal row.
	//
	// Nodes inside the lane are placed from left to right.
	for lane := Lane(0); lane < LaneCount; lane++ {

		nodes := laneNodes[lane]

		for index, node := range nodes {

			column := index % columns
			row := index / columns

			node.X =
				config.LeftPadding +
				column*step

			node.Y =
				config.TopPadding +
				int(lane)*config.LaneHeight +
				row*(config.NodeHeight+config.VerticalGap)
		}
	}
}

// buildEdgePaths creates simple orthogonal paths.
//
// The renderer will later turn these points into:
//
// ────────┐
//         │
//         ▼
//
// instead of drawing diagonal lines through other nodes.
func buildEdgePaths(g *Graph) {

	for _, edge := range g.Edges {

		source, sourceOK := g.Nodes[edge.Source]
		target, targetOK := g.Nodes[edge.Target]

		if !sourceOK || !targetOK {
			continue
		}

		start := Point{
			X: source.X + source.Width,
			Y: source.Y + source.Height/2,
		}

		end := Point{
			X: target.X,
			Y: target.Y + target.Height/2,
		}

		midX := (start.X + end.X) / 2

		edge.Path = EdgePath{
			Points: []Point{
				start,
				{X: midX, Y: start.Y},
				{X: midX, Y: end.Y},
				end,
			},
		}
	}
}
GOEOF

# ==================================================
# 3. Update edge model with paths
# ==================================================

cat > internal/graph/edge.go <<'GOEOF'
package graph

import "kranger/internal/model"

type EdgeStyle string

const (
	EdgeLogical   EdgeStyle = "logical"
	EdgeRuntime   EdgeStyle = "runtime"
	EdgeReference EdgeStyle = "reference"
	EdgeTraffic   EdgeStyle = "traffic"
)

type Edge struct {
	ID string

	Source string
	Target string

	Relation model.RelationshipType

	Style EdgeStyle

	Active bool

	Path EdgePath
}

func FromRelationship(
	relationship model.Relationship,
) Edge {

	style := EdgeLogical

	switch relationship.Type {

	case model.RelationRunsOn:
		style = EdgeRuntime

	case model.RelationSelects:
		style = EdgeTraffic

	case model.RelationMounts,
		model.RelationReferences,
		model.RelationUses:
		style = EdgeReference
	}

	return Edge{
		ID:       relationship.SourceID + "->" + relationship.TargetID,
		Source:   relationship.SourceID,
		Target:   relationship.TargetID,
		Relation: relationship.Type,
		Style:    style,
		Active:   true,
	}
}
GOEOF

# ==================================================
# 4. Update graph node
# ==================================================

cat > internal/graph/node.go <<'GOEOF'
package graph

import (
	"kranger/internal/model"
	"kranger/internal/ui"
)

type Node struct {
	ID        string
	Kind      model.ResourceKind
	Name      string
	Namespace string
	Status    string
	Age       string

	Icon  ui.Icon
	Shape ui.Shape

	X int
	Y int

	Width  int
	Height int
}

func FromResource(resource model.Resource) Node {

	return Node{
		ID:        resource.ID,
		Kind:      resource.Kind,
		Name:      resource.Name,
		Namespace: resource.Namespace,
		Status:    resource.Status,
		Age:       resource.Age,

		Icon:  ui.ForResource(resource.Kind),
		Shape: ui.ShapeForResource(string(resource.Kind)),

		Width:  24,
		Height: 3,
	}
}
GOEOF

# ==================================================
# 5. Better debug renderer
# ==================================================

cat > internal/graph/debug.go <<'GOEOF'
package graph

import (
	"fmt"
	"sort"
)

func PrintLayout(g *Graph) {

	nodes := make([]*Node, 0, len(g.Nodes))

	for _, node := range g.Nodes {
		nodes = append(nodes, node)
	}

	sort.Slice(
		nodes,
		func(i, j int) bool {

			if nodes[i].Y == nodes[j].Y {
				return nodes[i].X < nodes[j].X
			}

			return nodes[i].Y < nodes[j].Y
		},
	)

	fmt.Println()
	fmt.Println("NODES")
	fmt.Println("------------------------------------------")

	for _, node := range nodes {

		fmt.Printf(
			"%s %-28s x=%-4d y=%-4d shape=%-10s\n",
			node.Icon,
			node.Name,
			node.X,
			node.Y,
			node.Shape,
		)
	}

	fmt.Println()
	fmt.Println("EDGES")
	fmt.Println("------------------------------------------")

	edges := make([]*Edge, 0, len(g.Edges))

	for _, edge := range g.Edges {
		edges = append(edges, edge)
	}

	sort.Slice(
		edges,
		func(i, j int) bool {
			return edges[i].ID < edges[j].ID
		},
	)

	for _, edge := range edges {

		fmt.Printf(
			"%s --[%s]--> %s  style=%s\n",
			edge.Source,
			edge.Relation,
			edge.Target,
			edge.Style,
		)

		fmt.Printf(
			"    path: ",
		)

		for index, point := range edge.Path.Points {

			if index > 0 {
				fmt.Print(" → ")
			}

			fmt.Printf(
				"(%d,%d)",
				point.X,
				point.Y,
			)
		}

		fmt.Println()
	}
}
GOEOF

# ==================================================
# 6. Update main
# ==================================================

cat > main.go <<'GOEOF'
package main

import (
	"context"
	"fmt"
	"log"

	"kranger/internal/graph"
	"kranger/internal/k8s"
)

func main() {

	fmt.Println()
	fmt.Println("==========================================")
	fmt.Println("             󰒋 KRANGER")
	fmt.Println("==========================================")
	fmt.Println()

	fmt.Println("🔌 Connecting to Kubernetes...")

	client, err := k8s.NewClient()
	if err != nil {
		log.Fatalf(
			"❌ Kubernetes connection failed: %v",
			err,
		)
	}

	fmt.Println(
		"🟢 Kubernetes API connection established",
	)

	fmt.Println()

	discovery := k8s.NewDiscovery(client)

	fmt.Println(
		"🔍 Discovering cluster resources...",
	)

	state, err := discovery.Discover(
		context.Background(),
	)

	if err != nil {
		log.Fatalf(
			"❌ Resource discovery failed: %v",
			err,
		)
	}

	fmt.Printf(
		"🟢 Resources discovered: %d relationships\n",
		len(state.Relationships),
	)

	fmt.Println()

	fmt.Println("🏗️ Building graph...")

	clusterGraph := graph.Build(state)

	fmt.Printf(
		"🟢 Graph: %d nodes / %d edges\n",
		clusterGraph.NodeCount(),
		clusterGraph.EdgeCount(),
	)

	fmt.Println()

	fmt.Println("📐 Calculating semantic horizontal layout...")

	// Use a realistic terminal size for now.
	//
	// Bubble Tea will provide the real dimensions once
	// the TUI is implemented.
	config := graph.DefaultLayoutConfig(
		160,
		50,
	)

	graph.Layout(
		clusterGraph,
		config,
	)

	fmt.Println()

	fmt.Println("==========================================")
	fmt.Println("        📐 SEMANTIC LAYOUT V2")
	fmt.Println("==========================================")

	graph.PrintLayout(clusterGraph)

	fmt.Println()
	fmt.Println("==========================================")
	fmt.Println("              🟢 READY")
	fmt.Println("==========================================")
	fmt.Println()
}
GOEOF

# ==================================================
# 7. Add tests
# ==================================================

cat > internal/graph/layout_test.go <<'GOEOF'
package graph

import (
	"testing"

	"kranger/internal/model"
)

func TestSemanticHorizontalLayout(t *testing.T) {

	state := model.NewClusterState()

	state.Deployments = append(
		state.Deployments,
		model.Resource{
			ID:   "Deployment/default/api",
			Kind: model.KindDeployment,
			Name: "api",
		},
	)

	state.ReplicaSets = append(
		state.ReplicaSets,
		model.Resource{
			ID:   "ReplicaSet/default/api-123",
			Kind: model.KindReplicaSet,
			Name: "api-123",
		},
	)

	state.Pods = append(
		state.Pods,
		model.Resource{
			ID:   "Pod/default/api-123-abc",
			Kind: model.KindPod,
			Name: "api-123-abc",
		},
	)

	state.Nodes = append(
		state.Nodes,
		model.Resource{
			ID:   "Node/worker-01",
			Kind: model.KindNode,
			Name: "worker-01",
		},
	)

	state.Relationships = append(
		state.Relationships,

		model.Relationship{
			SourceID: "Deployment/default/api",
			TargetID: "ReplicaSet/default/api-123",
			Type:     model.RelationOwns,
		},

		model.Relationship{
			SourceID: "ReplicaSet/default/api-123",
			TargetID: "Pod/default/api-123-abc",
			Type:     model.RelationOwns,
		},

		model.Relationship{
			SourceID: "Pod/default/api-123-abc",
			TargetID: "Node/worker-01",
			Type:     model.RelationRunsOn,
		},
	)

	g := Build(state)

	Layout(
		g,
		DefaultLayoutConfig(160, 50),
	)

	deployment := g.Nodes["Deployment/default/api"]
	replicaset := g.Nodes["ReplicaSet/default/api-123"]
	pod := g.Nodes["Pod/default/api-123-abc"]
	node := g.Nodes["Node/worker-01"]

	// Workload → ReplicaSet → Pod should move
	// progressively toward the right.
	if deployment.X >= replicaset.X {
		t.Fatalf("deployment should be left of replicaset")
	}

	if replicaset.X >= pod.X {
		t.Fatalf("replicaset should be left of pod")
	}

	// Pod and Node occupy semantic lanes.
	if pod.Y == node.Y {
		t.Fatalf("pod and node should occupy different lanes")
	}

	// Every edge must have a path.
	for _, edge := range g.Edges {

		if len(edge.Path.Points) < 2 {
			t.Fatalf(
				"edge %s has invalid path",
				edge.ID,
			)
		}
	}
}
GOEOF

# ==================================================
# 8. Format
# ==================================================

echo "🎨 Formatting..."

gofmt -w \
	internal/graph/*.go \
	main.go

# ==================================================
# 9. Dependencies
# ==================================================

echo
echo "🧹 Tidying modules..."

go mod tidy

# ==================================================
# 10. Test
# ==================================================

echo
echo "🧪 Running tests..."

go test ./...

# ==================================================
# 11. Build
# ==================================================

echo
echo "🔨 Building..."

go build -o kranger .

echo
echo "=========================================="
echo "       ✅ LAYOUT V2 READY"
echo "=========================================="
echo
echo "Run:"
echo
echo "    ./kranger"
echo

EOF

chmod +x ~/kranger-layout-v2.sh
~/kranger-layout-v2.sh
