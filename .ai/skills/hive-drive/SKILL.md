---
name: hive-drive
description: >
  Save documents to Hive Drive and manage the tabs beside the session through the hive-drive MCP
  server, and push documents or create share links with the hive CLI when the user asks. Use when
  a result reads better rendered than as terminal text (tables, comparisons, reports, diagrams),
  when a skill saves a doc or mockup to Drive, when the user asks to open, move, or close a tab, or
  when the user asks to push a doc or share a link to it.
---

# Hive Drive

Hive Drive is the folder of markdown and html documents beside a chat or Code session. The
`hive-drive` MCP server writes them and arranges the tabs that show them. The `hive drive` CLI
copies them to a drive server and makes share links.

## Session

Every tool takes `caller`:

- `$HIVE_AGENT_SESSION` when it is set (Hive Desktop chats).
- Otherwise the absolute path of the working directory (`pwd`), which names the hive session.

A `not_found` on that value means this is not a hive session. Say so and answer in chat. Don't
retry with other values, and don't fall back to `global`: the shared space sits beside no session,
so nothing written there can open as a tab.

In a hive session the space is the repo's `.hive` folder, so `research/x.md` here is the file
`.hive/research/x.md`.

## Pick a format

- **Markdown** (`.md`) by default: plans, research, notes, reports, tables. The body may open
  with YAML front matter, and `title` sets the name the user sees. Front matter that doesn't parse
  is refused, not saved.
- **HTML** (`.html`) when the layout is the point: styled reports, drawn diagrams, mockups. The
  page renders in a sandboxed frame. Follow `drive-doc-style`, which lists what the frame allows.

## Documents

1. `document_list` on the folder before you pick a path, and follow the sibling naming
   (`research/YYYY-MM-DD-<slug>.md`). Folders in the path are created as needed.
2. If the path exists, `document_get` it first. The user or another chat may have changed it.
3. `document_put` replaces the whole document. Keep the same path for revisions.
4. Only move or delete documents you wrote or were asked to touch. `document_delete` has no trash.

## Tabs

Writes never open a tab. A write to a Drive tab that is open behind another tab only lights an
unseen dot on it. When a document is ready to read, show it once:

```text
tab_open  view: drive  path: <document path>
```

- Leave `placement` at its default, `behind`. The doc opens as a new tab in the session, behind
  the tab in front, with an unseen dot. The user's terminal stays on screen and they switch when
  they're ready.
- Use `beside` or `below` only when the user asked to see the result next to the terminal. Those
  split the panel and show it at once.
- Don't use `tab_focus` to show a result. It takes the screen. Use it only when the user asks to
  switch to a tab.
- Don't use `hive desktop open hive://...` to show a result. A link raises the window and can
  leave the session for the Drive page.
- Open once, when the work is ready, not after every write. A Drive tab that is already open stays
  where it is.
- Tab changes apply only while the user is viewing this session, and there is no
  acknowledgment. Call `layout_get` when you're not sure what is open: its tab names are the ones
  the tab tools take, and `onScreen: false` means the open will not land. Either way, give the
  document path in chat.
- Close only tabs you opened. `tab_close` on a terminal window kills the window and what runs in
  it.
- `diff`, `tasks`, and terminal windows exist only in Code sessions. A chat has `drive`.

## Push and share

`push` uploads documents to a drive server, and `share` prints a public link to a pushed
document. Run them only when the user asks, and only for the documents they named.

```sh
hive drive push plans/ship.md
hive drive share plans/ship.md --expires 7d
```

- Paths are space paths, the same ones the MCP tools take. From the repo checkout the CLI picks
  the repo's space. Elsewhere pass `--repo owner/name` or `--workspace <name>`.
- Always pass paths to `push`. With none it uploads the whole space.
- `push` skips unchanged documents, so push again after a revision. `share` on the same path
  returns the same link.
- Anyone with the link can read the document. Without `--expires` (`1d`, `7d`, `30d`) a new link
  never expires, so say which in chat.
- If `push` fails for a missing login or server, ask the user to run
  `! hive drive login <server>`. It reads a token from a prompt.

## In chat

Still give a one or two line summary in chat, with the document path, and the link when you
shared one.
