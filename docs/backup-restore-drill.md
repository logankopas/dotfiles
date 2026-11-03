# Backups on L-Desktop — where things are, how to restore, how to drill

## Layout

| What | Where |
|---|---|
| Script | `/usr/local/sbin/borg-backup` (from `dotfiles/borg/borg-backup.sh`) |
| Jobs | `/etc/borg/jobs/{full,precious,offsite}.conf` (from `dotfiles/borg/jobs/`) |
| Excludes | `/etc/borg/excludes-full`, `/etc/borg/excludes-precious` |
| Passphrase | `/etc/borg/passphrase` (0600 root) = Proton Pass `homelab/BORG_PASSPHRASE` |
| Repos | `full`: `/mnt/borg/repos/full` (blue disk, sdb) · `precious`: `/mnt/borg-precious/repos/precious` · `offsite`: ssh, when configured |
| Status | `/var/lib/borg/status` — `sudo borg-backup status` — shown at ssh login by `/etc/update-motd.d/40-backup-status` |
| Logs | `/var/log/borg/<job>-<cmd>-<timestamp>.log` (full borg output); `<job>-<cmd>-latest.log` symlink; journal has summaries: `journalctl -u backup@full.service` |
| Units | `backup@<job>` / `backup-check@<job>` / `backup-verify@<job>`; timers `backup-full.timer` 04:00, `backup-precious.timer` 03:00, checks Saturday night, verify-data first Sunday |

Deploy changes: edit in `~/dotfiles`, then `sudo ./homelab.sh --skip-docker --skip-secrets`.
Day-to-day operation is in `docs/operators-manual.md`; the no-prior-knowledge restore guide is
`borg/README-blue-disk.md` (installed on the disk as `/mnt/borg/README.md`).

Every borg command below needs the passphrase. Use:

```sh
sudo -i                       # root shell
export BORG_PASSCOMMAND='cat /etc/borg/passphrase'
```

## Key export — do this once per repo, and again after `borg key change-passphrase`

The repo key is stored inside the repo (`repokey`), protected by the passphrase. If the disk dies
you still have the data elsewhere, but if the *repo config* is damaged you need the key to read
anything at all. Export it and keep it with the passphrase, off this machine:

```sh
borg key export /mnt/borg/repos/full /root/borg-key-full.txt
borg key export --paper /mnt/borg/repos/full /root/borg-key-full-paper.txt
# store both files' contents in Proton Pass (vault homelab, item BORG_KEY_<job>, e.g. BORG_KEY_full); print the paper one
shred -u /root/borg-key-full*.txt
touch /etc/borg/key-exported-full         # clears the MOTD warning
```
Repeat for `precious` (`/mnt/borg-precious/repos/precious`) and `offsite`.

To use an exported key on another machine: `borg key import <repo> <keyfile>`.

## Browse

```sh
borg list /mnt/borg/repos/full                                   # archives
borg list /mnt/borg/repos/full::L-Desktop-full-2026-11-03T04:00:02 home/logan/projects   # files (no leading slash)
borg info /mnt/borg/repos/full                                   # sizes, dedup
borg mount /mnt/borg/repos/full /mnt/restore && ls /mnt/restore  # FUSE browse; borg umount /mnt/restore
```

## Restore a file or directory

Paths inside archives have no leading slash. Extract into a scratch dir, then move into place:

```sh
cd /var/tmp && mkdir restore && cd restore
borg extract --list /mnt/borg/repos/full::L-Desktop-full-2026-11-03T04:00:02 home/logan/projects/foo
ls home/logan/projects/foo
```
Restore in place: `cd / && borg extract ...` (overwrites). Add `--dry-run` first if unsure.

## Restore Immich

1. `systemctl stop immich.service` (or `docker compose down` in `/var/selfhosted/immich`).
2. Extract `var/selfhosted/immich/library` and `var/selfhosted/immich/db-dumps` (the nightly
   `pg_dumpall`) from the archive into `/var/selfhosted/immich/`.
3. Start only Postgres: `docker compose up -d database`; then
   `gunzip -c db-dumps/immich-<latest>.sql.gz | docker exec -i immich_postgres psql --username=postgres`.
4. `docker compose up -d`. (Alternative: extract `var/selfhosted/immich/postgres` instead of using
   the dump — crash-consistent only.)

## Precious / offsite repos

Same commands with `/mnt/borg-precious/repos/precious` or the ssh URL. For ssh also export
`BORG_RSH='ssh -i /etc/borg/offsite_ed25519'`.

## Run / inspect by hand

```sh
sudo systemctl start backup@full.service && journalctl -u backup@full.service -f
sudo systemctl start backup-check@full.service          # check + restore test
sudo borg-backup restore-test full                       # restore test only
sudo borg-backup dry-run full | less                     # what the excludes drop
sudo borg-backup status
systemctl list-timers 'backup*'
```

## Disaster drill — quarterly

Pretend L-Desktop is gone. On a live USB or another Linux box, with only Proton Pass:
1. Install borg (`apt install borgbackup`), plug in the blue disk, `mount /dev/disk/by-label/borg-main /mnt`.
2. `borg key import /mnt/repos/full <key from Proton Pass>`; `export BORG_PASSPHRASE=...`.
3. `borg list /mnt/repos/full`; extract `etc/` and one Immich album; open a photo.
4. Record the date and outcome below.

| Date | Who | Result |
|---|---|---|
| | | |
