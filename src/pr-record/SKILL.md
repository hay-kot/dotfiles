---
name: pr-assets
description: Take screenshots and screen recordings of an app, upload them with pra, and embed them in a pull request body. Use when a PR changes something visible (UI, layout, a multi-step flow, CLI or TUI output) or when the user asks for screenshots, a recording, a demo video, or images in a PR.
---

# Screenshots and recordings for pull requests

`pra` uploads files to a public bucket and prints stable URLs. Its config lives in `~/.config/prassets/config.yaml` and belongs to the user: never edit it, and never write a credential anywhere. Only repos listed in that config can upload.

## Before you start

Run `pra config check` in the repo. If a step fails, tell the user what failed and stop. Do not work around it with another bucket or a hand-written config.

## Rules

- The bucket is public. Show only dev, seed, or demo data. No real customer data, tokens, emails, internal URLs, or anything from a production database.
- Upload only the few images and videos that show the change. One before and after pair usually beats ten screenshots.
- `pra put` never overwrites. To replace a file, upload it under a new name. Do not pass `--force` unless the user asks.
- Use lower case file names with `-`, such as `recipe-view-after.png`. Save them in your scratchpad, not the repo.
- Assets expire after 30 days, so images in older PRs break. That is expected.

## Screenshots

1. Start the app and open it at `http://localhost:<port>`, never `127.0.0.1`: dev servers set cookies, CORS origins, and auth callbacks for `localhost`, so a session on `127.0.0.1` often fails partway through.
2. Take the screenshot with the Playwright MCP or the browser tool. Use the same data and state for before and after. When the layout changed, take a phone width (375px) and a desktop width (1280px).
3. Look at the image yourself before you upload it.
4. Upload: `pra put recipe-view.png` prints the URL, and `pra --format md put a.png b.png` prints Markdown.

The `pr` type keys uploads by branch, so you can upload before `gh pr create`.

## Recordings

Record a multi-step flow (more than one click or a state change over time) with `pr-record`. It drives the app with Playwright, draws a cursor that glides to each click (headless Chromium has none), and writes an H.264 MP4 and a JPEG poster.

1. Write a scene: a small ES module in your scratchpad that drives the page with Playwright locators. `pr-record --help` shows the format, and `src/pr-record/examples/sign-in-and-search.mjs` in the dotfiles repo (`$DOTFILES_DIR`) is a full one. Put sign-in and setup in `prepare`, which runs before the recording starts.
2. Run it from the repo root, so `pra` sees the repo and branch:

   ```sh
   pr-record scene.mjs --url http://localhost:5173 --upload
   ```

   `--phone` records at 375px, `--dark` uses the dark color scheme, `--hide <css>` hides a dev toolbar, and `--help` lists the rest.
3. `--upload` puts both files under this branch and prints a poster image that links to the video. Paste that line into the PR body.

Keep a recording under about 30 seconds.

GitHub plays inline only the videos it hosts. A `<video>` tag that points at another host is blocked, and a bare `.mp4` URL renders as a link, so reviewers see the poster and a click opens the video.

Other apps:

- iOS simulator: XcodeBuildMCP's `record_sim_video`, then `pra put` the file.
- CLI or TUI: see the next section.

## Terminal recordings (CLI and TUI)

Record a command or a TUI with `vhs`, which plays a tape file in a headless terminal and writes a GIF or MP4.

1. Write the tape in your scratchpad:

   ```tape
   Output hc-next.gif
   Set Shell bash
   Set FontSize 16
   Set Width 1200
   Set Height 600
   Set TypingSpeed 40ms

   Hide
   Type "export PS1='$ ' HOME=/tmp/demo-home && cd /tmp/demo && clear"
   Enter
   Show

   Type "mytool list --json"
   Sleep 500ms
   Enter
   Sleep 2s
   ```

   Put setup between `Hide` and `Show`: point the tool at a sandbox with demo data, and set a short prompt so no real path, user, or host name shows. For a TUI, `Sleep` until it draws, then send keys (`Down`, `Enter`, `Type "/"`) and quit with `Ctrl+C` or `q`.
2. Run `vhs tape.tape`. `vhs validate tape.tape` checks the syntax without a run.
3. Look at the result before you upload it. `Screenshot frame.png` in the tape saves a still, or `ffmpeg -i hc-next.gif -vf fps=1 frame-%02d.png` splits a GIF into frames. Read every frame for private data.
4. Upload with `pra put`.

GitHub shows a GIF inline, so use a GIF for a short clip (under about 15 seconds and 5 MB). For a longer one, write an MP4, take a poster with `ffmpeg -ss 2 -i demo.mp4 -frames:v 1 demo-poster.jpg`, upload both, and link the poster to the video: `[![what it shows](poster-url)](video-url)`.

## The PR body

`pra md` prints Markdown for every asset of this branch. Paste the lines you need under the PR template's section for reviewer notes or screenshots, with a short caption that says what each image shows. If the template has no such section, add the images after the summary.
