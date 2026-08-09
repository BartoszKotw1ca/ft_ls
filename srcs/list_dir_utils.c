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

static void	build_fullpath(char *dst, const char *dir, const char *name)
{
	size_t	len;

	len = strlen(dir);
	if (len > 0 && dir[len - 1] == '/')
		snprintf(dst, 4096, "%s%s", dir, name);
	else
		snprintf(dst, 4096, "%s/%s", dir, name);
}

static t_entry	*entries_push(t_entry **arr, int *count, int *cap)
{
	t_entry	*tmp;

	if (*count == *cap)
	{
		if (*cap == 0)
			*cap = 32;
		else
			*cap = *cap * 2;
		tmp = realloc(*arr, (size_t)(*cap) * sizeof(t_entry));
		if (!tmp)
		{
			perror("ft_ls: realloc");
			free(*arr);
			exit(1);
		}
		*arr = tmp;
	}
	return (&(*arr)[(*count)++]);
}

static void	fill_entry(t_entry *entry, const char *path, const char *name)
{
	strncpy(entry->name, name, sizeof(entry->name) - 1);
	entry->name[sizeof(entry->name) - 1] = '\0';
	build_fullpath(entry->fullpath, path, name);
	if (lstat(entry->fullpath, &entry->st) == -1)
	{
		ft_error(entry->fullpath);
		memset(&entry->st, 0, sizeof(entry->st));
	}
	entry->is_link = S_ISLNK(entry->st.st_mode);
	entry->link_target[0] = '\0';
	if (entry->is_link)
		read_link_target(entry, entry->fullpath);
}

void	read_link_target(t_entry *entry, const char *path)
{
	ssize_t	len;

	len = readlink(path, entry->link_target,
			sizeof(entry->link_target) - 1);
	if (len >= 0)
		entry->link_target[(size_t)len] = '\0';
}

t_entry	*read_entries(const char *path, const t_options *opts, int *out_count)
{
	DIR				*dir;
	struct dirent	*de;
	t_entry			*entries;
	int				count;
	int				cap;

	entries = NULL;
	count = 0;
	cap = 0;
	dir = open_directory(path, out_count);
	if (!dir)
		return (NULL);
	de = readdir(dir);
	while (de)
	{
		if (opts->a || de->d_name[0] != '.')
			fill_entry(entries_push(&entries, &count, &cap),
				path, de->d_name);
		de = readdir(dir);
	}
	closedir(dir);
	*out_count = count;
	return (entries);
}
