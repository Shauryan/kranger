package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"golang.org/x/term"

	"github.com/Shauryan/kranger/internal/graph"
	"github.com/Shauryan/kranger/internal/k8s"
	"github.com/Shauryan/kranger/internal/render"
)

const borderOverheadWidth = 4
const borderOverheadHeight = 2

func terminalSize() (width, height int) {
	const defaultWidth = 110
	const defaultHeight = 32

	w, h, err := term.GetSize(int(os.Stdout.Fd()))
	if err != nil || w <= 0 || h <= 0 {
		return defaultWidth, defaultHeight
	}

	return w, h
}

func clearScreen() {
	fmt.Print("\033[H\033[2J")
}

func wrapInBox(content string, innerWidth int) string {
	var b strings.Builder

	b.WriteString("╭" + strings.Repeat("─", innerWidth+2) + "╮\n")

	for _, line := range strings.Split(content, "\n") {
		b.WriteString("│ " + line + " │\n")
	}

	b.WriteString("╰" + strings.Repeat("─", innerWidth+2) + "╯")

	return b.String()
}

func renderOnce(discovery *k8s.Discovery) {
	state, err := discovery.Discover(context.Background())

	clearScreen()

	if err != nil {
		fmt.Println()
		fmt.Printf("⚠️  Resource discovery failed: %v\n", err)
		fmt.Println()
		return
	}

	g := graph.Build(state)

	termWidth, termHeight := terminalSize()

	contentWidth := termWidth - borderOverheadWidth
	contentHeight := termHeight - borderOverheadHeight

	if contentWidth < 40 {
		contentWidth = 40
	}
	if contentHeight < 10 {
		contentHeight = 10
	}

	output := render.RenderCompact(g, contentWidth, contentHeight)

	fmt.Println()
	fmt.Println(wrapInBox(output, contentWidth))
}

func main() {
	client, err := k8s.NewClient()
	if err != nil {
		log.Fatalf("❌ Kubernetes connection failed: %v", err)
	}

	discovery := k8s.NewDiscovery(client)

	reader := bufio.NewReader(os.Stdin)

	renderOnce(discovery)

	for {
		fmt.Println()
		fmt.Println("Press Enter to refresh, or type q + Enter to quit.")

		line, err := reader.ReadString('\n')
		if err != nil {
			return
		}

		line = strings.TrimSpace(line)

		if line == "q" || line == "quit" {
			return
		}

		renderOnce(discovery)
	}
}
