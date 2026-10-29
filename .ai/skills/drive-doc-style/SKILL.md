---
name: drive-doc-style
description:
  Style guide and starter template for HTML documents saved in Hive Drive
  (design docs, research write-ups, investigations, decision records,
  explainers). Use when writing or restyling an HTML doc in .hive/ for a
  complicated problem, or when the user asks for a Drive doc to look like an
  Artifact.
---

# Drive doc style

Rules for HTML documents that live in Hive Drive and open in the Hive pane. They
are the Artifact design rules, adapted for local-only docs: no publish step, no
CDN allowlist, no runtime capabilities.

Use this for docs where structure helps the reader think: trade-off comparisons,
data-flow diagrams, failure analysis, decision records. For short notes, plain
markdown is fine.

## Workflow

1. Copy `assets/doc.html` (in this skill's directory) to the Drive path. Edit
   the content; preserve the baseline palette unless the user explicitly asks
   for different colors.
2. Save under the repo's Drive space, for example
   `design-docs/YYYY-MM-DD-<slug>.html` or `research/YYYY-MM-DD-<slug>.html`.
   Follow the date-slug convention of the sibling files.
3. If a markdown doc with the same slug exists, keep it. The HTML is a rendered
   companion, so say which one is the source of truth in the doc's meta line.
4. Open it with the Hive Drive tools (see the `mockups` skill for the save/open
   steps and the snapshot helper).

## Constraints from the Drive frame

- Inline CSS and JS only. HTTPS assets load, but the doc must read correctly
  offline, so use system font stacks. Do not depend on a web font.
- Forms do not submit, nested frames and popups do not work, and there is no app
  storage.
- Keep the file under 2 MiB.
- Do not use Hive Canvas `hv-` classes. They do nothing in a standalone
  document.

## Rules

**Tokens first.** Every color is a CSS variable defined on bare `:root` (light
values). Redefine the same tokens under `@media (prefers-color-scheme: dark)`
and set `color-scheme: dark` there. `body` sets an explicit `background` from a
token. No literal colors in component rules.

**Baseline palette.** Use these exact values, shared with `assets/doc.html`:
slate neutrals with a teal accent. Do not invent a new palette for each
document. Change it only when the user explicitly requests another one.

| Token           | Light     | Dark      |
| --------------- | --------- | --------- |
| `--bg`          | `#f6f8fa` | `#0f151c` |
| `--surface`     | `#ffffff` | `#161e27` |
| `--surface-2`   | `#eef2f6` | `#1d2733` |
| `--border`      | `#d5dde6` | `#2b3745` |
| `--text`        | `#1b2430` | `#dbe3ec` |
| `--muted`       | `#5b6878` | `#93a1b3` |
| `--accent`      | `#0b6e8a` | `#5cc3dd` |
| `--accent-soft` | `#dcecf2` | `#17323d` |
| `--good`        | `#1a7f4b` | `#4cc380` |
| `--good-soft`   | `#dff2e7` | `#14301f` |
| `--warn`        | `#825700` | `#e0ae45` |
| `--warn-soft`   | `#f7ebcf` | `#36290f` |
| `--bad`         | `#c23030` | `#f07272` |
| `--bad-soft`    | `#f8e0e0` | `#3a1a1a` |

**Neutrals have a hue.** Keep the baseline's slate tint. No pure mid-grey.

**One accent, separate semantics.** One accent hue for links and emphasis. Good,
warning, and critical colors are a separate set and only mark state (pass/fail,
recommended/rejected, risk). Never use semantic colors as decoration.

**Avoid the generic AI look.** Not cream plus serif plus terracotta. Not
near-black plus one acid pop. Not purple-to-blue gradients. No emoji section
markers, no centered-everything, no rounded-corner-and-shadow on every block. If
the user names a direction, follow that.

**Type.** System sans for body, system mono for identifiers, flags, metrics, and
figure text. Fixed scale (see the template). Text uses the full content column,
not a separate character-width cap. `text-wrap: balance` on headings.
`font-variant-numeric: tabular-nums` on tables and any column of numbers.
Uppercase labels get a little letter-spacing.

**Structure is information.** Number sections only when order matters (a
procedure, a timeline, rollout phases) or the text cross-references them by
number. Use a table of contents only when the doc has more than about five
sections. Do not add eyebrows or dividers that encode nothing.

**Contents block, not a row of links.** A table of contents is a bordered block
with a `Contents` label and a grid of entries (`.toc` in the template): number
in muted mono, title in the body text color, no underline, and the accent with
a `--surface-2` fill on hover. List only the numbered sections; do not mix in
unnumbered sub-entries. A wrapping row of underlined accent links is hard to
scan.

**Links.** Prose links use the accent with a thin underline
(`text-decoration-thickness: 1px; text-underline-offset: 2px`). Navigation
links (contents, cross-references in a block) drop the underline and rely on
the hover state.

**Summary before detail.** Open with the problem, the decision or finding, and
what the reader must do or approve. Put the reasoning after. A reader who stops
after the first screen should still have the answer.

**Show state in form.** Decision status, option verdicts, and risk levels use a
pill, not just a word in a sentence. Keep one pill style across the doc.

**Cards by role.** Border, fill, and radius mark a separate object. Use them for
figures, callouts, and option panels. Do not wrap ordinary paragraphs.

**Tables hold short values.** Use a table only when every cell is a short,
comparable value (a date, a status pill, a number, a name, a path) and the
reader scans down a column. If a cell needs a sentence, a list, or more than
about ten words, the table is the wrong form: use entries or a month rail
instead. Never put a list inside a table cell, and never build a grid of
months by lanes or people where every cell is a stack of bullets. Compare
options in a table with the criteria as rows when the values are short. Put
the recommendation in its own column or row, marked with a pill. Wrap each
wide table in an `overflow-x: auto` container.

**Entries for items with prose.** Risks, constraints, options with reasoning,
gates, and similar items that each carry a sentence or more go in an entry
grid (`.entries` in the template): one bordered card per item, the item name
as an `h4`, the body, and an optional footer under a label (`Mitigation`,
`Plan`, `Risk`) separated by a rule. A verdict or status goes in a pill in the
`h4`. When the items fall into meaningful groups (risks by kind, for example),
put each group under its own `h3` instead of one long flat list.

**Timelines are month rails.** Draw a schedule as one row per month (`.months`
in the template): the month on the left, its items on the right in date
order, each with the date in mono (`11-13`, `wk 1`) and its lane or track as a
neutral pill. Undated work follows the dated items in the same month.
Checkpoints use the warn fill and a `Checkpoint` pill. A per-person plan uses
the same rail with one labeled list per person inside each month. The rail
reads top to bottom on a phone with no sideways scroll.

**Diagrams.** Draw the real mechanism: the actual components, queues, and limits
from the code, not a generic box-and-arrow. Inline SVG with a `viewBox`, every
shape with an explicit `fill`, text colored from tokens, and room in the viewBox
for the outermost labels. For simple flows, a ` ```mermaid ` diagram in the
markdown companion is enough. Animate only to show flow or state change (for
example dashed lines for data moving, paused when a path is blocked), and honor
`prefers-reduced-motion`.

**Include one detail only this problem has.** Real units, real config keys, real
metric names, real numbers from the code or a benchmark. Never lorem ipsum or
invented figures. Mark estimates as estimates.

**Layout.** Single content column, max width about 980px, side padding at least
16px at every width. Paragraphs, lists, callouts, tables, and figures share that
column's width. Do not add narrower `max-width` or `max-inline-size` caps to
prose or callouts (such as `70ch`); constrain the document once on `main`.
Content inside a card follows that card's inner width. Use flex or grid with
`gap`, not stacked margins. Rows wrap to one column at about 400px. Only tables,
code, and diagrams may scroll horizontally, inside their own container.

**Complete at rest.** Everything readable is visible on load. No content waits
on a scroll observer. No full-viewport hero.

**Accessibility.** Visible focus states. Text contrast of at least 4.5:1 in both
themes. State is never carried by color alone: pair a color with a word or a
shape.

## Writing

Follow the Human-first rules in the user's AGENTS.md. In short: plain, active,
short sentences, no em-dashes or en-dashes (use hyphens, or `--`), no emoji, no
promotional wording. Name things the way the codebase does. Errors and risks say
what breaks and what to do about it.

## Checklist before opening

- [ ] Light and dark both read correctly (check the `prefers-color-scheme` block
      redefines every token)
- [ ] First screen states the problem and the decision or finding
- [ ] Palette matches the baseline unless the user explicitly requested
      different colors
- [ ] Prose, lists, and callouts use the same content width as tables and
      figures
- [ ] No horizontal page scroll at 400px
- [ ] No table cell holds a list or more than a short phrase; prose items are
      entries, schedules are month rails
- [ ] A contents list, if any, is a `.toc` block, not a row of underlined
      links
- [ ] Figures use token colors and have captions that say what to look at
- [ ] No literal hex values outside the `:root` token blocks
- [ ] No em-dashes, en-dashes, or emoji in the text
