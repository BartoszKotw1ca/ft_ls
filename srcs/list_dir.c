#include "../includes/ft_ls.h"

/* Forward declaration — list_path calls list_directory, which calls list_path
   recursively when -R is active. Both live in this file. */
static int  list_directory(const char *path, const t_options *opts,
                            int print_header);

/*
** ─── PATH HELPERS ────────────────────────────────────────────────────────────
*/

/* Build "dir/name" into dst (4096 bytes). Handles trailing slash in dir. */
static void build_fullpath(char *dst, const char *dir, const char *name)
{
    size_t len;

    len = strlen(dir);
    if (len > 0 && dir[len - 1] == '/')
        snprintf(dst, 4096, "%s%s", dir, name);
    else
        snprintf(dst, 4096, "%s/%s", dir, name);
}

/*
** ─── DYNAMIC ENTRY ARRAY ─────────────────────────────────────────────────────
** We grow the array by doubling to avoid O(n²) reallocs.
** Returns a pointer to the freshly appended (uninitialised) slot.
*/
static t_entry  *entries_push(t_entry **arr, int *count, int *cap)
{
    t_entry *tmp;

    if (*count == *cap)
    {
        *cap = (*cap == 0) ? 32 : *cap * 2;
        tmp  = realloc(*arr, (size_t)(*cap) * sizeof(t_entry));
        if (!tmp)
        {
            perror("ft_ls: realloc");
            free(*arr);
            exit(1);
        }
        *arr = tmp;
    }
    return (&(*arr)[(*count)++]);
}

/*
** ─── READ DIRECTORY ──────────────────────────────────────────────────────────
** Reads every entry from the directory at *path* into a heap-allocated
** t_entry array.  Returns the array and sets *out_count.
**
** On opendir failure: prints an error, sets *out_count = -1, returns NULL.
** The caller must free() the returned pointer when done.
*/
static t_entry  *read_entries(const char *path, const t_options *opts,
                               int *out_count)
{
    DIR             *dir;
    struct dirent   *de;
    t_entry         *entries;
    t_entry         *e;
    int              count;
    int              cap;
    ssize_t          llen;

    entries = NULL;
    count   = 0;
    cap     = 0;

    dir = opendir(path);
    if (!dir)
    {
        ft_error(path);
        *out_count = -1;
        return (NULL);
    }

    while ((de = readdir(dir)) != NULL)
    {
        /* Without -a, skip any name that starts with '.' */
        if (!opts->a && de->d_name[0] == '.')
            continue;

        e = entries_push(&entries, &count, &cap);

        /* Copy name (d_name is at most NAME_MAX chars) */
        strncpy(e->name, de->d_name, sizeof(e->name) - 1);
        e->name[sizeof(e->name) - 1] = '\0';

        /* Build the full path for lstat / readlink / recursion */
        build_fullpath(e->fullpath, path, de->d_name);

        /*
        ** Use lstat so symlinks appear as symlinks, not as their targets.
        ** If lstat fails (race condition, permission issue), zero the stat
        ** so the entry is still listed but with no usable metadata.
        */
        if (lstat(e->fullpath, &e->st) == -1)
        {
            ft_error(e->fullpath);
            memset(&e->st, 0, sizeof(e->st));
        }

        e->is_link        = S_ISLNK(e->st.st_mode);
        e->link_target[0] = '\0';
        if (e->is_link)
        {
            llen = readlink(e->fullpath, e->link_target,
                            sizeof(e->link_target) - 1);
            if (llen >= 0)
                e->link_target[(size_t)llen] = '\0';
        }
    }
    closedir(dir);

    *out_count = count;
    return (entries);
}

/*
** ─── BLOCK TOTAL ─────────────────────────────────────────────────────────────
** st_blocks is always in 512-byte units. ls -l shows "total N" where N is
** in 1024-byte (1 KB) blocks on Linux (the dominant target for ft_ls).
** Dividing st_blocks by 2 converts 512 → 1024.
*/
static long compute_total(t_entry *entries, int n)
{
    long total;
    int  i;

    total = 0;
    i     = 0;
    while (i < n)
    {
        total += entries[i].st.st_blocks;
        i++;
    }

#if defined(__APPLE__) || defined(__MACH__) || defined(__FreeBSD__) \
 || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__DragonFly__)
    return (total);
#else
    return (total / 2);
#endif
}

/*
** ─── PRINT A SINGLE FILE ARGUMENT ────────────────────────────────────────────
** Called for non-directory paths given directly on the command line.
** With -l: will call print_long_entry() once print_long.c is written.
** Without -l: just print the path as the user typed it (matches ls).
*/
static int  list_file(t_entry *e, const t_options *opts)
{
    if (opts->l)
        print_entries_long(e, 1);
    else
        printf("%s\n", e->name);
    return (0);
}

/*
** ─── LIST ONE DIRECTORY ──────────────────────────────────────────────────────
**
** 1. Optionally print "path:" header.
** 2. Read all entries (respecting -a).
** 3. Sort (respecting -t and -r).
** 4. Print "total N" block count (only with -l).
** 5. Print entries (short now; long in next step).
** 6. If -R: recurse into every subdirectory in sorted order.
**
** The recursive structure is intentional and central to the design.
** Each recursive call owns its own entries array and frees it before returning.
*/
static int  list_directory(const char *path, const t_options *opts,
                            int print_header)
{
    t_entry *entries;
    int      count;
    int      ret;
    int      i;

    if (print_header)
        printf("%s:\n", path);

    entries = read_entries(path, opts, &count);
    if (count == -1)        /* opendir failed, error already printed */
        return (1);

    sort_entries(entries, count, opts);

    if (opts->l)
        printf("total %ld\n", compute_total(entries, count));

    if (opts->l)
        print_entries_long(entries, count);
    else
        print_entries_short(entries, count);

    ret = 0;

    /*
    ** ── Recursive pass (-R) ─────────────────────────────────────────────
    **
    ** Iterate the *already sorted* entries and recurse into each sub-
    ** directory.  We skip "." and ".." explicitly to prevent infinite loops.
    ** A blank line always precedes a new directory block, matching ls -R.
    */
    if (opts->R)
    {
        i = 0;
        while (i < count)
        {
            if (S_ISDIR(entries[i].st.st_mode)
                && strcmp(entries[i].name, ".")  != 0
                && strcmp(entries[i].name, "..") != 0)
            {
                printf("\n");
                if (list_path(entries[i].fullpath, opts, 1) != 0)
                    ret = 1;
            }
            i++;
        }
    }

    free(entries);
    return (ret);
}

/*
** ─── PUBLIC ENTRY POINT ──────────────────────────────────────────────────────
**
** list_path is called by main() for each top-level argument, and by
** list_directory() for every subdirectory when -R is active.
** It dispatches to list_file or list_directory based on the stat result.
*/
int list_path(const char *path, const t_options *opts, int print_header)
{
    struct stat st;
    t_entry     e;
    ssize_t     llen;

    if (lstat(path, &st) == -1)
    {
        ft_error(path);
        return (1);
    }

    if (S_ISDIR(st.st_mode))
        return (list_directory(path, opts, print_header));

    /*
    ** Build a synthetic t_entry so list_file can pass it straight to
    ** print_entries_long (which works on an array of t_entry).
    ** e.name is the path as the user typed it — ls prints it verbatim.
    */
    strncpy(e.name,     path, sizeof(e.name)     - 1);
    e.name[sizeof(e.name) - 1]         = '\0';
    strncpy(e.fullpath, path, sizeof(e.fullpath) - 1);
    e.fullpath[sizeof(e.fullpath) - 1] = '\0';
    e.st      = st;
    e.is_link = S_ISLNK(st.st_mode);
    e.link_target[0] = '\0';
    if (e.is_link)
    {
        llen = readlink(path, e.link_target, sizeof(e.link_target) - 1);
        if (llen >= 0)
            e.link_target[(size_t)llen] = '\0';
    }
    return (list_file(&e, opts));
}