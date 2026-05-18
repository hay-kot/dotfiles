# Pi Agent Configuration Notes

These instructions apply when working on Pi-specific agent configuration, extensions, skills, and model selection.

## Model Selection in Pi

Pi model identifiers use provider namespaces. When selecting or documenting models, use the namespace shown by `pi --list-models`.

- Anthropic Claude models use the `anthropic` provider namespace.
  - Preferred shorthand form: `--model anthropic/<model-id>`
  - Default example: `pi --model anthropic/claude-sonnet-4-6`
- OpenAI Codex / ChatGPT subscription models use the `openai-codex` provider namespace, not `openai`.
  - Preferred shorthand form: `--model openai-codex/<model-id>`
  - Default example: `pi --model openai-codex/gpt-5.5`

Do not guess provider namespaces from product names:

- “Claude” means look under `anthropic/*`.
- “GPT”, “Codex”, or ChatGPT subscription models mean look under `openai-codex/*`.
- Use `openai/*` only when the user explicitly wants the OpenAI API-key provider and `pi --list-models` shows the desired model there.

Before adding or changing hard-coded model names, verify current availability with:

```bash
pi --list-models
pi --list-models claude
pi --list-models codex
```
