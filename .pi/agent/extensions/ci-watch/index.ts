/**
 * CI Watch — monitor a PR's CI and review comments without wasting LLM calls.
 *
 * Runs pr-status.sh on a timer, handles deterministic states (wait, none, closed)
 * in the extension, and only invokes the LLM when action is needed (ci fix or
 * review comments).
 *
 * Command:
 *   /ci-watch [PR_NUMBER]   — start watching (default: current branch PR)
 *   /ci-watch stop           — stop watching
 *   /ci-watch status         — show current state
 *
 * Icons (Nerd Font Octicons):
 *    oct-check  — green / passing
 *    oct-sync   — syncing / pending
 *    oct-alert  — action needed / error
 */

import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const SCRIPT_PATH = join(homedir(), ".claude/skills/ci-watch/scripts/pr-status.sh");
const DEFAULT_INTERVAL_MS = 5 * 60 * 1000; // 5m
const MAX_CONSECUTIVE_FAILURES = 3;

// ── Types ────────────────────────────────────────────────────────────────

interface PRStatus {
	forge: string;
	pr_number: number;
	pr_title: string;
	pr_state: "open" | "closed" | "merged" | "no_pr";
	ci_status: "pass" | "fail" | "pending" | "unknown";
	failing_checks: Array<{ name: string; url: string }>;
	review_comments: Array<{ file: string; line: number; body: string; author: string }>;
	action_needed: "none" | "wait" | "ci" | "comments";
}

interface WatchState {
	prNumber: string | undefined;
	timer: ReturnType<typeof setInterval> | undefined;
	paused: boolean;
	consecutiveFailures: number;
	lastStatus: PRStatus | undefined;
	lastCheckTime: Date | undefined;
}

// ── Prompt builders ──────────────────────────────────────────────────────

function buildCiFixPrompt(status: PRStatus): string {
	const checks = status.failing_checks
		.map((c) => `- ${c.name}: ${c.url}`)
		.join("\n");

	return [
		`Fix the failing CI checks for PR #${status.pr_number}: "${status.pr_title}"`,
		"",
		"Failing checks:",
		checks,
		"",
		"Inspect the failure output at the URLs above. Identify the root cause and fix it in the source code.",
		"",
		"After fixing, stage and commit with a clear message describing what was fixed.",
		"Then push the changes to the remote.",
	].join("\n");
}

function buildCommentsPrompt(status: PRStatus): string {
	const comments = status.review_comments
		.map((c) => {
			const loc = c.file ? `${c.author} on ${c.file}:${c.line}` : `${c.author} (top-level review)`;
			return `- ${loc}\n     ${c.body}`;
		})
		.join("\n");

	return [
		`Address the review comments on PR #${status.pr_number}: "${status.pr_title}"`,
		"",
		"Review comments:",
		comments,
		"",
		"For each comment:",
		"1. Navigate to the file and line",
		"2. Understand what the reviewer is asking",
		"3. Make the change if it is correct and reasonable",
		"4. If a comment is unclear or you disagree, note it in your report but skip it",
		"",
		"After addressing comments, stage and commit with a clear message.",
		"Then push the changes to the remote.",
	].join("\n");
}

// ── Extension ────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	const state: WatchState = {
		prNumber: undefined,
		timer: undefined,
		paused: false,
		consecutiveFailures: 0,
		lastStatus: undefined,
		lastCheckTime: undefined,
	};

	let nextCheckAt = 0;

	// Persistent ctx from session_start for UI calls from timer/event callbacks.
	let sessionCtx: ExtensionContext | undefined;

	pi.on("session_start", async (_event, ctx) => {
		sessionCtx = ctx;
	});

	// ── UI helpers ───────────────────────────────────────────────────────

	function setFooterStatus(icon: string, color: string, prNum: number | string, status: string, dimSuffix?: string) {
		if (!sessionCtx?.hasUI) {
			console.error("[ci-watch] setFooterStatus: no sessionCtx or no UI");
			return;
		}
		const theme = sessionCtx.ui.theme;
		let line = theme.fg(color, `${icon}  CI #${prNum}: ${status}`);
		if (dimSuffix) {
			line += theme.fg("dim", `  (${dimSuffix})`);
		}
		// Use widget instead of setStatus — setStatus is invisible when a
		// custom footer (setFooter) replaces the built-in footer.
		sessionCtx.ui.setWidget("ci-watch", [line]);
	}

	function clearFooter() {
		sessionCtx?.ui.setWidget("ci-watch", undefined);
	}

	function notify(message: string, level: "info" | "warning" | "error" = "info") {
		if (sessionCtx?.hasUI) {
			sessionCtx.ui.notify(message, level);
		} else {
			console.error(`[ci-watch] notify (no UI): ${message}`);
		}
	}

	// ── State management ─────────────────────────────────────────────────

	function stopWatching(reason?: string) {
		if (state.timer) {
			clearInterval(state.timer);
			state.timer = undefined;
		}
		state.paused = false;
		state.consecutiveFailures = 0;
		state.lastStatus = undefined;
		state.lastCheckTime = undefined;
		state.prNumber = undefined;
		nextCheckAt = 0;
		clearFooter();

		if (reason) {
			notify(reason);
		}
	}

	function fmtNextCheckTime(): string {
		const d = new Date(nextCheckAt);
		return d.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
	}

	// ── Script execution ─────────────────────────────────────────────────

	async function execScript(): Promise<PRStatus | null> {
		const args = [SCRIPT_PATH];
		if (state.prNumber) args.push(state.prNumber);

		let result: { stdout: string; stderr: string; code: number };
		try {
			result = await pi.exec("bash", args, { timeout: 30_000 });
		} catch (err) {
			console.error("[ci-watch] pi.exec threw:", err);
			return null;
		}

		if (result.code !== 0) {
			console.error(`[ci-watch] script exit ${result.code}: ${result.stderr}`);
			return null;
		}

		try {
			return JSON.parse(result.stdout.trim()) as PRStatus;
		} catch {
			console.error("[ci-watch] invalid JSON:", result.stdout.slice(0, 200));
			return null;
		}
	}

	// ── Core check logic ─────────────────────────────────────────────────
	// Returns true if watching should continue, false if terminal.

	function handleStatus(status: PRStatus): boolean {
		state.lastStatus = status;
		state.lastCheckTime = new Date();
		state.consecutiveFailures = 0;

		// Terminal: no PR
		if (status.pr_state === "no_pr") {
			notify("CI Watch: No open PR found for current branch.");
			return false;
		}

		// Terminal: closed/merged
		if (status.pr_state === "closed" || status.pr_state === "merged") {
			notify(`CI Watch: PR #${status.pr_number} is ${status.pr_state}.`);
			return false;
		}

		switch (status.action_needed) {
			case "none":
				// Terminal: all green
				setFooterStatus("\uf4a0", "success", status.pr_number, "all green");
				notify(`CI Watch: PR #${status.pr_number} "${status.pr_title}" -- CI green, no pending comments. Done.`);
				return false;

			case "wait":
				setFooterStatus("\uf46a", "warning", status.pr_number, status.ci_status);
				return true;

			case "ci":
				setFooterStatus("\uf421", "error", status.pr_number, "fixing CI");
				state.paused = true;
				if (!sessionCtx?.isIdle()) {
					pi.sendUserMessage(buildCiFixPrompt(status), { deliverAs: "followUp" });
				} else {
					pi.sendUserMessage(buildCiFixPrompt(status));
				}
				return true;

			case "comments":
				setFooterStatus("\uf421", "error", status.pr_number, "comments");
				state.paused = true;
				if (!sessionCtx?.isIdle()) {
					pi.sendUserMessage(buildCommentsPrompt(status), { deliverAs: "followUp" });
				} else {
					pi.sendUserMessage(buildCommentsPrompt(status));
				}
				return true;

			default:
				return true;
		}
	}

	function handleScriptFailure() {
		state.consecutiveFailures++;
		state.lastCheckTime = new Date();

		if (state.consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
			setFooterStatus("\uf421", "error", state.lastStatus?.pr_number ?? "?", "stopped", "repeated script failures");
			stopWatching(`CI Watch: Stopped after ${MAX_CONSECUTIVE_FAILURES} consecutive script failures.`);
			return;
		}

		setFooterStatus("\uf421", "warning", state.lastStatus?.pr_number ?? "?", "script error", `${state.consecutiveFailures}/${MAX_CONSECUTIVE_FAILURES}`);
		notify("CI Watch: Script failed, will retry next interval.", "warning");
	}

	// Timer callback — runs every 5m in the background
	function tick() {
		if (state.paused) return;

		execScript().then((status) => {
			if (!status) {
				handleScriptFailure();
				return;
			}

			nextCheckAt = Date.now() + DEFAULT_INTERVAL_MS;
			const shouldContinue = handleStatus(status);

			if (!shouldContinue) {
				stopWatching();
			} else if (status.action_needed === "wait") {
				// Update footer with countdown
					setFooterStatus("\uf46a", "warning", status.pr_number, status.ci_status, `next ${fmtNextCheckTime()}`);
			}
		}).catch((err) => {
			console.error("[ci-watch] tick error:", err);
			handleScriptFailure();
		});
	}

	// Resume polling after agent finishes a fix
	pi.on("agent_end", async () => {
		if (!state.timer || !state.paused) return;

		state.paused = false;
		setFooterStatus("\uf46a", "muted", state.lastStatus?.pr_number ?? "?", "rechecking");

		const status = await execScript();
		if (!status) {
			handleScriptFailure();
			return;
		}

		nextCheckAt = Date.now() + DEFAULT_INTERVAL_MS;
		const shouldContinue = handleStatus(status);
		if (!shouldContinue) {
			stopWatching();
		}
	});

	// ── Command ──────────────────────────────────────────────────────────

	pi.registerCommand("ci-watch", {
		description: "Monitor PR CI and review comments. Usage: /ci-watch [PR_NUMBER | stop | status]",
		handler: async (args, ctx) => {
			const trimmed = args.trim();

			if (trimmed === "stop") {
				if (!state.timer) {
					ctx.ui.notify("CI Watch: Not running.", "info");
					return;
				}
				stopWatching("CI Watch: Stopped.");
				return;
			}

			if (trimmed === "status") {
				if (!state.timer) {
					ctx.ui.notify("CI Watch: Not running.", "info");
					return;
				}
				const s = state.lastStatus;
				const lines = [
					`PR: #${s?.pr_number ?? "?"}${s?.pr_title ? ` "${s.pr_title}"` : ""}`,
					`CI: ${s?.ci_status ?? "unknown"}`,
					`Action: ${s?.action_needed ?? "unknown"}`,
					`Paused: ${state.paused}`,
					`Failures: ${state.consecutiveFailures}`,
					state.lastCheckTime ? `Last check: ${state.lastCheckTime.toLocaleTimeString()}` : "",
				].filter(Boolean);
				ctx.ui.notify(lines.join("\n"), "info");
				return;
			}

			if (trimmed === "help" || trimmed === "?") {
				ctx.ui.notify(
					"Usage:\n  /ci-watch [PR_NUMBER]  -- start watching\n  /ci-watch stop         -- stop watching\n  /ci-watch status       -- show state",
					"info",
				);
				return;
			}

			// ── Start watching ───────────────────────────────────────────

			if (state.timer) {
				stopWatching();
			}

			const prNumber = trimmed || undefined;
			state.prNumber = prNumber;
			state.paused = false;
			state.consecutiveFailures = 0;

			const target = prNumber ? `PR #${prNumber}` : "current branch PR";
			ctx.ui.notify(`CI Watch: Checking ${target}...`, "info");

			// Await initial check so the user sees the result immediately
			const status = await execScript();

			if (!status) {
				ctx.ui.notify("CI Watch: Script failed on initial check. Not starting.", "error");
				state.prNumber = undefined;
				return;
			}

			const shouldContinue = handleStatus(status);

			if (!shouldContinue) {
				// Terminal on first check — footer was set momentarily by handleStatus,
				// then cleared by the notify. No interval needed.
				clearFooter();
				return;
			}

			// Start the polling interval
			state.timer = setInterval(tick, DEFAULT_INTERVAL_MS);
			nextCheckAt = Date.now() + DEFAULT_INTERVAL_MS;

			if (status.action_needed === "wait") {
				setFooterStatus("\uf46a", "warning", status.pr_number, status.ci_status, `next ${fmtNextCheckTime()}`);
			}

			ctx.ui.notify(`CI Watch: Monitoring PR #${status.pr_number} "${status.pr_title}". Checking every 5m.\nStop: /ci-watch stop`, "info");
		},
	});

	// ── Cleanup ──────────────────────────────────────────────────────────

	pi.on("session_shutdown", () => {
		if (state.timer) {
			clearInterval(state.timer);
			state.timer = undefined;
		}
	});
}
