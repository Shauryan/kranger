package render

import (
	"fmt"
	"strings"

	"github.com/Shauryan/kranger/internal/graph"
)

func compactNodeLabel(
	node *graph.Node,
) string {

	switch node.Kind {

	case "Pod":
		return "Pod"

	case "ReplicaSet":
		return "RS"

	case "Deployment":
		return "Deploy"

	case "Service":
		return "SVC"

	default:
		return node.Name
	}
}

func DrawCompactGroup(
	canvas *Canvas,
	group *CompactGroup,
	x int,
	y int,
	width int,
) {

	node := group.Nodes[0]

	label := compactNodeLabel(node)

	color := White

	// Ready-ratio bar. Shown for kinds whose Status field
	// carries real ready/not-ready data today (Pod,
	// Deployment, ReplicaSet). Service is excluded until
	// discovery reports real Endpoint-readiness instead of
	// an always-empty Status.
	showsHealth := group.Kind == "Pod" ||
		group.Kind == "Deployment" ||
		group.Kind == "ReplicaSet" ||
		group.Kind == "Service"

	if showsHealth {
		ready := 0
		total := len(group.Nodes)
		for _, n := range group.Nodes {
			if isNodeReady(n.Status) {
				ready++
			}
		}

		const barWidth = 4
		filled := 0
		if total > 0 {
			filled = (ready * barWidth) / total
		}
		bar := "[" +
			strings.Repeat("\u2588", filled) +
			strings.Repeat("\u2591", barWidth-filled) +
			"]"

		restarts := 0
		for _, n := range group.Nodes {
			restarts += n.RestartCount
		}

		label += fmt.Sprintf(
			" %s %d/%d",
			bar,
			ready,
			total,
		)

		if restarts > 0 {
			label += fmt.Sprintf(" \u27f3%d", restarts)
		}

		switch {
		case ready == total:
			color = Green
		case ready == 0:
			color = Red
		default:
			color = Yellow
		}
	}

	canvas.Set(
		x,
		y,
		'╭',
		color,
	)

	for i := 1; i < width-1; i++ {

		canvas.Set(
			x+i,
			y,
			Horizontal,
			color,
		)
	}

	canvas.Set(
		x+width-1,
		y,
		'╮',
		color,
	)

	canvas.Set(
		x,
		y+1,
		Vertical,
		color,
	)

	// Truncate by display width, not rune count, so labels
	// containing double-width runes (if any appear again in
	// the future) don't overflow the box.
	maxWidth := width - 2
	runes := []rune(label)

	for displayWidth(string(runes)) > maxWidth && len(runes) > 0 {
		runes = runes[:len(runes)-1]
	}

	canvas.Write(
		x+1,
		y+1,
		string(runes),
		color,
	)

	canvas.Set(
		x+width-1,
		y+1,
		Vertical,
		color,
	)

	canvas.Set(
		x,
		y+2,
		'╰',
		color,
	)

	for i := 1; i < width-1; i++ {

		canvas.Set(
			x+i,
			y+2,
			Horizontal,
			color,
		)
	}

	canvas.Set(
		x+width-1,
		y+2,
		'╯',
		color,
	)
}

// isNodeReady interprets the live Status string captured
// during discovery. Pods use a phase string ("Running",
// "Pending", ...); Deployments/ReplicaSets use a
// "<ready>/<desired> ready" summary; Nodes use the Ready
// condition ("True"/"False").
func isNodeReady(status string) bool {
	switch status {
	case "Running", "True", "Active":
		return true
	}

	var ready, desired int
	if n, err := fmt.Sscanf(status, "%d/%d ready", &ready, &desired); n == 2 && err == nil {
		return desired > 0 && ready == desired
	}

	return false
}
