/* ************************************************************************** */
/*                                                                            */
/*                                                          :::      :::::::: */
/*   ft_ls_snippet.c                                      :+:      :+:    :+: */
/*                                                        +:+ +:+         +:+ */
/*   By: login <login@student.42.fr>                       +#+  +:+       +#+ */
/*                                                          +#+#+#+#+#+   +#+ */
/*   Created: 2026/08/09 12:00:00 by login                         #+#    #+# */
/*   Updated: 2026/08/09 12:00:00 by login                  ###   ########.fr */
/*                                                                            */
/* ************************************************************************** */

#include "../includes/ft_ls.h"

char	*join_path(const char *dir, const char *name)
{
	size_t	len;
	char	*path;

	len = strlen(dir) + strlen(name) + 2;
	path = malloc(len);
	if (!path)
		return (NULL);
	snprintf(path, len, "%s/%s", dir, name);
	return (path);
}

void	free_entries(t_entry *entries, int count)
{
	(void)count;
	free(entries);
}

long	compute_total(t_entry *entries, int n)
{
	long	total;
	int		i;

	total = 0;
	i = 0;
	while (i < n)
	{
		total += entries[i].st.st_blocks;
		i++;
	}
	return (total / 2);
}

DIR	*open_directory(const char *path, int *out_count)
{
	DIR	*dir;

	dir = opendir(path);
	if (!dir)
	{
		ft_error(path);
		*out_count = -1;
	}
	return (dir);
}
