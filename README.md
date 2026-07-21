# ft_ls
Project from 42 Advance

# Docker Ubuntu Environment Setup

## 1. Start the Ubuntu Docker Container

```bash
docker run --rm -it -v "$(pwd)":/usr/src/app -w /usr/src/app ubuntu:latest bash
```

## 2. Install Required Tools (First Time Only)

Inside the container:

```bash
apt-get update && apt-get install -y build-essential valgrind
```

## 3. Build and Run the Project

```bash
make re
valgrind ./ft_ls [optional_arguments]
```