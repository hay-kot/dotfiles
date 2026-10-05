// winctl places app windows at fractional positions on screen. Raycast script
// commands call it from hotkeys, so it runs and exits instead of staying
// resident; the Accessibility grant it relies on is the calling app's.

import AppKit
import ApplicationServices

let usage = """
  usage: winctl summon <bundle-id> <x,y,w,h>
         winctl split <left-bundle-id> <right-bundle-id> <ratio,...>

    summon  Open the app and place its window on the main screen. If the app
            is already in front and in place, hide it instead.
    split   Put two apps side by side on the main screen, the left one taking
            the first ratio of the width. If both are already split at one of
            the ratios, step to the next ratio instead.

  Positions are fractions of the screen's usable area, as decimals or a/b,
  for example 0.2,0.03,0.6,0.94 or 1/6,0,2/3,1.
  """

enum WinctlError: Error {
  case usage(String)
  case failed(String)
}

func parseFraction(_ text: String) throws -> Double {
  let pieces = text.split(separator: "/", omittingEmptySubsequences: false)
  let numbers = pieces.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
  let value: Double
  switch (pieces.count, numbers.count) {
  case (1, 1): value = numbers[0]
  case (2, 2) where numbers[1] != 0: value = numbers[0] / numbers[1]
  default: throw WinctlError.usage("bad fraction \(text)")
  }
  guard (0...1).contains(value) else {
    throw WinctlError.usage("fraction \(text) is outside 0-1")
  }
  return value
}

func parseRatios(_ spec: String) throws -> [Double] {
  let ratios = try spec.split(separator: ",").map { try parseFraction(String($0)) }
  guard !ratios.isEmpty, ratios.allSatisfy({ $0 > 0 && $0 < 1 }) else {
    throw WinctlError.usage("bad ratios \(spec): want fractions between 0 and 1")
  }
  return ratios
}

struct UnitRect {
  let x: Double
  let y: Double
  let width: Double
  let height: Double

  func frame(in area: CGRect) -> CGRect {
    CGRect(
      x: (area.minX + x * area.width).rounded(),
      y: (area.minY + y * area.height).rounded(),
      width: (width * area.width).rounded(),
      height: (height * area.height).rounded())
  }
}

extension UnitRect {
  init(parsing spec: String) throws {
    let parts = spec.split(separator: ",").map { try? parseFraction(String($0)) }
    guard parts.count == 4, let x = parts[0], let y = parts[1], let w = parts[2], let h = parts[3]
    else { throw WinctlError.usage("bad position \(spec): want four fractions x,y,w,h") }
    // Tolerance for float sums like 1/3 + 2/3.
    guard x + w <= 1.0001, y + h <= 1.0001, w > 0, h > 0
    else { throw WinctlError.usage("bad position \(spec): window must fit on the screen") }
    self.init(x: x, y: y, width: w, height: h)
  }
}

// MARK: - Screens

// NSScreen frames have a bottom-left origin; AX positions are top-left, anchored
// at the primary screen's top edge.
func usableArea(of screen: NSScreen) -> CGRect {
  let primaryHeight = NSScreen.screens[0].frame.height
  let visible = screen.visibleFrame
  return CGRect(
    x: visible.minX, y: primaryHeight - visible.maxY, width: visible.width, height: visible.height)
}

// MARK: - Accessibility

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
    return nil
  }
  return value
}

func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
  guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
    return nil
  }
  return (value as! AXUIElement)
}

func primaryWindow(of app: AXUIElement) -> AXUIElement? {
  if let window = elementAttribute(app, kAXFocusedWindowAttribute) { return window }
  if let window = elementAttribute(app, kAXMainWindowAttribute) { return window }
  let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
  return windows.first {
    attribute($0, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole
  }
}

func frame(of window: AXUIElement) -> CGRect? {
  guard let position = attribute(window, kAXPositionAttribute),
    let size = attribute(window, kAXSizeAttribute)
  else { return nil }
  var origin = CGPoint.zero
  var dimensions = CGSize.zero
  guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
    AXValueGetValue(size as! AXValue, .cgSize, &dimensions)
  else { return nil }
  return CGRect(origin: origin, size: dimensions)
}

// Apps round or clamp a requested size by a few points, so an exact match
// would never count as in place for some of them.
func roughlyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
  let tolerance: CGFloat = 8
  return abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
    && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
}

func setPosition(_ window: AXUIElement, _ origin: CGPoint) {
  var origin = origin
  let value = AXValueCreate(.cgPoint, &origin)!
  AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
}

func setSize(_ window: AXUIElement, _ size: CGSize) {
  var size = size
  let value = AXValueCreate(.cgSize, &size)!
  AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
}

struct Move {
  let app: AXUIElement
  let window: AXUIElement
  let target: CGRect
}

// macOS has no animated move for another app's window, so a slide is a run of
// small AX moves, one per refresh of the 120Hz main display.
let slideDuration: TimeInterval = 0.12
let slideStepInterval: TimeInterval = 1.0 / 120

func interpolate(_ from: CGRect, _ to: CGRect, _ progress: Double) -> CGRect {
  func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { (a + (b - a) * progress).rounded() }
  return CGRect(
    x: mix(from.minX, to.minX), y: mix(from.minY, to.minY),
    width: mix(from.width, to.width), height: mix(from.height, to.height))
}

// Ease-in-out: an ease-out curve covers a quarter of the distance in its first
// step, which reads as a jump.
func easeInOut(_ t: Double) -> Double {
  t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
}

func setFrames(_ moves: [Move]) {
  // While AXEnhancedUserInterface is on, Zen ignores AX moves but still
  // applies resizes (Chromium and Electron apps misbehave similarly).
  // Activating an app switches it back on, and the apps being opened activate
  // mid-slide, so it goes off again before every step.
  let enhancedUI = "AXEnhancedUserInterface"
  let apps = moves.map(\.app)
  let enhancedApps = apps.filter { attribute($0, enhancedUI) as? Bool == true }
  let disableEnhancedUI = {
    for app in apps { AXUIElementSetAttributeValue(app, enhancedUI as CFString, kCFBooleanFalse) }
  }
  defer {
    for app in enhancedApps {
      AXUIElementSetAttributeValue(app, enhancedUI as CFString, kCFBooleanTrue)
    }
  }

  for move in moves where attribute(move.window, kAXMinimizedAttribute) as? Bool == true {
    AXUIElementSetAttributeValue(move.window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
  }

  let starts = moves.map { frame(of: $0.window) }
  let slides = zip(moves, starts).compactMap { move, start in
    start.flatMap { roughlyEqual($0, move.target) ? nil : (move.window, $0, move.target) }
  }
  let begin = Date()
  while !slides.isEmpty {
    // Sleep to the next tick, skipping any that a slow app made us miss.
    let elapsed = Date().timeIntervalSince(begin)
    let nextTick = (floor(elapsed / slideStepInterval) + 1) * slideStepInterval
    Thread.sleep(until: begin.addingTimeInterval(nextTick))
    let progress = Date().timeIntervalSince(begin) / slideDuration
    if progress >= 1 { break }
    disableEnhancedUI()
    for (window, start, target) in slides {
      let step = interpolate(start, target, easeInOut(progress))
      setPosition(window, step.origin)
      setSize(window, step.size)
    }
  }

  disableEnhancedUI()
  for move in moves { land(move.window, at: move.target) }
}

// Size goes on both sides of the move: a resize that would run past the screen
// edge from where the window is now, including on another screen, gets
// clamped to fit.
func land(_ window: AXUIElement, at target: CGRect) {
  setSize(window, target.size)
  setPosition(window, target.origin)
  setSize(window, target.size)
}

// MARK: - Apps

// `open -b` instead of NSRunningApplication.activate: since macOS 14 a
// background process cannot reliably take focus for another app, and `open`
// also launches the app or reopens its window when none is showing. Each one
// takes about 60ms, so they run alongside the slide instead of before it.
struct Opening {
  let bundleIDs: [String]
  let process = Process()

  // Opens the apps in order, so the last one ends up focused.
  init(_ bundleIDs: [String]) throws {
    for id in bundleIDs where NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) == nil
    {
      throw WinctlError.failed("cannot open \(id): not installed")
    }
    self.bundleIDs = bundleIDs
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments =
      ["-c", "for id; do /usr/bin/open -b \"$id\" || exit 1; done", "sh"] + bundleIDs
    try process.run()
  }

  func finish() throws {
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw WinctlError.failed("cannot open \(bundleIDs.joined(separator: ", "))")
    }
  }
}

func waitForWindow(of bundleID: String, timeout: TimeInterval) -> (AXUIElement, AXUIElement)? {
  let deadline = Date().addingTimeInterval(timeout)
  repeat {
    if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    {
      let app = AXUIElementCreateApplication(running.processIdentifier)
      if let window = primaryWindow(of: app) { return (app, window) }
    }
    Thread.sleep(forTimeInterval: 0.05)
  } while Date() < deadline
  return nil
}

// MARK: - Commands

func summon(_ bundleID: String, at unit: UnitRect) throws {
  let target = unit.frame(in: usableArea(of: NSScreen.screens[0]))
  if let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier == bundleID {
    let app = AXUIElementCreateApplication(front.processIdentifier)
    if let window = primaryWindow(of: app) {
      if let current = frame(of: window), roughlyEqual(current, target) {
        front.hide()
      } else {
        setFrames([Move(app: app, window: window, target: target)])
      }
      return
    }
  }
  let opening = try Opening([bundleID])
  guard let (app, window) = waitForWindow(of: bundleID, timeout: 5) else {
    throw WinctlError.failed("\(bundleID) has no window to place")
  }
  setFrames([Move(app: app, window: window, target: target)])
  try opening.finish()
}

func split(_ leftID: String, _ rightID: String, ratios: [Double]) throws {
  let area = usableArea(of: NSScreen.screens[0])
  let leftFrame = { (ratio: Double) in UnitRect(x: 0, y: 0, width: ratio, height: 1).frame(in: area)
  }
  let rightFrame = { (ratio: Double) in
    UnitRect(x: ratio, y: 0, width: 1 - ratio, height: 1).frame(in: area)
  }

  // Opened last ends up focused: keep focus on whichever of the pair had it.
  let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
  let focusID = frontID == rightID ? rightID : leftID
  let opening = try Opening([leftID, rightID].filter { $0 != focusID } + [focusID])
  guard let (leftApp, leftWindow) = waitForWindow(of: leftID, timeout: 5) else {
    throw WinctlError.failed("\(leftID) has no window to place")
  }
  guard let (rightApp, rightWindow) = waitForWindow(of: rightID, timeout: 5) else {
    throw WinctlError.failed("\(rightID) has no window to place")
  }

  // The current ratio is read back from the windows, so nothing is stored
  // between runs. A press only steps to the next ratio when both windows are
  // in place; otherwise it restores the left window's ratio, or the first
  // ratio when the left window matches none.
  var ratio = ratios[0]
  if let current = frame(of: leftWindow),
    let index = ratios.firstIndex(where: { roughlyEqual(current, leftFrame($0)) })
  {
    let rightInPlace = frame(of: rightWindow).map { roughlyEqual($0, rightFrame(ratios[index])) }
    ratio = rightInPlace == true ? ratios[(index + 1) % ratios.count] : ratios[index]
  }
  setFrames([
    Move(app: leftApp, window: leftWindow, target: leftFrame(ratio)),
    Move(app: rightApp, window: rightWindow, target: rightFrame(ratio)),
  ])
  try opening.finish()
}

// Overlapping presses would slide the same window toward two targets and leave
// it stuck between them, so runs take turns. The lock is released on exit.
func waitForTurn() {
  let lock = open(NSTemporaryDirectory() + "winctl.lock", O_CREAT | O_RDWR, 0o600)
  if lock >= 0 { flock(lock, LOCK_EX) }
}

func run(_ args: [String]) throws {
  guard let command = args.first else { throw WinctlError.usage(usage) }
  guard AXIsProcessTrusted() else {
    throw WinctlError.failed(
      "no Accessibility permission: grant it to the app that runs winctl (Raycast or your terminal)"
    )
  }
  waitForTurn()
  switch (command, args.count) {
  case ("summon", 3): try summon(args[1], at: UnitRect(parsing: args[2]))
  case ("split", 4): try split(args[1], args[2], ratios: parseRatios(args[3]))
  default: throw WinctlError.usage(usage)
  }
}

do {
  try run(Array(CommandLine.arguments.dropFirst()))
} catch WinctlError.usage(let message) {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(2)
} catch WinctlError.failed(let message) {
  FileHandle.standardError.write(Data(("winctl: " + message + "\n").utf8))
  exit(1)
} catch {
  FileHandle.standardError.write(Data("winctl: \(error)\n".utf8))
  exit(1)
}
