#include "../includes/ft_ls.h"

void print_long(const t_entry *entries, int count)
{
	for (int i = 0; i < count; ++i)
	{
		char *perms = format_permissions(entries[i].st.st_mode);
		char *mtime = format_mtime(&entries[i].st);
		printf("%s %2ld %s %s %6lld %s %s\n",
			perms,
			(long)entries[i].st.st_nlink,
			getpwuid(entries[i].st.st_uid)->pw_name,
			getgrgid(entries[i].st.st_gid)->gr_name,
			(long long)entries[i].st.st_size,
			mtime,
			entries[i].name);
		free(perms);
		free(mtime);
	}
}
