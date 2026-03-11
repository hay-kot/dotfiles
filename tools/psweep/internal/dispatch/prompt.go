package dispatch

import (
	"bytes"
	"fmt"
	"strings"
	"text/template"

	"github.com/hay-kot/psweep/internal/vault"
)

var researchTmpl = template.Must(template.New("research").Parse(`You are working on "{{.Title}}" for project {{.Project}}.

Repos: {{.ReposJoined}}

## Objective

{{.Objective}}

Work item path: {{.WorkItemPath}}

Please research this topic thoroughly, then run /project-advance to advance the work item to the next phase.
`))

var designTmpl = template.Must(template.New("design").Parse(`You are working on "{{.Title}}" for project {{.Project}}.

Repos: {{.ReposJoined}}

## Objective

{{.Objective}}

## Acceptance Criteria

{{.AcceptanceCriteria}}

Work item path: {{.WorkItemPath}}

Please create a design document, then run /project-advance to advance the work item to the next phase.
`))

var planningNoplanTmpl = template.Must(template.New("planning-noplan").Parse(`You are working on "{{.Title}}" for project {{.Project}}.

Repos: {{.ReposJoined}}

## Objective

{{.Objective}}

## Acceptance Criteria

{{.AcceptanceCriteria}}

Work item path: {{.WorkItemPath}}

Please create an implementation plan using /plan-write, then advance the work item.
`))

var planningWithplanTmpl = template.Must(template.New("planning-withplan").Parse(`You are working on "{{.Title}}" for project {{.Project}}.

A plan already exists at: {{.PlanPath}}

Please convert this plan to tracked tasks using /plan-to-hc, then advance the work item.
`))

type promptData struct {
	Title              string
	Project            string
	ReposJoined        string
	Objective          string
	AcceptanceCriteria string
	WorkItemPath       string
	PlanPath           string
}

// BuildPrompt generates the dispatch prompt for a work item based on its phase.
func BuildPrompt(item vault.WorkItem) (string, error) {
	data := promptData{
		Title:              item.Title,
		Project:            item.Project,
		ReposJoined:        strings.Join(item.Repos, ", "),
		Objective:          item.Objective,
		AcceptanceCriteria: item.AcceptanceCriteria,
		WorkItemPath:       item.Path,
		PlanPath:           item.PlanPath,
	}

	var tmpl *template.Template
	switch item.Phase {
	case vault.PhaseResearch:
		tmpl = researchTmpl
	case vault.PhaseDesign:
		tmpl = designTmpl
	case vault.PhasePlanning:
		if item.PlanPath != "" {
			tmpl = planningWithplanTmpl
		} else {
			tmpl = planningNoplanTmpl
		}
	default:
		return "", fmt.Errorf("no prompt template for phase %q", item.Phase)
	}

	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("executing template: %w", err)
	}
	return buf.String(), nil
}
