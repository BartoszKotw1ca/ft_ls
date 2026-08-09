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

static char	get_file_type(mode_t mode)
{
	if (S_ISDIR(mode))
		return ('d');
	if (S_ISLNK(mode))
		return ('l');
	if (S_ISCHR(mode))
		return ('c');
	if (S_ISBLK(mode))
		return ('b');
	if (S_ISFIFO(mode))
		return ('p');
	if (S_ISSOCK(mode))
		return ('s');
	return ('-');
}

static void	set_special_permissions(char *mode_str, mode_t mode)
{
	if (mode & S_ISUID)
	{
		if (mode & S_IXUSR)
			mode_str[3] = 's';
		else
			mode_str[3] = 'S';
	}
	if (mode & S_ISGID)
	{
		if (mode & S_IXGRP)
			mode_str[6] = 's';
		else
			mode_str[6] = 'S';
	}
	if (mode & S_ISVTX)
	{
		if (mode & S_IXOTH)
			mode_str[9] = 't';
		else
			mode_str[9] = 'T';
	}
}

void	mode_to_str(mode_t mode, char *mode_str)
{
	mode_str[0] = get_file_type(mode);
	set_user_permissions(mode_str, mode);
	set_group_permissions(mode_str, mode);
	set_other_permissions(mode_str, mode);
	mode_str[10] = '\0';
	set_special_permissions(mode_str, mode);
}

const char	*get_owner(uid_t uid)
{
	struct passwd	*pw;
	static char		buf[32];

	pw = getpwuid(uid);
	if (pw)
		return (pw->pw_name);
	snprintf(buf, sizeof(buf), "%u", (unsigned int)uid);
	return (buf);
}

const char	*get_group(gid_t gid)
{
	struct group	*gr;
	static char		buf[32];

	gr = getgrgid(gid);
	if (gr)
		return (gr->gr_name);
	snprintf(buf, sizeof(buf), "%u", (unsigned int)gid);
	return (buf);
}
