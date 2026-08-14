package graph

import (
	"testing"

	"github.com/Shauryan/kranger/internal/model"
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
