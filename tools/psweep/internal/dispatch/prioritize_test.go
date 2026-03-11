package dispatch_test

import (
	"testing"

	"github.com/hay-kot/psweep/internal/dispatch"
	"github.com/hay-kot/psweep/internal/vault"
)

func TestPrioritize(t *testing.T) {
	items := []vault.WorkItem{
		{Title: "low-research", Priority: vault.PriorityLow, Phase: vault.PhaseResearch},
		{Title: "high-research", Priority: vault.PriorityHigh, Phase: vault.PhaseResearch},
		{Title: "high-planning", Priority: vault.PriorityHigh, Phase: vault.PhasePlanning},
		{Title: "medium-design", Priority: vault.PriorityMedium, Phase: vault.PhaseDesign},
	}

	result := dispatch.Prioritize(items, 0)

	// high-planning (high pri, highest phase order) should be first
	// high-research (high pri, lower phase order) second
	// medium-design third
	// low-research last
	expected := []string{"high-planning", "high-research", "medium-design", "low-research"}
	for i, want := range expected {
		if result[i].Title != want {
			t.Errorf("position %d: got %q, want %q", i, result[i].Title, want)
		}
	}
}

func TestPrioritize_Truncate(t *testing.T) {
	items := []vault.WorkItem{
		{Title: "a", Priority: vault.PriorityHigh, Phase: vault.PhaseResearch},
		{Title: "b", Priority: vault.PriorityMedium, Phase: vault.PhaseResearch},
		{Title: "c", Priority: vault.PriorityLow, Phase: vault.PhaseResearch},
	}

	result := dispatch.Prioritize(items, 2)
	if len(result) != 2 {
		t.Errorf("got %d items, want 2", len(result))
	}
	if result[0].Title != "a" || result[1].Title != "b" {
		t.Errorf("wrong items after truncation: %v, %v", result[0].Title, result[1].Title)
	}
}
