# ft_ls — Full Project Report

## Overview

`ft_ls` is a C reimplementation of the Unix `ls` command. The goal is to reproduce the exact behavior of the system `ls` while supporting the options `-l`, `-R`, `-a`, `-r`, and `-t`. The project teaches interaction with the filesystem via C (directory traversal, `stat()`, permissions, dates, etc.) and demands careful upfront architecture to avoid costly refactoring later.

---

## 1. Files That Must Be Created

### 1.1 Mandatory Files

| File | Purpose |
|---|---|
| `Makefile` | Compiles the project; must include rules: `all`, `clean`, `fclean`, `re` |
| `ft_ls` | Final executable (produced by `make`) |
| `*.c` source files | All C source files implementing ft_ls |
| `*.h` header file(s) | All type definitions, prototypes, macros |

### 1.2 Recommended Directory Structure

```
ft_ls/
├── Makefile
├── includes/
│   └── ft_ls.h           # All structs, enums, prototypes, macros
├── srcs/
│   ├── main.c            # Entry point: parse args, dispatch
│   ├── parse_args.c      # Option and path parsing
│   ├── list_dir.c        # Core directory reading (opendir/readdir)
│   ├── print_short.c     # Default output (no -l): single-column names
│   ├── print_long.c      # Long format (-l): permissions, owner, size, date, name
│   ├── sort.c            # Sorting logic (alpha, -t, -r)
│   ├── recursive.c       # Recursive traversal (-R)
│   ├── stat_utils.c      # Wrappers around stat(2), permission strings, dates
│   ├── error.c           # Error handling (perror, strerror, exit codes)
│   └── utils.c           # Generic helpers (string ops, memory wrappers)
├── libft/                # Your libft (strongly recommended)
│   ├── Makefile
│   ├── ft_printf.c       # (strongly recommended)
│   └── ...               # All other libft functions
```

> **Note:** You are free to name and organize files as you wish, but the executable **must** be named `ft_ls`.

### 1.3 Makefile Rules

The Makefile must contain at minimum:

| Rule | Action |
|---|---|
| `all` | Compile libft (if present) then ft_ls |
| `clean` | Remove all `.o` object files |
| `fclean` | `clean` + remove the `ft_ls` executable (and `libft.a`) |
| `re` | `fclean` + `all` |

The Makefile must **not** recompile unnecessarily (i.e., use proper dependency tracking via object files).

---

## 2. Options That Must Be Implemented

### 2.1 Option Flags

| Flag | Behavior |
|---|---|
| `-l` | Long listing format: permissions, link count, owner, group, size, date, name |
| `-R` | Recursively list subdirectories |
| `-a` | Show all entries including hidden files (names starting with `.`) |
| `-r` | Reverse the sort order |
| `-t` | Sort by modification time, newest first |

### 2.2 Option Combination Rules

- All options must be combinable: `ft_ls -lRart /some/path` must work correctly.
- Options may be passed separately (`-l -a`) or grouped (`-la`).
- Multiple paths may be given: `ft_ls /tmp /var /etc`.
- If no path is given, the current directory (`.`) is used.
- **Design note:** `-R` changes the entire traversal structure. Plan for it from the very beginning — retrofitting recursion into a non-recursive design is extremely painful and a known cause of project failure.

---

## 3. What Must Work (Functional Requirements)

### 3.1 Default Behavior (no options)

- List entries in the given directory (or `.`), sorted alphabetically.
- **Do not** show hidden files (entries starting with `.`).
- You are **not** required to implement multi-column output (only single-column is required when `-l` is not active).
- Output must match `ls` output for the same inputs (entry names, ordering).

### 3.2 `-l` (Long Format)

Each line must display, in order:

```
[permissions] [links] [owner] [group] [size] [month day hh:mm|year] [name]
```

Example:
```
-rw-r--r--  1 user  staff  1024 Jul 18 14:32 file.txt
drwxr-xr-x  3 user  staff    96 Jun  5  2023 somedir
```

| Field | Source |
|---|---|
| Permissions | `stat.st_mode` — formatted as `drwxrwxrwx` |
| Hard link count | `stat.st_nlink` |
| Owner name | `getpwuid(stat.st_uid)->pw_name` |
| Group name | `getgrgid(stat.st_gid)->gr_name` |
| Size in bytes | `stat.st_size` |
| Modification date | `stat.st_mtime` (use `ctime`/`localtime`/`strftime`) — if older than 6 months, show year instead of `hh:mm` |
| Filename | `d_name` from `readdir` |

- The block total (`total N`) must be printed before the file list for each directory.
- Padding must align all columns (use field-width formatting).
- Symlinks must be shown as `name -> target` (use `readlink(2)`).

### 3.3 `-a` (All Files)

- Include entries whose names begin with `.` (including `.` and `..`).
- Without `-a`, skip any entry whose name starts with `.`.

### 3.4 `-r` (Reverse Sort)

- Reverse the output order after all other sorting is applied.
- Works with default (alphabetical) sort and with `-t`.

### 3.5 `-t` (Sort by Modification Time)

- Sort entries by `st_mtime`, newest first.
- When combined with `-r`, oldest first.
- Entries with equal `st_mtime` are sorted alphabetically as a tiebreak (match system behavior).

### 3.6 `-R` (Recursive)

- After listing a directory's contents, recursively list every subdirectory found within it.
- Format for each sub-directory header:
  ```
  ./subdir:
  ```
  or with full path when a path argument was given:
  ```
  /var/log/nginx:
  ```
- The `-a` flag affects which subdirectories are entered (`.` and `..` are listed but never entered to avoid infinite recursion).
- Recursion order must match the system `ls -R` output.

### 3.7 Multiple Path Arguments

- When multiple paths are given, list each one in argument order.
- Files are listed before directories.
- Each directory listing is prefaced with its path and a colon: `dirname:`.
- Errors for individual paths do not stop processing of remaining paths.

### 3.8 Error Handling

- Must handle errors **exactly like `ls`**:
  - Non-existent path: print error to `stderr`, continue with remaining paths.
  - No read permission: print error to `stderr`, continue.
  - Empty directory: print nothing (or just the `total 0` line with `-l`).
- **No segmentation fault, bus error, double free, or other undefined behavior — ever.**
- Exit code: `0` if all succeeded, `1` if any error occurred (mirror `ls` behavior).

### 3.9 Memory Management

- **Zero memory leaks.** Every `malloc` must have a corresponding `free`.
- All allocated lists/trees/strings for a directory must be freed before moving to the next.
- Validate every `malloc` return; handle `NULL` gracefully.

---

## 4. Key System Calls and Functions to Use

| Purpose | Functions |
|---|---|
| Open a directory | `opendir(3)`, `readdir(3)`, `closedir(3)` |
| File metadata | `stat(2)`, `lstat(2)` (use `lstat` to avoid following symlinks) |
| Permissions string | Bitwise ops on `st_mode`: `S_ISDIR`, `S_ISLNK`, `S_IRUSR`, etc. |
| Owner/group names | `getpwuid(3)`, `getgrgid(3)` |
| Symlink target | `readlink(2)` |
| Date formatting | `localtime(3)`, `strftime(3)` or manual formatting |
| Terminal width | `ioctl(TIOCGWINSZ)` — only if implementing multi-column (not required) |
| Error messages | `perror(3)`, `strerror(3)` |

> **Important:** Use `lstat()` instead of `stat()` on directory entries so that symlinks appear as symlinks rather than as their targets.

---

## 5. Architecture & Design Recommendations

### 5.1 Option Struct

Parse all flags into a single struct at startup:

```c
typedef struct s_options {
    int l;  // long format
    int R;  // recursive
    int a;  // all files
    int r;  // reverse
    int t;  // sort by time
} t_options;
```

### 5.2 File Entry Struct

Represent each directory entry as a struct:

```c
typedef struct s_entry {
    char            name[256];
    char            path[4096];
    struct stat     st;
    char            link_target[4096]; // for symlinks
} t_entry;
```

### 5.3 Sorting

Implement a comparator function and apply it consistently:

```c
int compare_entries(t_entry *a, t_entry *b, t_options *opts);
```

Apply `-t` (by `st_mtime`) and then `-r` (reverse) as independent post-processing steps.

### 5.4 Recursion Design (Critical)

Plan recursion from day one. Suggested flow:

```
list_path(path, opts)
  → read all entries into array
  → sort array
  → print entries (short or long)
  → if -R: for each entry that is a directory (and not "." or ".."):
       list_path(entry.path, opts)
```

Do **not** build a non-recursive version first and try to add `-R` later. The recursive structure must inform the entire data flow.

### 5.5 Long Format Padding

Pre-calculate the maximum field widths before printing:

- Max link count digits
- Max owner name length
- Max group name length
- Max size digits

Then use consistent padding for each column.

---

## 6. What Must Be Tested

### 6.1 Basic Tests

| Test | Expected |
|---|---|
| `./ft_ls` | List current directory, alphabetical, no hidden |
| `./ft_ls /tmp` | List `/tmp`, same behavior |
| `./ft_ls /nonexistent` | Error to stderr: `ft_ls: /nonexistent: No such file or directory` |
| `./ft_ls /etc/hosts` | List the file itself (it's a regular file, not a dir) |
| `./ft_ls /etc/hosts /tmp` | File first, then directory |

### 6.2 Option Tests

| Test | Expected |
|---|---|
| `./ft_ls -a` | Shows `.` and `..` and hidden files |
| `./ft_ls -l` | Long format with all fields, aligned columns |
| `./ft_ls -l /etc` | Long format of `/etc` |
| `./ft_ls -t` | Sorted by modification time, newest first |
| `./ft_ls -r` | Reverse alphabetical order |
| `./ft_ls -rt` | Reverse by modification time (oldest first) |
| `./ft_ls -R /tmp` | Recursive listing |
| `./ft_ls -la` | Long format showing all files including hidden |
| `./ft_ls -lRart` | All options combined |

### 6.3 Diff Tests Against System ls

Run the same command with both `ls` and `./ft_ls` and diff the output:

```bash
# Set locale to avoid locale-dependent diffs
LC_ALL=C ls -la /tmp > system.txt
LC_ALL=C ./ft_ls -la /tmp > mine.txt
diff system.txt mine.txt
```

Repeat for each option and combination. Graders will use this method.

### 6.4 Edge Case Tests

| Test | Expected |
|---|---|
| Empty directory | Only `total 0` with `-l`, nothing otherwise |
| Directory with only hidden files | Empty output without `-a` |
| Symlink entries with `-l` | Shows `name -> target` |
| Directory without read permission | Error message, continue with next |
| Very long filenames | Correct alignment (no truncation) |
| Files with identical `st_mtime` | Alphabetical tiebreak |
| `-R` on deep tree | All subdirs listed recursively with correct headers |
| `.` and `..` entries with `-Ra` | Listed but not entered (no infinite loop) |
| Single file argument (not a dir) | The file's information only |

### 6.5 Memory Leak Tests

```bash
valgrind --leak-check=full --error-exitcode=1 ./ft_ls -laRt /usr/include
```

Must report **0 leaks** and **0 errors**.

### 6.6 Crash / Robustness Tests

```bash
./ft_ls -lRat / 2>/dev/null   # Full filesystem traversal, no crash
./ft_ls ""                     # Empty string argument
./ft_ls -z                     # Invalid option — handle like ls
```

---

## 7. Grading Criteria Summary

| Criterion | Notes |
|---|---|
| Executable named `ft_ls` | Mandatory |
| Makefile with all/clean/fclean/re | Mandatory |
| No crash / undefined behavior | Mandatory — any crash = fail |
| No memory leaks | Mandatory — valgrind must pass |
| `-l` correct output | All fields present, aligned, correct format |
| `-a` correct output | Hidden files shown including `.` and `..` |
| `-R` correct output | Recursive, correct headers, no infinite loop |
| `-r` correct output | Reversed order |
| `-t` correct output | Sorted by mtime, tiebreak alphabetical |
| Options combined | All combinations must work |
| Multi-path arguments | Files before dirs, correct headers |
| Error handling | Matches `ls` behavior (stderr, continue, exit code) |
| Padding / alignment | "Cordial" grading — graders won't penalize minor padding diff, but **no information may be missing** |
| Locale | No locale handling required (`LC_ALL=C` is fine) |
| ACL / extended attributes | Not required |
| Multi-column format (no `-l`) | Not required — single column is sufficient |

---

## 8. Common Pitfalls to Avoid

1. **Not planning for `-R` from the start.** This is the #1 cause of project failure. The recursive structure must be central to the design.
2. **Using `stat()` instead of `lstat()` on directory entries.** Symlinks will be incorrectly reported.
3. **Forgetting to free entries before recursing.** Memory leaks accumulate across recursive calls.
4. **Printing `..` as a recursive target.** Never recurse into `.` or `..`.
5. **Hardcoding field widths.** Must compute max widths per-directory before printing.
6. **Wrong date format.** Files older than 6 months must show year, recent files show `hh:mm`.
7. **Wrong block total.** The `total N` line uses 512-byte blocks from `st_blocks`; check your system's `ls` (Linux uses 1024-byte blocks for display, macOS uses 512 — match the target system).
8. **Ignoring errors from `opendir`/`stat`.** Always check return values.
9. **Not supporting multiple path arguments.** `ls /a /b /c` is standard usage.
10. **Not handling a file (non-directory) as a path argument.** `ls /etc/hosts` must print just that file's info with `-l`.

---

## 9. Bonus Suggestions (if mandatory part is complete)

| Bonus | Description |
|---|---|
| `-1` | Force single-column output |
| `-G` / `--color` | Colorize output by file type |
| Multi-column output | Columnar display without `-l` (like real `ls`) |
| `-i` | Print inode number |
| `-s` | Print block usage per file |
| `-d` | List directory names, not their contents |
| ACL display | Show `@` or `+` after permissions where applicable |

---

## 10. Summary Checklist

```
[ ] Makefile with all/clean/fclean/re rules
[ ] Compiles cleanly with -Wall -Wextra -Werror
[ ] Executable named ft_ls
[ ] libft (with ft_printf) compiled and linked
[ ] Default listing: alphabetical, no hidden, single column
[ ] -a: show hidden files including . and ..
[ ] -l: full long format (permissions, links, owner, group, size, date, name)
[ ] -l: correct block total header ("total N")
[ ] -l: symlinks shown as "name -> target"
[ ] -l: date format switches to year for files > 6 months old
[ ] -l: all columns properly padded / aligned
[ ] -t: sorted by st_mtime, alphabetical tiebreak
[ ] -r: reverse of current sort
[ ] -R: recursive, correct directory headers, no infinite loop
[ ] All options combinable in any order and grouping
[ ] Multiple path arguments: files before directories, correct headers
[ ] Error messages to stderr, program continues with remaining paths
[ ] Exit code 0 on success, non-zero if any error occurred
[ ] No segfault, bus error, double free, or undefined behavior
[ ] Zero memory leaks (valgrind clean)
[ ] diff output matches LC_ALL=C ls for all tested cases
```
