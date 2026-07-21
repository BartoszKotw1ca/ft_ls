#include "../includes/ft_ls.h"

/*
** ─── COMPARATORS ─────────────────────────────────────────────────────────────
**
** qsort comparators receive (const void *, const void *) pointing to
** elements of the array — here, t_entry values (not pointers to t_entry).
*/

/* Alphabetical order — case-sensitive, like ls with LC_ALL=C */
static int  cmp_alpha(const void *a, const void *b)
{
    const t_entry *ea = (const t_entry *)a;
    const t_entry *eb = (const t_entry *)b;

    return (strcmp(ea->name, eb->name));
}

/*
** Modification-time order — newest first (-t).
**
** ls uses full nanosecond precision (st_mtim.tv_nsec on Linux / POSIX.1-2008).
** Without it, entries created in the same second are ordered differently from
** the system ls.  We compare seconds first, then nanoseconds, then fall back
** to alphabetical so the result is always deterministic.
*/
static int  cmp_time(const void *a, const void *b)
{
    const t_entry *ea = (const t_entry *)a;
    const t_entry *eb = (const t_entry *)b;

    if (eb->st.st_mtim.tv_sec != ea->st.st_mtim.tv_sec)
        return (eb->st.st_mtim.tv_sec > ea->st.st_mtim.tv_sec) ? 1 : -1;
    if (eb->st.st_mtim.tv_nsec != ea->st.st_mtim.tv_nsec)
        return (eb->st.st_mtim.tv_nsec > ea->st.st_mtim.tv_nsec) ? 1 : -1;
    return (strcmp(ea->name, eb->name));
}

/*
** ─── REVERSE ─────────────────────────────────────────────────────────────────
** Reverses the entries array in-place. Called after sorting when -r is active.
** We swap whole t_entry structs (they are on the stack / in a heap array).
*/
static void reverse_entries(t_entry *entries, int n)
{
    t_entry tmp;
    int     lo;
    int     hi;

    lo = 0;
    hi = n - 1;
    while (lo < hi)
    {
        tmp          = entries[lo];
        entries[lo]  = entries[hi];
        entries[hi]  = tmp;
        lo++;
        hi--;
    }
}

/*
** ─── PUBLIC ──────────────────────────────────────────────────────────────────
**
** sort_entries — applies the correct sort order then optionally reverses:
**   default  → alphabetical
**   -t       → by st_mtime (newest first), alpha tiebreak
**   -r       → reverse whatever order was produced above
*/
void    sort_entries(t_entry *entries, int n, const t_options *opts)
{
    if (n <= 1)
        return;

    if (opts->t)
        qsort(entries, (size_t)n, sizeof(t_entry), cmp_time);
    else
        qsort(entries, (size_t)n, sizeof(t_entry), cmp_alpha);

    if (opts->r)
        reverse_entries(entries, n);
}
