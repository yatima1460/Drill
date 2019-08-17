# CC = gcc
# LD = gcc
# OBJS = context.o config.o file_info.o matching_functions.o meta.o
FLAGS	 = -Wall -Wextra -pedantic -std=c11 #-Werror
# LFLAGS	 = -lpthread

.PHONY build
build: file_info.h matching_functions.h meta.h context.o config.o 
	echo "Compiling Drill Core"
	gcc -shared -fPIC -o drill_core.a file_info.h matching_functions.h meta.h context.h context.c config.c config.h $(FLAGS)

.PHONY: clean
clean:
	rm -f *.gch *.o drill_core.a
	echo Clean done

context.o : 
	gcc -c -fPIC context.h context.c $(FLAGS)

config.o : 
	gcc -c -fPIC config.c config.h $(FLAGS)

