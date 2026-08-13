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

}
