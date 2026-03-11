package pipeline_test

import (
	"strings"
	"testing"
	"time"

	"github.com/hay-kot/psweep/internal/pipeline"
	"github.com/hay-kot/psweep/internal/vault"
)

var now = time.Date(2026, 3, 10, 14, 30, 0, 0, time.UTC)

func TestGenerate_Empty(t *testing.T) {
	out := pipeline.Generate(nil, now)
	if !strings.Contains(out, "# Pipeline") {
		t.Error("missing header")
	}
	if !strings.Contains(out, "2026-03-10 14:30") {
		t.Error("missing timestamp")
	}
	// Should have header only, no project sections
	if strings.Contains(out, "## ") {
		t.Error("empty vault should not have project sections")
	}
}

func TestGenerate_MultipleProjectsAndPhases(t *testing.T) {
	items := []vault.WorkItem{
		{Title: "Task A", Project: "Beta", Phase: vault.PhaseResearch, Lane: vault.LanePrep},
		{Title: "Task B", Project: "Alpha", Phase: vault.PhasePlanning, Lane: vault.LanePrep},
		{Title: "Task C", Project: "Alpha", Phase: vault.PhaseResearch, Lane: vault.LaneEasy},
		{Title: "Task D", Project: "Beta", Phase: vault.PhaseBacklog},
	}

	out := pipeline.Generate(items, now)

	// Projects alphabetically sorted
	alphaIdx := strings.Index(out, "## Alpha")
	betaIdx := strings.Index(out, "## Beta")
	if alphaIdx == -1 || betaIdx == -1 {
		t.Fatalf("missing project headings:\n%s", out)
	}
	if alphaIdx > betaIdx {
		t.Error("Alpha should come before Beta")
	}

	// Within Alpha, planning should come before research (closer to building)
	planIdx := strings.Index(out, "### planning")
	resIdx := strings.Index(out[alphaIdx:], "### research")
	if planIdx == -1 || resIdx == -1 {
		t.Fatalf("missing phase headings:\n%s", out)
	}
}

func TestGenerate_StatusLines(t *testing.T) {
	dispatched := now.Add(-45 * time.Minute)
	items := []vault.WorkItem{
		{
			Title: "Gated Item", Project: "P", Phase: vault.PhasePlanning,
			GateBefore: vault.PhaseBuilding,
		},
		{
			Title: "In Flight", Project: "P", Phase: vault.PhaseResearch,
			DispatchedAt: dispatched, DispatchedSession: "sess-1",
		},
		{Title: "Ready Item", Project: "P", Phase: vault.PhaseDesign, Lane: vault.LanePrep},
		{Title: "Blocked Item", Project: "P", Phase: vault.PhaseBlocked},
		{Title: "Backlog Item", Project: "P", Phase: vault.PhaseBacklog},
	}

	out := pipeline.Generate(items, now)

	tests := []struct {
		name     string
		contains string
	}{
		{"gated", "**Gated Item** — plan approved, waiting for human"},
		{"in-flight", "**In Flight** — dispatched 45m ago (session: sess-1)"},
		{"ready", "**Ready Item** — ready (lane: prep)"},
		{"blocked", "**Blocked Item** — blocked"},
		{"backlog", "**Backlog Item** — not started"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if !strings.Contains(out, tt.contains) {
				t.Errorf("missing %q in output:\n%s", tt.contains, out)
			}
		})
	}
}

func TestGenerate_ExcludesDone(t *testing.T) {
	items := []vault.WorkItem{
		{Title: "Done Task", Project: "P", Phase: vault.PhaseDone},
		{Title: "Active Task", Project: "P", Phase: vault.PhaseResearch, Lane: vault.LanePrep},
	}

	out := pipeline.Generate(items, now)
	if strings.Contains(out, "Done Task") {
		t.Error("done items should be excluded")
	}
	if !strings.Contains(out, "Active Task") {
		t.Error("active items should be included")
	}
}

func TestGenerate_RelativeTimeHours(t *testing.T) {
	dispatched := now.Add(-2*time.Hour - 15*time.Minute)
	items := []vault.WorkItem{
		{
			Title: "Old Task", Project: "P", Phase: vault.PhaseResearch,
			DispatchedAt: dispatched, DispatchedSession: "sess-x",
		},
	}

	out := pipeline.Generate(items, now)
	if !strings.Contains(out, "2h15m ago") {
		t.Errorf("expected '2h15m ago' in output:\n%s", out)
	}
}
