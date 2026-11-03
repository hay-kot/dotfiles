import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  Input,
  Key,
  matchesKey,
  truncateToWidth,
  visibleWidth,
  wrapTextWithAnsi,
} from "@earendil-works/pi-tui";
import { Type } from "typebox";

const MAX_QUESTIONS = 4;
const MIN_OPTIONS = 2;
const MAX_OPTIONS = 4;
const MAX_HEADER_LENGTH = 16;
const MAX_LABEL_LENGTH = 60;
const CUSTOM_LABEL = "Type something.";
const CHAT_LABEL = "Chat about this";
const RESERVED_LABELS = new Set([
  "Other",
  CUSTOM_LABEL,
  CHAT_LABEL,
  "Next question",
]);
const DECLINE_MESSAGE = "User declined to answer questions";
const CHAT_MESSAGE =
  "User wants to chat about this. Continue the conversation to help them decide.";

interface QuestionOption {
  label: string;
  description: string;
  preview?: string;
}
interface QuestionData {
  question: string;
  header: string;
  options: QuestionOption[];
  multiSelect?: boolean;
}
interface QuestionParams {
  questions: QuestionData[];
}
interface QuestionAnswer {
  questionIndex: number;
  question: string;
  kind: "option" | "custom" | "chat" | "multi";
  answer: string | null;
  selected?: string[];
  notes?: string;
  preview?: string;
}
interface QuestionnaireResult {
  answers: QuestionAnswer[];
  cancelled: boolean;
  error?: string;
}

const QuestionParamsSchema = Type.Object({
  questions: Type.Array(
    Type.Object({
      question: Type.String({
        description:
          "The complete question to ask the user. Should be clear, specific, and end with a question mark.",
      }),
      header: Type.String({
        maxLength: MAX_HEADER_LENGTH,
        description:
          "MAX 16 CHARACTERS. Very short chip/tag shown next to the question.",
      }),
      options: Type.Array(
        Type.Object({
          label: Type.String({
            maxLength: MAX_LABEL_LENGTH,
            description: "MAX 60 CHARACTERS. Longer labels are rejected.",
          }),
          description: Type.String({
            description:
              "Explanation of what this option means or what will happen if chosen.",
          }),
          preview: Type.Optional(
            Type.String({
              description:
                "Optional preview content rendered when this option is focused and returned when selected.",
            }),
          ),
        }),
        {
          minItems: MIN_OPTIONS,
          maxItems: MAX_OPTIONS,
          description: "Available choices (2-4 options).",
        },
      ),
      multiSelect: Type.Optional(
        Type.Boolean({
          default: false,
          description: "Allow multiple answers and custom text.",
        }),
      ),
    }),
    {
      minItems: 1,
      maxItems: MAX_QUESTIONS,
      description: "Questions to ask the user (1-4 questions).",
    },
  ),
});

function validate(params: QuestionParams): string | undefined {
  if (!params.questions?.length || params.questions.length > MAX_QUESTIONS)
    return "Provide 1-4 questions";
  const seenQuestions = new Set<string>();
  for (const question of params.questions) {
    if (seenQuestions.has(question.question))
      return "Question text must be unique";
    seenQuestions.add(question.question);
    if (question.header.length > MAX_HEADER_LENGTH)
      return "Question headers must contain at most 16 characters";
    if (
      question.options.length < MIN_OPTIONS ||
      question.options.length > MAX_OPTIONS
    )
      return "Each question requires 2-4 options";
    const labels = new Set<string>();
    for (const option of question.options) {
      if (RESERVED_LABELS.has(option.label))
        return `Reserved option label: ${option.label}`;
      if (labels.has(option.label))
        return "Option labels must be unique within a question";
      if (option.label.length > MAX_LABEL_LENGTH)
        return "Option labels must contain at most 60 characters";
      labels.add(option.label);
    }
  }
}

function result(text: string, details: QuestionnaireResult) {
  return { content: [{ type: "text" as const, text }], details };
}

function formatAnswer(answer: QuestionAnswer): string {
  if (answer.kind === "chat") return CHAT_MESSAGE;
  if (answer.kind === "multi")
    return answer.selected?.join(", ") || "(no input)";
  return answer.answer || "(no input)";
}

function buildResponse(details: QuestionnaireResult) {
  if (details.cancelled || !details.answers.length)
    return result(DECLINE_MESSAGE, details);
  const segments = details.answers.map((answer) => {
    const parts = [`"${answer.question}"="${formatAnswer(answer)}"`];
    if (answer.preview) parts.push(`selected preview: ${answer.preview}`);
    if (answer.notes) parts.push(`user notes: ${answer.notes}`);
    return `${parts.join(". ")}.`;
  });
  return result(
    `User has answered your questions: ${segments.join(" ")} You can now continue with the user's answers in mind.`,
    details,
  );
}

async function questionnaire(
  ctx: ExtensionContext,
  questions: QuestionData[],
  signal?: AbortSignal,
) {
  return ctx.ui.custom<QuestionnaireResult>((tui, theme, _kb, done) => {
    const states = questions.map(() => ({
      focused: 0,
      selected: new Set<number>(),
      input: new Input(),
    }));
    const answers = new Map<number, QuestionAnswer>();
    let current = 0;
    let focused = false;
    let completed = false;

    function finish(cancelled: boolean) {
      if (completed) return;
      completed = true;
      signal?.removeEventListener("abort", cancel);
      done({
        answers: [...answers.values()].sort(
          (a, b) => a.questionIndex - b.questionIndex,
        ),
        cancelled,
      });
    }
    function cancel() {
      finish(true);
    }
    signal?.addEventListener("abort", cancel, { once: true });
    if (signal?.aborted) queueMicrotask(cancel);

    function syncFocus() {
      states.forEach((state, i) => {
        state.input.focused =
          focused &&
          current === i &&
          state.focused === questions[i]!.options.length;
      });
    }
    function refresh() {
      syncFocus();
      tui.requestRender();
    }
    function navigate(delta: number) {
      current =
        (current + delta + questions.length + 1) % (questions.length + 1);
      refresh();
    }
    function save(answer: QuestionAnswer) {
      answers.set(current, answer);
      if (answer.kind === "chat" || questions.length === 1) {
        finish(false);
        return;
      }
      const missing = questions.findIndex((_q, index) => !answers.has(index));
      current = missing < 0 ? questions.length : missing;
      refresh();
    }
    function canSubmit() {
      const state = states[current]!;
      return Boolean(
        questions[current]?.multiSelect &&
        (state.selected.size || state.input.getValue().trim()),
      );
    }
    function chatRow() {
      const q = questions[current]!;
      return q.options.length + (q.multiSelect ? 2 : 1);
    }
    function submitQuestion() {
      const q = questions[current]!;
      const state = states[current]!;
      const custom = state.input.getValue().trim();
      if (q.multiSelect) {
        const selected = q.options.filter((_option, i) =>
          state.selected.has(i),
        );
        const values = selected.map((option) => option.label);
        if (custom) values.push(custom);
        if (!values.length) return;
        save({
          questionIndex: current,
          question: q.question,
          kind: "multi",
          answer: null,
          selected: values,
          preview:
            selected
              .map((option) => option.preview)
              .filter(Boolean)
              .join("\n") || undefined,
        });
      } else if (state.focused < q.options.length) {
        const option = q.options[state.focused]!;
        save({
          questionIndex: current,
          question: q.question,
          kind: "option",
          answer: option.label,
          preview: option.preview,
        });
      } else if (custom) {
        save({
          questionIndex: current,
          question: q.question,
          kind: "custom",
          answer: custom,
        });
      }
    }

    function wrapped(
      lines: string[],
      prefix: string,
      text: string,
      width: number,
    ) {
      const indent = visibleWidth(prefix);
      if (indent >= width) {
        lines.push(...wrapTextWithAnsi(prefix + text, Math.max(1, width)));
        return;
      }
      wrapTextWithAnsi(text, width - indent).forEach((line, i) => {
        lines.push(`${i ? " ".repeat(indent) : prefix}${line}`);
      });
    }

    return {
      get focused() {
        return focused;
      },
      set focused(value: boolean) {
        focused = value;
        syncFocus();
      },
      dispose() {
        signal?.removeEventListener("abort", cancel);
      },
      invalidate() {
        for (const state of states) state.input.invalidate();
      },
      render(width) {
        width = Math.max(1, width);
        const lines = [theme.fg("borderMuted", "─".repeat(width)), ""];
        const steps = questions.map((q, i) => {
          const marker = i === current ? "> " : answers.has(i) ? "x " : "";
          const label = `[${marker}${i + 1} ${q.header}]`;
          return i === current
            ? theme.bg("selectedBg", theme.fg("accent", label))
            : theme.fg(answers.has(i) ? "success" : "muted", label);
        });
        if (questions.length > 1)
          steps.push(
            theme.fg(
              current === questions.length ? "accent" : "dim",
              `[${current === questions.length ? "> " : ""}Review]`,
            ),
          );
        wrapped(lines, " ", steps.join(" "), width);
        lines.push("");
        const q = questions[current];
        if (!q) {
          for (let i = 0; i < questions.length; i++) {
            const answer = answers.get(i);
            wrapped(
              lines,
              " ",
              `${questions[i]!.header}: ${answer ? formatAnswer(answer) : "(unanswered)"}`,
              width,
            );
          }
          lines.push("");
          wrapped(
            lines,
            " ",
            theme.fg(
              answers.size === questions.length ? "success" : "warning",
              answers.size === questions.length
                ? "Enter to submit answers"
                : "Answer each question before submitting",
            ),
            width,
          );
        } else {
          wrapped(lines, " ", theme.fg("text", theme.bold(q.question)), width);
          lines.push("");
          const state = states[current]!;
          for (let i = 0; i <= q.options.length; i++) {
            const active = state.focused === i;
            const checked =
              i < q.options.length
                ? state.selected.has(i)
                : Boolean(state.input.getValue().trim());
            const prefix = `${active ? "> " : "  "}${i + 1}. ${q.multiSelect ? `${checked ? "[x]" : "[ ]"} ` : ""}`;
            const option = q.options[i];
            const styledPrefix = theme.fg(active ? "accent" : "text", prefix);
            if (!option) {
              const inputPrefix =
                visibleWidth(prefix) < width ? styledPrefix : "";
              const inputWidth = Math.max(1, width - visibleWidth(inputPrefix));
              const content =
                active || state.input.getValue()
                  ? (state.input.render(inputWidth)[0] ?? "")
                  : truncateToWidth(theme.fg("dim", CUSTOM_LABEL), inputWidth);
              lines.push(inputPrefix + content);
              continue;
            }
            wrapped(
              lines,
              styledPrefix,
              theme.fg(active ? "accent" : "text", option.label),
              width,
            );
            wrapped(
              lines,
              " ".repeat(visibleWidth(prefix)),
              theme.fg("dim", option.description),
              width,
            );
          }
          lines.push("");
          if (q.multiSelect) {
            if (canSubmit())
              wrapped(
                lines,
                state.focused === q.options.length + 1 ? "> " : "  ",
                "Submit",
                width,
              );
            else lines.push("");
          }
          wrapped(
            lines,
            state.focused === chatRow() ? "> " : "  ",
            CHAT_LABEL,
            width,
          );
          const previews = q.options.map((option) => {
            const rows: string[] = [];
            if (option.preview)
              wrapped(rows, " ", theme.fg("muted", option.preview), width);
            return rows;
          });
          const previewHeight = Math.max(
            0,
            ...previews.map((rows) => rows.length),
          );
          if (previewHeight) {
            const preview = previews[state.focused] ?? [];
            lines.push(
              "",
              ...preview,
              ...Array<string>(previewHeight - preview.length).fill(""),
            );
          }
        }
        lines.push("");
        wrapped(
          lines,
          " ",
          theme.fg(
            "dim",
            "Tab/Shift+Tab questions | Up/Down options | Enter confirm | Esc cancel",
          ),
          width,
        );
        lines.push(theme.fg("borderMuted", "─".repeat(width)));
        return lines.map((line) => truncateToWidth(line, width));
      },
      handleInput(data) {
        if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
          cancel();
          return;
        }
        if (matchesKey(data, Key.tab)) {
          navigate(1);
          return;
        }
        if (matchesKey(data, Key.shift("tab"))) {
          navigate(-1);
          return;
        }
        const q = questions[current];
        if (!q) {
          if (matchesKey(data, Key.enter) && answers.size === questions.length)
            finish(false);
          else if (matchesKey(data, Key.left)) navigate(-1);
          else if (matchesKey(data, Key.right)) navigate(1);
          return;
        }
        const state = states[current]!;
        if (matchesKey(data, Key.up) || matchesKey(data, Key.down)) {
          const direction = matchesKey(data, Key.up) ? -1 : 1;
          let next = state.focused + direction;
          if (q.multiSelect && !canSubmit() && next === q.options.length + 1)
            next += direction;
          state.focused = Math.max(0, Math.min(chatRow(), next));
          refresh();
          return;
        }
        if (matchesKey(data, Key.enter)) {
          if (state.focused === chatRow()) {
            save({
              questionIndex: current,
              question: q.question,
              kind: "chat",
              answer: CHAT_LABEL,
            });
          } else if (q.multiSelect && state.focused < q.options.length) {
            if (state.selected.has(state.focused))
              state.selected.delete(state.focused);
            else state.selected.add(state.focused);
            answers.delete(current);
          } else submitQuestion();
          refresh();
          return;
        }
        if (state.focused === q.options.length) {
          const before = state.input.getValue();
          state.input.handleInput(data);
          if (before !== state.input.getValue()) answers.delete(current);
        } else if (matchesKey(data, Key.left)) {
          navigate(-1);
          return;
        } else if (matchesKey(data, Key.right)) {
          navigate(1);
          return;
        } else if (
          q.multiSelect &&
          data === " " &&
          state.focused < q.options.length
        ) {
          if (state.selected.has(state.focused))
            state.selected.delete(state.focused);
          else state.selected.add(state.focused);
          answers.delete(current);
        } else if (
          /^[1-9]$/.test(data) &&
          Number(data) <= q.options.length + 1
        ) {
          state.focused = Number(data) - 1;
        }
        refresh();
      },
    };
  });
}

export default function askUserQuestionExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ask_user_question",
    label: "Ask User Question",
    description: `Ask the user one or more structured questions during execution. Use to gather preferences, clarify requirements, get implementation decisions, or offer choices.
Users can type a custom answer in the automatically appended "Type something." row, or pick "Chat about this" to continue in free-form conversation.
Use multiSelect:true for multiple answers, including custom text. Preview text appears when an option is focused and returns with selected answers.
Do not author "Other", "Type something.", "Chat about this", or "Next question" as option labels.`,
    promptSnippet:
      "Ask the user up to 4 structured questions (2-4 options each) when requirements are ambiguous",
    promptGuidelines: [
      "Use ask_user_question whenever the user's request is underspecified and you cannot proceed without concrete decisions. Ask up to 4 questions per invocation.",
      "Each question MUST have 2-4 options, each with a concise label and a description explaining the trade-off.",
      "Set multiSelect:true when multiple answers are valid. Group clarifying questions into one invocation instead of stacking calls.",
    ],
    parameters: QuestionParamsSchema,
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      if (ctx.mode !== "tui")
        return result("Error: Terminal UI not available", {
          answers: [],
          cancelled: true,
          error: "no_ui",
        });
      const error = validate(params);
      if (error)
        return result(`Error: ${error}`, {
          answers: [],
          cancelled: true,
          error: "invalid_questions",
        });
      return buildResponse(await questionnaire(ctx, params.questions, signal));
    },
  });
}
