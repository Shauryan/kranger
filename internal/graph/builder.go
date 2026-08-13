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
