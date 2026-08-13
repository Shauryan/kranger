package render

import (
	"kranger/internal/graph"
	"kranger/internal/model"
)

type CompactRelation struct {
	From *CompactGroup
	To   *CompactGroup

	Style graph.EdgeStyle
}

func BuildCompactRelations(
	g *graph.Graph,
	m *CompactModel,
	layout CompactLayout,
) []CompactRelation {

	var result []CompactRelation

	for _, ns := range m.Namespaces {

		var deployments *CompactGroup
		var replicasets *CompactGroup
		var services *CompactGroup
		var pods *CompactGroup

		for _, group := range ns.Groups {

			switch group.Kind {

			case model.KindDeployment:
				deployments = group

			case model.KindReplicaSet:
				replicasets = group

			case model.KindService:
				services = group

			case model.KindPod:
				pods = group
			}
		}

		// Deployment -> ReplicaSet
		if deployments != nil && replicasets != nil {

			result = append(
				result,
				CompactRelation{
					From:  deployments,
					To:    replicasets,
					Style: graph.EdgeLogical,
				},
			)
		}

		// ReplicaSet -> Pods
		if replicasets != nil && pods != nil {

			result = append(
				result,
				CompactRelation{
					From:  replicasets,
					To:    pods,
					Style: graph.EdgeLogical,
				},
			)
		}

		// Service -> Pods
		if services != nil && pods != nil {

			result = append(
				result,
				CompactRelation{
					From:  services,
					To:    pods,
					Style: graph.EdgeTraffic,
				},
			)
		}
	}

	// Pod -> Node is represented once per namespace that
	// actually has pods, since pods can be spread across
	// multiple namespaces. A CompactGroup may represent
	// multiple actual Pods, e.g. "Pod ×9".
	if m.Node != nil {

		for _, ns := range m.Namespaces {

			for _, group := range ns.Groups {

				if group.Kind == model.KindPod {

					result = append(
						result,
						CompactRelation{
							From:  group,
							To:    nil,
							Style: graph.EdgeRuntime,
						},
					)

					break
				}
			}
		}
	}

	return result
}

func DrawCompactRelations(
	canvas *Canvas,
	g *graph.Graph,
	m *CompactModel,
	layout CompactLayout,
) {

	relations := BuildCompactRelations(
		g,
		m,
		layout,
	)

	for _, relation := range relations {

		if relation.From == nil {
			continue
		}

		from, ok := layout.Groups[relation.From]

		if !ok {
			continue
		}

		// Pod -> Node aggregation.
		if relation.To == nil {

			if m.Node == nil {
				continue
			}

			drawRuntimeToNode(
				canvas,
				from,
				layout.Node,
			)

			continue
		}

		to, ok := layout.Groups[relation.To]

		if !ok {
			continue
		}

		drawCompactRelation(
			canvas,
			from,
			to,
			relation.Style,
		)
	}
}

func drawCompactRelation(
	canvas *Canvas,
	from CompactPosition,
	to CompactPosition,
	style graph.EdgeStyle,
) {

	// Group boxes are 22 characters wide and 3 rows high.
	const boxWidth = 22

	fromY := from.Y + 1
	toY := to.Y + 1

	var horizontal, vertical, arrowRight, arrowLeft rune
	var color string

	switch style {

	case graph.EdgeTraffic:
		horizontal = DoubleHorizontal
		vertical = DoubleVertical
		arrowRight = ArrowRight
		arrowLeft = ArrowLeft
		color = BrightAqua

	case graph.EdgeRuntime:
		horizontal = DoubleHorizontal
		vertical = DoubleVertical
		arrowRight = ArrowRight
		arrowLeft = ArrowLeft
		color = Aqua

	default:
		horizontal = Horizontal
		vertical = Vertical
		arrowRight = ArrowRight
		arrowLeft = ArrowLeft
		color = White
	}

	// --------------------------------------------------
	// Same row: direction-aware straight line.
	// --------------------------------------------------

	if fromY == toY {

		fromX := from.X + boxWidth
		toX := to.X
		arrow := arrowRight
		step := 1

		if toX < fromX {
			// Target is to the left of source; exit from the
			// source's left edge and enter the target's right edge.
			fromX = from.X
			toX = to.X + boxWidth
			step = -1
			arrow = arrowLeft
		}

		for x := fromX; x != toX; x += step {
			canvas.Set(x, fromY, horizontal, color)
		}

		canvas.Set(toX, toY, arrow, color)
		return
	}

	// --------------------------------------------------
	// Different rows: route via a vertical channel chosen
	// relative to where the target actually is, instead of
	// always assuming it's to the right.
	// --------------------------------------------------

	fromLeft := from.X
	fromRight := from.X + boxWidth
	toLeft := to.X
	toRight := to.X + boxWidth

	var fromX, toX, midX int
	arrow := arrowRight

	switch {

	case toLeft >= fromRight:
		// Target is cleanly to the right.
		fromX = fromRight
		toX = toLeft
		midX = fromX + (toX-fromX)/2

	case toRight <= fromLeft:
		// Target is cleanly to the left.
		fromX = fromLeft
		toX = toRight
		midX = fromX - (fromX-toX)/2
		arrow = arrowLeft

	default:
		// Boxes overlap horizontally (e.g. one sits directly
		// above/below the other, same column). Route out past
		// whichever box extends furthest right, then back in.
		fromX = fromRight
		toX = toRight

		channel := fromRight
		if toRight > channel {
			channel = toRight
		}

		midX = channel + 2
	}

	hStep1 := 1
	if midX < fromX {
		hStep1 = -1
	}

	for x := fromX; x != midX; x += hStep1 {
		canvas.Set(x, fromY, horizontal, color)
	}

	vStep := 1
	if toY < fromY {
		vStep = -1
	}

	for y := fromY; y != toY; y += vStep {
		canvas.Set(midX, y, vertical, color)
	}

	hStep2 := 1
	if toX < midX {
		hStep2 = -1
	}

	for x := midX; x != toX; x += hStep2 {
		canvas.Set(x, toY, horizontal, color)
	}

	canvas.Set(toX, toY, arrow, color)
}

func drawRuntimeToNode(
	canvas *Canvas,
	from CompactPosition,
	node CompactPosition,
) {
	color := Aqua

	// Compact resource boxes are 22 columns wide
	// and 3 rows high.
	const boxWidth = 22

	// Start from the right-center of the source box.
	fromRight := from.X + boxWidth
	fromY := from.Y + 1

	nodeX := node.X
	nodeY := node.Y + 1

	// Runtime corridor: the Service->Pods traffic edge
	// (drawCompactRelation, "overlap" branch) routes its
	// own channel at fromRight+2 when boxes share a column.
	// Offset the runtime spine further out from the same
	// fromRight reference point so the two corridors run
	// parallel with a real gap instead of drifting into
	// each other.
	spineX := fromRight + 5

	// --------------------------------------------------
	// 1. Exit the source horizontally.
	// --------------------------------------------------

	if spineX > fromRight {
		for x := fromRight; x <= spineX; x++ {
			canvas.Set(
				x,
				fromY,
				DoubleHorizontal,
				color,
			)
		}
	}

	// --------------------------------------------------
	// 2. Travel vertically on the dedicated runtime spine.
	// --------------------------------------------------

	step := 1

	if nodeY < fromY {
		step = -1
	}

	for y := fromY; y != nodeY; y += step {
		canvas.Set(
			spineX,
			y,
			DoubleVertical,
			color,
		)
	}

	// --------------------------------------------------
	// 3. Enter the Node from the left.
	// --------------------------------------------------

	for x := spineX; x < nodeX; x++ {
		canvas.Set(
			x,
			nodeY,
			DoubleHorizontal,
			color,
		)
	}

	canvas.Set(
		nodeX,
		nodeY,
		ArrowRight,
		color,
	)

}
