---
name: init-simplified-english-contrib
description: Add ASD-STE100 Simplified Technical English guidance for LLM authors to a repository's contributing guide and pull request templates. Run only when explicitly invoked.
disable-model-invocation: true
argument-hint: "[repository-path]"
allowed-tools: "Read,Write,Edit,Glob,Bash(git rev-parse:*),Bash(git diff:*),Bash(find:*),Bash(mkdir:*)"
---

# Simplified English Contributor Guidance

Add repository guidance for contributors who use an LLM to draft prose. The
skill is idempotent: update existing guidance instead of adding a second copy.

Use `$ARGUMENTS` as the repository path when provided. Otherwise, use the
current working directory. Resolve the Git root before editing. Stop if the
path is not in a Git repository.

## Writing rules to install

Use the practical ASD-STE100 subset from Recipinned's contributor guidance:

- Use words from the STE approved-vocabulary dictionary.
- Permit repository-specific technical names that are not in the dictionary.
- Use one word for one meaning. Do not vary synonyms for style.
- Use active voice only.
- Use present or simple past tense.
- Do not use `-ing` gerunds or participles as nouns.
- Limit procedures to 20 words per sentence.
- Limit descriptions to 25 words per sentence.
- Put one instruction in each sentence.
- Do not use idioms, metaphors, or hedging.

Apply these rules to LLM authors. Human authors can write naturally with
short-to-medium sentences, active voice, and direct language.

## Update the contributing guide

Find an existing contributing guide in the repository root, `.github/`, or
`docs/`, case-insensitively. Prefer, in order:

1. A root `CONTRIBUTING.md`
2. `.github/CONTRIBUTING.md`
3. `docs/CONTRIBUTING.md`
4. The closest case or extension variant

When more than one file exists, identify the canonical guide from links and
content. Update only the canonical source. Do not edit generated or vendored
copies.

Add or update a section equivalent to this, adapting the heading level and
surrounding style without weakening the rules:

```markdown
## Writing style

This guidance applies to all contributor prose. It includes pull request
titles, pull request bodies, and commit messages.

**Human authors**: Write naturally. Use short-to-medium sentences, active
voice, and direct language. Assume that the reader knows the codebase.

**LLM authors**: Use
[ASD-STE100 Simplified Technical English](https://www.asd-ste100.org/) for all
text. Use this practical subset:

- Use words from the STE approved-vocabulary dictionary. Technical names that
  are not in the dictionary can be used as-is.
- Use one word for one meaning. Do not vary synonyms for style.
- Use active voice only. Do not use passive constructions.
- Use present or simple past tense. Do not use `-ing` gerunds or participles as
  nouns.
- Limit procedures to 20 words per sentence. Limit descriptions to 25 words
  per sentence.
- Put one instruction in each sentence.
- Do not use idioms, metaphors, or hedging.

The goal is text that each reviewer can understand in one read.
```

When useful, add a few repository-specific technical names as examples in the
first rule. Do not copy Recipinned-specific names into another repository.

Place the section near existing communication, documentation, commit, or pull
request guidance. If no contributing guide exists, create `CONTRIBUTING.md`
with a `# Contributing` title and this section. Do not invent unrelated setup,
testing, or submission instructions.

## Update pull request templates

Find pull request templates in the standard repository root, `.github/`,
`.gitea/`, and `docs/` locations, including template directories. Update every
active template because each one is a separate contributor entry point. Ignore
examples, generated files, and dependencies.

Append this standalone HTML comment to each template, unless equivalent
guidance already exists:

```markdown
<!--
If an LLM writes this pull request title, body, or any commit message on the
branch, use ASD-STE100 Simplified Technical English. Use active voice,
approved-vocabulary words, sentences of 20 words or fewer, and no gerunds.
See CONTRIBUTING.md > Writing style.
-->
```

Adjust the contributing-guide path when the canonical file has a different
name or location.

Keep the note in an HTML comment so authors see it while editing but it does not
appear in the rendered pull request. Preserve all existing headings, comments,
checkboxes, and repository-specific title or body rules.

If no template exists, create `.github/pull_request_template.md` containing the
comment. Do not add generic Summary, Changes, or Testing sections.

## Idempotence

Before adding text, search case-insensitively for `ASD-STE100`, `Simplified
Technical English`, and `LLM authors`. Reconcile equivalent existing guidance
in place. Never leave multiple copies in one document.

## Verify

Run `git diff --check`. Then report:

- the contributing guide created or updated
- every pull request template created or updated
- any equivalent guidance that was already current and left unchanged

Do not commit the changes unless the user asks.
