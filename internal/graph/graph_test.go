package graph

import (
	"testing"

	"github.com/Shauryan/kranger/internal/model"
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
