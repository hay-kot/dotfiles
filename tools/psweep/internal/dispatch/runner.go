package dispatch

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os/exec"
)

// CommandRunner abstracts subprocess execution for testability.
type CommandRunner interface {
	Run(ctx context.Context, name string, args []string, stdin io.Reader) (stdout []byte, stderr []byte, err error)
}

// ExecRunner is the real implementation using os/exec.
type ExecRunner struct{}

// Run executes a command with stdin, returns stdout, stderr, and error.
func (r *ExecRunner) Run(ctx context.Context, name string, args []string, stdin io.Reader) ([]byte, []byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf
	cmd.Stderr = &stderrBuf
	if stdin != nil {
		cmd.Stdin = stdin
	}
	err := cmd.Run()
	if err != nil {
		return stdoutBuf.Bytes(), stderrBuf.Bytes(), fmt.Errorf("%s: %w (stderr: %s)", name, err, stderrBuf.String())
	}
	return stdoutBuf.Bytes(), stderrBuf.Bytes(), nil
}
