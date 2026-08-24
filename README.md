# dotfiles-lite

Small, reversible dotfiles for Debian and Ubuntu servers. The repository keeps
the terminal habits from the main dotfiles without desktop applications,
workstation paths, private material or large plugin trees.

## What is included

- Zsh with history, completion, a safe UTF-8 fallback, conditional aliases and
  a native Nord-style prompt showing Git state, command duration, exit status
  and hostname.
- Git defaults and aliases, with no identity or signing policy.
- tmux with `Ctrl+q`, Vi copy mode, mouse support, Vim-aware pane movement and
  plugin-free Nord light/dark themes matching the main dotfiles.
- A plugin-free Neovim configuration in the `server` profile.
- Stable forwarded SSH-agent sockets for long-lived tmux sessions.

No SSH keys, Git identity, tokens or files from private dotfiles are installed.

## Profiles

`minimal` installs and configures Git, Zsh and tmux.

`server` is the default and adds Neovim, ripgrep, fzf and jq. Pass
`--with-optional` to also install any available packages among bat, fd, eza,
zoxide, btop and mosh.

When available, both profiles also install Kitty's small terminfo package so
tmux and other remote programs understand a client advertising `xterm-kitty`.
The tmux theme uses Powerline separators rendered by the client terminal, so a
compatible local font is required but no font is installed on the server. tmux
3.6 and newer follow the client's light/dark appearance automatically; older
versions use Nord dark.

Package installation currently targets Debian and Ubuntu through APT. On a
different distribution, provision the commands separately and use
`--skip-packages`.

## Local installation

```bash
./install --profile server
```

Useful variants:

```bash
./install --dry-run
./install --profile minimal
./install --profile server --with-optional
./install --skip-packages
./install --set-shell
```

Changing the login shell is intentionally opt-in. Reconnect after using
`--set-shell`.

## Remote installation over SSH

Run this from a clean, committed checkout:

```bash
./install-remote user@example.com
```

For a completely unattended deployment where remote `sudo` does not need a
password:

```bash
./install-remote --yes --profile server user@example.com
```

Options can be combined:

```bash
./install-remote \
    --profile server \
    --with-optional \
    --set-shell \
    --port 22 \
    user@example.com
```

The remote installer does not clone a repository and does not need GitHub
credentials. It streams `git archive HEAD` over SSH and deploys only tracked
files from the exact commit.

Releases are stored under:

```text
~/.local/share/dotfiles-lite/releases/<commit>
```

The stable `current` symlink is switched to the new release before the managed
configuration is installed. If installation fails, the previous release is
reactivated.

## Safety and local customization

Existing managed targets are moved, never deleted, to:

```text
~/.local/state/dotfiles-lite/backups/<timestamp>/
```

The linker is transactional: when a later validation step fails, targets
changed by that run are restored. Running the installer again is idempotent.

Machine-specific additions belong in these unmanaged files:

```text
~/.config/dotfiles-lite/zsh.local
~/.config/dotfiles-lite/git.local
~/.config/dotfiles-lite/nvim.local.lua
```

The Zsh and Neovim configurations load them automatically. The Git file may
contain identity and signing configuration, for example:

```gitconfig
[user]
    name = Your Name
    email = you@example.com
```

## Validation

Run the fast installer smoke test:

```bash
./tests/smoke.sh
```

Run the full installation twice in a disposable Debian container:

```bash
./tests/container-smoke.sh
```

Another Debian/Ubuntu image can be passed as the first argument. The installer
also validates the managed Git, Zsh, tmux and Neovim configurations after every
real installation.
