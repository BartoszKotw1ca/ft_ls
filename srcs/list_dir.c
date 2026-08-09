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

static long	compute_total(t_entry *entries, int count)
{
	long	total;
	int		i;

	total = 0;
	i = 0;
	while (i < count)
	{
		total += entries[i].st.st_blocks;
		i++;
	}
	return (total / 2);
}

static int	is_recursive_dir(t_entry *entry, const t_options *opts)
{
	if (!S_ISDIR(entry->st.st_mode))
		return (0);
	if (!opts->a && entry->name[0] == '.')
		return (0);
	if (strcmp(entry->name, ".") == 0)
		return (0);
	if (strcmp(entry->name, "..") == 0)
		return (0);
	return (1);
}

static int	recurse_dirs(t_entry *entries, int count, const t_options *opts)
{
	int	i;
	int	ret;

	i = 0;
	ret = 0;
	while (i < count)
	{
		if (is_recursive_dir(&entries[i], opts))
		{
			printf("\n");
			if (list_path(entries[i].fullpath, opts, 1) != 0)
				ret = 1;
		}
		i++;
	}
	return (ret);
}

static int	list_directory(const char *path, const t_options *opts,
		int print_header)
{
	t_entry	*entries;
	int		count;
	int		ret;

	if (print_header)
		printf("%s:\n", path);
	entries = read_entries(path, opts, &count);
	if (count == -1)
		return (1);
	sort_entries(entries, count, opts);
	if (opts->l)
		printf("total %ld\n", compute_total(entries, count));
	if (opts->l)
		print_entries_long(entries, count);
	else
		print_entries_short(entries, count);
	ret = 0;
	if (opts->big_r)
		ret = recurse_dirs(entries, count, opts);
	free(entries);
	return (ret);
}

int	list_path(const char *path, const t_options *opts, int print_header)
{
	struct stat	st;
	t_entry		e;

	if (lstat(path, &st) == -1)
	{
		ft_error(path);
		return (1);
	}
	if (S_ISDIR(st.st_mode))
		return (list_directory(path, opts, print_header));
	strncpy(e.name, path, sizeof(e.name) - 1);
	e.name[sizeof(e.name) - 1] = '\0';
	strncpy(e.fullpath, path, sizeof(e.fullpath) - 1);
	e.fullpath[sizeof(e.fullpath) - 1] = '\0';
	e.st = st;
	e.is_link = S_ISLNK(st.st_mode);
	e.link_target[0] = '\0';
	if (e.is_link)
		read_link_target(&e, path);
	if (opts->l)
		print_entries_long(&e, 1);
	else
		printf("%s\n", e.name);
	return (0);
}
