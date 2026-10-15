---
name: responsible-model
description: >
  Opt-in cost-aware delegation policy for routing bounded work to the smallest
  capable native subagent model. Use only when invoked directly to delegate
  work responsibly across Claude Code or Pi without crossing harness boundaries.
argument-hint: "[task or routing goal]"
disable-model-invocation: true
---

# Responsible model delegation

Use native subagents where they save cost or protect the parent context. Route each
assignment to the smallest model likely to complete it correctly.

Invocation authorizes subagent delegation for the work covered by this invocation.
It does not require delegation and does not authorize new product decisions,
external communication, commits, pushes, or other actions the user did not request.
Apply this policy to subsequent delegations in the current conversation until the
user changes it. Do not change the parent model or persist settings.

Invoke with `/responsible-model` in Claude Code or `/skill:responsible-model` in Pi.
An optional task after the command defines the work to apply it to. Without a task,
apply it to the current work; if nothing is pending, acknowledge the policy and wait.

## Guardrails

1. **Keep work in the active harness.**
   - In Claude Code, use the native `Agent` tool and Claude models only. Never launch
     GPT, Codex, Pi, or another CLI as a substitute subagent.
   - In Pi, use native Pi children through `pi-subagents`. Call `subagents_enable`
     first when the subagent tool is not active. Inspect discovered agents with
     `subagent({ action: "list", capabilities: true })` and select a native runner,
     not an external CLI adapter such as `claude-code*`, `codex-exec*`, or
     `cursor-agent*`. Do not shell out to another harness to create a child.
   - If no native subagent runtime is available, work directly and say that native
     delegation was unavailable.
2. **Use only available agents and models.** Inspect the harness's agent list rather
   than inventing an agent name. In Pi, inspect `PI_PROVIDER` and `PI_MODEL`, then
   call `subagent({ action: "models" })` and copy an exact `provider/id` from the
   live session registry. Use `pi --list-models claude` or `pi --list-models codex`
   only as a cross-check. Model catalogs change; old IDs here are not authority.
   A catalog entry does not prove access: respect authentication, model allowlists,
   quotas, tool restrictions, and the runtime's resolved model.
3. **Stay in the parent's provider family by default.** An Anthropic parent uses
   Claude children. An `openai-codex` parent uses GPT children. Pi may cross providers
   only when the user asks for it or the current task already defines a mixed fleet.
   Claude Code must never cross to GPT.
4. **Delegate bounded outcomes, not ownership.** The parent retains scope, decisions,
   synthesis, final validation, and user communication. Give each child a clear goal,
   relevant files, edit authority, constraints, acceptance criteria, validation, and
   expected report.
5. **Do not delegate tiny coupled work.** Keep a task in the parent when explaining it
   would cost as much as doing it, when it depends heavily on current conversation
   context, or when the parent must immediately use every detail of the result.
6. **Do not fan out by habit.** Use one child for one bounded task. Parallelize only
   independent tasks with non-overlapping write ownership. Never assign two writers
   to the same checkout or files concurrently.
7. **Escalate, do not overprovision.** Start at the lowest suitable tier. Move only the
   blocked or uncertain remainder up one tier after a concrete failure, ambiguity, or
   confidence warning. Do not rerun successful work on a larger model for ceremony.
8. **Match tools to authority.** Inspect each role's actual tools; a read-only task
   does not make a write-capable agent read-only. For exploration, review, and
   planning, explicitly forbid project edits and mutating shell commands. When
   tool-enforced read-only access is required, choose a role with restricted tools;
   a prompt is not a sandbox. Children must not spawn more children unless the user
   explicitly requested nested delegation.
9. **Keep context and effort proportional.** Prefer fresh, compact handoffs over the
   entire conversation for bounded work. In Pi, explicitly pass `context: "fresh"`;
   use `context: "fork"` only when inherited conversation history is needed. Use
   only supported effort parameters and avoid premium fast modes unless requested.
   Do not constrain editing workers with arbitrary tiny turn or tool budgets that
   can leave partial changes.
10. **Separate access failures from capability failures.** Rate limits, missing auth,
    and launch errors are not reasons to buy more reasoning. Report the error and
    inspect partial work before any explicit retry; never silently switch models.

## Routing test

Before each launch, classify the assignment:

- **Focused worker**
  - Use for mechanical or tightly specified edits, file discovery, pattern
    collection, routine tests, formatting, simple docs, and narrow transformations.
  - Do not use for architecture choices, ambiguous debugging, broad refactors,
    or independent product decisions.
- **Capable coder**
  - Use for multi-file implementation within an approved design, non-obvious
    debugging, integration work, serious code review, and changes that need
    coding judgment.
  - Do not use for routine lookup or mechanical work a focused worker can do.
- **Top reasoner**
  - Use for planning with real ambiguity, difficult architecture, stubborn
    root-cause analysis after a lower tier fails, or a bounded high-risk critique.
  - Do not use for routine implementation, first-pass exploration, test execution,
    formatting, or ordinary review.

When a task mixes tiers, split it by outcome. For example, have the parent approve
the design for the hard seam, let a capable coder implement it, then give
repetitive follow-up edits to focused workers. Return unresolved design choices
to the parent.
Do not ask a focused worker to make hidden design decisions inside a supposedly
mechanical assignment.

## Claude model policy

Use Claude Code's per-invocation model parameter and native aliases:

| Tier           | Model    | Typical effort         |
| -------------- | -------- | ---------------------- |
| Focused worker | `haiku`  | low or medium          |
| Capable coder  | `sonnet` | medium or high         |
| Top reasoner   | `opus`   | high; bounded use only |

Haiku is the default for small delegated work, including tightly specified edits.
Sonnet handles harder coding and debugging. Opus is reserved for planning with real
ambiguity, unresolved complexity, or very difficult work. A Fable or Opus parent should
still route ordinary children down this table instead of making every child inherit
the parent model.

Use only subagent types shown by Claude Code. Prefer a read-only Explore-style agent
for lookup and a mutation-capable general or custom agent for approved edits. Pass the
model on the invocation when the tool supports it. Do not edit global environment
variables or settings merely to route one task. Explore is read-only, so it must not
receive an edit assignment. A Claude conversation fork inherits the parent model;
do not use a fork when the goal is a cheaper worker.

In Pi, use the same Haiku / Sonnet / Opus families under the native `anthropic`
provider, with a fully qualified ID verified from the current catalog. Do not pass
Claude Code aliases as if they were Pi agent names.

## GPT model policy in Pi

Map the OpenAI Codex fleet by capability family, then choose the newest available
native model in that family:

| Tier           | Family | Current example            | Typical effort                  |
| -------------- | ------ | -------------------------- | ------------------------------- |
| Focused worker | Luna   | `openai-codex/gpt-6-luna`  | low or medium                   |
| Capable coder  | Sol    | `openai-codex/gpt-6.1-sol` | medium or high                  |
| Top reasoner   | Astra  | `openai-codex/gpt-6-astra` | high or xhigh; bounded use only |

Luna is the primary GPT worker. Use it for most implementation, scouting, routine
review, and validation. Move to Sol when the task needs stronger coding judgment or
Luna returns a concrete blocker. Reserve Astra for ambiguous planning, difficult
architecture, persistent root-cause work, or a bounded final critique.

The exact IDs above are examples from the current catalog, not permanent constants.
If a family is unavailable, choose a cheaper available model from the same provider
when it remains capable. Otherwise do the work in the parent. Inherit the parent
model for a child only when it fits the task's capability and cost tier, not merely
because the cheaper family is unavailable. Never silently switch providers.

For Pi roles, prefer `scout` for focused discovery, `worker` for approved
implementation, `reviewer` for fresh review, and `oracle` only for bounded top-tier
advice. `scout` has write and shell tools, `oracle` has shell tools, and `delegate`
can mutate files. Give them explicit authority boundaries; do not assume their
names enforce read-only access. Inspect actual tools because local definitions may
replace these built-ins. The packaged `oracle` defaults to forked context, so pass
`context: "fresh"` explicitly unless inherited history is part of its assignment.

Read the installed `pi-subagents` skill for the launch contract. Use the live
`subagent({ action: "models" })` result for candidate IDs and role defaults. Pass
an explicit per-run `model` with an effort suffix, for example
`model: "openai-codex/gpt-6-luna:low"`, using a verified model and supported level.
Do not pass a separate `thinking` dispatch field; it controls watchdog
configuration, not child launches. Keep overrides per-run; this skill does not
install profiles or change global role definitions.

## Launch contract

Every child prompt must state:

- the exact outcome and scope
- repository, working directory, and relevant files or symbols
- whether it may read, edit, run tests, or only advise
- decisions already made and decisions it must return to the parent
- acceptance criteria and focused validation
- the requested concise report: changed files, checks run, failures, and open questions
- a stop rule for ambiguity, scope expansion, unsafe actions, or missing access

After children finish, inspect their evidence and diffs. The parent resolves conflicts,
runs or confirms final validation, and reports the result. A child result is evidence,
not automatic acceptance.

## References

- [Claude Code subagent models](https://code.claude.com/docs/en/sub-agents#choose-a-model)
- [OpenAI model selection](https://developers.openai.com/api/docs/guides/model-selection)

These explain the native model controls and family roles. The live harness catalog,
access policy, and explicit user choices take precedence over the examples here.
