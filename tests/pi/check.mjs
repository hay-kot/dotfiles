import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { piDirectory } from "./runtime.mjs";

const modules = resolve(piDirectory, "../..");
const directory = mkdtempSync(join(tmpdir(), "pi-extension-check-"));
try {
  const config = join(directory, "tsconfig.json");
  writeFileSync(
    config,
    JSON.stringify({
      compilerOptions: {
        noEmit: true,
        strict: true,
        skipLibCheck: true,
        noUnusedLocals: true,
        noUnusedParameters: true,
        target: "ES2023",
        module: "ESNext",
        moduleResolution: "Bundler",
        allowImportingTsExtensions: true,
        typeRoots: [join(modules, "@types")],
        types: ["node"],
        paths: {
          "@earendil-works/pi-coding-agent": [
            join(piDirectory, "dist/index.d.ts"),
          ],
          "@earendil-works/pi-tui": [
            join(dirname(piDirectory), "pi-tui/dist/index.d.ts"),
          ],
          "@earendil-works/pi-agent-core": [
            join(dirname(piDirectory), "pi-agent-core/dist/index.d.ts"),
          ],
          typebox: [join(modules, "typebox/build/index.d.mts")],
        },
      },
      files: [
        ".pi/agent/extensions/ask-user-question.ts",
        ".pi/agent/extensions/custom-footer.ts",
        ".pi/agent/extensions/background-shell/index.ts",
        ".pi/agent/extensions/background-shell/jobs.ts",
        ".pi/agent/extensions/goal/index.ts",
        ".pi/agent/extensions/goal/state.ts",
      ].map((path) => resolve(path)),
    }),
  );
  execFileSync("tsc", ["-p", config], { stdio: "inherit" });
} finally {
  rmSync(directory, { recursive: true, force: true });
}
