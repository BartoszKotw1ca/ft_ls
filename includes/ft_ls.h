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
#ifndef FT_LS_H
# define FT_LS_H

# include <sys/stat.h>
# include <sys/types.h>
# include <dirent.h>
# include <pwd.h>
# include <grp.h>
# include <time.h>
# include <stdio.h>
# include <stdlib.h>
# include <string.h>
# include <unistd.h>
# include <errno.h>
# include "../mylibft/mylibft.h"

typedef struct s_widths
{
	int	nlink;
	int	owner;
	int	group;
	int	size;
}	t_widths;

typedef struct s_arglist
{
	char	**files;
	int		nfiles;
	char	**dirs;
	int		ndirs;
}	t_arglist;

typedef struct s_options
{
	int	l;
	int	big_r;
	int	a;
	int	r;
	int	t;
}	t_options;

typedef struct s_entry
{
	char		name[256];
	char		fullpath[4096];
	struct stat	st;
	int			is_link;
	char		link_target[4096];
}	t_entry;

int			parse_args(char **argv, t_options *opts, char ***paths,
				int *npath);

int			list_path(const char *path, const t_options *opts,
				int print_header);

void		ft_error(const char *path);
void		sort_entries(t_entry *entries, int n, const t_options *opts);
void		print_entries_short(t_entry *entries, int n);

void		mode_to_str(mode_t mode, char *buf);
const char	*get_owner(uid_t uid);
const char	*get_group(gid_t gid);

void		print_entries_long(t_entry *entries, int n);
t_entry		*read_entries(const char *path, const t_options *opts,
				int *out_count);
void		read_link_target(t_entry *entry, const char *path);
DIR			*open_directory(const char *path, int *out_count);
void		set_other_permissions(char *str, mode_t mode);
void		set_group_permissions(char *str, mode_t mode);
void		set_user_permissions(char *str, mode_t mode);
int			cmp_time_main(const void *a, const void *b);
void		reverse_paths_main(char **paths, int n);

#endif /* FT_LS_H */
