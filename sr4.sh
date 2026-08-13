cd ~/projects/kranger

cat > internal/graph/layout.go <<'EOF'
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

// Layout creates a left-to-right architectural flow.
//
// X = relationship/dependency depth
// Y = semantic resource lane
//
// Example:
//
// Deployment -> ReplicaSet -> Pod -> Node
//
// becomes:
//
// x=2    x=30       x=58      x=86
//
// Deployment -> ReplicaSet -> Pod -> Node
//
// while each resource kind keeps its semantic Y lane.
func Layout(g *Graph, config LayoutConfig) {

	if len(g.Nodes) == 0 {
		return
	}

	layers := calculateLayers(g)

	assignCoordinates(g, layers, config)

	buildEdgePaths(g)
}

// --------------------------------------------------
// Semantic lane
// --------------------------------------------------

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

// --------------------------------------------------
// Calculate horizontal dependency depth
// --------------------------------------------------

func calculateLayers(g *Graph) map[string]int {

	layers := make(map[string]int)

	incoming := make(map[string]int)

	// Start every node at layer 0.
	for id := range g.Nodes {
		layers[id] = 0
		incoming[id] = 0
	}

	// Count incoming relationships.
	for _, edge := range g.Edges {

		if _, ok := g.Nodes[edge.Source]; !ok {
			continue
		}

		if _, ok := g.Nodes[edge.Target]; !ok {
			continue
		}

		incoming[edge.Target]++
	}

	// Nodes without parents are roots.
	queue := make([]string, 0)

	for id, count := range incoming {

		if count == 0 {
			queue = append(queue, id)
		}
	}

	sort.Strings(queue)

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

			// Target must appear to the right of source.
			candidate := currentLayer + 1

			if candidate > layers[target] {
				layers[target] = candidate
			}

			incoming[target]--

			if incoming[target] <= 0 {
				queue = append(queue, target)
			}
		}
	}

	// --------------------------------------------------
	// Handle cycles.
	//
	// Kubernetes ownership graphs should normally be
	// acyclic, but we don't want a malformed graph to
	// break the renderer.
	// --------------------------------------------------

	for id := range g.Nodes {

		if !processed[id] {
			if _, exists := layers[id]; !exists {
				layers[id] = 0
			}
		}
	}

	return layers
}

// --------------------------------------------------
// Coordinates
// --------------------------------------------------

func assignCoordinates(
	g *Graph,
	layers map[string]int,
	config LayoutConfig,
) {

	type positionedNode struct {
		node  *Node
		layer int
		lane  Lane
	}

	nodes := make([]positionedNode, 0, len(g.Nodes))

	for _, node := range g.Nodes {

		layer := layers[node.ID]
		lane := laneFor(node.Kind)

		nodes = append(
			nodes,
			positionedNode{
				node:  node,
				layer: layer,
				lane:  lane,
			},
		)
	}

	// Stable ordering.
	sort.Slice(
		nodes,
		func(i, j int) bool {

			if nodes[i].layer != nodes[j].layer {
				return nodes[i].layer < nodes[j].layer
			}

			if nodes[i].lane != nodes[j].lane {
				return nodes[i].lane < nodes[j].lane
			}

			return nodes[i].node.ID < nodes[j].node.ID
		},
	)

	step :=
		config.NodeWidth +
			config.HorizontalGap

	availableWidth :=
		config.TerminalWidth -
			config.LeftPadding*2

	maxColumns := 1

	if step > 0 {
		maxColumns = availableWidth / step
	}

	if maxColumns < 1 {
		maxColumns = 1
	}

	// Track how many nodes occupy each
	// layer/lane combination.
	occupancy := make(
		map[[2]int]int,
	)

	for _, item := range nodes {

		layer := item.layer
		lane := item.lane

		key := [2]int{
			layer,
			int(lane),
		}

		row := occupancy[key]
		occupancy[key]++

		// Primary horizontal position is the
		// dependency depth.
		column := layer

		// If the graph exceeds terminal width,
		// wrap nodes belonging to the same layer.
		if column >= maxColumns {
			column = column % maxColumns
		}

		item.node.X =
			config.LeftPadding +
				column*step

		// Semantic lane determines Y.
		item.node.Y =
			config.TopPadding +
				int(lane)*config.LaneHeight +
				row*(config.NodeHeight+config.VerticalGap)
	}
}

// --------------------------------------------------
// Edge routing
// --------------------------------------------------

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

		// Normal left-to-right connection.
		if end.X > start.X {

			midX := start.X + (end.X-start.X)/2

			edge.Path = EdgePath{
				Points: []Point{
					start,
					{X: midX, Y: start.Y},
					{X: midX, Y: end.Y},
					end,
				},
			}

			continue
		}

		// Fallback for relationships that point
		// backwards or wrap around.
		//
		// Route downward first so the renderer can
		// still draw the edge without a diagonal.
		midY := start.Y + configRouteGap()

		edge.Path = EdgePath{
			Points: []Point{
				start,
				{X: start.X, Y: midY},
				{X: end.X, Y: midY},
				end,
			},
		}
	}
}

func configRouteGap() int {
	return 2
}

gofmt -w internal/graph/layout.go

echo
echo "🧪 Running tests..."
go test ./...

echo
echo "🔨 Building..."
go build -o kranger .

echo
echo "=========================================="
echo "       ✅ LAYOUT V2.1 FIXED"
echo "=========================================="
