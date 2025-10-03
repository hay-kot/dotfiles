My Dotfiles.

## Setup

Run `./files/bootstrap.sh` to install pre-reqs and then use the `Taskfile.yml` to run any other setup commands

```sh
chmod +x ./files/bootstrap.sh
./files/bootstrap.sh
```

```sh
task setup # initialize setup
task run -- personal # mmdot personal group
```
