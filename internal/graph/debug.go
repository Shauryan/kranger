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
