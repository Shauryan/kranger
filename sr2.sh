cd ~/projects/kranger

cat > ~/kranger-layout.sh <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$HOME/projects/kranger"

cd "$PROJECT_DIR"

echo "=========================================="
echo "       󰒋 KRANGER HORIZONTAL LAYOUT"
echo "=========================================="
echo

mkdir -p internal/graph

# --------------------------------------------------
# Layout configuration
# --------------------------------------------------

cat > internal/graph/layout.go <<'GOEOF'
package graph

import (
	"sort"
)

type LayoutConfig struct {
	TerminalWidth int

	NodeWidth  int
	NodeHeight int

	HorizontalGap int
	VerticalGap   int

	LeftPadding int
	TopPadding  int
}

func DefaultLayoutConfig(width int) LayoutConfig {
	return LayoutConfig{
		TerminalWidth: width,

		NodeWidth: 22,
		NodeHeight: 3,

		HorizontalGap: 8,
		VerticalGap:   3,

		LeftPadding: 2,
		TopPadding:  2,
	}
}

// Layout arranges graph nodes from left to right.
//
// The algorithm assigns nodes to horizontal layers based on
// their relationship depth.
//
// Example:
//
// Deployment -> ReplicaSet -> Pod -> Node
//
// becomes:
//
// Layer 0       Layer 1        Layer 2        Layer 3
// Deployment -> ReplicaSet -> Pod -> Node
func Layout(g *Graph, config LayoutConfig) {

	if len(g.Nodes) == 0 {
		return
	}

	layers := calculateLayers(g)

	assignCoordinates(g, layers, config)
}

func calculateLayers(g *Graph) map[string]int {

	layers := make(map[string]int)

	// --------------------------------------------------
	// Calculate incoming edge count
	// --------------------------------------------------

	incoming := make(map[string]int)

	for id := range g.Nodes {
		incoming[id] = 0
	}

	for _, edge := range g.Edges {

		if _, ok := g.Nodes[edge.Source]; !ok {
			continue
		}

		if _, ok := g.Nodes[edge.Target]; !ok {
			continue
		}

		incoming[edge.Target]++
	}

	// --------------------------------------------------
	// Nodes with no incoming edges start at layer 0
	// --------------------------------------------------

	queue := make([]string, 0)

	for id, count := range incoming {

		if count == 0 {
			queue = append(queue, id)
			layers[id] = 0
		}
	}

	// Stable ordering
	sort.Strings(queue)

	// --------------------------------------------------
	// Traverse graph
	// --------------------------------------------------

	processed := make(map[string]bool)

	for len(queue) > 0 {

		current := queue[0]
		queue = queue[1:]

		if processed[current] {
			continue
		}

		processed[current] = true

		currentLayer := layers[current]

		for _, edge := range g.Edges {

			if edge.Source != current {
				continue
			}

			target := edge.Target

			if _, exists := g.Nodes[target]; !exists {
				continue
			}

			nextLayer := currentLayer + 1

			if existing, exists := layers[target]; !exists ||
				nextLayer > existing {

				layers[target] = nextLayer
			}

			incoming[target]--

			if incoming[target] <= 0 {
				queue = append(queue, target)
			}
		}
	}

	// --------------------------------------------------
	// Handle cycles / disconnected nodes
	// --------------------------------------------------

	for id := range g.Nodes {

		if _, exists := layers[id]; !exists {
			layers[id] = 0
		}
	}

	return layers
}

func assignCoordinates(
	g *Graph,
	layers map[string]int,
	config LayoutConfig,
) {

	layerNodes := make(map[int][]*Node)

	maxLayer := 0

	for id, layer := range layers {

		node, exists := g.Nodes[id]

		if !exists {
			continue
		}

		layerNodes[layer] = append(
			layerNodes[layer],
			node,
		)

		if layer > maxLayer {
			maxLayer = layer
		}
	}

	// --------------------------------------------------
	// Sort nodes for stable output
	// --------------------------------------------------

	for layer := range layerNodes {

		sort.Slice(
			layerNodes[layer],
			func(i, j int) bool {
				return layerNodes[layer][i].ID <
					layerNodes[layer][j].ID
			},
		)
	}

	// --------------------------------------------------
	// Calculate horizontal spacing
	// --------------------------------------------------

	step := config.NodeWidth + config.HorizontalGap

	availableWidth := config.TerminalWidth -
		config.LeftPadding*2

	maxColumns := 1

	if step > 0 {
		maxColumns = availableWidth / step
	}

	if maxColumns < 1 {
		maxColumns = 1
	}

	// --------------------------------------------------
	// Assign coordinates
	// --------------------------------------------------

	for layer := 0; layer <= maxLayer; layer++ {

		nodes := layerNodes[layer]

		for index, node := range nodes {

			column := layer

			row := index

			// If the graph is wider than the terminal,
			// wrap additional layers into rows.
			if column >= maxColumns {
				column = column % maxColumns
			}

			node.X =
				config.LeftPadding +
				column*step

			node.Y =
				config.TopPadding +
				row*(config.NodeHeight+config.VerticalGap)
		}
	}
}
GOEOF

# --------------------------------------------------
# Layout test
# --------------------------------------------------

cat > internal/graph/layout_test.go <<'GOEOF'
package graph

import (
	"testing"

	"kranger/internal/model"
)

func TestHorizontalLayout(t *testing.T) {

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

	graph := Build(state)

	config := DefaultLayoutConfig(160)

	Layout(graph, config)

	deployment := graph.Nodes["Deployment/default/api"]
	replicaset := graph.Nodes["ReplicaSet/default/api-123"]
	pod := graph.Nodes["Pod/default/api-123-abc"]
	node := graph.Nodes["Node/worker-01"]

	if deployment.X >= replicaset.X {
		t.Fatalf(
			"deployment should be left of replicaset: %d >= %d",
			deployment.X,
			replicaset.X,
		)
	}

	if replicaset.X >= pod.X {
		t.Fatalf(
			"replicaset should be left of pod: %d >= %d",
			replicaset.X,
			pod.X,
		)
	}

	if pod.X >= node.X {
		t.Fatalf(
			"pod should be left of node: %d >= %d",
			pod.X,
			node.X,
		)
	}
}
GOEOF

# --------------------------------------------------
# Layout visualization helper
# --------------------------------------------------

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

	for _, node := range nodes {

		fmt.Printf(
			"%s %-18s x=%-4d y=%-4d shape=%s\n",
			node.Icon,
			node.Name,
			node.X,
			node.Y,
			node.Shape,
		)
	}
}
GOEOF

# --------------------------------------------------
# Update main to show graph coordinates
# --------------------------------------------------

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

	fmt.Println()

	fmt.Println("🏗️ Building graph...")

	clusterGraph := graph.Build(state)

	fmt.Printf(
		"🟢 Graph: %d nodes / %d edges\n",
		clusterGraph.NodeCount(),
		clusterGraph.EdgeCount(),
	)

	fmt.Println()

	fmt.Println("📐 Calculating horizontal layout...")

	config := graph.DefaultLayoutConfig(160)

	graph.Layout(
		clusterGraph,
		config,
	)

	fmt.Println()

	fmt.Println("==========================================")
	fmt.Println("        📐 HORIZONTAL LAYOUT")
	fmt.Println("==========================================")
	fmt.Println()

	graph.PrintLayout(clusterGraph)

	fmt.Println()
	fmt.Println("==========================================")
	fmt.Println("              🟢 READY")
	fmt.Println("==========================================")
	fmt.Println()
}
GOEOF

# --------------------------------------------------
# Format
# --------------------------------------------------

echo "🎨 Formatting..."

gofmt -w \
	internal/graph/*.go \
	main.go

# --------------------------------------------------
# Dependencies
# --------------------------------------------------

echo
echo "🧹 Tidying modules..."

go mod tidy

# --------------------------------------------------
# Tests
# --------------------------------------------------

echo
echo "🧪 Running tests..."

go test ./...

# --------------------------------------------------
# Build
# --------------------------------------------------

echo
echo "🔨 Building..."

go build -o kranger .

echo
echo "=========================================="
echo "       ✅ HORIZONTAL LAYOUT READY"
echo "=========================================="
echo
echo "Run:"
echo
echo "  ./kranger"
echo
EOF

chmod +x ~/kranger-layout.sh
~/kranger-layout.sh
