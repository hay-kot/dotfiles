package dispatch

import (
	"regexp"
	"strings"

	"github.com/hay-kot/psweep/internal/vault"
)

// BatchInput represents the JSON input for hive batch.
type BatchInput struct {
	Sessions []BatchSession `json:"sessions"`
}

// BatchSession represents a single session in a hive batch.
type BatchSession struct {
	Name   string `json:"name"`
	Prompt string `json:"prompt"`
	Remote string `json:"remote,omitempty"`
}

var slugRe = regexp.MustCompile(`[^a-z0-9-]+`)

// slugify converts a title to a lowercase, hyphenated slug (max 30 chars).
func slugify(title string) string {
	s := strings.ToLower(title)
	s = slugRe.ReplaceAllString(s, "-")
	s = strings.Trim(s, "-")
	if len(s) > 30 {
		s = s[:30]
		s = strings.TrimRight(s, "-")
	}
	return s
}

// BuildBatch creates a BatchInput from work items with their prompts.
func BuildBatch(items []vault.WorkItem, prompts map[string]string) BatchInput {
	var sessions []BatchSession
	for _, item := range items {
		prompt, ok := prompts[item.Path]
		if !ok {
			continue
		}
		session := BatchSession{
			Name:   slugify(item.Title),
			Prompt: prompt,
		}
		if len(item.Repos) > 0 {
			session.Remote = item.Repos[0]
		}
		sessions = append(sessions, session)
	}
	return BatchInput{Sessions: sessions}
}
