#!/usr/bin/env bash
# stage-disk -- move everything worth keeping off an old disk into /home/logan/staging/<name>,
# with a checksum manifest and two independent verifications. Run as root. Nothing here writes
# to the source disk; mount it read-only yourself first.
#
#   stage-disk.sh inventory <name> <src-mount> <junk.txt>   # manifest + sha256 of the source (slow: reads the disk)
#   stage-disk.sh index     <name>                          # size/basename index of /home /var/selfhosted (incl. staging)
#   stage-disk.sh report    <name>                          # dedup-report.tsv + duplicates.list  -> REVIEW before copy
#   stage-disk.sh copy      <name> <src-mount> <junk.txt>   # rsync (skips duplicates.list) into /home/logan/staging/<name>
#   stage-disk.sh verify    <name> <src-mount> <junk.txt>   # rsync --checksum dry-run must be empty AND sha256sum -c must pass
#
# Work dir: /root/disk-migration/<name>/ (on the NVMe, inside the full backup).
# Add top-level dirs you do NOT want (movies, games, ISOs) to the junk file before `inventory`.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
STAGING_ROOT=/home/logan/staging
OWNER=logan:logan

cmd=${1:-}; name=${2:-}
[[ -n $cmd && -n $name && $name =~ ^[a-z0-9-]+$ ]] || { sed -n '2,15p' "$0" >&2; exit 2; }
W=/root/disk-migration/$name
install -d -m 0700 "$W"
DEST=$STAGING_ROOT/$name

prune_expr() {   # build find -prune expression from a junk list (matches at any depth, by name)
    local j; PRUNE=()
    while IFS= read -r j; do [[ -n $j && $j != \#* ]] || continue; PRUNE+=( -name "$j" -prune -o ); done < "$1"
}
rsync_excludes() { printf -- '--exclude-from=%s\n' "$1"; [[ -s $W/duplicates.list ]] && printf -- '--exclude-from=%s\n' "$W/duplicates.list"; return 0; }

case $cmd in
inventory)
    src=${3:?src-mount}; junk=${4:?junk.txt}
    mountpoint -q "$src" || { echo "$src is not a mountpoint" >&2; exit 2; }
    grep -qE "^\S+ $src \S+ ro[ ,]" /proc/mounts || { echo "REFUSING: $src is not mounted read-only" >&2; exit 2; }
    cp "$junk" "$W/junk.txt"; prune_expr "$W/junk.txt"
    echo "inventory of $src -> $W/$name-inventory.tsv"
    ( cd "$src" && find . "${PRUNE[@]}" -type f -printf '%s\t%P\n' ) > "$W/$name-inventory.tsv"
    echo "hashing $(wc -l < "$W/$name-inventory.tsv") files (this reads the whole disk) ..."
    ( cd "$src" && find . "${PRUNE[@]}" -type f -printf '%P\0' | xargs -0 -r sha256sum ) > "$W/$name.sha256"
    n1=$(wc -l < "$W/$name-inventory.tsv"); n2=$(wc -l < "$W/$name.sha256")
    echo "inventory: $n1 files, manifest: $n2 hashes"
    [[ $n1 -eq $n2 ]] || { echo "MISMATCH between inventory and manifest -- investigate before continuing" >&2; exit 1; }
    awk -F'\t' '{s+=$1} END {printf "total size: %.1f GiB\n", s/2^30}' "$W/$name-inventory.tsv"
    ;;
index)
    echo "indexing /home /var/selfhosted -> $W/local-index.tsv"
    find /home /var/selfhosted -xdev -type f -printf '%s\t%f\t%p\n' > "$W/local-index.tsv"
    echo "$(wc -l < "$W/local-index.tsv") local files indexed"
    ;;
report)
    python3 -I "$HERE/dedup-report.py" "$W/$name.sha256" "$W/$name-inventory.tsv" "$W/local-index.tsv" "$W"
    echo "review: $W/dedup-report.tsv   (DUPLICATE rows are skipped by copy; delete lines from $W/duplicates.list to copy them anyway)"
    cut -f1 "$W/dedup-report.tsv" | sort | uniq -c
    ;;
copy)
    src=${3:?src-mount}; junk=${4:?junk.txt}
    [[ -f $W/dedup-report.tsv ]] || { echo "run report first" >&2; exit 2; }
    mapfile -t ex < <(rsync_excludes "$W/junk.txt")
    install -d -o "${OWNER%%:*}" -g "${OWNER##*:}" -m 0755 "$STAGING_ROOT" "$DEST"
    df -h / | tail -1
    echo "rsync $src/ -> $DEST/"
    rsync -aH --info=progress2 --chown="$OWNER" "${ex[@]}" "$src/" "$DEST/"
    cp "$W/dedup-report.tsv" "$DEST/DUPLICATES-ON-NVME.tsv"; chown "$OWNER" "$DEST/DUPLICATES-ON-NVME.tsv"
    echo "copy done; now run: $0 verify $name $src $junk"
    ;;
verify)
    src=${3:?src-mount}; junk=${4:?junk.txt}
    mapfile -t ex < <(rsync_excludes "$W/junk.txt")
    echo "== 1/2 rsync --checksum dry-run (must print nothing below this line)"
    out=$(rsync -aH --checksum --dry-run --itemize-changes --chown="$OWNER" "${ex[@]}" "$src/" "$DEST/" | grep -v '^\.d' || true)
    if [[ -n $out ]]; then echo "$out"; echo "VERIFY FAILED (rsync differences)"; exit 1; fi
    echo "   ok"
    echo "== 2/2 sha256 manifest check against the copy (must report nothing below this line)"
    if [[ -s $W/duplicates.list ]]; then
        sed 's#^/##' "$W/duplicates.list" | awk 'NR==FNR {d[$0]=1; next} { p=$0; sub(/^[0-9a-f]+  /, "", p); if (!(p in d)) print }' - "$W/$name.sha256" > "$W/$name-copied.sha256"
    else
        cp "$W/$name.sha256" "$W/$name-copied.sha256"
    fi
    ( cd "$DEST" && sha256sum --quiet -c "$W/$name-copied.sha256" ) || { echo "VERIFY FAILED (manifest)"; exit 1; }
    echo "   ok ($(wc -l < "$W/$name-copied.sha256") files)"
    echo "VERIFIED: $DEST matches $src"
    ;;
*) sed -n '2,15p' "$0" >&2; exit 2 ;;
esac
