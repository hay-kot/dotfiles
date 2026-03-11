package cmd

import (
	"fmt"
	"os"
	"sort"
)

type subcommand struct {
	desc string
	run  func(args []string) error
}

var commands = map[string]subcommand{
	"run": {
		desc: "Scan vault, dispatch work items, generate pipeline dashboard",
		run:  runRun,
	},
	"status": {
		desc: "Print pipeline state without dispatching",
		run:  runStatus,
	},
}

// Execute parses args and runs the appropriate subcommand.
func Execute() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	name := os.Args[1]
	if name == "help" || name == "-h" || name == "--help" {
		printUsage()
		return
	}

	cmd, ok := commands[name]
	if !ok {
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", name)
		printUsage()
		os.Exit(1)
	}

	if err := cmd.run(os.Args[2:]); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Fprintln(os.Stderr, "psweep - automated project pipeline CLI")
	fmt.Fprintln(os.Stderr)
	fmt.Fprintln(os.Stderr, "Commands:")

	names := make([]string, 0, len(commands))
	for name := range commands {
		names = append(names, name)
	}
	sort.Strings(names)

	for _, name := range names {
		fmt.Fprintf(os.Stderr, "  %-12s %s\n", name, commands[name].desc)
	}
}
