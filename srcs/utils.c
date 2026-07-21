#include "../includes/ft_ls.h"

char *join_path(const char *dir, const char *name)
{
	size_t len = strlen(dir) + strlen(name) + 2;
	char *path = malloc(len);

	if (!path)
		return (NULL);
	snprintf(path, len, "%s/%s", dir, name);
	return (path);
}

void free_entries(t_entry *entries, int count)
{
	(void)count;
	free(entries);
}
