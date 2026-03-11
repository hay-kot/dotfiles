package cmd

import (
	"flag"
	"fmt"
	"os"

	"github.com/hay-kot/psweep/internal/vault"
)

func runStatus(args []string) error {
	fs := flag.NewFlagSet("status", flag.ExitOnError)
	fs.Parse(args)

	vaultPath := os.Getenv("OBSIDIAN_NOTEBOOK_DIR")
	if vaultPath == "" {
		return fmt.Errorf("OBSIDIAN_NOTEBOOK_DIR is not set")
	}

	paths, err := vault.Scan(vaultPath)
	if err != nil {
		return fmt.Errorf("scanning vault: %w", err)
	}

	var items []vault.WorkItem
	for _, p := range paths {
		item, err := vault.Parse(p)
		if err != nil {
			fmt.Fprintf(os.Stderr, "warning: skipping %s: %v\n", p, err)
			continue
		}
		items = append(items, item)
	}

	dispatchable := vault.FilterDispatchable(items)

	fmt.Printf("Total work items: %d\n", len(items))
	fmt.Printf("Dispatchable:     %d\n", len(dispatchable))

	for _, item := range items {
		if item.Phase == vault.PhaseDone {
			continue
		}
		status := "ready"
		if !item.DispatchedAt.IsZero() {
			status = fmt.Sprintf("dispatched (session: %s)", item.DispatchedSession)
		}
		fmt.Printf("  %-30s %-12s %s\n", item.Title, item.Phase, status)
	}

	return nil
}
