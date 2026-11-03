#!/usr/bin/env bash
# borg-backup -- single entry point for all borg jobs on this host (run as root, by systemd).
#
#   borg-backup backup <job>              create + prune + compact
#   borg-backup check quick|full <job>    borg check (full = --verify-data), then restore-test
#   borg-backup restore-test <job>        extract a random sample from the latest archive, hash-compare with live files
#   borg-backup dry-run <job>             list what the excludes would drop (repo must exist)
#   borg-backup status                    print the status file
#   borg-backup mark-failed <unit>        used by backup-failed@.service (OnFailure)
#
# Jobs:    /etc/borg/jobs/<job>.conf     Passphrase: /etc/borg/passphrase (0600 root)
# Logs:    /var/log/borg/<job>-<cmd>-<timestamp>.log (full borg output); journal gets summary lines only
# Status:  /var/lib/borg/status (key=value, read by /etc/update-motd.d/40-backup-status)
set -uo pipefail
umask 077

# BORG_BACKUP_ROOT lets the test suite run everything under a scratch dir as a normal user.
ROOT=${BORG_BACKUP_ROOT:-}
JOBS_DIR=$ROOT/etc/borg/jobs
PASSFILE=$ROOT/etc/borg/passphrase
KEYMARK_DIR=$ROOT/etc/borg
STATUS_DIR=$ROOT/var/lib/borg
STATUS_FILE=$STATUS_DIR/status
LOG_DIR=$ROOT/var/log/borg
LOCK_DIR=${ROOT:+$ROOT/run}${ROOT:-/run/lock}
LOG_KEEP_DAYS=${LOG_KEEP_DAYS:-180}

usage() { sed -n '2,13p' "$0" >&2; exit 2; }
die()   { echo "borg-backup: $*" >&2; exit 2; }

CMD=${1:-}; [[ $# -gt 0 ]] && shift
[[ -n $CMD ]] || usage
[[ $EUID -eq 0 || -n $ROOT ]] || die "must run as root"

TS=$(date +%Y%m%d-%H%M%S)
now()   { date -Is; }
epoch() { date +%s; }
# borg return codes (docs: usage/general, "Return codes"):
#   0      success
#   1      warning  -- the operation reached its normal end but logged warnings (check the log)
#   2      error    -- the operation did not reach its normal end
#   128+N  killed by signal N (137 = kill -9)
# borg >= 1.4 can also emit "modern" codes: 3..99 specific errors, 100..127 specific warnings.
# Everything is collapsed to a severity: 0 ok / 1 warning / 2 error. The script's own exit code is
# the severity, so the units only need SuccessExitStatus=1 to keep warnings from tripping OnFailure.
rc_severity() {
    local rc=$1
    if   (( rc == 0 )); then echo 0
    elif (( rc == 1 || (rc >= 100 && rc <= 127) )); then echo 1
    else echo 2; fi
}
rc_describe() {
    local rc=$1
    if   (( rc == 0 ));   then echo "rc 0 (success)"
    elif (( rc == 1 ));   then echo "rc 1 (warning: completed, but check the log)"
    elif (( rc == 2 ));   then echo "rc 2 (error: did not complete)"
    elif (( rc >= 128 )); then echo "rc $rc (killed by signal $((rc - 128)))"
    elif (( rc >= 100 )); then echo "rc $rc (warning)"
    else                       echo "rc $rc (error)"; fi
}
worst() { local w=0 x; for x in "$@"; do x=$(rc_severity "$x"); (( x > w )) && w=$x; done; echo "$w"; }
state_for_rc() { case $(rc_severity "$1") in 0) echo ok;; 1) echo warning;; *) echo failed;; esac; }

install -d -m 0755 "$STATUS_DIR"
install -d -m 0750 "$LOG_DIR"
[[ -f $STATUS_FILE ]] || { : > "$STATUS_FILE"; chmod 644 "$STATUS_FILE"; }

# ---------------------------------------------------------------------------
# status file: atomic rewrite, keys are "<job>_<name>"
# ---------------------------------------------------------------------------
status_set() {   # status_set key value [key value ...]
    local tmp; tmp=$(mktemp "$STATUS_DIR/.status.XXXXXX") || return 1
    cp "$STATUS_FILE" "$tmp"
    while (( $# >= 2 )); do
        local k=$1 v=$2; shift 2
        { grep -v -- "^$k=" "$tmp" || :; printf '%s=%s\n' "$k" "$v"; } > "$tmp.n" && mv -f "$tmp.n" "$tmp"
    done
    chmod 644 "$tmp" && mv -f "$tmp" "$STATUS_FILE"
}

# ---------------------------------------------------------------------------
# job loading
# ---------------------------------------------------------------------------
load_job() {
    JOB=${1:-}
    [[ -n $JOB && $JOB =~ ^[a-z0-9-]+$ ]] || die "bad job name '${JOB}'"
    local conf="$JOBS_DIR/$JOB.conf"
    [[ -r $conf ]] || die "missing $conf (run: sudo ./homelab.sh --skip-docker --skip-secrets)"
    # defaults
    ENABLED=no REPO="" MOUNTPOINT="" EXCLUDES="" COMPRESSION=lz4
    KEEP_DAILY=7 KEEP_WEEKLY=4 KEEP_MONTHLY=6 CHECK_QUICK_ARGS="" LOCK_WAIT=21600
    RESTORE_TEST_PER_DIR=20 RESTORE_TEST_MAX_BYTES=67108864
    SOURCES=() RESTORE_TEST_DIRS=() PRE_HOOKS=() POST_HOOKS=()
    # shellcheck source=/dev/null
    source "$conf"
    [[ -n $REPO ]] || die "$conf: REPO not set"
    (( ${#SOURCES[@]} > 0 )) || die "$conf: SOURCES empty"
    [[ -n $EXCLUDES ]] || die "$conf: EXCLUDES not set"
    export BORG_PASSCOMMAND="cat $PASSFILE"
    export BORG_RSH="${BORG_RSH:-ssh -o BatchMode=yes}"
    [[ -n ${BORG_REMOTE_PATH:-} ]] && export BORG_REMOTE_PATH
    export BORG_HOSTNAME_IS_UNIQUE=yes
    ARCHIVE_GLOB="{hostname}-$JOB-*"
    install -d -m 0755 "$LOCK_DIR"; LOCK="$LOCK_DIR/borg-$JOB.lock"
    LOG="$LOG_DIR/$JOB-$CMD-$TS.log"
}

log()  { printf '%s [%s] %s\n' "$(date -Is)" "$JOB" "$*" | tee -a "$LOG"; }   # journal + file
logf() { printf '%s [%s] %s\n' "$(date -Is)" "$JOB" "$*" >> "$LOG"; }         # file only
run()  { logf "+ $*"; "$@" >> "$LOG" 2>&1; }                                  # full output to file only

is_ssh_repo() { [[ $REPO == ssh://* || $REPO == *:* && $REPO != /* ]]; }

job_enabled_or_exit() {
    if [[ $ENABLED != yes ]]; then
        echo "borg-backup: job '$JOB' is disabled (ENABLED=$ENABLED in $JOBS_DIR/$JOB.conf); nothing to do"
        exit 0
    fi
}

rotate_logs() {
    find "$LOG_DIR" -name '*.log' -mtime +7 -exec gzip -q {} + 2>/dev/null || :
    find "$LOG_DIR" -name '*.log.gz' -mtime +"$LOG_KEEP_DAYS" -delete 2>/dev/null || :
    : > "$LOG"; chmod 640 "$LOG"
    ln -sfn "$LOG" "$LOG_DIR/$JOB-$CMD-latest.log"
}

take_lock() {
    exec 9>>"$LOCK"
    flock -w "$LOCK_WAIT" 9 || { log "FAILED: another borg-backup job for '$JOB' held the lock for >${LOCK_WAIT}s"; return 1; }
}

preflight() {
    local ok=0
    if [[ -n $MOUNTPOINT ]] && ! mountpoint -q "$MOUNTPOINT"; then
        log "FAILED: $MOUNTPOINT is not mounted"; ok=1
    fi
    [[ -r $PASSFILE ]]  || { log "FAILED: $PASSFILE missing or unreadable"; ok=1; }
    [[ -r $EXCLUDES ]]  || { log "FAILED: excludes file $EXCLUDES missing"; ok=1; }
    if (( ok == 0 )); then
        if is_ssh_repo; then
            run borg info "$REPO" || { log "FAILED: cannot reach repository $REPO"; ok=1; }
        else
            [[ -f $REPO/config ]] || { log "FAILED: no borg repository at $REPO (borg init --encryption=repokey-blake2 $REPO)"; ok=1; }
        fi
    fi
    [[ -f $KEYMARK_DIR/key-exported-$JOB ]] || log "WARNING: borg key for '$JOB' not exported yet (see docs/backup-restore-drill.md), then: touch /etc/borg/key-exported-$JOB"
    return $ok
}

run_hooks() {   # run_hooks pre|post
    local -n hooks="${1^^}_HOOKS"; local h rc
    for h in "${hooks[@]}"; do
        [[ -x $h ]] || { log "WARNING: $1-hook $h not executable, skipped"; continue; }
        run "$h"; rc=$?
        if (( rc == 0 )); then log "$1-hook $h ok"; else log "WARNING: $1-hook $h exited $rc"; fi
    done
}

create_args() {
    printf '%s\n' --verbose --filter AME --list --stats --show-rc \
        --compression "$COMPRESSION" --one-file-system \
        --exclude-caches --exclude-if-present .nobackup --exclude-from "$EXCLUDES"
}

latest_archive() {
    borg list --last 1 --short --glob-archives "$ARCHIVE_GLOB" "$REPO" 2>>"$LOG"
}

# ---------------------------------------------------------------------------
# backup
# ---------------------------------------------------------------------------
do_backup() {
    status_set "${JOB}_backup_state" running "${JOB}_backup_last_start" "$(now)" "${JOB}_backup_log" "$LOG"
    if ! preflight; then
        status_set "${JOB}_backup_state" failed "${JOB}_backup_rc" 2 "${JOB}_backup_last_end" "$(now)" "${JOB}_backup_last_epoch" "$(epoch)"
        return 2
    fi
    run_hooks pre
    local -a args; mapfile -t args < <(create_args)
    local c p k rc archive
    log "borg create -> $REPO"
    run borg create "${args[@]}" "$REPO::{hostname}-$JOB-{now}" "${SOURCES[@]}"; c=$?
    log "borg create: $(rc_describe "$c")"
    grep -E '^(Duration|Number of files|This archive|All archives):' "$LOG" | tail -4 | while IFS= read -r l; do log "  $l"; done
    log "borg prune"
    run borg prune --list --show-rc --glob-archives "$ARCHIVE_GLOB" \
        --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY" "$REPO"; p=$?
    log "borg prune: $(rc_describe "$p")"
    log "borg compact"
    run borg compact --show-rc "$REPO"; k=$?
    log "borg compact: $(rc_describe "$k")"
    run_hooks post
    rc=$(worst "$c" "$p" "$k")      # severity 0/1/2; the raw borg rcs are kept in *_create_rc etc.
    archive=$(latest_archive || echo unknown)
    status_set "${JOB}_create_rc" "$c" "${JOB}_prune_rc" "$p" "${JOB}_compact_rc" "$k" \
               "${JOB}_backup_rc" "$rc" "${JOB}_archive" "$archive" \
               "${JOB}_backup_state" "$(state_for_rc "$rc")" \
               "${JOB}_backup_last_end" "$(now)" "${JOB}_backup_last_epoch" "$(epoch)"
    log "backup finished: $(state_for_rc "$rc") (create=$c prune=$p compact=$k) archive=$archive log=$LOG"
    return "$rc"
}

# ---------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------
do_check() {   # $1 = quick|full
    local mode=$1 rc
    local -a extra=()
    if [[ $mode == full ]]; then extra=(--verify-data); else read -r -a extra <<< "$CHECK_QUICK_ARGS"; fi
    status_set "${JOB}_check_state" running "${JOB}_check_mode" "$mode" "${JOB}_check_last_start" "$(now)" "${JOB}_check_log" "$LOG"
    if ! preflight; then
        status_set "${JOB}_check_state" failed "${JOB}_check_rc" 2 "${JOB}_check_last_end" "$(now)" "${JOB}_check_last_epoch" "$(epoch)"
        return 2
    fi
    log "borg check $mode -> $REPO"
    run borg check --show-rc --glob-archives "$ARCHIVE_GLOB" "${extra[@]}" "$REPO"; local raw=$?
    rc=$(rc_severity "$raw")
    status_set "${JOB}_check_state" "$(state_for_rc "$raw")" "${JOB}_check_rc" "$rc" "${JOB}_check_borg_rc" "$raw" \
               "${JOB}_check_last_end" "$(now)" "${JOB}_check_last_epoch" "$(epoch)"
    [[ $mode == full ]] && status_set "${JOB}_verify_last_epoch" "$(epoch)" "${JOB}_verify_rc" "$rc"
    log "check finished: $(state_for_rc "$raw") -- borg check $(rc_describe "$raw") log=$LOG"
    do_restore_test; local r=$?
    return "$(worst "$rc" "$r")"
}

# ---------------------------------------------------------------------------
# restore test: sample files that ARE in the latest archive, extract, compare
# ---------------------------------------------------------------------------
do_restore_test() {
    local archive start tmp d total=0 ok=0 bad=0 missing=0 skipped=0 p rc xrc=0
    status_set "${JOB}_restore_state" running "${JOB}_restore_log" "$LOG"
    restore_fail() { log "restore-test FAILED: $*"; status_set "${JOB}_restore_state" failed "${JOB}_restore_rc" 2 "${JOB}_restore_last_epoch" "$(epoch)"; return 2; }
    archive=$(latest_archive)
    [[ -n $archive ]] || { restore_fail "no archive matching $ARCHIVE_GLOB in $REPO"; return $?; }
    start=$(borg info --json "$REPO::$archive" 2>>"$LOG" | jq -r '.archives[0].start'); start=${start%%.*}
    [[ -n $start && $start != null ]] || { restore_fail "could not read archive start time"; return $?; }
    tmp=$(mktemp -d /var/tmp/borg-restore-test.XXXXXX)
    (( ${#RESTORE_TEST_DIRS[@]} > 0 )) || RESTORE_TEST_DIRS=("${SOURCES[@]}")
    for d in "${RESTORE_TEST_DIRS[@]}"; do
        # regular files below the size cap, as recorded IN THE ARCHIVE (so excluded paths never show up as "missing")
        borg list --format '{mode}{TAB}{size}{TAB}{path}{NUL}' "$REPO::$archive" "${d#/}" 2>>"$LOG" \
            | awk -v RS='\0' -v ORS='\0' -F'\t' -v max="$RESTORE_TEST_MAX_BYTES" 'substr($1,1,1)=="-" && $2+0 < max+0 {print $3}' \
            | shuf -z -n "$RESTORE_TEST_PER_DIR" >> "$tmp/sample0"
    done
    tr '\0' '\n' < "$tmp/sample0" > "$tmp/sample"
    total=$(grep -c . "$tmp/sample" || :)
    log "restore-test: extracting $total sample files from $archive (started $start)"
    if (( total > 0 )); then
        mkdir "$tmp/out"
        ( cd "$tmp/out" && xargs -d '\n' -a "$tmp/sample" borg extract --show-rc "$REPO::$archive" ) >> "$LOG" 2>&1; xrc=$?
        log "borg extract: $(rc_describe "$xrc")"
        while IFS= read -r p; do
            [[ -n $p ]] || continue
            if [[ ! -f $tmp/out/$p ]]; then missing=$((missing+1)); logf "MISSING $p"; continue; fi
            if [[ ! -f /$p ]] || [[ -n $(find "/$p" -newermt "$start" 2>/dev/null) ]]; then
                skipped=$((skipped+1)); logf "SKIPPED (changed/removed since archive) $p"; continue
            fi
            if [[ $(sha256sum < "/$p") == $(sha256sum < "$tmp/out/$p") ]]; then ok=$((ok+1)); else bad=$((bad+1)); logf "HASH MISMATCH $p"; fi
        done < "$tmp/sample"
    fi
    rm -rf "$tmp"
    rc=$(rc_severity "$xrc"); (( bad > 0 || missing > 0 || total == 0 )) && rc=2
    status_set "${JOB}_restore_state" "$(state_for_rc "$rc")" "${JOB}_restore_rc" "$rc" "${JOB}_restore_archive" "$archive" \
               "${JOB}_restore_ok" "$ok" "${JOB}_restore_total" "$total" "${JOB}_restore_bad" "$bad" \
               "${JOB}_restore_missing" "$missing" "${JOB}_restore_skipped" "$skipped" "${JOB}_restore_last_epoch" "$(epoch)"
    log "restore-test finished: ok=$ok bad=$bad missing=$missing skipped=$skipped of $total, extract $(rc_describe "$xrc") -> $(state_for_rc "$rc")"
    return "$rc"
}

# ---------------------------------------------------------------------------
# dry-run: what would be excluded
# ---------------------------------------------------------------------------
do_dry_run() {
    # shared args minus --stats (borg refuses it with --dry-run) and minus "--filter AME" (we want x = excluded)
    local -a args; mapfile -t args < <(create_args | grep -vx -e --stats -e --filter -e AME)
    echo "# Paths EXCLUDED by $EXCLUDES / --exclude-caches / --one-file-system for job '$JOB':"
    borg create --dry-run "${args[@]}" --list --filter x "$REPO::dryrun-$TS" "${SOURCES[@]}" 2>&1 \
        | sed -n 's/^x //p'
    return "${PIPESTATUS[0]}"
}

# ---------------------------------------------------------------------------
case $CMD in
    backup)
        load_job "${1:-}"; job_enabled_or_exit; rotate_logs; take_lock || exit 2; do_backup ;;
    check)
        mode=${1:-}; [[ $mode == quick || $mode == full ]] || usage
        load_job "${2:-}"; job_enabled_or_exit; rotate_logs; take_lock || exit 2; do_check "$mode" ;;
    restore-test)
        load_job "${1:-}"; job_enabled_or_exit; rotate_logs; take_lock || exit 2; do_restore_test ;;
    dry-run)
        load_job "${1:-}"; LOG=/dev/null; do_dry_run ;;
    status)
        cat "$STATUS_FILE" ;;
    mark-failed)
        unit=${1:-}; [[ -n $unit ]] || usage
        # backup@full.service -> job=full kind=backup ; backup-check@full.service -> kind=check
        job=${unit#*@}; job=${job%.service}; kind=${unit%%@*}
        status_set unit_failed "$unit" unit_failed_epoch "$(epoch)"
        case $kind in
            backup)                       status_set "${job}_backup_state" failed ;;
            backup-check|backup-verify)   status_set "${job}_check_state" failed ;;
        esac ;;
    *) usage ;;
esac
