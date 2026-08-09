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
failures=0

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
trap 'ret=$?; if [ "$KEEP" -eq 1 ] || [ "${failures:-0}" -ne 0 ]; then echo "Preserving temporary workspace: ${TMPROOT:-}"; echo "Preserving results workspace: ${RESULTS_DIR:-}"; else chmod -R u+rwx "$TMPROOT" "$RESULTS_DIR" || true; rm -rf "$TMPROOT" "$RESULTS_DIR"; fi; exit $ret' EXIT

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
mkdir -p "$TMPROOT/dir_sort"
mkdir -p "$TMPROOT/dir_time_tie"
mkdir -p "$TMPROOT/dir_grouped/visible_dir"
mkdir -p "$TMPROOT/dir_grouped/.hidden_dir"
mkdir -p "$TMPROOT/dir_multi_a"
mkdir -p "$TMPROOT/dir_multi_b"
mkdir -p "$TMPROOT/dir_multi_c"
mkdir -p "$TMPROOT/dir_dates"
mkdir -p "$TMPROOT/dir_empty"

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
printf "n" > "$TMPROOT/dir_spaces/"$'file\nnewline'

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

# sorting fixtures
printf 'oldest\n' > "$TMPROOT/dir_sort/oldest.txt"
printf 'middle\n' > "$TMPROOT/dir_sort/middle.txt"
printf 'newest\n' > "$TMPROOT/dir_sort/newest.txt"
touch -t 202001010101 "$TMPROOT/dir_sort/oldest.txt"
touch -t 202401010101 "$TMPROOT/dir_sort/middle.txt"
touch -t 202501010101 "$TMPROOT/dir_sort/newest.txt"

printf 'tie1\n' > "$TMPROOT/dir_time_tie/alpha_tie.txt"
printf 'tie2\n' > "$TMPROOT/dir_time_tie/beta_tie.txt"
touch -t 202401010101 "$TMPROOT/dir_time_tie/alpha_tie.txt"
touch -t 202401010101 "$TMPROOT/dir_time_tie/beta_tie.txt"

printf 'visible\n' > "$TMPROOT/dir_grouped/visible.txt"
printf 'hidden\n' > "$TMPROOT/dir_grouped/.hidden.txt"
printf 'child\n' > "$TMPROOT/dir_grouped/visible_dir/child.txt"

printf 'file-a\n' > "$TMPROOT/dir_multi_a/fileA.txt"
printf 'file-b\n' > "$TMPROOT/dir_multi_b/fileB.txt"
printf 'file-c\n' > "$TMPROOT/dir_multi_c/fileC.txt"

printf 'old\n' > "$TMPROOT/dir_dates/old.txt"
printf 'recent\n' > "$TMPROOT/dir_dates/recent.txt"
touch -t 202001010101 "$TMPROOT/dir_dates/old.txt"
touch -t 202501010101 "$TMPROOT/dir_dates/recent.txt"

normalize_long() {
    sed 's/  */ /g' | awk '{
        if ($1 == "total") {
            print "total"
            next
        }
        mode = $1;
        sub(/[@+]$/, "", mode);
        name = "";
        for (i = 9; i <= NF; i++) {
            name = (i == 9) ? $i : name " " $i
        }
        printf "%s %s %s %s %s %s %s\n", mode, $2, $5, $6, $7, $8, name
    }'
}

# helper: run pair of commands and compare outputs
run_and_compare() {
    local testname="$1"
    local ls_flags="$2"
    local ft_flags="$3"
    local target="$4"
    local ls_output="$RESULTS_DIR/${testname}.ls.out"
    local ft_output="$RESULTS_DIR/${testname}.ft.out"
    local ls_norm="$RESULTS_DIR/${testname}.ls.norm"
    local ft_norm="$RESULTS_DIR/${testname}.ft.norm"

    printf '\n=== Test: %s (ls_flags: %s) (ft_flags: %s) on %s ===\n' "$testname" "$ls_flags" "$ft_flags" "$target"
    # Use C locale for deterministic ordering
    LC_ALL=C "$LS_BIN" $ls_flags "$target" | sed -n '1,2000p' > "$ls_output" 2>&1

    # Run ft_ls and capture exit status
    "$FT_BIN" $ft_flags "$target" > "$ft_output" 2>"$RESULTS_DIR/${testname}.ft.err"
    ft_status=$?
    if [ $ft_status -ne 0 ]; then
        echo "ft_ls exited with status $ft_status (see $RESULTS_DIR/${testname}.ft.err)"
    fi

    if [ -s "$RESULTS_DIR/${testname}.ft.err" ]; then
        echo "ft_ls stderr:"
        sed -n '1,80p' "$RESULTS_DIR/${testname}.ft.err"
    fi

    if [[ "$ls_flags" == *"l"* ]]; then
        normalize_long < "$ls_output" > "$ls_norm"
        normalize_long < "$ft_output" > "$ft_norm"
        if diff -u "$ls_norm" "$ft_norm" > "$RESULTS_DIR/${testname}.diff"; then
            echo "[PASS] output match"
        else
            echo "[FAIL] output differs -> $RESULTS_DIR/${testname}.diff"
            failures=$((failures+1))
        fi
    else
        if diff -u "$ls_output" "$ft_output" > "$RESULTS_DIR/${testname}.diff"; then
            echo "[PASS] output match"
        else
            echo "[FAIL] output differs -> $RESULTS_DIR/${testname}.diff"
            failures=$((failures+1))
        fi
    fi

    run_valgrind_case "$testname" "$FT_BIN" $ft_flags "$target"
}

run_and_compare_args() {
    local testname="$1"
    local ls_flags="$2"
    local ft_flags="$3"
    shift 3
    local -a args=("$@")

    printf '\n=== Test: %s (ls_flags: %s) (ft_flags: %s) on %s ===\n' "$testname" "$ls_flags" "$ft_flags" "${args[*]}"
    LC_ALL=C "$LS_BIN" $ls_flags "${args[@]}" | sed -n '1,2000p' > "$RESULTS_DIR/${testname}.ls.out" 2>&1

    "$FT_BIN" $ft_flags "${args[@]}" > "$RESULTS_DIR/${testname}.ft.out" 2>"$RESULTS_DIR/${testname}.ft.err"
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

    run_valgrind_case "$testname" "$FT_BIN" $ft_flags "${args[@]}"
}

run_valgrind_case() {
    local testname="$1"
    shift
    local -a cmd=("$@")

    if [ "$NO_VALGRIND" -eq 0 ] && command -v valgrind >/dev/null 2>&1; then
        echo "Running valgrind for $testname..."
        vglog="$RESULTS_DIR/valgrind_${testname}.log"
        valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --log-file="$vglog" "${cmd[@]}" >/dev/null 2>&1 || true

        if [ ! -s "$vglog" ]; then
            echo "[WARN] valgrind produced no log ($vglog)"
            failures=$((failures+1))
        elif grep -Eq '(definitely|indirectly) lost: [1-9][0-9]* bytes' "$vglog"; then
            echo "[FAIL] valgrind: memory leak detected (see $vglog)"
            failures=$((failures+1))
        else
            echo "[PASS] valgrind: clean memory"
        fi
    elif [ "$NO_VALGRIND" -eq 0 ]; then
        echo "valgrind not installed; skipping valgrind for $testname"
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

# Sorting tests
run_and_compare time_sort "-t" "-t" "$TMPROOT/dir_sort"
run_and_compare reverse_sort "-r" "-r" "$TMPROOT/dir_sort"
run_and_compare reverse_time_sort "-rt" "-rt" "$TMPROOT/dir_sort"
run_and_compare time_tiebreak "-t" "-t" "$TMPROOT/dir_time_tie"

# Flag grouping / combination tests
run_and_compare grouped_options "-laR" "-laR" "$TMPROOT/dir_grouped"
run_and_compare separated_options "-l -r -R" "-l -r -R" "$TMPROOT/dir_grouped"

# Multiple path and mixed input tests
run_and_compare_args multiple_dirs "-1" "" "$TMPROOT/dir_multi_b" "$TMPROOT/dir_multi_a" "$TMPROOT/dir_multi_c"
run_and_compare_args mixed_files_dirs "-1" "" "$TMPROOT/dir_multi_a/fileA.txt" "$TMPROOT/dir_multi_a" "$TMPROOT/dir_multi_b/fileB.txt" "$TMPROOT/dir_multi_b"

# Default path fallback
printf '\n=== Test: default_path (ls_flags: ) (ft_flags: ) on . ===\n'
( cd "$TMPROOT" && LC_ALL=C "$LS_BIN" > "$RESULTS_DIR/default_path.ls.out" 2>&1 )
( cd "$TMPROOT" && "$FT_BIN" > "$RESULTS_DIR/default_path.ft.out" 2>"$RESULTS_DIR/default_path.ft.err" )
if diff -u "$RESULTS_DIR/default_path.ls.out" "$RESULTS_DIR/default_path.ft.out" > "$RESULTS_DIR/default_path.diff"; then
    echo "[PASS] output match"
else
    echo "[FAIL] output differs -> $RESULTS_DIR/default_path.diff"
    failures=$((failures+1))
fi
run_valgrind_case default_path "$FT_BIN"

# Tests that check behavior rather than exact textual match
printf '\n=== Edge test: unreadable directory ===\n'
if [ "$(id -u)" -eq 0 ]; then
    echo "[SKIP] unreadable directory test skipped (running as root)"
else
    LC_ALL=C "$LS_BIN" -1 "$TMPROOT/dir_unreadable" > "$TMPROOT/unreadable.ls.out" 2>&1 || true
    "$FT_BIN" "$TMPROOT/dir_unreadable" > "$TMPROOT/unreadable.ft.out" 2>"$TMPROOT/unreadable.ft.err" || true
    if [ -s "$TMPROOT/unreadable.ft.err" ] || [ -s "$TMPROOT/unreadable.ls.out" ]; then
        echo "[PASS] unreadable directory produced error output (see logs)"
    else
        echo "[FAIL] unreadable directory produced no error output"
        failures=$((failures+1))
    fi
fi

printf '\n=== Edge test: invalid option ===\n'
LC_ALL=C "$LS_BIN" -z > "$TMPROOT/invalid_option.ls.out" 2>"$TMPROOT/invalid_option.ls.err"
ls_status=$?
"$FT_BIN" -z > "$TMPROOT/invalid_option.ft.out" 2>"$TMPROOT/invalid_option.ft.err"
ft_status=$?
if [ "$ft_status" -eq 0 ] || [ "$ls_status" -eq 0 ]; then
    echo "[FAIL] invalid option should fail with a non-zero exit code"
    failures=$((failures+1))
elif [ ! -s "$TMPROOT/invalid_option.ft.err" ]; then
    echo "[FAIL] ft_ls did not print an error for an invalid option"
    failures=$((failures+1))
else
    echo "[PASS] invalid option produced stderr and a non-zero exit code"
fi

# Broken symlink handling
printf '\n=== Edge test: broken symlink ===\n'
LC_ALL=C "$LS_BIN" -l "$TMPROOT/dir_symlinks" > "$TMPROOT/broken_symlink.ls.out" 2>&1
"$FT_BIN" -l "$TMPROOT/dir_symlinks" > "$TMPROOT/broken_symlink.ft.out" 2>"$TMPROOT/broken_symlink.ft.err"
normalize_long < "$TMPROOT/broken_symlink.ls.out" > "$TMPROOT/broken_symlink.ls.norm"
normalize_long < "$TMPROOT/broken_symlink.ft.out" > "$TMPROOT/broken_symlink.ft.norm"
if diff -u "$TMPROOT/broken_symlink.ls.norm" "$TMPROOT/broken_symlink.ft.norm" > "$TMPROOT/broken_symlink.diff"; then
    echo "[PASS] broken symlink output matches"
else
    echo "[FAIL] broken symlink output differs -> $TMPROOT/broken_symlink.diff"
    failures=$((failures+1))
fi

# Old-file date formatting
printf '\n=== Edge test: old file date ===\n'
LC_ALL=C "$LS_BIN" -l "$TMPROOT/dir_dates" > "$TMPROOT/old_file_date.ls.out" 2>&1
"$FT_BIN" -l "$TMPROOT/dir_dates" > "$TMPROOT/old_file_date.ft.out" 2>"$TMPROOT/old_file_date.ft.err"
normalize_long < "$TMPROOT/old_file_date.ls.out" > "$TMPROOT/old_file_date.ls.norm"
normalize_long < "$TMPROOT/old_file_date.ft.out" > "$TMPROOT/old_file_date.ft.norm"
if diff -u "$TMPROOT/old_file_date.ls.norm" "$TMPROOT/old_file_date.ft.norm" > "$TMPROOT/old_file_date.diff"; then
    echo "[PASS] old file date output matches"
else
    echo "[FAIL] old file date output differs -> $TMPROOT/old_file_date.diff"
    failures=$((failures+1))
fi

# Empty directory handling
printf '\n=== Edge test: empty directory ===\n'
LC_ALL=C "$LS_BIN" -l "$TMPROOT/dir_empty" > "$TMPROOT/empty_dir.ls.out" 2>&1
"$FT_BIN" -l "$TMPROOT/dir_empty" > "$TMPROOT/empty_dir.ft.out" 2>"$TMPROOT/empty_dir.ft.err"
normalize_long < "$TMPROOT/empty_dir.ls.out" > "$TMPROOT/empty_dir.ls.norm"
normalize_long < "$TMPROOT/empty_dir.ft.out" > "$TMPROOT/empty_dir.ft.norm"
if diff -u "$TMPROOT/empty_dir.ls.norm" "$TMPROOT/empty_dir.ft.norm" > "$TMPROOT/empty_dir.diff"; then
    echo "[PASS] empty directory output matches"
else
    echo "[FAIL] empty directory output differs -> $TMPROOT/empty_dir.diff"
    failures=$((failures+1))
fi

# Exit code check for partial failures
printf '\n=== Edge test: partial path failures ===\n'
LC_ALL=C "$LS_BIN" "$TMPROOT/dir_multi_a" "$TMPROOT/does_not_exist" "$TMPROOT/dir_multi_b" > "$TMPROOT/partial_paths.ls.out" 2>"$TMPROOT/partial_paths.ls.err"
ls_status=$?
"$FT_BIN" "$TMPROOT/dir_multi_a" "$TMPROOT/does_not_exist" "$TMPROOT/dir_multi_b" > "$TMPROOT/partial_paths.ft.out" 2>"$TMPROOT/partial_paths.ft.err"
ft_status=$?
if [ "$ft_status" -eq 0 ] || [ "$ls_status" -eq 0 ]; then
    echo "[FAIL] expected non-zero exit status on error"
    failures=$((failures+1))
fi
if diff -u "$TMPROOT/partial_paths.ls.out" "$TMPROOT/partial_paths.ft.out" > "$TMPROOT/partial_paths.diff"; then
    echo "[PASS] partial paths stdout matches"
else
    echo "[FAIL] partial paths stdout differs -> $TMPROOT/partial_paths.diff"
    failures=$((failures+1))
fi
if grep -q 'does_not_exist' "$TMPROOT/partial_paths.ft.err"; then
    echo "[PASS] partial paths stderr reports the missing path"
else
    echo "[FAIL] partial paths stderr did not report the missing path"
    failures=$((failures+1))
fi
run_valgrind_case partial_path_failures "$FT_BIN" "$TMPROOT/dir_multi_a" "$TMPROOT/does_not_exist" "$TMPROOT/dir_multi_b"

printf '\n=== Edge test: exit status ===\n'
LC_ALL=C "$LS_BIN" "$TMPROOT/dir_files" "$TMPROOT/does_not_exist" > "$TMPROOT/exit.ls.out" 2>"$TMPROOT/exit.ls.err"
ls_status=$?
"$FT_BIN" "$TMPROOT/dir_files" "$TMPROOT/does_not_exist" > "$TMPROOT/exit.ft.out" 2>"$TMPROOT/exit.ft.err"
ft_status=$?
if [ "$ft_status" -eq 0 ] || [ "$ls_status" -eq 0 ]; then
    echo "[FAIL] expected non-zero exit status on error"
    failures=$((failures+1))
else
    echo "[PASS] exit code matches system ls semantics"
fi
run_valgrind_case exit_status "$FT_BIN" "$TMPROOT/dir_files" "$TMPROOT/does_not_exist"

# Long listing normalization: compare selected fields (mode, nlink, size, name)
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

# SUID / SGID / Sticky bit fixtures
mkdir -p "$TMPROOT/dir_special"
touch "$TMPROOT/dir_special/suid_exec" && chmod 4755 "$TMPROOT/dir_special/suid_exec"
touch "$TMPROOT/dir_special/suid_noexec" && chmod 4055 "$TMPROOT/dir_special/suid_noexec"
touch "$TMPROOT/dir_special/sgid_exec" && chmod 2755 "$TMPROOT/dir_special/sgid_exec"
mkdir -p "$TMPROOT/dir_special/sticky_dir" && chmod 1777 "$TMPROOT/dir_special/sticky_dir"

# 1. Test SUID / SGID / Sticky bit w -l
run_and_compare special_bits "-l" "-l" "$TMPROOT/dir_special"

# 2. Test -r oraz -t z kilkoma argumentami na raz
run_and_compare_args multi_arg_reverse "-r" "-r" "$TMPROOT/dir_multi_a" "$TMPROOT/dir_multi_b" "$TMPROOT/dir_multi_c"
run_and_compare_args multi_arg_time "-t" "-t" "$TMPROOT/dir_sort/oldest.txt" "$TMPROOT/dir_sort/newest.txt" "$TMPROOT/dir_sort/middle.txt"
run_and_compare_args multi_arg_time_reverse "-rt" "-rt" "$TMPROOT/dir_multi_a" "$TMPROOT/dir_multi_b"