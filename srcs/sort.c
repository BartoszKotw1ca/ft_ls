#include "../includes/ft_ls.h"

static int compare_name(const t_entry *a, const t_entry *b)
{
	return (strcmp(a->name, b->name));
}

static int compare_mtime(const t_entry *a, const t_entry *b)
{
	if (a->st.st_mtime < b->st.st_mtime)
		return (1);
	if (a->st.st_mtime > b->st.st_mtime)
		return (-1);
	return (compare_name(a, b));
}

void sort_entries(t_entry *entries, int count, const t_options *opts)
{
	for (int i = 0; i < count - 1; ++i)
	{
		for (int j = i + 1; j < count; ++j)
		{
			int cmp = opts->t ? compare_mtime(&entries[i], &entries[j]) : compare_name(&entries[i], &entries[j]);
			if ((opts->r && cmp < 0) || (!opts->r && cmp > 0))
			{
				t_entry tmp = entries[i];
				entries[i] = entries[j];
				entries[j] = tmp;
			}
		}
	}
}
