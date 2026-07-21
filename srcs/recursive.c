#include "../includes/ft_ls.h"

void recursive_traverse(const char *path, const t_options *opts)
{
	DIR *dir;
	struct dirent *entry;

	dir = opendir(path);
	if (!dir)
	{
		print_error(path);
		return;
	}

	printf("%s:\n", path);
	while ((entry = readdir(dir)) != NULL)
	{
		if (!opts->a && entry->d_name[0] == '.')
			continue;
		printf("%s\n", entry->d_name);
	}

	rewinddir(dir);
	while ((entry = readdir(dir)) != NULL)
	{
		if (entry->d_type != DT_DIR)
			continue;
		if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
			continue;
		char *subpath = join_path(path, entry->d_name);
		recursive_traverse(subpath, opts);
		free(subpath);
	}

	closedir(dir);
}
