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
