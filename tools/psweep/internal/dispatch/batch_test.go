package dispatch_test

import (
	"encoding/json"
	"testing"

	"github.com/hay-kot/psweep/internal/dispatch"
	"github.com/hay-kot/psweep/internal/vault"
)

func TestBuildBatch(t *testing.T) {
	items := []vault.WorkItem{
		{
			Title: "My Cool Task",
			Path:  "/path/to/item.md",
			Repos: []string{"https://github.com/example/repo"},
		},
	}
	prompts := map[string]string{
		"/path/to/item.md": "Do the work.",
	}

	batch := dispatch.BuildBatch(items, prompts)

	data, err := json.Marshal(batch)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var result dispatch.BatchInput
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if len(result.Sessions) != 1 {
		t.Fatalf("got %d sessions, want 1", len(result.Sessions))
	}

	s := result.Sessions[0]
	if s.Name == "" {
		t.Error("session name is empty")
	}
	if s.Prompt == "" {
		t.Error("session prompt is empty")
	}
	if s.Remote != "https://github.com/example/repo" {
		t.Errorf("remote = %q", s.Remote)
	}

	// Verify slug format
	if s.Name != "my-cool-task" {
		t.Errorf("slug = %q, want %q", s.Name, "my-cool-task")
	}
}

func TestSlugTruncation(t *testing.T) {
	items := []vault.WorkItem{
		{
			Title: "This Is A Very Long Task Name That Should Be Truncated",
			Path:  "/path",
		},
	}
	prompts := map[string]string{"/path": "prompt"}
	batch := dispatch.BuildBatch(items, prompts)

	if len(batch.Sessions[0].Name) > 30 {
		t.Errorf("slug too long: %d chars", len(batch.Sessions[0].Name))
	}
}
