package render

import (
	"sort"

	"github.com/Shauryan/kranger/internal/graph"
	"github.com/Shauryan/kranger/internal/model"
)

type CompactGroup struct {
	Kind      model.ResourceKind
	Namespace string
	Nodes     []*graph.Node
	Count     int
}

type CompactNamespace struct {
	Name   string
	Groups []*CompactGroup
}

type CompactModel struct {
	Namespaces []*CompactNamespace
	Node       *graph.Node
}

func BuildCompactModel(g *graph.Graph) *CompactModel {

	namespaceMap := map[string]*CompactNamespace{}

	var node *graph.Node

	for _, n := range g.Nodes {

		if n.Kind == model.KindNode {
			node = n
			continue
		}

		if n.Kind == model.KindNamespace {

			if _, ok := namespaceMap[n.Name]; !ok {
				namespaceMap[n.Name] = &CompactNamespace{
					Name: n.Name,
				}
			}

			continue
		}

		ns := n.Namespace

		if _, ok := namespaceMap[ns]; !ok {
			namespaceMap[ns] = &CompactNamespace{
				Name: ns,
			}
		}
	}

	groupMap := map[string]*CompactGroup{}

	for _, n := range g.Nodes {

		if n.Kind == model.KindNamespace ||
			n.Kind == model.KindNode {
			continue
		}

		key := n.Namespace + "/" + string(n.Kind)

		group, ok := groupMap[key]

		if !ok {
			group = &CompactGroup{
				Kind:      n.Kind,
				Namespace: n.Namespace,
			}

			groupMap[key] = group
		}

		group.Nodes = append(group.Nodes, n)
	}

	for _, group := range groupMap {

		group.Count = len(group.Nodes)

		sort.Slice(group.Nodes, func(i, j int) bool {
			return group.Nodes[i].Name < group.Nodes[j].Name
		})
	}

	for _, group := range groupMap {

		ns := namespaceMap[group.Namespace]

		ns.Groups = append(
			ns.Groups,
			group,
		)
	}

	namespaces := make(
		[]*CompactNamespace,
		0,
		len(namespaceMap),
	)

	for _, ns := range namespaceMap {

		sort.Slice(ns.Groups, func(i, j int) bool {
			return compactPriority(ns.Groups[i].Kind) <
				compactPriority(ns.Groups[j].Kind)
		})

		namespaces = append(namespaces, ns)
	}

	sort.Slice(namespaces, func(i, j int) bool {
		return namespaces[i].Name < namespaces[j].Name
	})

	return &CompactModel{
		Namespaces: namespaces,
		Node:       node,
	}
}

func compactPriority(kind model.ResourceKind) int {

	switch kind {

	case model.KindDeployment:
		return 1

	case model.KindReplicaSet:
		return 2

	case model.KindService:
		return 3

	case model.KindPod:
		return 4

	default:
		return 10
	}
}
