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
