FLAGS	 = -std=c11#-Wall -Wextra -pedantic  -Wfatal-errors #-Werror



ifeq ($(OS),Windows_NT)
    CCFLAGS += -D WIN32
    ifeq ($(PROCESSOR_ARCHITEW6432),AMD64)
        CCFLAGS += -D AMD64
    else
        ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
            CCFLAGS += -D AMD64
        endif
        ifeq ($(PROCESSOR_ARCHITECTURE),x86)
            CCFLAGS += -D IA32
        endif
    endif
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        CCFLAGS += -D LINUX
		LFLAGS	 = -lpthread
    endif
    ifeq ($(UNAME_S),Darwin)
        CCFLAGS += -D OSX
    endif
    UNAME_P := $(shell uname -p)
    ifeq ($(UNAME_P),x86_64)
        CCFLAGS += -D AMD64
    endif
    ifneq ($(filter %86,$(UNAME_P)),)
        CCFLAGS += -D IA32
    endif
    ifneq ($(filter arm%,$(UNAME_P)),)
        CCFLAGS += -D ARM
    endif
endif



.PHONY: build
build: cli.c drill_core.a
	gcc -fPIC -o cli.elf cli.c ../core/drill_core.a $(FLAGS) -I../core $(LFLAGS)

.PHONY: clean
clean:
	rm -f cli.elf
	cd ../core && make clean
	echo Clean done

.PHONY: run
run:
	cd ../core && make clean
	make build
	./cli.elf

drill_core.a : 
	echo "Compiling Drill Core"
	cd ../core && make
