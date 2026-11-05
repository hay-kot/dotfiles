---
name: hive-drive
description: >
  Save documents and canvases to Hive Drive and manage the tabs beside the session through the
  hive-drive MCP server. Use when a result reads better rendered than as terminal text (tables,
  comparisons, reports, diagrams), when a skill saves a doc or mockup to Drive, or when the user
  asks to open, move, or close a tab.
---

# Hive Drive

Hive Drive is the folder of documents beside a chat or Code session: markdown, html, and
canvases. The `hive-drive` MCP server writes them and arranges the tabs that show them. Hive chat
workspaces may still list the server as `hive-canvas`. It is the same server with the same tools.

## Session

Every tool takes `caller`:

- `$HIVE_AGENT_SESSION` when it is set (Hive Desktop chats).
- Otherwise the absolute path of the working directory (`pwd`), which names the hive session.

A `not_found` on that value means this is not a hive session. Say so and answer in chat. Don't
retry with other values, and don't fall back to `global`: the shared space sits beside no session,
so nothing written there can open as a tab.

## Pick a format

- **Document** for something the user keeps and rereads: plans, research, design docs, mockups.
  `document_put` takes `.md` or `.html`. For styled HTML pages, follow `drive-doc-style`.
- **Canvas** for a surface you revise in place while work runs: a status report, a comparison,
  stat tiles. Blocks are sanitized and use the `hv-` classes below.

In a hive session the space is the repo's `.hive` folder, so `research/x.md` here is the file
`.hive/research/x.md`.

## Documents

1. `document_list` on the folder before you pick a path, and follow the sibling naming
   (`research/YYYY-MM-DD-<slug>.md`).
2. If the path exists, `document_get` it first. The user or another chat may have changed it.
3. `document_put` replaces the whole document. Keep the same path for revisions.
4. Only move or delete documents you wrote or were asked to touch.

## Canvases

1. Name the canvas after the artifact (`perf-report`), not the conversation. Set `canvasTitle` on
   the first write.
2. `canvas_list` first. If the name exists, `canvas_get` it before you overwrite it.
3. Lay out the first version with `canvas_blocks_put` in one call.
4. Revise with `canvas_block_put` and the same `id`, so the block updates in place instead of stacking a
   copy.

## Tabs

Writes never open a tab. A write to a Drive tab that is open behind another tab only lights an
unseen dot on it. When a document or canvas is ready to read, show it once:

```text
tab_open  view: drive  path: <document path, or canvas name>
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

## Blocks

- `markdown`: prose, lists, simple tables. Raw HTML is escaped. A standalone ` ```mermaid ` fence
  renders as a diagram. Use this by default.
- `html`: only when the layout is the point: stat tiles, columns, cards, drawn diagrams.
- `link`: `title` plus an `http`, `https`, or `mailto` URL.

## HTML block rules

Hive refuses a block it can't sanitize and names the problem. It doesn't silently drop anything.

- Refused: `script`, the `style` element (the `style` attribute is fine), `iframe`, `object`,
  `embed`, `form` and its controls, `on*` handlers, and the `id` attribute.
- Allowed: normal sectioning, text, list, table, and code tags, `details`/`summary`, `a`, and
  `img` with an `http`, `https`, or base64 `data:` source.
- SVG: `svg`, `g`, `path`, `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`, `text`,
  `tspan`. There's no `defs`, `marker`, or `use`, so draw arrowheads as a `polygon`. Give the
  `svg` a `viewBox` so it scales to the pane.

Use the `hv-` classes before you write your own colors. They follow the user's light or dark
theme.

| Purpose    | Classes                                                                                                  |
| ---------- | -------------------------------------------------------------------------------------------------------- |
| Layout     | `hv-stack`, `hv-row`, `hv-grid` + `hv-cols-2` to `hv-cols-6` (collapse when the panel is narrow)         |
| Containers | `hv-card`, `hv-panel`, `hv-callout`                                                                      |
| Data       | `hv-stat-card` > `hv-stat-value` (+ `hv-stat-unit`), `hv-stat-label`, `hv-stat-sub`; `hv-kv` on a `<dl>` |
| Emphasis   | `hv-badge`, `hv-muted`, `hv-mono`                                                                        |
| Tones      | `hv-info`, `hv-success`, `hv-warn`, `hv-error`, `hv-accent`                                              |
| SVG roles  | `hv-node`, `hv-edge`, `hv-arrow`, `hv-label`, `hv-dashed` (with `hv-edge`)                               |

`hv-stat` is the `hv-stat-card` layout without the card border, for a figure inside your own
container. Put a tone on a stat card only for the number that needs attention.

```html
<div class="hv-grid hv-cols-3">
  <div class="hv-stat-card hv-success">
    <span class="hv-stat-value">98.2<span class="hv-stat-unit">%</span></span>
    <span class="hv-stat-label">Success</span>
  </div>
  <div class="hv-stat-card">
    <span class="hv-stat-value">412<span class="hv-stat-unit">ms</span></span>
    <span class="hv-stat-sub">was 530ms last week</span>
    <span class="hv-stat-label">p95</span>
  </div>
  <div class="hv-stat-card hv-error">
    <span class="hv-stat-value">3</span>
    <span class="hv-stat-label">Failing</span>
  </div>
</div>
<div class="hv-callout hv-warn">
  <strong>Migration 0042 is not reversible.</strong> Back up first.
</div>
```

The `hv-` classes mean nothing outside Hive. If the canvas is meant to leave the app, use inline
`style`, `fill`, and `stroke` instead.

## In chat

Still give a one or two line summary in chat, with the document path or canvas name.
