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

int	cmp_time_main(const void *a, const void *b)
{
	struct stat	sa;
	struct stat	sb;

	if (lstat(*(const char **)a, &sa) == -1)
		return (0);
	if (lstat(*(const char **)b, &sb) == -1)
		return (0);
	if (sa.st_mtime < sb.st_mtime)
		return (1);
	if (sa.st_mtime > sb.st_mtime)
		return (-1);
	return (strcmp(*(const char **)a, *(const char **)b));
}

void	reverse_paths_main(char **paths, int n)
{
	char	*tmp;
	int		i;

	i = 0;
	while (i < n / 2)
	{
		tmp = paths[i];
		paths[i] = paths[n - 1 - i];
		paths[n - 1 - i] = tmp;
		i++;
	}
}
