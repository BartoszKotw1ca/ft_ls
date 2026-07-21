#include "../includes/ft_ls.h"

/*
** ft_error – prints a diagnostic to stderr in the same format as ls:
**
**   ft_ls: <path>: <system error message>
**
** It does NOT exit; the caller decides whether to continue or stop.
*/
void    ft_error(const char *path)
{
    fprintf(stderr, "ft_ls: %s: %s\n", path, strerror(errno));
}
