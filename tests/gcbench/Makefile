# tests/gcbench/Makefile -- the collector harness of
# docs/plans/garbage-collector-v2.md (*The harness*, H1-H10): one binary,
# ../out/gcbench/gcbench, built as one translation unit (main.c includes
# every experiment). `make -C tests/gcbench` with the tree's CC; `make -C
# tests/gcbench CC=clang-18` for a second compiler. The top-level `make
# gcbench` builds it, and `make check-gcbench` builds it and runs check.sh.
# GCB_ARCH is the instruction set: this machine's, since the harness
# measures the machine it runs on (the roadmap's numbers were made with
# gcc 13 and -march=haswell on the Haswell); GCB_ARCH= builds for any
# x86-64. A change of CC, CFLAGS or GCB_ARCH rebuilds (flags.txt).
CC       ?= cc
CFLAGS   ?= -std=c17 -O2 -Wall -Wextra -pedantic
GCB_ARCH ?= -march=native
LDFLAGS  := -lpthread -lm
OUT      := ../out/gcbench
SRCS     := main.c gcb.h trace.h gen.h h6k.h alloc.h collect.h heapgen.h h1.c h2.c h3.c h5.c h6.c h7.c h8.c h9.c h10.c ../layouts/common.h
BUILD    := $(CC) $(CFLAGS) $(GCB_ARCH)

all: $(OUT)/gcbench

$(OUT)/gcbench: $(SRCS) $(OUT)/flags.txt
	$(BUILD) -I../../runtime -o $@ main.c $(LDFLAGS)

# the compiler and flags of the last build, written only when they change
$(OUT)/flags.txt: FORCE | $(OUT)
	@echo '$(BUILD)' | cmp -s - $@ || echo '$(BUILD)' > $@

$(OUT):
	mkdir -p $(OUT)

clean:
	rm -rf $(OUT)

FORCE:
.PHONY: all clean FORCE
