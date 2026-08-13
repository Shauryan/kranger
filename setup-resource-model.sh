#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$HOME/projects/kranger"
cd "$PROJECT_DIR"

echo "=========================================="
echo "   󰒋 KRANGER RESOURCE MODEL FOUNDATION"
echo "=========================================="
echo

mkdir -p internal/model internal/ui

# --------------------------------------------------
# Resource kinds
# --------------------------------------------------

cat > internal/model/resource.go <<'GOEOF'
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
	ID        string
	Kind      ResourceKind
	Name      string
	Namespace string
	Status    string
	Age       string
}
GOEOF

# --------------------------------------------------
# Cluster model
# --------------------------------------------------

cat > internal/model/cluster.go <<'GOEOF'
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
GOEOF

# --------------------------------------------------
# Relationship model
# --------------------------------------------------

cat > internal/model/relationship.go <<'GOEOF'
package model

type RelationshipType string

const (
	RelationOwns       RelationshipType = "owns"
	RelationSelects    RelationshipType = "selects"
	RelationRunsOn     RelationshipType = "runs-on"
	RelationContains   RelationshipType = "contains"
	RelationMounts     RelationshipType = "mounts"
	RelationRoutesTo   RelationshipType = "routes-to"
	RelationUses       RelationshipType = "uses"
	RelationReferences RelationshipType = "references"
)

type Relationship struct {
	SourceID string
	TargetID string
	Type     RelationshipType
}
GOEOF

# --------------------------------------------------
# Technical icons
# --------------------------------------------------

cat > internal/ui/icons.go <<'GOEOF'
package ui

import "kranger/internal/model"

type Icon string

const (
	IconCluster    Icon = "󰒋"
	IconNamespace  Icon = "󰆼"
	IconNode       Icon = "󰻠"
	IconPod        Icon = "󰐂"
	IconContainer  Icon = "󰙳"
	IconDeployment Icon = "󰘦"
	IconReplicaSet Icon = "󰑭"
	IconService    Icon = "󰒍"
	IconIngress    Icon = "󰖟"
	IconNetwork    Icon = "󰖂"
	IconStorage    Icon = "󰋊"
	IconVolume     Icon = "󰗮"
	IconSecret     Icon = "󰌷"
	IconConfigMap  Icon = "󰒓"
)

func ForResource(kind model.ResourceKind) Icon {
	switch kind {
	case model.KindCluster:
		return IconCluster
	case model.KindNamespace:
		return IconNamespace
	case model.KindNode:
		return IconNode
	case model.KindPod:
		return IconPod
	case model.KindContainer:
		return IconContainer
	case model.KindDeployment:
		return IconDeployment
	case model.KindReplicaSet:
		return IconReplicaSet
	case model.KindService:
		return IconService
	case model.KindIngress:
		return IconIngress
	case model.KindConfigMap:
		return IconConfigMap
	case model.KindSecret:
		return IconSecret
	case model.KindPVC:
		return IconStorage
	case model.KindPV:
		return IconVolume
	default:
		return "◆"
	}
}
GOEOF

# --------------------------------------------------
# Shapes
# --------------------------------------------------

cat > internal/ui/shapes.go <<'GOEOF'
package ui

type Shape string

const (
	ShapeRectangle Shape = "rectangle"
	ShapeRounded   Shape = "rounded"
	ShapeCircle    Shape = "circle"
	ShapeTriangle  Shape = "triangle"
	ShapeHexagon   Shape = "hexagon"
	ShapeCylinder  Shape = "cylinder"
)

func ShapeForResource(kind string) Shape {
	switch kind {
	case "Node":
		return ShapeCircle

	case "Pod":
		return ShapeRounded

	case "Deployment":
		return ShapeRounded

	case "Service":
		return ShapeHexagon

	case "Ingress":
		return ShapeTriangle

	case "PersistentVolume":
		return ShapeCylinder

	default:
		return ShapeRectangle
	}
}
GOEOF

# --------------------------------------------------
# Semantic status
# --------------------------------------------------

cat > internal/ui/status.go <<'GOEOF'
package ui

type Status string

const (
	StatusHealthy Status = "healthy"
	StatusWarning Status = "warning"
	StatusFailed  Status = "failed"
	StatusUnknown Status = "unknown"
)

const (
	IconHealthy = "●"
	IconWarning = "◆"
	IconFailed  = "✖"
	IconUnknown = "?"
)
GOEOF

# --------------------------------------------------
# Verify
# --------------------------------------------------

echo
echo "🧹 Tidying Go modules..."
go mod tidy

echo
echo "🧪 Running tests..."
go test ./...

echo
echo "🔨 Building kranger..."
go build -o kranger .

echo
echo "=========================================="
echo "        ✅ FOUNDATION UPDATED"
echo "=========================================="
echo
echo "Created:"
echo
echo "  internal/model/"
echo "    ├── resource.go"
echo "    ├── cluster.go"
echo "    └── relationship.go"
echo
echo "  internal/ui/"
echo "    ├── icons.go"
echo "    ├── shapes.go"
echo "    └── status.go"
echo
echo "Binary:"
echo "  $PROJECT_DIR/kranger"
echo
