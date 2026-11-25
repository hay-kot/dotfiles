# Drive markdown components

Hive Drive markdown documents (`.md`) render three fenced components and `[[wikilinks]]`. This is the format as of hive 0.75.0. The source of truth is the hive repo: `docs/docs/desktop/chats/drive-fences.md` and the validators in `web/packages/ui/src/lib/fenceData.ts`.

## Where they render

| Surface | Fences | Wikilinks |
| --- | --- | --- |
| Hive Desktop Drive tab | Component | Link |
| Drive server share link (`hive drive share`) | Component | Plain text |
| GitHub and Gitea PR, issue, and comment bodies | YAML code block | Plain text |
| Hive TUI, terminal, Obsidian, Plannotator | YAML code block | Plain text |
| Chat messages, `hive hc` task text | YAML code block | Plain text |
| HTML Drive documents (`.html`) | Not parsed | Not parsed |

Write a fence so its YAML still reads as a plain code block, because most readers outside Hive Desktop see it that way.

## Rules for every fence

- The body is YAML 1.2, core schema. Hive ignores unknown keys.
- A body that does not parse or misses a required key shows an error above the raw source. The doc still reads, but the component is gone, so get the shape right.
- Quote a string that holds `: `, a leading `#`, `[`, `{`, `*`, `&`, or `!`. Issue titles and notes often hold a colon.
- Quote a version string: `1.10` parses as the number `1.1`.
- Only a top-level fence renders as a component. A fence inside a list item or a blockquote stays a code block.
- An unknown `hive-*` lang shows as a plain code block. Do not invent fence names.

## hive-tree: changed files

A collapsible file tree built from a flat list of paths. Use it for the files a change touches, the layout of a new package, or the files a review covered.

- `root` (optional): a path prefix shown as the top folder. The `path` values are relative to it.
- `files` (required): a list. Each item:
  - `path` (required): a file path, relative to `root`. Do not put `:line` in it, because the tree splits on `/` and shows the whole last segment as the file name. Put line refs in `note`.
  - `status` (optional): `added`, `modified`, `deleted`, or `renamed`. Leave it out for a file the doc only mentions.
  - `from` (optional): the old path of a rename.
  - `note` (optional): one line beside the file.

A path that matches a Drive document becomes a link.

````markdown
```hive-tree
root: internal/auth
files:
  - path: service.go
    status: modified
    note: "NewService takes a clock; Login checks expiry"
  - path: service_test.go
    status: modified
    note: table tests for expired and revoked tokens
  - path: store/sql.go
    status: added
    note: Store backed by the sessions table
  - path: legacy/cookie.go
    status: deleted
  - path: tokens.go
    status: renamed
    from: token.go
```
````

## hive-calls: call tree

One call tree with a root call. The reader clicks a row, or moves with the arrow keys, and reads its `explain` text in a strip under the tree. Use it for a request path, the flow of data from A to B, or the path that leads to a bug.

Each call is a map:

- `name` (required): the function, method, or component name, as in the code (`Service.Login`).
- `at` (optional): `path:line`, a path, or a package name (`markdown-it`).
- `kind` (optional): `function`, `method`, `component`, `computed`, or `external`. Without it, Hive picks from `at`: a `.vue` file with a capitalized name is a component, an `at` with no `/` or `.` is an external package, anything else is a function.
- `note` (optional): one line shown in the row.
- `explain` (optional): a few sentences shown when the row is selected. Defaults to `note`.
- `focus` (optional): `true` starts this row selected. Set it on at most one row, the call the doc is about.
- `more` (optional): a whole number of calls left out, shown as "... N more".
- `calls` (optional): the child calls, in call order.

The root is a single call, not a list. Show the calls that matter and count the rest in `more`.

````markdown
```hive-calls
name: Handler.Login
at: internal/http/auth.go:41
kind: method
calls:
  - name: Service.Login
    at: internal/auth/service.go:88
    kind: method
    note: checks credentials, then issues a token
    calls:
      - name: Store.Get
        at: internal/auth/store/sql.go:23
        kind: method
      - name: issueToken
        at: internal/auth/tokens.go:15
        focus: true
        note: expiry comes from time.Now
        explain: "The expiry uses time.Now directly, so tests cannot fix the clock. The plan injects a clock here."
    more: 2
  - name: bcrypt.CompareHashAndPassword
    at: golang.org/x/crypto/bcrypt
    kind: external
```
````

## hive-forge: PR and issue cards

Static cards for pull requests and issues from GitHub, Gitea, Forgejo, or GitLab. Hive fetches nothing when the doc opens, so the cards show what you wrote. Fetch the data (`gh`, `tea`, `ghissues`) at the time you write the doc, and set `snapshot` so the reader knows its age.

- `snapshot` (optional, but always set it): when you took the data, such as `2026-11-23T14:05`.
- `host` (optional): the default host for items without `url`. Default `github.com`.
- `items` (required): a list. Each item:
  - `kind` (required): `pr` or `issue`.
  - `ref` (required): `owner/repo#123`.
  - `title` (required): quote it, because titles often hold `:` or `#`.
  - `state` (required): `open`, `draft`, `merged`, or `closed`.
  - `url` (optional): required in practice for any host other than github.com. Without it Hive builds a GitHub-style URL, which is wrong for Gitea, Forgejo, and GitLab.
  - `author`, `checks` (such as `6/6`), `diff` (such as `+120 -30`), `comments` (a number), `labels` (a list of strings), `updated` (optional).

Do not guess a field. Leave out what you did not fetch.

````markdown
```hive-forge
snapshot: 2026-11-23T14:05
items:
  - kind: issue
    ref: acme/api#412
    title: "Login: tokens never expire in tests"
    state: open
    labels: [bug, auth]
  - kind: pr
    ref: infra/deploy#212
    url: https://gitea.example.com/infra/deploy/pulls/212
    title: Pin the runner image
    state: merged
    checks: 6/6
```
````

## Wikilinks

Link to another document in the same Drive space:

| Write | Links to |
| --- | --- |
| `[[research/2026-11-20-auth-flow]]` | The doc at that path. `.md` is optional. |
| `[[research/2026-11-20-auth-flow\|the research]]` | The same doc, shown as "the research". |
| `[[2026-11-20-auth-flow]]` | The one doc with that file name in the space. |

- The path is relative to the space root, not to `.hive/` in the checkout: write `[[plans/x]]`, not `[[.hive/plans/x]]`.
- Inside a table cell, escape the alias pipe as `\|`.
- A link that matches nothing shows as plain text, so check the target with `hive drive ls`.
- Front matter is YAML, not markdown. Keep plain paths there (`research: .hive/research/x.md`) and put the wikilink in the body.
- A share link holds one document, so wikilinks show as plain text there. In a doc meant for `hive drive share`, write the target name in words too.

## Graphs

There is no fence for dependency or component graphs. Use a `mermaid` fence with `flowchart LR`. Mermaid renders in Drive, on share links, and on GitHub.

## Pick one

| Content | Use |
| --- | --- |
| Files a change adds, changes, or deletes | `hive-tree` |
| A package layout for new code | `hive-tree` with `status: added` |
| How a call or request moves through the code | `hive-calls` |
| Components and how they depend on each other | `mermaid` `flowchart LR` |
| Related PRs and issues | `hive-forge` |
| Another Drive doc | `[[wikilink]]` |
| A comparison, or several columns per row | a markdown table |
