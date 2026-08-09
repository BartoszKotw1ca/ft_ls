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

static void	format_time(time_t mtime, char *buf, size_t sz)
{
	time_t		now;
	struct tm	*tm;

	now = time(NULL);
	tm = localtime(&mtime);
	if (!tm)
	{
		strncpy(buf, "??? ?? ??:??", sz - 1);
		buf[sz - 1] = '\0';
		return ;
	}
	if (mtime <= now && (now - mtime) < (time_t)(180 * 86400))
		strftime(buf, sz, "%b %e %H:%M", tm);
	else
		strftime(buf, sz, "%b %e  %Y", tm);
}

static void	update_widths(t_widths *w, t_entry *e)
{
	char	tmp[64];
	int		len;

	len = snprintf(tmp, sizeof(tmp), "%lu",
			(unsigned long)e->st.st_nlink);
	if (len > w->nlink)
		w->nlink = len;
	len = (int)strlen(get_owner(e->st.st_uid));
	if (len > w->owner)
		w->owner = len;
	len = (int)strlen(get_group(e->st.st_gid));
	if (len > w->group)
		w->group = len;
	len = snprintf(tmp, sizeof(tmp), "%lld",
			(long long)e->st.st_size);
	if (len > w->size)
		w->size = len;
}

static t_widths	scan_widths(t_entry *entries, int n)
{
	t_widths	w;
	int			i;

	w.nlink = 1;
	w.owner = 1;
	w.group = 1;
	w.size = 1;
	i = 0;
	while (i < n)
	{
		update_widths(&w, &entries[i]);
		i++;
	}
	return (w);
}

static void	print_one_long(t_entry *e, t_widths *w)
{
	char	mode[11];
	char	timebuf[32];

	mode_to_str(e->st.st_mode, mode);
	format_time(e->st.st_mtime, timebuf, sizeof(timebuf));
	printf("%s %*lu %-*s %-*s %*lld %s %s",
		mode,
		w->nlink, (unsigned long)e->st.st_nlink,
		w->owner, get_owner(e->st.st_uid),
		w->group, get_group(e->st.st_gid),
		w->size, (long long)e->st.st_size,
		timebuf,
		e->name);
	if (e->is_link && e->link_target[0])
		printf(" -> %s", e->link_target);
	printf("\n");
}

void	print_entries_long(t_entry *entries, int n)
{
	t_widths	w;
	int			i;

	if (n == 0)
		return ;
	w = scan_widths(entries, n);
	i = 0;
	while (i < n)
	{
		print_one_long(&entries[i], &w);
		i++;
	}
}
