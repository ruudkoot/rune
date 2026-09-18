# Rune: Standard ML '97 to bytecode compiler + portable C VM.
#
#   make            build bin/rune (the self-hosted compiler) and bin/runevm
#   make mlton|smlnj|polyml   build the compiler with a specific SML system
#   make all3       build the compiler with all three SML systems
#   make vm         build bin/runevm
#   make boot       bin/rune.rbc (the compiler compiled by bin/rune-$(BOOTHOST)),
#                   the bin/rune-boot wrapper that runs it, and bin/rune -> it
#   make test       run the test suite with bin/rune
#   make install    install rune, runevm and the basis library under PREFIX
#                   (/usr/local as root, ~/.local otherwise); as root nothing
#                   is built, so run `make` as yourself first
#   make uninstall  remove them again
#   make test-all   run the suite with each of the three host builds
#   make check-cross  verify all four builds emit byte-identical bytecode
#   make check-docs verify docs/language.md, tests and .def files are in sync
#   make test-basis run the Basis Library suite (tests/basis) with bin/rune
#   make perf-check verify the instruction and allocation budgets (tests/perf)
#   make test-stress  both suites with a collection before every GC_STRESS-th
#                   (101; Basis Library suite: GC_STRESS_BASIS-th, 1009) allocation
#   make bootstrap  verify that the self-hosted compiler reproduces bin/rune.rbc
#   make check      everything above
#   make doctor     check that the tools all targets need are installed
#   make matrix-quick  the Basis Library suite on Rune, on the installed MLton,
#                   SML/NJ and Poly/ML, and on Rune's library compiled by them
#   make hosts      install current releases of the three under ~/.local/rune-hosts
#   make matrix     matrix-quick and the same with those releases
#
# bin/rune is the compiler Rune ships: itself, on the VM. The host builds
# bin/rune-mlton, bin/rune-smlnj and bin/rune-polyml exist to bootstrap it and
# to check that all four agree (check-cross). Every target that runs the
# compiler uses $(RUNE), so `make test RUNE=bin/rune-mlton` is the fast loop.
# `make BOOTHOST=smlnj` bootstraps with another host; any one of the three
# suffices to build everything but test-all, check-cross and the matrix.
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

# The compiler and VM the test targets run. Override to test another build:
# `make test RUNE=bin/rune-mlton`.
RUNE    ?= bin/rune
RUNEVM  ?= bin/runevm

SOURCES  := $(shell grep -v '^[[:space:]]*\#' sources.txt | grep -v '^[[:space:]]*$$')
GEN_SML  := src/backend/opcodes.sml src/backend/prims.sml
GEN_C    := vm/opcodes.h vm/prims_table.h
BUILDGEN := build/rune.mlb build/rune.cm build/polyml-build.sml build/config.sml

VM_SRCS := vm/main.c vm/heap.c vm/loader.c vm/interp.c vm/prims.c
VM_HDRS := vm/vm.h $(GEN_C)

# Sources of the compiler as compiled by itself, the host build that compiles
# stage 1, and the initial semispace of the VM that bin/rune runs on. The heap
# grows on demand; this only sets how much is mapped up front (measured: 32 MiB
# to 256 MiB are within 3% of each other on the bootstrap, and the smaller
# sizes keep the resident set of JOBS parallel compilers down).
BOOT_SRCS := build/config.sml $(SOURCES) src/main/rune-main.sml
BOOTHOST ?= mlton
RUNE_HEAP ?= 67108864

.PHONY: all mlton smlnj polyml all3 vm vm-asan gen test test-all check-cross check-docs boot bootstrap check clean doctor test-basis perf-check test-stress hosts matrix-quick matrix install uninstall

all: vm boot

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
	sh scripts/gen-build-files.sh "$(ROOT)"

$(GEN_SML) $(GEN_C) &: vm/opcodes.def vm/prims.def scripts/gen-opcodes.sh
	sh scripts/gen-opcodes.sh

# ---------------------------------------------------------------- compiler
# The compiler has no built-in library path, so each bin/rune* is a wrapper
# that passes --lib; the payload of a host build sits next to it as .bin.
# A --lib of the caller's comes later on the command line and so wins.
mlton: bin/rune-mlton

smlnj: bin/rune-smlnj

polyml: bin/rune-polyml

all3: mlton smlnj polyml

bin/rune-mlton.bin: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/mlton-main.sml | build/.doctor-mlton
	@mkdir -p bin
	mlton -output $@ build/rune.mlb

bin/rune-mlton: bin/rune-mlton.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/rune-mlton.bin" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/rune-smlnj: $(BUILDGEN) $(SOURCES) $(GEN_SML) Makefile | build/.doctor-smlnj
	@mkdir -p bin
	ml-build build/rune.cm Main.main bin/rune-smlnj.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec sml @SMLload="$$d/rune-smlnj.heap" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/rune-polyml.bin: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/polyml-main.sml | build/.doctor-polyml
	@mkdir -p bin
	polyc -o $@ build/polyml-build.sml

bin/rune-polyml: bin/rune-polyml.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/rune-polyml.bin" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

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
# Depending on $(RUNE) builds whichever compiler the override names.
test: $(RUNE) vm | build/.doctor-check
	sh tests/run-tests.sh -j $(JOBS) --rune $(RUNE) --vm $(RUNEVM)

test-all: all3 vm | build/.doctor-check
	@for c in mlton smlnj polyml; do \
	  echo "=== testing with $$c build ==="; \
	  sh tests/run-tests.sh -j $(JOBS) --rune bin/rune-$$c --vm bin/runevm || exit 1; \
	done

check-cross: all3 bin/rune-boot | build/.doctor-check
	sh scripts/check-cross.sh -j $(JOBS)

check-docs: $(RUNE)
	sh scripts/check-docs.sh
	sh scripts/check-basis-coverage.sh
	$(RUNE) --basis-check

# ---------------------------------------------------------------- Basis Library suite
# tests/basis/README.md. The matrix targets compare Rune with other systems
# and are not part of `make check`.
# run-matrix.sh runs each program in its own directory, so $(RUNE) goes in absolute.
test-basis: $(RUNE) vm | build/.doctor-check
	RUNE=$(abspath $(RUNE)) RUNEVM=$(abspath $(RUNEVM)) \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs rune

# Deterministic budgets on what `runevm --count` reports, for benchmark
# programs, the hello compile and the bootstrap (tests/perf/run-perf.sh;
# --update after a deliberate change). About 10 seconds.
perf-check: $(RUNE) vm | build/.doctor-check
	RUNE=$(RUNE) RUNEVM=$(RUNEVM) sh tests/perf/run-perf.sh

# Not part of `make check`: a collection before every allocation makes a few
# tests quadratic. For VM changes, next to `make vm-asan`.
# The Basis Library suite keeps vectors of 200000 elements alive, so it gets
# a longer interval and time limit (about 4 minutes).
# The tested programs run on the stressed VM; the compiler keeps the plain one
# (bin/rune names bin/runevm outright), or every compile would be quadratic too.
GC_STRESS ?= 101
GC_STRESS_BASIS ?= 1009
test-stress: $(RUNE) vm | build/.doctor-check
	printf '#!/bin/sh\nexec "$(ROOT)/bin/runevm" --gc-stress "$${RUNE_GC_STRESS:-1}" "$$@"\n' > bin/runevm-stress
	chmod +x bin/runevm-stress
	RUNE_GC_STRESS=$(GC_STRESS) sh tests/run-tests.sh -j $(JOBS) --rune $(RUNE) --vm bin/runevm-stress
	RUNE_GC_STRESS=$(GC_STRESS_BASIS) RUNE_MATRIX_TIMEOUT=900 \
	  RUNE=$(abspath $(RUNE)) RUNEVM="$(ROOT)/bin/runevm-stress" \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs rune

hosts: | build/.doctor-matrix
	sh scripts/fetch-hosts.sh

MATRIX_DOCTOR := build/.doctor-mlton build/.doctor-smlnj build/.doctor-polyml build/.doctor-check

matrix-quick: $(RUNE) vm | $(MATRIX_DOCTOR)
	RUNE=$(abspath $(RUNE)) RUNEVM=$(abspath $(RUNEVM)) \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs installed,xc1

matrix: $(RUNE) vm | $(MATRIX_DOCTOR)
	RUNE=$(abspath $(RUNE)) RUNEVM=$(abspath $(RUNEVM)) \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs all

# ---------------------------------------------------------------- bootstrap
# Stage 1: a host build compiles the compiler to bytecode. bin/rune-boot runs
# it on runevm and is what bin/rune names; `bootstrap` checks that it
# reproduces itself byte for byte. check-cross knows the build as `boot`.
# All three host builds emit the same bytecode, so BOOTHOST (mlton, smlnj or
# polyml) only decides which one has to be installed, not what comes out.
bin/rune.rbc: bin/rune-$(BOOTHOST) bin/runevm $(BOOT_SRCS) lib/basis/MANIFEST $(wildcard lib/basis/*.sml)
	bin/rune-$(BOOTHOST) -o $@ $(BOOT_SRCS)

bin/rune-boot: bin/rune.rbc Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" --heap-size $(RUNE_HEAP) "$$d/rune.rbc" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/rune: bin/rune-boot
	ln -sf rune-boot $@

boot: bin/rune

bootstrap: bin/rune-boot
	bin/rune-boot -o bin/rune.stage2.rbc $(BOOT_SRCS)
	cmp bin/rune.rbc bin/rune.stage2.rbc
	@echo "bootstrap: bin/rune.rbc reproduces itself"

# Steps run one after another: the suite runs share tests/out, and each step
# keeps JOBS CPUs busy by itself. bootstrap is a single process, so it runs
# alongside the suite.
check:
	@$(MAKE) --no-print-directory all3 vm boot
	@$(MAKE) --no-print-directory test bootstrap
	@$(MAKE) --no-print-directory test-all
	@$(MAKE) --no-print-directory test-basis
	@$(MAKE) --no-print-directory perf-check
	@$(MAKE) --no-print-directory check-cross check-docs

clean:
	rm -rf bin build $(GEN_SML) $(GEN_C) tests/out
	find . -type d -name .cm -prune -exec rm -rf {} +

# ---------------------------------------------------------------- install
# PREFIX defaults to /usr/local for root and ~/.local for anyone else;
# DESTDIR stages the tree elsewhere. `make install HOST=mlton` installs that
# host build instead of the bytecode compiler, with rune pointing at it.
# The target has no prerequisites: a root install builds nothing and fails if
# bin/ is empty, so `sudo make install` never leaves root-owned files behind.
PREFIX  ?=
DESTDIR ?=
HOST    ?=
INSTALL_FLAGS := $(if $(PREFIX),--prefix $(PREFIX)) $(if $(DESTDIR),--destdir $(DESTDIR)) $(if $(HOST),--host $(HOST))

install:
	@if [ "$$(id -u)" -eq 0 ]; then \
	  echo "install: running as root, installing what is in bin/ as it stands"; \
	else \
	  $(MAKE) --no-print-directory $(if $(HOST),vm $(HOST),all); \
	fi
	RUNE_HEAP=$(RUNE_HEAP) sh scripts/install.sh $(INSTALL_FLAGS)

uninstall:
	sh scripts/install.sh --uninstall $(INSTALL_FLAGS)
