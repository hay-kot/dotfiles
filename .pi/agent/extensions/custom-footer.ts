/**
 * Custom Footer Extension
 *
 * Replaces the built-in footer with a minimal status bar showing:
 *   LEFT:  git branch
 *   RIGHT: ctx · model · thinking effort
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;

		ctx.ui.setFooter((tui, _theme, footerData) => {
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose() {
					unsub();
				},
				invalidate() {},
				render(width: number): string[] {
					const theme = ctx.ui.theme;

					// Left: spinner + context usage
					const usage = ctx.getContextUsage();
					const contextWindow = usage?.contextWindow ?? ctx.model?.contextWindow;
					const fmt = (n: number) => n >= 1000000 ? `${(n / 1000000).toFixed(0)}m` : n >= 1000 ? `${(n / 1000).toFixed(0)}k` : `${n}`;
					let ctxStr: string;
					if (contextWindow && usage && usage.percent !== null) {
						const pct = Math.round(usage.percent);
						const ctxColor = pct >= 75 ? "error" : pct >= 65 ? "warning" : "muted";
						const used = fmt(usage.tokens ?? Math.round(contextWindow * usage.percent / 100));
						const total = fmt(contextWindow);
						ctxStr = theme.fg("dim", `${used}/${total} `) + theme.fg(ctxColor, `${pct}%`);
					} else {
						ctxStr = theme.fg("dim", "ctx ?");
					}

					const sep = theme.fg("dim", " · ");

					// Left: branch
					const branch = footerData.getGitBranch();
					const left = branch ? theme.fg("accent", " " + branch) : theme.fg("dim", "no branch");

					// Right: ctx · model · effort
					const modelId = ctx.model?.id ?? "no model";
					const effort = pi.getThinkingLevel();
					const right = ctxStr + sep + theme.fg("muted", modelId) + sep + theme.fg("muted", effort);

					// Layout: 1 char padding on each side
					const innerWidth = width - 2;
					const gap = Math.max(1, innerWidth - visibleWidth(left) - visibleWidth(right));
					return [" " + truncateToWidth(left + " ".repeat(gap) + right, innerWidth) + " "];
				},
			};
		});
	});
}
