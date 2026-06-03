import {
  BorderedLoader,
  type ExtensionAPI,
  type ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

type Forge = "github" | "gitea";
type TargetKind = "issue" | "pr" | "auto";

type RepoRef = {
  forge: Forge;
  owner: string;
  repo: string;
  host?: string;
};

type Target = RepoRef & {
  kind: TargetKind;
  number: number;
};

type ExecSuccess = {
  stdout: string;
};

type LoadResult =
  | { ok: true; markdown: string }
  | { ok: false; error: Error }
  | { ok: false; cancelled: true };

const COMMAND = {
  name: "context:repo",
  description: "Load GitHub/Gitea issue or PR context into the conversation",
};

const JSON_SPACING = 2;

function usage(): string {
  return [
    "Usage: /context:repo <url | issue # | pr #>",
    "Examples:",
    "  /context:repo https://github.com/owner/repo/issues/123",
    "  /context:repo https://gitea.example.com/owner/repo/pulls/123",
    "  /context:repo issue 123",
    "  /context:repo pr 123",
    "  /context:repo #123",
  ].join("\n");
}

function stripGitSuffix(value: string): string {
  return value.replace(/\.git$/, "");
}

function normalizeRepoName(value: string): string {
  return stripGitSuffix(value).replace(/^\/+|\/+$/g, "");
}

function parseGitHubRemote(remoteUrl: string): RepoRef | null {
  const ssh = remoteUrl.match(/^git@github\.com:([^/]+)\/(.+?)(?:\.git)?$/);
  if (ssh) {
    return { forge: "github", owner: ssh[1], repo: stripGitSuffix(ssh[2]) };
  }

  const https = remoteUrl.match(
    /^https?:\/\/github\.com\/([^/]+)\/(.+?)(?:\.git)?$/,
  );
  if (https) {
    return { forge: "github", owner: https[1], repo: stripGitSuffix(https[2]) };
  }

  return null;
}

function parseHostedRemote(remoteUrl: string): RepoRef | null {
  const ssh = remoteUrl.match(/^git@([^:]+):([^/]+)\/(.+?)(?:\.git)?$/);
  if (ssh) {
    return {
      forge: "gitea",
      host: ssh[1],
      owner: ssh[2],
      repo: stripGitSuffix(ssh[3]),
    };
  }

  const https = remoteUrl.match(
    /^https?:\/\/([^/]+)\/([^/]+)\/(.+?)(?:\.git)?$/,
  );
  if (https && https[1] !== "github.com") {
    return {
      forge: "gitea",
      host: https[1],
      owner: https[2],
      repo: stripGitSuffix(https[3]),
    };
  }

  return null;
}

function parseRemote(remoteUrl: string): RepoRef | null {
  return parseGitHubRemote(remoteUrl) ?? parseHostedRemote(remoteUrl);
}

function parseTargetUrl(raw: string): Target | null {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }

  const parts = url.pathname.split("/").filter(Boolean).map(decodeURIComponent);
  if (parts.length < 4) return null;

  const [owner, repoPart, area, numberText] = parts;
  const number = Number(numberText);
  if (!Number.isInteger(number) || number < 1) return null;

  let kind: TargetKind | null = null;
  if (area === "issues") kind = "issue";
  if (area === "pull" || area === "pulls") kind = "pr";
  if (!kind) return null;

  return {
    forge: url.hostname === "github.com" ? "github" : "gitea",
    host: url.hostname === "github.com" ? undefined : url.hostname,
    owner,
    repo: normalizeRepoName(repoPart),
    kind,
    number,
  };
}

function parseTargetArgs(args: string, repo: RepoRef): Target | null {
  const trimmed = args.trim();
  const fromUrl = parseTargetUrl(trimmed);
  if (fromUrl) return fromUrl;

  const prefixed = trimmed.match(/^(issue|i|pr|pull|pulls)\s+#?(\d+)$/i);
  if (prefixed) {
    return {
      ...repo,
      kind: prefixed[1].toLowerCase().startsWith("i") ? "issue" : "pr",
      number: Number(prefixed[2]),
    };
  }

  const bare = trimmed.match(/^#?(\d+)$/);
  if (bare) {
    return { ...repo, kind: "auto", number: Number(bare[1]) };
  }

  return null;
}

function repoSlug(repo: RepoRef): string {
  return `${repo.owner}/${repo.repo}`;
}

function apiBase(target: Target): string {
  if (!target.host) {
    throw new Error("Gitea host is not known for this target");
  }
  return `https://${target.host}/api/v1/repos/${encodeURIComponent(target.owner)}/${encodeURIComponent(target.repo)}`;
}

async function run(
  pi: ExtensionAPI,
  command: string,
  args: string[],
  cwd: string,
): Promise<ExecSuccess> {
  const result = await pi.exec(command, args, { cwd, timeout: 30_000 });
  if (result.code !== 0) {
    const details =
      result.stderr.trim() || result.stdout.trim() || `exit ${result.code}`;
    throw new Error(`${command} ${args.join(" ")} failed: ${details}`);
  }
  return { stdout: result.stdout };
}

async function readOrigin(pi: ExtensionAPI, cwd: string): Promise<RepoRef> {
  const result = await run(
    pi,
    "git",
    ["config", "--get", "remote.origin.url"],
    cwd,
  );
  const repo = parseRemote(result.stdout.trim());
  if (!repo) {
    throw new Error("remote.origin.url is not a supported GitHub/Gitea remote");
  }
  return repo;
}

function parseJson<T>(stdout: string, label: string): T {
  try {
    return JSON.parse(stdout) as T;
  } catch (error) {
    throw new Error(
      `Could not parse ${label} JSON: ${(error as Error).message}`,
    );
  }
}

function names(items: unknown): string {
  if (!Array.isArray(items) || items.length === 0) return "none";
  return (
    items
      .map((item) => {
        if (item && typeof item === "object") {
          const record = item as Record<string, unknown>;
          return record.name ?? record.login ?? record.username;
        }
        return item;
      })
      .filter((item) => typeof item === "string" && item.length > 0)
      .join(", ") || "none"
  );
}

function authorName(value: unknown): string {
  if (!value || typeof value !== "object") return "unknown";
  const record = value as Record<string, unknown>;
  return String(
    record.login ?? record.username ?? record.full_name ?? "unknown",
  );
}

function bodyText(value: unknown): string {
  return typeof value === "string" && value.trim()
    ? value.trim()
    : "_(no body)_";
}

function formatJsonBlock(label: string, value: unknown): string {
  return [
    `## ${label}`,
    "",
    "```json",
    JSON.stringify(value, null, JSON_SPACING),
    "```",
  ].join("\n");
}

async function fetchGitHubIssue(
  pi: ExtensionAPI,
  target: Target,
  cwd: string,
): Promise<string> {
  const fields =
    "number,title,state,url,author,body,createdAt,updatedAt,labels,assignees,comments,closedByPullRequestsReferences";
  const { stdout } = await run(
    pi,
    "gh",
    [
      "issue",
      "view",
      String(target.number),
      "--repo",
      repoSlug(target),
      "--comments",
      "--json",
      fields,
    ],
    cwd,
  );
  const issue = parseJson<Record<string, unknown>>(stdout, "GitHub issue");
  return [
    `# GitHub Issue Context: ${repoSlug(target)} #${target.number}`,
    "",
    `- URL: ${String(issue.url ?? "")}`,
    `- Title: ${String(issue.title ?? "")}`,
    `- State: ${String(issue.state ?? "")}`,
    `- Author: ${authorName(issue.author)}`,
    `- Labels: ${names(issue.labels)}`,
    `- Assignees: ${names(issue.assignees)}`,
    `- Created: ${String(issue.createdAt ?? "")}`,
    `- Updated: ${String(issue.updatedAt ?? "")}`,
    "",
    "## Body",
    "",
    bodyText(issue.body),
    "",
    formatJsonBlock("Issue Metadata and Comments", issue),
  ].join("\n");
}

async function fetchGitHubPr(
  pi: ExtensionAPI,
  target: Target,
  cwd: string,
): Promise<string> {
  const fields =
    "number,title,state,url,author,body,createdAt,updatedAt,baseRefName,headRefName,additions,deletions,changedFiles,files,labels,assignees,comments,latestReviews,reviewDecision,mergeable,isDraft";
  const { stdout } = await run(
    pi,
    "gh",
    [
      "pr",
      "view",
      String(target.number),
      "--repo",
      repoSlug(target),
      "--comments",
      "--json",
      fields,
    ],
    cwd,
  );
  const pr = parseJson<Record<string, unknown>>(stdout, "GitHub PR");

  let richComments = "";
  try {
    const comments = await run(
      pi,
      "ghcomments",
      ["--repo", repoSlug(target), String(target.number)],
      cwd,
    );
    richComments = comments.stdout.trim();
  } catch {
    richComments = "";
  }

  return [
    `# GitHub PR Context: ${repoSlug(target)} #${target.number}`,
    "",
    `- URL: ${String(pr.url ?? "")}`,
    `- Title: ${String(pr.title ?? "")}`,
    `- State: ${String(pr.state ?? "")}`,
    `- Author: ${authorName(pr.author)}`,
    `- Branches: ${String(pr.headRefName ?? "?")} -> ${String(pr.baseRefName ?? "?")}`,
    `- Draft: ${String(pr.isDraft ?? false)}`,
    `- Review decision: ${String(pr.reviewDecision ?? "")}`,
    `- Mergeable: ${String(pr.mergeable ?? "")}`,
    `- Changes: +${String(pr.additions ?? "?")} -${String(pr.deletions ?? "?")} across ${String(pr.changedFiles ?? "?")} files`,
    `- Labels: ${names(pr.labels)}`,
    `- Assignees: ${names(pr.assignees)}`,
    `- Created: ${String(pr.createdAt ?? "")}`,
    `- Updated: ${String(pr.updatedAt ?? "")}`,
    "",
    "## Body",
    "",
    bodyText(pr.body),
    "",
    richComments
      ? `## Review and Conversation Comments\n\n${richComments}`
      : "",
    "",
    formatJsonBlock("PR Metadata", pr),
  ]
    .filter(Boolean)
    .join("\n");
}

function isPrLikeIssue(issue: Record<string, unknown>): boolean {
  return Boolean(issue.pull_request || issue.pullRequest || issue.pull);
}

async function fetchGiteaJson<T>(
  pi: ExtensionAPI,
  url: string,
  cwd: string,
): Promise<T> {
  const { stdout } = await run(pi, "teaapi", ["curl", "-fsSL", url], cwd);
  return parseJson<T>(stdout, "Gitea API");
}

async function fetchGiteaIssue(
  pi: ExtensionAPI,
  target: Target,
  cwd: string,
): Promise<string> {
  const issue = await fetchGiteaJson<Record<string, unknown>>(
    pi,
    `${apiBase(target)}/issues/${target.number}`,
    cwd,
  );
  const comments = await fetchGiteaJson<unknown[]>(
    pi,
    `${apiBase(target)}/issues/${target.number}/comments`,
    cwd,
  );

  return [
    `# Gitea Issue Context: ${repoSlug(target)} #${target.number}`,
    "",
    `- URL: ${String(issue.html_url ?? issue.url ?? "")}`,
    `- Title: ${String(issue.title ?? "")}`,
    `- State: ${String(issue.state ?? "")}`,
    `- Author: ${authorName(issue.user)}`,
    `- Labels: ${names(issue.labels)}`,
    `- Assignees: ${names(issue.assignees)}`,
    `- Created: ${String(issue.created_at ?? "")}`,
    `- Updated: ${String(issue.updated_at ?? "")}`,
    "",
    "## Body",
    "",
    bodyText(issue.body),
    "",
    formatJsonBlock("Issue Metadata", issue),
    "",
    formatJsonBlock("Issue Comments", comments),
  ].join("\n");
}

async function fetchGiteaPr(
  pi: ExtensionAPI,
  target: Target,
  cwd: string,
): Promise<string> {
  const pr = await fetchGiteaJson<Record<string, unknown>>(
    pi,
    `${apiBase(target)}/pulls/${target.number}`,
    cwd,
  );
  const issue = await fetchGiteaJson<Record<string, unknown>>(
    pi,
    `${apiBase(target)}/issues/${target.number}`,
    cwd,
  );
  const comments = await fetchGiteaJson<unknown[]>(
    pi,
    `${apiBase(target)}/issues/${target.number}/comments`,
    cwd,
  );

  const base =
    pr.base && typeof pr.base === "object"
      ? (pr.base as Record<string, unknown>)
      : {};
  const head =
    pr.head && typeof pr.head === "object"
      ? (pr.head as Record<string, unknown>)
      : {};

  return [
    `# Gitea PR Context: ${repoSlug(target)} #${target.number}`,
    "",
    `- URL: ${String(pr.html_url ?? pr.url ?? issue.html_url ?? "")}`,
    `- Title: ${String(pr.title ?? issue.title ?? "")}`,
    `- State: ${String(pr.state ?? issue.state ?? "")}`,
    `- Author: ${authorName(pr.user ?? issue.user)}`,
    `- Branches: ${String(head.ref ?? "?")} -> ${String(base.ref ?? "?")}`,
    `- Mergeable: ${String(pr.mergeable ?? "")}`,
    `- Merged: ${String(pr.merged ?? false)}`,
    `- Labels: ${names(issue.labels)}`,
    `- Assignees: ${names(issue.assignees)}`,
    `- Created: ${String(pr.created_at ?? issue.created_at ?? "")}`,
    `- Updated: ${String(pr.updated_at ?? issue.updated_at ?? "")}`,
    "",
    "## Body",
    "",
    bodyText(pr.body ?? issue.body),
    "",
    formatJsonBlock("PR Metadata", pr),
    "",
    formatJsonBlock("Issue Metadata", issue),
    "",
    formatJsonBlock("Conversation Comments", comments),
  ].join("\n");
}

async function fetchContext(
  pi: ExtensionAPI,
  target: Target,
  cwd: string,
): Promise<string> {
  if (target.forge === "github") {
    if (target.kind === "pr") return fetchGitHubPr(pi, target, cwd);
    if (target.kind === "issue") return fetchGitHubIssue(pi, target, cwd);

    try {
      return await fetchGitHubPr(pi, { ...target, kind: "pr" }, cwd);
    } catch {
      return fetchGitHubIssue(pi, { ...target, kind: "issue" }, cwd);
    }
  }

  if (target.kind === "pr") return fetchGiteaPr(pi, target, cwd);
  if (target.kind === "issue") return fetchGiteaIssue(pi, target, cwd);

  const issue = await fetchGiteaJson<Record<string, unknown>>(
    pi,
    `${apiBase(target)}/issues/${target.number}`,
    cwd,
  );
  if (isPrLikeIssue(issue))
    return fetchGiteaPr(pi, { ...target, kind: "pr" }, cwd);
  return fetchGiteaIssue(pi, { ...target, kind: "issue" }, cwd);
}

function contextTitle(target: Target): string {
  const kind = target.kind === "auto" ? "issue/PR" : target.kind.toUpperCase();
  return `${target.forge} ${repoSlug(target)} ${kind} #${target.number}`;
}

async function loadContextWithFeedback(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  target: Target,
): Promise<LoadResult> {
  const title = contextTitle(target);

  if (!ctx.hasUI) {
    try {
      return { ok: true, markdown: await fetchContext(pi, target, ctx.cwd) };
    } catch (error) {
      return { ok: false, error: error as Error };
    }
  }

  return await ctx.ui.custom<LoadResult>((tui, theme, _kb, done) => {
    const loader = new BorderedLoader(tui, theme, `Loading ${title}...`);
    loader.onAbort = () => done({ ok: false, cancelled: true });

    fetchContext(pi, target, ctx.cwd)
      .then((markdown) => done({ ok: true, markdown }))
      .catch((error) => done({ ok: false, error: error as Error }));

    return loader;
  });
}

async function handleContextCommand(
  pi: ExtensionAPI,
  args: string,
  ctx: ExtensionCommandContext,
) {
  const trimmed = args.trim();
  if (!trimmed) {
    ctx.ui.notify(usage(), "warning");
    return;
  }

  let target = parseTargetUrl(trimmed);
  if (!target) {
    let currentRepo: RepoRef;
    try {
      currentRepo = await readOrigin(pi, ctx.cwd);
    } catch (error) {
      ctx.ui.notify((error as Error).message, "error");
      return;
    }

    target = parseTargetArgs(trimmed, currentRepo);
    if (!target) {
      ctx.ui.notify(usage(), "warning");
      return;
    }
  }

  ctx.ui.setStatus("repo-context", `loading ${contextTitle(target)}`);
  try {
    const result = await loadContextWithFeedback(pi, ctx, target);
    if (!result.ok) {
      if ("cancelled" in result) {
        ctx.ui.notify(`Cancelled loading ${contextTitle(target)}.`, "info");
        return;
      }

      ctx.ui.notify(
        `Could not load ${contextTitle(target)}: ${result.error.message}`,
        "error",
      );
      return;
    }

    pi.sendMessage({
      customType: "repo-context",
      content: result.markdown,
      display: true,
      details: target,
    });
    ctx.ui.notify(`Loaded ${contextTitle(target)} into context.`, "info");
  } finally {
    ctx.ui.setStatus("repo-context", "");
  }
}

export default function repoContextExtension(pi: ExtensionAPI) {
  pi.registerCommand(COMMAND.name, {
    description: COMMAND.description,
    handler: async (args, ctx) => {
      await handleContextCommand(pi, args, ctx);
    },
  });
}
