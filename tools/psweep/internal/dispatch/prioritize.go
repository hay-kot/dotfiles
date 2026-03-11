package dispatch

import (
	"sort"

	"github.com/hay-kot/psweep/internal/vault"
)

var priorityOrder = map[vault.Priority]int{
	vault.PriorityHigh:   3,
	vault.PriorityMedium: 2,
	vault.PriorityLow:    1,
	"":                   0,
}

// Prioritize sorts items by priority (high first) then phase proximity to building
// (planning > design > research), and truncates to maxItems.
func Prioritize(items []vault.WorkItem, maxItems int) []vault.WorkItem {
	sort.SliceStable(items, func(i, j int) bool {
		pi := priorityOrder[items[i].Priority]
		pj := priorityOrder[items[j].Priority]
		if pi != pj {
			return pi > pj
		}
		return items[i].Phase.Order() > items[j].Phase.Order()
	})

	if maxItems > 0 && len(items) > maxItems {
		items = items[:maxItems]
	}
	return items
}
