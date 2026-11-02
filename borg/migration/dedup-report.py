#!/usr/bin/env python3
"""Which files from an old disk already exist on this machine?
Match on (size, basename), then confirm by sha256 of the local candidate.

usage: python3 -I dedup-report.py <disk>.sha256 <disk>-inventory.tsv local-index.tsv OUTDIR
  <disk>.sha256        sha256sum output, paths relative to the disk root
  <disk>-inventory.tsv size<TAB>relpath
  local-index.tsv      size<TAB>basename<TAB>abspath   (from `find ... -printf '%s\\t%f\\t%p\\n'`)
writes OUTDIR/dedup-report.tsv  (STATUS<TAB>relpath<TAB>local_path)
       OUTDIR/duplicates.list   (one '/relpath' per DUPLICATE, for rsync --exclude-from)
"""
import collections, hashlib, os, sys

if len(sys.argv) != 5:
    sys.exit(__doc__)
sha_f, inv_f, idx_f, out = sys.argv[1:5]
opts = dict(encoding="utf-8", errors="surrogateescape")

docs_sha = {}
with open(sha_f, **opts) as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        h, _, p = line.partition("  ")
        docs_sha[p.removeprefix("./")] = h

docs_size = {}
with open(inv_f, **opts) as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        s, p = line.split("\t", 1)
        docs_size[p.removeprefix("./")] = int(s)

local = collections.defaultdict(list)
with open(idx_f, **opts) as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        s, b, p = line.split("\t", 2)
        local[(int(s), b)].append(p)

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

cache, counts, dup_bytes = {}, collections.Counter(), 0
with open(os.path.join(out, "dedup-report.tsv"), "w", **opts) as rep, \
     open(os.path.join(out, "duplicates.list"), "w", **opts) as dup:
    for p, size in sorted(docs_size.items()):
        cands = local.get((size, os.path.basename(p)), []) if size > 0 else []
        status, match = "UNIQUE", ""
        for c in cands:
            if c not in cache:
                try:
                    cache[c] = sha256(c)
                except OSError:
                    cache[c] = None
            if cache[c] is not None and cache[c] == docs_sha.get(p):
                status, match = "DUPLICATE", c
                break
        else:
            if cands:
                status, match = "SAMESIZE_DIFFHASH", cands[0]
        if status == "DUPLICATE":
            dup.write("/" + p + "\n")
            dup_bytes += size
        counts[status] += 1
        rep.write(f"{status}\t{p}\t{match}\n")

print(dict(counts), f"duplicate bytes: {dup_bytes / 2**30:.1f} GiB")
