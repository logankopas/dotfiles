#!/bin/bash
# Copy Windows EFS-encrypted files off an NTFS disk in their raw (still encrypted) form.
#
#   efs-raw-copy.sh <efs-raw-mount> <dest-dir> <list>
#
# <efs-raw-mount>  an ntfs-3g mount made with `-o ro,efs_raw` (plain mounts return EIO for these files)
# <dest-dir>       where to put them; each file becomes <relpath>.efsraw + <relpath>.efsinfo ($EFS metadata)
# <list>           relative paths, one per line
#
# Decrypting later needs the EFS certificate + private key of the Windows account that encrypted them
# (exported .pfx), or that account's profile (AppData/Roaming/Microsoft/{Crypto,Protect}) plus its password.
# Without those the bytes are unrecoverable; this only keeps the option open.
set -euo pipefail
src=${1:?efs-raw-mount}; dest=${2:?dest-dir}; list=${3:?list}
grep -q " $src .*efs_raw" /proc/mounts || { echo "$src is not an efs_raw ntfs-3g mount" >&2; exit 2; }
n=0
while IFS= read -r f; do
    [[ -n $f ]] || continue
    install -d -m 0755 "$dest/$(dirname "$f")"
    cp -p -- "$src/$f" "$dest/$f.efsraw"
    python3 -I -c 'import os,sys; open(sys.argv[2],"wb").write(os.getxattr(sys.argv[1],"system.ntfs_efsinfo"))' \
        "$src/$f" "$dest/$f.efsinfo"
    cmp -- "$src/$f" "$dest/$f.efsraw" && echo "ok  $f ($(stat -c %s "$dest/$f.efsraw") bytes raw, $(stat -c %s "$dest/$f.efsinfo") bytes efsinfo)"
    n=$((n+1))
done < "$list"
cat > "$dest/README.txt" <<'TXT'
These files were Windows EFS-encrypted on the source disk (green names in Explorer).
*.efsraw  = the raw encrypted data stream, byte-for-byte as stored on the NTFS volume
*.efsinfo = the file's $EFS attribute (encrypted FEK, certificate thumbprints)
To decrypt: put both back on an NTFS volume with ntfs-3g mounted -o efs_raw (copy the .efsraw as the file,
set the xattr system.ntfs_efsinfo from the .efsinfo), then open it on Windows as the account that encrypted
it, with its EFS certificate (.pfx) imported. Without that certificate they cannot be decrypted.
TXT
echo "$n files copied raw to $dest"
