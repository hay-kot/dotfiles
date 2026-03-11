package launchd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	Label    = "com.hayden.psweep"
	PlistDir = "Library/LaunchAgents"
)

// PlistPath returns the full path to the plist file.
func PlistPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, PlistDir, Label+".plist")
}

// LogPath returns the path for psweep logs.
func LogPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Library", "Logs", "psweep.log")
}

// Config holds the configuration for plist generation.
type Config struct {
	BinaryPath string
	IntervalS  int
}

// Generate produces the plist XML content.
func Generate(cfg Config) (string, error) {
	if cfg.BinaryPath == "" {
		return "", fmt.Errorf("binary path is required")
	}
	if cfg.IntervalS <= 0 {
		return "", fmt.Errorf("interval must be positive")
	}

	logPath := LogPath()

	// Build plist manually — encoding/xml doesn't handle Apple's plist DTD well
	var b strings.Builder
	b.WriteString(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>` + Label + `</string>
	<key>ProgramArguments</key>
	<array>
		<string>` + xmlEscape(cfg.BinaryPath) + `</string>
		<string>run</string>
	</array>
	<key>StartInterval</key>
	<integer>` + fmt.Sprintf("%d", cfg.IntervalS) + `</integer>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardOutPath</key>
	<string>` + xmlEscape(logPath) + `</string>
	<key>StandardErrorPath</key>
	<string>` + xmlEscape(logPath) + `</string>
	<key>EnvironmentVariables</key>
	<dict>
		<key>OBSIDIAN_NOTEBOOK_DIR</key>
		<string>` + xmlEscape(os.Getenv("OBSIDIAN_NOTEBOOK_DIR")) + `</string>
		<key>PATH</key>
		<string>` + xmlEscape(os.Getenv("PATH")) + `</string>
		<key>HOME</key>
		<string>` + xmlEscape(os.Getenv("HOME")) + `</string>
		<key>PSWEEP_HOURS</key>
		<string>` + xmlEscape(os.Getenv("PSWEEP_HOURS")) + `</string>
	</dict>
</dict>
</plist>
`)

	return b.String(), nil
}

func xmlEscape(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	return s
}
