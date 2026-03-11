package cmd

import (
	"os"
	"testing"
	"time"
)

func TestWithinWorkingHours(t *testing.T) {
	tests := []struct {
		name   string
		env    string
		hour   int
		wantOK bool
	}{
		{"unset allows all", "", 3, true},
		{"within range", "8-16", 10, true},
		{"at start boundary", "8-16", 8, true},
		{"at end boundary excluded", "8-16", 16, false},
		{"before range", "8-16", 7, false},
		{"after range", "8-16", 20, false},
		{"invalid format ignored", "bad", 10, true},
		{"early bird", "6-14", 6, true},
		{"early bird after", "6-14", 14, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os.Setenv("PSWEEP_HOURS", tt.env)
			defer os.Unsetenv("PSWEEP_HOURS")

			now := time.Date(2026, 3, 10, tt.hour, 30, 0, 0, time.Local)
			ok, _ := withinWorkingHours(now)
			if ok != tt.wantOK {
				t.Errorf("hour=%d env=%q: got ok=%v, want %v", tt.hour, tt.env, ok, tt.wantOK)
			}
		})
	}
}
