package cmd

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// withinWorkingHours checks PSWEEP_HOURS env var (e.g. "8-16") and returns
// whether the given time falls within the range. If unset, always returns true.
func withinWorkingHours(now time.Time) (ok bool, reason string) {
	hours := os.Getenv("PSWEEP_HOURS")
	if hours == "" {
		return true, ""
	}

	start, end, err := parseHoursRange(hours)
	if err != nil {
		return true, fmt.Sprintf("warning: invalid PSWEEP_HOURS=%q, ignoring: %v", hours, err)
	}

	hour := now.Hour()
	if hour < start || hour >= end {
		return false, fmt.Sprintf("Outside working hours (%s), skipping.", hours)
	}
	return true, ""
}

// parseHoursRange parses "8-16" into (8, 16).
func parseHoursRange(s string) (start, end int, err error) {
	parts := strings.SplitN(s, "-", 2)
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("expected format START-END (e.g. 8-16)")
	}
	start, err = strconv.Atoi(strings.TrimSpace(parts[0]))
	if err != nil {
		return 0, 0, fmt.Errorf("invalid start hour: %w", err)
	}
	end, err = strconv.Atoi(strings.TrimSpace(parts[1]))
	if err != nil {
		return 0, 0, fmt.Errorf("invalid end hour: %w", err)
	}
	if start < 0 || start > 23 || end < 0 || end > 23 {
		return 0, 0, fmt.Errorf("hours must be 0-23")
	}
	if start >= end {
		return 0, 0, fmt.Errorf("start must be before end")
	}
	return start, end, nil
}
