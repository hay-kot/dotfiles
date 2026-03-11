package vault

import (
	"fmt"
	"time"
)

// WorkItem represents a parsed work item from the Obsidian vault.
type WorkItem struct {
	Path               string
	Title              string
	Project            string
	Phase              Phase
	Priority           Priority
	AutoAdvance        bool
	GateBefore         Phase
	Lane               Lane
	Repos              []string
	DispatchedAt       time.Time
	DispatchedSession  string
	Created            string
	Objective          string
	AcceptanceCriteria string
	PlanPath           string
}

// Phase represents the lifecycle phase of a work item.
type Phase string

const (
	PhaseBacklog  Phase = "backlog"
	PhaseResearch Phase = "research"
	PhaseDesign   Phase = "design"
	PhasePlanning Phase = "planning"
	PhaseBuilding Phase = "building"
	PhaseReview   Phase = "review"
	PhaseDone     Phase = "done"
	PhaseBlocked  Phase = "blocked"
)

var phaseOrder = map[Phase]int{
	PhaseBacklog:  0,
	PhaseResearch: 1,
	PhaseDesign:   2,
	PhasePlanning: 3,
	PhaseBuilding: 4,
	PhaseReview:   5,
	PhaseDone:     6,
	PhaseBlocked:  -1,
}

// ParsePhase validates a phase string. Returns error for unknown values.
func ParsePhase(s string) (Phase, error) {
	p := Phase(s)
	if _, ok := phaseOrder[p]; !ok {
		return "", fmt.Errorf("unknown phase: %q", s)
	}
	return p, nil
}

// Order returns the numeric order for prioritization (higher = closer to building).
func (p Phase) Order() int {
	return phaseOrder[p]
}

// Priority represents the priority level of a work item.
type Priority string

const (
	PriorityHigh   Priority = "high"
	PriorityMedium Priority = "medium"
	PriorityLow    Priority = "low"
)

// ParsePriority validates a priority string. Returns error for unknown values.
func ParsePriority(s string) (Priority, error) {
	switch Priority(s) {
	case PriorityHigh, PriorityMedium, PriorityLow:
		return Priority(s), nil
	default:
		return "", fmt.Errorf("unknown priority: %q", s)
	}
}

// Lane represents the dispatch lane of a work item.
type Lane string

const (
	LaneFocus Lane = "focus"
	LanePrep  Lane = "prep"
	LaneEasy  Lane = "easy"
)

// ParseLane validates a lane string. Returns error for unknown values.
func ParseLane(s string) (Lane, error) {
	switch Lane(s) {
	case LaneFocus, LanePrep, LaneEasy:
		return Lane(s), nil
	default:
		return "", fmt.Errorf("unknown lane: %q", s)
	}
}
