/**
 * /handoff-auto — generate a focused handoff and continue in a fresh session.
 *
 * Usage:
 *   /handoff-auto implement phase one of the plan
 *   /handoff-auto pivot to work on x with the goal of y
 *
 * The command summarizes the current branch, creates a new session, and
 * auto-submits the generated handoff prompt in that fresh session.
 */

import type { AgentMessage } from "@earendil-works/pi-agent-core";
import { complete, type Message } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  SessionEntry,
} from "@earendil-works/pi-coding-agent";
import {
  BorderedLoader,
  convertToLlm,
  serializeConversation,
} from "@earendil-works/pi-coding-agent";

const SYSTEM_PROMPT = `You are a coding-session handoff assistant. Given a Pi coding-agent conversation and the user's goal for the next fresh session, write a self-contained handoff prompt that the next session can execute from scratch.

Requirements:
- Preserve only information relevant to the user's next goal.
- Include current objective, repository/workspace context, important decisions, constraints, and known preferences.
- Include files read, edited, or likely relevant when they appear in the conversation.
- Include current implementation state, validation status, blockers, and open questions.
- State the next task clearly as an actionable prompt for the new coding agent session.
- Do not ask the new session to rely on hidden prior conversation context.
- Do not include preamble like "Here is the handoff". Output only the handoff prompt.

Use this structure:
## Handoff Context
[Concise context the new session needs]

## Relevant Files
- path: why it matters

## Current State
[What has happened so far and what is known]

## Next Task
[Concrete instruction for the new session]

## Verification
[Known checks already run and checks the new session should run]`;

function entryToMessage(entry: SessionEntry): AgentMessage | undefined {
  if (entry.type === "message") {
    return entry.message;
  }

  if (entry.type === "compaction") {
    return {
      role: "compactionSummary",
      summary: entry.summary,
      tokensBefore: entry.tokensBefore,
      timestamp: new Date(entry.timestamp).getTime(),
    };
  }

  if (entry.type === "branch_summary") {
    return {
      role: "branchSummary",
      summary: entry.summary,
      fromId: entry.fromId,
      timestamp: new Date(entry.timestamp).getTime(),
    };
  }

  return undefined;
}

function getHandoffMessages(branch: SessionEntry[]): AgentMessage[] {
  const latestCompactionIndex = findLatestCompactionIndex(branch);
  if (latestCompactionIndex < 0) {
    return branch
      .map(entryToMessage)
      .filter((message) => message !== undefined);
  }

  const compaction = branch[latestCompactionIndex];
  if (compaction.type !== "compaction") {
    return branch
      .map(entryToMessage)
      .filter((message) => message !== undefined);
  }

  const firstKeptIndex = branch.findIndex(
    (entry) => entry.id === compaction.firstKeptEntryId,
  );
  const compactedBranch = [
    compaction,
    ...(firstKeptIndex >= 0
      ? branch.slice(firstKeptIndex, latestCompactionIndex)
      : []),
    ...branch.slice(latestCompactionIndex + 1),
  ];

  return compactedBranch
    .map(entryToMessage)
    .filter((message) => message !== undefined);
}

function findLatestCompactionIndex(branch: SessionEntry[]): number {
  for (let i = branch.length - 1; i >= 0; i--) {
    if (branch[i].type === "compaction") {
      return i;
    }
  }
  return -1;
}

function buildPrompt(conversationText: string, goal: string): string {
  return [
    "## Conversation History",
    conversationText,
    "",
    "## User's Goal for Fresh Session",
    goal,
  ].join("\n");
}

async function generateHandoff(
  ctx: ExtensionCommandContext,
  goal: string,
  signal?: AbortSignal,
): Promise<string | null> {
  if (!ctx.model) {
    ctx.ui.notify("No model selected", "error");
    return null;
  }

  const messages = getHandoffMessages(ctx.sessionManager.getBranch());
  if (messages.length === 0) {
    ctx.ui.notify("No conversation to hand off", "error");
    return null;
  }

  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
  if (!auth.ok || !auth.apiKey) {
    ctx.ui.notify(
      auth.ok ? `No API key for ${ctx.model.provider}` : auth.error,
      "error",
    );
    return null;
  }

  const llmMessages = convertToLlm(messages);
  const conversationText = serializeConversation(llmMessages);
  const userMessage: Message = {
    role: "user",
    content: [{ type: "text", text: buildPrompt(conversationText, goal) }],
    timestamp: Date.now(),
  };

  const response = await complete(
    ctx.model,
    { systemPrompt: SYSTEM_PROMPT, messages: [userMessage] },
    { apiKey: auth.apiKey, headers: auth.headers, signal },
  );

  if (response.stopReason === "aborted") {
    return null;
  }

  return response.content
    .filter(
      (content): content is { type: "text"; text: string } =>
        content.type === "text",
    )
    .map((content) => content.text)
    .join("\n")
    .trim();
}

export default function handoffExtension(pi: ExtensionAPI) {
  pi.registerCommand("handoff-auto", {
    description: "Generate a handoff and auto-submit it in a fresh session",
    handler: async (args, ctx) => {
      const goal = args.trim();
      if (!goal) {
        ctx.ui.notify(
          "Usage: /handoff-auto <goal for the fresh session>",
          "error",
        );
        return;
      }

      await ctx.waitForIdle();

      const currentSessionFile = ctx.sessionManager.getSessionFile();
      const handoff = ctx.hasUI
        ? await ctx.ui.custom<string | null>((tui, theme, _kb, done) => {
            const loader = new BorderedLoader(
              tui,
              theme,
              "Generating handoff...",
            );
            loader.onAbort = () => done(null);

            generateHandoff(ctx, goal, loader.signal)
              .then(done)
              .catch((error) => {
                console.error("Handoff generation failed:", error);
                done(null);
              });

            return loader;
          })
        : await generateHandoff(ctx, goal);

      if (!handoff) {
        ctx.ui.notify("Handoff cancelled or empty", "info");
        return;
      }

      const result = await ctx.newSession({
        parentSession: currentSessionFile,
        withSession: async (replacementCtx) => {
          replacementCtx.ui.notify(
            "Starting fresh session from handoff",
            "info",
          );
          await replacementCtx.sendUserMessage(handoff);
        },
      });

      if (result.cancelled) {
        ctx.ui.notify("New session cancelled", "info");
      }
    },
  });
}
