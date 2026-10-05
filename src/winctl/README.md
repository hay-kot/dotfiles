# winctl

Hotkey-driven window placement for macOS. A Raycast hotkey runs a small
script, the script calls `winctl`, and `winctl` moves windows through the
Accessibility API and exits. Nothing new stays running in the background.

## What it is for

A handful of fixed desktop workflows, each on one hotkey, with the setup kept
as code in this repo. The main screen is a 32" monitor, so nothing goes full
screen.

1. Pop Slack up centered over everything, reply, put it away.
2. Browser on the left, Hive on the right, swapping between 36/64 and 60/40.
   The sides never change, only the ratio.
3. Bring the browser to the center of the screen (about the middle
   two-thirds).
4. During a meeting, put the meeting on the right and the browser or another
   app on the left.
5. Send something like YouTube to the secondary screen (a portrait 27"
   monitor, or the laptop).
6. Pop Obsidian up centered for a moment, then put it away.

Built so far: 1, 2, 3, and 6. See [Not built yet](#not-built-yet) for the rest.

## How it fits together

```
Raycast hotkey
  -> ~/.config/raycast/scripts/<name>.sh   (from .config/raycast/scripts/)
    -> ~/.local/bin/winctl <command> ...   (built from src/winctl/main.swift)
      -> Accessibility API: open and hide apps, read and set window frames
```

| Piece   | Lives in                       | Notes                                                                                                                         |
| ------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| Source  | `src/winctl/main.swift`        | One file, no dependencies.                                                                                                    |
| Build   | `mise run winctl`              | Task in `mise.dev.toml`. Compiles into `~/.local/bin/winctl`. Not part of `dotsync`, so run it after source changes and on a new Mac. |
| Scripts | `.config/raycast/scripts/`     | Raycast Script Commands. They call winctl by absolute path because Raycast does not run them with the login shell's PATH.    |
| Hotkeys | Raycast settings               | Not in the repo. Raycast keeps hotkeys in its own encrypted settings.                                                        |

## Commands

`winctl summon <bundle-id> <x,y,w,h>`

- App not in front: open it (launching it if needed) and place its window.
- In front but out of place: move it back.
- In front and in place: hide the app. macOS returns focus to the previous
  app.

`winctl split <left-bundle-id> <right-bundle-id> <ratio,...>`

- Opens both apps. The left one gets the first ratio of the screen width, the
  right one gets the rest.
- Both already split at one of the ratios: step to the next ratio.
- Either window out of place: restore the left window's current ratio, or the
  first ratio if it matches none, without stepping.
- Focus stays on whichever of the two had it. Otherwise the left app gets it.

Positions and ratios are fractions of the screen's usable area (menu bar and
Dock excluded), as decimals or `a/b`. `x,y,w,h` is measured from the top-left
corner. To center a window of width `w`, use `x = (1 - w) / 2`.

Every command targets the main screen, the one with the menu bar.

Exit codes: 0 success, 1 runtime failure, 2 bad arguments. Errors go to
stderr; the scripts redirect it to stdout so Raycast shows the message in its
HUD.

## Current scripts

| Script              | Runs                                                       | Notes                                                                    |
| ------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------ |
| `obsidian-peek.sh`  | `summon md.obsidian 0.225,0.03,0.55,0.94`                  |                                                                          |
| `slack-peek.sh`     | `summon com.tinyspeck.slackmacgap 0.225,0.03,0.55,0.94`    | Slack is only on the work Mac. Elsewhere it fails with "cannot open".   |
| `zen-hive-split.sh` | `split app.zen-browser.zen com.hivedesktop.app 0.36,0.6`   | Zen left, Hive right. Hive gets 64% first, then 40%.                     |
| `zen-center.sh`     | `summon app.zen-browser.zen 1/6,0.03,2/3,0.94`             | Middle two-thirds. A press while it is in place hides Zen.               |

Find an app's bundle ID with `osascript -e 'id of app "Obsidian"'`.

## Setting up a Mac

1. `mise run winctl` to build.
2. `mise bootstrap dotfiles apply` to link the scripts into
   `~/.config/raycast/scripts`.
3. Raycast Settings > Extensions > Script Commands > Add Directories, and pick
   `~/.config/raycast/scripts` (cmd+shift+G in the file picker to type the
   path).
4. For each command: find it in Raycast, cmd+K > Configure Command > Record
   Hotkey. Rectangle Pro only uses ctrl+opt+cmd with the arrow keys, so
   ctrl+opt+cmd plus a letter is free.
5. Raycast needs Accessibility permission (System Settings > Privacy &
   Security > Accessibility). winctl uses Raycast's grant.

## Design decisions

These came out of comparing the alternatives. Keep them unless the reason no
longer holds.

- **No resident process.** Hammerspoon could do all of this in Lua, but it is
  one more always-running app. Raycast already runs and owns global hotkeys,
  so it is the hotkey layer, and winctl only runs per press.
- **Not Rectangle Pro layouts.** Rectangle Pro stays installed for drag-to-snap
  and the ctrl+opt halves and thirds. Its Layouts could cover most of these
  workflows, but the config is GUI-only: export and import is a manual JSON
  blob with numeric action IDs and pixel coordinates, and nothing loads it
  from a file.
- **Not a Raycast extension.** Raycast's Window Management API needs Raycast
  Pro, which this account does not have.
- **The caller's Accessibility grant.** macOS attributes winctl's
  Accessibility use to the app that launched it: Raycast for hotkeys, the
  terminal when run by hand. Rebuilding winctl does not need a new grant.
- **`open -b` to launch and focus.** Since macOS 14, a background process
  cannot reliably bring another app forward with
  `NSRunningApplication.activate`. `open -b` also launches the app, or
  reopens a window when none is showing. Each call takes about 60ms, so it
  runs alongside the slide instead of before it. The split opens both apps
  from one shell, in order, so the right app ends up focused.
- **Coordinate conversion.** `NSScreen` frames have a bottom-left origin. AX
  positions are top-left, anchored at the primary screen's top edge.
  `usableArea(of:)` converts between them.
- **Slide, then land.** macOS has no animated move for another app's window,
  so a slide is a run of small AX moves: 0.12s, one step per refresh of the
  120Hz main display, eased in and out (an ease-out curve covers a quarter of
  the distance in its first step and reads as a jump). Steps are timed against
  the clock, so a slow app drops steps instead of stretching the slide. The
  constants are at the top of the slide code in `main.swift`.
- **Size, then position, then size again, when landing.** A resize that would
  run past the screen edge from where the window currently is gets clamped to
  fit, so the size goes on both sides of the move.
- **`AXEnhancedUserInterface` off before every step.** While it is on, Zen
  ignores AX moves but still applies resizes, so the window ends up stuck
  partway with its height clamped. Activating an app switches it back on, and
  `open -b` activates apps mid-slide, so turning it off once at the start is
  not enough. Measured on Zen; Chromium and Electron apps have similar
  problems. The original value comes back after the move.
- **Runs take turns.** Each run holds a lock file (`$TMPDIR/winctl.lock`).
  Without it, two quick presses slide the same window toward two targets and
  leave it between them. With it, a double press of the split swaps twice.
- **8-point tolerance for "in place".** Apps round or clamp a requested size,
  so with exact matching "hide when in place" would never fire for some apps.
- **No stored state.** `split` reads the current ratio back from the windows
  instead of remembering it, so moving windows by hand never confuses it.

## Adding a workflow

- An existing command fits: copy a script in `.config/raycast/scripts/`, keep
  `@raycast.packageName Windows` and `@raycast.mode silent`, run
  `mise bootstrap dotfiles apply`, then assign a hotkey in Raycast.
- It needs new behavior: add a command function in `main.swift`, add it to
  `run()` and the usage text, then run `swift format -i src/winctl/main.swift`,
  `swift format lint src/winctl/main.swift`, and `mise run winctl`.

## Testing

There are no automated tests, because the behavior depends on live windows.
Test by hand from a terminal that has Accessibility permission.

- Run a script the way Raycast does:
  `env -i HOME="$HOME" /bin/bash ~/.config/raycast/scripts/<name>.sh`
- Read a window's frame:
  `osascript -e 'tell application "System Events" to get {position, size} of window 1 of process "Obsidian"'`
  Process names can differ from app names: Hive is `hive-desktop`, Zen is
  `zen`.
- Tests move and hide the user's real windows. Say so before running them,
  and expect the user to be clicking around at the same time.

## Not built yet

Rough plans for the remaining workflows:

- **4, meeting on the right.** A `pair` command: the frontmost window to the
  right third, the window behind it (next in `CGWindowListCopyWindowInfo`
  order) to the left two-thirds. That works for Zoom and for a meeting in its
  own browser window.
- **5, side screen.** A `throw` command that moves the focused window to the
  other screen: the top half on the portrait monitor, the full screen on the
  laptop.
