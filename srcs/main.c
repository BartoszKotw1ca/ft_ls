/* ************************************************************************** */
/*                                                                            */
/*                                                          :::      :::::::: */
/*   ft_ls.h                                              :+:      :+:    :+: */
/*                                                        +:+ +:+         +:+ */
/*   By: login <login@student.42.fr>                       +#+  +:+       +#+ */
/*                                                          +#+#+#+#+#+   +#+ */
/*   Created: 2026/08/09 12:00:00 by login                         #+#    #+# */
/*   Updated: 2026/08/09 12:00:00 by login                  ###   ########.fr */
/*                                                                            */
/* ************************************************************************** */

#include "../includes/ft_ls.h"

static int	cmp_alpha(const void *a, const void *b)
{
	return (strcmp(*(const char **)a, *(const char **)b));
}

static void	classify(char **paths, int npath, t_arglist *out, int *exit_code)
{
	struct stat	st;
	int			i;

	out->files = malloc((size_t)npath * sizeof(char *));
	out->dirs = malloc((size_t)npath * sizeof(char *));
	if (!out->files || !out->dirs)
		exit(1);
	out->nfiles = 0;
	out->ndirs = 0;
	i = 0;
	while (i < npath)
	{
		if (lstat(paths[i], &st) == -1)
		{
			ft_error(paths[i]);
			*exit_code = 2;
		}
		else if (S_ISDIR(st.st_mode))
			out->dirs[out->ndirs++] = paths[i];
		else
			out->files[out->nfiles++] = paths[i];
		i++;
	}
}

static void	print_all(t_arglist *al, t_options *opts, int npath, int *exit_code)
{
	int	i;
	int	print_header;

	i = 0;
	while (i < al->nfiles)
	{
		if (list_path(al->files[i], opts, 0) != 0)
			*exit_code = 2;
		i++;
	}
	print_header = (npath > 1) || opts->big_r;
	i = 0;
	while (i < al->ndirs)
	{
		if (i > 0 || al->nfiles > 0)
			printf("\n");
		if (list_path(al->dirs[i], opts, print_header) != 0)
			*exit_code = 2;
		i++;
	}
}

static void	execute_ls(char **paths, int npath, t_options *opts, int *exit_code)
{
	t_arglist	al;

	classify(paths, npath, &al, exit_code);
	if (al.nfiles > 1)
		qsort(al.files, (size_t)al.nfiles, sizeof(char *), cmp_alpha);
	if (al.ndirs > 1)
		qsort(al.dirs, (size_t)al.ndirs, sizeof(char *), cmp_alpha);
	print_all(&al, opts, npath, exit_code);
	free(al.files);
	free(al.dirs);
}

int	main(int argc, char **argv)
{
	t_options	opts;
	char		**paths;
	int			npath;
	int			exit_code;

	(void)argc;
	exit_code = parse_args(argv, &opts, &paths, &npath);
	if (exit_code)
		return (free(paths), exit_code);
	if (npath == 0)
	{
		free(paths);
		paths = malloc(sizeof(char *));
		if (!paths)
			return (1);
		paths[0] = ".";
		npath = 1;
	}
	execute_ls(paths, npath, &opts, &exit_code);
	free(paths);
	return (exit_code);
}
