# TypeScript review notes

- Prefer `unknown` over `any`; flag `any` that erases a real type, but generated/`.d.ts`
  and truly dynamic boundaries are acceptable.
- Async: unawaited promises, missing `await` in try/catch, floating promises in effects.
  Don't flag intentionally fire-and-forget calls that are commented as such.
- Null safety: optional chaining / nullish coalescing where values can be undefined;
  non-null assertions (`!`) that hide a real nullable.
- React (if present): missing/incorrect hook deps, state updates in render, keys on lists,
  effects without cleanup. Don't flag deps a lint rule would already own unless the diff
  disables the rule.
- Not-a-bug: type-only imports, `satisfies` usage, framework-required prop shapes.
