SHELL=/bin/sh
OS=$(shell uname || uname -s)
ARCH=$(shell arch || uname -m)

GIR_TO_D_VERSION=v0.16.0

ifndef DC
    ifneq ($(strip $(shell which dmd 2>/dev/null)),)
        DC=dmd
    else ifneq ($(strip $(shell which ldc 2>/dev/null)),)
        DC=ldc
    else ifneq ($(strip $(shell which ldc2 2>/dev/null)),)
        DC=ldc2
    else
        DC=gdc
    endif
endif

ifeq ("$(DC)","gdc")
    DCFLAGS=-O2
    INCLUDEFLAG=-J
    LINKERFLAG=-Xlinker 
    DDOCFLAGS=-fsyntax-only -c -fdoc -fdoc-file=$@
    DDOCINC=-fdoc-inc=
    output=-o $@
else
    DCFLAGS=-O
    INCLUDEFLAG=-J
    LINKERFLAG=-L
    DDOCFLAGS=-o- -Df$@
	output=-of$@
endif

#######################################################################

.DEFAULT_GOAL = $(BINNAME)

SOURCES = $(wildcard source/*.d) $(wildcard source/gtd/*.d)
BINNAME = girtod

$(BINNAME): VERSION $(SOURCES)
	$(DC) $(filter-out $<,$^) $(output) $(INCLUDEFLAG)./ $(DCFLAGS) $(LDFLAGS)
	rm -f *.o

VERSION: VERSION.in
	sed 's/@VCS_TAG@/$(shell git describe --dirty=+ --tags || echo $(GIR_TO_D_VERSION))/g' $< > $@

clean:
	-rm -f $(BINNAME)
	-rm -f VERSION

