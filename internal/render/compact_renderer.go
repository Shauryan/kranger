package render

import (
	"fmt"
	"strconv"

	"github.com/Shauryan/kranger/internal/graph"
)

func RenderCompact(
	g *graph.Graph,
	width int,
	height int,
) string {

	model := BuildCompactModel(g)

	config := DefaultCompactLayout(width)

	layout := LayoutCompact(
		model,
		config,
	)

	statusHeight := 4
	topologyHeight := layout.Height

	canvasHeight := topologyHeight + statusHeight

	if height > canvasHeight {
		canvasHeight = height
	}

	canvas := NewCanvas(
		width,
		canvasHeight,
	)

	// Namespace containers.
	for _, ns := range model.Namespaces {

		pos := layout.Namespaces[ns.Name]

		drawCompactNamespace(
			canvas,
			ns,
			pos,
			layout,
			config,
		)
	}

	DrawCompactRelations(
		canvas,
		g,
		model,
		layout,
	)

	// Compact resource groups.
	for group, pos := range layout.Groups {

		DrawCompactGroup(
			canvas,
			group,
			pos.X,
			pos.Y,
			config.GroupWidth,
		)
	}

	// Node.
	if model.Node != nil {

		pos := layout.Node

		drawCompactNode(
			canvas,
			model.Node,
			pos.X,
			pos.Y,
		)
	}

	drawCompactStatus(
		canvas,
		g,
		width,
		topologyHeight,
	)

	return canvas.String()
}

func drawCompactNamespace(
	canvas *Canvas,
	ns *CompactNamespace,
	pos CompactPosition,
	layout CompactLayout,
	config CompactLayoutConfig,
) {

	x := pos.X
	y := pos.Y

	width := config.Width - 4

	if width > 110 {
		width = 110
	}

	height := 2

	if len(ns.Groups) > 0 {
		height = 3
	}

	for _, group := range ns.Groups {
		if groupPos, ok := layout.Groups[group]; ok {

			bottom := groupPos.Y + 2
			required := bottom - y + 1

			if required > height {
				height = required
			}
		}
	}

	// Top.
	canvas.Set(x, y, '╭', Gray)

	title := "─ " + ns.Name + " "

	canvas.Write(
		x+1,
		y,
		title,
		Gray,
	)

	for px := x + 1 + displayWidth(title); px < x+width; px++ {
		canvas.Set(px, y, '─', Gray)
	}

	canvas.Set(x+width, y, '╮', Gray)

	// Sides.
	for py := y + 1; py < y+height; py++ {

		canvas.Set(x, py, '│', Gray)
		canvas.Set(x+width, py, '│', Gray)
	}

	// Bottom.
	canvas.Set(x, y+height, '╰', Gray)

	for px := x + 1; px < x+width; px++ {
		canvas.Set(px, y+height, '─', Gray)
	}

	canvas.Set(x+width, y+height, '╯', Gray)
}

func drawCompactNode(
	canvas *Canvas,
	node *graph.Node,
	x int,
	y int,
) {

	// Node color reflects the live Ready condition
	// captured during discovery.
	color := Green
	if node.Status != "True" {
		color = Red
	}

	canvas.Write(
		x,
		y,
		"╭──────────────╮",
		color,
	)

	status := "Ready"
	if node.Status != "True" {
		status = "Down "
	}

	// Build the interior to exactly 14 columns (matching
	// the 14-dash border). No icon here now, so plain rune
	// counting is safe.
	const boxInner = 14
	text := fmt.Sprintf(" Node %-5s", status)
	for len([]rune(text)) < boxInner {
		text += " "
	}

	label := "│" + text + "│"

	canvas.Write(
		x,
		y+1,
		label,
		color,
	)

	canvas.Write(
		x,
		y+2,
		"╰──────────────╯",
		color,
	)
}

func drawCompactStatus(
	canvas *Canvas,
	g *graph.Graph,
	width int,
	y int,
) {

	x := 2
	width = width - x*2

	if width > 118 {
		width = 118
	}

	if width < 60 {
		width = 60
	}

	top := y

	canvas.Set(x, top, '╭', Gray)

	for i := 1; i < width-1; i++ {
		canvas.Set(x+i, top, '─', Gray)
	}

	canvas.Set(x+width-1, top, '╮', Gray)

	canvas.Set(x, top+1, '│', Gray)
	canvas.Set(x+width-1, top+1, '│', Gray)

	canvas.Set(x, top+2, '│', Gray)
	canvas.Set(x+width-1, top+2, '│', Gray)

	canvas.Set(x, top+3, '╰', Gray)

	for i := 1; i < width-1; i++ {
		canvas.Set(x+i, top+3, '─', Gray)
	}

	canvas.Set(x+width-1, top+3, '╯', Gray)

	namespaceCount := 0
	nodeCount := 0
	deploymentCount := 0
	replicaSetCount := 0
	podCount := 0
	serviceCount := 0

	for _, node := range g.Nodes {

		switch node.Kind {

		case "Namespace":
			namespaceCount++

		case "Node":
			nodeCount++

		case "Deployment":
			deploymentCount++

		case "ReplicaSet":
			replicaSetCount++

		case "Pod":
			podCount++

		case "Service":
			serviceCount++
		}
	}

	resourceCount := len(g.Nodes)

	line1 :=
		"CLUSTER " + strconv.Itoa(resourceCount) +
			"   NS " + strconv.Itoa(namespaceCount) +
			"   NODE " + strconv.Itoa(nodeCount) +
			"   DEPLOY " + strconv.Itoa(deploymentCount) +
			"   RS " + strconv.Itoa(replicaSetCount) +
			"   POD " + strconv.Itoa(podCount)

	canvas.Write(
		x+2,
		top+1,
		line1,
		White,
	)

	line2 :=
		"SVC " + strconv.Itoa(serviceCount) +
			"   " + strconv.Itoa(len(g.Edges)) + " EDGES   "

	canvas.Write(
		x+2,
		top+2,
		line2,
		White,
	)

	aquaX := x + 2 + displayWidth(line2)

	canvas.Write(
		aquaX,
		top+2,
		"═ AQUA RUNTIME / TRAFFIC",
		BrightAqua,
	)

	liveText := "   ● LIVE"

	liveX := aquaX +
		displayWidth("═ AQUA RUNTIME / TRAFFIC")

	canvas.Write(
		liveX,
		top+2,
		liveText,
		Green,
	)

	legend :=
		"─ STRUCTURE   · REFERENCE"

	legendX :=
		x + width -
			displayWidth(legend) -
			2

	if legendX < x+2 {
		legendX = x + 2
	}

	canvas.Write(
		legendX,
		top+2,
		legend,
		Gray,
	)
}
