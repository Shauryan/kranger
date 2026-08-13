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
