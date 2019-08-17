FLAGS	 = -Wall -Wextra -pedantic -std=c11 #-Werror
# LFLAGS	 = -lpthread



.PHONY: build
build: cli.c drill_core.a
	gcc -fPIC -o cli.elf cli.c ../core/drill_core.a $(FLAGS) -I../core

.PHONY: clean
clean:
	rm -f cli.elf
	cd ../core && make clean
	echo Clean done

.PHONY: run
run:
	make build
	./cli.elf

drill_core.a : 
	echo "Compiling Drill Core"
	cd ../core && make
