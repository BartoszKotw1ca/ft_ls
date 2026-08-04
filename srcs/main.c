#include "../includes/ft_ls.h"

/*
** ─── PATH CLASSIFICATION ─────────────────────────────────────────────────────
**
** ls separates its arguments into two groups before printing anything:
**   1. Regular files (and other non-directory entries)
**   2. Directories
**
** Files are printed first (with their info), then each directory is listed.
** We use lstat so that a symlink to a directory is treated as a file at the
** top level, matching ls behaviour.
*/

typedef struct s_arglist
{
    char    **files;    /* non-directory paths */
    int     nfiles;
    char    **dirs;     /* directory paths     */
    int     ndirs;
}   t_arglist;

/* Simple alphabetical comparator for qsort */
static int  cmp_alpha(const void *a, const void *b)
{
    return (strcmp(*(const char **)a, *(const char **)b));
}

/*
** Classify every path in paths[] into files or dirs.
** Paths that cannot be stat'd are printed as errors immediately (ls does the
** same — it reports the error at classification time, not listing time).
** Returns the number of errors encountered.
*/
static int  classify(char **paths, int npath,
                     t_arglist *out, int *exit_code)
{
    struct stat st;
    int         i;
    int         errors;

    out->files  = malloc((size_t)npath * sizeof(char *));
    out->dirs   = malloc((size_t)npath * sizeof(char *));
    out->nfiles = 0;
    out->ndirs  = 0;
    errors      = 0;

    if (!out->files || !out->dirs)
    {
        perror("ft_ls: malloc");
        exit(1);
    }

    i = 0;
    while (i < npath)
    {
        if (lstat(paths[i], &st) == -1)
        {
            ft_error(paths[i]);
            *exit_code = 2;
            errors++;
        }
        else if (S_ISDIR(st.st_mode))
            out->dirs[out->ndirs++] = paths[i];
        else
            out->files[out->nfiles++] = paths[i];
        i++;
    }
    return (errors);
}

static void free_arglist(t_arglist *al)
{
    free(al->files);
    free(al->dirs);
}

/*
** ─── ENTRY POINT ─────────────────────────────────────────────────────────────
**
** Flow:
**   1. Parse flags and path arguments.
**   2. Default to "." when no paths given.
**   3. Classify paths into files vs directories.
**   4. Sort both groups alphabetically.
**   5. List file arguments first.
**   6. List directories (with header when there are multiple top-level args
**      or when -R is active, to match ls behaviour).
*/
int main(int argc, char **argv)
{
    t_options   opts;
    char      **paths;
    int         npath;
    int         exit_code;
    t_arglist   al;
    char       *default_path[1];
    int         print_header;
    int         i;

    /* ── 1. Parse arguments ─────────────────────────────────────────────── */
    exit_code = parse_args(argc, argv, &opts, &paths, &npath);
    if (exit_code)
    {
        free(paths);
        return (exit_code);
    }

    /* ── 2. Default to current directory ────────────────────────────────── */
    if (npath == 0)
    {
        default_path[0] = ".";
        paths  = default_path;
        npath  = 1;
    }

    /* ── 3. Classify paths into files and directories ───────────────────── */
    classify(paths, npath, &al, &exit_code);

    /* ── 4. Sort both groups alphabetically ─────────────────────────────── */
    if (al.nfiles > 1)
        qsort(al.files, (size_t)al.nfiles, sizeof(char *), cmp_alpha);
    if (al.ndirs > 1)
        qsort(al.dirs,  (size_t)al.ndirs,  sizeof(char *), cmp_alpha);

    /*
    ** ── 5. List non-directory arguments ─────────────────────────────────
    **
    ** ls prints file arguments before any directory listing.
    ** With -l each file gets its own stat line; without -l just the name.
    ** We delegate to list_path with print_header = 0 so no "path:" prefix
    ** is added — file arguments are never given a header by ls.
    */
    i = 0;
    while (i < al.nfiles)
    {
        if (list_path(al.files[i], &opts, 0) != 0)
            exit_code = 2;
        i++;
    }

    /*
    ** ── 6. List directory arguments ──────────────────────────────────────
    **
    ** A blank line separates the file block from the first directory listing
    ** when there were file arguments before it.
    ** print_header is set when:
    **   • there are multiple top-level arguments (files + dirs, or 2+ dirs)
    **   • -R is active (every sub-directory needs a header)
    */
	/*
    ** Header decision is based on the original argument count, not the count
    ** of successfully classified paths.  When the user provides two args and
    ** one fails lstat, real ls still prints a header for the surviving dir.
    */
    print_header = (npath > 1) || opts.R;

    i = 0;
    while (i < al.ndirs)
    {
        /*
        ** Print a blank separator between consecutive directory blocks,
        ** and between the file block and the first directory block.
        ** ls emits a blank line before every directory except the very first
        ** listing on stdout.
        */
        if (i > 0 || al.nfiles > 0)
            printf("\n");

        if (list_path(al.dirs[i], &opts, print_header) != 0)
            exit_code = 2;
        i++;
    }
    /* ── Cleanup ─────────────────────────────────────────────────────────── */
    free_arglist(&al);

    /*
    ** Free paths only when it was heap-allocated by parse_args.
    ** When npath was 0 we pointed paths at the stack array default_path,
    ** which must not be freed.
    */
    if (paths != default_path)
        free(paths);

    return (exit_code);
}
