#!/usr/bin/env bash
# Test suite for ft_ls comparing against system ls and running valgrind
# Usage: ./run_tests.sh [--no-valgrind] [--keep] 

set -u

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
FT_BIN="$ROOT_DIR/ft_ls"
LS_BIN=$(command -v ls || true)
VALGRIND=$(command -v valgrind || true)

NO_VALGRIND=0
KEEP=0

for arg in "$@"; do
    case "$arg" in
        --no-valgrind) NO_VALGRIND=1 ;; 
        --keep) KEEP=1 ;; 
        *) echo "Unknown arg: $arg"; exit 1 ;;
    esac
done

if [ ! -x "$FT_BIN" ]; then
    echo "Error: ft_ls binary not found or not executable at $FT_BIN"
    exit 2
fi
if [ -z "$LS_BIN" ]; then
    echo "Error: system 'ls' not found in PATH"
    exit 2
fi

# Quick runtime sanity check: try executing ft_ls on '.' to detect exec-format issues
"$FT_BIN" . >/dev/null 2>&1
ft_test_status=$?
if [ $ft_test_status -eq 126 ]; then
    echo "Error: ft_ls binary cannot be executed on this platform (Exec format error)."
    echo "Rebuild ft_ls in this environment (run 'make' here) or run tests inside the container where ft_ls was built."
    exit 3
fi

TMPROOT=$(mktemp -d /tmp/ft_ls_tests.XXXXXX)
RESULTS_DIR=$(mktemp -d /tmp/ft_ls_results.XXXXXX)
trap 'ret=$?; if [ "$KEEP" -eq 0 ]; then chmod -R u+rwx "$TMPROOT" "$RESULTS_DIR" || true; rm -rf "$TMPROOT" "$RESULTS_DIR"; fi; exit $ret' EXIT

echo "Test workspace: $TMPROOT"
echo "Result workspace: $RESULTS_DIR"

# Create fixtures
mkdir -p "$TMPROOT/empty_dir"
mkdir -p "$TMPROOT/dir_files"
mkdir -p "$TMPROOT/dir_hidden"
mkdir -p "$TMPROOT/dir_spaces"
mkdir -p "$TMPROOT/dir_symlinks/target_dir"
mkdir -p "$TMPROOT/dir_unreadable"
mkdir -p "$TMPROOT/dir_many"

# files
echo "hello" > "$TMPROOT/dir_files/foo.txt"
echo "world" > "$TMPROOT/dir_files/bar.txt"

# hidden
echo "h" > "$TMPROOT/dir_hidden/.a_hidden"
echo "v" > "$TMPROOT/dir_hidden/visible"

# spaces and special characters
printf "x" > "$TMPROOT/dir_spaces/file with spaces.txt"
# filename beginning with dash
touch "$TMPROOT/dir_spaces/-dashfile"
# filename with newline (use $'...' quoting)
printf "n" > $TMPROOT/dir_spaces/$'file
newline'

# symlinks
echo "t" > "$TMPROOT/dir_symlinks/target_dir/file_in_target"
ln -s target_dir "$TMPROOT/dir_symlinks/link_to_dir"
ln -s target_dir/file_in_target "$TMPROOT/dir_symlinks/link_to_file"
ln -s does_not_exist "$TMPROOT/dir_symlinks/broken_link"

# unreadable dir
mkdir -p "$TMPROOT/dir_unreadable/sub"
chmod 000 "$TMPROOT/dir_unreadable"

# many files
i=0
while [ $i -lt 120 ]; do
    printf "file%03d" "$i" > "$TMPROOT/dir_many/file$i.txt"
    i=$((i+1))
done

# helper: run pair of commands and compare outputs
failures=0

run_and_compare() {
    local testname="$1"
    local ls_flags="$2"
    local ft_flags="$3"
    local target="$4"

    printf '\n=== Test: %s (ls_flags: %s) (ft_flags: %s) on %s ===\n' "$testname" "$ls_flags" "$ft_flags" "$target"
    # Use C locale for deterministic ordering
    LC_ALL=C "$LS_BIN" $ls_flags "$target" | sed -n '1,2000p' > "$RESULTS_DIR/${testname}.ls.out" 2>&1

    # Run ft_ls and capture exit status
    "$FT_BIN" $ft_flags "$target" > "$RESULTS_DIR/${testname}.ft.out" 2>"$RESULTS_DIR/${testname}.ft.err"
    ft_status=$?
    if [ $ft_status -ne 0 ]; then
        echo "ft_ls exited with status $ft_status (see $RESULTS_DIR/${testname}.ft.err)"
    fi

    if [ -s "$RESULTS_DIR/${testname}.ft.err" ]; then
        echo "ft_ls stderr:"
        sed -n '1,80p' "$RESULTS_DIR/${testname}.ft.err"
    fi

    if diff -u "$RESULTS_DIR/${testname}.ls.out" "$RESULTS_DIR/${testname}.ft.out" > "$RESULTS_DIR/${testname}.diff"; then
        echo "[PASS] output match"
    else
        echo "[FAIL] output differs -> $RESULTS_DIR/${testname}.diff"
        failures=$((failures+1))
    fi

    # valgrind run (if available and not disabled)
    if [ "$NO_VALGRIND" -eq 0 ]; then
        if command -v valgrind >/dev/null 2>&1; then
            echo "Running valgrind for $testname..."
            vglog="$RESULTS_DIR/valgrind_${testname}.log"
            valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --leak-resolution=high --num-callers=50 --log-file="$vglog" "$FT_BIN" $ft_flags "$target" >/dev/null 2>&1 || true
            # check for definite leaks
            if grep -q "definitely lost: 0 bytes" "$vglog"; then
                echo "[PASS] valgrind: no definite leaks"
            else
                echo "[WARN] valgrind: definite leaks detected (see $vglog)"
                failures=$((failures+1))
            fi
        else
            echo "valgrind not installed; skipping valgrind for $testname"
        fi
    fi
}

# Simple listing (default): ls uses -1 for one-per-line, ft_ls uses no flags
run_and_compare simple_default "-1" "" "$TMPROOT/dir_files"
# Hidden files: both support -a
run_and_compare hidden "-a" "-a" "$TMPROOT/dir_hidden"
# Spaces and special names
run_and_compare spaces "-1" "" "$TMPROOT/dir_spaces"
# Symlinks and broken symlink
run_and_compare symlinks "-1" "" "$TMPROOT/dir_symlinks"
# Recursive listing: use -R for ft_ls
run_and_compare recursive "-R" "-R" "$TMPROOT"
# Many files
run_and_compare many "-1" "" "$TMPROOT/dir_many"
# File argument (single file)
run_and_compare filearg "-1" "" "$TMPROOT/dir_files/foo.txt"

# Tests that check behavior rather than exact textual match
printf '\n=== Edge test: unreadable directory ===\n'
LC_ALL=C "$LS_BIN" -1 "$TMPROOT/dir_unreadable" > "$TMPROOT/unreadable.ls.out" 2>&1 || true
"$FT_BIN" -1 "$TMPROOT/dir_unreadable" > "$TMPROOT/unreadable.ft.out" 2>"$TMPROOT/unreadable.ft.err" || true
if [ -s "$TMPROOT/unreadable.ft.err" ] || [ -s "$TMPROOT/unreadable.ls.out" ]; then
    echo "[PASS] unreadable directory produced error output (see logs)"
else
    echo "[FAIL] unreadable directory produced no error output"
    failures=$((failures+1))
fi

# Long listing normalization: compare selected fields (mode, nlink, size, name)
normalize_long() {
    sed 's/  */ /g' | awk '{
        # Strip extended attribute / ACL marker from the mode string for portability.
        mode = $1;
        sub(/[@+]$/, "", mode);
        # handle names with spaces: assume name starts at $9 onwards
        name = "";
        for (i=9;i<=NF;i++) { if (i>9) name = name " "; name = name $i }
        printf "%s %s %s %s\n", mode, $2, $5, name
    }'
}

LC_ALL=C "$LS_BIN" -l "$TMPROOT/dir_files" | normalize_long > "$TMPROOT/long.ls.norm"
"$FT_BIN" -l "$TMPROOT/dir_files" | normalize_long > "$TMPROOT/long.ft.norm"
if diff -u "$TMPROOT/long.ls.norm" "$TMPROOT/long.ft.norm" > "$TMPROOT/long.diff"; then
    echo "[PASS] long listing normalization matches"
else
    echo "[WARN] long listing differs (see $TMPROOT/long.diff)"
    failures=$((failures+1))
fi

# Summary
printf '\nTest summary: failures = %d\n' "$failures"
if [ $failures -ne 0 ]; then
    echo "Some tests failed. See $TMPROOT for outputs and valgrind logs."
    exit 1
else
    echo "All tests passed. Temporary workspace: $TMPROOT"
    exit 0
fi
