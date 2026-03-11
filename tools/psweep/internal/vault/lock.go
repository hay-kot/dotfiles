package vault

import (
	"fmt"
	"os"
	"regexp"
	"strings"
	"time"
)

// IsLocked returns true if the item has been dispatched and is within the stale threshold.
func IsLocked(item WorkItem, staleThreshold time.Duration) bool {
	if item.DispatchedAt.IsZero() {
		return false
	}
	return time.Since(item.DispatchedAt) < staleThreshold
}

// IsStale returns true if the item was dispatched but exceeds the stale threshold.
func IsStale(item WorkItem, staleThreshold time.Duration) bool {
	if item.DispatchedAt.IsZero() {
		return false
	}
	return time.Since(item.DispatchedAt) >= staleThreshold
}

var (
	dispatchedAtRe      = regexp.MustCompile(`(?m)^dispatched-at:.*\n?`)
	dispatchedSessionRe = regexp.MustCompile(`(?m)^dispatched-session:.*\n?`)
)

// SetLock writes dispatched-at and dispatched-session to the file's frontmatter.
// Uses targeted text replacement to preserve formatting.
func SetLock(path string, sessionID string, now time.Time) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("reading file: %w", err)
	}

	content := string(data)
	if !strings.HasPrefix(content, "---") {
		return fmt.Errorf("file does not have frontmatter: %s", path)
	}

	// Find the closing --- delimiter
	endIdx := strings.Index(content[3:], "\n---")
	if endIdx == -1 {
		return fmt.Errorf("missing closing --- delimiter: %s", path)
	}
	endIdx += 3 // adjust for the offset

	fmSection := content[:endIdx]
	rest := content[endIdx:]

	lockLines := fmt.Sprintf("dispatched-at: %s\ndispatched-session: %s\n",
		now.UTC().Format(time.RFC3339), sessionID)

	// Remove existing lock fields if present
	fmSection = dispatchedAtRe.ReplaceAllString(fmSection, "")
	fmSection = dispatchedSessionRe.ReplaceAllString(fmSection, "")

	// Ensure trailing newline before we append
	if !strings.HasSuffix(fmSection, "\n") {
		fmSection += "\n"
	}

	// Insert lock fields before closing ---
	newContent := fmSection + lockLines + rest

	return os.WriteFile(path, []byte(newContent), 0o644)
}

// ClearLock removes dispatched-at and dispatched-session from the file's frontmatter.
func ClearLock(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("reading file: %w", err)
	}

	content := string(data)
	content = dispatchedAtRe.ReplaceAllString(content, "")
	content = dispatchedSessionRe.ReplaceAllString(content, "")

	return os.WriteFile(path, []byte(content), 0o644)
}
