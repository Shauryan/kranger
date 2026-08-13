cat > ~/kranger-graph.sh <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$HOME/projects/kranger"

cd "$PROJECT_DIR"

echo "=========================================="
echo "        󰒋 KRANGER GRAPH ENGINE"
echo "=========================================="
echo

mkdir -p internal/graph

# --------------------------------------------------
# Graph node
# --------------------------------------------------

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

		Width:  20,
		Height: 3,
	}
}
GOEOF

# --------------------------------------------------
# Graph edge
# --------------------------------------------------

cat > internal/graph/edge.go <<'GOEOF'
package graph

import "kranger/internal/model"

type EdgeStyle string

const (
	EdgeLogical  EdgeStyle = "logical"
	EdgeRuntime  EdgeStyle = "runtime"
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

# --------------------------------------------------
# Graph
# --------------------------------------------------

cat > internal/graph/graph.go <<'GOEOF'
package graph

type Graph struct {
	Nodes map[string]*Node
	Edges map[string]*Edge
}

func New() *Graph {
	return &Graph{
		Nodes: make(map[string]*Node),
		Edges: make(map[string]*Edge),
	}
}

func (g *Graph) AddNode(node Node) {
	g.Nodes[node.ID] = &node
}

func (g *Graph) AddEdge(edge Edge) {
	g.Edges[edge.ID] = &edge
}

func (g *Graph) NodeCount() int {
	return len(g.Nodes)
}

func (g *Graph) EdgeCount() int {
	return len(g.Edges)
}
GOEOF

# --------------------------------------------------
# Graph builder
# --------------------------------------------------

cat > internal/graph/builder.go <<'GOEOF'
package graph

import "kranger/internal/model"

func Build(state *model.ClusterState) *Graph {

	graph := New()

	// --------------------------------------------------
	// Add resources
	// --------------------------------------------------

	for _, resource := range state.Nodes {
		graph.AddNode(FromResource(resource))
	}

	for _, resource := range state.Namespaces {
		graph.AddNode(FromResource(resource))
	}

	for _, resource := range state.Pods {
		graph.AddNode(FromResource(resource))
	}

	for _, resource := range state.Deployments {
		graph.AddNode(FromResource(resource))
	}

	for _, resource := range state.ReplicaSets {
		graph.AddNode(FromResource(resource))
	}

	for _, resource := range state.Services {
		graph.AddNode(FromResource(resource))
	}

	// --------------------------------------------------
	// Add relationships
	// --------------------------------------------------

	for _, relationship := range state.Relationships {

		// Ignore relationships whose resources aren't
		// currently represented as graph nodes.

		if _, exists := graph.Nodes[relationship.SourceID]; !exists {
			continue
		}

		if _, exists := graph.Nodes[relationship.TargetID]; !exists {
			continue
		}

		graph.AddEdge(
			FromRelationship(relationship),
		)
	}

	return graph
}
GOEOF

# --------------------------------------------------
# Add graph test
# --------------------------------------------------

cat > internal/graph/graph_test.go <<'GOEOF'
package graph

import (
	"testing"

	"kranger/internal/model"
)

func TestBuildGraph(t *testing.T) {

	state := model.NewClusterState()

	state.Nodes = append(
		state.Nodes,
		model.Resource{
			ID:     "Node/worker-01",
			Kind:   model.KindNode,
			Name:   "worker-01",
			Status: "True",
		},
	)

	state.Pods = append(
		state.Pods,
		model.Resource{
			ID:     "Pod/default/api",
			Kind:   model.KindPod,
			Name:   "api",
			Status: "Running",
		},
	)

	state.Relationships = append(
		state.Relationships,
		model.Relationship{
			SourceID: "Pod/default/api",
			TargetID: "Node/worker-01",
			Type:     model.RelationRunsOn,
		},
	)

	graph := Build(state)

	if graph.NodeCount() != 2 {
		t.Fatalf(
			"expected 2 nodes, got %d",
			graph.NodeCount(),
		)
	}

	if graph.EdgeCount() != 1 {
		t.Fatalf(
			"expected 1 edge, got %d",
			graph.EdgeCount(),
		)
	}
}
GOEOF

# --------------------------------------------------
# Format
# --------------------------------------------------

echo "🎨 Formatting..."

gofmt -w internal/graph/*.go

# --------------------------------------------------
# Tidy
# --------------------------------------------------

echo
echo "🧹 Tidying..."

go mod tidy

# --------------------------------------------------
# Test
# --------------------------------------------------

echo
echo "🧪 Testing..."

go test ./...

# --------------------------------------------------
# Build
# --------------------------------------------------

echo
echo "🔨 Building..."

go build -o kranger .

echo
echo "=========================================="
echo "        🟢 GRAPH ENGINE READY"
echo "=========================================="
echo

echo "Graph package:"
echo
echo "  internal/graph/"
echo "  ├── graph.go"
echo "  ├── node.go"
echo "  ├── edge.go"
echo "  ├── builder.go"
echo "  └── graph_test.go"
echo

echo "Next:"
echo
echo "  Horizontal layout engine"
echo "  ↓"
echo "  Terminal renderer"
echo "  ↓"
echo "  Bubble Tea TUI"
echo

EOF

chmod +x ~/kranger-graph.sh
~/kranger-graph.sh
