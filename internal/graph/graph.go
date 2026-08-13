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
