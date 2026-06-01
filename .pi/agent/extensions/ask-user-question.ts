import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  Key,
  matchesKey,
  truncateToWidth,
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

const OptionSchema = Type.Object({
  label: Type.String({
    maxLength: MAX_LABEL_LENGTH,
    description: `MAX ${MAX_LABEL_LENGTH} CHARACTERS — hard limit, requests over the limit are rejected.`,
  }),
  description: Type.String({
    description:
      "Explanation of what this option means or what will happen if chosen.",
  }),
  preview: Type.Optional(
    Type.String({
      description:
        "Optional preview content rendered when this option is focused.",
    }),
  ),
});

const QuestionSchema = Type.Object({
  question: Type.String({
    description:
      "The complete question to ask the user. Should be clear, specific, and end with a question mark.",
  }),
  header: Type.String({
    maxLength: MAX_HEADER_LENGTH,
    description: `MAX ${MAX_HEADER_LENGTH} CHARACTERS — hard limit. Very short chip/tag shown next to the question.`,
  }),
  options: Type.Array(OptionSchema, {
    minItems: MIN_OPTIONS,
    maxItems: MAX_OPTIONS,
    description:
      "The available choices for this question. Must have 2-4 options.",
  }),
  multiSelect: Type.Optional(
    Type.Boolean({
      default: false,
      description:
        "Set to true to allow the user to select multiple options instead of just one.",
    }),
  ),
});

const QuestionParamsSchema = Type.Object({
  questions: Type.Array(QuestionSchema, {
    minItems: 1,
    maxItems: MAX_QUESTIONS,
    description: "Questions to ask the user (1-4 questions)",
  }),
});

function validate(
  params: QuestionParams,
): { ok: true } | { ok: false; error: string; message: string } {
  if (!Array.isArray(params.questions) || params.questions.length === 0) {
    return {
      ok: false,
      error: "no_questions",
      message: "Error: At least one question is required",
    };
  }
  if (params.questions.length > MAX_QUESTIONS) {
    return {
      ok: false,
      error: "too_many_questions",
      message: `Error: At most ${MAX_QUESTIONS} questions are allowed per invocation`,
    };
  }

  const seenQuestions = new Set<string>();
  for (const question of params.questions) {
    if (seenQuestions.has(question.question)) {
      return {
        ok: false,
        error: "duplicate_question",
        message: "Error: Question text must be unique within an invocation",
      };
    }
    seenQuestions.add(question.question);

    if (
      !Array.isArray(question.options) ||
      question.options.length < MIN_OPTIONS
    ) {
      return {
        ok: false,
        error: "empty_options",
        message: `Error: Each question requires at least ${MIN_OPTIONS} options`,
      };
    }
    if (question.options.length > MAX_OPTIONS) {
      return {
        ok: false,
        error: "too_many_options",
        message: `Error: Each question allows at most ${MAX_OPTIONS} options`,
      };
    }

    const seenLabels = new Set<string>();
    for (const option of question.options) {
      if (RESERVED_LABELS.has(option.label)) {
        return {
          ok: false,
          error: "reserved_label",
          message: `Error: Option label is reserved (${Array.from(RESERVED_LABELS).join(", ")})`,
        };
      }
      if (seenLabels.has(option.label)) {
        return {
          ok: false,
          error: "duplicate_option_label",
          message: "Error: Option labels must be unique within a question",
        };
      }
      seenLabels.add(option.label);
    }
  }

  return { ok: true };
}

function buildToolResult(text: string, details: QuestionnaireResult) {
  return {
    content: [{ type: "text" as const, text }],
    details,
  };
}

function formatAnswer(answer: QuestionAnswer): string {
  switch (answer.kind) {
    case "chat":
      return CHAT_MESSAGE;
    case "multi":
      return answer.selected?.length
        ? answer.selected.join(", ")
        : "(no input)";
    case "custom":
      return answer.answer?.length ? answer.answer : "(no input)";
    case "option":
      return answer.answer ?? "(no input)";
  }
}

function buildResponse(
  result: QuestionnaireResult | null | undefined,
  params: QuestionParams,
) {
  if (!result || result.cancelled) {
    return buildToolResult(DECLINE_MESSAGE, {
      answers: result?.answers ?? [],
      cancelled: true,
    });
  }

  const segments: string[] = [];
  for (let i = 0; i < params.questions.length; i++) {
    const answer = result.answers.find(
      (candidate) => candidate.questionIndex === i,
    );
    if (!answer) continue;

    const parts = [`"${answer.question}"="${formatAnswer(answer)}"`];
    if (answer.preview) parts.push(`selected preview: ${answer.preview}`);
    if (answer.notes) parts.push(`user notes: ${answer.notes}`);
    segments.push(`${parts.join(". ")}.`);
  }

  if (segments.length === 0) {
    return buildToolResult(DECLINE_MESSAGE, {
      answers: result.answers,
      cancelled: true,
    });
  }

  return buildToolResult(
    `User has answered your questions: ${segments.join(" ")} You can now continue with the user's answers in mind.`,
    result,
  );
}

type ThemeLike = {
  fg: (color: any, text: string) => string;
  bold?: (text: string) => string;
};

type CustomUIContext = {
  ui: {
    custom: <T>(
      factory: (
        tui: { requestRender: () => void },
        theme: ThemeLike,
        keybindings: unknown,
        done: (value: T) => void,
      ) => {
        render: (width: number) => string[];
        handleInput: (data: string) => void;
        invalidate: () => void;
      },
    ) => Promise<T>;
  };
};

function optionLabel(option: QuestionOption): string {
  const previewFlag = option.preview ? " [preview]" : "";
  return `${option.label}${previewFlag}`;
}

function titleFor(
  question: QuestionData,
  index: number,
  total: number,
  theme: ThemeLike,
): string {
  const count = total > 1 ? theme.fg("dim", ` ${index + 1}/${total}`) : "";
  return `${chip(question.header)}${count}`;
}

function chip(text: string): string {
  return `\x1b[48;2;65;68;89m\x1b[38;2;202;211;245m ${text} \x1b[0m`;
}

function questionLine(question: QuestionData, theme: ThemeLike): string {
  const text = theme.bold ? theme.bold(question.question) : question.question;
  return theme.fg("text", text);
}

function addWrapped(lines: string[], text: string, width: number, indent = "") {
  const wrapped = wrapTextWithAnsi(text, Math.max(1, width - indent.length));
  for (const line of wrapped) {
    lines.push(truncateToWidth(`${indent}${line}`, width));
  }
}

function addPaddedWrapped(
  lines: string[],
  text: string,
  width: number,
  indent = "",
) {
  addWrapped(lines, text, width, ` ${indent}`);
}

function isPrintable(data: string): boolean {
  return data.length === 1 && data >= " " && data !== "\x7f";
}

function customTextLabel(value: string, theme: ThemeLike): string {
  if (value.length === 0) {
    return `${CUSTOM_LABEL} ${theme.fg("dim", "Type here...")}`;
  }
  return `${CUSTOM_LABEL} ${theme.fg("accent", value)}`;
}

async function askSingle(
  ctx: CustomUIContext,
  question: QuestionData,
  index: number,
  total: number,
): Promise<QuestionAnswer | null> {
  return await ctx.ui.custom<QuestionAnswer | null>(
    (
      tui: { requestRender: () => void },
      theme: ThemeLike,
      _kb: unknown,
      done: (value: QuestionAnswer | null) => void,
    ) => {
      let focused = 0;
      let customText = "";
      let cachedLines: string[] | undefined;
      const customRow = question.options.length;
      const submitRow = question.options.length + 1;
      const chatRow = question.options.length + 2;
      const totalRows = question.options.length + 3;

      function refresh() {
        cachedLines = undefined;
        tui.requestRender();
      }

      function submit() {
        if (focused === chatRow) {
          done({
            questionIndex: index,
            question: question.question,
            kind: "chat",
            answer: CHAT_LABEL,
          });
          return;
        }

        const option = question.options[focused];
        if (option) {
          done({
            questionIndex: index,
            question: question.question,
            kind: "option",
            answer: option.label,
            preview: option.preview,
          });
          return;
        }

        const trimmed = customText.trim();
        if (trimmed) {
          done({
            questionIndex: index,
            question: question.question,
            kind: "custom",
            answer: trimmed,
          });
        }
      }

      function styledRow(
        isFocused: boolean,
        indexLabel: string,
        label: string,
      ): string {
        const prefix = isFocused ? theme.fg("accent", "❯ ") : "  ";
        const number = indexLabel
          ? theme.fg(isFocused ? "accent" : "text", `${indexLabel}. `)
          : "";
        const text = theme.fg(isFocused ? "accent" : "text", label);
        return `${prefix}${number}${text}`;
      }

      function renderOption(
        lines: string[],
        width: number,
        row: number,
        label: string,
        description?: string,
      ) {
        addWrapped(
          lines,
          styledRow(row === focused, String(row + 1), label),
          width,
        );
        if (description) {
          const descriptionIndent = " ".repeat(2 + `${row + 1}. `.length);
          addWrapped(
            lines,
            theme.fg("dim", description),
            width,
            descriptionIndent,
          );
        }
      }

      function render(width: number): string[] {
        if (cachedLines) return cachedLines;

        const lines: string[] = [];
        const add = (line: string) => lines.push(truncateToWidth(line, width));

        add(theme.fg("borderMuted", "─".repeat(width)));
        lines.push("");
        add(` ${titleFor(question, index, total, theme)}`);
        lines.push("");
        add(` ${questionLine(question, theme)}`);
        lines.push("");

        for (let i = 0; i < question.options.length; i++) {
          const option = question.options[i]!;
          renderOption(
            lines,
            width,
            i,
            optionLabel(option),
            option.description,
          );
        }
        renderOption(
          lines,
          width,
          customRow,
          customTextLabel(customText, theme),
        );
        lines.push("");
        addPaddedWrapped(
          lines,
          styledRow(focused === submitRow, "", "Submit"),
          width,
        );
        addPaddedWrapped(
          lines,
          styledRow(focused === chatRow, "", CHAT_LABEL),
          width,
        );
        lines.push("");
        add(theme.fg("borderMuted", "─".repeat(width)));

        cachedLines = lines;
        return lines;
      }

      function handleInput(data: string) {
        if (matchesKey(data, Key.up)) {
          focused = Math.max(0, focused - 1);
          refresh();
          return;
        }
        if (matchesKey(data, Key.down)) {
          focused = Math.min(totalRows - 1, focused + 1);
          refresh();
          return;
        }
        if (matchesKey(data, Key.enter)) {
          if (focused === customRow && !customText.trim()) {
            focused = submitRow;
            refresh();
            return;
          }
          submit();
          return;
        }
        if (matchesKey(data, Key.escape)) {
          done(null);
          return;
        }
        if (focused !== customRow) return;
        if (matchesKey(data, Key.backspace)) {
          customText = customText.slice(0, -1);
          refresh();
          return;
        }
        if (isPrintable(data)) {
          customText += data;
          refresh();
        }
      }

      return {
        render,
        handleInput,
        invalidate: () => {
          cachedLines = undefined;
        },
      };
    },
  );
}

async function askMulti(
  ctx: CustomUIContext,
  question: QuestionData,
  index: number,
  total: number,
): Promise<QuestionAnswer | null> {
  return await ctx.ui.custom<QuestionAnswer | null>(
    (
      tui: { requestRender: () => void },
      theme: ThemeLike,
      _kb: unknown,
      done: (value: QuestionAnswer | null) => void,
    ) => {
      const selected = new Set<string>();
      let customText = "";
      let focused = 0;
      let cachedLines: string[] | undefined;

      function refresh() {
        cachedLines = undefined;
        tui.requestRender();
      }

      function selectedValues(): string[] {
        const values = Array.from(selected);
        const custom = customText.trim();
        if (custom) values.push(custom);
        return values;
      }

      function submit() {
        done({
          questionIndex: index,
          question: question.question,
          kind: "multi",
          answer: null,
          selected: selectedValues(),
        });
      }

      function customRowIndex(): number {
        return question.options.length;
      }

      function submitRowIndex(): number {
        return question.options.length + 1;
      }

      function chatRowIndex(): number {
        return question.options.length + 2;
      }

      function totalRows(): number {
        return question.options.length + 3;
      }

      function toggleFocused() {
        const option = question.options[focused];
        if (!option) return;
        if (selected.has(option.label)) {
          selected.delete(option.label);
        } else {
          selected.add(option.label);
        }
        refresh();
      }

      function styledOptionRow(
        isFocused: boolean,
        isSelected: boolean,
        indexLabel: string,
        label: string,
      ): string {
        const prefix = isFocused ? theme.fg("accent", "❯ ") : "  ";
        const number = theme.fg(
          isFocused ? "accent" : "text",
          `${indexLabel}. `,
        );
        const marker = theme.fg(
          isSelected ? "success" : "dim",
          isSelected ? "[x]" : "[ ]",
        );
        const text = theme.fg(isFocused ? "accent" : "text", label);
        return `${prefix}${number}${marker} ${text}`;
      }

      function styledActionRow(
        isFocused: boolean,
        indexLabel: string,
        label: string,
      ): string {
        const prefix = isFocused ? theme.fg("accent", "❯ ") : "  ";
        const number = indexLabel
          ? theme.fg(isFocused ? "accent" : "text", `${indexLabel}. `)
          : "";
        return `${prefix}${number}${theme.fg(isFocused ? "accent" : "text", label)}`;
      }

      function renderOption(
        lines: string[],
        width: number,
        row: number,
        option: QuestionOption,
      ) {
        addWrapped(
          lines,
          styledOptionRow(
            row === focused,
            selected.has(option.label),
            String(row + 1),
            optionLabel(option),
          ),
          width,
        );
        const descriptionIndent = " ".repeat(
          2 + `${row + 1}. `.length + "[ ] ".length,
        );
        addWrapped(
          lines,
          theme.fg("dim", option.description),
          width,
          descriptionIndent,
        );
      }

      function render(width: number): string[] {
        if (cachedLines) return cachedLines;

        const lines: string[] = [];
        const add = (line: string) => lines.push(truncateToWidth(line, width));

        add(theme.fg("borderMuted", "─".repeat(width)));
        lines.push("");
        add(` ${titleFor(question, index, total, theme)}`);
        lines.push("");
        add(` ${questionLine(question, theme)}`);
        lines.push("");

        for (let i = 0; i < question.options.length; i++) {
          renderOption(lines, width, i, question.options[i]!);
        }

        addWrapped(
          lines,
          styledOptionRow(
            focused === customRowIndex(),
            customText.trim().length > 0,
            String(customRowIndex() + 1),
            customTextLabel(customText, theme),
          ),
          width,
        );
        lines.push("");
        addPaddedWrapped(
          lines,
          styledActionRow(focused === submitRowIndex(), "", "Submit"),
          width,
        );
        addPaddedWrapped(
          lines,
          styledActionRow(focused === chatRowIndex(), "", CHAT_LABEL),
          width,
        );
        lines.push("");
        add(theme.fg("borderMuted", "─".repeat(width)));

        cachedLines = lines;
        return lines;
      }

      function handleInput(data: string) {
        if (focused === customRowIndex()) {
          if (matchesKey(data, Key.backspace)) {
            customText = customText.slice(0, -1);
            refresh();
            return;
          }
          if (isPrintable(data) && !matchesKey(data, Key.enter)) {
            customText += data;
            refresh();
            return;
          }
        }

        if (matchesKey(data, Key.up)) {
          focused = Math.max(0, focused - 1);
          refresh();
          return;
        }
        if (matchesKey(data, Key.down)) {
          focused = Math.min(totalRows() - 1, focused + 1);
          refresh();
          return;
        }
        if (matchesKey(data, Key.enter)) {
          if (focused === chatRowIndex()) {
            done({
              questionIndex: index,
              question: question.question,
              kind: "chat",
              answer: CHAT_LABEL,
            });
            return;
          }
          if (focused === submitRowIndex()) {
            submit();
            return;
          }
          toggleFocused();
          return;
        }
        if (matchesKey(data, Key.escape)) {
          done(null);
          return;
        }
        if (data === " " || data === "Space") {
          toggleFocused();
          return;
        }
        if (data.toLowerCase() === "c") {
          done({
            questionIndex: index,
            question: question.question,
            kind: "chat",
            answer: CHAT_LABEL,
          });
        }
      }

      return {
        render,
        handleInput,
        invalidate: () => {
          cachedLines = undefined;
        },
      };
    },
  );
}

export default function askUserQuestionExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ask_user_question",
    label: "Ask User Question",
    description: `Ask the user one or more structured questions during execution. Use when you need to:
1. Gather user preferences or requirements
2. Clarify ambiguous instructions
3. Get decisions on implementation choices as you work
4. Offer choices to the user about what direction to take

Usage notes:
- Users can type a custom answer directly into the automatically appended "Type something." row, or pick "Chat about this" to continue in free-form conversation.
- Use multiSelect: true to allow multiple answers. Multi-select includes a custom answer row where the user can type an additional selection inline.
- If an option has preview text, that preview text is echoed back to the model when the option is selected.
- Do not author "Other", "Type something.", "Chat about this", or "Next question" as option labels.`,
    promptSnippet: `Ask the user up to ${MAX_QUESTIONS} structured questions (${MIN_OPTIONS}-${MAX_OPTIONS} options each) when requirements are ambiguous`,
    promptGuidelines: [
      `Use ask_user_question whenever the user's request is underspecified and you cannot proceed without concrete decisions — you can ask up to ${MAX_QUESTIONS} questions per invocation.`,
      `Each ask_user_question question MUST have ${MIN_OPTIONS}-${MAX_OPTIONS} options. Every option requires a concise label and a description explaining the trade-off.`,
      `Set multiSelect: true in ask_user_question when multiple answers are valid. Do not stack multiple ask_user_question calls back-to-back — group clarifying questions into one invocation.`,
    ],
    parameters: QuestionParamsSchema,

    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const typed = params as QuestionParams;
      if (!ctx.hasUI) {
        return buildToolResult(
          "Error: UI not available (running in non-interactive mode)",
          {
            answers: [],
            cancelled: true,
            error: "no_ui",
          },
        );
      }

      const validation = validate(typed);
      if (!validation.ok) {
        return buildToolResult(validation.message, {
          answers: [],
          cancelled: true,
          error: validation.error,
        });
      }

      const answers: QuestionAnswer[] = [];
      for (let i = 0; i < typed.questions.length; i++) {
        const question = typed.questions[i]!;
        const answer = question.multiSelect
          ? await askMulti(ctx, question, i, typed.questions.length)
          : await askSingle(ctx, question, i, typed.questions.length);

        if (!answer) {
          return buildResponse({ answers, cancelled: true }, typed);
        }

        answers.push(answer);
        if (answer.kind === "chat") break;
      }

      return buildResponse({ answers, cancelled: false }, typed);
    },
  });
}
