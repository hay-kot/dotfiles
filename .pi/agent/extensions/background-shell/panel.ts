import { stripVTControlCharacters } from "node:util";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  truncateToWidth,
  visibleWidth,
  wrapTextWithAnsi,
} from "@earendil-works/pi-tui";
import type { ShellJob } from "./jobs.ts";

type PanelJob = Pick<
  ShellJob,
  "id" | "command" | "status" | "startedAt" | "endedAt"
>;
type PanelTheme = Pick<ExtensionContext["ui"]["theme"], "fg" | "bg" | "bold">;

function clean(text: string): string {
  return stripVTControlCharacters(text)
    .replace(/\t/g, "  ")
    .replace(/[\x00-\x08\x0b-\x1f\x7f]/g, "");
}

function age(job: PanelJob): string {
  const seconds = Math.max(
    0,
    Math.floor(((job.endedAt ?? Date.now()) - job.startedAt) / 1000),
  );
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
  return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`;
}

export function renderShellPanel(
  width: number,
  jobs: PanelJob[],
  selected: number,
  output: string,
  theme: PanelTheme,
): string[] {
  width = Math.max(1, width);
  const panelWidth = width;
  const job = jobs[selected];
  if (panelWidth < 12) {
    return [
      "Shells",
      job?.id ?? "No shells",
      job?.status ?? "",
      "Esc close",
    ].map((line) => truncateToWidth(line, width));
  }
  const inside = panelWidth - 4;
  const sideBySide = panelWidth >= 76;
  const listWidth = sideBySide ? 29 : inside;
  const outputWidth = sideBySide ? inside - listWidth - 3 : inside;
  const fit = (text: string, size: number) => {
    const fitted = truncateToWidth(text, size);
    return fitted + " ".repeat(Math.max(0, size - visibleWidth(fitted)));
  };
  const border = (left: string, right: string) =>
    theme.fg("borderMuted", left + "─".repeat(panelWidth - 2) + right);
  const row = (text: string) =>
    theme.fg("borderMuted", "│ ") +
    fit(text, inside) +
    theme.fg("borderMuted", " │");
  const cell = (text: string, size: number) => fit(text, size);
  const list: string[] = [
    theme.fg(
      "dim",
      listWidth >= 27
        ? `  ${cell("Shell", 9)} ${cell("State", 9)} ${cell("Age", 7)}`
        : "Shell / state",
    ),
  ];
  const visibleJobs = sideBySide ? 6 : 4;
  const start = Math.max(0, selected - visibleJobs + 1);
  for (let i = start; i < Math.min(jobs.length, start + visibleJobs); i++) {
    const item = jobs[i]!;
    const color =
      item.status === "failed"
        ? "error"
        : item.status === "timed_out"
          ? "warning"
          : item.status === "completed"
            ? "success"
            : item.status === "running"
              ? "accent"
              : "dim";
    const label =
      listWidth >= 27
        ? `${i === selected ? "> " : "  "}${cell(item.id, 9)} ${cell(theme.fg(color, item.status), 9)} ${age(item)}`
        : `${i === selected ? "> " : "  "}${item.id} ${item.status} ${age(item)}`;
    list.push(
      i === selected
        ? theme.bg("selectedBg", fit(theme.bold(label), listWidth))
        : fit(label, listWidth),
    );
  }
  if (!jobs.length) list.push(theme.fg("dim", "No background shells"));

  const outputRows = sideBySide ? 8 : 5;
  const preview = wrapTextWithAnsi(
    clean(output).replace(/\n+$/, "") ||
      (job ? "Waiting for output..." : "Select a shell to preview output"),
    outputWidth,
  ).slice(-outputRows);
  const detail = [
    theme.bold("Output") + (job ? theme.fg("accent", `  ${job.id}`) : ""),
    theme.fg(
      "dim",
      job ? `Command: ${clean(job.command).replace(/\s+/g, " ")}` : "",
    ),
    theme.fg("borderMuted", "─".repeat(outputWidth)),
    ...preview,
    ...Array<string>(Math.max(0, outputRows - preview.length)).fill(""),
  ];
  const lines = [
    border("╭", "╮"),
    row(theme.bold("Shells") + theme.fg("dim", `  ${jobs.length}`)),
    border("├", "┤"),
  ];
  if (sideBySide) {
    for (let i = 0; i < Math.max(list.length, detail.length); i++) {
      lines.push(
        row(
          fit(list[i] ?? "", listWidth) +
            theme.fg("borderMuted", " │ ") +
            fit(detail[i] ?? "", outputWidth),
        ),
      );
    }
  } else {
    lines.push(...list.map(row), border("├", "┤"), ...detail.map(row));
  }
  lines.push(
    border("├", "┤"),
    row(theme.fg("dim", "↑↓ switch  k kill  Esc close")),
    border("╰", "╯"),
  );
  return lines;
}
