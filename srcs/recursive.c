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

static void	print_dir_entries(DIR *dir, const t_options *opts)
{
	struct dirent	*entry;

	entry = readdir(dir);
	while (entry)
	{
		if (opts->a || entry->d_name[0] != '.')
			printf("%s\n", entry->d_name);
		entry = readdir(dir);
	}
}

static void	process_subdirs(DIR *dir, const char *path, const t_options *opts)
{
	struct dirent	*entry;
	char			*subpath;

	rewinddir(dir);
	entry = readdir(dir);
	while (entry)
	{
		if ((opts->a || entry->d_name[0] != '.')
			&& entry->d_type == DT_DIR
			&& strcmp(entry->d_name, ".") != 0
			&& strcmp(entry->d_name, "..") != 0)
		{
			subpath = join_path(path, entry->d_name);
			recursive_traverse(subpath, opts);
			free(subpath);
		}
		entry = readdir(dir);
	}
}

void	recursive_traverse(const char *path, const t_options *opts)
{
	DIR	*dir;

	dir = opendir(path);
	if (!dir)
	{
		print_error(path);
		return ;
	}
	printf("%s:\n", path);
	print_dir_entries(dir, opts);
	process_subdirs(dir, path, opts);
	closedir(dir);
}
