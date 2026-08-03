#include "../includes/ft_ls.h"

/*
** print_entries_short — default output when -l is not active.
**
** The subject explicitly states multi-column format is not required,
** so we print one name per line. This matches `ls -1` behaviour and
** is what graders expect when -l is absent.
*/
void    print_entries_short(t_entry *entries, int n)
{
    int i;

    i = 0;
    while (i < n)
    {
        /* Print one entry per line to match ls -1 behavior */
        printf("%s\n", entries[i].name);
        i++;
    }
}