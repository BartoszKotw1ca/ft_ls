#!/usr/bin/env bash

# ============================================================
# ft_ls evaluation test - mandatory requirements
# ============================================================
#
# Usage:
#   ./tests/run_tests.sh
#   ./tests/run_tests.sh --no-valgrind
#   ./tests/run_tests.sh --keep
#
# Covers mandatory ft_ls requirements:
# - author file
# - Makefile and required rules
# - Makefile functionality
# - Norminette
# - forbidden functions
# - ls
# - ls -a
# - ls -l
# - symbolic links
# - ls -r
# - ls -t
# - ls -r with multiple arguments
# - ls -t with multiple arguments
# - SUID / SGID / sticky bit
# - ls -R
# - combined/separated options
# - multiple option display
# - nonexistent files/directories
# - inaccessible files/directories
# - invalid options
# - exit status
# - Valgrind / memory leaks
#
# Bonus options are intentionally not tested.
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
# Author
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
# Makefile functionality
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
		sed -n '1,160p' "$NORM_OUTPUT"
		echo "-----------------------------"
	fi
else
	echo "[WARN] norminette is not installed; Norminette check skipped"
fi

# ------------------------------------------------------------
# Forbidden functions
# ------------------------------------------------------------

echo
echo "Checking suspicious functions..."

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
	if grep -REn \
		--include='*.c' \
		--include='*.h' \
		"(^|[^A-Za-z0-9_])${func}[[:space:]]*\(" \
		"$ROOT_DIR/srcs" "$ROOT_DIR/includes" \
		>"$RESULTS_DIR/forbidden_${func}.out" 2>/dev/null; then
		echo "[FAIL] suspicious/forbidden function detected: $func"
		sed -n '1,10p' "$RESULTS_DIR/forbidden_${func}.out"
		FORBIDDEN_FOUND=1
	fi
done

if [ "$FORBIDDEN_FOUND" -eq 0 ]; then
	pass "no clearly forbidden external-execution functions detected"
else
	fail "forbidden/suspicious functions detected"
fi

# ============================================================
# CREATE TEST FIXTURES
# ============================================================

info "CREATING TEST FIXTURES"

mkdir -p "$TMPROOT/dir_files"
mkdir -p "$TMPROOT/dir_hidden"
mkdir -p "$TMPROOT/dir_spaces"
mkdir -p "$TMPROOT/dir_symlinks/target_dir"
mkdir -p "$TMPROOT/dir_recursive/subdir/deeper"
mkdir -p "$TMPROOT/dir_unreadable"
mkdir -p "$TMPROOT/dir_many"
mkdir -p "$TMPROOT/dir_sort"
mkdir -p "$TMPROOT/dir_special/sticky_dir"
mkdir -p "$TMPROOT/dir_multi_a"
mkdir -p "$TMPROOT/dir_multi_b"
mkdir -p "$TMPROOT/dir_multi_c"
mkdir -p "$TMPROOT/dir_dates"
mkdir -p "$TMPROOT/empty_dir"

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
# Special filenames
# ------------------------------------------------------------

printf 'space\n' > "$TMPROOT/dir_spaces/file with spaces.txt"
touch "$TMPROOT/dir_spaces/-dashfile"

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
# Recursive directory
# ------------------------------------------------------------

printf 'root\n' > "$TMPROOT/dir_recursive/root.txt"
printf 'sub\n' > "$TMPROOT/dir_recursive/subdir/sub.txt"
printf 'deep\n' > \
	"$TMPROOT/dir_recursive/subdir/deeper/deep.txt"

mkdir -p "$TMPROOT/dir_recursive/.hidden_dir"
printf 'hidden\n' > \
	"$TMPROOT/dir_recursive/.hidden_dir/hidden.txt"

# ------------------------------------------------------------
# Inaccessible file / directory
# ------------------------------------------------------------

printf 'secret\n' > "$TMPROOT/inaccessible_file.txt"
chmod 000 "$TMPROOT/inaccessible_file.txt"

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
# Special permission bits
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

# ============================================================
# BASIC TESTS
# ============================================================

info "BASIC TESTS"

# ------------------------------------------------------------
# ls - no arguments
# ------------------------------------------------------------

(
	cd "$TMPROOT" || exit 1
	LC_ALL=C "$LS_BIN" -1 >"$RESULTS_DIR/ls_no_args.ls" 2>&1
	"$FT_BIN" >"$RESULTS_DIR/ls_no_args.ft" 2>&1
)

if diff -u \
	"$RESULTS_DIR/ls_no_args.ls" \
	"$RESULTS_DIR/ls_no_args.ft" \
	>"$RESULTS_DIR/ls_no_args.diff"; then
	pass "ls_no_args"
else
	fail "ls_no_args"
	sed -n '1,80p' "$RESULTS_DIR/ls_no_args.diff"
fi

# ------------------------------------------------------------
# ls - file
# ------------------------------------------------------------

compare_output \
	"ls_file" \
	"LC_ALL=C \"$LS_BIN\" -1 \"$TMPROOT/dir_files/foo.txt\"" \
	"\"$FT_BIN\" \"$TMPROOT/dir_files/foo.txt\""

# ------------------------------------------------------------
# ls - directory
# ------------------------------------------------------------

compare_output \
	"ls_directory" \
	"LC_ALL=C \"$LS_BIN\" -1 \"$TMPROOT/dir_files\"" \
	"\"$FT_BIN\" \"$TMPROOT/dir_files\""

# ------------------------------------------------------------
# ls -a
# ------------------------------------------------------------

compare_output \
	"ls_a" \
	"LC_ALL=C \"$LS_BIN\" -a -1 \"$TMPROOT/dir_hidden\"" \
	"\"$FT_BIN\" -a \"$TMPROOT/dir_hidden\""

# ------------------------------------------------------------
# ls -l - no arguments
# ------------------------------------------------------------

(
	cd "$TMPROOT" || exit 1
	LC_ALL=C "$LS_BIN" -l >"$RESULTS_DIR/ls_l_no_args.ls" 2>&1
	"$FT_BIN" -l >"$RESULTS_DIR/ls_l_no_args.ft" 2>&1
)

normalize_long <"$RESULTS_DIR/ls_l_no_args.ls" \
	>"$RESULTS_DIR/ls_l_no_args.ls.norm"

normalize_long <"$RESULTS_DIR/ls_l_no_args.ft" \
	>"$RESULTS_DIR/ls_l_no_args.ft.norm"

if diff -u \
	"$RESULTS_DIR/ls_l_no_args.ls.norm" \
	"$RESULTS_DIR/ls_l_no_args.ft.norm" \
	>"$RESULTS_DIR/ls_l_no_args.diff"; then
	pass "ls_l_no_args"
else
	fail "ls_l_no_args"
	sed -n '1,80p' "$RESULTS_DIR/ls_l_no_args.diff"
fi

# ------------------------------------------------------------
# ls -l - file
# ------------------------------------------------------------

compare_long \
	"ls_l_file" \
	"LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_files/foo.txt\"" \
	"\"$FT_BIN\" -l \"$TMPROOT/dir_files/foo.txt\""

# ------------------------------------------------------------
# ls -l - directory
# ------------------------------------------------------------

compare_long \
	"ls_l_directory" \
	"LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_files\"" \
	"\"$FT_BIN\" -l \"$TMPROOT/dir_files\""

# ------------------------------------------------------------
# Symbolic links - directory
# ------------------------------------------------------------

compare_output \
	"symlink_directory_listing" \
	"LC_ALL=C \"$LS_BIN\" -1 \"$TMPROOT/dir_symlinks\"" \
	"\"$FT_BIN\" \"$TMPROOT/dir_symlinks\""

# ------------------------------------------------------------
# Symbolic links - exact display
# ------------------------------------------------------------

compare_long \
	"symlink_to_directory" \
	"LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_symlinks/link_to_dir\"" \
	"\"$FT_BIN\" -l \"$TMPROOT/dir_symlinks/link_to_dir\""

compare_long \
	"symlink_to_file" \
	"LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_symlinks/link_to_file\"" \
	"\"$FT_BIN\" -l \"$TMPROOT/dir_symlinks/link_to_file\""

compare_long \
	"broken_symlink" \
	"LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_symlinks/broken_link\"" \
	"\"$FT_BIN\" -l \"$TMPROOT/dir_symlinks/broken_link\""

# ============================================================
# BASIC ++ TESTS
# ============================================================

info "BASIC ++ TESTS"

# ------------------------------------------------------------
# ls -r
# ------------------------------------------------------------

compare_output \
	"ls_r" \
	"LC_ALL=C \"$LS_BIN\" -1 -r \"$TMPROOT/dir_sort\"" \
	"\"$FT_BIN\" -r \"$TMPROOT/dir_sort\""

# ------------------------------------------------------------
# ls -t
# ------------------------------------------------------------

compare_output \
	"ls_t" \
	"LC_ALL=C \"$LS_BIN\" -1 -t \"$TMPROOT/dir_sort\"" \
	"\"$FT_BIN\" -t \"$TMPROOT/dir_sort\""

# ------------------------------------------------------------
# ls -r multiple files/folders
# ------------------------------------------------------------

compare_output \
	"ls_r_multiple_args" \
	"LC_ALL=C \"$LS_BIN\" -1 -r \"$TMPROOT/dir_multi_a\" \"$TMPROOT/dir_multi_b\" \"$TMPROOT/dir_multi_c\"" \
	"\"$FT_BIN\" -r \"$TMPROOT/dir_multi_a\" \"$TMPROOT/dir_multi_b\" \"$TMPROOT/dir_multi_c\""

# ------------------------------------------------------------
# ls -t multiple files/folders
# ------------------------------------------------------------

compare_output \
	"ls_t_multiple_args" \
	"LC_ALL=C \"$LS_BIN\" -1 -t \"$TMPROOT/dir_sort/oldest.txt\" \"$TMPROOT/dir_sort/newest.txt\" \"$TMPROOT/dir_sort/middle.txt\"" \
	"\"$FT_BIN\" -t \"$TMPROOT/dir_sort/oldest.txt\" \"$TMPROOT/dir_sort/newest.txt\" \"$TMPROOT/dir_sort/middle.txt\""

# ------------------------------------------------------------
# SUID / SGID / sticky
# ------------------------------------------------------------

compare_long \
	"special_bits" \
	"LC_ALL=C \"$LS_BIN\" -l \"$TMPROOT/dir_special\"" \
	"\"$FT_BIN\" -l \"$TMPROOT/dir_special\""

special_output="$RESULTS_DIR/special_bits.raw"

"$FT_BIN" -l "$TMPROOT/dir_special" \
	>"$special_output" 2>&1

if grep -Eq "suid_exec|suid_noexec|sgid_exec|sticky_dir" \
	"$special_output" &&
	grep -Eq "[rwx-]{3}[sStT]" "$special_output"; then
	pass "special permission bits are displayed"
else
	fail "special permission bits are displayed"
fi

# ============================================================
# MIDDLE TESTS
# ============================================================

info "MIDDLE TESTS"

# ------------------------------------------------------------
# ls -R
# ------------------------------------------------------------

compare_output \
	"ls_R" \
	"LC_ALL=C \"$LS_BIN\" -R \"$TMPROOT/dir_recursive\"" \
	"\"$FT_BIN\" -R \"$TMPROOT/dir_recursive\""

# ------------------------------------------------------------
# -l -t
# ------------------------------------------------------------

compare_long \
	"separated_l_t" \
	"LC_ALL=C \"$LS_BIN\" -l -t \"$TMPROOT/dir_sort\"" \
	"\"$FT_BIN\" -l -t \"$TMPROOT/dir_sort\""

compare_long \
	"combined_lt" \
	"LC_ALL=C \"$LS_BIN\" -lt \"$TMPROOT/dir_sort\"" \
	"\"$FT_BIN\" -lt \"$TMPROOT/dir_sort\""

# ------------------------------------------------------------
# -l -r
# ------------------------------------------------------------

compare_long \
	"separated_l_r" \
	"LC_ALL=C \"$LS_BIN\" -l -r \"$TMPROOT/dir_sort\"" \
	"\"$FT_BIN\" -l -r \"$TMPROOT/dir_sort\""

compare_long \
	"combined_lr" \
	"LC_ALL=C \"$LS_BIN\" -lr \"$TMPROOT/dir_sort\"" \
	"\"$FT_BIN\" -lr \"$TMPROOT/dir_sort\""

# ------------------------------------------------------------
# -l -a -R
# ------------------------------------------------------------

compare_long \
	"combined_laR" \
	"LC_ALL=C \"$LS_BIN\" -laR \"$TMPROOT/dir_recursive\"" \
	"\"$FT_BIN\" -laR \"$TMPROOT/dir_recursive\""

# ------------------------------------------------------------
# separated -l -r -R
# ------------------------------------------------------------

compare_long \
	"separated_l_r_R" \
	"LC_ALL=C \"$LS_BIN\" -l -r -R \"$TMPROOT/dir_recursive\"" \
	"\"$FT_BIN\" -l -r -R \"$TMPROOT/dir_recursive\""

# ============================================================
# SPECIAL FILENAMES
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
# MULTIPLE FILES / DIRECTORIES
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
# ERROR MANAGEMENT
# ============================================================

info "ERROR MANAGEMENT"

# ------------------------------------------------------------
# Nonexistent file
# ------------------------------------------------------------

"$LS_BIN" "$TMPROOT/no_such_file.txt" \
	>"$RESULTS_DIR/nonexistent_file.ls.out" \
	2>"$RESULTS_DIR/nonexistent_file.ls.err"
ls_status=$?

"$FT_BIN" "$TMPROOT/no_such_file.txt" \
	>"$RESULTS_DIR/nonexistent_file.ft.out" \
	2>"$RESULTS_DIR/nonexistent_file.ft.err"
ft_status=$?

if [ "$ls_status" -ne 0 ] && [ "$ft_status" -ne 0 ]; then
	pass "nonexistent file returns non-zero"
else
	fail "nonexistent file returns non-zero"
fi

if grep -q "no_such_file.txt" \
	"$RESULTS_DIR/nonexistent_file.ft.err"; then
	pass "nonexistent file prints an error"
else
	fail "nonexistent file prints an error"
fi

# ------------------------------------------------------------
# Nonexistent directory
# ------------------------------------------------------------

"$LS_BIN" "$TMPROOT/no_such_directory" \
	>"$RESULTS_DIR/nonexistent_dir.ls.out" \
	2>"$RESULTS_DIR/nonexistent_dir.ls.err"
ls_status=$?

"$FT_BIN" "$TMPROOT/no_such_directory" \
	>"$RESULTS_DIR/nonexistent_dir.ft.out" \
	2>"$RESULTS_DIR/nonexistent_dir.ft.err"
ft_status=$?

if [ "$ls_status" -ne 0 ] && [ "$ft_status" -ne 0 ]; then
	pass "nonexistent directory returns non-zero"
else
	fail "nonexistent directory returns non-zero"
fi

if grep -q "no_such_directory" \
	"$RESULTS_DIR/nonexistent_dir.ft.err"; then
	pass "nonexistent directory prints an error"
else
	fail "nonexistent directory prints an error"
fi

# ------------------------------------------------------------
# Partial failure
# ------------------------------------------------------------

"$LS_BIN" \
	"$TMPROOT/dir_multi_a" \
	"$TMPROOT/no_such_path" \
	"$TMPROOT/dir_multi_b" \
	>"$RESULTS_DIR/partial.ls.out" \
	2>"$RESULTS_DIR/partial.ls.err"
ls_status=$?

"$FT_BIN" \
	"$TMPROOT/dir_multi_a" \
	"$TMPROOT/no_such_path" \
	"$TMPROOT/dir_multi_b" \
	>"$RESULTS_DIR/partial.ft.out" \
	2>"$RESULTS_DIR/partial.ft.err"
ft_status=$?

if [ "$ls_status" -ne 0 ] && [ "$ft_status" -ne 0 ]; then
	pass "partial path failure returns non-zero"
else
	fail "partial path failure returns non-zero"
fi

if grep -q "no_such_path" \
	"$RESULTS_DIR/partial.ft.err"; then
	pass "partial path failure reports missing path"
else
	fail "partial path failure reports missing path"
fi

# ============================================================
# INACCESSIBLE FILE / DIRECTORY
# ============================================================

info "INACCESSIBLE FILE / DIRECTORY"

if [ "$(id -u)" -eq 0 ]; then
	echo "[SKIP] inaccessible file/directory tests: running as root"
else
	# --------------------------------------------------------
	# Inaccessible file
	# --------------------------------------------------------

	"$LS_BIN" "$TMPROOT/inaccessible_file.txt" \
		>"$RESULTS_DIR/inaccessible_file.ls.out" \
		2>"$RESULTS_DIR/inaccessible_file.ls.err"

	"$FT_BIN" "$TMPROOT/inaccessible_file.txt" \
		>"$RESULTS_DIR/inaccessible_file.ft.out" \
		2>"$RESULTS_DIR/inaccessible_file.ft.err"

	if [ -s "$RESULTS_DIR/inaccessible_file.ft.err" ]; then
		pass "inaccessible file produces an error"
	else
		fail "inaccessible file produces an error"
	fi

	# --------------------------------------------------------
	# Inaccessible directory
	# --------------------------------------------------------

	"$LS_BIN" "$TMPROOT/dir_unreadable" \
		>"$RESULTS_DIR/inaccessible_dir.ls.out" \
		2>"$RESULTS_DIR/inaccessible_dir.ls.err"

	"$FT_BIN" "$TMPROOT/dir_unreadable" \
		>"$RESULTS_DIR/inaccessible_dir.ft.out" \
		2>"$RESULTS_DIR/inaccessible_dir.ft.err"

	if [ -s "$RESULTS_DIR/inaccessible_dir.ft.err" ]; then
		pass "inaccessible directory produces an error"
	else
		fail "inaccessible directory produces an error"
	fi
fi

# ============================================================
# INVALID OPTIONS
# ============================================================

info "INVALID OPTIONS"

# ------------------------------------------------------------
# -z
# ------------------------------------------------------------

"$LS_BIN" -z \
	>"$RESULTS_DIR/invalid_z.ls.out" \
	2>"$RESULTS_DIR/invalid_z.ls.err"
ls_status=$?

"$FT_BIN" -z \
	>"$RESULTS_DIR/invalid_z.ft.out" \
	2>"$RESULTS_DIR/invalid_z.ft.err"
ft_status=$?

if [ "$ls_status" -ne 0 ] && [ "$ft_status" -ne 0 ]; then
	pass "invalid option -z returns non-zero"
else
	fail "invalid option -z returns non-zero"
fi

if [ -s "$RESULTS_DIR/invalid_z.ft.err" ]; then
	pass "invalid option -z prints an error"
else
	fail "invalid option -z prints an error"
fi

# ------------------------------------------------------------
# invalid option in cluster
# ------------------------------------------------------------

"$FT_BIN" -lz \
	>"$RESULTS_DIR/invalid_lz.ft.out" \
	2>"$RESULTS_DIR/invalid_lz.ft.err"
ft_status=$?

if [ "$ft_status" -ne 0 ]; then
	pass "invalid clustered option returns non-zero"
else
	fail "invalid clustered option returns non-zero"
fi

if [ -s "$RESULTS_DIR/invalid_lz.ft.err" ]; then
	pass "invalid clustered option prints an error"
else
	fail "invalid clustered option prints an error"
fi

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
	run_valgrind()
	{
		test_name="$1"
		shift

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
		elif grep -Eq \
			"definitely lost: [1-9][0-9]* bytes|indirectly lost: [1-9][0-9]* bytes" \
			"$log"; then
			fail "Valgrind $test_name - memory leak detected"
			grep -E \
				"definitely lost|indirectly lost|ERROR SUMMARY" \
				"$log" | tail -10
		else
			pass "Valgrind $test_name - no memory leak detected"
		fi
	}

	run_valgrind \
		"basic" \
		"$FT_BIN" "$TMPROOT/dir_files"

	run_valgrind \
		"long" \
		"$FT_BIN" -l "$TMPROOT/dir_files"

	run_valgrind \
		"recursive" \
		"$FT_BIN" -R "$TMPROOT/dir_recursive"

	run_valgrind \
		"multiple_args" \
		"$FT_BIN" -r \
		"$TMPROOT/dir_multi_a" \
		"$TMPROOT/dir_multi_b" \
		"$TMPROOT/dir_multi_c"

	run_valgrind \
		"all_flags" \
		"$FT_BIN" -laR "$TMPROOT/dir_recursive"

	run_valgrind \
		"error" \
		"$FT_BIN" "$TMPROOT/no_such_file.txt"
fi

# ============================================================
# RESTORE PERMISSIONS
# ============================================================

chmod 755 "$TMPROOT/inaccessible_file.txt" 2>/dev/null || true
chmod 755 "$TMPROOT/dir_unreadable" 2>/dev/null || true

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
	echo "ALL MANDATORY AUTOMATED TESTS PASSED"
	echo "============================================================"
	exit 0
else
	echo
	echo "============================================================"
	echo "SOME MANDATORY TESTS FAILED"
	echo "============================================================"
	echo
	echo "Results are available in:"
	echo "  $RESULTS_DIR"
	echo
	echo "Temporary tests:"
	echo "  $TMPROOT"
	exit 1
fi