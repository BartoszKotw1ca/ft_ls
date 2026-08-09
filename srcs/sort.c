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
	const t_entry	*ea;
	const t_entry	*eb;

	ea = (const t_entry *)a;
	eb = (const t_entry *)b;
	return (strcmp(ea->name, eb->name));
}

static int	cmp_time(const void *a, const void *b)
{
	const t_entry	*ea;
	const t_entry	*eb;

	ea = (const t_entry *)a;
	eb = (const t_entry *)b;
	if (eb->st.st_mtime != ea->st.st_mtime)
	{
		if (eb->st.st_mtime > ea->st.st_mtime)
			return (1);
		return (-1);
	}
	return (strcmp(ea->name, eb->name));
}

static void	reverse_entries(t_entry *entries, int n)
{
	t_entry	tmp;
	int		lo;
	int		hi;

	lo = 0;
	hi = n - 1;
	while (lo < hi)
	{
		tmp = entries[lo];
		entries[lo] = entries[hi];
		entries[hi] = tmp;
		lo++;
		hi--;
	}
}

void	sort_entries(t_entry *entries, int n, const t_options *opts)
{
	if (n <= 1)
		return ;
	if (opts->t)
		qsort(entries, (size_t)n, sizeof(t_entry), cmp_time);
	else
		qsort(entries, (size_t)n, sizeof(t_entry), cmp_alpha);
	if (opts->r)
		reverse_entries(entries, n);
}
