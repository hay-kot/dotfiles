# Go review notes

- Errors: expect `fmt.Errorf("context: %w", err)`; flag dropped errors, but `_ =` on
  genuinely ignorable returns (e.g. `w.Write` in some handlers) is idiomatic — don't over-flag.
- `defer resp.Body.Close()` immediately after the nil-error check.
- Concurrency: unsynchronized map access, goroutines with no lifecycle owner, channels not
  closed by the sender. Suggest `testing/synctest` over `time.Sleep` in tests (Go 1.24+).
- Dead code: for larger changes, `deadcode -test ./...` can confirm orphaned functions —
  treat exported symbols as possible external API, not automatic dead code.
- Not-a-bug: unused struct fields set via reflection/JSON tags; interface-satisfying methods
  that look unused; `context.Context` passed but unused in a stub. Verify before flagging.
