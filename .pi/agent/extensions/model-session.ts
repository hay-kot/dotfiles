/**
 * /model-session — switch model for this session only.
 *
 * Snapshots the model active at startup, calls pi.setModel() for the
 * requested model, then restores the original on session_shutdown so the
 * config file is left unchanged.
 *
 * Usage:
 *   /model-session                       Open a picker of available models.
 *   /model-session claude-opus-4         Match by model ID fragment.
 *   /model-session anthropic/claude-…    Match by provider/id.
 */

import type { Api, Model } from "@earendil-works/pi-ai";
import type {
	ExtensionAPI,
	ExtensionCommandContext,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";

type AnyModel = Model<Api>;

export default function modelSessionExtension(pi: ExtensionAPI) {
	let originalModel: AnyModel | undefined;
	let sessionModel: AnyModel | undefined;
	let cachedModels: AnyModel[] = [];

	// ── snapshot on start ────────────────────────────────────────────

	pi.on("session_start", async (_event, ctx) => {
		// Cache the model list for completions
		cachedModels = ctx.modelRegistry.getAll().filter((m) => ctx.modelRegistry.hasConfiguredAuth(m));

		// Only snapshot once — on the initial startup, not on resume/fork/reload
		if (!originalModel && ctx.model) {
			originalModel = ctx.model;
		}

		updateStatus(ctx);
	});

	// ── restore on quit ──────────────────────────────────────────────

	pi.on("session_shutdown", async (event, _ctx) => {
		if (event.reason !== "quit") return;
		if (!sessionModel || !originalModel) return;
		// Restore config to what it was before this session
		await pi.setModel(originalModel);
	});

	// ── status indicator ─────────────────────────────────────────────

	function updateStatus(ctx: ExtensionContext) {
		if (sessionModel) {
			ctx.ui.setStatus(
				"model-session",
				`session: ${sessionModel.provider}/${sessionModel.id}`,
			);
		} else {
			ctx.ui.setStatus("model-session", undefined);
		}
	}

	// ── model resolution ─────────────────────────────────────────────

	function resolveModel(spec: string): AnyModel | undefined {
		const lower = spec.toLowerCase();
		// "provider/id" form
		if (spec.includes("/")) {
			const [provider, id] = spec.split("/", 2);
			return cachedModels.find(
				(m) => m.provider.toLowerCase() === provider.toLowerCase() && m.id.toLowerCase().includes(id.toLowerCase()),
			);
		}
		// fragment match against id
		return cachedModels.find((m) => m.id.toLowerCase().includes(lower));
	}

	// ── /model-session command ───────────────────────────────────────

	pi.registerCommand("model-session", {
		description: "Switch model for this session only (restores on exit)",
		getArgumentCompletions: (prefix) => {
			const lower = prefix.toLowerCase();
			const items = cachedModels
				.map((m) => ({
					value: `${m.provider}/${m.id}`,
					label: `${m.provider}/${m.id}`,
				}))
				.filter((i) => i.value.toLowerCase().includes(lower));
			return items.length > 0 ? items : null;
		},
		handler: async (args: string, ctx: ExtensionCommandContext) => {
			const trimmed = args.trim();
			let target: AnyModel | undefined;

			if (!trimmed) {
				// Picker
				const items = cachedModels.map((m) => `${m.provider}/${m.id}`);
				if (items.length === 0) {
					ctx.ui.notify("No models with configured auth found", "warning");
					return;
				}
				const picked = await ctx.ui.select("Model for this session", items);
				if (!picked) return;
				target = cachedModels.find((m) => `${m.provider}/${m.id}` === picked);
			} else {
				target = resolveModel(trimmed);
				if (!target) {
					ctx.ui.notify(`No model matching: ${trimmed}`, "error");
					return;
				}
			}

			if (!target) return;

			const ok = await pi.setModel(target);
			if (!ok) {
				ctx.ui.notify(`No API key configured for ${target.provider}/${target.id}`, "error");
				return;
			}

			sessionModel = target;
			updateStatus(ctx);
			ctx.ui.notify(
				`Using ${target.provider}/${target.id} for this session`,
				"info",
			);
		},
	});
}
