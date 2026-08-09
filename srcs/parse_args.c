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

static int	apply_flag(char c, t_options *opts)
{
	if (c == 'l')
		opts->l = 1;
	else if (c == 'R')
		opts->big_r = 1;
	else if (c == 'a')
		opts->a = 1;
	else if (c == 'r')
		opts->r = 1;
	else if (c == 't')
		opts->t = 1;
	else
		return (-1);
	return (0);
}

static int	illegal_option(char c)
{
	fprintf(stderr, "ft_ls: illegal option -- %c\n", c);
	fprintf(stderr, "usage: ft_ls [-Ralrt] [file ...]\n");
	return (1);
}

static int	paths_push(char ***paths, int *npath, int *cap, char *arg)
{
	char	**tmp;

	if (*npath == *cap)
	{
		if (*cap == 0)
			*cap = 8;
		else
			*cap = *cap * 2;
		tmp = realloc(*paths, (size_t)(*cap) * sizeof(char *));
		if (!tmp)
		{
			perror("ft_ls: realloc");
			return (-1);
		}
		*paths = tmp;
	}
	(*paths)[(*npath)++] = arg;
	return (0);
}

static int	parse_cluster(char *arg, t_options *opts)
{
	int	j;

	j = 1;
	while (arg[j])
	{
		if (apply_flag(arg[j], opts) == -1)
			return (illegal_option(arg[j]));
		j++;
	}
	return (0);
}

int	parse_args(char **argv, t_options *opts, char ***paths, int *npath)
{
	int	i;
	int	cap;
	int	p_opts;

	ft_bzero(opts, sizeof(t_options));
	*paths = NULL;
	*npath = 0;
	cap = 0;
	p_opts = 1;
	i = 0;
	while (argv[++i])
	{
		if (p_opts && strcmp(argv[i], "--") == 0)
			p_opts = 0;
		else if (p_opts && argv[i][0] == '-' && argv[i][1] != '\0')
		{
			if (parse_cluster(argv[i], opts) != 0)
				return (1);
		}
		else if (paths_push(paths, npath, &cap, argv[i]) == -1)
			return (1);
	}
	return (0);
}
