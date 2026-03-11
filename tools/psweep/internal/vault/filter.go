package vault

// FilterDispatchable returns work items eligible for dispatch.
// An item is dispatchable if:
//   - Lane is prep (or easy)
//   - Phase is research, design, or planning
//   - auto-advance is true
//   - repos is non-empty
//   - Not gated (gate-before would not block the current phase from advancing)
func FilterDispatchable(items []WorkItem) []WorkItem {
	var result []WorkItem
	for _, item := range items {
		if !isDispatchable(item) {
			continue
		}
		result = append(result, item)
	}
	return result
}

func isDispatchable(item WorkItem) bool {
	// Must be prep or easy lane
	if item.Lane != LanePrep && item.Lane != LaneEasy {
		return false
	}

	// Must be in a dispatchable phase
	switch item.Phase {
	case PhaseResearch, PhaseDesign, PhasePlanning:
		// ok
	default:
		return false
	}

	// Must have auto-advance enabled
	if !item.AutoAdvance {
		return false
	}

	// Must have at least one repo
	if len(item.Repos) == 0 {
		return false
	}

	// Check gate: if gate-before is set and current phase would advance
	// to or past the gated phase, skip
	if item.GateBefore != "" {
		nextPhaseOrder := item.Phase.Order() + 1
		if nextPhaseOrder >= item.GateBefore.Order() {
			return false
		}
	}

	return true
}
