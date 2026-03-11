package cmd

import (
	"fmt"
	"log"
	"os"
	"os/exec"

	"github.com/hay-kot/psweep/internal/launchd"
)

func init() {
	commands["log"] = subcommand{
		desc: "Open psweep log file in $EDITOR",
		run:  runLog,
	}
}

// setupLogger configures the default logger to write timestamped output
// to the psweep log file in addition to stderr.
func setupLogger() (*os.File, error) {
	logPath := launchd.LogPath()

	f, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, fmt.Errorf("opening log file: %w", err)
	}

	log.SetOutput(f)
	log.SetFlags(log.Ldate | log.Ltime)

	return f, nil
}

func runLog(args []string) error {
	logPath := launchd.LogPath()

	if _, err := os.Stat(logPath); err != nil {
		return fmt.Errorf("log file not found: %s", logPath)
	}

	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = "less"
	}

	cmd := exec.Command(editor, logPath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
