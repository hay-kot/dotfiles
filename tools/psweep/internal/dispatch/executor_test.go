package dispatch_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/hay-kot/psweep/internal/dispatch"
)

func TestExecute_Success(t *testing.T) {
	runner := &mockRunner{
		stdout: []byte(`{"id":"sess-1"}
{"id":"sess-2"}
`),
	}

	batch := dispatch.BatchInput{
		Sessions: []dispatch.BatchSession{
			{Name: "task-1", Prompt: "do it"},
			{Name: "task-2", Prompt: "do it too"},
		},
	}

	result, err := dispatch.Execute(context.Background(), runner, batch)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if len(result.CreatedSessions) != 2 {
		t.Fatalf("got %d sessions, want 2", len(result.CreatedSessions))
	}
	if result.CreatedSessions[0] != "sess-1" {
		t.Errorf("session[0] = %q", result.CreatedSessions[0])
	}
}

func TestExecute_Error(t *testing.T) {
	runner := &mockRunner{
		stderr: []byte("hive batch failed"),
		err:    fmt.Errorf("exit status 1"),
	}

	batch := dispatch.BatchInput{Sessions: []dispatch.BatchSession{{Name: "x", Prompt: "y"}}}
	_, err := dispatch.Execute(context.Background(), runner, batch)
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestExecute_PartialFailure(t *testing.T) {
	// Only first session created successfully
	runner := &mockRunner{
		stdout: []byte(`{"id":"sess-1"}
`),
	}

	batch := dispatch.BatchInput{
		Sessions: []dispatch.BatchSession{
			{Name: "task-1", Prompt: "do it"},
			{Name: "task-2", Prompt: "do it too"},
		},
	}

	result, err := dispatch.Execute(context.Background(), runner, batch)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if len(result.CreatedSessions) != 1 {
		t.Fatalf("got %d sessions, want 1 (partial success)", len(result.CreatedSessions))
	}
}
