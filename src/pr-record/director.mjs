// Cursor and capture for scripted recordings of a web app.
//
// Headless Chromium draws no pointer, and Playwright's built-in recordVideo is
// low-bitrate VP8, so the Director paints a cursor into the page and the
// Screencast keeps each CDP frame as a JPEG with its real timestamp, then
// encodes H.264.
import { execFileSync } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const CURSOR_CSS = `
  #__cursor { position: fixed; left: 0; top: 0; width: 28px; height: 28px; z-index: 2147483647; pointer-events: none; will-change: transform; filter: drop-shadow(0 1px 2px rgba(0,0,0,.4)); }
  #__cursor svg { width: 100%; height: 100%; transition: transform 120ms ease-out; transform-origin: 4px 2px; }
  #__cursor.down svg { transform: scale(.82); }
  .__ripple { position: fixed; z-index: 2147483646; pointer-events: none; width: 40px; height: 40px; margin: -20px 0 0 -20px; border-radius: 50%; border: 3px solid rgba(239,68,68,.9); background: rgba(239,68,68,.2); animation: __ripple 550ms ease-out forwards; }
  @keyframes __ripple { from { transform: scale(.4); opacity: 1 } to { transform: scale(1.5); opacity: 0 } }
  html { scroll-behavior: auto !important; }
`;

const pageSetup = (hide) => {
  const css =
    (hide.length ? `${hide.join(", ")} { display: none !important; }\n` : "") +
    CURSOR_CSS;
  return `(() => {
  const install = () => {
    if (document.getElementById('__cursorstyle')) return;
    const style = document.createElement('style');
    style.id = '__cursorstyle';
    style.textContent = ${JSON.stringify(css)};
    document.documentElement.appendChild(style);
    const c = document.createElement('div');
    c.id = '__cursor';
    c.innerHTML = '<svg viewBox="0 0 24 24"><path d="M4.5 2.5v17.2l4.9-4.6 3.1 7 3-1.3-3.1-6.9h6.7z" fill="#111" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/></svg>';
    c.style.transform = 'translate(' + (window.__cx ?? -100) + 'px,' + (window.__cy ?? -100) + 'px)';
    document.documentElement.appendChild(c);
  };
  window.__cursorAt = (x, y) => {
    window.__cx = x; window.__cy = y;
    const c = document.getElementById('__cursor');
    if (c) c.style.transform = 'translate(' + (x - 4) + 'px,' + (y - 2) + 'px)';
  };
  window.__cursorDown = (down) => {
    document.getElementById('__cursor')?.classList.toggle('down', down);
    if (!down) return;
    const r = document.createElement('div');
    r.className = '__ripple';
    r.style.left = window.__cx + 'px';
    r.style.top = window.__cy + 'px';
    document.documentElement.appendChild(r);
    setTimeout(() => r.remove(), 600);
  };
  if (document.documentElement) install();
  document.addEventListener('DOMContentLoaded', install);
})();`;
};

const ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Moves a visible cursor and the real mouse together, so hovers still fire. */
export class Director {
  /** hide lists CSS selectors to hide in every frame, such as a dev toolbar. */
  constructor(page, { hide = [] } = {}) {
    this.page = page;
    this.script = pageSetup(hide);
    const { width, height } = page.viewportSize();
    this.x = width / 2;
    this.y = height / 2;
  }

  async setup() {
    await this.page.addInitScript(this.script);
    await this.page.evaluate(this.script);
    await this.page.mouse.move(this.x, this.y);
    await this.ensureCursor();
  }

  /** A full page load runs the init script again but loses the position. */
  async ensureCursor() {
    await this.page.evaluate(
      ([x, y]) => window.__cursorAt?.(x, y),
      [this.x, this.y],
    );
  }

  async glide(x, y, ms) {
    const dist = Math.hypot(x - this.x, y - this.y);
    const dur = ms ?? Math.max(380, Math.min(1100, 350 + dist * 0.9));
    const [sx, sy] = [this.x, this.y];
    const t0 = Date.now();
    for (;;) {
      const t = Math.min(1, (Date.now() - t0) / dur);
      const e = ease(t);
      const nx = sx + (x - sx) * e;
      const ny = sy + (y - sy) * e;
      await Promise.all([
        this.page.mouse.move(nx, ny),
        this.page.evaluate(([a, b]) => window.__cursorAt?.(a, b), [nx, ny]),
      ]);
      if (t >= 1) break;
      await sleep(8);
    }
    this.x = x;
    this.y = y;
  }

  async center(locator) {
    await locator.waitFor({ state: "visible", timeout: 30000 });
    await locator.scrollIntoViewIfNeeded();
    const b = await locator.boundingBox();
    return [b.x + b.width / 2, b.y + b.height / 2];
  }

  async hover(locator, ms) {
    const [x, y] = await this.center(locator);
    await this.glide(x, y, ms);
    await sleep(150);
  }

  async click(locator, ms) {
    await this.hover(locator, ms);
    await this.page.evaluate(() => window.__cursorDown?.(true));
    await this.page.mouse.down();
    await sleep(80);
    await this.page.mouse.up();
    await this.page.evaluate(() => window.__cursorDown?.(false));
  }

  async type(text, delay = 70) {
    await this.page.keyboard.type(text, { delay });
  }

  /** Eased scroll of a scroll container, the window by default. */
  async scrollTo(top, ms = 900, selector) {
    await this.page.evaluate(
      ([top, ms, selector]) =>
        new Promise((done) => {
          const el = selector
            ? document.querySelector(selector)
            : document.scrollingElement;
          const start = el.scrollTop;
          const t0 = performance.now();
          const inOut = (t) =>
            t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2;
          const step = (now) => {
            const t = Math.min(1, (now - t0) / ms);
            el.scrollTop = start + (top - start) * inOut(t);
            t < 1 ? requestAnimationFrame(step) : done();
          };
          requestAnimationFrame(step);
        }),
      [top, ms, selector ?? null],
    );
  }

  /** Network idle and every image loaded, so the next frame is not half drawn. */
  async settled() {
    await this.page.waitForLoadState("networkidle").catch(() => {});
    await this.page.evaluate(() =>
      Promise.all(
        [...document.images]
          .filter((i) => !i.complete)
          .map(
            (i) =>
              new Promise((r) => {
                i.onload = i.onerror = r;
              }),
          ),
      ),
    );
  }

  sleep(ms) {
    return sleep(ms);
  }
}

export class Screencast {
  constructor(page, dir) {
    this.page = page;
    this.dir = dir;
    this.frames = [];
  }

  async start() {
    rmSync(this.dir, { recursive: true, force: true });
    mkdirSync(this.dir, { recursive: true });
    const { width, height } = this.page.viewportSize();
    this.cdp = await this.page.context().newCDPSession(this.page);
    this.cdp.on(
      "Page.screencastFrame",
      async ({ data, metadata, sessionId }) => {
        const file = join(
          this.dir,
          `${String(this.frames.length).padStart(6, "0")}.jpg`,
        );
        this.frames.push({ file, t: metadata.timestamp });
        writeFileSync(file, Buffer.from(data, "base64"));
        await this.cdp
          .send("Page.screencastFrameAck", { sessionId })
          .catch(() => {});
      },
    );
    await this.cdp.send("Page.startScreencast", {
      format: "jpeg",
      quality: 92,
      maxWidth: width * 2,
      maxHeight: height * 2,
      everyNthFrame: 1,
    });
  }

  async stop() {
    await this.cdp.send("Page.stopScreencast");
    await sleep(100);
    if (this.frames.length < 2)
      throw new Error("the screencast captured fewer than 2 frames");
  }

  /**
   * Chromium sends a frame only when the page repaints, so each frame lasts
   * until the next one's timestamp and idle stretches cost nothing.
   */
  encode({ mp4, poster, width, posterAt, endHold = 0.6 }) {
    const f = this.frames;
    const lines = [];
    for (let i = 0; i < f.length; i++) {
      const next = i + 1 < f.length ? f[i + 1].t : f[i].t + endHold;
      lines.push(
        `file '${f[i].file}'`,
        `duration ${Math.max(0.001, next - f[i].t).toFixed(4)}`,
      );
    }
    lines.push(`file '${f.at(-1).file}'`);
    const list = join(this.dir, "list.txt");
    writeFileSync(list, lines.join("\n"));
    execFileSync("ffmpeg", [
      "-y",
      "-loglevel",
      "error",
      "-f",
      "concat",
      "-safe",
      "0",
      "-i",
      list,
      "-vf",
      `fps=30,scale=${width}:-2:flags=lanczos,format=yuv420p`,
      "-c:v",
      "libx264",
      "-preset",
      "slow",
      "-crf",
      process.env.RECORD_CRF ?? "23",
      "-movflags",
      "+faststart",
      "-an",
      mp4,
    ]);
    const total = f.at(-1).t + endHold - f[0].t;
    const at = posterAt ?? total / 2;
    execFileSync("ffmpeg", [
      "-y",
      "-loglevel",
      "error",
      "-ss",
      String(Math.min(at, total - 0.1)),
      "-i",
      mp4,
      "-frames:v",
      "1",
      "-q:v",
      "3",
      poster,
    ]);
    rmSync(this.dir, { recursive: true, force: true });
    return { total, frames: f.length };
  }
}
