# ft_ls Execution Flow & System Call Specifications

## 1. Top-Level Flow & Program Lifecycle

```text
[CLI Invocation]
  └─> ./ft_ls -alrR path1 path2 ...
        │
        ▼
[main.c] main(argc, argv)
        │
        ├─> [Memory] Allocates t_options opts & t_arg_lists al ({.files, .dirs})
        │
        ├─> 1. CALL parse_args(argc, argv, &opts, &paths, &npath) ──► [parse_args.c]
        │     ├─ CHECK: Starts with '-' and length > 1?
        │     │    ├─ YES: Loop over chars. Parse 'a', 'l', 'r', 'R', 't'.
        │     │    │       └─ CHECK: Unknown flag? ──► CALL ft_error() ──► Return 1 (Exit)
        │     │    └─ NO / '--': Stop option parsing.
        │     └─ ALLOCATE: paths array for positional arguments.
        │
        ├─> CHECK: Is npath == 0?
        │     └─ YES: Set default path array to ["."]
        │
        ├─> 2. CALL classify(paths, npath, &al, &opts) ─────────────► [main.c]
        │     └─ LOOP over each path in paths[]:
        │          ├─ CALL lstat(path, &st)
        │          ├─ CHECK: lstat() failed (< 0)?
        │          │    └─ YES: CALL ft_error(path) [stderr] ──► Increment error count ──► CONTINUE
        │          ├─ CHECK: S_ISDIR(st.st_mode)?
        │          │    ├─ YES: Push path into al.dirs array
        │          │    └─ NO:  Push path into al.files array
        │          └─ SORT: Sort al.files and al.dirs alphabetically.
        │
        ├─> 3. Process Non-Directory Arguments (al.files)
        │     └─ LOOP over al.files[i]:
        │          └─ CALL list_path(al.files[i], &opts, print_header=0) ──► [list_dir.c]
        │
        ├─> 4. Process Directory Arguments (al.dirs)
        │     └─ LOOP over al.dirs[i]:
        │          ├─ CHECK: Print newline separator if al.files was non-empty or i > 0
        │          └─ CALL list_path(al.dirs[i], &opts, print_header=(npath > 1))
        │
        └─> 5. Cleanup & Exit
              ├─ FREE: paths, al.files, al.dirs
              └─ RETURN exit_code (0 if no errors, 1 if any lstat/opendir failed)
```

---

## 2. Path Dispatcher & Single File Flow

```text
[list_dir.c] list_path(path, opts, print_header)
        │
        ├─> CALL lstat(path, &st)
        │     └─ CHECK: lstat() failed?
        │          └─ YES: CALL ft_error(path) [stderr] ──► RETURN 1
        │
        ├─> CHECK: S_ISDIR(st.st_mode)?
        │     ├─ YES: ──► CALL list_directory(path, opts, print_header) [See Section 3]
        │     └─ NO:  ──► CALL list_file(path, &st, opts)
        │
        ▼
[list_dir.c] list_file(path, st, opts)
        │
        ├─> ALLOCATE/FILL: Synthetic t_entry e
        │     ├─ e.name = basename(path)
        │     ├─ e.fullpath = path
        │     ├─ e.st = *st
        │     └─ CHECK: S_ISLNK(st->st_mode) && opts->l?
        │          └─ YES: CALL readlink(path, e.link_target)
        │
        └─> CHECK: opts->l active?
              ├─ YES: CALL print_entries_long(&e, count=1) ──► [print_long.c]
              └─ NO:  CALL printf("%s\n", e.name)           ──► [stdout]
```

---

## 3. Directory Listing & Processing Engine

```text
[list_dir.c] list_directory(path, opts, print_header)
        │
        ├─> CHECK: print_header == 1?
        │     └─ YES: CALL printf("%s:\n", path) ──► [stdout]
        │
        ├─> 1. READ DIRECTORY
        │     └─ CALL read_entries(path, opts, &count) ─────────────────► [list_dir.c]
        │           ├─ CALL opendir(path)
        │           │    └─ CHECK: opendir() == NULL?
        │           │         └─ YES: CALL ft_error(path) [stderr] ──► RETURN NULL (*out_count = -1)
        │           │
        │           ├─ LOOP: readdir(dirp) while entry != NULL
        │           │    ├─ CHECK: entry->d_name starts with '.' && !opts->a?
        │           │    │    └─ YES: SKIP (Do not process hidden file)
        │           │    │
        │           │    ├─ ALLOCATE / EXTEND: t_entry array (entries_push)
        │           │    ├─ COPY: entry->d_name ──► e.name
        │           │    ├─ BUILD PATH: path + "/" + entry->d_name ──► e.fullpath
        │           │    │
        │           │    ├─ CALL lstat(e.fullpath, &e.st)
        │           │    │    └─ CHECK: lstat() failed?
        │           │    │         └─ YES: CALL ft_error(e.fullpath) ──► Zero e.st
        │           │    │
        │           │    └─ CHECK: S_ISLNK(e.st.st_mode)?
        │           │         └─ YES: CALL readlink(e.fullpath, e.link_target, 4095)
        │           │
        │           └─ CALL closedir(dirp) ──► RETURN entries array
        │
        ├─> CHECK: count <= 0 or entries == NULL? ──► RETURN
        │
        ├─> 2. SORT ENTRIES
        │     └─ CALL sort_entries(entries, count, opts) ───────────────► [sort.c]
        │           ├─ CHECK: opts->t active?
        │           │    ├─ YES: QuickSort/BubbleSort by st.st_mtime (descending)
        │           │    │       └─ Tie-breaker: Alphabetical by e.name
        │           │    └─ NO:  QuickSort/BubbleSort alphabetically by e.name
        │           └─ CHECK: opts->r active?
        │                └─ YES: Reverse the array order in-place
        │
        ├─> 3. PRINT ENTRIES
        │     ├─ CHECK: opts->l active?
        │     │    ├─ YES:
        │     │    │    ├─ Calculate total 512B blocks: SUM(e.st.st_blocks)
        │     │    │    ├─ CALL printf("total %ld\n", total_blocks) ──► [stdout]
        │     │    │    └─ CALL print_entries_long(entries, count) ─────► [print_long.c]
        │     │    │         ├─ Scan column widths (max links, max owner length, max size, etc.)
        │     │    │         └─ LOOP i = 0..count-1:
        │     │    │              ├─ Convert st_mode ──► permission string ("-rw-r--r--")
        │     │    │              ├─ Get owner name (getpwuid) & group name (getgrgid)
        │     │    │              ├─ Format time (ctime / strftime)
        │     │    │              ├─ Print formatted row
        │     │    │              └─ CHECK: e.is_link? ──► Print " -> link_target"
        │     │    └─ NO:
        │     │         └─ CALL print_entries_short(entries, count) ────► [print_short.c]
        │     │              └─ LOOP i = 0..count-1:
        │     │                   └─ Print name separated by space/newline
        │     │
        │     └─ FREE: entries array memory
        │              (Ensure all allocated fullpath strings are freed)
        │
        └─> 4. RECURSIVE SUBDIRECTORY TRAVERSAL (-R)
              └─ CHECK: opts->R active?
                   └─ LOOP i = 0..count-1:
                        ├─ CHECK: S_ISDIR(entries[i].st.st_mode)?
                        │    ├─ CHECK: name is "." OR ".."?
                        │    │    └─ YES: SKIP (Prevents infinite recursion)
                        │    └─ NO:
                        │         ├─ CALL printf("\n") ──► [stdout]
                        │         └─ RECURSE:
                        │              CALL list_path(entries[i].fullpath, opts, print_header=1)
                        └─ NO: SKIP (Regular file)
```

---

## 4. System Calls & Output Target Summary

| System Call | Trigger Location | Purpose | On Error |
|-------------|------------------|---------|----------|
| `lstat()` | `main.c`, `list_dir.c` | Fetch file metadata without following symlinks | `ft_error()` → `stderr` |
| `opendir()` | `list_dir.c` | Open directory stream for reading | `ft_error()` → `stderr` |
| `readdir()` | `list_dir.c` | Read next directory entry | Returns `NULL` when finished |
| `closedir()` | `list_dir.c` | Close directory stream | Ignored |
| `readlink()` | `list_dir.c` | Get target path of symbolic link | Sets `link_target[0] = '\0'` |
| `getpwuid()` | `print_long.c` | Map UID to username | Falls back to printing numeric UID |
| `getgrgid()` | `print_long.c` | Map GID to group name | Falls back to printing numeric GID |