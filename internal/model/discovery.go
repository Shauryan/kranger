package model

type ClusterState struct {
	Nodes         []Resource
	Namespaces    []Resource
	Pods          []Resource
	Deployments   []Resource
	ReplicaSets   []Resource
	Services      []Resource
	StatefulSets  []Resource
	Relationships []Relationship
}

func NewClusterState() *ClusterState {
	return &ClusterState{
		Nodes:         []Resource{},
		Namespaces:    []Resource{},
		Pods:          []Resource{},
		Deployments:   []Resource{},
		ReplicaSets:   []Resource{},
		Services:      []Resource{},
		StatefulSets:  []Resource{},
		Relationships: []Relationship{},
	}
}
