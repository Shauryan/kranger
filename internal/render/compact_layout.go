package render

type CompactLayoutConfig struct {
	Width int

	Left int
	Top  int

	GroupWidth int
	GroupGap   int

	NamespaceGap int
	NamespacePad int

	NodeGap int
}

func DefaultCompactLayout(width int) CompactLayoutConfig {
	return CompactLayoutConfig{
		Width: width,

		Left: 2,
		Top:  1,

		GroupWidth: 22,
		GroupGap:   4,

		NamespaceGap: 1,
		NamespacePad: 1,

		NodeGap: 2,
	}
}

type CompactPosition struct {
	X int
	Y int
}

type CompactLayout struct {
	Namespaces map[string]CompactPosition

	Groups map[*CompactGroup]CompactPosition

	Node CompactPosition

	Height int
}

func LayoutCompact(
	model *CompactModel,
	config CompactLayoutConfig,
) CompactLayout {

	layout := CompactLayout{
		Namespaces: map[string]CompactPosition{},
		Groups:     map[*CompactGroup]CompactPosition{},
	}

	y := config.Top

	for _, ns := range model.Namespaces {

		nsY := y

		layout.Namespaces[ns.Name] = CompactPosition{
			X: config.Left,
			Y: nsY,
		}

		// Identify the main Kubernetes relationship chain.
		var deployment *CompactGroup
		var replicaSet *CompactGroup
		var pod *CompactGroup
		var service *CompactGroup

		for _, group := range ns.Groups {

			switch group.Kind {
			case "Deployment":
				deployment = group

			case "ReplicaSet":
				replicaSet = group

			case "Pod":
				pod = group

			case "Service":
				service = group
			}
		}

		contentX := config.Left + 3
		contentY := nsY + 1

		step := config.GroupWidth + config.GroupGap

		// Deployment -> ReplicaSet -> Pod
		if deployment != nil {
			layout.Groups[deployment] = CompactPosition{
				X: contentX,
				Y: contentY,
			}
		}

		if replicaSet != nil {
			layout.Groups[replicaSet] = CompactPosition{
				X: contentX + step,
				Y: contentY,
			}
		}

		if pod != nil {
			layout.Groups[pod] = CompactPosition{
				X: contentX + 2*step,
				Y: contentY,
			}
		}

		// Service goes directly below Pod.
		if service != nil {

			serviceX := contentX
			serviceY := contentY

			if pod != nil {
				serviceX = contentX + 2*step
				serviceY = contentY + 3
			}

			layout.Groups[service] = CompactPosition{
				X: serviceX,
				Y: serviceY,
			}
		}

		// Place any unrecognised resource groups compactly,
		// starting on a fresh row below whatever the primary
		// chain (Deployment/ReplicaSet/Pod/Service) already
		// occupies, so fallback groups never overlap them.
		fallbackStartY := contentY

		for _, pos := range layout.Groups {
			bottom := pos.Y + 3
			if bottom > fallbackStartY {
				fallbackStartY = bottom
			}
		}

		fallbackX := contentX
		fallbackY := fallbackStartY

		for _, group := range ns.Groups {

			if _, exists := layout.Groups[group]; exists {
				continue
			}

			layout.Groups[group] = CompactPosition{
				X: fallbackX,
				Y: fallbackY,
			}

			fallbackX += step

			if fallbackX+config.GroupWidth >= config.Width-4 {
				fallbackX = contentX
				fallbackY += 3
			}
		}

		// Calculate the namespace height from actual content.
		namespaceHeight := 2

		if len(ns.Groups) > 0 {
			namespaceHeight = 3
		}

		maxBottom := nsY

		for _, group := range ns.Groups {

			pos, ok := layout.Groups[group]

			if !ok {
				continue
			}

			// Resource group occupies three rows.
			bottom := pos.Y + 2

			if bottom > maxBottom {
				maxBottom = bottom
			}
		}

		requiredHeight := maxBottom - nsY + 1

		if requiredHeight > namespaceHeight {
			namespaceHeight = requiredHeight
		}

		// One row between namespaces.
		y = nsY + namespaceHeight + config.NamespaceGap
	}

	// Node sits one row below the final namespace.
	if model.Node != nil {

		layout.Node = CompactPosition{
			X: config.Width - 24,
			Y: y + 1,
		}

		// Reserve the Node's three rendered rows
		// plus the separation row.
		y += 5
	}

	layout.Height = y + 1

	return layout
}
