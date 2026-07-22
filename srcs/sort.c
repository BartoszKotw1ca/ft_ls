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

#if defined(__APPLE__) || defined(__MACH__) || defined(__FreeBSD__) \
 || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__DragonFly__)
static const struct timespec *stat_mtim(const struct stat *st)
{
    return (&st->st_mtimespec);
}
#else
static const struct timespec *stat_mtim(const struct stat *st)
{
    return (&st->st_mtim);
}
#endif

/*
** Modification-time order — newest first (-t).
**
** ls uses full nanosecond precision when available. We compare seconds first,
** then nanoseconds, then fall back to alphabetical so the result is always
** deterministic across systems.
*/
static int  cmp_time(const void *a, const void *b)
{
    const t_entry           *ea = (const t_entry *)a;
    const t_entry           *eb = (const t_entry *)b;
    const struct timespec   *ta;
    const struct timespec   *tb;

    ta = stat_mtim(&ea->st);
    tb = stat_mtim(&eb->st);

    if (tb->tv_sec != ta->tv_sec)
        return (tb->tv_sec > ta->tv_sec) ? 1 : -1;
    if (tb->tv_nsec != ta->tv_nsec)
        return (tb->tv_nsec > ta->tv_nsec) ? 1 : -1;
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
