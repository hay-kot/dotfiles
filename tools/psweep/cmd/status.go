package cmd

import (
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/hay-kot/psweep/internal/pipeline"
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

	fmt.Print(pipeline.Generate(items, time.Now()))
	return nil
}
