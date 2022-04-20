package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"
)

const (
	CodeDirectory = "code"
)

func Must[T any](v T, err error) T {
	if err != nil {
		panic(err)
	}

	return v
}

func getCodeDir() string {
	homedir := Must(os.UserHomeDir())
	return path.Join(homedir, CodeDirectory)
}

type Repo struct {
	Name string
	Path string
}

func searchForGitRepositories(codeDir string) []Repo {

	var repos []Repo

	// Glob search for all .git directories in the code directory

	var results = Must(filepath.Glob(path.Join(codeDir, "**/*/.git")))

	for _, result := range results {
		repoPath := strings.TrimSuffix(result, ".git")

		name := filepath.Base(repoPath)

		if name == "" {
			continue
		}

		repos = append(repos, Repo{
			Name: name,
			Path: repoPath,
		})
	}

	return repos
}

func formatSearch(repos []Repo) string {
	longest := 0

	for _, repo := range repos {
		if len(repo.Name) > longest {
			longest = len(repo.Name)
		}
	}

	searchList := ""
	for _, repo := range repos {
		spaces := (longest + 5) - len(repo.Name)

		text := repo.Name + strings.Repeat(" ", spaces) + repo.Path

		searchList += text + "\n"
	}

	return searchList
}

func fzfSearch(repos []Repo) Repo {
	var parseName = func(line string) string {
		return strings.TrimSpace(strings.Split(line, "    ")[0])
	}

	searchList := formatSearch(repos)

	command := fmt.Sprintf("echo '%s' | fzf", searchList)

	// pipe list of repo names to fzf and get result
	cmd := exec.Command("bash", "-c", command)

	cmd.Stdin = os.Stdin
	cmd.Stderr = os.Stderr

	bts, err := cmd.Output()

	if err != nil {
		log.Fatal(err)
	}

	name := strings.TrimSpace(string(bts))

	name = parseName(name)

	for _, repo := range repos {

		if repo.Name == name {
			return repo
		}
	}

	panic("Could not find repo")
}

func main() {
	codeDir := getCodeDir()
	repos := searchForGitRepositories(codeDir)

	result := fzfSearch(repos)

	fmt.Print(result.Path)
}
