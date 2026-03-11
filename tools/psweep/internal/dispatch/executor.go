package dispatch

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
)

// DispatchResult contains the outcome of a batch dispatch.
type DispatchResult struct {
	CreatedSessions []string
}

// Execute dispatches work via hive batch and returns the created session IDs.
func Execute(ctx context.Context, runner CommandRunner, batch BatchInput) (DispatchResult, error) {
	input, err := json.Marshal(batch)
	if err != nil {
		return DispatchResult{}, fmt.Errorf("marshaling batch input: %w", err)
	}

	stdout, stderr, err := runner.Run(ctx, "hive", []string{"batch"}, bytes.NewReader(input))
	if err != nil {
		return DispatchResult{}, fmt.Errorf("hive batch: %w (stderr: %s)", err, string(stderr))
	}

	var result DispatchResult
	// hive batch outputs JSON with session info
	// Parse each line as potential JSON with an "id" field
	for _, line := range bytes.Split(stdout, []byte("\n")) {
		line = bytes.TrimSpace(line)
		if len(line) == 0 {
			continue
		}
		var entry struct {
			ID string `json:"id"`
		}
		if json.Unmarshal(line, &entry) == nil && entry.ID != "" {
			result.CreatedSessions = append(result.CreatedSessions, entry.ID)
		}
	}

	return result, nil
}
