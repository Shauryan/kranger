package graph

import (
	"kranger/internal/model"
	"kranger/internal/ui"
)

type Node struct {
	ID           string
	Kind         model.ResourceKind
	Name         string
	Namespace    string
	Status       string
	Age          string
	RestartCount int

	Icon  ui.Icon
	Shape ui.Shape

	X int
	Y int

	Width  int
	Height int
}

func FromResource(resource model.Resource) Node {

	return Node{
		ID:           resource.ID,
		Kind:         resource.Kind,
		Name:         resource.Name,
		Namespace:    resource.Namespace,
		Status:       resource.Status,
		Age:          resource.Age,
		RestartCount: resource.RestartCount,

		Icon:  ui.ForResource(resource.Kind),
		Shape: ui.ShapeForResource(string(resource.Kind)),

		Width:  24,
		Height: 3,
	}
}
