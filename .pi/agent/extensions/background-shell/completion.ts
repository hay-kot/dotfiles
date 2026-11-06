import { stripVTControlCharacters } from "node:util";
import { keyHint, type MessageRenderer } from "@earendil-works/pi-coding-agent";
import { MouseRegion, Text, truncateToWidth } from "@earendil-works/pi-tui";

interface CompletionDetails {
  status?: string;
  summary?: string;
}

export function createCompletionRenderer(): MessageRenderer<CompletionDetails> {
  // Pi rebuilds message components on invalidation, including after mouse input.
  const states = new WeakMap<object, { expanded: boolean; global: boolean }>();
  return (message, options, theme) => {
    let state = states.get(message);
    if (!state) {
      state = { expanded: options.expanded, global: options.expanded };
      states.set(message, state);
    } else if (state.global !== options.expanded) {
      state.expanded = options.expanded;
      state.global = options.expanded;
    }
    const expansion = state;
    const content = stripVTControlCharacters(
      typeof message.content === "string"
        ? message.content
        : message.content
            .filter((block) => block.type === "text")
            .map((block) => block.text)
            .join("\n"),
    )
      .replace(/\r\n?/g, "\n")
      .replace(/\t/g, "  ")
      .replace(/[\x00-\x08\x0b-\x1f\x7f]/g, "");
    const summary = stripVTControlCharacters(
      message.details?.summary ??
        content.split("\n")[1] ??
        "Background shell finished",
    ).replace(/[\s\x00-\x1f\x7f]+/g, " ");
    const status = message.details?.status;
    const color =
      status === "failed" || status === "timed_out"
        ? "error"
        : status === "killed"
          ? "warning"
          : "success";

    return new MouseRegion(
      {
        render(width) {
          const action = expansion.expanded ? "collapse" : "expand";
          const lines = [
            truncateToWidth(
              theme.fg(color, `${expansion.expanded ? "v" : ">"} ${summary}`),
              width,
            ),
            truncateToWidth(
              theme.fg(
                "dim",
                `Click to ${action} | ${keyHint("app.tools.expand", action)}`,
              ),
              width,
            ),
          ];
          if (expansion.expanded)
            lines.push(
              ...new Text(theme.fg("toolOutput", content), 0, 0).render(width),
            );
          return lines;
        },
        invalidate() {},
      },
      (event) => {
        if (event.type !== "click" || event.button !== "left" || event.y > 1)
          return undefined;
        expansion.expanded = !expansion.expanded;
        return { handled: true, render: true };
      },
    );
  };
}
