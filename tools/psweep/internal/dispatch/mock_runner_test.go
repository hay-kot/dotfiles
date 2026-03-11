package dispatch_test

import (
	"context"
	"io"
)

// mockRunner implements dispatch.CommandRunner for testing.
type mockRunner struct {
	stdout []byte
	stderr []byte
	err    error
}

func (m *mockRunner) Run(_ context.Context, _ string, _ []string, _ io.Reader) ([]byte, []byte, error) {
	return m.stdout, m.stderr, m.err
}
