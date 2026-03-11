package dispatch_test

import (
	"strings"
	"testing"

	"github.com/hay-kot/psweep/internal/dispatch"
	"github.com/hay-kot/psweep/internal/vault"
)

func TestBuildPrompt(t *testing.T) {
	base := vault.WorkItem{
		Title:              "My Task",
		Project:            "TestProject",
		Repos:              []string{"https://github.com/example/repo"},
		Objective:          "Build something.",
		AcceptanceCriteria: "- It works",
		Path:               "/vault/Projects/TestProject/Work/My Task.md",
		PlanPath:           ".hive/plans/my-plan.md",
	}

	tests := []struct {
		name     string
		phase    vault.Phase
		planPath string
		required []string
	}{
		{
			name:  "research",
			phase: vault.PhaseResearch,
			required: []string{
				"My Task", "TestProject",
				"https://github.com/example/repo",
				"Build something.",
				"/vault/Projects/TestProject/Work/My Task.md",
				"/project-advance",
			},
		},
		{
			name:  "design",
			phase: vault.PhaseDesign,
			required: []string{
				"My Task", "TestProject",
				"https://github.com/example/repo",
				"Build something.",
				"- It works",
				"/project-advance",
			},
		},
		{
			name:     "planning without plan",
			phase:    vault.PhasePlanning,
			planPath: "",
			required: []string{
				"My Task", "TestProject",
				"https://github.com/example/repo",
				"Build something.",
				"- It works",
				"/plan-write",
			},
		},
		{
			name:     "planning with plan",
			phase:    vault.PhasePlanning,
			planPath: ".hive/plans/my-plan.md",
			required: []string{
				".hive/plans/my-plan.md",
				"/plan-to-hc",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			item := base
			item.Phase = tt.phase
			item.PlanPath = tt.planPath

			prompt, err := dispatch.BuildPrompt(item)
			if err != nil {
				t.Fatalf("BuildPrompt: %v", err)
			}

			for _, req := range tt.required {
				if !strings.Contains(prompt, req) {
					t.Errorf("prompt missing required string %q\nprompt:\n%s", req, prompt)
				}
			}
		})
	}
}

func TestBuildPrompt_UnsupportedPhase(t *testing.T) {
	item := vault.WorkItem{Phase: vault.PhaseBuilding}
	_, err := dispatch.BuildPrompt(item)
	if err == nil {
		t.Fatal("expected error for unsupported phase")
	}
}
