package vault

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Scan finds all .md files under Projects/*/Work/ in the given vault path.
func Scan(vaultPath string) ([]string, error) {
	info, err := os.Stat(vaultPath)
	if err != nil {
		return nil, fmt.Errorf("vault path: %w", err)
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("vault path is not a directory: %s", vaultPath)
	}

	projectsDir := filepath.Join(vaultPath, "Projects")
	if _, err := os.Stat(projectsDir); os.IsNotExist(err) {
		return nil, nil
	}

	entries, err := os.ReadDir(projectsDir)
	if err != nil {
		return nil, fmt.Errorf("reading projects directory: %w", err)
	}

	var paths []string
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		workDir := filepath.Join(projectsDir, entry.Name(), "Work")
		if _, err := os.Stat(workDir); os.IsNotExist(err) {
			continue
		}

		workFiles, err := os.ReadDir(workDir)
		if err != nil {
			return nil, fmt.Errorf("reading work directory %s: %w", workDir, err)
		}
		for _, f := range workFiles {
			if f.IsDir() || !strings.HasSuffix(f.Name(), ".md") {
				continue
			}
			paths = append(paths, filepath.Join(workDir, f.Name()))
		}
	}

	return paths, nil
}
