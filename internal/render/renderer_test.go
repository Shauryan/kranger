package render

import (
	"strings"
	"testing"
)

func TestCanvas(t *testing.T) {

	canvas := NewCanvas(20, 5)

	canvas.Write(
		2,
		2,
		"KRANGER",
		White,
	)

	result := canvas.String()

	if !strings.Contains(
		result,
		"KRANGER",
	) {
		t.Fatal(
			"canvas did not contain expected text",
		)
	}
}
