---
name: go
description: >
  Best practices for working with Go codebases. Use when writing, debugging,
  or exploring Go code, including reading dependency sources and documentation.
allowed-tools: "Read,Bash(go:*)"
---

# Go Programming Language

Guidelines for working effectively with Go projects.

## Code Style

- Concrete types over `interface{}`/`any` — interfaces hide bugs.
- Channels for synchronization, not `time.Sleep()`.
- Early returns to reduce nesting.
- Wrap errors with `fmt.Errorf("context: %w", err)` to preserve chains.
- Table tests for complex logic.
- Godoc all exported symbols.

## Reading Dependency Source Files

To see source files from a dependency, or to answer questions about a dependency:

```bash
go mod download -json MODULE
```

Use the returned Dir path to read the source files.

## Reading Documentation

Use go doc to read documentation for packages, types, functions, etc:

```bash
go doc foo.Bar       # Documentation for a specific symbol
go doc -all foo      # All documentation for a package
```

## Running Programs

Use go run instead of go build to avoid leaving behind build artifacts:

```bash
go run .             # Run the current package
go run ./cmd/foo     # Run a specific command
```
