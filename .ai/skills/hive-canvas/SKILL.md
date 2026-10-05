---
name: hive-canvas
description: >
  Show rendered output in the Hive canvas pane beside the chat through the hive-canvas MCP server.
  Use when a result reads better rendered than as terminal text (tables, comparisons, stat
  summaries, diagrams, reports), or when the user asks to put something on the canvas.
---

# Hive Canvas

A canvas is a named, ordered list of blocks that Hive renders in a pane beside the chat. Canvases
are saved in the workspace and outlive the conversation.

## Session

Every tool takes `session`:

- `$HIVE_AGENT_SESSION` when it is set (Hive Desktop chats).
- Otherwise the absolute path of the working directory (`pwd`), which names the hive session.

A `not_found` on that value means this is not a hive session. Say so and answer in chat. Don't
retry with other values.

## Workflow

1. Name the canvas after the artifact (`perf-report`, `release-notes`), not the conversation. Set
   `canvasTitle` on the first write.
2. Run `list_canvases` first. If the name already exists, `read_canvas` it before you overwrite
   it -- it may belong to an earlier chat.
3. Lay out the first version with `put_blocks` in one call.
4. Revise with `put_block` and the same `id`. That updates the block in place instead of adding a
   copy.
5. Call `open_canvas` once, when something is worth looking at. Writes to a closed pane already
   show an unseen dot.
6. Still give a one or two line summary in chat.

## Blocks

- `markdown` -- prose, lists, simple tables. Raw HTML is escaped. Use this by default.
- `html` -- use only when the layout is the point: stat tiles, columns, cards, diagrams.
- `link` -- `title` plus an `http`, `https`, or `mailto` URL.

## HTML rules

Hive refuses a block it can't sanitize and names the problem. It doesn't silently drop anything.

- Refused: `script`, the `style` element (the `style` attribute is fine), `iframe`, `object`,
  `embed`, `form` and its controls, `on*` handlers, and the `id` attribute.
- Allowed: normal sectioning, text, list, table, and code tags, `details`/`summary`, `a`, and `img`
  with an `http`, `https`, or base64 `data:` source.
- SVG: `svg`, `g`, `path`, `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`, `text`,
  `tspan`. There's no `defs`, `marker`, or `use`, so draw arrowheads as a `polygon`. Give the
  `svg` a `viewBox` so it scales to the pane.

Use the `hv-` classes before you write your own colors. They follow the user's light or dark theme.

| Purpose    | Classes                                                                                    |
| ---------- | ------------------------------------------------------------------------------------------ |
| Layout     | `hv-stack`, `hv-row`, `hv-grid` + `hv-cols-2`/`3`/`4` (collapse to one column when narrow) |
| Containers | `hv-card`, `hv-panel`, `hv-callout`                                                        |
| Data       | `hv-stat` > `hv-stat-value` + `hv-stat-label`; `hv-kv` on a `<dl>`                         |
| Emphasis   | `hv-badge`, `hv-muted`, `hv-mono`                                                          |
| Tones      | `hv-info`, `hv-success`, `hv-warn`, `hv-error`, `hv-accent`                                |
| SVG roles  | `hv-node`, `hv-edge`, `hv-arrow`, `hv-label`, `hv-dashed` (with `hv-edge`)                 |

```html
<div class="hv-grid hv-cols-3">
  <div class="hv-card hv-stat">
    <span class="hv-stat-value">98.2%</span
    ><span class="hv-stat-label">Success</span>
  </div>
  <div class="hv-card hv-stat">
    <span class="hv-stat-value">412ms</span
    ><span class="hv-stat-label">p95</span>
  </div>
  <div class="hv-card hv-stat">
    <span class="hv-stat-value">3</span
    ><span class="hv-stat-label">Failing</span>
  </div>
</div>
<div class="hv-callout hv-warn">
  <strong>Migration 0042 is not reversible.</strong> Back up first.
</div>
```

The `hv-` classes mean nothing outside Hive. If the canvas is meant to leave the app, use inline
`style`, `fill`, and `stroke` instead.
