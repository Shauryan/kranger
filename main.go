package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"golang.org/x/term"

	"github.com/Shauryan/kranger/internal/graph"
	"github.com/Shauryan/kranger/internal/k8s"
	"github.com/Shauryan/kranger/internal/render"
)

// refreshInterval controls how often Kranger re-queries the
// cluster and redraws the topology.
const refreshInterval = 3 * time.Second

// terminalSize returns the current terminal's width and
// height. If the output isn't a real terminal (e.g. piped
// to a file) or the size can't be determined, it falls back
// to a fixed default.
func terminalSize() (width, height int) {
	const defaultWidth = 110
	const defaultHeight = 32

	w, h, err := term.GetSize(int(os.Stdout.Fd()))
	if err != nil || w <= 0 || h <= 0 {
		return defaultWidth, defaultHeight
	}

	return w, h
}

// clearScreen resets the cursor to the top-left and clears
// the visible terminal, so each refresh redraws in place
// instead of scrolling.
func clearScreen() {
	fmt.Print("\033[H\033[2J")
}

func main() {
	// A connection failure at startup is still fatal — there
	// is nothing useful to show without a working client.
	client, err := k8s.NewClient()
	if err != nil {
		log.Fatalf(
			"❌ Kubernetes connection failed: %v",
			err,
		)
	}

	discovery := k8s.NewDiscovery(client)

	for {
		state, err := discovery.Discover(
			context.Background(),
		)

		clearScreen()

		if err != nil {
			// A transient discovery error (e.g. a brief API
			// hiccup) should not kill an otherwise-live view.
			// Show the error in place and keep retrying on the
			// normal refresh cadence.
			fmt.Println()
			fmt.Printf(
				"⚠️  Resource discovery failed: %v\n",
				err,
			)
			fmt.Printf(
				"   Retrying in %s...\n",
				refreshInterval,
			)
			fmt.Println()

			time.Sleep(refreshInterval)
			continue
		}

		g := graph.Build(state)

		// The full graph is still built and retained.
		// Compact mode has its own layout.
		width, height := terminalSize()

		output := render.RenderCompact(
			g,
			width,
			height,
		)

		fmt.Println()
		fmt.Println(output)
		fmt.Printf(
			"Refreshing every %s — press Ctrl+C to quit.\n",
			refreshInterval,
		)

		time.Sleep(refreshInterval)
	}
}
