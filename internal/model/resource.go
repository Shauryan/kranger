package model

type ResourceKind string

const (
	KindCluster     ResourceKind = "Cluster"
	KindNamespace   ResourceKind = "Namespace"
	KindNode        ResourceKind = "Node"
	KindPod         ResourceKind = "Pod"
	KindContainer   ResourceKind = "Container"
	KindDeployment  ResourceKind = "Deployment"
	KindReplicaSet  ResourceKind = "ReplicaSet"
	KindStatefulSet ResourceKind = "StatefulSet"
	KindDaemonSet   ResourceKind = "DaemonSet"
	KindService     ResourceKind = "Service"
	KindIngress     ResourceKind = "Ingress"
	KindConfigMap   ResourceKind = "ConfigMap"
	KindSecret      ResourceKind = "Secret"
	KindPVC         ResourceKind = "PersistentVolumeClaim"
	KindPV          ResourceKind = "PersistentVolume"
)

type Resource struct {
	ID           string
	Kind         ResourceKind
	Name         string
	Namespace    string
	Status       string
	Age          string
	RestartCount int
}
