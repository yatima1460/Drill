# CC = gcc
# LD = gcc
# OBJS = context.o config.o file_info.o matching_functions.o meta.o
FLAGS	 =  -std=c11 -Wall -Wextra -pedantic -Wfatal-errors#-Werror
# LFLAGS	 = -lpthread

.PHONY: build
build: file_info.h matching_functions.h meta.h context.o config.o crawler.o 
	echo "Compiling Drill Core"
	gcc -g -shared -fPIC crawler.c context.c config.c $(FLAGS)
	gcc-ar cr libdrillcore.a crawler.o context.o config.o 

.PHONY: clean
clean:
	rm -f *.gch *.o drill_core.a
	echo Clean done

# context.o : 
# 	gcc -c -fPIC context.c $(FLAGS)

# config.o :  config.o 
# 	gcc -c -fPIC config.c  $(FLAGS)

# crawler.o : 
# 	gcc -c -fPIC crawler.c $(FLAGS)