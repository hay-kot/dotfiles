package dispatch_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/hay-kot/psweep/internal/dispatch"
)

func TestIsSessionAlive(t *testing.T) {
	jsonl := `{"id":"sess-1","name":"task-a","repo":"","state":"active"}
{"id":"sess-2","name":"task-b","repo":"","state":"recycled"}
`

	tests := []struct {
		name      string
		sessionID string
		want      bool
	}{
		{"active session", "sess-1", true},
		{"recycled session", "sess-2", false},
		{"missing session", "sess-999", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			runner := &mockRunner{stdout: []byte(jsonl)}
			alive, err := dispatch.IsSessionAlive(context.Background(), runner, tt.sessionID)
			if err != nil {
				t.Fatalf("IsSessionAlive: %v", err)
			}
			if alive != tt.want {
				t.Errorf("alive = %v, want %v", alive, tt.want)
			}
		})
	}
}

func TestIsSessionAlive_EmptyOutput(t *testing.T) {
	runner := &mockRunner{stdout: []byte("")}
	alive, err := dispatch.IsSessionAlive(context.Background(), runner, "sess-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if alive {
		t.Error("empty output should return not alive")
	}
}

func TestIsSessionAlive_HiveNotFound(t *testing.T) {
	runner := &mockRunner{err: fmt.Errorf("exec: \"hive\": executable file not found")}
	_, err := dispatch.IsSessionAlive(context.Background(), runner, "sess-1")
	if err == nil {
		t.Fatal("expected error when hive not found")
	}
}
