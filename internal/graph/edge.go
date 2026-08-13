package graph

import "kranger/internal/model"

type EdgeStyle string

const (
	EdgeLogical   EdgeStyle = "logical"
	EdgeRuntime   EdgeStyle = "runtime"
	EdgeReference EdgeStyle = "reference"
	EdgeTraffic   EdgeStyle = "traffic"
)

type Edge struct {
	ID string

	Source string
	Target string

	Relation model.RelationshipType

	Style EdgeStyle

	Active bool

	Path EdgePath
}

func FromRelationship(
	relationship model.Relationship,
) Edge {

	style := EdgeLogical

	switch relationship.Type {

	case model.RelationRunsOn:
		style = EdgeRuntime

	case model.RelationSelects:
		style = EdgeTraffic

	case model.RelationMounts,
		model.RelationReferences,
		model.RelationUses:
		style = EdgeReference
	}

	return Edge{
		ID:       relationship.SourceID + "->" + relationship.TargetID,
		Source:   relationship.SourceID,
		Target:   relationship.TargetID,
		Relation: relationship.Type,
		Style:    style,
		Active:   true,
	}
}
