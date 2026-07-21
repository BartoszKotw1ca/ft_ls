/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   ft_strnstr.c                                       :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: bkotwica <bkotwica@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2024/02/28 17:23:14 by bkotwica          #+#    #+#             */
/*   Updated: 2024/03/10 13:51:53 by bkotwica         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "libft.h"

char	*ft_strnstr(const char *big, const char *little, size_t len)
{
	size_t	i;
	size_t	j;
	char	*str;
	char	*to_find;

	if (!big && !len)
		return (NULL);
	if (!*little)
		return ((char *)big);
	to_find = (char *)little;
	str = (char *)big;
	i = 0;
	j = 0;
	if (*to_find == '\0')
		return (str);
	while (str[i] != 0 && len-- > 0)
	{
		while (str[i + j] == to_find[j] && str[i + j] != 0 && j < len + 1)
			j++;
		if (to_find[j] == 0)
			return (str + i);
		i++;
		j = 0;
	}
	return (0);
}
