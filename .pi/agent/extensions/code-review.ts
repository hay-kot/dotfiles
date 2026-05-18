/**
 * /code-review — open plannotator's review UI.
 *
 * Defaults to a local diff against the repo's default branch (what plannotator
 * does with `plannotator review` and no args). Pass a PR/MR URL to review that
 * instead.
 *
 * Usage:
 *   /code-review                Review local diff vs default branch.
 *   /code-review <PR_URL>       Review the given PR/MR.
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

function isUrl(s: string): boolean {
	return s.startsWith("http://") || s.startsWith("https://");
}

export default function codeReviewExtension(pi: ExtensionAPI) {
	pi.registerCommand("review-code", {
		description: "Open plannotator review (local diff by default, or a PR/MR URL)",
		handler: async (args: string, ctx: ExtensionCommandContext) => {
			const trimmed = args.trim();
			const plannotatorArgs = ["review"];
			let label = "local diff";

			if (trimmed) {
				if (!isUrl(trimmed)) {
					ctx.ui.notify(`Expected a PR/MR URL, got: ${trimmed}`, "error");
					return;
				}
				plannotatorArgs.push(trimmed);
				label = trimmed;
			}

			ctx.ui.setStatus("code-review", `plannotator review: ${label}`);
			try {
				const result = await pi.exec("plannotator", plannotatorArgs, { signal: ctx.signal });
				if (result.code !== 0 && !result.killed) {
					const err = result.stderr.trim() || result.stdout.trim() || `exit ${result.code}`;
					ctx.ui.notify(`plannotator review failed: ${err}`, "error");
				}
			} catch (err) {
				ctx.ui.notify(`plannotator failed to launch: ${(err as Error).message}`, "error");
			} finally {
				ctx.ui.setStatus("code-review", "");
			}
		},
	});
}
