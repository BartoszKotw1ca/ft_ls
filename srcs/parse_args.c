#include "../includes/ft_ls.h"

/*
** ─── HELPERS ─────────────────────────────────────────────────────────────────
*/

/* Apply a single option character to *opts.
** Returns 0 on success, -1 if the character is not a recognised flag. */
static int  apply_flag(char c, t_options *opts)
{
    if (c == 'l') { opts->l = 1; return (0); }
    if (c == 'R') { opts->R = 1; return (0); }
    if (c == 'a') { opts->a = 1; return (0); }
    if (c == 'r') { opts->r = 1; return (0); }
    if (c == 't') { opts->t = 1; return (0); }
    return (-1);
}

/* Print the same illegal-option error ls itself prints, then return 1. */
static int  illegal_option(char c)
{
    fprintf(stderr, "ft_ls: illegal option -- %c\n", c);
    fprintf(stderr, "usage: ft_ls [-Ralrt] [file ...]\n");
    return (1);
}

/*
** ─── PATH LIST HELPERS ───────────────────────────────────────────────────────
** We collect non-option arguments into a dynamically grown array.
*/

static int  paths_push(char ***paths, int *npath, int *cap, char *arg)
{
    char **tmp;

    if (*npath == *cap)
    {
        *cap = (*cap == 0) ? 8 : *cap * 2;
        tmp = realloc(*paths, (size_t)(*cap) * sizeof(char *));
        if (!tmp)
        {
            perror("ft_ls: realloc");
            return (-1);
        }
        *paths = tmp;
    }
    (*paths)[(*npath)++] = arg;   /* argv strings live for the process lifetime */
    return (0);
}

/*
** ─── MAIN PARSER ─────────────────────────────────────────────────────────────
**
** Iterates over argv[1..argc-1].
**
** • An argument that starts with '-' and has at least one more character is
**   treated as a flag cluster (e.g. "-lRart").
**
** • The special argument "--" ends option parsing; everything after it is a
**   path, even if it starts with '-'.
**
** • A bare '-' (just a hyphen) is treated as a path, like ls does.
**
** • Anything else is a path.
**
** Returns 0 on success, 1 on illegal option (caller should exit(1)).
*/
int parse_args(int argc, char **argv,
               t_options *opts, char ***paths, int *npath)
{
    int  i;
    int  j;
    int  cap;
    int  parsing_opts;  /* becomes 0 after "--" */

    /* Zero-initialise the options struct */
    opts->l = 0;
    opts->R = 0;
    opts->a = 0;
    opts->r = 0;
    opts->t = 0;

    *paths  = NULL;
    *npath  = 0;
    cap     = 0;
    parsing_opts = 1;

    i = 1;
    while (i < argc)
    {
        /* End-of-options sentinel */
        if (parsing_opts && strcmp(argv[i], "--") == 0)
        {
            parsing_opts = 0;
            i++;
            continue;
        }

        /* Flag cluster: starts with '-', has at least one char after it,
           and we have not yet seen "--" */
        if (parsing_opts && argv[i][0] == '-' && argv[i][1] != '\0')
        {
            j = 1;
            while (argv[i][j])
            {
                if (apply_flag(argv[i][j], opts) == -1)
                    return (illegal_option(argv[i][j]));
                j++;
            }
        }
        else
        {
            /* Path argument (includes bare "-") */
            if (paths_push(paths, npath, &cap, argv[i]) == -1)
                return (1);
        }
        i++;
    }
    return (0);
}