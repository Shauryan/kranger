package model

type Cluster struct {
	Name        string
	Version     string
	Namespaces  int
	Nodes       int
	Pods        int
	Deployments int
	Services    int
}
