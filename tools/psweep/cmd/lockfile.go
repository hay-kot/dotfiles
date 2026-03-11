package cmd

import (
	"fmt"
	"os"
	"syscall"
)

// ProcessLock represents a process-level lockfile.
type ProcessLock struct {
	path string
	file *os.File
}

// acquireLock tries to acquire an exclusive lockfile.
func acquireLock(path string) (*ProcessLock, error) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return nil, fmt.Errorf("opening lockfile: %w", err)
	}

	err = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
	if err != nil {
		f.Close()
		return nil, fmt.Errorf("lockfile held by another process")
	}

	// Write our PID
	f.Truncate(0)
	f.Seek(0, 0)
	fmt.Fprintf(f, "%d\n", os.Getpid())
	f.Sync()

	return &ProcessLock{path: path, file: f}, nil
}

// Release releases the lockfile.
func (l *ProcessLock) Release() {
	if l.file != nil {
		syscall.Flock(int(l.file.Fd()), syscall.LOCK_UN)
		l.file.Close()
		os.Remove(l.path)
	}
}

