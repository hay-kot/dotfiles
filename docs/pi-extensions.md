# Local Pi extensions

`setup/ai.sh` links `.pi/agent/extensions` into `~/.pi/agent/extensions`.
These extensions need Pi 1.2.0 or newer and use the packages Pi supplies.
There are no extra npm dependencies to install.

Run `/reload` in an existing Pi session after changing them. Reload stops
managed shells, so do it before starting a server or a long build.

## Background shells

The `background-shell` extension replaces Pi's `bash` tool but keeps its
shell configuration, command prefix, session environment, renderers, timeout,
and output handling. Commands still running after 10 seconds return a job ID
and continue in the background. The agent can also request `background: true`
or set `yield_ms` between 0 and 600000.

- **Ctrl+B Ctrl+B**, twice within 750 ms while a shell runs in the foreground:
  background the latest foreground shell. A dim hint appears directly below
  its output, without an extra blank line, while it waits. The hint disappears
  when the command finishes or moves to the background.
  A single Ctrl+B keeps its normal editor behavior. Another key, a dialog, or
  a change of foreground shell resets the sequence.
- **Down**, from an empty prompt: highlight the accent-colored `shells (N)`
  footer label. **Enter** opens the job list and live preview. **Up/Esc** returns
  to the prompt; typing also returns to normal editing.
- **Ctrl+Shift+B** or **`/shells`**: open the job list directly.
- **Up/Down**: select a job. **k**: stop it. **Esc**: close the list.
- **`/shells output shell-1`**: print a job's output tail and log path.
- **`/shells kill shell-1`** or **`/shells kill all`**: stop jobs.

The footer shows one `shells (N)` label beside the branch name, without a
separate status row or foreground-shell count. The menu lists only background
shells, including their completed history. A compact bordered panel separates
the shell list from the live output preview, with a highlighted selected row.
Narrow terminals stack the list above the preview. Only the selected command
appears, on one truncated detail line. Up/Down switches the preview; new jobs
do not move your selection. A completed background job sends its
status, output tail, and full log path back to the agent as a follow-up.
The agent can inspect or stop jobs through `shell_jobs`.

`timeout` is a process deadline in seconds, not the foreground wait. It stays
in effect after backgrounding. Escape cancels foreground commands but does not
stop jobs that have already moved to the background.

Each job owns a process group. Stop sends SIGTERM, then SIGKILL after 500ms if
needed. Quit, reload, and session replacement stop all managed jobs without
sending completion prompts into the next session. Descendants do not outlive
their owning shell. Use `background: true`, not a trailing shell `&`.

Logs live in a private `pi-shell-jobs-*` directory under the system temporary
directory; files use mode 0600. They remain after jobs finish and can contain
sensitive command output. They have no size cap; stop noisy jobs and remove
logs when no longer needed. The manager retains at most 100 job records and
allows at most 16 concurrent shells. These are session-owned processes, not
persistent terminals: no PTY, stdin, attach, or restoration after exit.

Programmatic `bash` results keep `output`, `truncated`, `full_output_path`,
`exit_code`, and `wall_time_seconds`. A background result adds `job_id` and
`status: "running"`; its `exit_code` is `null` until the job finishes.
Use `shell_jobs` or the completion notification for the final result.

## Goals

```text
/goal Make every test in test/auth pass without changing the tests
/goal --max-turns 30 --max-tokens 150000 Implement the reviewed design and run its verification steps
/goal
/goal pause
/goal resume
/goal clear
```

A goal starts work immediately. After the agent finishes, a separate model
request checks the goal against conversation evidence. It cannot read files
or run tools itself. It returns **met**, **not_met**, or **impossible**, with a
reason. An unmet goal starts another turn with that feedback. The transcript
shows verdicts; expand them to read the reason. `/goal` shows status, the last
reason, elapsed time, evaluated turns, and output-token use.

Use a measurable condition and a concrete check. For example, name the test
command that must exit successfully rather than asking for code to be
"production ready". Conditions can contain up to 4000 characters.

Defaults are **20 evaluated turns** and **100000 output tokens**. Counts
include worker assistant output and evaluator output, not input/cache tokens
or independently billed child-agent work. Limits are soft: they stop another
request at a boundary, not midway through a response. Reaching a limit pauses
the goal. Start a new goal with larger limits to continue after exhaustion.

The evaluator defaults to the current session model with low reasoning. Use
`/goal model <provider>/<model-id>` to select a smaller evaluator from
`pi --list-models`; `/goal model current` restores the default. Pi validates
availability and authentication before accepting the model. This selection
follows the session branch and does not change the worker model.

Evaluation adds a separate request per check. Goal status includes its output
tokens; Pi's normal session totals do not include these out-of-band evaluator
requests.

A goal pauses on interruption, an agent/evaluator error, cancelled questions,
"Chat about this", or three evaluated rounds without tool use. `pause` also
interrupts current work. `clear` disables further goal continuations without
aborting an unrelated current command. Neither changes project instructions
or grants permission for external actions.

Managed background shells and native `pi-subagents` runs announced during the
session defer evaluation until they finish. Their completion notifications
supply the next turn. The subagent integration uses the package's lifecycle
events, not process polling; it does not independently recover outstanding
subagent activity after a reload. A server or watcher that runs forever keeps
evaluation waiting; stop it when its work is done. This extension does not add
Claude's timed check-ins for stalled background work.

Goal snapshots follow the session's active branch and survive compaction and
resume. Resume restores the condition and remaining budget but does not start
work until another prompt. Session-tree navigation pauses a restored goal so
old work does not restart unexpectedly. `/goal resume` explicitly restarts a
paused goal. `/goal clear` also accepts stop, off, reset, none, and cancel.

This is a local implementation of the
[Claude Code goal workflow](https://code.claude.com/docs/en/goal), not a copy of
its internal hooks. It uses Pi's final-settlement lifecycle hook, applies
explicit limits, and pauses on errors rather than adding a second retry loop.

## Structured questions

`ask_user_question` keeps its existing tool name, question schema, custom
answers, previews, multi-select, and chat escape hatch.

- A compact step bar shows question headers and marks the current and answered
  steps. Only the current question's full text appears below it.
- **Tab/Shift+Tab** move between questions and the final review. Left/Right
  also navigate when the custom input does not have focus.
- **Up/Down** select rows. A number key focuses an option.
- **Enter** chooses a single answer or toggles a multi-select option.
  **Space** also toggles multi-select options.
- Custom text replaces “Type something.” inline in the numbered row, with no
  extra placeholder or input line. Pi's `Input` supplies the cursor, paste,
  Unicode, and editing shortcuts. Long answers scroll horizontally.
- Single-choice and custom answers advance with **Enter**, without a separate
  Submit button. Multi-select shows **Submit** only when there is an answer.
  Multiple questions have a final review step. **Esc** cancels the interaction.

Option labels and descriptions wrap under their text, not under the number
or selection marker. Resizing recalculates layout. Previews appear below the
options and return with the selected answers.

The custom question UI requires terminal mode. RPC, JSON, and print modes
return an explicit unsupported-UI result rather than trying to open a terminal
component.

## Checks

```sh
mi pi:fmt
mi pi:check
mi pi:test
```

The checks use the installed Pi runtime and TypeScript compiler, with no local
`node_modules` or package installation. `PI_PACKAGE_DIR` can point at another
Pi package directory. Tests cover process lifetimes, output and cancellation,
goal evaluation and limits, extension loading, footer statuses, question
navigation, input focus, Unicode, paste, and narrow/resize layouts. Model
responses are mocked; tests do not send requests to a model provider.
