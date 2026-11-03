/**
 * Custom Footer Extension
 *
 * Replaces the built-in footer with a minimal status bar showing:
 *   LEFT:  git branch and background jobs
 *   RIGHT: ctx · model · thinking effort
 *   BELOW: extension statuses
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;

    ctx.ui.setFooter((tui, _theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());
      let shellFocused = false;
      const unsubscribeShellFocus = pi.events.on(
        "dotfiles:shell-footer",
        (data) => {
          shellFocused = (data as { focused?: boolean })?.focused === true;
          tui.requestRender();
        },
      );
      pi.events.emit("dotfiles:shell-query", {});

      return {
        dispose() {
          unsub();
          unsubscribeShellFocus();
        },
        invalidate() {},
        render(width: number): string[] {
          const theme = ctx.ui.theme;

          // Left: spinner + context usage
          const usage = ctx.getContextUsage();
          const contextWindow =
            usage?.contextWindow ?? ctx.model?.contextWindow;
          const fmt = (n: number) =>
            n >= 1000000
              ? `${(n / 1000000).toFixed(0)}m`
              : n >= 1000
                ? `${(n / 1000).toFixed(0)}k`
                : `${n}`;
          let ctxStr: string;
          if (contextWindow && usage && usage.percent !== null) {
            const pct = Math.round(usage.percent);
            const ctxColor =
              pct >= 75 ? "error" : pct >= 65 ? "warning" : "muted";
            const used = fmt(
              usage.tokens ?? Math.round((contextWindow * usage.percent) / 100),
            );
            const total = fmt(contextWindow);
            ctxStr =
              theme.fg("dim", `${used}/${total} `) +
              theme.fg(ctxColor, `${pct}%`);
          } else {
            ctxStr = theme.fg("dim", "ctx ?");
          }

          const sep = theme.fg("dim", " · ");

          // Left: branch
          const branch = footerData.getGitBranch();
          const extensionStatuses = footerData.getExtensionStatuses();
          const shellStatus = extensionStatuses.get("shells");
          const innerWidth = Math.max(1, width - 2);
          let shellLabel = shellStatus
            ? theme.fg("accent", shellStatus.replace(/[\r\n\t]/g, " "))
            : "";
          if (shellFocused && shellLabel)
            shellLabel = theme.bg("selectedBg", theme.bold(shellLabel));
          const branchLabel = branch
            ? theme.fg("muted", " " + branch)
            : theme.fg("dim", "no branch");
          const branchWidth = shellLabel
            ? Math.max(
                0,
                innerWidth - visibleWidth(shellLabel) - visibleWidth(sep),
              )
            : innerWidth;
          const left = shellLabel
            ? (branchWidth > 0
                ? truncateToWidth(branchLabel, branchWidth) + sep
                : "") + shellLabel
            : branchLabel;

          // Right: ctx · model · effort
          const modelId = ctx.model?.id ?? "no model";
          const effort = pi.getThinkingLevel();
          const right =
            ctxStr +
            sep +
            theme.fg("muted", modelId) +
            sep +
            theme.fg("muted", effort);

          // Layout: 1 char padding on each side
          const fittedLeft = truncateToWidth(left, innerWidth, "");
          const fittedRight = truncateToWidth(
            right,
            Math.max(0, innerWidth - visibleWidth(fittedLeft) - 2),
            "",
          );
          const gap = Math.max(
            0,
            innerWidth - visibleWidth(fittedLeft) - visibleWidth(fittedRight),
          );
          const lines = [
            truncateToWidth(
              " " + fittedLeft + " ".repeat(gap) + fittedRight + " ",
              width,
            ),
          ];
          // Hive already renders its task and inbox as editor widgets.
          const statuses = [...extensionStatuses]
            .filter(
              ([key]) =>
                !["shells", "hive-active-task", "hive-inbox"].includes(key),
            )
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([, text]) => text.replace(/[\r\n\t]/g, " "));
          for (const status of statuses) {
            lines.push(truncateToWidth(" " + status, width));
          }
          return lines;
        },
      };
    });
  });
}
