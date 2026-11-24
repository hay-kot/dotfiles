#!/usr/bin/env node
// Records a scripted walk through a web app for a pull request: an H.264 MP4
// and a JPEG poster, optionally uploaded with pra. Runs from any repo; --help
// lists the options and the scene file format.
import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";
import { Director, Screencast } from "./director.mjs";

const HELP = `Usage: pr-record <scene.mjs> --url <base-url> [options]

Records a scene against a running app and writes <out>/<name>.mp4 and
<out>/<name>-poster.jpg.

Options:
  --url <url>       base URL of the app, such as http://localhost:5173
                    (default: $RECORD_BASE_URL)
  --name <name>     output file name, lower case (default: the scene file name)
  --out <dir>       output directory (default: $TMPDIR/pr-media)
  --phone           record at 375x812 in place of 1280x800
  --dark            prefer the dark color scheme
  --hide <css>      hide elements that match the selector in every frame, such
                    as a dev toolbar; repeat for more
  --upload          upload both files with pra to this branch's pr type and
                    print the Markdown to paste into the PR body
  -h, --help        show this help

A scene is an ES module:

  export const start = "/search";     // optional path to open before recording
  export const posterAt = 3;          // optional poster time in seconds
  export const hide = [".dev-bar"];   // optional, added to --hide
  // optional, runs before the recording starts: sign in, seed state
  export async function prepare({ page, d, baseUrl }) {}
  export default async function ({ page, d, baseUrl }) {
    await d.click(page.getByPlaceholder("Search"));
    await d.type("soup");
  }

d is the Director: click, hover, glide, type, scrollTo, settled, sleep.
Playwright comes from the current repo when it has it, else from the
mise-installed npm:playwright. See src/pr-record/examples/ in the dotfiles
repo, and docs/pr-assets.md for the whole workflow.`;

const { values: opts, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    url: { type: "string" },
    name: { type: "string" },
    out: { type: "string" },
    phone: { type: "boolean" },
    dark: { type: "boolean" },
    hide: { type: "string", multiple: true },
    upload: { type: "boolean" },
    help: { type: "boolean", short: "h" },
  },
});
if (opts.help || positionals.length !== 1) {
  console.log(HELP);
  process.exit(opts.help ? 0 : 2);
}

const fail = (msg) => {
  console.error(`record: ${msg}`);
  process.exit(1);
};

const run = (cmd, args) =>
  execFileSync(cmd, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  });

function baseUrl() {
  const raw = opts.url ?? process.env.RECORD_BASE_URL;
  if (!raw)
    fail("pass --url with the app's base URL, such as http://localhost:5173");
  const url = new URL(raw);
  // Dev servers set cookies, CORS origins and auth callbacks for localhost,
  // so a session started on 127.0.0.1 often fails partway through.
  if (url.hostname === "127.0.0.1")
    fail(`use localhost, not 127.0.0.1: ${raw}`);
  return url.origin + url.pathname.replace(/\/$/, "");
}

const PLAYWRIGHT = ["playwright", "@playwright/test", "playwright-core"];

function loadPlaywright() {
  const fromRepo = createRequire(join(process.cwd(), "package.json"));
  for (const name of PLAYWRIGHT) {
    try {
      return fromRepo(name);
    } catch {}
  }
  let dir;
  try {
    dir = run("mise", ["where", "npm:playwright"]).trim();
  } catch {
    fail(
      "no Playwright in this repo and no mise npm:playwright install; run mise install",
    );
  }
  return createRequire(join(dir, "package.json"))("playwright");
}

// The repo's Playwright may not have downloaded its browsers; the installed
// Google Chrome works with any recent Playwright.
async function launch(chromium) {
  try {
    return await chromium.launch();
  } catch (err) {
    if (!/Executable doesn't exist|playwright install/.test(String(err)))
      throw err;
    return chromium.launch({ channel: "chrome" });
  }
}

const scenePath = resolve(positionals[0]);
const scene = await import(pathToFileURL(scenePath).href);
if (typeof scene.default !== "function")
  fail(`${scenePath} has no default export function`);
const name = opts.name ?? basename(scenePath).replace(/\.m?js$/, "");
if (!/^[a-z0-9][a-z0-9._-]*$/.test(name)) {
  fail(
    `${name}: use lower case letters, digits, '.', '-' and '_' for the name, so pra keeps the file names`,
  );
}

let branch = "";
if (opts.upload) {
  branch = run("git", ["branch", "--show-current"]).trim();
  if (!branch || branch === "main" || branch === "master")
    fail("--upload needs a feature branch");
}

const url = baseUrl();
const { chromium } = loadPlaywright();
const viewport = opts.phone
  ? { width: 375, height: 812 }
  : { width: 1280, height: 800 };
const outDir = resolve(opts.out ?? join(tmpdir(), "pr-media"));
mkdirSync(outDir, { recursive: true });
const mp4 = join(outDir, `${name}.mp4`);
const poster = join(outDir, `${name}-poster.jpg`);
const hide = [...(scene.hide ?? []), ...(opts.hide ?? [])];

const browser = await launch(chromium);
try {
  const context = await browser.newContext({
    viewport,
    deviceScaleFactor: 2,
    isMobile: Boolean(opts.phone),
    colorScheme: opts.dark ? "dark" : "light",
  });
  const page = await context.newPage();
  await page.goto(url + (scene.start ?? "/"));

  const d = new Director(page, { hide });
  await d.setup();
  await d.settled();
  if (scene.prepare) {
    await scene.prepare({ page, d, baseUrl: url });
    await d.setup();
    await d.settled();
  }
  await d.sleep(300);

  const sc = new Screencast(page, join(outDir, `.frames-${name}`));
  await sc.start();
  await d.sleep(600);
  await scene.default({ page, d, baseUrl: url });
  await d.sleep(800);
  await sc.stop();
  const { total, frames } = sc.encode({
    mp4,
    poster,
    width: viewport.width * (opts.phone ? 2 : 1.25),
    posterAt: scene.posterAt,
  });
  console.error(`${name}: ${total.toFixed(1)}s, ${frames} frames`);
  await context.close();
} finally {
  await browser.close();
}

console.log(mp4);
console.log(poster);

if (opts.upload) {
  const urls = run("pra", ["put", mp4, poster]).match(/https?:\/\/\S+/g);
  if (urls?.length !== 2) fail("pra did not print two URLs");
  const [videoUrl, posterUrl] = urls;
  console.log(`\n[![${name} (video)](${posterUrl})](${videoUrl})`);
}
