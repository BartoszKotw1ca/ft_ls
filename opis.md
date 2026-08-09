FT_LS — dokładne wyjaśnienie projektu

1. Czym jest projekt?

ft_ls jest własną implementacją polecenia Unix/Linux ls.

Standardowe:

ls

pokazuje zawartość katalogu.

Nasz program:

./ft_ls

ma wykonywać podobne zadanie, ale cały mechanizm został napisany samodzielnie w C.

Projekt obsługuje następujące opcje:

-l
-R
-a
-r
-t

oraz ich kombinacje:

./ft_ls -la
./ft_ls -Ral
./ft_ls -ltr
./ft_ls -laRt
./ft_ls -lartR

W kodzie opcje są przechowywane w strukturze:

typedef struct s_options
{
    int l;
    int big_r;
    int a;
    int r;
    int t;
} t_options;

czyli:

l      -> -l
big_r  -> -R
a      -> -a
r      -> -r
t      -> -t

Źródło: includes/ft_ls.h.

⸻

2. Najważniejszy przepływ całego programu

Cały program można zapamiętać jako:

                    ./ft_ls [OPTIONS] [PATHS]
                              |
                              v
                       parse_args()
                              |
                              v
                     options + paths
                              |
                              v
                         main()
                              |
                              v
                        execute_ls()
                              |
                              v
                         classify()
                              |
                 +------------+------------+
                 |                         |
                 v                         v
              FILES                    DIRECTORIES
                 |                         |
                 |                         v
                 |                    list_path()
                 |                         |
                 |                         v
                 |                    lstat()
                 |                         |
                 |              +----------+----------+
                 |              |                     |
                 |              v                     v
                 |           FILE                  DIRECTORY
                 |              |                     |
                 |              |                     v
                 |              |              list_directory()
                 |              |                     |
                 |              |                     v
                 |              |               read_entries()
                 |              |                     |
                 |              |                     v
                 |              |               t_entry[]
                 |              |                     |
                 |              |                     v
                 |              |               sort_entries()
                 |              |                     |
                 |              |              +------+------+
                 |              |              |             |
                 |              |              v             v
                 |              |           short           -l
                 |              |           output         output
                 |              |                              |
                 |              |                              v
                 |              |                         stat data
                 |              |                              |
                 |              |                              v
                 |              |                    permissions/owner/
                 |              |                    group/size/date
                 |              |
                 |              v
                 |           print file
                 |
                 |
                 +-----------------------------------+
                                                     |
                                                if -R
                                                     |
                                                     v
                                              recurse_dirs()
                                                     |
                                                     v
                                                list_path()
                                                     |
                                                     +----> ...

Najważniejsze funkcje projektu to:

main()
parse_args()
classify()
execute_ls()
list_path()
list_directory()
read_entries()
sort_entries()
print_entries_short()
print_entries_long()
recurse_dirs()

⸻

3. Struktura projektu

Główna część projektu znajduje się w:

ft_ls/
│
├── includes/
│   └── ft_ls.h
│
├── srcs/
│   ├── main.c
│   ├── main_utils.c
│   ├── parse_args.c
│   ├── list_dir.c
│   ├── list_dir_utils.c
│   ├── recursive.c
│   ├── sort.c
│   ├── print_short.c
│   ├── print_long.c
│   ├── permissions_utils.c
│   ├── stat_utils.c
│   ├── utils.c
│   └── error.c
│
├── mylibft/
│   ├── libft/
│   ├── ft_printf/
│   ├── get_next_line/
│   ├── mylibft.h
│   └── mylibft.a
│
├── tests/
│
├── test.sh
├── test_check.sh
├── test_parser.sh
└── tests/run_tests.sh

Wspólny nagłówek ft_ls.h zawiera struktury oraz prototypy funkcji potrzebnych między modułami.

⸻

4. includes/ft_ls.h

To jest centralny nagłówek projektu.

Zawiera biblioteki:

#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <pwd.h>
#include <grp.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

oraz:

#include "../mylibft/mylibft.h"

Najważniejsze są cztery struktury.

⸻

5. t_widths

typedef struct s_widths
{
    int nlink;
    int owner;
    int group;
    int size;
} t_widths;

Ta struktura służy do wyrównania kolumn przy:

./ft_ls -l

Przykład:

-rw-r--r--  1 user group    10 ...
-rw-r--r-- 12 user group 12345 ...

Program musi wiedzieć, jak szerokie mają być kolumny.

Dlatego sprawdza maksymalną długość:

nlink
owner
group
size

i dopiero potem drukuje dane.

⸻

6. t_arglist

typedef struct s_arglist
{
    char **files;
    int nfiles;
    char **dirs;
    int ndirs;
} t_arglist;

Ta struktura służy do rozdzielenia argumentów wejściowych na:

files
dirs

Przykład:

./ft_ls file.txt src Makefile include

po classify():

files:
    file.txt
    Makefile
dirs:
    src
    include

⸻

7. t_options

typedef struct s_options
{
    int l;
    int big_r;
    int a;
    int r;
    int t;
} t_options;

To jest konfiguracja działania programu.

Przykład:

./ft_ls -laRt

spowoduje:

l      = 1
big_r  = 1
a      = 1
r      = 0
t      = 1

⸻

8. t_entry

Najważniejsza struktura opisująca pojedynczy element katalogu:

typedef struct s_entry
{
    char name[256];
    char fullpath[4096];
    struct stat st;
    int is_link;
    char link_target[4096];
} t_entry;

Można ją rozumieć jako:

t_entry
│
├── name
│
├── fullpath
│
├── st
│
├── is_link
│
└── link_target

Przykład dla:

/home/user/project/src/main.c

może wyglądać logicznie tak:

name:
    main.c
fullpath:
    /home/user/project/src/main.c
st:
    wszystkie metadane pliku
is_link:
    0
link_target:
    ""

Jeżeli jest symbolic link:

name:
    config
fullpath:
    /home/user/project/config
is_link:
    1
link_target:
    /home/user/project/config_real

⸻

9. main() — punkt startowy

Program zaczyna się od:

int main(int argc, char **argv)

W tym projekcie argc nie jest używane bezpośrednio:

(void)argc;

Następnie:

exit_code = parse_args(argv, &opts, &paths, &npath);

czyli:

argv
 |
 v
parse_args()
 |
 +----> opts
 |
 +----> paths
 |
 +----> npath

Jeżeli parser zwróci błąd:

if (exit_code)
    return (free(paths), exit_code);

Program kończy działanie.

⸻

10. Co jeżeli użytkownik nie poda ścieżki?

Przykład:

./ft_ls

Nie mamy:

paths[0]

Dlatego program tworzy:

paths[0] = ".";

czyli bieżący katalog.

W efekcie:

./ft_ls

jest logicznie traktowane jako:

./ft_ls .

Kod robi to bezpośrednio w main().

⸻

11. Co oznacza .?

W systemach Unix:

.

oznacza:

bieżący katalog

Przykład:

Jeżeli terminal znajduje się w:

/home/user/42/ft_ls

to:

./ft_ls .

oznacza:

/home/user/42/ft_ls

⸻

12. Ścieżki względne i absolutne

Program może dostać:

./ft_ls .

albo:

./ft_ls src

albo:

./ft_ls ./src

albo:

./ft_ls ../

albo:

./ft_ls /home/user/project

Wewnętrznie program traktuje je jako string reprezentujący ścieżkę i przekazuje ją do funkcji systemowych takich jak:

lstat()
opendir()

⸻

13. parse_args() — parsowanie argumentów

Funkcja:

parse_args()

odpowiada za:

1. wyzerowanie opcji
2. przejście po argv
3. rozpoznanie flag
4. rozpoznanie ścieżek
5. zapisanie ścieżek do dynamicznej tablicy

Na początku:

ft_bzero(opts, sizeof(t_options));

czyli:

l = 0
big_r = 0
a = 0
r = 0
t = 0

⸻

14. Pojedyncze flagi

Kod apply_flag() rozpoznaje:

l
R
a
r
t

czyli:

-l
-R
-a
-r
-t

Nieznana opcja powoduje:

ft_ls: illegal option -- X
usage: ft_ls [-Ralrt] [file ...]

Źródłem tego komunikatu jest illegal_option().

⸻

15. Łączenie flag

Program obsługuje:

./ft_ls -la

Nie interpretuje tego jako jednej flagi la.

Funkcja:

parse_cluster()

przechodzi po każdym znaku:

-l a

czyli:

l -> apply_flag()
a -> apply_flag()

Przykład:

./ft_ls -lart

jest analizowane jako:

l
a
r
t

i kończy się:

l = 1
a = 1
r = 1
t = 1

⸻

16. --

Parser obsługuje również:

./ft_ls -- -file

Po pojawieniu się:

--

ustawiane jest:

p_opts = 0;

Od tego momentu kolejne argumenty są traktowane jako ścieżki, a nie jako opcje.

Czyli:

./ft_ls -- -file

oznacza:

--
 |
 +--> koniec interpretacji opcji
       |
       +--> "-file" = nazwa ścieżki

Kod obsługujący to znajduje się w parse_args().

⸻

17. Dynamiczna tablica ścieżek

Program nie wie, ile ścieżek użytkownik poda.

Może być:

./ft_ls file1 file2 file3

ale również:

./ft_ls file1 file2 file3 file4 file5 file6 file7 file8 file9 ...

Dlatego używane jest:

realloc()

Początkowo:

capacity = 0

pierwszy przydział:

capacity = 8

potem:

8
16
32
64
128
...

Kod paths_push() realizuje ten mechanizm.

⸻

18. classify() — najważniejszy podział

Po parserze mamy:

paths

np.:

[
    "README.md",
    "src",
    "Makefile",
    "include"
]

Następnie:

classify(paths, npath, &al, exit_code);

Dla każdej ścieżki wykonywane jest:

lstat(paths[i], &st);

Następnie:

S_ISDIR(st.st_mode)

sprawdza, czy jest to katalog.

Jeżeli tak:

dirs

Jeżeli nie:

files

Źródło: srcs/main.c.

⸻

19. Dlaczego lstat()?

lstat() pobiera informacje o elemencie systemu plików.

Przykładowo możemy dowiedzieć się:

typ pliku
uprawnienia
właściciel
grupa
rozmiar
czas modyfikacji
liczba hard linków

Dane są zapisywane do:

struct stat

W projekcie:

struct stat st;

jest podstawą późniejszego:

-l
-R
-t

⸻

20. lstat() vs symbolic link

To jest bardzo ważne.

Jeżeli mamy:

real_file
     ^
     |
my_link

to lstat() pobiera informacje o:

my_link

a nie o celu linku.

Dzięki temu program może rozpoznać:

S_ISLNK(st.st_mode)

i później użyć:

readlink()

żeby poznać cel.

⸻

21. execute_ls()

Po classify() mamy:

files
dirs

Następnie program sortuje:

files
dirs

osobno.

Jeżeli:

-t = 1

używany jest:

cmp_time_main

w przeciwnym razie:

cmp_alpha

Jeżeli:

-r = 1

wykonywane jest:

reverse_paths_main()

Kod realizujący ten etap znajduje się w execute_ls().

⸻

22. Sortowanie argumentów wejściowych

Załóżmy:

./ft_ls zzz.txt aaa.txt src bbb.txt

Najpierw program rozdzieli:

files:
    zzz.txt
    aaa.txt
    bbb.txt
dirs:
    src

Potem sortuje pliki.

Bez -t:

aaa.txt
bbb.txt
zzz.txt

Z -r:

zzz.txt
bbb.txt
aaa.txt

Z -t:

najstarszy/najnowszy według implementowanego comparatora

Przy równym czasie używana jest nazwa jako tie-breaker.

⸻

23. print_all()

Po posortowaniu:

files
dirs

program najpierw przetwarza pliki:

list_path(al->files[i], opts, 0);

a później katalogi:

list_path(al->dirs[i], opts, print_header);

Dlatego:

./ft_ls file.txt src

nie oznacza:

wejdź do src
potem file.txt

tylko:

file.txt
src:
...

Źródło: print_all().

⸻

24. Kiedy drukowany jest nagłówek katalogu?

W print_all():

print_header = (npath > 1) || opts->big_r;

Czyli nagłówek jest potrzebny, gdy:

podano więcej niż jedną ścieżkę

lub:

użyto -R

Przykład:

./ft_ls src

może nie potrzebować:

src:

Natomiast:

./ft_ls src include

potrzebuje rozróżnić:

include:
...
src:
...

⸻

25. list_path() — centralna funkcja

To jedna z najważniejszych funkcji projektu.

Dostaje:

list_path(path, opts, print_header)

Najpierw:

lstat(path, &st)

Jeżeli ścieżka nie istnieje:

error

Jeżeli:

S_ISDIR(st.st_mode)

jest prawdą:

list_directory()

Jeżeli nie:

traktuj jako pojedynczy plik

Czyli:

                   list_path()
                       |
                    lstat()
                       |
             +---------+---------+
             |                   |
          ERROR               SUCCESS
                                 |
                        +--------+--------+
                        |                 |
                     DIRECTORY          FILE
                        |                 |
                        v                 v
                list_directory()      print file

Źródło: srcs/list_dir.c.

⸻

26. Przypadek: podano zwykły plik

Przykład:

./ft_ls README.md

list_path() robi:

lstat("README.md", &st);

Następnie stwierdza:

to nie jest katalog

Tworzy pojedynczy:

t_entry e;

i zapisuje:

name
fullpath
st
is_link
link_target

Jeżeli nie ma -l:

README.md

Jeżeli jest -l:

-rw-r--r-- ...

⸻

27. Przypadek: podano katalog

Przykład:

./ft_ls src

list_path() rozpoznaje:

src = directory

i wywołuje:

list_directory("src", opts, ...)

⸻

28. list_directory()

Ta funkcja wykonuje główną pracę dla katalogu.

Kolejność:

1. opcjonalny nagłówek
2. read_entries()
3. sort_entries()
4. total przy -l
5. print_short albo print_long
6. recurse_dirs przy -R
7. free(entries)

Dokładnie:

list_directory()
       |
       v
read_entries()
       |
       v
sort_entries()
       |
       +---- -l ----> compute_total()
       |
       v
   -l ?
   /   \
 TAK    NIE
 |       |
 v       v
long    short
 |
 +----------------+
                  |
                 -R?
                  |
             +----+----+
             |         |
            NIE       TAK
             |         |
             |         v
             |    recurse_dirs()
             |
             v
          free()

Źródło: list_directory().

⸻

29. opendir()

Żeby odczytać katalog, program używa:

opendir(path)

Przykład:

DIR *dir;
dir = opendir("src");

Jeżeli się uda:

DIR*

reprezentuje otwarty katalog.

Jeżeli się nie uda:

NULL

i program zgłasza błąd.

⸻

30. readdir()

Po:

opendir()

program wykonuje:

readdir(dir)

kolejne razy.

Każde wywołanie zwraca:

struct dirent *

czyli informacje o kolejnym wpisie.

Przykład katalogu:

src/
├── main.c
├── utils.c
├── parser.c
└── include/

readdir() może zwrócić:

.
..
main.c
utils.c
parser.c
include

Kolejność zwracania przez system nie jest tym samym co finalna kolejność wyświetlania.

Finalne sortowanie wykonuje później sort_entries().

⸻

31. read_entries()

Funkcja:

read_entries()

robi:

opendir()
    |
    v
readdir()
    |
    v
sprawdzenie hidden
    |
    v
fill_entry()
    |
    v
entries[]

Czyli:

DIR*
 |
 +-- readdir() --> entry 1
 |
 +-- readdir() --> entry 2
 |
 +-- readdir() --> entry 3
 |
 +-- ...
 |
 +-- NULL

Kod kończy odczyt:

closedir(dir);

Źródło: srcs/list_dir_utils.c.

⸻

32. Ukryte pliki — -a

Domyślnie:

./ft_ls

pomija wpisy zaczynające się od:

.

Czyli np.:

.git
.env
.config
.hidden

Kod:

if (opts->a || de->d_name[0] != '.')

oznacza:

-a ?
 |
 +---- TAK ---> dodaj wszystko
 |
 +---- NIE ---> jeśli pierwszy znak '.', pomiń

Źródło: read_entries().

⸻

33. Przykład -a

Załóżmy:

project/
├── .git/
├── .env
├── main.c
└── README.md

Bez:

./ft_ls project

wynik logicznie obejmuje:

README.md
main.c

Z:

./ft_ls -a project

do listy dochodzą:

.
..
.git
.env
README.md
main.c

⸻

34. Dynamiczna tablica t_entry

Program nie wie, ile elementów ma katalog.

Dlatego:

entries = NULL
count = 0
capacity = 0

Pierwsze dodanie:

capacity = 32

Potem:

32 -> 64 -> 128 -> 256 -> ...

przez:

realloc()

Funkcja:

entries_push()

zwiększa pojemność, jeśli:

count == capacity

Źródło: srcs/list_dir_utils.c.

⸻

35. build_fullpath()

Program musi wiedzieć nie tylko:

name = main.c

ale również:

fullpath = src/main.c

Funkcja:

build_fullpath()

buduje ścieżkę.

Jeżeli:

dir = "src"
name = "main.c"

wynik:

src/main.c

Jeżeli:

dir = "src/"
name = "main.c"

wynik:

src/main.c

Kod sprawdza, czy katalog już kończy się /.

⸻

36. Dlaczego fullpath jest potrzebne?

Wyobraźmy sobie:

project/
└── src/
    └── utils/
        └── test.c

Program może mieć:

name:
    test.c
fullpath:
    project/src/utils/test.c

name służy do wyświetlania.

fullpath służy do:

lstat()
recurse
readlink()
otwierania następnego katalogu

⸻

37. fill_entry()

Funkcja:

fill_entry()

wypełnia strukturę:

name
fullpath
st
is_link
link_target

Najważniejszy moment:

lstat(entry->fullpath, &entry->st);

Czyli dla każdego pliku/katalogu pobieramy jego metadane.

Jeżeli:

S_ISLNK(entry->st.st_mode)

to:

is_link = 1

i wykonywany jest:

read_link_target()

Źródło: fill_entry().

⸻

38. Symboliczne linki

Załóżmy:

real.txt
my_link -> real.txt

Program wykrywa:

S_ISLNK(...)

następnie:

readlink()

pobiera:

real.txt

i zapisuje do:

link_target

Przy -l może zostać wyświetlone:

my_link -> real.txt

⸻

39. sort_entries()

Po zebraniu wszystkich:

t_entry[]

program je sortuje.

Jeżeli:

-t = 0

używa:

cmp_alpha

czyli:

strcmp(ea->name, eb->name)

Jeżeli:

-t = 1

używa:

cmp_time

czyli porównuje:

st.st_mtime

Jeżeli:

-r = 1

na końcu:

reverse_entries()

odwraca tablicę.

Źródło: srcs/sort.c.

⸻

40. Sortowanie alfabetyczne

Bez -t:

apple
banana
hello
test

Comparator:

strcmp(ea->name, eb->name)

czyli porównywane są nazwy.

⸻

41. Sortowanie po czasie — -t

Przy:

./ft_ls -t

program używa:

st_mtime

czyli czasu ostatniej modyfikacji.

Comparator:

cmp_time()

porównuje:

ea->st.st_mtime
eb->st.st_mtime

Jeżeli czasy są równe:

strcmp(ea->name, eb->name)

jest tie-breakerem.

⸻

42. -r

Opcja:

-r

oznacza odwrócenie kolejności.

Przykład:

normal:
a
b
c
d

po:

-r

otrzymujemy:

d
c
b
a

Implementacja nie tworzy drugiego comparatora.

Najpierw sortuje normalnie:

qsort()

a później odwraca tablicę:

reverse_entries()

⸻

43. -t + -r

Przykład:

./ft_ls -tr

Logika:

1. sortuj po czasie
2. odwróć wynik

Czyli:

sort_time()
      |
      v
reverse()

⸻

44. -a + -t + -r

Przykład:

./ft_ls -atr

Logika:

-a
 |
 +--> nie pomijaj hidden
       |
-t ----+--> sortuj po czasie
       |
-r ----+--> odwróć kolejność

Ważne:

-a wpływa przede wszystkim na to, które wpisy zostaną wczytane.

-t wpływa na sortowanie.

-r wpływa na odwrócenie sortowania.

⸻

45. -l — long format

Bez:

-l

program używa:

print_entries_short()

czyli:

filename
filename
filename

Z:

-l

używa:

print_entries_long()

czyli wyświetla znacznie więcej informacji.

Źródło: list_directory().

⸻

46. Co pokazuje -l?

Schemat:

permissions
     |
     v
-rwxr-xr-x
     |
     v
number of links
     |
     v
owner
     |
     v
group
     |
     v
size
     |
     v
date/time
     |
     v
name

Przykład:

-rwxr-xr-x 2 user staff 1234 Aug  9 15:20 main.c

⸻

47. Uprawnienia

Pierwszy znak:

-

oznacza zwykły plik.

Może być:

d

dla katalogu.

l

dla linku.

c

dla character device.

b

dla block device.

p

dla FIFO.

s

dla socketu.

Kod get_file_type() w stat_utils.c obsługuje te typy.

⸻

48. Dziewięć bitów uprawnień

Po typie pliku:

rwxrwxrwx

dzielimy na:

rwx | rwx | rwx
 |     |     |
 |     |     +--- others
 |     +--------- group
 +--------------- owner

Czyli:

USER       GROUP      OTHERS
r w x      r w x      r w x

⸻

49. r, w, x

r = read
w = write
x = execute

Dla właściciela:

S_IRUSR
S_IWUSR
S_IXUSR

Dla grupy:

S_IRGRP
S_IWGRP
S_IXGRP

Dla innych:

S_IROTH
S_IWOTH
S_IXOTH

Projekt sprawdza te bity w permissions_utils.c.

⸻

50. Special permissions

Projekt obsługuje:

S_ISUID
S_ISGID
S_ISVTX

czyli odpowiednio:

setuid
setgid
sticky bit

Możliwe znaki:

s
S
t
T

Przykładowo:

rws

oznacza specjalny bit połączony z x.

Kod jest w:

stat_utils.c

w:

set_special_permissions()

Źródło:

⸻

51. Owner

Właściciel pliku jest zapisany w:

st.st_uid

Program używa:

getpwuid(uid)

aby dostać nazwę użytkownika.

Schemat:

st_uid
  |
  v
getpwuid()
  |
  +---- znaleziony ---> username
  |
  +---- brak ---------> numer UID

⸻

52. Group

Analogicznie:

st.st_gid

jest przekazywane do:

getgrgid()

Schemat:

st_gid
  |
  v
getgrgid()
  |
  +---- znaleziony ---> group name
  |
  +---- brak ---------> numer GID

Kod get_owner() i get_group() znajduje się w stat_utils.c.

⸻

53. Rozmiar

Rozmiar pliku pochodzi z:

st.st_size

i jest używany przy:

./ft_ls -l

Program najpierw sprawdza maksymalną szerokość rozmiaru, żeby kolumny były wyrównane.

⸻

54. Liczba linków

Informacja:

st.st_nlink

oznacza liczbę hard linków.

Jest również uwzględniana w:

t_widths.nlink

aby kolumna była poprawnie wyrównana.

⸻

55. Data

Program wykorzystuje:

st.st_mtime

czyli czas ostatniej modyfikacji.

Następnie:

localtime()

oraz:

strftime()

formatują datę.

Projekt ma regułę:

jeżeli modyfikacja jest młodsza niż 180 dni:
    miesiąc dzień godzina:minuta
w przeciwnym razie:
    miesiąc dzień rok

Kod format_time() realizuje ten mechanizm.

⸻

56. Wyrównanie kolumn -l

Program nie drukuje wszystkiego “na sztywno”.

Najpierw:

scan_widths()

przechodzi po wszystkich wpisach.

Dla każdego oblicza maksymalną długość:

nlink
owner
group
size

Przykład:

nlink:
1
10
100

maksimum:

3 znaki

Dzięki temu:

  1
 10
100

jest wyrównane.

⸻

57. printf() w long format

Najważniejsza funkcja:

print_one_long()

robi logicznie:

mode
links
owner
group
size
time
name

i jeżeli:

is_link == 1

dodaje:

-> target

Źródło: print_long.c.

⸻

58. total przy -l

Przy:

./ft_ls -l

przed listą pojawia się:

total ...

Projekt oblicza to przez sumowanie:

entries[i].st.st_blocks

a następnie:

total / 2

Kod list_directory() wywołuje:

compute_total(entries, count)

tylko gdy:

opts->l

jest ustawione.

⸻

59. -R — rekurencja

Opcja:

-R

oznacza:

recursive

Czyli program nie pokazuje tylko:

src/

ale również:

src/subdir/
src/subdir/another/
...

⸻

60. Przykład drzewa

Mamy:

project/
├── README.md
├── main.c
├── src/
│   ├── parser.c
│   └── utils/
│       ├── string.c
│       └── memory.c
└── include/
    └── ft_ls.h

Polecenie:

./ft_ls -R project

logicznie przechodzi:

project
 |
 +--> src
 |     |
 |     +--> utils
 |
 +--> include

Czyli:

list_path(project)
        |
        v
list_directory(project)
        |
        +--> src
        |      |
        |      v
        |  list_path(src)
        |      |
        |      +--> utils
        |             |
        |             v
        |         list_path(utils)
        |
        +--> include
               |
               v
           list_path(include)

⸻

61. Jak działa rekurencja w tym projekcie?

list_directory() po wypisaniu zawartości:

if (opts->big_r)
    ret = recurse_dirs(entries, count, opts);

Czyli:

-R?
 |
 +--- NIE ---> koniec katalogu
 |
 +--- TAK
       |
       v
recurse_dirs()

recurse_dirs() przechodzi po wszystkich t_entry.

Jeżeli wpis jest katalogiem, wywołuje:

list_path(entries[i].fullpath, opts, 1);

Źródło: list_dir.c.

⸻

62. Zabezpieczenie przed . i ..

Najważniejsza rzecz w rekurencji:

.
..

nie mogą być odwiedzane.

Inaczej:

project
  |
  +--> .
       |
       +--> .
            |
            +--> .
                 |
                 +--> ...

powstałaby nieskończona rekurencja.

Dlatego:

strcmp(entry->name, ".") == 0

oraz:

strcmp(entry->name, "..") == 0

są odrzucane.

⸻

63. Hidden directories przy -R

is_recursive_dir() sprawdza:

if (!opts->a && entry->name[0] == '.')
    return (0);

Czyli bez -a ukryty katalog nie jest odwiedzany.

Z -a ukryty katalog może zostać uwzględniony.

Ale:

.
..

nadal są wykluczone.

Źródło: is_recursive_dir().

⸻

64. Bardzo ważna różnica: -R a -a

To nie jest to samo.

-a

mówi:

pokaż hidden entries

Natomiast:

-R

mówi:

wchodź do podkatalogów

Dlatego:

./ft_ls -a

nie oznacza rekurencji.

A:

./ft_ls -R

nie oznacza automatycznie pokazywania hidden.

Dopiero:

./ft_ls -aR

łączy oba zachowania.

⸻

65. Bardzo ważna różnica: -l a -R

-l

zmienia:

FORMAT WYŚWIETLANIA

Natomiast:

-R

zmienia:

SPOSÓB PRZECHODZENIA PO KATALOGACH

Czyli:

./ft_ls -l

to:

normalne przejście
+
więcej informacji

a:

./ft_ls -R

to:

rekurencja
+
normalny output

a:

./ft_ls -lR

to:

rekurencja
+
long format

⸻

66. print_entries_short()

Najprostsza funkcja drukowania:

while (i < n)
{
    printf("%s\n", entries[i].name);
    i++;
}

Czyli:

entries[]
 |
 +--> name
 |
 +--> name
 |
 +--> name

Każdy wpis jest drukowany w osobnej linii.

Źródło: print_short.c.

⸻

67. print_entries_long()

Działa dwuetapowo:

1. scan_widths()
2. print_one_long() dla każdego wpisu

Dlaczego?

Bo program najpierw musi wiedzieć:

jak szerokie są kolumny

a dopiero później może poprawnie je wyrównać.

Źródło: print_long.c.

⸻

68. recursive.c

W przesłanym projekcie znajduje się również osobny moduł:

srcs/recursive.c

z funkcją:

recursive_traverse()

oraz:

print_dir_entries()
process_subdirs()

Mechanizm ten wykorzystuje:

opendir()
readdir()
rewinddir()

i buduje ścieżkę przez:

join_path()

process_subdirs() pomija:

.
..

oraz, zależnie od -a, hidden directories.

⸻

69. Uwaga dotycząca aktualnej architektury

W aktualnie pokazanym kodzie istnieją dwa mechanizmy związane z rekurencją:

srcs/list_dir.c
    |
    +--> recurse_dirs()
    |
    +--> list_path()

oraz:

srcs/recursive.c
    |
    +--> recursive_traverse()

Główna ścieżka wywołania list_directory() w pokazanym list_dir.c używa:

recurse_dirs()

czyli rekurencji opartej o t_entry[].

recursive.c zawiera osobny mechanizm recursive_traverse() oparty bezpośrednio o DIR */readdir().

Na obronie warto znać oba, ale przede wszystkim rozumieć ścieżkę faktycznie wywoływaną przez list_directory().

⸻

70. utils.c

W utils.c znajduje się między innymi:

join_path()

Funkcja tworzy:

dir/name

Przykład:

dir:
    project/src
name:
    utils
wynik:
    project/src/utils

Kod oblicza długość:

strlen(dir) + strlen(name) + 2

alokuje pamięć przez:

malloc()

i tworzy ścieżkę przez:

snprintf()

Źródło: utils.c.

⸻

71. Zarządzanie pamięcią

Projekt dynamicznie alokuje pamięć między innymi dla:

paths
entries
subpath

Przykłady:

malloc()
realloc()
free()

Bardzo ważna zasada:

malloc/realloc
      |
      v
   używanie
      |
      v
    free()

Przykład w list_directory():

entries = read_entries(...);
...
free(entries);

Źródło:

⸻

72. Błąd realloc()

Jeżeli:

realloc()

nie może przydzielić pamięci:

NULL

projekt zgłasza:

ft_ls: realloc: ...

i w przypadku entries_push() kończy program przez:

exit(1);

⸻

73. Błąd nieistniejącej ścieżki

Przykład:

./ft_ls does_not_exist

lstat() zwraca:

-1

i program wywołuje:

ft_error(path);

Błąd wykorzystuje:

strerror(errno)

Czyli system przekazuje konkretny powód błędu.

⸻

74. Exit codes

W projekcie używane są między innymi:

0
1
2

Ogólna idea:

0 = sukces
1 = błąd parsera / option / allocation
2 = problem ze ścieżką lub listingiem

W main.c błędy przetwarzania ścieżek ustawiają:

exit_code = 2;

i finalnie:

return (exit_code);

⸻

75. Przykład pełnego wywołania

Załóżmy:

/home/user/project/
├── README.md
├── main.c
├── .env
├── src/
│   ├── parser.c
│   └── utils/
│       └── memory.c
└── include/
    └── ft_ls.h

Uruchamiamy:

./ft_ls -laRt /home/user/project

Parser ustawia:

l = 1
a = 1
R = 1
t = 1
r = 0

Następnie:

path:
    /home/user/project

classify():

directory

list_path():

directory -> list_directory()

read_entries():

.
..
README.md
main.c
.env
src
include

Ponieważ:

a = 1

ukryte wpisy są dołączone.

Potem:

t = 1

więc:

sort_entries(..., cmp_time)

Potem:

l = 1

więc:

total ...
long format

Następnie:

R = 1

więc:

recurse_dirs()

i program wchodzi do:

src
include

oraz do kolejnych podkatalogów, zgodnie z warunkami rekurencji.

⸻

76. Bardzo dokładny przepływ dla ./ft_ls

Komenda:

./ft_ls

Krok 1

argv:

argv[0] = "./ft_ls"

Krok 2

parse_args():

opts:
    l = 0
    R = 0
    a = 0
    r = 0
    t = 0
npath = 0

Krok 3

main() zauważa:

npath == 0

więc tworzy:

paths[0] = "."

Krok 4

execute_ls().

Krok 5

classify():

"." = directory

Krok 6

list_path(".").

Krok 7

lstat(".").

Krok 8

S_ISDIR():

true

Krok 9

list_directory(".").

Krok 10

read_entries(".").

Krok 11

ukryte wpisy pomijane.

Krok 12

sort_entries() alfabetycznie.

Krok 13

brak -l:

print_entries_short()

Krok 14

brak -R:

koniec

⸻

77. Bardzo dokładny przepływ dla ./ft_ls -l

./ft_ls -l

Parser:

l = 1

Pozostałe:

R = 0
a = 0
r = 0
t = 0

Następnie:

path = "."

Program:

lstat(".")
    |
    v
directory
    |
    v
list_directory()
    |
    v
read_entries()
    |
    v
sort_entries()
    |
    v
compute_total()
    |
    v
print_entries_long()

⸻

78. Bardzo dokładny przepływ dla ./ft_ls -a

./ft_ls -a

Parser:

a = 1

Przy readdir():

if (opts->a || de->d_name[0] != '.')

ponieważ:

opts->a == 1

warunek jest prawdziwy dla wszystkich wpisów.

⸻

79. Bardzo dokładny przepływ dla ./ft_ls -t

./ft_ls -t

Parser:

t = 1

Po zebraniu wpisów:

sort_entries()

wybiera:

cmp_time

Comparator patrzy na:

st_mtime

⸻

80. Bardzo dokładny przepływ dla ./ft_ls -r

./ft_ls -r

Najpierw:

sort alphabetically

potem:

reverse

czyli:

a
b
c

staje się:

c
b
a

⸻

81. Bardzo dokładny przepływ dla ./ft_ls -R

./ft_ls -R

Najpierw normalny listing:

current directory

potem:

recurse_dirs()

Dla każdego odpowiedniego podkatalogu:

list_path(entries[i].fullpath, opts, 1);

Czyli:

current
 |
 +--> dir1
 |     |
 |     +--> subdir
 |
 +--> dir2

⸻

82. Kombinacja -lR

./ft_ls -lR

oznacza:

-l:
    long format
-R:
    recursion

Czyli:

directory
 |
 +--> long listing
 |
 +--> enter subdirectory
       |
       +--> long listing
       |
       +--> enter next subdirectory

⸻

83. Kombinacja -la

./ft_ls -la

oznacza:

-l:
    szczegółowe informacje
-a:
    hidden files

Czyli np.:

.
..
.git
.env
main.c

są kandydatami do wyświetlenia.

⸻

84. Kombinacja -lt

./ft_ls -lt

oznacza:

-l:
    long output
-t:
    sort by modification time

Czyli:

sort by mtime
      |
      v
long format

⸻

85. Kombinacja -ltr

./ft_ls -ltr

oznacza:

-l
-t
-r

czyli:

1. zbierz entries
2. sortuj po mtime
3. reverse
4. wyświetl long format

⸻

86. Kombinacja -laR

./ft_ls -laR

oznacza:

-l -> long
-a -> hidden
-R -> recursive

Czyli program:

pokazuje hidden
+
pokazuje szczegóły
+
wchodzi do podkatalogów

⸻

87. Kombinacja wszystkich flag

./ft_ls -lartR

Parser:

l = 1
a = 1
r = 1
t = 1
R = 1

Przepływ:

             ./ft_ls -lartR
                    |
                    v
               parse_args
                    |
                    v
             options = ALL
                    |
                    v
               classify
                    |
                    v
              list_path
                    |
                    v
             read_entries
                    |
              +-----+-----+
              |           |
            -a          hidden
              |
              v
          t_entry[]
              |
              v
           sort -t
              |
              v
          reverse -r
              |
              v
           -l ?
              |
             YES
              |
              v
          long format
              |
              v
           -R ?
              |
             YES
              |
              v
        recurse_dirs()
              |
              v
        następny katalog
              |
              +------> ten sam proces

⸻

88. DRZEWKO DECYZYJNE — CAŁY PROGRAM

START
 |
 v
parse_args()
 |
 +---- BŁĄD OPCJI? ------------------ YES --> exit(1)
 |
 NO
 |
 v
npath == 0?
 |
 +---- YES --> paths = ["."]
 |
 NO
 |
 v
execute_ls()
 |
 v
classify()
 |
 +---- lstat(path) ERROR? ----------- YES --> ft_error()
 |                                           exit_code = 2
 |
 NO
 |
 v
S_ISDIR?
 |
 +---- NO
 |      |
 |      v
 |   FILE
 |      |
 |      v
 |   list_path()
 |      |
 |      +---- -l? ---- YES --> print_entries_long()
 |      |
 |      NO
 |      |
 |      v
 |   printf(name)
 |
 YES
 |
 v
DIRECTORY
 |
 v
list_directory()
 |
 v
print_header?
 |
 +---- YES --> print "path:"
 |
 NO
 |
 v
read_entries()
 |
 v
opendir()
 |
 +---- ERROR --> return error
 |
 SUCCESS
 |
 v
readdir()
 |
 v
hidden?
 |
 +---- YES
 |      |
 |      +---- -a? ---- NO --> SKIP
 |      |
 |      YES
 |      |
 |      v
 |    INCLUDE
 |
 NO
 |
 v
fill_entry()
 |
 v
lstat(entry)
 |
 v
symbolic link?
 |
 +---- YES --> readlink()
 |
 NO
 |
 v
more entries?
 |
 +---- YES --> readdir()
 |
 NO
 |
 v
closedir()
 |
 v
sort_entries()
 |
 +---- -t? ---- YES --> sort by mtime
 |
 NO
 |
 +----> sort alphabetically
 |
 v
-r?
 |
 +---- YES --> reverse_entries()
 |
 NO
 |
 v
-l?
 |
 +---- YES --> compute_total()
 |             |
 |             v
 |         print_entries_long()
 |
 NO
 |
 v
print_entries_short()
 |
 v
-R?
 |
 +---- NO --> free(entries) --> END
 |
 YES
 |
 v
recurse_dirs()
 |
 v
entry is directory?
 |
 +---- NO --> next entry
 |
 YES
 |
 v
hidden directory?
 |
 +---- -a? NO --> skip
 |
 YES
 |
 v
name == "."?
 |
 +---- YES --> skip
 |
 NO
 |
 v
name == ".."?
 |
 +---- YES --> skip
 |
 NO
 |
 v
list_path(subdirectory)
 |
 v
REPEAT

⸻

89. DRZEWKO DECYZYJNE — OPCJE

                 argv[i]
                    |
                    v
             zaczyna się '-'?
                /          \
              NIE           TAK
               |             |
               v             v
             PATH          "--"?
                             / \
                           TAK  NIE
                           |      |
                           v      v
                     koniec     parse_cluster()
                     opcji          |
                                    v
                              każdy znak
                                    |
                     +--------------+--------------+
                     |       |      |      |       |
                     v       v      v      v       v
                     l       R      a      r       t
                     |       |      |      |       |
                     v       v      v      v       v
                    -l      -R     -a     -r      -t

⸻

90. DRZEWKO DECYZYJNE — -l

-l?
 |
 +---- NO ----> print_entries_short()
 |
 YES
 |
 v
compute_total()
 |
 v
scan_widths()
 |
 v
dla każdego entry:
 |
 +--> mode_to_str()
 |
 +--> get_owner()
 |
 +--> get_group()
 |
 +--> st_size
 |
 +--> format_time()
 |
 +--> name
 |
 +--> jeśli link --> " -> target"
 |
 v
print

⸻

91. DRZEWKO DECYZYJNE — -a

entry->name[0] == '.'?
 |
 +---- NO ----> INCLUDE
 |
 YES
 |
 v
-a?
 |
 +---- YES ----> INCLUDE
 |
 NO
 |
 v
SKIP

⸻

92. DRZEWKO DECYZYJNE — -R

-R?
 |
 +---- NO ----> END DIRECTORY
 |
 YES
 |
 v
recurse_dirs()
 |
 v
entry is directory?
 |
 +---- NO ----> next
 |
 YES
 |
 v
hidden?
 |
 +---- YES --> -a?
 |               |
 |               +-- NO --> skip
 |               |
 |               +-- YES
 |
 v
name == "."?
 |
 +---- YES --> skip
 |
 NO
 |
 v
name == ".."?
 |
 +---- YES --> skip
 |
 NO
 |
 v
list_path(fullpath)
 |
 v
RECURSE

⸻

93. DRZEWKO DECYZYJNE — -t + -r

entries
 |
 v
-t?
 |
 +---- NO --> cmp_alpha
 |
 YES
 |
 v
cmp_time
 |
 v
qsort()
 |
 v
-r?
 |
 +---- NO --> output
 |
 YES
 |
 v
reverse_entries()
 |
 v
output

⸻

94. DRZEWKO DECYZYJNE — typ ścieżki

                  path
                   |
                   v
                 lstat
                   |
            +------+------+
            |             |
          ERROR          OK
            |             |
            v             v
        ft_error      S_ISDIR?
                         |
                  +------+------+
                  |             |
                 YES            NO
                  |             |
                  v             v
          list_directory     single entry
                  |             |
                  |             +--> is link?
                  |                       |
                  |                       +--> readlink()
                  |
                  v
             read_entries()

⸻

95. Najważniejsze funkcje systemowe

lstat()

Służy do pobrania metadanych pliku.

Używane do:

typ
uprawnienia
owner
group
size
mtime
links
symlink

⸻

opendir()

Otwiera katalog:

DIR *dir = opendir(path);

⸻

readdir()

Czyta kolejny wpis:

struct dirent *entry = readdir(dir);

⸻

closedir()

Zamyka katalog:

closedir(dir);

⸻

readlink()

Pobiera cel symbolic linku.

⸻

getpwuid()

Konwertuje UID na nazwę użytkownika.

⸻

getgrgid()

Konwertuje GID na nazwę grupy.

⸻

qsort()

Sortuje tablicę.

⸻

malloc()

Alokuje pamięć.

⸻

realloc()

Zmienia rozmiar wcześniej zaalokowanej pamięci.

⸻

free()

Zwalnia pamięć.

⸻

96. Co to jest struct stat?

To struktura systemowa zawierająca informacje o obiekcie systemu plików.

W projekcie najważniejsze są:

st_mode
st_nlink
st_uid
st_gid
st_size
st_mtime
st_blocks

Można myśleć:

struct stat
│
├── st_mode    -> typ + permissions
├── st_nlink   -> liczba hard linków
├── st_uid     -> owner
├── st_gid     -> group
├── st_size    -> size
├── st_mtime   -> modification time
└── st_blocks  -> blocks

⸻

97. Jak st_mode jest używane?

st_mode zawiera informacje o:

typie pliku
+
uprawnieniach
+
special permissions

Dlatego można zrobić:

S_ISDIR(st.st_mode)

lub:

S_ISLNK(st.st_mode)

lub sprawdzać:

S_IRUSR
S_IWUSR
S_IXUSR

⸻

98. Dlaczego projekt ma osobny stat_utils.c?

Ponieważ struct stat jest wykorzystywane w wielu miejscach.

Zamiast wszędzie pisać:

if (...)
    ...

projekt centralizuje między innymi:

mode_to_str()
get_owner()
get_group()

Dzięki temu:

stat data
    |
    +--> stat_utils
           |
           +--> permissions
           +--> owner
           +--> group
           +--> type

⸻

99. Dlaczego projekt ma permissions_utils.c?

Ponieważ:

rwx

ma dziewięć pozycji:

user
group
others

Kod został rozdzielony na:

set_user_permissions()
set_group_permissions()
set_other_permissions()

Każda funkcja odpowiada za jedną grupę trzech bitów.

⸻

100. Dlaczego projekt ma print_long.c?

Żeby list_dir.c nie musiał znać szczegółów formatowania:

permissions
owner
group
size
date

Architektura jest więc mniej więcej:

list_dir
   |
   +--> "chcę long format"
             |
             v
       print_long.c
             |
       +-----+-----+
       |     |     |
      mode owner group

⸻

101. Dlaczego projekt ma sort.c?

Tak samo sortowanie zostało oddzielone.

list_dir.c mówi tylko:

sort_entries(entries, count, opts);

Nie musi wiedzieć:

jak porównywać nazwy
jak porównywać czas
jak odwrócić tablicę

To jest odpowiedzialność sort.c.

⸻

102. Zasada odpowiedzialności modułów

Można zapamiętać:

parse_args.c
    -> CO UŻYTKOWNIK CHCE?
main.c
    -> JAKI JEST GŁÓWNY PRZEPŁYW?
list_dir.c
    -> JAK ODCZYTAĆ I WYŚWIETLIĆ KATALOG?
list_dir_utils.c
    -> JAK ZBUDOWAĆ t_entry?
sort.c
    -> W JAKIEJ KOLEJNOŚCI?
print_short.c
    -> JAK WYŚWIETLIĆ PROSTO?
print_long.c
    -> JAK WYŚWIETLIĆ SZCZEGÓŁOWO?
stat_utils.c
    -> JAK INTERPRETOWAĆ struct stat?
permissions_utils.c
    -> JAK ZROBIĆ rwxrwxrwx?
recursive.c
    -> JAK PRZECHODZIĆ REKURENCYJNIE?
utils.c
    -> MAŁE FUNKCJE POMOCNICZE
error.c
    -> JAK RAPORTOWAĆ BŁĘDY?

⸻

103. Kompletny przykład nr 1

Struktura:

project/
├── a.txt
├── b.txt
├── .hidden
├── src/
│   ├── main.c
│   └── utils.c
└── .git/

Polecenie:

./ft_ls project

Działanie:

project
 |
 v
lstat()
 |
 v
DIRECTORY
 |
 v
opendir()
 |
 v
readdir()
 |
 +--> .hidden --> SKIP
 |
 +--> .git    --> SKIP
 |
 +--> a.txt   --> INCLUDE
 |
 +--> b.txt   --> INCLUDE
 |
 +--> src     --> INCLUDE
 |
 v
sort alphabetically
 |
 v
short output

⸻

104. Kompletny przykład nr 2

./ft_ls -a project

Teraz:

-a = 1

więc:

.hidden
.git

również są wczytane.

⸻

105. Kompletny przykład nr 3

./ft_ls -l project

Teraz:

entries
 |
 v
sort
 |
 v
compute_total
 |
 v
scan_widths
 |
 v
long output

⸻

106. Kompletny przykład nr 4

./ft_ls -R project

Program:

project
 |
 +--> src
      |
      +--> main.c
      |
      +--> utils.c

i wchodzi do src.

⸻

107. Kompletny przykład nr 5

./ft_ls -laR project

To jest:

-l
-a
-R

czyli:

long format
+
hidden
+
recursive

⸻

108. Kompletny przykład nr 6

./ft_ls -ltr project

To jest:

-l -> long
-t -> time
-r -> reverse

Przepływ:

read entries
    |
    v
sort by mtime
    |
    v
reverse
    |
    v
long format

⸻

109. Kompletny przykład nr 7 — wiele ścieżek

./ft_ls file1.txt src include

Po classify():

files:
    file1.txt
dirs:
    src
    include

Następnie:

file1.txt
include:
...
src:
...

Katalogi są sortowane osobno.

⸻

110. Kompletny przykład nr 8 — nieistniejąca ścieżka

./ft_ls file.txt does_not_exist src

classify():

file.txt
    |
    +--> file
does_not_exist
    |
    +--> lstat ERROR
src
    |
    +--> directory

Program zgłasza błąd dla nieistniejącej ścieżki, ale nadal ma osobne przetwarzanie pozostałych poprawnych ścieżek.

exit_code zostaje ustawiony na 2.

⸻

111. Kompletny przykład nr 9 — pojedynczy plik z -l

./ft_ls -l main.c

Nie ma potrzeby:

opendir()
readdir()

bo main.c nie jest katalogiem.

Przepływ:

main.c
 |
 v
lstat()
 |
 v
not directory
 |
 v
t_entry e
 |
 v
is_link?
 |
 v
-l?
 |
 +--> YES
       |
       v
print_entries_long(&e, 1)

⸻

112. Kompletny przykład nr 10 — symbolic link

Załóżmy:

file.txt
link -> file.txt

Polecenie:

./ft_ls -l link

Program:

lstat(link)
 |
 v
S_ISLNK = true
 |
 v
readlink(link)
 |
 v
link_target = "file.txt"
 |
 v
print
 |
 v
link -> file.txt

⸻

113. Co powiedzieć na obronie o t_entry?

Dobra odpowiedź:

t_entry reprezentuje jeden element systemu plików znaleziony podczas listowania katalogu. Przechowuje jego nazwę, pełną ścieżkę, strukturę stat z metadanymi, informację czy jest symbolicznym linkiem oraz cel tego linku.

⸻

114. Co powiedzieć na obronie o struct stat?

Dobra odpowiedź:

struct stat jest strukturą systemową zawierającą metadane obiektu systemu plików. W projekcie wykorzystujemy między innymi st_mode do określenia typu i uprawnień, st_nlink do liczby linków, st_uid i st_gid do właściciela i grupy, st_size do rozmiaru, st_mtime do sortowania po czasie i formatowania daty oraz st_blocks do obliczenia total.

⸻

115. Co powiedzieć o lstat()?

lstat() pobiera metadane wskazanej ścieżki. W projekcie jest szczególnie istotne dla symbolic linków, ponieważ pozwala rozpoznać sam link poprzez S_ISLNK, zamiast automatycznie traktować go jak jego cel.

⸻

116. Co powiedzieć o opendir()?

opendir() otwiera katalog i zwraca wskaźnik DIR *, który później jest wykorzystywany przez readdir() do pobierania kolejnych wpisów.

⸻

117. Co powiedzieć o readdir()?

readdir() pobiera kolejne wpisy z otwartego katalogu. Każdy wpis jest reprezentowany przez struct dirent. Projekt filtruje hidden entries, tworzy dla zaakceptowanych elementów t_entry, a następnie po zakończeniu odczytu zamyka katalog przez closedir().

⸻

118. Co powiedzieć o qsort()?

qsort() jest używane do sortowania tablic. Projekt wybiera comparator alfabetyczny albo czasowy zależnie od -t, a jeżeli ustawione jest -r, po sortowaniu odwraca tablicę.

⸻

119. Co powiedzieć o -a?

-a powoduje, że podczas odczytywania katalogu nie są pomijane wpisy, których nazwa zaczyna się od kropki.

⸻

120. Co powiedzieć o -l?

-l zmienia sposób prezentowania wpisów. Zamiast samej nazwy program wyświetla typ i uprawnienia, liczbę linków, właściciela, grupę, rozmiar, czas modyfikacji oraz nazwę. Dla symbolic linku dodatkowo wyświetlany jest jego cel.

⸻

121. Co powiedzieć o -R?

-R uruchamia rekurencyjne przechodzenie po podkatalogach. Projekt nie schodzi do . ani .., żeby uniknąć nieskończonej rekurencji. Ukryte katalogi są uwzględniane zależnie od flagi -a.

⸻

122. Co powiedzieć o -t?

-t powoduje sortowanie według czasu modyfikacji st_mtime, a przy takim samym czasie projekt używa nazwy jako tie-breakera.

⸻

123. Co powiedzieć o -r?

-r nie zmienia comparatora. Program najpierw wykonuje normalne sortowanie, a następnie odwraca kolejność elementów w tablicy.

⸻

124. Najważniejsze zależności między opcjami

-a
 |
 +--> wpływa na read_entries()
 |
 +--> wpływa na recurse_dirs()
-l
 |
 +--> wpływa na print
 |
 +--> compute_total()
 |
 +--> long metadata
-t
 |
 +--> comparator
-r
 |
 +--> reverse
-R
 |
 +--> recurse_dirs()
 |
 +--> print headers

⸻

125. Tabela wszystkich opcji

Opcja	Co robi	Gdzie wpływa
-l	long format	list_directory, print_long
-R	recursion	recurse_dirs
-a	hidden files	read_entries, recursion
-r	reverse	sort_entries
-t	sort by mtime	sort_entries

⸻

126. Tabela funkcji

Funkcja	Odpowiedzialność
main()	start programu
parse_args()	parser
apply_flag()	ustawienie flagi
parse_cluster()	obsługa -laRt
paths_push()	dynamiczna tablica ścieżek
classify()	files vs dirs
execute_ls()	sortowanie + uruchomienie listingu
print_all()	wypisanie files i dirs
list_path()	decyzja file/dir
list_directory()	pełny listing katalogu
read_entries()	odczyt katalogu
fill_entry()	utworzenie t_entry
build_fullpath()	budowanie ścieżki
sort_entries()	sortowanie wpisów
print_entries_short()	prosty output
print_entries_long()	long output
mode_to_str()	permissions string
get_owner()	UID -> username
get_group()	GID -> group
read_link_target()	cel symlink
recurse_dirs()	rekurencja
join_path()	łączenie ścieżek
ft_error()	obsługa błędów

⸻

127. Najważniejszy diagram architektury

                           +----------------+
                           |    main.c      |
                           +-------+--------+
                                   |
                                   v
                           +---------------+
                           | parse_args.c  |
                           +-------+-------+
                                   |
                       +-----------+-----------+
                       |                       |
                       v                       v
                  t_options                 paths
                       |                       |
                       +-----------+-----------+
                                   |
                                   v
                           +---------------+
                           |   main.c      |
                           | classify()    |
                           +-------+-------+
                                   |
                       +-----------+-----------+
                       |                       |
                       v                       v
                     files                    dirs
                       |                       |
                       |                       v
                       |                +-------------+
                       |                | list_dir.c  |
                       |                +------+------+
                       |                       |
                       |                       v
                       |                list_entries
                       |                       |
                       |                       v
                       |                +-------------+
                       |                |    sort.c   |
                       |                +------+------+
                       |                       |
                       |             +---------+---------+
                       |             |                   |
                       |             v                   v
                       |          short               long
                       |             |                   |
                       |             |                   v
                       |             |            print_long.c
                       |             |
                       |             v
                       |       print_short.c
                       |
                       v
                  list_path()
                       |
                       v
                  single entry

⸻

128. Najważniejszy diagram wykonania

USER
 |
 | ./ft_ls -laRt src include file.txt
 |
 v
argv
 |
 v
parse_args()
 |
 +--------------------------+
 |                          |
 v                          v
t_options                  paths
 |                          |
 |                          v
 |                       classify()
 |                          |
 |               +----------+----------+
 |               |                     |
 |               v                     v
 |             files                 dirs
 |               |                     |
 |               |                     v
 |               |                sort paths
 |               |                     |
 |               |                     v
 |               |                list_path()
 |               |                     |
 |               |                     v
 |               |                lstat()
 |               |                     |
 |               |                 directory
 |               |                     |
 |               |                     v
 |               |                opendir()
 |               |                     |
 |               |                     v
 |               |                readdir()
 |               |                     |
 |               |                     v
 |               |                 t_entry[]
 |               |                     |
 |               |                     v
 |               |                sort_entries()
 |               |                     |
 |               |                 -t -> time
 |               |                     |
 |               |                 -r -> reverse
 |               |                     |
 |               |                     v
 |               |                 -l -> long
 |               |                     |
 |               |                     v
 |               |                  output
 |               |                     |
 |               |                 -R -> recurse
 |               |                     |
 |               |                     v
 |               |                list_path()
 |               |                     |
 |               |                    ...
 |               |
 |               v
 |           print file
 |
 v
END

⸻

129. Co dzieje się w pamięci?

Dla:

./ft_ls src

można myśleć o pamięci:

STACK
│
├── opts
├── npath
├── exit_code
└── local variables
│
HEAP
│
├── paths
│
└── entries
      │
      ├── t_entry[0]
      ├── t_entry[1]
      ├── t_entry[2]
      └── ...

DIR * jest uchwytem zwróconym przez system przy:

opendir()

Po zakończeniu:

closedir()

a dynamiczne:

paths
entries
subpath

muszą zostać zwolnione.

⸻

130. Dlaczego t_entry[], a nie tylko struct dirent[]?

struct dirent daje informacje o wpisie katalogu, ale projekt potrzebuje znacznie więcej informacji.

Dlatego tworzy własne:

t_entry

które zawiera:

name
fullpath
stat
link information

To umożliwia później:

sorting
long format
recursion
symlink display

⸻

131. Dlaczego sortowanie jest dopiero po readdir()?

readdir() dostarcza wpisy kolejno z katalogu.

Program chce mieć własną kolejność:

alphabetical

lub:

mtime

więc musi:

1. zebrać wszystkie
2. przechować je w tablicy
3. posortować
4. wyświetlić

Dlatego:

readdir()
   |
   v
entries[]
   |
   v
qsort()
   |
   v
print

⸻

132. Dlaczego najpierw sortowanie, a potem print?

Bo jeżeli program od razu drukowałby:

readdir()

to nie miałby możliwości łatwego sortowania całego zestawu.

Obecna architektura:

READ
 |
 v
STORE
 |
 v
SORT
 |
 v
PRINT

jest prostsza do kontrolowania.

⸻

133. Dlaczego -r robi się po qsort()?

Można byłoby napisać drugi comparator.

Projekt zamiast tego robi:

qsort()
+
reverse

czyli:

[a,b,c,d]
    |
    v
[d,c,b,a]

przez zamianę:

0 <-> n-1
1 <-> n-2
...

Kod reverse_entries() wykorzystuje dwa indeksy:

lo
hi

i przesuwa je do środka.

⸻

134. Co jeśli katalog jest pusty?

Przykład:

empty/

read_entries() zwróci:

count = 0

sort_entries() od razu kończy:

if (n <= 1)
    return;

Przy -l projekt może wypisać:

total 0

a funkcja long output niczego więcej nie wypisze.

⸻

135. Co jeśli -l dostanie pojedynczy plik?

./ft_ls -l file.txt

Nie jest wykonywane:

opendir(file.txt)

bo:

file.txt != directory

Powstaje jeden:

t_entry

i:

print_entries_long(&e, 1);

⸻

136. Co jeśli podamy wiele plików?

./ft_ls b.txt a.txt c.txt

classify():

files:
    b.txt
    a.txt
    c.txt

Potem:

qsort()

wynik:

a.txt
b.txt
c.txt

⸻

137. Co jeśli podamy wiele katalogów?

./ft_ls zdir adir mdir

classify():

dirs:
    zdir
    adir
    mdir

Potem sortowanie:

adir
mdir
zdir

i każdy katalog jest przetwarzany osobno.

⸻

138. Co jeśli podamy plik i katalog?

./ft_ls file.txt src

Najpierw:

file.txt

potem:

src:
...

To wynika z rozdzielenia:

files
dirs

w classify() i późniejszego print_all().

⸻

139. Co jeśli podamy - jako ścieżkę?

Sam znak:

-

nie spełnia warunku:

argv[i][1] != '\0'

czyli może zostać potraktowany jako argument/ścieżka, a nie klaster opcji.

To jest przykład różnicy między:

-

a:

-l

⸻

140. Co jeśli podamy nieznaną flagę?

Przykład:

./ft_ls -x

apply_flag('x', ...) zwraca:

-1

następnie:

illegal_option('x')

i program wypisuje:

ft_ls: illegal option -- x
usage: ft_ls [-Ralrt] [file ...]

oraz kończy parser z błędem.

⸻

141. Co jeśli podamy --?

./ft_ls -- -file

Po:

--

parser przestaje interpretować kolejne argumenty jako opcje.

Czyli:

-- 
 |
 v
stop option parsing
 |
 v
-file = path

⸻

142. Minimalna wiedza potrzebna do obrony

Jeżeli masz bardzo mało czasu, zapamiętaj:

main
 |
 v
parse_args
 |
 v
classify
 |
 +--> files
 |
 +--> dirs
        |
        v
    list_path
        |
        v
      lstat
        |
        +--> file
        |
        +--> directory
                  |
                  v
             opendir
                  |
                  v
             readdir
                  |
                  v
              t_entry[]
                  |
                  v
             sort_entries
                  |
          +-------+-------+
          |               |
        short            long
          |               |
          +-------+-------+
                  |
                 -R
                  |
                  v
             recursion

⸻

143. 10 rzeczy, które prawie na pewno warto znać

1.

lstat()

Pobiera metadane.

2.

opendir()

Otwiera katalog.

3.

readdir()

Czyta wpisy.

4.

closedir()

Zamyka katalog.

5.

struct stat

Przechowuje metadane.

6.

struct dirent

Reprezentuje wpis katalogu zwrócony przez readdir().

7.

t_entry

Własna struktura projektu opisująca jeden wpis.

8.

qsort()

Sortowanie.

9.

readlink()

Cel symlink.

10.

getpwuid()
getgrgid()

Owner/group.

⸻

144. 10 pytań, które może zadać prowadzący

Pytanie 1

Dlaczego lstat, a nie tylko stat?

Odpowiedź:

Ponieważ chcemy rozpoznać sam symbolic link i pobrać informacje o linku, a następnie osobno odczytać jego cel przez readlink().

⸻

Pytanie 2

Po co t_entry?

Żeby przechować wszystkie informacje potrzebne później do sortowania, wyświetlania i rekurencji.

⸻

Pytanie 3

Jak działa -a?

W read_entries() wpisy zaczynające się od . są normalnie pomijane, chyba że opts->a jest ustawione.

⸻

Pytanie 4

Jak działa -t?

sort_entries() wybiera comparator cmp_time, który porównuje st_mtime.

⸻

Pytanie 5

Jak działa -r?

Po sortowaniu tablica jest odwracana przez reverse_entries().

⸻

Pytanie 6

Jak działa -R?

Po wyświetleniu katalogu recurse_dirs() znajduje podkatalogi i wywołuje dla nich ponownie list_path().

⸻

Pytanie 7

Dlaczego pomijamy . i ..?

Żeby nie tworzyć nieskończonej rekurencji.

⸻

Pytanie 8

Skąd bierze się owner?

Z st_uid, który jest przekazywany do getpwuid().

⸻

Pytanie 9

Skąd bierze się group?

Z st_gid, który jest przekazywany do getgrgid().

⸻

Pytanie 10

Dlaczego potrzebujemy scan_widths()?

Żeby określić maksymalne szerokości kolumn w long format i wyrównać output.

⸻

145. Jedno zdanie opisujące każdy plik

main.c
    steruje całym programem
main_utils.c
    sortuje ścieżki wejściowe i obsługuje reverse
parse_args.c
    parsuje opcje i ścieżki
list_dir.c
    wykonuje listing katalogu i uruchamia rekurencję
list_dir_utils.c
    tworzy t_entry i czyta katalog
recursive.c
    zawiera mechanizm rekurencyjnego traversal
sort.c
    sortuje t_entry
print_short.c
    drukuje same nazwy
print_long.c
    drukuje szczegółowe informacje
permissions_utils.c
    tworzy rwxrwxrwx
stat_utils.c
    interpretuje struct stat
utils.c
    funkcje pomocnicze, np. join_path
error.c
    obsługa błędów

⸻

146. Finalny model mentalny

Najłatwiej zapamiętać projekt jako pipeline:

             USER COMMAND
                   |
                   v
              ARGUMENTS
                   |
                   v
              PARSING
                   |
                   v
          OPTIONS + PATHS
                   |
                   v
             CLASSIFY
                   |
          +--------+--------+
          |                 |
        FILES             DIRS
          |                 |
          |                 v
          |             OPENDIR
          |                 |
          |                 v
          |             READDIR
          |                 |
          |                 v
          |             LSTAT
          |                 |
          |                 v
          |             T_ENTRY
          |                 |
          |                 v
          |              SORT
          |                 |
          |        +--------+--------+
          |        |                 |
          |      SHORT              LONG
          |        |                 |
          |        +--------+--------+
          |                 |
          |                -R
          |                 |
          |                 v
          |             RECURSION
          |                 |
          +-----------------+
                   |
                   v
                 OUTPUT
                   |
                   v
                  END

⸻

147. Najkrótsze streszczenie całego projektu

ft_ls pobiera argumenty z argv, parsuje opcje -l, -R, -a, -r i -t, a następnie rozdziela podane ścieżki na pliki i katalogi. Dla katalogów używa opendir() i readdir() do zebrania wpisów, a dla każdego wpisu wykorzystuje lstat() do pobrania metadanych. Dane są przechowywane w t_entry, następnie sortowane alfabetycznie albo według st_mtime, opcjonalnie odwracane przez -r i wyświetlane w formacie zwykłym lub long przez -l. Opcja -a wpływa na uwzględnianie ukrytych wpisów, natomiast -R uruchamia rekurencyjne przechodzenie po podkatalogach. Symboliczne linki są rozpoznawane przez S_ISLNK() i ich cel jest pobierany przez readlink().

⸻

148. Jedno zdanie na obronę

To jest implementacja ls, w której najpierw parsujemy opcje i ścieżki, następnie rozdzielamy pliki od katalogów, katalogi odczytujemy przez opendir/readdir, metadane pobieramy przez lstat i zapisujemy w t_entry, potem sortujemy dane zależnie od -t i -r, drukujemy je w zwykłym albo long formacie zależnie od -l, a przy -R rekurencyjnie wykonujemy ten sam proces dla podkatalogów.

⸻

149. Najważniejsze źródła w projekcie

Centralny nagłówek:

includes/ft_ls.h

Główne sterowanie:

srcs/main.c

Parser:

srcs/parse_args.c

Listing:

srcs/list_dir.c
srcs/list_dir_utils.c

Sortowanie:

srcs/sort.c
srcs/main_utils.c

Output:

srcs/print_short.c
srcs/print_long.c

Uprawnienia:

srcs/permissions_utils.c
srcs/stat_utils.c

Rekurencja:

srcs/list_dir.c
srcs/recursive.c

Pomocnicze:

srcs/utils.c
srcs/error.c

Biblioteka własna:

mylibft/

⸻

150. Ostateczne drzewko do zapamiętania przed obroną

                         FT_LS
                           |
                           v
                    +-------------+
                    | parse_args  |
                    +------+------+
                           |
                  +--------+--------+
                  |                 |
               OPTIONS             PATHS
                  |                 |
                  |                 v
                  |             classify
                  |                 |
                  |       +---------+---------+
                  |       |                   |
                  |      FILES              DIRS
                  |       |                   |
                  |       |                   v
                  |       |              list_path
                  |       |                   |
                  |       |                 lstat
                  |       |                   |
                  |       |            +------+------+
                  |       |            |             |
                  |       |           FILE          DIR
                  |       |            |             |
                  |       |            |             v
                  |       |            |       list_directory
                  |       |            |             |
                  |       |            |             v
                  |       |            |        read_entries
                  |       |            |             |
                  |       |            |             v
                  |       |            |          t_entry[]
                  |       |            |             |
                  |       |            |             v
                  |       |            |        sort_entries
                  |       |            |             |
                  |       |            |      +------+------+
                  |       |            |      |             |
                  |       |            |     -t            normal
                  |       |            |      |             |
                  |       |            |      v             v
                  |       |            |    time          alpha
                  |       |            |      \             /
                  |       |            |       +-----------+
                  |       |            |             |
                  |       |            |            -r
                  |       |            |             |
                  |       |            |             v
                  |       |            |          reverse
                  |       |            |             |
                  |       |            |            -l
                  |       |            |             |
                  |       |            |       +-----+-----+
                  |       |            |       |           |
                  |       |            |      YES         NO
                  |       |            |       |           |
                  |       |            |       v           v
                  |       |            |      LONG       SHORT
                  |       |            |       |           |
                  |       |            |       +-----+-----+
                  |       |            |             |
                  |       |            |            -R
                  |       |            |             |
                  |       |            |       +-----+-----+
                  |       |            |       |           |
                  |       |            |      YES         NO
                  |       |            |       |           |
                  |       |            |       v           v
                  |       |            |   recurse       END
                  |       |            |       |
                  |       |            |       v
                  |       |            |  subdirectory
                  |       |            |       |
                  |       |            |       +----> list_path()
                  |       |            |
                  |       v            |
                  |   print file      |
                  |       |            |
                  +-------+------------+
                          |
                          v
                         END

Najważniejsza rzecz

Jeżeli masz zrozumieć jedną rzecz, nie ucz się tego projektu jako listy funkcji. Zapamiętaj przepływ:

argv
 ↓
parse_args
 ↓
paths + options
 ↓
classify
 ↓
file / directory
 ↓
lstat / opendir / readdir
 ↓
t_entry[]
 ↓
sort
 ↓
print
 ↓
-R → recursion

A potem dopiero przypinaj do tego opcje:

-a → co wczytujemy
-t → jak sortujemy
-r → jak odwracamy
-l → jak drukujemy
-R → gdzie idziemy dalej

To jest najprostszy sposób, żeby podczas obrony nie zgubić się w szczegółach.