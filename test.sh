#!/bin/bash
# =============================================================================
# test_parser.sh — validate ft_ls argument parsing and top-level behaviour
#
# What is tested here:
#   • Default path (no args)
#   • Single file / single dir / mixed arguments
#   • Header ("dir:") logic and blank-line separators
#   • Argument ordering: files before directories
#   • Flag parsing: grouped, separated, all combinations, duplicates
#   • "--" end-of-options sentinel
#   • Bare "-" treated as a path
#   • Illegal option → stderr + exit 1
#   • Non-existent path → stderr + exit 1 but continues
#   • Exit codes
#
# Run from the ft_ls/ directory:
#   bash tests/test_parser.sh
# =============================================================================
FT_LS="./ft_ls"
PASS=0
FAIL=0
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
RST='\033[0m'

# ─── Helpers ─────────────────────────────────────────────────────────────────

# check_stdout <label> <expected_stdout> <actual_stdout>
check_stdout()
{
    local label="$1"
    local expected="$2"
    local actual="$3"

    if [ "$actual" = "$expected" ]; then
        echo -e "${GRN}[PASS]${RST} $label"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${RST} $label"
        echo    "       expected: $(echo "$expected" | cat -A)"
        echo    "       got:      $(echo "$actual"   | cat -A)"
        FAIL=$((FAIL + 1))
    fi
}

# check_exit <label> <expected_code> <actual_code>
check_exit()
{
    local label="$1"
    local expected="$2"
    local actual="$3"

    if [ "$actual" -eq "$expected" ]; then
        echo -e "${GRN}[PASS]${RST} $label (exit $actual)"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${RST} $label — expected exit $expected, got $actual"
        FAIL=$((FAIL + 1))
    fi
}

# check_stderr_contains <label> <substring> <actual_stderr>
check_stderr_contains()
{
    local label="$1"
    local substr="$2"
    local actual="$3"

    if echo "$actual" | grep -qF -- "$substr"; then
        echo -e "${GRN}[PASS]${RST} $label"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${RST} $label"
        echo    "       expected stderr to contain: '$substr'"
        echo    "       got: '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

# check_no_crash <label> <exit_code>
#   Passes as long as the exit code is not a signal (>= 128 usually means signal)
check_no_crash()
{
    local label="$1"
    local code="$2"

    if [ "$code" -lt 128 ]; then
        echo -e "${GRN}[PASS]${RST} $label (no crash, exit $code)"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${RST} $label — process crashed (exit $code)"
        FAIL=$((FAIL + 1))
    fi
}

# ─── Test environment setup ───────────────────────────────────────────────────
# We create a small, controlled directory tree so tests don't depend on
# the volatile contents of /tmp.

TESTDIR=$(mktemp -d /tmp/ft_ls_tests_XXXXXX)
TESTFILE_A="$TESTDIR/apple.txt"
TESTFILE_B="$TESTDIR/banana.txt"
TESTSUBDIR="$TESTDIR/subdir"
touch "$TESTFILE_A" "$TESTFILE_B"
mkdir "$TESTSUBDIR"

cleanup() { rm -rf "$TESTDIR"; }
trap cleanup EXIT

# ─── 1. DEFAULT PATH ─────────────────────────────────────────────────────────
echo ""
echo -e "${YEL}── 1. Default path (no args) ──────────────────────────────────${RST}"

# The stub prints the path with no header when there is a single directory.
# When invoked with no args the default is "." so the stub prints ".".
out=$($FT_LS 2>/dev/null)
check_stdout "no args → prints '.'" "." "$out"

check_exit "no args → exit 0" 0 $?

# ─── 2. SINGLE ARGUMENTS ────────────────────────────────────────────────────
echo ""
echo -e "${YEL}── 2. Single path arguments ───────────────────────────────────${RST}"

# Single directory: no header
out=$($FT_LS "$TESTDIR" 2>/dev/null)
check_stdout "single dir → no header" "$TESTDIR" "$out"

# Single regular file: no header
out=$($FT_LS "$TESTFILE_A" 2>/dev/null)
check_stdout "single file → no header" "$TESTFILE_A" "$out"

# ─── 3. MULTIPLE ARGUMENTS ───────────────────────────────────────────────────
echo ""
echo -e "${YEL}── 3. Multiple arguments (header + blank-line logic) ──────────${RST}"

# Two directories → each gets a "dir:" header, blank line between them.
# They are sorted alphabetically. TESTDIR < TESTSUBDIR alphabetically? No:
# TESTSUBDIR is inside TESTDIR, we're passing them as separate args.
# Let's use two fully separate paths for clarity.
DIRA="$TESTDIR"
DIRB="$TESTSUBDIR"
expected="$(printf '%s:\n\n%s:' "$DIRA" "$DIRB")"
out=$($FT_LS "$DIRA" "$DIRB" 2>/dev/null)
check_stdout "two dirs → header on each, blank between" "$expected" "$out"

# File then directory: file first (no header), blank line, then dir with header.
expected="$(printf '%s\n\n%s:' "$TESTFILE_A" "$TESTDIR")"
out=$($FT_LS "$TESTFILE_A" "$TESTDIR" 2>/dev/null)
check_stdout "file + dir → file first (no header), blank, dir with header" "$expected" "$out"

# Directory then file in argv: ls still prints file first, then directory.
expected="$(printf '%s\n\n%s:' "$TESTFILE_A" "$TESTDIR")"
out=$($FT_LS "$TESTDIR" "$TESTFILE_A" 2>/dev/null)
check_stdout "argv dir then file → file still printed first" "$expected" "$out"

# Two files: no headers, sorted alphabetically.
expected="$(printf '%s\n%s' "$TESTFILE_A" "$TESTFILE_B")"
out=$($FT_LS "$TESTFILE_B" "$TESTFILE_A" 2>/dev/null)
check_stdout "two files → alphabetical order, no headers" "$expected" "$out"

# Three arguments: two files + one dir.
expected="$(printf '%s\n%s\n\n%s:' "$TESTFILE_A" "$TESTFILE_B" "$TESTDIR")"
out=$($FT_LS "$TESTFILE_B" "$TESTDIR" "$TESTFILE_A" 2>/dev/null)
check_stdout "two files + dir → files alphabetical first, then dir" "$expected" "$out"

# ─── 4. FLAG PARSING — GROUPED ───────────────────────────────────────────────
echo ""
echo -e "${YEL}── 4. Flag parsing (grouped clusters) ────────────────────────${RST}"

# These should all succeed (exit 0) and not crash — the stub ignores flags.
for flags in -l -R -a -r -t -la -lr -lt -Ra -Rr -Rt -ar -at -rt \
             -lRa -lRr -lRt -lar -lat -lrt -Rar -Rat -Rrt -art \
             -lRar -lRat -lRrt -lart -Rart -lRart; do
    out=$($FT_LS "$flags" "$TESTDIR" 2>/dev/null)
    code=$?
    check_no_crash "grouped flags '$flags' → no crash" "$code"
done

# ─── 5. FLAG PARSING — SEPARATED ────────────────────────────────────────────
echo ""
echo -e "${YEL}── 5. Flag parsing (separated flags) ─────────────────────────${RST}"

out=$($FT_LS -l -R -a -r -t "$TESTDIR" 2>/dev/null); code=$?
check_no_crash "all flags separated → no crash" "$code"
check_exit     "all flags separated → exit 0" 0 "$code"

# ─── 6. DUPLICATE FLAGS ───────────────────────────────────────────────────────
echo ""
echo -e "${YEL}── 6. Duplicate flags ─────────────────────────────────────────${RST}"

out=$($FT_LS -l -l -l "$TESTDIR" 2>/dev/null); code=$?
check_no_crash "duplicate -l flags → no crash" "$code"
check_exit     "duplicate -l flags → exit 0" 0 "$code"

out=$($FT_LS -lllll "$TESTDIR" 2>/dev/null); code=$?
check_no_crash "grouped duplicate -lllll → no crash" "$code"
check_exit     "grouped duplicate -lllll → exit 0" 0 "$code"

# ─── 7. ILLEGAL OPTIONS ───────────────────────────────────────────────────────
echo ""
echo -e "${YEL}── 7. Illegal options ─────────────────────────────────────────${RST}"

for bad in -z -x -y -b -c -q; do
    stderr=$($FT_LS "$bad" 2>&1 1>/dev/null)
    code=$?
    check_exit            "illegal option '$bad' → exit 1" 1 "$code"
    check_stderr_contains "illegal option '$bad' → mentions 'illegal option'" \
                          "illegal option" "$stderr"
    check_stderr_contains "illegal option '$bad' → mentions the flag char" \
                          "${bad:1:1}" "$stderr"
    check_stderr_contains "illegal option '$bad' → prints usage hint" \
                          "usage" "$stderr"
done

# Illegal option inside a cluster
stderr=$($FT_LS -lz 2>&1 1>/dev/null); code=$?
check_exit            "illegal option in cluster '-lz' → exit 1" 1 "$code"
check_stderr_contains "illegal option in cluster '-lz' → mentions 'z'" "z" "$stderr"

# ─── 8. END-OF-OPTIONS SENTINEL ──────────────────────────────────────────────
echo ""
echo -e "${YEL}── 8. '--' end-of-options sentinel ───────────────────────────${RST}"

# After "--", a string that looks like a flag must be treated as a path.
# Since that path ("-l") does not exist, we expect an error to stderr and exit 1.
stderr=$($FT_LS -- -l 2>&1 1>/dev/null); code=$?
check_exit            "'-- -l' → path not found, exit 1" 1 "$code"
check_stderr_contains "'-- -l' → error contains '-l'" "-l" "$stderr"

# A real path after "--" must work.
out=$($FT_LS -- "$TESTDIR" 2>/dev/null); code=$?
check_exit "valid path after '--' → exit 0" 0 "$code"
check_stdout "valid path after '--' → same output as without '--'" \
             "$TESTDIR" "$out"

# ─── 9. BARE '-' AS PATH ─────────────────────────────────────────────────────
echo ""
echo -e "${YEL}── 9. Bare '-' treated as path ───────────────────────────────${RST}"

# '-' is not a flag; it is a non-existent path → error to stderr, exit 1.
stderr=$($FT_LS - 2>&1 1>/dev/null); code=$?
check_exit            "bare '-' → exit 1 (no such file)" 1 "$code"
check_stderr_contains "bare '-' → error mentions '-'" "ft_ls" "$stderr"

# ─── 10. NON-EXISTENT PATHS ───────────────────────────────────────────────────
echo ""
echo -e "${YEL}── 10. Non-existent paths ─────────────────────────────────────${RST}"

stderr=$($FT_LS /no_such_path_xyz 2>&1 1>/dev/null); code=$?
check_exit            "non-existent path → exit 1" 1 "$code"
check_stderr_contains "non-existent path → error to stderr" \
                      "ft_ls" "$stderr"
check_stderr_contains "non-existent path → mentions the path" \
                      "/no_such_path_xyz" "$stderr"

# Multiple non-existent paths: both errors must be reported.
stderr=$($FT_LS /no_such_a /no_such_b 2>&1 1>/dev/null); code=$?
check_exit            "two non-existent paths → exit 1" 1 "$code"
check_stderr_contains "two non-existent paths → first error reported" \
                      "/no_such_a" "$stderr"
check_stderr_contains "two non-existent paths → second error reported" \
                      "/no_such_b" "$stderr"

# Non-existent path mixed with a valid one: error reported but valid one listed.
out=$($FT_LS /no_such_path_xyz "$TESTDIR" 2>/dev/null); code=$?
check_exit   "bad + good path → exit 1" 1 "$code"
# The good directory should still appear in stdout (with a header since
# there were multiple args, even though one failed classification).
if echo "$out" | grep -qF "$TESTDIR"; then
    echo -e "${GRN}[PASS]${RST} bad + good path → valid dir still printed"
    PASS=$((PASS + 1))
else
    echo -e "${RED}[FAIL]${RST} bad + good path → valid dir missing from stdout"
    echo    "       stdout was: '$out'"
    FAIL=$((FAIL + 1))
fi

# ─── 11. EXIT CODES ──────────────────────────────────────────────────────────
echo ""
echo -e "${YEL}── 11. Exit codes ─────────────────────────────────────────────${RST}"

$FT_LS "$TESTDIR" >/dev/null 2>&1
check_exit "single valid dir → exit 0" 0 $?

$FT_LS "$TESTFILE_A" >/dev/null 2>&1
check_exit "single valid file → exit 0" 0 $?

$FT_LS "$TESTDIR" "$TESTFILE_A" >/dev/null 2>&1
check_exit "two valid paths → exit 0" 0 $?

$FT_LS -z >/dev/null 2>&1
check_exit "illegal option → exit 1" 1 $?

$FT_LS /no_such >/dev/null 2>&1
check_exit "non-existent path → exit 1" 1 $?

# ─── 12. STDOUT VS STDERR SEPARATION ─────────────────────────────────────────
echo ""
echo -e "${YEL}── 12. stdout / stderr separation ────────────────────────────${RST}"

# Error messages must NOT appear on stdout.
stdout=$($FT_LS /no_such_path_xyz 2>/dev/null)
if [ -z "$stdout" ]; then
    echo -e "${GRN}[PASS]${RST} error path → nothing on stdout"
    PASS=$((PASS + 1))
else
    echo -e "${RED}[FAIL]${RST} error path → unexpected stdout: '$stdout'"
    FAIL=$((FAIL + 1))
fi

# Normal output must NOT appear on stderr.
stderr=$($FT_LS "$TESTDIR" 2>&1 1>/dev/null)
if [ -z "$stderr" ]; then
    echo -e "${GRN}[PASS]${RST} valid path → nothing on stderr"
    PASS=$((PASS + 1))
else
    echo -e "${RED}[FAIL]${RST} valid path → unexpected stderr: '$stderr'"
    FAIL=$((FAIL + 1))
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GRN}All $TOTAL tests passed.${RST}"
    exit 0
else
    echo -e "${RED}$FAIL / $TOTAL tests FAILED.${RST}"
    exit 1
fi