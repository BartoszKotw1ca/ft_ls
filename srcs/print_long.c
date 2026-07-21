#include "../includes/ft_ls.h"

/*
** ─── format_time ─────────────────────────────────────────────────────────────
** ls -l uses two date formats (both 12 chars wide):
**   Within the last 6 months  →  "Jan  2 15:04"   (%b %e %H:%M)
**   Older than 6 months       →  "Jan  2  2021"   (%b %e  %Y)
**
** "%e" pads the day with a leading space instead of zero, giving the double-
** space for single-digit days that ls produces ("Jan  2" vs "Jan 12").
*/
static void format_time(time_t mtime, char *buf, size_t sz)
{
    time_t      now;
    struct tm  *tm;

    now = time(NULL);
    tm  = localtime(&mtime);
    if (!tm)
    {
        strncpy(buf, "??? ?? ??:??", sz - 1);
        buf[sz - 1] = '\0';
        return;
    }
    /* 6 months ≈ 180 days × 86 400 s */
    if (mtime <= now && (now - mtime) < (time_t)(180 * 86400))
        strftime(buf, sz, "%b %e %H:%M", tm);
    else
        strftime(buf, sz, "%b %e  %Y", tm);
}

/*
** ─── Column widths ────────────────────────────────────────────────────────────
** Pre-scan the array once to find the widest nlink, owner, group and size
** fields so every row is aligned identically — just like real ls -l.
*/
typedef struct s_widths
{
    int nlink;
    int owner;
    int group;
    int size;
}   t_widths;

static t_widths scan_widths(t_entry *entries, int n)
{
    t_widths    w;
    char        tmp[64];
    int         i;
    int         len;

    w.nlink = 1;
    w.owner = 1;
    w.group = 1;
    w.size  = 1;
    i = 0;
    while (i < n)
    {
        len = snprintf(tmp, sizeof(tmp), "%lu",
                       (unsigned long)entries[i].st.st_nlink);
        if (len > w.nlink) w.nlink = len;

        len = (int)strlen(get_owner(entries[i].st.st_uid));
        if (len > w.owner) w.owner = len;

        len = (int)strlen(get_group(entries[i].st.st_gid));
        if (len > w.group) w.group = len;

        len = snprintf(tmp, sizeof(tmp), "%lld",
                       (long long)entries[i].st.st_size);
        if (len > w.size) w.size = len;

        i++;
    }
    return (w);
}

/*
** ─── print_one_long ──────────────────────────────────────────────────────────
** Prints one entry in ls -l format, fields aligned to the pre-scanned widths.
**
** Format (separated by single spaces):
**   <mode(10)> <nlink(right)> <owner(left)> <group(left)> <size(right)>
**   <date(12)> <name> [-> target]
*/
static void print_one_long(t_entry *e, t_widths *w)
{
    char mode[11];
    char timebuf[32];

    mode_to_str(e->st.st_mode, mode);
    format_time(e->st.st_mtime, timebuf, sizeof(timebuf));

    printf("%s %*lu %-*s %-*s %*lld %s %s",
           mode,
           w->nlink, (unsigned long)e->st.st_nlink,
           w->owner, get_owner(e->st.st_uid),
           w->group, get_group(e->st.st_gid),
           w->size,  (long long)e->st.st_size,
           timebuf,
           e->name);

    if (e->is_link && e->link_target[0])
        printf(" -> %s", e->link_target);

    printf("\n");
}

/*
** ─── print_entries_long ──────────────────────────────────────────────────────
** Public entry point called by list_dir.c.
** Scans column widths once, then prints every entry.
*/
void    print_entries_long(t_entry *entries, int n)
{
    t_widths    w;
    int         i;

    if (n == 0)
        return;
    w = scan_widths(entries, n);
    i = 0;
    while (i < n)
    {
        print_one_long(&entries[i], &w);
        i++;
    }
}