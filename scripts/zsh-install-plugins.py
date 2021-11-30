#! /usr/bin/python3

import subprocess
from dataclasses import dataclass
from pathlib import Path

CWD = Path(__file__).parent

@dataclass
class Plugin:
    name: str
    url: str

HOME = Path.home()

PLUGIN_DIR = HOME / ".oh-my-zsh/plugins"
CUSTOM = HOME / ".oh-my-zsh" / "custom"

plugins = [
    Plugin("zsh-completions", "https://github.com/zsh-users/zsh-completions"),
    Plugin("zsh-autosuggestions", "https://github.com/zsh-users/zsh-autosuggestions"),
]


def clone_plungin(plugin: Plugin):
    plugin_dest = f"{CUSTOM}/plugins/{plugin.name}"
    print(plugin_dest)
    print("Cloning plugin: {}".format(plugin))
    subprocess.run(["git", "clone", plugin.url, plugin_dest], stdout=subprocess.PIPE)


def main():
    print("Starting...")

    # Ensure Directory Exists
    if not PLUGIN_DIR.exists():
        print(f"Creating {PLUGIN_DIR}")
        PLUGIN_DIR.mkdir(parents=True)

    for plugin in plugins:
        clone_plungin(plugin)

    # Poetry Plugin CLI Command -> poetry completions zsh > $ZSH_CUSTOM/plugins/poetry/_poetry
    PLUGIN_DIR.joinpath("poetry").mkdir(parents=True, exist_ok=True)
    subprocess.run(["poetry", "completions", "zsh"], cwd=PLUGIN_DIR.joinpath("poetry"))

    print("Finished...")


if __name__ == "__main__":
    main()
