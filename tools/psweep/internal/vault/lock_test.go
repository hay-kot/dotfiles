package vault_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/hay-kot/psweep/internal/vault"
)

func TestIsLocked(t *testing.T) {
	threshold := 2 * time.Hour
	now := time.Now()

	tests := []struct {
		name string
		item vault.WorkItem
		want bool
	}{
		{
			name: "not dispatched",
			item: vault.WorkItem{},
			want: false,
		},
		{
			name: "dispatched recently",
			item: vault.WorkItem{DispatchedAt: now.Add(-30 * time.Minute)},
			want: true,
		},
		{
			name: "dispatched long ago",
			item: vault.WorkItem{DispatchedAt: now.Add(-3 * time.Hour)},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := vault.IsLocked(tt.item, threshold); got != tt.want {
				t.Errorf("IsLocked = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestIsStale(t *testing.T) {
	threshold := 2 * time.Hour
	now := time.Now()

	tests := []struct {
		name string
		item vault.WorkItem
		want bool
	}{
		{
			name: "not dispatched",
			item: vault.WorkItem{},
			want: false,
		},
		{
			name: "dispatched recently",
			item: vault.WorkItem{DispatchedAt: now.Add(-30 * time.Minute)},
			want: false,
		},
		{
			name: "dispatched long ago",
			item: vault.WorkItem{DispatchedAt: now.Add(-3 * time.Hour)},
			want: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := vault.IsStale(tt.item, threshold); got != tt.want {
				t.Errorf("IsStale = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestSetLockAndClearLock_RoundTrip(t *testing.T) {
	// Realistic multi-section work item
	original := `---
project: "[[MyProject]]"
phase: research
priority: high
auto-advance: true
lane: prep
repos:
  - https://github.com/example/repo
created: "2026-01-10"
tags: [work]
type: work
---

## Objective

Build something cool with multiple paragraphs
and detailed requirements.

## Acceptance Criteria

- Feature A works
- Feature B is fast
- No regressions

## Artifacts

- Plan: [[.hive/plans/cool-plan.md]]

## Notes

Some additional notes here.
`

	dir := t.TempDir()
	path := filepath.Join(dir, "test-item.md")
	if err := os.WriteFile(path, []byte(original), 0o644); err != nil {
		t.Fatal(err)
	}

	lockTime := time.Date(2026, 3, 10, 12, 0, 0, 0, time.UTC)

	// Set lock
	if err := vault.SetLock(path, "sess-abc", lockTime); err != nil {
		t.Fatalf("SetLock: %v", err)
	}

	// Read back and verify lock fields present
	data, _ := os.ReadFile(path)
	content := string(data)
	if !strings.Contains(content, "dispatched-at: 2026-03-10T12:00:00Z") {
		t.Error("dispatched-at not found after SetLock")
	}
	if !strings.Contains(content, "dispatched-session: sess-abc") {
		t.Error("dispatched-session not found after SetLock")
	}

	// Verify body content preserved
	bodyStart := strings.Index(content, "\n## Objective")
	originalBodyStart := strings.Index(original, "\n## Objective")
	if bodyStart == -1 || originalBodyStart == -1 {
		t.Fatal("could not find body sections")
	}
	originalBody := original[originalBodyStart:]
	actualBody := content[bodyStart:]
	if originalBody != actualBody {
		t.Errorf("body content changed after SetLock.\nOriginal:\n%s\nActual:\n%s", originalBody, actualBody)
	}

	// Re-parse to verify it's valid
	item, err := vault.ParseContent(path, content)
	if err != nil {
		t.Fatalf("re-parse after SetLock: %v", err)
	}
	if item.DispatchedSession != "sess-abc" {
		t.Errorf("DispatchedSession = %q after re-parse", item.DispatchedSession)
	}

	// Clear lock
	if err := vault.ClearLock(path); err != nil {
		t.Fatalf("ClearLock: %v", err)
	}

	// Verify lock fields gone
	data, _ = os.ReadFile(path)
	content = string(data)
	if strings.Contains(content, "dispatched-at") {
		t.Error("dispatched-at still present after ClearLock")
	}
	if strings.Contains(content, "dispatched-session") {
		t.Error("dispatched-session still present after ClearLock")
	}

	// Verify body still preserved
	bodyStart = strings.Index(content, "\n## Objective")
	if bodyStart == -1 {
		t.Fatal("body sections missing after ClearLock")
	}
	actualBody = content[bodyStart:]
	if originalBody != actualBody {
		t.Errorf("body content changed after ClearLock.\nOriginal:\n%s\nActual:\n%s", originalBody, actualBody)
	}
}

func TestSetLock_Idempotent(t *testing.T) {
	content := `---
project: X
phase: research
dispatched-at: "2026-01-01T00:00:00Z"
dispatched-session: old-session
---

Body.
`
	dir := t.TempDir()
	path := filepath.Join(dir, "item.md")
	os.WriteFile(path, []byte(content), 0o644)

	lockTime := time.Date(2026, 3, 10, 12, 0, 0, 0, time.UTC)
	if err := vault.SetLock(path, "new-session", lockTime); err != nil {
		t.Fatalf("SetLock: %v", err)
	}

	data, _ := os.ReadFile(path)
	result := string(data)

	// Should have new values, not duplicates
	if strings.Count(result, "dispatched-at:") != 1 {
		t.Errorf("expected exactly 1 dispatched-at, got %d", strings.Count(result, "dispatched-at:"))
	}
	if strings.Count(result, "dispatched-session:") != 1 {
		t.Errorf("expected exactly 1 dispatched-session, got %d", strings.Count(result, "dispatched-session:"))
	}
	if !strings.Contains(result, "new-session") {
		t.Error("new session ID not found")
	}
}
