#!/usr/bin/env bash

# ============================================================
# ft_ls evaluation test
# ============================================================
#
# Usage:
#   ./tests/run_tests.sh
#   ./tests/run_tests.sh --no-valgrind
#   ./tests/run_tests.sh --keep
#
# The script compares ft_ls with the system ls where possible.
# It also checks:
#   - author file
#   - Makefile
#   - required Makefile rules
#   - ft_ls executable
#   - Norminette
#   - suspicious/forbidden functions
#   - ls
#   - ls -a
#   - ls -l
#   - symbolic links
#   - ls -r
#   - ls -t
#   - multiple arguments
#   - SUID / SGID / sticky bit
#   - ls -R
#   - combined options
#   - invalid options
#   - nonexistent paths
#   - inaccessible directory
#   - broken symlinks
#   - old dates
#   - empty directories
#   - exit status
#   - Valgrind / memory leaks
# ============================================================

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FT_BIN="$ROOT_DIR/ft_ls"
LS_BIN="$(command -v ls || true)"
NORM_BIN="$(command -v norminette || true)"
VALGRIND_BIN="$(command -v valgrind || true)"

NO_VALGRIND=0
KEEP=0
FAILURES=0
TESTS=0
PASSES=0

for arg in "$@"; do
    case "$arg" in
        --no-valgrind)
            NO_VALGRIND=1
            ;;
        --keep)
            KEEP=1
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

TMPROOT="$(mktemp -d /tmp/ft_ls_tests.XXXXXX)"
RESULTS_DIR="$(mktemp -d /tmp/ft_ls_results.XXXXXX)"

cleanup()
{
    ret=$?

    if [ "$KEEP" -eq 1 ] || [ "$FAILURES" -ne 0 ]; then
        echo
        echo "Temporary files preserved:"
        echo "  tests:   $TMPROOT"
        echo "  results: $RESULTS_DIR"
    else
        rm -rf "$TMPROOT" "$RESULTS_DIR"
    fi

    exit "$ret"
}

trap cleanup EXIT

pass()
{
    TESTS=$((TESTS + 1))
    PASSES=$((PASSES + 1))
    echo "[PASS] $1"
}

fail()
{
    TESTS=$((TESTS + 1))
    FAILURES=$((FAILURES + 1))
    echo "[FAIL] $1"
}

info()
{
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

# ============================================================
# PRELIMINARY CHECKS
# ============================================================

info "PRELIMINARY CHECKS"

# ------------------------------------------------------------
# author
# ------------------------------------------------------------

if [ -s "$ROOT_DIR/author" ]; then
    pass "author file exists and is not empty"
else
    fail "author file is missing or empty"
fi

# ------------------------------------------------------------
# Makefile
# ------------------------------------------------------------

if [ -f "$ROOT_DIR/Makefile" ]; then
    pass "Makefile exists"

    for rule in all clean fclean re; do
        if grep -Eq "^${rule}:" "$ROOT_DIR/Makefile"; then
            pass "Makefile contains $rule rule"
        else
            fail "Makefile is missing $rule rule"
        fi
    done
else
    fail "Makefile is missing"
fi

# ------------------------------------------------------------
# Required Makefile functionality
# ------------------------------------------------------------

if [ -f "$ROOT_DIR/Makefile" ]; then
    echo
    echo "Testing Makefile..."

    if make -C "$ROOT_DIR" all >/dev/null 2>&1; then
        pass "make all"
    else
        fail "make all"
    fi

    if make -C "$ROOT_DIR" clean >/dev/null 2>&1; then
        pass "make clean"
    else
        fail "make clean"
    fi

    if make -C "$ROOT_DIR" all >/dev/null 2>&1; then
        pass "make all after clean"
    else
        fail "make all after clean"
    fi

    if make -C "$ROOT_DIR" fclean >/dev/null 2>&1; then
        pass "make fclean"
    else
        fail "make fclean"
    fi

    if make -C "$ROOT_DIR" re >/dev/null 2>&1; then
        pass "make re"
    else
        fail "make re"
    fi
fi

# ------------------------------------------------------------
# ft_ls binary
# ------------------------------------------------------------

if [ -x "$FT_BIN" ]; then
    pass "ft_ls exists and is executable"
else
    fail "ft_ls binary is missing or not executable"
fi

# ------------------------------------------------------------
# system ls
# ------------------------------------------------------------

if [ -n "$LS_BIN" ]; then
    pass "system ls found: $LS_BIN"
else
    fail "system ls not found"
fi

# ------------------------------------------------------------
# Norminette
# ------------------------------------------------------------

if [ -n "$NORM_BIN" ]; then
	echo
	echo "Checking Norminette..."

	NORM_OUTPUT="$RESULTS_DIR/norminette.out"

	(
		cd "$ROOT_DIR" || exit 1
		"$NORM_BIN" srcs/*.c includes/*.h \
			>"$NORM_OUTPUT" 2>&1
	)

	norm_status=$?

	if [ "$norm_status" -eq 0 ]; then
		pass "Norminette"
	else
		fail "Norminette reported errors"
		echo "----- Norminette output -----"
		sed -n '1,120p' "$NORM_OUTPUT"
		echo "-----------------------------"
	fi
else
	echo "[WARN] norminette is not installed; Norminette check skipped"
fi

# ------------------------------------------------------------
# Suspicious / clearly forbidden external execution functions
# ------------------------------------------------------------

echo
echo "Checking suspicious functions..."

SOURCE_FILES="$(find "$ROOT_DIR" -type f \( -name "*.c" -o -name "*.h" \) -print)"

FORBIDDEN_FOUND=0

FORBIDDEN_FUNCTIONS=(
    "system"
    "popen"
    "fork"
    "execve"
    "execl"
    "execlp"
    "execle"
    "execv"
    "execvp"
    "execvpe"
    "scandir"
)

for func in "${FORBIDDEN_FUNCTIONS[@]}"; do
    if [ -n "$SOURCE_FILES" ]; then
        if grep -REn --include='*.c' --include='*.h' \
            "(^|[^A-Za-z0-9_])${func}[[:space:]]*\(" \
            "$ROOT_DIR" >/dev/null 2>&1; then
            echo "[FAIL] suspicious/forbidden function detected: $func"
            grep -REn --include='*.c' --include='*.h' \
                "(^|[^A-Za-z0-9_])${func}[[:space:]]*\(" \
                "$ROOT_DIR" | head -10
            FORBIDDEN_FOUND=1
        fi
    fi
done

if [ "$FORBIDDEN_FOUND" -eq 0 ]; then
    pass "no clearly forbidden external-execution functions detected"
else
    fail "forbidden/suspicious functions detected"
fi

# ============================================================
# FUNCTIONAL TEST FIXTURES
# ============================================================

info "CREATING TEST FIXTURES"

mkdir -p "$TMPROOT/empty_dir"
mkdir -p "$TMPROOT/dir_files"
mkdir -p "$TMPROOT/dir_hidden"
mkdir -p "$TMPROOT/dir_spaces"
mkdir -p "$TMPROOT/dir_symlinks/target_dir"
mkdir -p "$TMPROOT/dir_unreadable/sub"
mkdir -p "$TMPROOT/dir_many"
mkdir -p "$TMPROOT/dir_sort"
mkdir -p "$TMPROOT/dir_time_tie"
mkdir -p "$TMPROOT/dir_grouped/visible_dir"
mkdir -p "$TMPROOT/dir_grouped/.hidden_dir"
mkdir -p "$TMPROOT/dir_multi_a"
mkdir -p "$TMPROOT/dir_multi_b"
mkdir -p "$TMPROOT/dir_multi_c"
mkdir -p "$TMPROOT/dir_dates"
mkdir -p "$TMPROOT/dir_special/sticky_dir"

# ------------------------------------------------------------
# Normal files
# ------------------------------------------------------------

printf 'hello\n' > "$TMPROOT/dir_files/foo.txt"
printf 'world\n' > "$TMPROOT/dir_files/bar.txt"

# ------------------------------------------------------------
# Hidden files
# ------------------------------------------------------------

printf 'hidden\n' > "$TMPROOT/dir_hidden/.hidden"
printf 'visible\n' > "$TMPROOT/dir_hidden/visible"

# ------------------------------------------------------------
# Spaces and special names
# ------------------------------------------------------------

printf 'space\n' > "$TMPROOT/dir_spaces/file with spaces.txt"
touch "$TMPROOT/dir_spaces/-dashfile"

# Filename containing newline
printf 'newline\n' > "$TMPROOT/dir_spaces/file"$'\n'"newline"

# ------------------------------------------------------------
# Symlinks
# ------------------------------------------------------------

printf 'target\n' > \
    "$TMPROOT/dir_symlinks/target_dir/file_in_target"

ln -s "target_dir" \
    "$TMPROOT/dir_symlinks/link_to_dir"

ln -s "target_dir/file_in_target" \
    "$TMPROOT/dir_symlinks/link_to_file"

ln -s "does_not_exist" \
    "$TMPROOT/dir_symlinks/broken_link"

# ------------------------------------------------------------
# Unreadable directory
# ------------------------------------------------------------

chmod 000 "$TMPROOT/dir_unreadable"

# ------------------------------------------------------------
# Many files
# ------------------------------------------------------------

i=0
while [ "$i" -lt 120 ]; do
    printf 'file %03d\n' "$i" > \
        "$TMPROOT/dir_many/file$i.txt"
    i=$((i + 1))
done

# ------------------------------------------------------------
# Sorting
# ------------------------------------------------------------

printf 'oldest\n' > "$TMPROOT/dir_sort/oldest.txt"
printf 'middle\n' > "$TMPROOT/dir_sort/middle.txt"
printf 'newest\n' > "$TMPROOT/dir_sort/newest.txt"

touch -t 202001010101 \
    "$TMPROOT/dir_sort/oldest.txt"

touch -t 202401010101 \
    "$TMPROOT/dir_sort/middle.txt"

touch -t 202501010101 \
    "$TMPROOT/dir_sort/newest.txt"

# ------------------------------------------------------------
# Equal timestamps
# ------------------------------------------------------------

printf 'alpha\n' > "$TMPROOT/dir_time_tie/alpha_tie.txt"
printf 'beta\n' > "$TMPROOT/dir_time_tie/beta_tie.txt"

touch -t 202401010101 \
    "$TMPROOT/dir_time_tie/alpha_tie.txt"

touch -t 202401010101 \
    "$TMPROOT/dir_time_tie/beta_tie.txt"

# ------------------------------------------------------------
# Recursive / grouped
# ------------------------------------------------------------

printf 'visible\n' > "$TMPROOT/dir_grouped/visible.txt"
printf 'hidden\n' > "$TMPROOT/dir_grouped/.hidden.txt"
printf 'child\n' > \
    "$TMPROOT/dir_grouped/visible_dir/child.txt"

printf 'hidden child\n' > \
    "$TMPROOT/dir_grouped/.hidden_dir/hidden_child.txt"

# ------------------------------------------------------------
# Multiple arguments
# ------------------------------------------------------------

printf 'A\n' > "$TMPROOT/dir_multi_a/fileA.txt"
printf 'B\n' > "$TMPROOT/dir_multi_b/fileB.txt"
printf 'C\n' > "$TMPROOT/dir_multi_c/fileC.txt"

# ------------------------------------------------------------
# Old dates
# ------------------------------------------------------------

printf 'old\n' > "$TMPROOT/dir_dates/old.txt"
printf 'recent\n' > "$TMPROOT/dir_dates/recent.txt"

touch -t 202001010101 \
    "$TMPROOT/dir_dates/old.txt"

touch -t 202501010101 \
    "$TMPROOT/dir_dates/recent.txt"

# ------------------------------------------------------------
# SUID / SGID / sticky
# ------------------------------------------------------------

touch "$TMPROOT/dir_special/suid_exec"
chmod 4755 "$TMPROOT/dir_special/suid_exec"

touch "$TMPROOT/dir_special/suid_noexec"
chmod 4055 "$TMPROOT/dir_special/suid_noexec"

touch "$TMPROOT/dir_special/sgid_exec"
chmod 2755 "$TMPROOT/dir_special/sgid_exec"

chmod 1777 "$TMPROOT/dir_special/sticky_dir"

# ============================================================
# HELPERS
# ============================================================

normalize_long()
{
    awk '
    BEGIN {
        OFS=" "
    }

    $1 == "total" {
        print "total"
        next
    }

    {
        mode = $1
        nlink = $2
        owner = $3
        group = $4
        size = $5

        name = $9

        for (i = 10; i <= NF; i++)
            name = name " " $i

        print mode, nlink, owner, group, size, name
    }
    '
}

compare_output()
{
    test_name="$1"
    ls_command="$2"
    ft_command="$3"

    ls_file="$RESULTS_DIR/${test_name}.ls"
    ft_file="$RESULTS_DIR/${test_name}.ft"
    diff_file="$RESULTS_DIR/${test_name}.diff"

    eval "$ls_command" >"$ls_file" 2>&1
    eval "$ft_command" >"$ft_file" 2>&1

    if diff -u "$ls_file" "$ft_file" >"$diff_file"; then
        pass "$test_name"
    else
        fail "$test_name"
        echo "  Diff: $diff_file"
        sed -n '1,80p' "$diff_file"
    fi
}

compare_long()
{
    test_name="$1"
    ls_command="$2"
    ft_command="$3"

    ls_file="$RESULTS_DIR/${test_name}.ls"
    ft_file="$RESULTS_DIR/${test_name}.ft"
    diff_file="$RESULTS_DIR/${test_name}.diff"

    eval "$ls_command" 2>&1 | normalize_long >"$ls_file"
    eval "$ft_command" 2>&1 | normalize_long >"$ft_file"

    if diff -u "$ls_file" "$ft_file" >"$diff_file"; then
        pass "$test_name"
    else
        fail "$test_name"
        echo "  Diff: $diff_file"
        sed -n '1,80p' "$diff_file"
    fi
}

check_exit_status()
{
    test_name="$1"
    expected="$2"
    shift 2

    "$@" >/dev/null 2>&1
    status=$?

    if [ "$status" -eq "$expected" ]; then
        pass "$test_name"
    else
        fail "$test_name (expected exit $expected, got $status)"
    fi
}

run_valgrind()
{
    test_name="$1"
    shift

    if [ "$NO_VALGRIND" -eq 1 ]; then
        return
    fi

    if [ -z "$VALGRIND_BIN" ]; then
        echo "[WARN] Valgrind not installed; skipping $test_name"
        return
    fi

    log="$RESULTS_DIR/valgrind_${test_name}.log"

    "$VALGRIND_BIN" \
        --leak-check=full \
        --show-leak-kinds=all \
        --track-origins=yes \
        --error-exitcode=42 \
        --log-file="$log" \
        "$@" >/dev/null 2>&1

    vg_status=$?

    if [ "$vg_status" -eq 42 ]; then
        fail "Valgrind $test_name"
        grep -E \
            "definitely lost|indirectly lost|ERROR SUMMARY" \
            "$log" | tail -10
    else
        if grep -Eq \
            "definitely lost: [1-9][0-9]* bytes|indirectly lost: [1-9][0-9]* bytes" \
            "$log"; then
            fail "Valgrind $test_name - memory leak detected"
            grep -E \
                "definitely lost|indirectly lost|ERROR SUMMARY" \
                "$log" | tail -10
        else
            pass "Valgrind $test_name - no memory leak detected"
        fi
    fi
}

# ============================================================
# BASIC TESTS
# ============================================================

info "BASIC TESTS"

# ls
compare_output \
    "ls_basic" \
    "LC_ALL=C \"$LS_BIN\" -1 \"$TMPROOT/dir_files\"" \
    "\"$FT_BIN\" \"$TMPROOT/dir_files\""

# ls -a
compare_output \
    "ls_a" \
    "LC_ALL=C \"$LS_BIN\" -a -1 \"$TMPROOT/dir_hidden\"" \
    "\"$FT_BIN\" -a \"$TMPROOT/dir_hidden\""

# ls -l directory
compare_long \
    "ls_l_directory" \
    "LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_files\"" \
    "\"$FT_BIN\" -l \"$TMPROOT/dir_files\""

# ls -l file
compare_long \
    "ls_l_file" \
    "LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_files/foo.txt\"" \
    "\"$FT_BIN\" -l \"$TMPROOT/dir_files/foo.txt\""

# ls -l default
compare_long \
    "ls_l_default" \
    "LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_files\"" \
    "\"$FT_BIN\" -l \"$TMPROOT/dir_files\""

# symbolic links
compare_output \
    "symlinks" \
    "LC_ALL=C \"$LS_BIN\" -1 \"$TMPROOT/dir_symlinks\"" \
    "\"$FT_BIN\" \"$TMPROOT/dir_symlinks\""

# direct broken symlink
compare_long \
    "broken_symlink" \
    "LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_symlinks/broken_link\"" \
    "\"$FT_BIN\" -l \"$TMPROOT/dir_symlinks/broken_link\""

# ============================================================
# BASIC ++
# ============================================================

info "BASIC ++ TESTS"

# reverse
compare_output \
    "ls_r" \
    "LC_ALL=C \"$LS_BIN\" -1 -r \"$TMPROOT/dir_sort\"" \
    "\"$FT_BIN\" -r \"$TMPROOT/dir_sort\""

# time
compare_output \
    "ls_t" \
    "LC_ALL=C \"$LS_BIN\" -1 -t \"$TMPROOT/dir_sort\"" \
    "\"$FT_BIN\" -t \"$TMPROOT/dir_sort\""

# reverse + time
compare_output \
    "ls_rt" \
    "LC_ALL=C \"$LS_BIN\" -1 -r -t \"$TMPROOT/dir_sort\"" \
    "\"$FT_BIN\" -rt \"$TMPROOT/dir_sort\""

# multiple arguments with -r
compare_output \
    "ls_r_multiple_args" \
    "LC_ALL=C \"$LS_BIN\" -1 -r \"$TMPROOT/dir_multi_a\" \"$TMPROOT/dir_multi_b\" \"$TMPROOT/dir_multi_c\"" \
    "\"$FT_BIN\" -r \"$TMPROOT/dir_multi_a\" \"$TMPROOT/dir_multi_b\" \"$TMPROOT/dir_multi_c\""

# multiple arguments with -t
compare_output \
    "ls_t_multiple_args" \
    "LC_ALL=C \"$LS_BIN\" -1 -t \"$TMPROOT/dir_sort/oldest.txt\" \"$TMPROOT/dir_sort/newest.txt\" \"$TMPROOT/dir_sort/middle.txt\"" \
    "\"$FT_BIN\" -t \"$TMPROOT/dir_sort/oldest.txt\" \"$TMPROOT/dir_sort/newest.txt\" \"$TMPROOT/dir_sort/middle.txt\""

# ============================================================
# SPECIAL BITS
# ============================================================

info "SUID / SGID / STICKY TESTS"

compare_long \
    "special_bits" \
    "LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_special\"" \
    "\"$FT_BIN\" -l \"$TMPROOT/dir_special\""

# Explicitly inspect special permission characters
special_output="$RESULTS_DIR/special_bits.raw"

"$FT_BIN" -l "$TMPROOT/dir_special" >"$special_output" 2>&1

if grep -Eq "suid_exec|suid_noexec|sgid_exec" "$special_output" &&
   grep -Eq "[rwx-]{3}[sStT]" "$special_output"; then
    pass "special permission bits are displayed"
else
    fail "special permission bits are not displayed correctly"
fi

# ============================================================
# MIDDLE TESTS
# ============================================================

info "MIDDLE TESTS"

# recursive
compare_output \
    "ls_R" \
    "LC_ALL=C \"$LS_BIN\" -R \"$TMPROOT/dir_grouped\"" \
    "\"$FT_BIN\" -R \"$TMPROOT/dir_grouped\""

# grouped options
compare_long \
    "combined_laR" \
    "LC_ALL=C \"$LS_BIN\" -l -a -R \"$TMPROOT/dir_grouped\"" \
    "\"$FT_BIN\" -laR \"$TMPROOT/dir_grouped\""

# separated options
compare_long \
    "separated_l_r_R" \
    "LC_ALL=C \"$LS_BIN\" -l -r -R \"$TMPROOT/dir_grouped\"" \
    "\"$FT_BIN\" -l -r -R \"$TMPROOT/dir_grouped\""

# combined lt
compare_long \
    "combined_lt" \
    "LC_ALL=C \"$LS_BIN\" -l -t \"$TMPROOT/dir_sort\"" \
    "\"$FT_BIN\" -lt \"$TMPROOT/dir_sort\""

# combined lr
compare_long \
    "combined_lr" \
    "LC_ALL=C \"$LS_BIN\" -l -r \"$TMPROOT/dir_sort\"" \
    "\"$FT_BIN\" -lr \"$TMPROOT/dir_sort\""

# ============================================================
# SPECIAL NAMES
# ============================================================

info "SPECIAL FILENAMES"

compare_output \
    "spaces" \
    "LC_ALL=C \"$LS_BIN\" -1 \"$TMPROOT/dir_spaces\"" \
    "\"$FT_BIN\" \"$TMPROOT/dir_spaces\""

# ============================================================
# MANY FILES
# ============================================================

info "MANY FILES"

compare_output \
    "many_files" \
    "LC_ALL=C \"$LS_BIN\" -1 \"$TMPROOT/dir_many\"" \
    "\"$FT_BIN\" \"$TMPROOT/dir_many\""

# ============================================================
# DEFAULT PATH
# ============================================================

info "DEFAULT PATH"

(
    cd "$TMPROOT" || exit 1

    LC_ALL=C "$LS_BIN" >"$RESULTS_DIR/default.ls" 2>&1
    "$FT_BIN" >"$RESULTS_DIR/default.ft" 2>&1
)

if diff -u \
    "$RESULTS_DIR/default.ls" \
    "$RESULTS_DIR/default.ft" \
    >"$RESULTS_DIR/default.diff"; then
    pass "default path"
else
    fail "default path"
    sed -n '1,80p' "$RESULTS_DIR/default.diff"
fi

# ============================================================
# EMPTY DIRECTORY
# ============================================================

info "EMPTY DIRECTORY"

compare_long \
    "empty_directory" \
    "LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/empty_dir\"" \
    "\"$FT_BIN\" -l \"$TMPROOT/empty_dir\""

# ============================================================
# OLD DATES
# ============================================================

info "DATE TESTS"

compare_long \
    "old_dates" \
    "LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_dates\"" \
    "\"$FT_BIN\" -l \"$TMPROOT/dir_dates\""

# ============================================================
# NONEXISTENT PATH
# ============================================================

info "ERROR MANAGEMENT"

"$LS_BIN" "$TMPROOT/does_not_exist" \
    >"$RESULTS_DIR/nonexistent.ls.out" \
    2>"$RESULTS_DIR/nonexistent.ls.err"
ls_status=$?

"$FT_BIN" "$TMPROOT/does_not_exist" \
    >"$RESULTS_DIR/nonexistent.ft.out" \
    2>"$RESULTS_DIR/nonexistent.ft.err"
ft_status=$?

if [ "$ls_status" -ne 0 ] && [ "$ft_status" -ne 0 ]; then
    pass "nonexistent path returns non-zero"
else
    fail "nonexistent path exit status"
fi

if [ -s "$RESULTS_DIR/nonexistent.ft.err" ]; then
    pass "nonexistent path prints an error"
else
    fail "nonexistent path does not print an error"
fi

# ============================================================
# PARTIAL PATH FAILURE
# ============================================================

"$LS_BIN" \
    "$TMPROOT/dir_multi_a" \
    "$TMPROOT/does_not_exist" \
    "$TMPROOT/dir_multi_b" \
    >"$RESULTS_DIR/partial.ls.out" \
    2>"$RESULTS_DIR/partial.ls.err"
ls_status=$?

"$FT_BIN" \
    "$TMPROOT/dir_multi_a" \
    "$TMPROOT/does_not_exist" \
    "$TMPROOT/dir_multi_b" \
    >"$RESULTS_DIR/partial.ft.out" \
    2>"$RESULTS_DIR/partial.ft.err"
ft_status=$?

if [ "$ls_status" -ne 0 ] && [ "$ft_status" -ne 0 ]; then
    pass "partial path failure returns non-zero"
else
    fail "partial path failure exit status"
fi

if grep -q "does_not_exist" "$RESULTS_DIR/partial.ft.err"; then
    pass "partial path failure reports missing path"
else
    fail "partial path failure does not report missing path"
fi

# ============================================================
# INVALID OPTION
# ============================================================

"$LS_BIN" -z \
    >"$RESULTS_DIR/invalid.ls.out" \
    2>"$RESULTS_DIR/invalid.ls.err"
ls_status=$?

"$FT_BIN" -z \
    >"$RESULTS_DIR/invalid.ft.out" \
    2>"$RESULTS_DIR/invalid.ft.err"
ft_status=$?

if [ "$ls_status" -ne 0 ] && [ "$ft_status" -ne 0 ]; then
    pass "invalid option returns non-zero"
else
    fail "invalid option exit status"
fi

if [ -s "$RESULTS_DIR/invalid.ft.err" ]; then
    pass "invalid option prints an error"
else
    fail "invalid option does not print an error"
fi

# ============================================================
# MULTIPLE FILES + DIRECTORIES
# ============================================================

info "MULTIPLE ARGUMENT TESTS"

compare_output \
    "multiple_dirs" \
    "LC_ALL=C \"$LS_BIN\" -1 \"$TMPROOT/dir_multi_b\" \"$TMPROOT/dir_multi_a\" \"$TMPROOT/dir_multi_c\"" \
    "\"$FT_BIN\" \"$TMPROOT/dir_multi_b\" \"$TMPROOT/dir_multi_a\" \"$TMPROOT/dir_multi_c\""

compare_output \
    "mixed_files_dirs" \
    "LC_ALL=C \"$LS_BIN\" -1 \"$TMPROOT/dir_multi_a/fileA.txt\" \"$TMPROOT/dir_multi_a\" \"$TMPROOT/dir_multi_b/fileB.txt\" \"$TMPROOT/dir_multi_b\"" \
    "\"$FT_BIN\" \"$TMPROOT/dir_multi_a/fileA.txt\" \"$TMPROOT/dir_multi_a\" \"$TMPROOT/dir_multi_b/fileB.txt\" \"$TMPROOT/dir_multi_b\""

# ============================================================
# INACCESSIBLE DIRECTORY
# ============================================================

info "INACCESSIBLE DIRECTORY"

if [ "$(id -u)" -eq 0 ]; then
    echo "[SKIP] inaccessible-directory test: running as root"
else
    "$LS_BIN" "$TMPROOT/dir_unreadable" \
        >"$RESULTS_DIR/unreadable.ls.out" \
        2>"$RESULTS_DIR/unreadable.ls.err"

    "$FT_BIN" "$TMPROOT/dir_unreadable" \
        >"$RESULTS_DIR/unreadable.ft.out" \
        2>"$RESULTS_DIR/unreadable.ft.err"

    if [ -s "$RESULTS_DIR/unreadable.ft.err" ]; then
        pass "inaccessible directory produces an error"
    else
        fail "inaccessible directory does not produce an error"
    fi
fi

# Restore permissions so cleanup works normally.
chmod 755 "$TMPROOT/dir_unreadable" 2>/dev/null || true

# ============================================================
# EXIT STATUS
# ============================================================

info "EXIT STATUS"

"$FT_BIN" \
    "$TMPROOT/dir_files" \
    "$TMPROOT/does_not_exist" \
    >/dev/null 2>&1

ft_status=$?

if [ "$ft_status" -ne 0 ]; then
    pass "exit status on partial failure is non-zero"
else
    fail "exit status on partial failure should be non-zero"
fi

# ============================================================
# VALGRIND
# ============================================================

info "VALGRIND"

if [ "$NO_VALGRIND" -eq 1 ]; then
    echo "[SKIP] Valgrind disabled with --no-valgrind"
elif [ -z "$VALGRIND_BIN" ]; then
    echo "[WARN] Valgrind is not installed"
else
    run_valgrind "basic" \
        "$FT_BIN" "$TMPROOT/dir_files"

    run_valgrind "long" \
        "$FT_BIN" -l "$TMPROOT/dir_files"

    run_valgrind "recursive" \
        "$FT_BIN" -R "$TMPROOT/dir_grouped"

    run_valgrind "all_flags" \
        "$FT_BIN" -laR "$TMPROOT/dir_grouped"

    run_valgrind "error" \
        "$FT_BIN" "$TMPROOT/does_not_exist"
fi

# ============================================================
# FINAL SUMMARY
# ============================================================

info "FINAL SUMMARY"

echo "Tests run: $TESTS"
echo "Passed:    $PASSES"
echo "Failed:    $FAILURES"

if [ "$FAILURES" -eq 0 ]; then
    echo
    echo "============================================================"
    echo "ALL AUTOMATED TESTS PASSED"
    echo "============================================================"
    exit 0
else
    echo
    echo "============================================================"
    echo "SOME TESTS FAILED"
    echo "============================================================"
    echo
    echo "Results are available in:"
    echo "  $RESULTS_DIR"
    exit 1
fi
