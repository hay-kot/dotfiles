package dispatch

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
)

type sessionInfo struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Repo  string `json:"repo"`
	State string `json:"state"`
}

// IsSessionAlive checks if a session is still active by querying hive session list.
func IsSessionAlive(ctx context.Context, runner CommandRunner, sessionID string) (bool, error) {
	stdout, _, err := runner.Run(ctx, "hive", []string{"session", "list", "--json"}, nil)
	if err != nil {
		return false, fmt.Errorf("checking session liveness: %w", err)
	}

	for _, line := range bytes.Split(stdout, []byte("\n")) {
		line = bytes.TrimSpace(line)
		if len(line) == 0 {
			continue
		}
		var info sessionInfo
		if err := json.Unmarshal(line, &info); err != nil {
			continue
		}
		if info.ID == sessionID {
			return info.State == "active", nil
		}
	}

	return false, nil
}
