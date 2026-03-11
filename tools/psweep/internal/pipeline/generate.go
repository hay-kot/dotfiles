package pipeline

import (
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"github.com/hay-kot/psweep/internal/vault"
)

// phaseDisplayOrder defines the order phases appear in the dashboard (active first).
var phaseDisplayOrder = map[vault.Phase]int{
	vault.PhaseBuilding: 0,
	vault.PhasePlanning: 1,
	vault.PhaseDesign:   2,
	vault.PhaseResearch: 3,
	vault.PhaseBacklog:  4,
	vault.PhaseBlocked:  5,
	vault.PhaseReview:   6,
}

// Generate produces the Pipeline.md content from a list of work items.
// Items with phase "done" are excluded. The now parameter is used for
// relative time calculations (no time.Now() calls).
func Generate(items []vault.WorkItem, now time.Time) string {
	// Group by project
	byProject := make(map[string][]vault.WorkItem)
	for _, item := range items {
		if item.Phase == vault.PhaseDone {
			continue
		}
		byProject[item.Project] = append(byProject[item.Project], item)
	}

	// Sort project names
	projects := make([]string, 0, len(byProject))
	for p := range byProject {
		projects = append(projects, p)
	}
	sort.Strings(projects)

	var b strings.Builder
	fmt.Fprintf(&b, "# Pipeline\n\n")
	fmt.Fprintf(&b, "*Last updated: %s*\n", now.Format("2006-01-02 15:04"))

	for _, project := range projects {
		projectItems := byProject[project]

		// Sort by phase display order
		sort.SliceStable(projectItems, func(i, j int) bool {
			return phaseDisplayOrder[projectItems[i].Phase] < phaseDisplayOrder[projectItems[j].Phase]
		})

		// Group by phase
		byPhase := make(map[vault.Phase][]vault.WorkItem)
		for _, item := range projectItems {
			byPhase[item.Phase] = append(byPhase[item.Phase], item)
		}

		// Collect phases in display order
		var phases []vault.Phase
		seen := make(map[vault.Phase]bool)
		for _, item := range projectItems {
			if !seen[item.Phase] {
				phases = append(phases, item.Phase)
				seen[item.Phase] = true
			}
		}

		fmt.Fprintf(&b, "\n## %s\n", project)

		for _, phase := range phases {
			fmt.Fprintf(&b, "\n### %s\n\n", phase)
			for _, item := range byPhase[phase] {
				fmt.Fprintf(&b, "- %s\n", statusLine(item, now))
			}
		}
	}

	return b.String()
}

func statusLine(item vault.WorkItem, now time.Time) string {
	// Gated: has gate-before and current phase would advance to gated phase
	if item.GateBefore != "" && item.Phase.Order()+1 >= item.GateBefore.Order() {
		return fmt.Sprintf("**%s** — plan approved, waiting for human", item.Title)
	}

	// In-flight: has dispatched-at
	if !item.DispatchedAt.IsZero() {
		ago := relativeTime(now.Sub(item.DispatchedAt))
		return fmt.Sprintf("**%s** — dispatched %s ago (session: %s)", item.Title, ago, item.DispatchedSession)
	}

	// Blocked
	if item.Phase == vault.PhaseBlocked {
		return fmt.Sprintf("**%s** — blocked", item.Title)
	}

	// Backlog
	if item.Phase == vault.PhaseBacklog {
		return fmt.Sprintf("**%s** — not started", item.Title)
	}

	// Ready
	lane := ""
	if item.Lane != "" {
		lane = fmt.Sprintf(" (lane: %s)", item.Lane)
	}
	return fmt.Sprintf("**%s** — ready%s", item.Title, lane)
}

func relativeTime(d time.Duration) string {
	minutes := int(math.Round(d.Minutes()))
	if minutes < 60 {
		return fmt.Sprintf("%dm", minutes)
	}
	hours := minutes / 60
	mins := minutes % 60
	if mins == 0 {
		return fmt.Sprintf("%dh", hours)
	}
	return fmt.Sprintf("%dh%dm", hours, mins)
}
