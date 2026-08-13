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
