# Rune: Standard ML '97 to bytecode compiler + portable C VM.
#
#   make            build compiler with MLton (bin/rune) and the VM (bin/runevm)
#   make mlton|smlnj|polyml   build the compiler with a specific SML system
#   make all3       build the compiler with all three SML systems
#   make vm         build bin/runevm
#   make test       run the test suite with bin/rune
#   make test-all   run the suite with each of the three compiler builds
#   make check-cross  verify all three builds emit byte-identical bytecode
#   make check-docs verify docs/language.md, tests and .def files are in sync
#   make test-basis run the Basis Library suite (tests/basis) with bin/rune
#   make test-stress  both suites with a collection before every GC_STRESS-th
#                   (101; Basis Library suite: GC_STRESS_BASIS-th, 1009) allocation
#   make boot       bin/rune.rbc (the compiler compiled by itself) + bin/rune-boot wrapper
#   make test-boot  run the suite with the self-hosted compiler
#   make bootstrap  verify that the self-hosted compiler reproduces bin/rune.rbc
#   make check      everything above
#   make doctor     check that the tools all targets need are installed
#   make matrix-quick  the Basis Library suite on Rune, on the installed MLton,
#                   SML/NJ and Poly/ML, and on Rune's library compiled by them
#   make hosts      install current releases of the three under ~/.local/rune-hosts
#   make matrix     matrix-quick and the same with those releases
#
# The build and test targets check their own tools once before they first run
# (scripts/doctor.sh); `make DOCTOR=no ...` skips that.
#
# Recipes and test programs run in parallel on all available CPUs;
# `make JOBS=N ...` uses N instead.

SHELL   := /bin/sh
ifndef JOBS
JOBS    := $(shell sh scripts/ncpus.sh)
endif
ifeq ($(MAKELEVEL),0)
MAKEFLAGS += -j$(JOBS)
endif
CC      ?= cc
CFLAGS  ?= -std=c99 -O2 -Wall -Wextra -pedantic
ROOT    := $(CURDIR)
RUNE_LIB ?= $(ROOT)/lib

SOURCES  := $(shell grep -v '^[[:space:]]*\#' sources.txt | grep -v '^[[:space:]]*$$')
GEN_SML  := src/backend/opcodes.sml src/backend/prims.sml
GEN_C    := vm/opcodes.h vm/prims_table.h
BUILDGEN := build/rune.mlb build/rune.cm build/polyml-build.sml build/config.sml

VM_SRCS := vm/main.c vm/heap.c vm/loader.c vm/interp.c vm/prims.c
VM_HDRS := vm/vm.h $(GEN_C)

# Sources of the compiler as compiled by itself, and the initial semispace of
# the VM running it (a large heap keeps the bootstrap nearly collection-free).
BOOT_SRCS := build/config.sml $(SOURCES) src/main/rune-main.sml
BOOT_HEAP ?= 268435456

.PHONY: all mlton smlnj polyml all3 vm vm-asan gen test test-all check-cross check-docs boot test-boot bootstrap check clean doctor test-basis test-stress hosts matrix-quick matrix

all: mlton vm

# ---------------------------------------------------------------- environment
# `make doctor` reports on everything. Targets depend (order-only) on a stamp
# per doctor scope, so each scope is checked once: again after `make clean` or
# when the script changes.
doctor:
	@CC="$(CC)" sh scripts/doctor.sh

build/.doctor-%: scripts/doctor.sh
	@mkdir -p build
	@[ "$(DOCTOR)" = no ] || { CC="$(CC)" sh scripts/doctor.sh --quiet --scope $* && touch $@; }

# ---------------------------------------------------------------- generated
gen: $(BUILDGEN) $(GEN_SML) $(GEN_C)

$(BUILDGEN) &: sources.txt scripts/gen-build-files.sh
	RUNE_LIB="$(RUNE_LIB)" sh scripts/gen-build-files.sh "$(ROOT)"

$(GEN_SML) $(GEN_C) &: vm/opcodes.def vm/prims.def scripts/gen-opcodes.sh
	sh scripts/gen-opcodes.sh

# ---------------------------------------------------------------- compiler
mlton: bin/rune-mlton
	ln -sf rune-mlton bin/rune

smlnj: bin/rune-smlnj

polyml: bin/rune-polyml

all3: mlton smlnj polyml

bin/rune-mlton: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/mlton-main.sml | build/.doctor-mlton
	@mkdir -p bin
	mlton -output $@ build/rune.mlb

bin/rune-smlnj: $(BUILDGEN) $(SOURCES) $(GEN_SML) | build/.doctor-smlnj
	@mkdir -p bin
	ml-build build/rune.cm Main.main bin/rune-smlnj.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec sml @SMLload="$$d/rune-smlnj.heap" "$$@"\n' > $@
	chmod +x $@

bin/rune-polyml: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/polyml-main.sml | build/.doctor-polyml
	@mkdir -p bin
	polyc -o $@ build/polyml-build.sml

# ---------------------------------------------------------------- VM
vm: bin/runevm

bin/runevm: $(VM_SRCS) $(VM_HDRS) | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -o $@ $(VM_SRCS) -lm

vm-asan: bin/runevm-asan

bin/runevm-asan: $(VM_SRCS) $(VM_HDRS) | build/.doctor-asan
	@mkdir -p bin
	$(CC) -std=c99 -g -O1 -Wall -Wextra -fsanitize=address,undefined -fno-omit-frame-pointer -o $@ $(VM_SRCS) -lm

# ---------------------------------------------------------------- tests
test: mlton vm | build/.doctor-check
	sh tests/run-tests.sh -j $(JOBS) --rune bin/rune --vm bin/runevm

test-all: all3 vm | build/.doctor-check
	@for c in mlton smlnj polyml; do \
	  echo "=== testing with $$c build ==="; \
	  sh tests/run-tests.sh -j $(JOBS) --rune bin/rune-$$c --vm bin/runevm || exit 1; \
	done

check-cross: all3 bin/rune-boot | build/.doctor-check
	sh scripts/check-cross.sh -j $(JOBS)

check-docs:
	sh scripts/check-docs.sh
	sh scripts/check-basis-coverage.sh

# ---------------------------------------------------------------- Basis Library suite
# tests/basis/README.md. The matrix targets compare Rune with other systems
# and are not part of `make check`.
test-basis: mlton vm | build/.doctor-check
	sh tests/basis/run-matrix.sh -j $(JOBS) --configs rune

# Not part of `make check`: a collection before every allocation makes a few
# tests quadratic. For VM changes, next to `make vm-asan`.
# The Basis Library suite keeps vectors of 200000 elements alive, so it gets
# a longer interval and time limit (about 4 minutes).
GC_STRESS ?= 101
GC_STRESS_BASIS ?= 1009
test-stress: mlton vm | build/.doctor-check
	printf '#!/bin/sh\nexec "$(ROOT)/bin/runevm" --gc-stress "$${RUNE_GC_STRESS:-1}" "$$@"\n' > bin/runevm-stress
	chmod +x bin/runevm-stress
	RUNE_GC_STRESS=$(GC_STRESS) sh tests/run-tests.sh -j $(JOBS) --rune bin/rune --vm bin/runevm-stress
	RUNE_GC_STRESS=$(GC_STRESS_BASIS) RUNE_MATRIX_TIMEOUT=900 RUNEVM="$(ROOT)/bin/runevm-stress" \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs rune

hosts: | build/.doctor-matrix
	sh scripts/fetch-hosts.sh

MATRIX_DOCTOR := build/.doctor-mlton build/.doctor-smlnj build/.doctor-polyml build/.doctor-check

matrix-quick: mlton vm | $(MATRIX_DOCTOR)
	sh tests/basis/run-matrix.sh -j $(JOBS) --configs installed,xc1

matrix: mlton vm | $(MATRIX_DOCTOR)
	sh tests/basis/run-matrix.sh -j $(JOBS) --configs all

# ---------------------------------------------------------------- bootstrap
# Stage 1: the MLton build compiles the compiler to bytecode. bin/rune-boot
# runs it on runevm; `bootstrap` checks that it reproduces itself byte for byte.
bin/rune.rbc: bin/rune-mlton bin/runevm $(BOOT_SRCS) lib/basis/MANIFEST $(wildcard lib/basis/*.sml)
	bin/rune-mlton -o $@ $(BOOT_SRCS)

bin/rune-boot: bin/rune.rbc
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" --heap-size $(BOOT_HEAP) "$$d/rune.rbc" "$$@"\n' > $@
	chmod +x $@

boot: bin/rune-boot

test-boot: bin/rune-boot vm | build/.doctor-check
	sh tests/run-tests.sh -j $(JOBS) --rune bin/rune-boot --vm bin/runevm

bootstrap: bin/rune-boot
	bin/rune-boot -o bin/rune.stage2.rbc $(BOOT_SRCS)
	cmp bin/rune.rbc bin/rune.stage2.rbc
	@echo "bootstrap: bin/rune.rbc reproduces itself"

# Steps run one after another: the suite runs share tests/out, and each step
# keeps JOBS CPUs busy by itself. bootstrap is a single process, so it runs
# alongside test-boot.
check:
	@$(MAKE) --no-print-directory all3 vm boot
	@$(MAKE) --no-print-directory test
	@$(MAKE) --no-print-directory test-all
	@$(MAKE) --no-print-directory test-basis
	@$(MAKE) --no-print-directory test-boot bootstrap
	@$(MAKE) --no-print-directory check-cross check-docs

clean:
	rm -rf bin build $(GEN_SML) $(GEN_C) tests/out
	find . -type d -name .cm -prune -exec rm -rf {} +
