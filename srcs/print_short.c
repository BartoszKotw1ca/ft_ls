#include "../includes/ft_ls.h"

void print_short(const t_entry *entries, int count)
{
	for (int i = 0; i < count; ++i)
	{
		printf("%s\n", entries[i].name);
	}
}
