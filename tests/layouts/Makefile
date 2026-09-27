# tests/layouts/Makefile -- the layout harness (docs/plans/heap-layout.md,
# *The experiments*): one binary per (layout + variant) in
# ../out/layouts/$(CCNAME)/harness-NAME, built from the same kernels
# (kernels.c) over the layout headers (layouts/*.h) and the size models of
# vm/layouts.h. `make -C tests/layouts` with the tree's CC; `make -C
# tests/layouts CC=clang-18` for a second compiler (CCNAME is the compiler's
# basename). The top-level `make check-layouts` builds and runs check.sh.
CC      ?= cc
CCNAME  ?= $(notdir $(CC))
CFLAGS  ?= -std=c17 -O2 -Wall -Wextra -pedantic
LDFLAGS := -lpthread -lm
OUT     := ../out/layouts/$(CCNAME)

CONFIGS := L0 L1 L1+REALIMM L1+UNBOXED L1+PAIRS L1+HDR4 L1+ALIGN16 L1+FLATREAL L1+COMPACT L1+BARRIER \
           L2 L2+REALIMM L3 L3+NAN51 L4MONO L4UNI L4MONO+PAIRS L4UNI+FLATREAL L4MONO+COMPACT L4UNI+PAIRS

FLAGS_L0            := -DLAYOUT=L0
FLAGS_L1            := -DLAYOUT=L1
FLAGS_L1+REALIMM    := -DLAYOUT=L1 -DREALIMM
FLAGS_L1+UNBOXED    := -DLAYOUT=L1 -DL1_UNBOXED_LOCALS
FLAGS_L1+PAIRS      := -DLAYOUT=L1 -DPAIRS
FLAGS_L1+HDR4       := -DLAYOUT=L1 -DHDR4
FLAGS_L1+ALIGN16    := -DLAYOUT=L1 -DALIGN16
FLAGS_L1+FLATREAL   := -DLAYOUT=L1 -DFLATREAL
FLAGS_L1+COMPACT    := -DLAYOUT=L1 -DCOMPACTBYTES
FLAGS_L1+BARRIER    := -DLAYOUT=L1 -DBARRIER_CARD
FLAGS_L2            := -DLAYOUT=L2
FLAGS_L2+REALIMM    := -DLAYOUT=L2 -DREALIMM
FLAGS_L3            := -DLAYOUT=L3
FLAGS_L3+NAN51      := -DLAYOUT=L3 -DNAN51
FLAGS_L4MONO        := -DLAYOUT=L4 -DL4_MONO
FLAGS_L4UNI         := -DLAYOUT=L4 -DL4_UNIFORM
FLAGS_L4MONO+PAIRS  := -DLAYOUT=L4 -DL4_MONO -DPAIRS
FLAGS_L4UNI+FLATREAL:= -DLAYOUT=L4 -DL4_UNIFORM -DFLATREAL
FLAGS_L4MONO+COMPACT:= -DLAYOUT=L4 -DL4_MONO -DCOMPACTBYTES
FLAGS_L4UNI+PAIRS   := -DLAYOUT=L4 -DL4_UNIFORM -DPAIRS

BINS := $(addprefix $(OUT)/harness-,$(CONFIGS))
SRCS := main.c kernels.c harness.h common.h gc_core.h map_impl.h layouts/iface.h layouts/objs8.h layouts/L0.h layouts/L1.h layouts/L2.h layouts/L3.h layouts/L4.h ../../vm/layouts.h

all: $(BINS)

$(OUT)/harness-%: $(SRCS) | $(OUT)
	$(CC) $(CFLAGS) $(FLAGS_$*) -I../../vm -o $@ main.c $(LDFLAGS)

$(OUT):
	mkdir -p $(OUT)

# the first two layouts alone, for a quick sanity check
first: $(OUT)/harness-L0 $(OUT)/harness-L1

clean:
	rm -rf ../out/layouts

.PHONY: all first clean
