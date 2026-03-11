package vault_test

import (
	"testing"

	"github.com/hay-kot/psweep/internal/vault"
)

func TestFilterDispatchable(t *testing.T) {
	base := vault.WorkItem{
		Lane:        vault.LanePrep,
		Phase:       vault.PhaseResearch,
		AutoAdvance: true,
		Repos:       []string{"https://github.com/example/repo"},
	}

	tests := []struct {
		name string
		mod  func(vault.WorkItem) vault.WorkItem
		want bool
	}{
		{
			name: "fully dispatchable",
			mod:  func(w vault.WorkItem) vault.WorkItem { return w },
			want: true,
		},
		{
			name: "wrong lane (focus)",
			mod:  func(w vault.WorkItem) vault.WorkItem { w.Lane = vault.LaneFocus; return w },
			want: false,
		},
		{
			name: "easy lane is dispatchable",
			mod:  func(w vault.WorkItem) vault.WorkItem { w.Lane = vault.LaneEasy; return w },
			want: true,
		},
		{
			name: "wrong phase (building)",
			mod:  func(w vault.WorkItem) vault.WorkItem { w.Phase = vault.PhaseBuilding; return w },
			want: false,
		},
		{
			name: "wrong phase (done)",
			mod:  func(w vault.WorkItem) vault.WorkItem { w.Phase = vault.PhaseDone; return w },
			want: false,
		},
		{
			name: "design phase is dispatchable",
			mod:  func(w vault.WorkItem) vault.WorkItem { w.Phase = vault.PhaseDesign; return w },
			want: true,
		},
		{
			name: "planning phase is dispatchable",
			mod:  func(w vault.WorkItem) vault.WorkItem { w.Phase = vault.PhasePlanning; return w },
			want: true,
		},
		{
			name: "auto-advance false",
			mod:  func(w vault.WorkItem) vault.WorkItem { w.AutoAdvance = false; return w },
			want: false,
		},
		{
			name: "empty repos",
			mod:  func(w vault.WorkItem) vault.WorkItem { w.Repos = nil; return w },
			want: false,
		},
		{
			name: "gated - research gated before design blocks",
			mod: func(w vault.WorkItem) vault.WorkItem {
				w.Phase = vault.PhaseResearch
				w.GateBefore = vault.PhaseDesign
				return w
			},
			want: false,
		},
		{
			name: "gated - research gated before building does not block",
			mod: func(w vault.WorkItem) vault.WorkItem {
				w.Phase = vault.PhaseResearch
				w.GateBefore = vault.PhaseBuilding
				return w
			},
			want: true,
		},
		{
			name: "gated - planning gated before building blocks",
			mod: func(w vault.WorkItem) vault.WorkItem {
				w.Phase = vault.PhasePlanning
				w.GateBefore = vault.PhaseBuilding
				return w
			},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			item := tt.mod(base)
			result := vault.FilterDispatchable([]vault.WorkItem{item})
			got := len(result) > 0
			if got != tt.want {
				t.Errorf("got dispatchable=%v, want %v", got, tt.want)
			}
		})
	}
}
