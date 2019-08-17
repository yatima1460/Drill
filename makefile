#
# In order to execute this "Makefile" just type "make"
#	A. Delis (ad@di.uoa.gr)
#

# OBJS	= context.o config.o file_info.o matching_functions.o meta.o
# OUT	= cli,gtk

# OBJS0	= context.o config.o file_info.o matching_functions.o meta.o
# SOURCE0	= context.c config.c file_info.o matching_functions.o meta.o
# HEADER0	= cheese.h
# OUT0	= cli

# OBJS1	= cheese.o bread.o baycon.o mushrooms.o ketchup.o
# SOURCE1	= cheese.c bread.c baycon.c mushrooms.c ketchup.c
# HEADER1	= cheese.h ketchup.h
# OUT1	= gtk

# CC	 = gcc

# -g option enables debugging mode 
# -c flag generates object code for separate files


#
# Makefile conversione temperatura
# Sistema operativo Linux con compilatore gcc 2.95.2
# Utilizzo di macro
#
# CC = gcc
# LD = gcc
# OBJS = context.o config.o file_info.o matching_functions.o meta.o
# FLAGS	 = -g -c -Wall
# LFLAGS	 = -lpthread

FLAGS	 = -Wall -Wextra -pedantic -std=c11 #-Werror
# LFLAGS	 = -lpthread


core: core/file_info.h matching_functions.h meta.h context.o config.o 
	echo "Compiling Drill Core"
	gcc -shared -fPIC -o drill_core.a file_info.h matching_functions.h meta.h context.h context.c config.c config.h $(FLAGS)

context.o : 
	gcc -c -fPIC context.h context.c $(FLAGS)

config.o : 
	gcc -c -fPIC config.c config.h $(FLAGS)


.PHONY: clean

# clean house
clean:
	rm -f *.gch drill-core.a
	echo Clean done

# run the program
run: $(OUT)
	./$(OUT)



# VPATH = SRC INCLUDE 
# #
# cli: $(OBJS)
# 	$(LD) -o cli $(OBJS)


# cli.o: cli.c
# 	$(CC) -c cli/cli.c

# file_info.o: core/file_info.c
# 	$(CC) -c -I./INCLUDE -I./SRC

# config.o: core/config.c
# 	$(CC) -c -I./INCLUDE -I./SRC

# context.o: core/context.c
# 	$(CC) -c -I./INCLUDE -I./SRC


# all: cli gtk

# cli: $(OBJS0) $(LFLAGS)
# 	$(CC) -g $(OBJS0) -o $(OUT0)

# gtk: $(OBJS1) $(LFLAGS)
# 	$(CC) -g $(OBJS1) -o $(OUT1)


# # create/compile the individual files >>separately<<
# # cheese.o: cheese.c
# # 	$(CC) $(FLAGS) cheese.c -std=c11 -lcunit

# bread.o: bread.c
# 	$(CC) $(FLAGS) bread.c -std=c11 -lcunit

# butter.o: butter.c
# 	$(CC) $(FLAGS) butter.c -std=c11 -lcunit

# baycon.o: baycon.c,
# 	$(CC) $(FLAGS) baycon.c, -std=c11 -lcunit

# mushrooms.o: mushrooms.c
# 	$(CC) $(FLAGS) mushrooms.c -std=c11 -lcunit

# ketchup.o: ketchup.c
# 	$(CC) $(FLAGS) ketchup.c -std=c11 -lcunit


