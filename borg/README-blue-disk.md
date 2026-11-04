# READ ME: this disk holds the backups of L-Desktop

This is the backup disk for the home computer called **L-Desktop**. Everything that matters on
that computer is copied onto this disk every night at 04:00: both home folders, all the photos and
videos in Immich, and the documents rescued from the old external disks.

If L-Desktop is broken, stolen or gone, **this disk plus two secrets from the family password
manager is all you need to get everything back.** You do not need the original computer. You do
not need to understand borg. Give this file to an AI agent (Claude, ChatGPT, or similar) and ask
it to walk you through it. It is written so the agent can follow it step by step.

The two secrets are in the family password manager (Proton Pass), vault **homelab**:

| Item | What it is |
|---|---|
| `BORG_PASSPHRASE` | The passphrase that unlocks the backups. **You always need this.** |
| `BORG_KEY_full` | A spare copy of the encryption key. Only needed if the disk is damaged and borg complains about the key. There is also a printed copy with the household papers. |

Never share the passphrase with a website or paste it into a chat with an AI. Type it into the
terminal when the steps below ask for it.

## What is on the disk

The disk is a 3.6 TB USB hard drive, formatted as Linux ext4, volume label `borg-main`. The
backups are stored in one folder, `repos/full`, in the format of the backup program **borg**
(BorgBackup, version 1.2). Borg keeps many dated snapshots called *archives* and stores every
file only once, so the folder is a single big database, not plain files. The whole thing is
encrypted with the passphrase above.

Each archive is a complete picture of the computer on that night and is named like
`L-Desktop-full-2026-11-03T04:00:02`. About 7 daily, 4 weekly and 6 monthly archives are kept.

Inside every archive, paths are the computer's paths without the leading slash:

| Path inside the archive | What you will find |
|---|---|
| `home/megan/` | Megan's home folder: Documents, Desktop, Downloads and so on |
| `home/logan/` | Logan's home folder (projects, settings, staging below) |
| `home/logan/staging/` | Everything rescued from the old external disks, one folder per disk: `bluedisk-docs`, `touro`, `touro-trash`, `photos-disk`, `samsung-data` |
| `var/selfhosted/immich/library/upload/<user-id>/` | **The original photos and videos from Immich**, one `<user-id>` folder per Immich user. These are the actual JPG/HEIC/MP4/RAW files; copy this and you have the photos. |
| `var/selfhosted/immich/library/thumbs/`, `encoded-video/` | Generated previews. Not needed; Immich recreates them. |
| `var/selfhosted/immich/db-dumps/` and `var/selfhosted/immich/library/backups/` | Nightly dumps of the Immich database (albums, people, favourites). Needed only to rebuild Immich itself, not to get the photos. |
| `etc/`, `root/`, `var/selfhosted/` | System configuration. Only interesting when rebuilding the computer. |

## What you need

- Any computer that can run Linux. The easiest is a normal PC booted from an **Ubuntu live USB**
  ("Try Ubuntu", no installation needed). A Mac cannot read this disk without extra software.
- A USB port for this disk, and somewhere to put the restored files (another external disk, or the
  live PC's own disk if you are installing Linux on it). Restoring all the photos needs about
  160 GB of free space; Megan's home folder about 110 GB.
- The passphrase from the password manager.
- Internet access for one command that installs borg.

## Step by step

Open a terminal. Every line that starts with `sudo` will ask for the live-session password
(on an Ubuntu live USB, press Enter: there is none).

**1. Install borg.** It must be version 1.2 or 1.4, not 2.x. Ubuntu's package is the right one.

```sh
sudo apt update && sudo apt install -y borgbackup
borg --version
```

**2. Plug in this disk and mount it read-only.** Read-only means nothing on this disk can be
changed by mistake.

```sh
sudo mkdir -p /mnt/backup
sudo mount -o ro /dev/disk/by-label/borg-main /mnt/backup
ls /mnt/backup/repos/full        # should list: config  data  hints.*  index.*  integrity.*  README
```

**3. Give borg the passphrase.** This keeps it out of your shell history. Paste the passphrase
when the cursor waits; nothing is shown while you type.

```sh
read -rs BORG_PASSPHRASE && export BORG_PASSPHRASE
export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes      # borg notices the disk moved to a new computer; this says that is fine
export REPO=/mnt/backup/repos/full
```

**4. List the archives.** Because the disk is read-only, add `--bypass-lock` to every borg command.

```sh
borg list --bypass-lock "$REPO"
```

You should see lines like `L-Desktop-full-2026-11-03T04:00:02  Tue, 2026-11-03 04:00:03`. Pick the
newest one (the last line) and keep its name:

```sh
export ARCHIVE="$REPO::$(borg list --bypass-lock --last 1 --short "$REPO")"
echo "$ARCHIVE"
```

If step 4 says the passphrase is wrong, check for a copy-paste mistake first. If it complains
about the key or the repository config, go to "If the key is damaged" below.

**5. Look inside.** Paths have no leading slash.

```sh
borg list --bypass-lock "$ARCHIVE" home/megan | head -50
borg list --bypass-lock "$ARCHIVE" var/selfhosted/immich/library/upload | head -50
borg info --bypass-lock "$ARCHIVE"                      # how big it is
```

**6. Restore.** Go to a folder on the disk where you want the files, then extract. Borg recreates
the archive's folder tree under the current directory, so the photos end up in
`./var/selfhosted/immich/library/upload/...`.

```sh
mkdir -p /media/ubuntu/<your-other-disk>/restore && cd /media/ubuntu/<your-other-disk>/restore
# Megan's home folder:
borg extract --bypass-lock --list "$ARCHIVE" home/megan
# All original photos and videos:
borg extract --bypass-lock --list "$ARCHIVE" var/selfhosted/immich/library/upload
# One specific folder or file:
borg extract --bypass-lock --list "$ARCHIVE" home/megan/Documents/taxes
```

Alternatively, browse the whole archive like a normal folder and copy things with the file
manager (needs `sudo apt install python3-pyfuse3` first):

```sh
mkdir -p /mnt/restore-view
borg mount --bypass-lock "$ARCHIVE" /mnt/restore-view
ls /mnt/restore-view/home/megan
# ... copy what you need ...
borg umount /mnt/restore-view
```

**7. Done.** Unmount the disk before unplugging it: `sudo umount /mnt/backup`.

## If the key is damaged

Borg stores the encryption key inside the repository, protected by the passphrase. If the disk
has bad sectors and the key is unreadable, borg says something like *"key not found"* or
*"repository config is corrupted"*. Then import the spare key from the password manager item
`BORG_KEY_full` (paste its full contents into a file called `key.txt`), and try again:

```sh
sudo mount -o remount,rw /mnt/backup          # importing the key writes to the repo
borg key import "$REPO" key.txt
sudo mount -o remount,ro /mnt/backup
borg list --bypass-lock "$REPO"
```

If borg reports damage to the data itself, do **not** run any repair command. Stop, keep the
disk as it is, and get help: a repair can make things worse, and most of the data is usually
still readable with `borg extract` even when a check reports errors.

## Things never to do with this disk

- Never run `borg check --repair`, `borg delete`, `borg prune`, `borg compact` or `borg init` on it.
- Never format it, never "fix" it when Windows or macOS offers to, never store other files on it.
- Never copy the `repos/full` folder with Finder/Explorer and then work on the copy while it is
  still copying. Copying the folder to another disk is fine as a safeguard, once it has finished.

## What to tell an AI agent

Paste the text below, then paste this whole file after it:

> I have a USB backup disk from a Linux computer. It contains a BorgBackup 1.2 repository at
> `repos/full`, encrypted with a passphrase I have. I am on an Ubuntu live USB (or: on a Linux
> machine). Walk me through the README below one step at a time, show me each command before I
> run it, and help me restore `home/megan` and the Immich photos to another disk. Do not run any
> command that modifies the backup disk.

## The second disk (TOURO)

There is a second, smaller USB disk labelled **borg-precious** (a 466 GB HGST "Touro"). It holds a
second copy of only the irreplaceable things: the Immich photos and videos, the Immich database
dumps, and Megan's home folder. It is there in case this disk fails. Everything above works the
same way on it with three substitutions:

| On this disk | On the second disk |
|---|---|
| `/dev/disk/by-label/borg-main` | `/dev/disk/by-label/borg-precious` |
| `repos/full` | `repos/precious` |
| archives named `L-Desktop-full-...` | archives named `L-Desktop-precious-...` |

The passphrase is the same `BORG_PASSPHRASE`. Its spare key is the password manager item
`BORG_KEY_precious`.

## If L-Desktop still works

On the computer itself none of the above is needed: the disk is mounted at `/mnt/borg`, the
passphrase is in `/etc/borg/passphrase`, and every ssh login shows the backup status. As root:

```sh
sudo -i
export BORG_PASSCOMMAND='cat /etc/borg/passphrase'
borg list /mnt/borg/repos/full
```

The maintainer's documentation is in Logan's `dotfiles` repository
(`docs/operators-manual.md` and `docs/backup-restore-drill.md`).
