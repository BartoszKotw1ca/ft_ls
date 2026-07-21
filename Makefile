NAME = ft_ls
CC = cc
CFLAGS = -Wall -Wextra -Werror
SRC_DIR = srcs
OBJ_DIR = obj
INC_DIR = includes
LIBFT_DIR = mylibft
LIBFT_NAME = mylibft.a
LIBFT = $(LIBFT_DIR)/$(LIBFT_NAME)
SRCS = $(SRC_DIR)/main.c \
	$(SRC_DIR)/parse_args.c \
	$(SRC_DIR)/list_dir.c \
	$(SRC_DIR)/error.c \
# 	$(SRC_DIR)/print_short.c \
# 	$(SRC_DIR)/print_long.c \
# 	$(SRC_DIR)/sort.c \
# 	$(SRC_DIR)/recursive.c \
# 	$(SRC_DIR)/stat_utils.c \
# 	$(SRC_DIR)/utils.c
OBJS = $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(SRCS))

all: $(NAME)

$(NAME): $(OBJS) $(LIBFT)
	$(CC) $(CFLAGS) -I$(INC_DIR) -I$(LIBFT_DIR) $^ -o $@

$(LIBFT):
	$(MAKE) -C $(LIBFT_DIR)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR)
	$(CC) $(CFLAGS) -I$(INC_DIR) -I$(LIBFT_DIR) -c $< -o $@

clean:
	rm -rf $(OBJ_DIR)
	$(MAKE) -C $(LIBFT_DIR) clean

fclean: clean
	rm -f $(NAME)
	rm -f $(LIBFT)
	$(MAKE) -C $(LIBFT_DIR) fclean

re: fclean all

.PHONY: all clean fclean re
