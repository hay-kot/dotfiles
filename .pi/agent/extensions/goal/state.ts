import { randomUUID } from "node:crypto";

export type GoalStatus = "active" | "paused" | "met" | "impossible" | "cleared";
export interface GoalState {
  id: string;
  condition: string;
  evaluatorModel?: string;
  status: GoalStatus;
  startedAt: number;
  turns: number;
  outputTokens: number;
  maxTurns: number;
  maxTokens: number;
  stalled: number;
  reason: string;
}
export interface Verdict {
  verdict: "met" | "not_met" | "impossible";
  reason: string;
}

export function newGoal(input: string): GoalState {
  let rest = input.trim();
  let maxTurns = 20;
  let maxTokens = 100_000;
  while (rest.startsWith("--")) {
    const match = rest.match(/^--(max-turns|max-tokens)\s+(\d+)\s+([\s\S]+)$/);
    if (!match)
      throw new Error(
        "Usage: /goal [--max-turns N] [--max-tokens N] <condition>",
      );
    const value = Number(match[2]);
    if (!Number.isSafeInteger(value) || value < 1)
      throw new Error("Goal limits must be positive integers");
    if (match[1] === "max-turns") maxTurns = value;
    else maxTokens = value;
    rest = match[3]!.trim();
  }
  if (!rest || rest.length > 4000)
    throw new Error("Goal condition must contain 1-4000 characters");
  return {
    id: randomUUID(),
    condition: rest,
    status: "active",
    startedAt: Date.now(),
    turns: 0,
    outputTokens: 0,
    maxTurns,
    maxTokens,
    stalled: 0,
    reason: "Goal started",
  };
}

export function parseVerdict(text: string): Verdict {
  const value = JSON.parse(
    text.trim().replace(/^```(?:json)?\s*|\s*```$/g, ""),
  );
  if (
    !value ||
    !["met", "not_met", "impossible"].includes(value.verdict) ||
    typeof value.reason !== "string" ||
    !value.reason.trim()
  ) {
    throw new Error("Goal evaluator returned an invalid verdict");
  }
  return { verdict: value.verdict, reason: value.reason.slice(0, 2000) };
}

export function restoreGoal(data: unknown): GoalState | undefined {
  if (!data || typeof data !== "object") return;
  const value = data as GoalState;
  if (
    typeof value.id !== "string" ||
    typeof value.condition !== "string" ||
    !["active", "paused", "met", "impossible", "cleared"].includes(
      value.status,
    ) ||
    typeof value.reason !== "string" ||
    (value.evaluatorModel !== undefined &&
      typeof value.evaluatorModel !== "string") ||
    ![
      value.startedAt,
      value.turns,
      value.outputTokens,
      value.maxTurns,
      value.maxTokens,
      value.stalled,
    ].every(Number.isFinite)
  )
    return;
  return { ...value };
}

export function goalLimit(goal: GoalState): string | undefined {
  if (goal.turns >= goal.maxTurns)
    return `Reached ${goal.maxTurns} evaluated turns`;
  if (goal.outputTokens >= goal.maxTokens)
    return `Reached ${goal.maxTokens} output tokens`;
}
