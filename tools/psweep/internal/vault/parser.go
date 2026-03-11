package vault

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

// frontmatter represents the YAML frontmatter of a work item.
type frontmatter struct {
	Project           string   `yaml:"project"`
	Phase             string   `yaml:"phase"`
	Priority          string   `yaml:"priority"`
	AutoAdvance       bool     `yaml:"auto-advance"`
	GateBefore        string   `yaml:"gate-before"`
	Lane              string   `yaml:"lane"`
	Repos             []string `yaml:"repos"`
	DispatchedAt      string   `yaml:"dispatched-at"`
	DispatchedSession string   `yaml:"dispatched-session"`
	Created           string   `yaml:"created"`
	Tags              []string `yaml:"tags"`
	Type              string   `yaml:"type"`
}

// Parse reads a work item markdown file and returns a WorkItem.
func Parse(path string) (WorkItem, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return WorkItem{}, fmt.Errorf("reading file: %w", err)
	}
	return ParseContent(path, string(data))
}

// ParseContent parses work item content from a string.
func ParseContent(path, content string) (WorkItem, error) {
	if len(content) == 0 {
		return WorkItem{}, fmt.Errorf("empty file: %s", path)
	}

	fm, err := extractFrontmatter(content)
	if err != nil {
		return WorkItem{}, fmt.Errorf("parsing %s: %w", path, err)
	}

	var meta frontmatter
	if err := yaml.Unmarshal([]byte(fm), &meta); err != nil {
		return WorkItem{}, fmt.Errorf("parsing YAML in %s: %w", path, err)
	}

	phase, err := ParsePhase(meta.Phase)
	if err != nil {
		return WorkItem{}, fmt.Errorf("in %s: %w", path, err)
	}

	var priority Priority
	if meta.Priority != "" {
		priority, err = ParsePriority(meta.Priority)
		if err != nil {
			return WorkItem{}, fmt.Errorf("in %s: %w", path, err)
		}
	}

	var lane Lane
	if meta.Lane != "" {
		lane, err = ParseLane(meta.Lane)
		if err != nil {
			return WorkItem{}, fmt.Errorf("in %s: %w", path, err)
		}
	}

	var gateBefore Phase
	if meta.GateBefore != "" {
		gateBefore, err = ParsePhase(meta.GateBefore)
		if err != nil {
			return WorkItem{}, fmt.Errorf("in %s gate-before: %w", path, err)
		}
	}

	var dispatchedAt time.Time
	if meta.DispatchedAt != "" {
		dispatchedAt, err = time.Parse(time.RFC3339, meta.DispatchedAt)
		if err != nil {
			return WorkItem{}, fmt.Errorf("in %s dispatched-at: %w", path, err)
		}
	}

	// Strip [[ ]] from project name
	project := strings.TrimPrefix(meta.Project, "[[")
	project = strings.TrimSuffix(project, "]]")

	title := strings.TrimSuffix(filepath.Base(path), ".md")

	item := WorkItem{
		Path:               path,
		Title:              title,
		Project:            project,
		Phase:              phase,
		Priority:           priority,
		AutoAdvance:        meta.AutoAdvance,
		GateBefore:         gateBefore,
		Lane:               lane,
		Repos:              meta.Repos,
		DispatchedAt:       dispatchedAt,
		DispatchedSession:  meta.DispatchedSession,
		Created:            meta.Created,
		Objective:          extractSection(content, "Objective"),
		AcceptanceCriteria: extractSection(content, "Acceptance Criteria"),
		PlanPath:           extractPlanPath(content),
	}

	return item, nil
}

// extractFrontmatter pulls out the YAML between --- delimiters.
func extractFrontmatter(content string) (string, error) {
	if !strings.HasPrefix(content, "---") {
		return "", fmt.Errorf("missing opening --- delimiter")
	}

	end := strings.Index(content[3:], "\n---")
	if end == -1 {
		return "", fmt.Errorf("missing closing --- delimiter")
	}

	return content[3 : end+3], nil
}

// extractSection extracts the body content of a ## heading section.
var sectionRe = regexp.MustCompile(`(?m)^## (.+)$`)

func extractSection(content, heading string) string {
	matches := sectionRe.FindAllStringSubmatchIndex(content, -1)
	for i, match := range matches {
		sectionTitle := content[match[2]:match[3]]
		if sectionTitle != heading {
			continue
		}
		start := match[1]
		var end int
		if i+1 < len(matches) {
			end = matches[i+1][0]
		} else {
			end = len(content)
		}
		return strings.TrimSpace(content[start:end])
	}
	return ""
}

// extractPlanPath finds "- Plan:" in an Artifacts section and returns the path.
func extractPlanPath(content string) string {
	artifacts := extractSection(content, "Artifacts")
	if artifacts == "" {
		return ""
	}
	for _, line := range strings.Split(artifacts, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "- Plan:") {
			path := strings.TrimPrefix(line, "- Plan:")
			path = strings.TrimSpace(path)
			// Strip [[ ]] if present
			path = strings.TrimPrefix(path, "[[")
			path = strings.TrimSuffix(path, "]]")
			return path
		}
	}
	return ""
}
