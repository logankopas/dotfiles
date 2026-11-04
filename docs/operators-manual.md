# Operator's manual: the L-Desktop homelab

This is the "how do I run this thing" document for the machine provisioned from this repository.
`README.md` says what is in the repo; this file says what to do with it. The restore-only guide
written for a non-operator is `borg/README-blue-disk.md`, which also lives on the backup disk as
`/mnt/borg/README.md`.

## 1. The machine

| | |
|---|---|
| Host | L-Desktop, Zorin OS 18 (Ubuntu 24.04 base), LUKS-encrypted NVMe root |
| Users | `logan` (admin, sudo), `megan`, `immich` (runs the Immich containers), `agent` (runs the agent sandbox). Group `selfhosted` owns `/var/selfhosted`. |
| Services | Immich (photos, port 2283), nginx-proxy-manager (80/443, admin 81), agent sandbox container (ssh 2222, Phoenix 4000). All are `docker compose` projects started by systemd units. |
| Backup disk | Blue 3.6 TB USB HDD, ext4 label `borg-main`, UUID `8c0fd48b-10ed-42cd-bedb-5ae24c97d016`, mounted at `/mnt/borg` from fstab with `nofail`. Must stay on a USB 3 port. |
| Other disks | TOURO (sda, 466 GB NTFS): media only, re-downloadable, 8 pending sectors, not a backup target. Photos disk (sdd, 56 GB HFS+): fully staged, flaky USB bridge. Samsung 840 (sdc, 112 GB SATA SSD): wiped 2026-11-04, now ext4 `scratch` mounted at `/mnt/scratch` (owned by logan, `nofail`; throwaway space, not backed up by any job, not a backup target). |
| Secrets | Proton Pass vault `homelab`. `BORG_PASSPHRASE`, `BORG_KEY_full` (exported repo key), `IMMICH_DB_PASSWORD`, plus a pass-cli PAT stored at `/home/logan/secrets/proton-pass-pat`. |

## 2. Two installers

**`install.sh`** sets up a user's shell: it symlinks `bashrc`, `bash_aliases`, `bash_profile`,
`vimrc`, `tmux.conf`, `gitconfig`, `pythonrc`, `git_template`, `zshrc` into `~` as dotfiles and
`nvim/` to `~/.config/nvim`. It never overwrites a real file that is already there. Run it once per
user; it is not needed for the server side.

**`homelab.sh`** (run as root) provisions the server side and is idempotent:

```sh
cd ~/dotfiles && sudo ./homelab.sh --skip-docker --skip-secrets     # the usual re-run
```

In order it: creates users and groups; installs Docker (skip with `--skip-docker`); installs
pass-cli and logs in with the PAT (skip with `--skip-secrets`: this avoids a `curl | bash` on every
run); hard-links `services/<name>/*` into `/var/selfhosted/<name>/` and generates `.env` from
`.env.template` via Proton Pass on first run only; fixes ownership for the container UIDs; installs
borg (section 4); installs the login banner (section 5); links `systemd/*.service` and `*.timer`
into `/etc/systemd/system`, removes links whose source disappeared, enables everything; builds the
agent image.

Two deployment styles coexist, on purpose:

- **Symlinked/hard-linked**: service compose files and systemd units. Editing the repo edits the
  live file; run `systemctl daemon-reload` after unit changes.
- **Copied** (`install`): everything under `borg/` and `motd/`. These run as root, and root must
  never execute a file that the `logan` user can write. Editing the repo does nothing until you
  re-run `homelab.sh`.

## 3. Day to day

**Status at a glance**: `ssh localhost` prints the login banner. One block per backup job:

```
  Backup full:     OK                        2026-11-03 04:00  L-Desktop-full-2026-11-03T04:00:02
  Check  full:     OK                        2026-11-03 09:44  quick
  Restore full:    OK                        2026-11-03 09:44  80/80 files verified
```

`OVERDUE Nh`, `FAILED`, `WARN (rc 1)` or a `!!` line means look at the log it names. The same
data is in `/var/lib/borg/status` (`sudo borg-backup status`).

**Schedule** (`systemctl list-timers 'backup*'`):

| Timer | When | Does |
|---|---|---|
| `backup-full.timer` | daily 04:00 | `borg-backup backup full`: Immich DB dump, create, prune, compact |
| `backup-check-full.timer` | Saturday 01:00 | `borg check` (metadata) then a restore test of 80 sampled files |
| `backup-verify-full.timer` | first Sunday 01:00 | `borg check --verify-data` (reads every chunk; hours) then the restore test |
| `backup-precious.timer`, `backup-check-precious.timer`, `backup-verify-precious.timer` | 03:00 / Sat 00:00 / first Sunday 00:00 | fire, but job `precious` is `ENABLED=no`, so the script exits 0 and clears any stale `precious_*` status (a disabled job never shows in the banner). Flip to `yes` when a second healthy disk exists. |

**Logs**: `/var/log/borg/<job>-<cmd>-<timestamp>.log` holds the full borg output including the
`--list` of every changed file; `<job>-<cmd>-latest.log` points at the newest. Logs are gzipped
after 7 days and deleted after 180. The journal only gets the summary lines:
`journalctl -u backup@full.service -n 30`.

**Run things by hand** (all as root):

```sh
systemctl start backup@full.service && journalctl -u backup@full.service -f   # a backup now
systemctl start backup-check@full.service                                    # check + restore test
borg-backup restore-test full                                                # restore test only
borg-backup dry-run full | less                                              # what the excludes drop
export BORG_PASSCOMMAND='cat /etc/borg/passphrase'; borg list /mnt/borg/repos/full
```

A backup and a check of the same job never overlap: they share a lock and wait up to 6 hours.

**Return codes**: borg rc 0 = ok, 1 = warning (finished, something logged, typically a file that
changed while being read), 2 = error, 128+N = killed by signal N. The script collapses these to a
severity and exits with it; the units declare `SuccessExitStatus=1`, so only real errors trigger
`backup-failed@.service`, which marks the job failed in the status file and the banner.

## 4. Borg: how it is wired

| Piece | Repo file | Installed to |
|---|---|---|
| Script | `borg/borg-backup.sh` | `/usr/local/sbin/borg-backup` 0755 |
| Jobs | `borg/jobs/{full,precious,offsite}.conf` | `/etc/borg/jobs/` 0640 |
| Excludes | `borg/excludes-full`, `borg/excludes-precious` | `/etc/borg/` 0644 |
| Pre-hook | `borg/hooks/immich-db-dump` | `/etc/borg/hooks/` 0755 |
| Recovery README | `borg/README-blue-disk.md` | `/mnt/borg/README.md` (only when the disk is mounted) |
| Passphrase | not in the repo | `/etc/borg/passphrase` 0600 root, written once by `homelab.sh` from Proton Pass or by hand |
| Key exported marker | not in the repo | `/etc/borg/key-exported-<job>`; missing marker = banner warning |

A job config is a bash fragment sourced by the script: `ENABLED`, `REPO`, `MOUNTPOINT` (the
script refuses to run unless it is a mountpoint; empty for ssh repos), `SOURCES`, `EXCLUDES`,
`COMPRESSION`, `KEEP_DAILY/WEEKLY/MONTHLY`, `CHECK_QUICK_ARGS`, `RESTORE_TEST_DIRS`,
`RESTORE_TEST_PER_DIR`, `RESTORE_TEST_MAX_BYTES`, `PRE_HOOKS`, `POST_HOOKS`, `LOCK_WAIT`.

Job `full` backs up `/etc /home /root /var` with `--one-file-system`, lz4, 7/4/6 retention, to
`/mnt/borg/repos/full` (repokey-blake2). Archives are named `{hostname}-full-{now}`. Excluded:
docker's image store, caches, journal, the job's own logs, rebuildable toolchains, flatpak and
snap stores, and build artefacts under `~/projects` and `~/agent-workspace` (see the excludes file;
`borg-backup dry-run full` shows exactly what is dropped). Everything under `/var/selfhosted`
is kept, including the Immich library and the nightly `pg_dumpall` the pre-hook writes to
`/var/selfhosted/immich/db-dumps/` (14 days kept).

**Restore test**: samples 20 regular files under each of `/etc`, `/home/logan/staging`,
`/home/megan` and the Immich library from the archive listing, extracts them to `/var/tmp`, and
sha256-compares with the live file. Files changed since the archive started are "skipped", not
failures. `bad` or `missing` above 0 marks the restore state failed.

**Editing excludes**: one pattern per line, no inline comments (borg treats the whole line as the
pattern), paths relative to `/` without a leading slash, `re:` prefix for regexes. Then re-run
`homelab.sh` and `borg-backup dry-run full`.

**Changing the passphrase**: `borg key change-passphrase`, update `/etc/borg/passphrase`, update
Proton Pass, re-export the key (`docs/backup-restore-drill.md`), re-touch the marker.

**Adding a job**: copy a conf into `borg/jobs/`, add `backup-<job>.timer` plus check/verify
timers in `systemd/` (each with `Unit=backup@<job>.service` etc.), `borg init
--encryption=repokey-blake2 <repo>` as root, re-run `homelab.sh`, export the key. The banner
picks the job up automatically after its first run. `offsite.conf` is the template for a borg-over-ssh
destination.

## 5. Login banner (MOTD)

`motd/40-backup-status` is a `/bin/sh` script installed into `/etc/update-motd.d/`. `homelab.sh`
also strips the executable bit from the noisy Ubuntu scripts (`10-help-text 50-motd-news 85-fwupd
91-release-upgrade 95-hwe-eol`) and disables `motd-news.timer`; it re-applies that on every run
because package upgrades restore the bits. Test with `ssh localhost` or `sudo run-parts
/etc/update-motd.d`.

## 6. Services and secrets

Each `services/<name>/` holds a `docker-compose.yml` and optionally `.env.template` with
`${NAME}` placeholders. `homelab.sh` hard-links the files into `/var/selfhosted/<name>/`, looks each
`${NAME}` up as a Proton Pass item of that title in vault `homelab` (field `password`), and writes
`/var/selfhosted/<name>/.env` (0640 `logan:selfhosted`). It will not regenerate an existing `.env`;
delete it and re-run to refresh. `systemd/<name>.service` runs `docker compose up` in that directory
as the service's user. All containers share the external Docker network `homelab`.

To add a service: create the directory and compose file, add a template if it needs secrets,
add the Proton Pass items, add the unit, run `homelab.sh`.

Immich specifics: originals live in `/var/selfhosted/immich/library/upload/<user-id>/`;
`library/backups/` holds Immich's own 02:00 database dumps; Postgres data is in
`/var/selfhosted/immich/postgres` (crash-consistent only, which is why the pre-hook dumps it).
Restore procedure: `docs/backup-restore-drill.md`.

## 7. Disks

```sh
lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT,TRAN      # who is who (names change between boots)
sudo smartctl -H -A /dev/sdX                          # health; watch Current_Pending_Sector, Reallocated_Sector_Ct, UDMA_CRC_Error_Count
sudo dmesg -Tw | grep -E 'disconnect|I/O error|Medium|critical'   # watch a USB disk while it works
```

Rules learned the hard way:

- Refer to disks by label or UUID (`/dev/disk/by-label/...`), never by `sdX`, in fstab and in
  long-running commands. A USB disk can drop off the bus and come back under a new name while
  its old mount is still pinned to the dead device; the symptom is `Buffer I/O error ... async
  page read` with no `Medium Error` lines. Unmount, move to a USB 3 port, remount by label.
- Real surface errors show `Sense Key : Medium Error` or `critical medium error` with sector
  numbers in `dmesg`.
- Old disks are mounted read-only (`mount -o ro`, `ntfs-3g` for NTFS, `hfsplus` for Mac) and
  staged with `borg/migration/stage-disk.sh` before anything is done to them: inventory with a
  sha256 manifest, dedup report against what the NVMe already has, rsync copy, then a verify that
  must print `VERIFIED`. Windows EFS-encrypted files on NTFS show up as `Permission denied` at
  offset 0 in the ntfs-3g log and cannot be recovered without the Windows account's certificate.
- fstab entries for removable disks use `noatime,nofail,x-systemd.device-timeout=30s` so the
  machine boots with the disk unplugged. The backup job then fails loudly in the banner instead
  of writing to the NVMe.

## 8. When something is wrong

| Banner says | Do |
|---|---|
| `Backup full: FAILED` + log path | `less` the log. Preflight failures (disk not mounted, passphrase unreadable) are the first lines. `mount /mnt/borg` then `systemctl start backup@full.service`. |
| `WARN (rc 1)` | Borg finished with warnings. `grep -E '^[A-Z]|warning' <log>`; usually a file changed during the read. Nothing to do unless it repeats. |
| `OVERDUE` | The timer did not fire or the run never finished. `systemctl status backup-full.timer backup@full.service`; `journalctl -u backup@full.service`. |
| `Check full: FAILED` | `borg check` found a problem or the restore test had `bad`/`missing` files. Read the check log. Do not run `--repair` without a second copy of the repo. |
| `!! backup@full.service failed at ...` | The unit itself failed (script crash, timeout 18 h, killed). `journalctl -u backup@full.service`. |
| `!! borg key for full NOT exported` | Export per `docs/backup-restore-drill.md`, store in Proton Pass as `BORG_KEY_<job>`, `touch /etc/borg/key-exported-<job>`. |
| Lock errors, nothing running | `borg break-lock /mnt/borg/repos/full` only after `pgrep -a borg` shows nothing. |

## 9. Git

Work on `main` and push to `origin/main`. The GitHub default branch is still `master`; it is the
same history and can be fast-forwarded (`git push origin main:master`) whenever convenient.
Commits are small and prefixed with the area they touch (`borg:`, `agent:`, `migration:`,
`nvim:`).

## 10. Open items (as of 2026-11-04)

- Phase 5 is done: all four old-disk trees are staged, verified and present in the 2026-11-04
  archive, and the Samsung is now `/mnt/scratch`. Nothing else is left on the old disks except
  re-downloadable media on TOURO.

- `precious` (second copy of Immich + `/home/megan`) stays disabled until there is a trustworthy
  second disk. TOURO is a candidate only if a full write test clears its pending sectors.
- `offsite` waits for a destination (a Hetzner storage box or a friend's box with borg over ssh).
  Everything is prepared in `borg/jobs/offsite.conf`.
- Quarterly restore drill: table at the end of `docs/backup-restore-drill.md`.
- `~/staging` is a holding pen: sort it, delete `._*` AppleDouble files, import the camera RAW
  files from `photos-disk` into Immich.
