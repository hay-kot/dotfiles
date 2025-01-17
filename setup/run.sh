#!/bin/bash

set -e

script_dir=$(cd $(dirname "$BASH_SOURCE[0]}") && pwd)
filters=()
dry="0"

center_text() {
  local task="TASK"
  local string=" [$1] "       # Add brackets around the input string
  local width=$(tput cols)    # Get terminal width
  local prefix="${task}${string}"
  local prefix_length=${#prefix}
  local total_length=$((width - prefix_length))
  local dashes_length=$((total_length > 0 ? total_length : 0)) # Prevent negative lengths

  # Generate the dashes
  local dashes=$(printf "%*s" $dashes_length | tr ' ' '-')

  # Print the final output
  echo "${prefix}${dashes}"
}

# Function to display help text
show_help() {
  echo "Usage: $(basename "$0") [OPTIONS] [FILTER...]"
  echo ""
  echo "This script executes all scripts located in the 'runs' directory. It supports filtering"
  echo "scripts based on one or more substrings and a 'dry run' mode to simulate execution without making changes."
  echo ""
  echo "Positional Arguments:"
  echo "  FILTER           One or more substrings to filter which scripts to execute. Only scripts containing"
  echo "                   at least one of the FILTER substrings in their names will be executed. If no FILTER"
  echo "                   is provided, all scripts in the 'runs' directory will be considered."
  echo ""
  echo "Options:"
  echo "  --help           Show this help message and exit."
  echo "  --dry            Run the script in dry-run mode. No actual scripts will be executed."
  echo "                   Instead, actions will be printed to the console prefixed with '[DRY_RUN]'."
  echo ""
  echo "Examples:"
  echo "  $(basename "$0")"
  echo "      Run all scripts in the 'runs' directory."
  echo ""
  echo "  $(basename "$0") test deploy"
  echo "      Run scripts that contain the words 'test' or 'deploy' in their names."
  echo ""
  echo "  $(basename "$0") --dry test deploy"
  echo "      Simulate the execution of scripts containing the words 'test' or 'deploy'."
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --dry)
      dry="1"
      ;;
    *)
      filters+=("$1")
      ;;
  esac
  shift
done

log() {
  if [[ $dry == "1" ]]; then
    echo "[DRY_RUN]: $@"
  else
    echo "$@"
  fi
}

execute() {
  # Usage
  center_text "$@"
  echo ""
  if [[ $dry == "1" ]]; then
    echo "Dry..."
    echo ""
    return
  else
    "$@"
    echo ""
  fi
}

echo "$script_dir" -- "${filters[*]}"

cd "$script_dir"

scripts=$(find ./runs -maxdepth 1 -mindepth 1 -type f)

for script in $scripts; do
  match="0"
  for filter in "${filters[@]}"; do
    if echo "$script" | grep -q "$filter"; then
      match="1"
      break
    fi
  done

  if [[ "$match" == "0" ]]; then
    log "filter $script"
    continue
  fi


  execute ./"$script"
done


