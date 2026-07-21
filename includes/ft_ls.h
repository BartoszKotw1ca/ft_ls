#ifndef FT_LS_H
# define FT_LS_H

# include <sys/stat.h>
# include <sys/types.h>
# include <dirent.h>
# include <pwd.h>
# include <grp.h>
# include <time.h>
# include <stdio.h>
# include <stdlib.h>
# include <string.h>
# include <unistd.h>
# include <errno.h>
#include "../mylibft/mylibft.h"
/*
** ─── OPTIONS ────────────────────────────────────────────────────────────────
** All flags parsed from argv are stored in a single t_options struct.
** Every function that needs to know the active flags receives a const pointer
** to this struct so there is no global state.
*/

typedef struct s_options
{
    int l;  /* -l : long listing format                         */
    int R;  /* -R : recursive traversal                         */
    int a;  /* -a : show hidden entries (names starting with .) */
    int r;  /* -r : reverse the sort order                      */
    int t;  /* -t : sort by modification time (newest first)    */
}   t_options;

/*
** ─── FILE ENTRY ─────────────────────────────────────────────────────────────
** One t_entry is created for every name returned by readdir (or for every
** explicit path argument that is a regular file).
** We store both the bare name and the full path so that stat() can be called
** on the full path while we print only the bare name.
*/

typedef struct s_entry
{
    char        name[256];          /* d_name from readdir / basename    */
    char        fullpath[4096];     /* absolute or relative path to stat */
    struct stat st;                 /* result of lstat(fullpath)         */
    int         is_link;            /* 1 when S_ISLNK(st.st_mode)       */
    char        link_target[4096];  /* readlink result, only if is_link  */
}   t_entry;

/*
** ─── PARSE_ARGS ──────────────────────────────────────────────────────────────
** Fills *opts with the parsed flags and allocates *paths (caller must free).
** Returns 0 on success, 1 if an illegal option was found (program exits 1).
*/
int     parse_args(int argc, char **argv,
                   t_options *opts, char ***paths, int *npath);

/*
** ─── LIST ────────────────────────────────────────────────────────────────────
** list_path() is the central entry point for listing one directory or file.
**   path         – what to list
**   opts         – active flags
**   print_header – whether to print "path:" before the contents
**                  (set when there are multiple top-level arguments or -R)
** Returns 0 on success, 1 if the path could not be accessed.
*/
int     list_path(const char *path, const t_options *opts, int print_header);

/*
** ─── ERROR ───────────────────────────────────────────────────────────────────
** Prints "ft_ls: <path>: <strerror>" to stderr, mirroring ls behaviour.
*/
void    ft_error(const char *path);

/*
** ─── sort.c ──────────────────────────────────────────────────────────────────
** Sort the entries array in-place according to the active flags.
**   -t → by st_mtime descending, then alpha; -r → reverse the result.
*/
void    sort_entries(t_entry *entries, int n, const t_options *opts);

/*
** ─── print_short.c ───────────────────────────────────────────────────────────
** One entry name per line (no -l). Called by list_dir after sorting.
*/
void    print_entries_short(t_entry *entries, int n);

/*
** ─── stat_utils.c ────────────────────────────────────────────────────────────
** Permission string and owner/group name helpers used by print_long.c.
*/
void        mode_to_str(mode_t mode, char *buf); /* buf must be >= 11 bytes */
const char *get_owner(uid_t uid);                /* pw_name or decimal uid   */
const char *get_group(gid_t gid);                /* gr_name or decimal gid   */

/*
** ─── print_long.c ────────────────────────────────────────────────────────────
** Full ls -l output: permissions, nlink, owner, group, size, date, name.
** Pre-scans column widths so every row is aligned.
*/
void    print_entries_long(t_entry *entries, int n);


#endif /* FT_LS_H */