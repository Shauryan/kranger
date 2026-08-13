package render

import "strings"

type Cell struct {
	Char  rune
	Color string
}

type Canvas struct {
	Width  int
	Height int

	cells [][]Cell
}

func NewCanvas(width, height int) *Canvas {

	cells := make([][]Cell, height)

	for y := 0; y < height; y++ {

		cells[y] = make([]Cell, width)

		for x := 0; x < width; x++ {

			cells[y][x] = Cell{
				Char:  ' ',
				Color: Reset,
			}
		}
	}

	return &Canvas{
		Width:  width,
		Height: height,
		cells:  cells,
	}
}

func (c *Canvas) Set(
	x int,
	y int,
	char rune,
	color string,
) {

	if x < 0 ||
		y < 0 ||
		x >= c.Width ||
		y >= c.Height {
		return
	}

	c.cells[y][x] = Cell{
		Char:  char,
		Color: color,
	}
}

// runeDisplayWidth returns the terminal column width of a
// rune. Nerd Font icons (used throughout this renderer for
// resource kinds) live in Unicode Private Use Areas and are
// rendered double-width by most terminals, even though they
// are a single Go rune. Everything else in this app's active
// character set (box-drawing, ASCII, arrows) is single-width.
func runeDisplayWidth(r rune) int {
	switch {
	case r >= 0xE000 && r <= 0xF8FF:
		// Basic Multilingual Plane Private Use Area —
		// where most Nerd Font glyphs live.
		return 2
	case r >= 0xF0000 && r <= 0xFFFFD:
		// Supplementary Private Use Area-A.
		return 2
	case r >= 0x100000 && r <= 0x10FFFD:
		// Supplementary Private Use Area-B.
		return 2
	default:
		return 1
	}
}

// displayWidth returns the total terminal column width of
// a string, accounting for double-width runes (see
// runeDisplayWidth). Use this instead of len([]rune(s))
// anywhere a width is used for positioning or truncation.
func displayWidth(s string) int {
	width := 0
	for _, r := range []rune(s) {
		width += runeDisplayWidth(r)
	}
	return width
}

func (c *Canvas) Write(
	x int,
	y int,
	text string,
	color string,
) {

	col := x

	for _, char := range []rune(text) {

		c.Set(
			col,
			y,
			char,
			color,
		)

		col += runeDisplayWidth(char)
	}
}

func (c *Canvas) String() string {

	var builder strings.Builder

	for y := 0; y < c.Height; y++ {

		currentColor := ""

		for x := 0; x < c.Width; x++ {

			cell := c.cells[y][x]

			if cell.Color != currentColor {

				builder.WriteString(cell.Color)
				currentColor = cell.Color
			}

			builder.WriteRune(cell.Char)
		}

		builder.WriteString(Reset)

		if y < c.Height-1 {
			builder.WriteByte('\n')
		}
	}

	return builder.String()
}
