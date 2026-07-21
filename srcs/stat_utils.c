#include "../includes/ft_ls.h"

/*
** ─── mode_to_str ─────────────────────────────────────────────────────────────
** Fills buf[11] with the 10-char permission string used by ls -l, then NUL.
**
** Slot 0  : file type  (- d l c b p s)
** Slots 1-3 : owner rwx  (setuid replaces x with s/S)
** Slots 4-6 : group rwx  (setgid replaces x with s/S)
** Slots 7-9 : other rwx  (sticky replaces x with t/T)
*/
void    mode_to_str(mode_t mode, char *buf)
{
    /* File type */
    if      (S_ISREG(mode))  buf[0] = '-';
    else if (S_ISDIR(mode))  buf[0] = 'd';
    else if (S_ISLNK(mode))  buf[0] = 'l';
    else if (S_ISCHR(mode))  buf[0] = 'c';
    else if (S_ISBLK(mode))  buf[0] = 'b';
    else if (S_ISFIFO(mode)) buf[0] = 'p';
    else if (S_ISSOCK(mode)) buf[0] = 's';
    else                     buf[0] = '?';

    /* Owner */
    buf[1] = (mode & S_IRUSR) ? 'r' : '-';
    buf[2] = (mode & S_IWUSR) ? 'w' : '-';
    if (mode & S_ISUID)
        buf[3] = (mode & S_IXUSR) ? 's' : 'S';
    else
        buf[3] = (mode & S_IXUSR) ? 'x' : '-';

    /* Group */
    buf[4] = (mode & S_IRGRP) ? 'r' : '-';
    buf[5] = (mode & S_IWGRP) ? 'w' : '-';
    if (mode & S_ISGID)
        buf[6] = (mode & S_IXGRP) ? 's' : 'S';
    else
        buf[6] = (mode & S_IXGRP) ? 'x' : '-';

    /* Other */
    buf[7] = (mode & S_IROTH) ? 'r' : '-';
    buf[8] = (mode & S_IWOTH) ? 'w' : '-';
    if (mode & S_ISVTX)
        buf[9] = (mode & S_IXOTH) ? 't' : 'T';
    else
        buf[9] = (mode & S_IXOTH) ? 'x' : '-';

    buf[10] = '\0';
}

/*
** ─── get_owner ────────────────────────────────────────────────────────────────
** Returns the login name for uid, or the uid as a decimal string when no
** passwd entry exists.  The numeric fallback uses a static buffer — safe
** because callers use the result immediately (no re-entrancy concern here).
*/
const char  *get_owner(uid_t uid)
{
    struct passwd   *pw;
    static char      buf[32];

    pw = getpwuid(uid);
    if (pw)
        return (pw->pw_name);
    snprintf(buf, sizeof(buf), "%u", (unsigned int)uid);
    return (buf);
}

/*
** ─── get_group ────────────────────────────────────────────────────────────────
** Same idea for gid.
*/
const char  *get_group(gid_t gid)
{
    struct group    *gr;
    static char      buf[32];

    gr = getgrgid(gid);
    if (gr)
        return (gr->gr_name);
    snprintf(buf, sizeof(buf), "%u", (unsigned int)gid);
    return (buf);
}
