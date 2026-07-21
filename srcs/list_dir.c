#include "../includes/ft_ls.h"

/*
** list_path – stub placeholder.
** Will be replaced with the full implementation (readdir, sort, print).
** For now it just prints the path so main.c / parse_args.c can be compiled
** and tested in isolation.
*/
int     list_path(const char *path, const t_options *opts, int print_header)
{
    (void)opts;

    if (print_header)
        printf("%s:\n", path);
    else
        printf("%s\n", path);
    return (0);
}