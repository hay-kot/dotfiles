package cmd

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/hay-kot/psweep/internal/dispatch"
	"github.com/hay-kot/psweep/internal/pipeline"
	"github.com/hay-kot/psweep/internal/vault"
)

func runRun(args []string) error {
	fs := flag.NewFlagSet("run", flag.ExitOnError)
	maxDispatch := fs.Int("max-dispatch", 3, "Maximum items to dispatch")
	dryRun := fs.Bool("dry-run", false, "Print what would happen without dispatching")
	forceItem := fs.String("force", "", "Ignore lock for item matching this filename slug")
	staleThreshold := fs.Duration("stale-threshold", 2*time.Hour, "Lock timeout duration")
	fs.Parse(args)

	// Working hours guard: PSWEEP_HOURS=8-16 (24h format, default: no restriction)
	if !*dryRun {
		if ok, reason := withinWorkingHours(time.Now()); !ok {
			fmt.Println(reason)
			return nil
		}
	}

	ctx := context.Background()

	// Acquire process lockfile
	lockPath := filepath.Join(os.TempDir(), "psweep.lock")
	lock, err := acquireLock(lockPath)
	if err != nil {
		return fmt.Errorf("another psweep run is in progress: %w", err)
	}
	defer lock.Release()

	vaultPath := os.Getenv("OBSIDIAN_NOTEBOOK_DIR")
	if vaultPath == "" {
		return fmt.Errorf("OBSIDIAN_NOTEBOOK_DIR is not set")
	}
	if _, err := os.Stat(vaultPath); err != nil {
		return fmt.Errorf("vault path: %w", err)
	}

	// Verify hive binary exists
	if _, err := exec.LookPath("hive"); err != nil {
		return fmt.Errorf("hive binary not found on PATH: %w", err)
	}

	// Scan vault
	paths, err := vault.Scan(vaultPath)
	if err != nil {
		return fmt.Errorf("scanning vault: %w", err)
	}

	// Parse all items
	var items []vault.WorkItem
	for _, p := range paths {
		item, err := vault.Parse(p)
		if err != nil {
			fmt.Fprintf(os.Stderr, "warning: skipping %s: %v\n", p, err)
			continue
		}
		items = append(items, item)
	}

	// Filter for dispatchable
	dispatchable := vault.FilterDispatchable(items)

	runner := &dispatch.ExecRunner{}

	// Handle locks
	var toDispatch []vault.WorkItem
	for _, item := range dispatchable {
		if *forceItem != "" && item.Title == *forceItem {
			toDispatch = append(toDispatch, item)
			continue
		}

		if vault.IsLocked(item, *staleThreshold) {
			fmt.Printf("  skip (locked): %s\n", item.Title)
			continue
		}

		if vault.IsStale(item, *staleThreshold) {
			alive, err := dispatch.IsSessionAlive(ctx, runner, item.DispatchedSession)
			if err != nil {
				fmt.Fprintf(os.Stderr, "warning: checking session %s: %v\n", item.DispatchedSession, err)
				continue
			}
			if alive {
				if !*dryRun {
					_ = vault.SetLock(item.Path, item.DispatchedSession, time.Now())
				}
				fmt.Printf("  skip (stale but alive): %s\n", item.Title)
				continue
			}
			if !*dryRun {
				_ = vault.ClearLock(item.Path)
			}
			fmt.Printf("  re-dispatch (stale, dead): %s\n", item.Title)
		}

		toDispatch = append(toDispatch, item)
	}

	// Prioritize and truncate
	toDispatch = dispatch.Prioritize(toDispatch, *maxDispatch)

	if len(toDispatch) == 0 {
		fmt.Println("No items to dispatch.")
		return nil
	}

	// Build prompts
	prompts := make(map[string]string)
	for _, item := range toDispatch {
		prompt, err := dispatch.BuildPrompt(item)
		if err != nil {
			fmt.Fprintf(os.Stderr, "warning: prompt for %s: %v\n", item.Title, err)
			continue
		}
		prompts[item.Path] = prompt
	}

	// Build batch
	batch := dispatch.BuildBatch(toDispatch, prompts)

	if *dryRun {
		fmt.Printf("Would dispatch %d items:\n", len(toDispatch))
		for _, item := range toDispatch {
			remote := ""
			if len(item.Repos) > 0 {
				remote = item.Repos[0]
			}
			fmt.Printf("  - %s [%s] (remote: %s)\n", item.Title, item.Phase, remote)
		}
		return nil
	}

	// Execute dispatch
	result, err := dispatch.Execute(ctx, runner, batch)
	if err != nil {
		return fmt.Errorf("dispatch: %w", err)
	}

	// Set locks on successfully dispatched items
	now := time.Now()
	for i, item := range toDispatch {
		if i >= len(result.CreatedSessions) {
			break
		}
		sessionID := result.CreatedSessions[i]
		if err := vault.SetLock(item.Path, sessionID, now); err != nil {
			fmt.Fprintf(os.Stderr, "warning: setting lock on %s: %v\n", item.Title, err)
		}
		fmt.Printf("  dispatched: %s → %s\n", item.Title, sessionID)
	}

	// Re-scan to pick up lock changes we just wrote
	return generateAndWritePipeline(vaultPath)
}

func generateAndWritePipeline(vaultPath string) error {
	paths, err := vault.Scan(vaultPath)
	if err != nil {
		return fmt.Errorf("scanning vault for pipeline: %w", err)
	}
	var items []vault.WorkItem
	for _, p := range paths {
		item, err := vault.Parse(p)
		if err != nil {
			continue
		}
		items = append(items, item)
	}
	content := pipeline.Generate(items, time.Now())
	outPath := filepath.Join(vaultPath, "Projects", "Pipeline.md")
	if err := os.WriteFile(outPath, []byte(content), 0o644); err != nil {
		return fmt.Errorf("writing Pipeline.md: %w", err)
	}
	fmt.Printf("  wrote %s\n", outPath)
	return nil
}
