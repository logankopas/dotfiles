# dotfiles

Shell, editor and homelab configuration for Logan's machines, currently the home server
**L-Desktop** (Zorin OS 18). Two things live here:

1. **Personal dotfiles**: `bashrc`, `zshrc`, `vimrc`, `nvim/`, `tmux.conf`, `gitconfig`, and
   friends. `install.sh` symlinks them into `~`.
2. **The homelab**: Docker services (`services/`), their systemd units (`systemd/`), the borg
   backup system (`borg/`), the login banner (`motd/`) and the provisioning script `homelab.sh`
   that installs all of it.

## Quick start

```sh
git clone git@github.com:logankopas/dotfiles.git ~/dotfiles
~/dotfiles/install.sh                                            # shell + editor for this user
cd ~/dotfiles && sudo ./homelab.sh                               # server side (first run: installs Docker, pass-cli)
cd ~/dotfiles && sudo ./homelab.sh --skip-docker --skip-secrets  # every later deploy
```

## Layout

| Path | What |
|---|---|
| `install.sh` | Links the user dotfiles into `~` and `nvim/` into `~/.config/nvim`. Refuses to overwrite real files. |
| `homelab.sh` | Idempotent root provisioning: users/groups, Docker, Proton Pass secrets, service links and `.env` generation, borg, MOTD, systemd units. |
| `lib/secrets.sh` | `get_secret <vault> <item> <field>` wrapper around pass-cli. |
| `services/<name>/` | `docker-compose.yml` (+ `.env.template`) per service: `immich`, `nginxproxy`, `agent`. Hard-linked into `/var/selfhosted/<name>/`. |
| `systemd/` | One `.service` per docker service, plus the borg templates `backup@`, `backup-check@`, `backup-verify@`, `backup-failed@` and their timers. Symlinked into `/etc/systemd/system`. |
| `borg/` | `borg-backup.sh` (the one script behind every backup job), `jobs/*.conf`, `excludes-*`, `hooks/`, the recovery `README-blue-disk.md` that is placed on the backup disk, and `migration/` (one-off tooling that staged the old disks). |
| `motd/` | `40-backup-status`, the login banner block that shows backup, check and restore state. |
| `docs/` | `operators-manual.md` (start here to run the machine), `backup-restore-drill.md` (key export, restore commands, quarterly drill), `journal.md` (dated log of decisions, findings and research). |
| `nvim/` | Neovim config (lazy.nvim, LSP, CodeCompanion with Claude Code adapters; see `nvim/codecompanion-cheatsheet.md`). |
| `git_template/` | Git hooks that rebuild ctags on commit/checkout/merge. |
| `setup_venv_autoactivate.sh` | Adds a `cd` hook that activates `./venv` when present. |

## Where to read next

- Running the machine, schedules, what the banner means, what to do when it is red:
  [`docs/operators-manual.md`](docs/operators-manual.md)
- Getting data back, with or without the original machine:
  [`borg/README-blue-disk.md`](borg/README-blue-disk.md) (non-operator version, also on the disk)
  and [`docs/backup-restore-drill.md`](docs/backup-restore-drill.md) (operator version).

Secrets never live in this repo. They are in Proton Pass (vault `homelab`) and are pulled in at
install time or read from root-only files on the host.
