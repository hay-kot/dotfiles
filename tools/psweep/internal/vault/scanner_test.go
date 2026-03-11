package vault_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/hay-kot/psweep/internal/vault"
)

func TestScan(t *testing.T) {
	tests := []struct {
		name    string
		setup   func(t *testing.T) string
		want    int
		wantErr bool
	}{
		{
			name: "vault path doesn't exist",
			setup: func(t *testing.T) string {
				return filepath.Join(t.TempDir(), "nonexistent")
			},
			wantErr: true,
		},
		{
			name: "empty vault returns empty list",
			setup: func(t *testing.T) string {
				return t.TempDir()
			},
			want: 0,
		},
		{
			name: "vault with no Work dirs returns empty list",
			setup: func(t *testing.T) string {
				dir := t.TempDir()
				os.MkdirAll(filepath.Join(dir, "Projects", "MyProject"), 0o755)
				return dir
			},
			want: 0,
		},
		{
			name: "finds md files in Work directories",
			setup: func(t *testing.T) string {
				dir := t.TempDir()
				workDir := filepath.Join(dir, "Projects", "ProjectA", "Work")
				os.MkdirAll(workDir, 0o755)
				os.WriteFile(filepath.Join(workDir, "task-1.md"), []byte("test"), 0o644)
				os.WriteFile(filepath.Join(workDir, "task-2.md"), []byte("test"), 0o644)
				os.WriteFile(filepath.Join(workDir, "notes.txt"), []byte("ignored"), 0o644)
				return dir
			},
			want: 2,
		},
		{
			name: "finds across multiple projects",
			setup: func(t *testing.T) string {
				dir := t.TempDir()
				for _, proj := range []string{"Alpha", "Beta"} {
					workDir := filepath.Join(dir, "Projects", proj, "Work")
					os.MkdirAll(workDir, 0o755)
					os.WriteFile(filepath.Join(workDir, "item.md"), []byte("test"), 0o644)
				}
				return dir
			},
			want: 2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			vaultPath := tt.setup(t)
			paths, err := vault.Scan(vaultPath)
			if tt.wantErr {
				if err == nil {
					t.Fatal("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if len(paths) != tt.want {
				t.Errorf("got %d paths, want %d", len(paths), tt.want)
			}
		})
	}
}
