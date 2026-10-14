#!/usr/bin/env node

import { existsSync } from "node:fs";
import {
  mkdtemp,
  mkdir,
  readFile,
  rm,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, delimiter, join, resolve } from "node:path";
import { spawn } from "node:child_process";
import { pathToFileURL } from "node:url";

const [, , input, outputArg] = process.argv;
if (!input || !outputArg) {
  console.error("usage: node snapshot.mjs <mockup.html> <output-directory>");
  process.exit(2);
}

const inputPath = resolve(input);
const outputDirectory = resolve(outputArg);
if (!existsSync(inputPath)) {
  console.error(`mockup not found: ${inputPath}`);
  process.exit(2);
}
await mkdir(outputDirectory, { recursive: true });

function executableOnPath(name) {
  for (const directory of (process.env.PATH ?? "").split(delimiter)) {
    const candidate = join(directory, name);
    if (existsSync(candidate)) return candidate;
  }
  return undefined;
}

const browserCandidates = [
  process.env.CHROME_BIN,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  executableOnPath("google-chrome"),
  executableOnPath("chromium"),
  executableOnPath("chromium-browser"),
].filter(Boolean);
const executablePath = browserCandidates.find(existsSync);
if (!executablePath) {
  console.error("no compatible Chrome or Chromium executable found");
  process.exit(1);
}

const source = await readFile(inputPath, "utf8");
const tabPattern = /<(?:button|a)\b[^>]*\brole\s*=\s*["']tab["'][^>]*>([\s\S]*?)<\/(?:button|a)>/gi;
const tabNames = [...source.matchAll(tabPattern)]
  .map((match) => match[1].replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim())
  .slice(0, 6);
const optionNames = tabNames.length ? tabNames : ["Default"];

function lintShell() {
  const problems = [];
  const attribute = (name) => [...source.matchAll(new RegExp(`${name}\\s*=\\s*["']([^"']+)["']`, "g"))].map((match) => match[1]);
  if (/REPLACE:/.test(source)) problems.push("template placeholder text (REPLACE:) is still present");
  const tabIds = attribute("data-mockup-tab");
  const noteIds = attribute("data-mockup-note");
  const optionIds = attribute("data-mockup-option");
  const problemIds = new Set(attribute("data-problem"));
  if (new Set(tabIds).size !== tabIds.length) problems.push("duplicate data-mockup-tab ids");
  for (const id of tabIds) {
    if (!noteIds.includes(id)) problems.push(`tab ${id} has no data-mockup-note article in the brief`);
    if (!optionIds.includes(id)) problems.push(`tab ${id} has no data-mockup-option panel`);
  }
  for (const id of [...noteIds, ...optionIds]) {
    if (!tabIds.includes(id)) problems.push(`${id} has a note or panel but no tab`);
  }
  for (const group of attribute("data-solves")) {
    for (const id of group.split(/\s+/).filter(Boolean)) {
      if (!problemIds.has(id)) problems.push(`data-solves references unknown problem ${id}`);
    }
  }
  return [...new Set(problems)];
}
if (tabNames.length) {
  const lint = lintShell();
  if (lint.length) {
    console.error("Shell check failed:");
    for (const problem of lint) console.error(`- ${problem}`);
    process.exit(1);
  }
}
const viewports = [
  { name: "desktop", width: 1440, height: 900 },
  { name: "pane", width: 760, height: 900 },
];
const manifest = {
  source: inputPath,
  browser: executablePath,
  snapshots: [],
};
const temporaryDirectory = await mkdtemp(join(tmpdir(), "mockup-snapshot-"));
const profileDirectory = join(temporaryDirectory, "chrome-profile");

function slug(value, fallback) {
  const normalized = value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 48);
  return normalized || fallback;
}

function sourceForOption(index) {
  if (!tabNames.length) return source;
  const activation = `<script data-mockup-snapshot>window.addEventListener("load",()=>{const tabs=document.querySelectorAll('[role="tab"]');if(tabs[${index}])tabs[${index}].click();});<\/script>`;
  const bodyEnd = source.toLowerCase().lastIndexOf("</body>");
  if (bodyEnd === -1) return `${source}\n${activation}\n`;
  return `${source.slice(0, bodyEnd)}${activation}\n${source.slice(bodyEnd)}`;
}

function runChrome(args) {
  return new Promise((resolveRun, rejectRun) => {
    const child = spawn(executablePath, args, {
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stderr = "";
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", rejectRun);
    child.on("close", (code) => {
      if (code === 0) {
        resolveRun();
        return;
      }
      rejectRun(new Error(`Chrome exited with status ${code}: ${stderr.trim()}`));
    });
  });
}

try {
  for (let index = 0; index < optionNames.length; index += 1) {
    const optionName = optionNames[index];
    const renderedSource = join(temporaryDirectory, `option-${index + 1}.html`);
    await writeFile(renderedSource, sourceForOption(index));

    for (const viewport of viewports) {
      const filename = `${viewport.name}-${String(index + 1).padStart(2, "0")}-${slug(optionName, `option-${index + 1}`)}.png`;
      const outputPath = resolve(outputDirectory, filename);
      await runChrome([
        "--headless=new",
        "--disable-gpu",
        "--hide-scrollbars",
        "--no-first-run",
        "--no-default-browser-check",
        `--user-data-dir=${profileDirectory}`,
        `--window-size=${viewport.width},${viewport.height}`,
        "--force-device-scale-factor=1",
        "--run-all-compositor-stages-before-draw",
        "--virtual-time-budget=1000",
        `--screenshot=${outputPath}`,
        pathToFileURL(renderedSource).href,
      ]);
      if (!existsSync(outputPath)) {
        throw new Error(`Chrome did not create ${outputPath}`);
      }
      manifest.snapshots.push({
        viewport: viewport.name,
        width: viewport.width,
        height: viewport.height,
        option: optionName,
        path: outputPath,
      });
    }
  }
} finally {
  await rm(temporaryDirectory, { recursive: true, force: true });
}

const manifestPath = resolve(outputDirectory, "snapshot-manifest.json");
await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Captured ${manifest.snapshots.length} snapshots for ${basename(inputPath)}`);
for (const snapshot of manifest.snapshots) {
  console.log(`${snapshot.viewport}\t${snapshot.option}\t${snapshot.path}`);
}
