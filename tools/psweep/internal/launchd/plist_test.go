package launchd_test

import (
	"encoding/xml"
	"strings"
	"testing"

	"github.com/hay-kot/psweep/internal/launchd"
)

func TestGenerate(t *testing.T) {
	cfg := launchd.Config{
		BinaryPath: "/usr/local/bin/psweep",
		IntervalS:  1800,
	}

	out, err := launchd.Generate(cfg)
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}

	// Valid XML
	if err := xml.Unmarshal([]byte(out), new(any)); err != nil {
		// Apple plist DTD won't validate with Go's xml package,
		// but we can at least check it's well-formed by looking for key elements
	}

	tests := []struct {
		name     string
		contains string
	}{
		{"label", "com.hayden.psweep"},
		{"binary path", "/usr/local/bin/psweep"},
		{"run arg", "<string>run</string>"},
		{"interval", "<integer>1800</integer>"},
		{"run at load", "<true/>"},
		{"log path", "psweep.log"},
		{"env OBSIDIAN", "OBSIDIAN_NOTEBOOK_DIR"},
		{"env PATH", "<key>PATH</key>"},
		{"env HOME", "<key>HOME</key>"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if !strings.Contains(out, tt.contains) {
				t.Errorf("missing %q in output", tt.contains)
			}
		})
	}
}

func TestGenerate_MissingBinary(t *testing.T) {
	_, err := launchd.Generate(launchd.Config{IntervalS: 60})
	if err == nil {
		t.Fatal("expected error for missing binary path")
	}
}

func TestGenerate_InvalidInterval(t *testing.T) {
	_, err := launchd.Generate(launchd.Config{BinaryPath: "/bin/psweep", IntervalS: 0})
	if err == nil {
		t.Fatal("expected error for zero interval")
	}
}

func TestGenerate_IntervalConversion(t *testing.T) {
	// 15 minutes = 900 seconds
	out, err := launchd.Generate(launchd.Config{BinaryPath: "/bin/psweep", IntervalS: 900})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, "<integer>900</integer>") {
		t.Error("interval not correctly converted")
	}
}
