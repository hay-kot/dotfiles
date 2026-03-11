package cmd

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/hay-kot/psweep/internal/launchd"
)

func init() {
	commands["install"] = subcommand{
		desc: "Install psweep as a launchd periodic job",
		run:  runInstall,
	}
	commands["uninstall"] = subcommand{
		desc: "Uninstall psweep launchd job",
		run:  runUninstall,
	}
}

func runInstall(args []string) error {
	fs := flag.NewFlagSet("install", flag.ExitOnError)
	interval := fs.Duration("interval", 30*time.Minute, "Run interval (e.g. 15m, 1h)")
	fs.Parse(args)

	// Find psweep binary
	binaryPath, err := os.Executable()
	if err != nil {
		// Fall back to looking on PATH
		binaryPath, err = exec.LookPath("psweep")
		if err != nil {
			return fmt.Errorf("cannot find psweep binary: %w", err)
		}
	}
	binaryPath, _ = filepath.Abs(binaryPath)

	cfg := launchd.Config{
		BinaryPath: binaryPath,
		IntervalS:  int(interval.Seconds()),
	}

	content, err := launchd.Generate(cfg)
	if err != nil {
		return fmt.Errorf("generating plist: %w", err)
	}

	plistPath := launchd.PlistPath()

	// Ensure directory exists
	if err := os.MkdirAll(filepath.Dir(plistPath), 0o755); err != nil {
		return fmt.Errorf("creating LaunchAgents dir: %w", err)
	}

	if err := os.WriteFile(plistPath, []byte(content), 0o644); err != nil {
		return fmt.Errorf("writing plist: %w", err)
	}

	// Load with launchctl
	out, err := exec.Command("launchctl", "load", plistPath).CombinedOutput()
	if err != nil {
		return fmt.Errorf("launchctl load: %s: %w", string(out), err)
	}

	fmt.Printf("Installed %s\n", plistPath)
	fmt.Printf("Interval: %s\n", interval)
	fmt.Printf("Log: %s\n", launchd.LogPath())

	return nil
}

func runUninstall(args []string) error {
	fs := flag.NewFlagSet("uninstall", flag.ExitOnError)
	fs.Parse(args)

	plistPath := launchd.PlistPath()

	// Unload
	out, err := exec.Command("launchctl", "unload", plistPath).CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: launchctl unload: %s\n", string(out))
	}

	// Remove file
	if err := os.Remove(plistPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("removing plist: %w", err)
	}

	fmt.Printf("Uninstalled %s\n", plistPath)
	return nil
}
