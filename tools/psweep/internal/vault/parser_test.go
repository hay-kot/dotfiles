package vault_test

import (
	"testing"

	"github.com/hay-kot/psweep/internal/vault"
)

func TestParseContent(t *testing.T) {
	tests := []struct {
		name    string
		content string
		check   func(t *testing.T, item vault.WorkItem)
		wantErr bool
	}{
		{
			name: "valid item with all fields",
			content: `---
project: "[[MyProject]]"
phase: research
priority: high
auto-advance: true
gate-before: building
lane: prep
repos:
  - https://github.com/example/repo
dispatched-at: "2026-01-15T10:00:00Z"
dispatched-session: sess-123
created: "2026-01-10"
tags: [work]
type: work
---

## Objective

Build the thing.

## Acceptance Criteria

- It works
- It's fast

## Artifacts

- Plan: [[.hive/plans/my-plan.md]]
`,
			check: func(t *testing.T, item vault.WorkItem) {
				assertEqual(t, "Project", item.Project, "MyProject")
				assertEqual(t, "Phase", string(item.Phase), "research")
				assertEqual(t, "Priority", string(item.Priority), "high")
				assertEqual(t, "AutoAdvance", item.AutoAdvance, true)
				assertEqual(t, "GateBefore", string(item.GateBefore), "building")
				assertEqual(t, "Lane", string(item.Lane), "prep")
				assertEqual(t, "Repos[0]", item.Repos[0], "https://github.com/example/repo")
				assertEqual(t, "DispatchedSession", item.DispatchedSession, "sess-123")
				assertEqual(t, "Created", item.Created, "2026-01-10")
				assertEqual(t, "Title", item.Title, "test-item")
				if item.DispatchedAt.IsZero() {
					t.Error("DispatchedAt should not be zero")
				}
				if item.Objective != "Build the thing." {
					t.Errorf("Objective = %q, want %q", item.Objective, "Build the thing.")
				}
				if item.AcceptanceCriteria != "- It works\n- It's fast" {
					t.Errorf("AcceptanceCriteria = %q", item.AcceptanceCriteria)
				}
				if item.PlanPath != ".hive/plans/my-plan.md" {
					t.Errorf("PlanPath = %q, want %q", item.PlanPath, ".hive/plans/my-plan.md")
				}
			},
		},
		{
			name: "required fields only",
			content: `---
project: SimpleProject
phase: backlog
---

Some content.
`,
			check: func(t *testing.T, item vault.WorkItem) {
				assertEqual(t, "Project", item.Project, "SimpleProject")
				assertEqual(t, "Phase", string(item.Phase), "backlog")
				assertEqual(t, "Priority", string(item.Priority), "")
				assertEqual(t, "AutoAdvance", item.AutoAdvance, false)
				assertEqual(t, "GateBefore", string(item.GateBefore), "")
				assertEqual(t, "Lane", string(item.Lane), "")
				if len(item.Repos) != 0 {
					t.Errorf("Repos should be empty, got %v", item.Repos)
				}
				if !item.DispatchedAt.IsZero() {
					t.Error("DispatchedAt should be zero")
				}
			},
		},
		{
			name:    "malformed YAML",
			content: "---\n: invalid: yaml:\n---\n",
			wantErr: true,
		},
		{
			name:    "missing opening delimiter",
			content: "no frontmatter here",
			wantErr: true,
		},
		{
			name:    "missing closing delimiter",
			content: "---\nphase: research\n",
			wantErr: true,
		},
		{
			name:    "empty file",
			content: "",
			wantErr: true,
		},
		{
			name:    "unknown phase",
			content: "---\nproject: X\nphase: banana\n---\n",
			wantErr: true,
		},
		{
			name:    "malformed dispatched-at",
			content: "---\nproject: X\nphase: research\ndispatched-at: \"not-a-date\"\n---\n",
			wantErr: true,
		},
		{
			name: "multiline objective extraction",
			content: `---
project: X
phase: research
---

## Objective

Line one.
Line two.
Line three.

## Next Section

Other stuff.
`,
			check: func(t *testing.T, item vault.WorkItem) {
				want := "Line one.\nLine two.\nLine three."
				if item.Objective != want {
					t.Errorf("Objective = %q, want %q", item.Objective, want)
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			item, err := vault.ParseContent("/fake/path/test-item.md", tt.content)
			if tt.wantErr {
				if err == nil {
					t.Fatal("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if tt.check != nil {
				tt.check(t, item)
			}
		})
	}
}

func TestParsePhase(t *testing.T) {
	tests := []struct {
		input   string
		want    vault.Phase
		wantErr bool
	}{
		{"research", vault.PhaseResearch, false},
		{"design", vault.PhaseDesign, false},
		{"planning", vault.PhasePlanning, false},
		{"building", vault.PhaseBuilding, false},
		{"done", vault.PhaseDone, false},
		{"blocked", vault.PhaseBlocked, false},
		{"invalid", "", true},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got, err := vault.ParsePhase(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Fatal("expected error")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Errorf("got %q, want %q", got, tt.want)
			}
		})
	}
}

func TestParsePriority(t *testing.T) {
	_, err := vault.ParsePriority("invalid")
	if err == nil {
		t.Fatal("expected error for invalid priority")
	}
	p, err := vault.ParsePriority("high")
	if err != nil || p != vault.PriorityHigh {
		t.Fatalf("got %q, %v", p, err)
	}
}

func TestParseLane(t *testing.T) {
	_, err := vault.ParseLane("invalid")
	if err == nil {
		t.Fatal("expected error for invalid lane")
	}
	l, err := vault.ParseLane("prep")
	if err != nil || l != vault.LanePrep {
		t.Fatalf("got %q, %v", l, err)
	}
}

func assertEqual[T comparable](t *testing.T, field string, got, want T) {
	t.Helper()
	if got != want {
		t.Errorf("%s = %v, want %v", field, got, want)
	}
}
