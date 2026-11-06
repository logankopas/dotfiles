# Homelab journal

Dated notes on decisions, findings and research for L-Desktop. Newest entry last. The
operator's manual describes the current state; this file records how it got there and what was
considered along the way.

## 2026-11-02 — Backup overhaul starts

**Starting point.** A nightly borg job wrote to `/var/local/backups` on the same NVMe as the data
(no protection against disk failure), backed up `/var/lib/docker`, used an `authenticated` repo
with the key stored in the repo and the passphrase substituted in plain text into a group-readable
script, logged only to journald (which dropped thousands of lines per run), never ran `borg check`
or a restore, and showed nothing at login when it failed.

Two USB disks held data that existed nowhere else: the **blue disk** (3.6 TB HFS+, a 2019 Time
Machine partition plus ~155 GB of documents) and **TOURO** (466 GB NTFS, 2013–2016 Windows-era
folders plus movies and games). An internal Samsung 840 SSD (112 GB NTFS "Data") and a 56 GB
HFS+ "Photos" disk were found later.

**Decisions.** Blue disk becomes the dedicated ext4 borg target `/mnt/borg`. Everything on the old
disks is copied to `~/staging/<disk>` with sha256 verification before any reformat. One
config-driven script (`borg-backup`) with jobs `full`, `precious`, `offsite`; file logs; a status
file read by a login banner; weekly check + restore test; monthly `--verify-data`. New repos are
`repokey-blake2` with the existing Proton Pass passphrase. The Time Machine partition is dropped
un-inventoried (owner decision). The old NVMe repo is deleted once the first new archive passes
check + restore test (no legacy copy).

**Done today.** Phase 0 (old repo `borg check` rc 0; passphrase file written). Phase 1 staging
of the blue-disk docs (49984 files, 155 GiB; one 23.7 GiB `Archive.zip` skipped as an exact
duplicate of `/home/megan/Archive.zip`). Phase 2 install of the new system. Phase 3 started: EFI +
Time Machine partitions deleted, 931 GB ext4 `borg-main` made in their place, repo initialised,
first archive running overnight. The Docs partition stays until the archive is verified, so the
docs are never on fewer than two media.

## 2026-11-03 — Blue disk complete, TOURO/Photos/Samsung staged

- First archive OK (1 h 23 m, 426 GB → 296 GB on disk). Borg returned rc 1 only because its own
  log under `/var/log/borg` changed while being read; excluded that directory, added
  `SuccessExitStatus=1`, and rewrote the rc handling per the borg docs.
- Key exported to Proton Pass (`BORG_KEY_full`) and paper. Check (35 min) + restore test 80/80 OK
  = GATE 3b. Old repo deleted; Docs partition deleted; `borg-main` grown to 3.6 TB (Phase 4).
- `smartmontools` installed. TOURO: 8 `Current_Pending_Sector`, 0 reallocated. Decided at the
  time not to use it as a backup target; `precious` parked (option C).
- Staged four more trees with the generic stage-a-disk procedure (inventory + sha256 manifest →
  NVMe index → dedup report → copy → checksum verify): `touro` (95196 files, 65 GB), `touro-trash`
  (24 files picked from the NTFS trash), `photos-disk` (3119 camera RAW files, 34 GB),
  `samsung-data` (521 files, 2 GB). All VERIFIED = GATE 5b.
- Findings: 10 files on TOURO are Windows EFS-encrypted and unreadable without the original
  Windows key (owner: ignore; `efs-raw-copy.sh` exists if ever wanted). The Photos disk reset off
  the USB bus by itself once; mounting by label on a USB 3 port fixed it. HFS+ stores symlink
  permission bits that ext4 cannot; the verify filter ignores that.
- Wrote `README-blue-disk.md` (recovery guide for a non-operator plus an AI agent; installed on the
  disk as `/mnt/borg/README.md`), `operators-manual.md`, and the repo `README.md`.

## 2026-11-04 — Samsung wiped, TOURO cleared and tested

- The 04:00 archive lists all four new staging trees = GATE 5c.
- Bug: re-running `homelab.sh` re-enables every timer, so the parked `precious` timer fired and
  the banner showed `Backup precious: FAILED`. Fix: a job with `ENABLED=no` now clears its own
  status keys when its timer fires, so a parked job never shows in the banner (commit 1a34403).
- Samsung 840 wiped → ext4 `scratch` at `/mnt/scratch` (110 GB, owned by logan, in no backup job).
- Owner reconsidered TOURO. The 192 GB of re-downloadable media (Videos + eight movie/series/game
  folders, 1147 files) was copied to `/mnt/borg/media` on the blue disk and checksum-verified;
  then `badblocks -wsv -t 0` over the whole disk: 0 bad blocks, pending sectors 8 → 0, reallocated
  stayed 0. SMART extended self-test: completed without error. Conclusion: the pending sectors
  were stale weak writes, not failing media. Decision: TOURO becomes the `precious` disk. The
  owner intends to buy a rotating pair of disks later for a take-away copy.

## 2026-11-05 — Phase 6: TOURO is the second backup disk

- Formatted ext4 `borg-precious` (UUID `5163e663-…`), mounted `/mnt/borg-precious` with
  `nofail`. Gotcha: `mkfs` ran before udev had created `/dev/sda1` and left a `UUID= ` line in
  fstab; removed it, and `udevadm settle` after `parted` from now on.
- `precious` enabled; repo initialised; first archive 199 GB on disk in ~1 h; check + restore test
  40/40 OK; key exported (`BORG_KEY_precious` + paper). Banner shows six OK lines. GATE 6 passed.
- Schedule from here: `precious` 03:00, `full` 04:00, checks Saturday 00:00/01:00, data verify
  first Sunday. The irreplaceable set (Immich library + DB dumps + `/home/megan`) is now on three
  devices; everything else on two.

## 2026-11-06 — Offsite options researched

Question: an online "cold storage" destination for the `offsite` job. True cold storage
(Glacier-class) does not fit borg: every run reads the repository index and segments, and a check
reads everything, so retrieval-priced archival tiers are the wrong shape. What fits is cheap ssh
storage that borg can talk to directly. The repo is ~300 GB today; a 1 TB tier leaves years of
headroom.

Cost for a ~350 GB repo, rounded, as of 2026-11-06:

| Service | Tier | Per year | Region | Notes |
|---|---|---|---|---|
| Hetzner Storage Box | BX11, 1 TB | €38 ex VAT (€3.20/month) + a one-time setup fee | Germany or Finland | Borg over ssh on port 23; remote borg version selectable with `--remote-path=borg-1.2` / `borg-1.4`; append-only supported; 10 snapshots; unlimited traffic; no minimum term. Only `/home/` is writable, so repo URLs are `ssh://uXXXX@uXXXX.your-storagebox.de:23/./<repo>`. |
| BorgBase | Small: 250 GB included, $0.015/GB/month overage | ≈ $48 (Small listed at $30/yr on the site, $24 in a search snippet — check at signup) | EU or US | Borg-native host; append-only; email/webhook alerts when a backup goes stale; 10 repos. Medium (1 TB) $110/yr; Large (2 TB) $210/yr. Free tier 10 GB / 2 repos. |
| rsync.net | Borg account, 200 GB minimum | $42 (= $0.01/GB/month, billed annually) | US | Borg-only accounts: no ZFS snapshots, no sub-accounts, no borg support. Standard accounts are $0.015/GB/month with an 800 GB minimum. |
| Backblaze B2 | pay as you go, $6.95/TB/month | ≈ $29 | US | Not a borg target (borg 1.x has no S3 backend). Would be `rclone sync` of the repo directory after each run. Cheapest, but no remote `borg check`, and a sync during compaction can leave a torn copy. Egress free up to 3× stored volume. |

Sources: [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box/) ·
[Hetzner borg docs](https://docs.hetzner.com/storage/storage-box/access/access-ssh-rsync-borg/) ·
[BorgBase](https://www.borgbase.com/) · [BorgBase pricing docs](https://docs.borgbase.com/pricing) ·
[rsync.net borg](https://www.rsync.net/products/borg.html) ·
[rsync.net pricing](https://www.rsync.net/pricing.html) ·
[Backblaze B2 pricing (third party)](https://tech-insider.org/backblaze-b2-vs-wasabi-vs-s3-2026/) ·
[B2 egress (third party)](https://egresscost.com/backblaze-b2/).

**Recommendation: Hetzner BX11.** Cheapest native borg target with the most room, and
`borg/jobs/offsite.conf` was already written for its URL form and port. Pick BorgBase instead if a
US region or the stale-backup email alert matters (the banner only reports at login).

**Phase 7 plan when a box exists** (also in the plan file): `ssh-keygen -t ed25519 -f
/etc/borg/offsite_ed25519` as root; register the key in the Hetzner console with ssh and external
reachability enabled; enable append-only on the box; `borg init --encryption=repokey-blake2` over
ssh; set `REPO`, `ENABLED=yes` and `--remote-path=borg-1.2` in `offsite.conf`; add
`backup-offsite.timer` (05:00) plus check/verify timers; `homelab.sh`; start the first archive by
hand; export the key to `BORG_KEY_offsite` + paper.

**Things to know.** The first upload is ~300 GB: about 1.5 days at 20 Mbit/s up, 7 hours at
100 Mbit/s; after that nightly deltas are usually under a GB. The job backs up the `full` set
(restricting it to the precious set would save ~100 GB but not change the tier). The monthly
`--verify-data` downloads every chunk; the first one decides whether it stays monthly or becomes
quarterly for offsite. The rotating disk pair still makes sense alongside: the online copy covers
the house, the disks cover a provider or account problem and restore at disk speed.
