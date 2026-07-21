#include "../includes/ft_ls.h"

int get_entry_stat(t_entry *entry)
{
	if (stat(entry->path, &entry->st) != 0)
	{
		print_error(entry->path);
		return (0);
	}
	return (1);
}

char *format_permissions(mode_t mode)
{
	char *str = malloc(11);

	if (!str)
		return (NULL);
	str[0] = (S_ISDIR(mode)) ? 'd' : '-';
	str[1] = (mode & S_IRUSR) ? 'r' : '-';
	str[2] = (mode & S_IWUSR) ? 'w' : '-';
	str[3] = (mode & S_IXUSR) ? 'x' : '-';
	str[4] = (mode & S_IRGRP) ? 'r' : '-';
	str[5] = (mode & S_IWGRP) ? 'w' : '-';
	str[6] = (mode & S_IXGRP) ? 'x' : '-';
	str[7] = (mode & S_IROTH) ? 'r' : '-';
	str[8] = (mode & S_IWOTH) ? 'w' : '-';
	str[9] = (mode & S_IXOTH) ? 'x' : '-';
	str[10] = '\0';
	return (str);
}

char *format_mtime(const struct stat *st)
{
	char *buf = malloc(20);
	struct tm *timeinfo;

	if (!buf)
		return (NULL);
	timeinfo = localtime(&st->st_mtime);
	strftime(buf, 20, "%b %e %H:%M", timeinfo);
	return (buf);
}
