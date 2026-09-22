# Rune: Standard ML '97 to bytecode compiler + portable C VM.
#
#   make hosts      install the SML systems Rune is built and compared with
#                   (MLton, SML/NJ in 64 and 32 bits, Poly/ML) under
#                   ~/.local/rune-hosts; needed once, before anything else
#   make            build bin/rune (the self-hosted compiler) and bin/runevm
#   make mlton|smlnj|smlnj32|polyml   build the compiler with one of them
#   make host-builds  build the compiler with all four
#   make vm         build bin/runevm
#   make boot       bin/rune.rbc (the compiler compiled by bin/rune-$(BOOTHOST)),
#                   the bin/rune-boot wrapper that runs it, and bin/rune -> it
#   make test       run the test suite with bin/rune
#   make install    install rune, runevm, runedoc and the basis library under PREFIX
#                   (/usr/local as root, ~/.local otherwise); as root nothing
#                   is built, so run `make` as yourself first
#   make uninstall  remove them again
#   make test-all   run the suite with each of the four host builds
#   make check-cross  verify all five builds emit byte-identical bytecode
#   make check-docs verify docs/language.md, tests and .def files are in sync
#   make test-basis run the Basis Library suite (tests/basis) with bin/rune
#   make perf-check verify the instruction and allocation budgets (tests/perf)
#   make test-stress  both suites with a collection before every GC_STRESS-th
#                   (101; Basis Library suite: GC_STRESS_BASIS-th, 1009) allocation
#   make bootstrap  verify that the self-hosted compiler reproduces bin/rune.rbc
#   make check      everything above
#   make doctor     check that the tools all targets need are installed
#   make matrix-quick  the Basis Library suite on Rune and on Rune's library
#                   compiled by each of the hosts
#   make matrix     matrix-quick and the suite on each host's own library
#   make windows    the VM for Windows with mingw-w64, 64-bit and 32-bit
#                   (docs/building.md); it and make test-windows are apart
#                   from every other target
#   make perf       the wall-clock times of tests/perf in the configurations of
#                   the matrix
#
# bin/rune is the compiler Rune ships: itself, on the VM. The host builds
# bin/rune-mlton, bin/rune-smlnj, bin/rune-smlnj32 and bin/rune-polyml exist
# to bootstrap it and to check that all five agree (check-cross). Every target
# that runs the compiler uses $(RUNE), so `make test RUNE=bin/rune-mlton` is
# the fast loop. `make BOOTHOST=smlnj` bootstraps with another host.
#
# The SML systems are the releases scripts/fetch-hosts.sh installs under
# $(HOSTS), never ones the machine has on its PATH: MLTON, MLBUILD, SMLNJ,
# MLBUILD32, SMLNJ32 and POLYC name their commands.
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
RUNEDOC ?= bin/runedoc

SOURCES  := $(shell grep -v '^[[:space:]]*\#' sources.txt | grep -v '^[[:space:]]*$$')
GEN_SML  := src/backend/opcodes.sml src/backend/prims.sml
GEN_C    := vm/opcodes.h vm/prims_table.h
SOURCES_DOC := $(shell grep -v '^[[:space:]]*\#' sources-doc.txt | grep -v '^[[:space:]]*$$')
BUILDGEN := build/rune.mlb build/rune.cm build/polyml-build.sml build/runedoc.mlb build/runedoc.cm build/runedoc-polyml-build.sml build/config.sml

# The core VM is ISO C99; what needs the operating system is in vm/sys.h and
# one of its implementations. `make SYS=none` builds without POSIX, and the
# library then reports ENOSYS for what it cannot do.
SYS ?= posix
VM_SRCS := vm/main.c vm/heap.c vm/loader.c vm/interp.c vm/prims.c vm/sys_$(SYS).c
VM_HDRS := vm/vm.h vm/sys.h $(GEN_C)

# The host SML systems (`make hosts`).
HOSTS     ?= $(or $(RUNE_HOSTS),$(HOME)/.local/rune-hosts)
MLTON     ?= $(HOSTS)/mlton/bin/mlton
MLBUILD   ?= $(HOSTS)/smlnj/bin/ml-build
SMLNJ     ?= $(HOSTS)/smlnj/bin/sml
MLBUILD32 ?= $(HOSTS)/smlnj32/bin/ml-build
SMLNJ32   ?= $(HOSTS)/smlnj32/bin/sml
POLYC     ?= $(HOSTS)/polyml/bin/polyc
export RUNE_HOSTS := $(HOSTS)
export MLTON SMLNJ SMLNJ32 POLYC

# Sources of the compiler as compiled by itself, the host build that compiles
# stage 1, and the initial semispace of the VM that bin/rune runs on. The heap
# grows on demand; this only sets how much is mapped up front (measured: 32 MiB
# to 256 MiB are within 3% of each other on the bootstrap, and the smaller
# sizes keep the resident set of JOBS parallel compilers down).
BOOT_SRCS := build/config.sml $(SOURCES) src/main/rune-main.sml
BOOTHOST ?= mlton
RUNE_HEAP ?= 67108864

.PHONY: windows test-windows docs test-doc all mlton smlnj smlnj32 polyml host-builds runedoc runedoc-host-builds vm vm-asan gen test test-all check-cross check-docs boot bootstrap check clean doctor test-basis perf-check test-stress hosts matrix-quick matrix perf install uninstall

all: vm boot runedoc

# ---------------------------------------------------------------- environment
# `make doctor` reports on everything. Targets depend (order-only) on a stamp
# per doctor scope, so each scope is checked once: again after `make clean` or
# when the script changes.
doctor:
	@CC="$(CC)" sh scripts/doctor.sh
	@WINCC="$(WINCC)" WINCC32="$(WINCC32)" sh scripts/doctor.sh --scope windows || \
	  echo "doctor: the Windows tools are optional: only make windows and make test-windows need them"

build/.doctor-%: scripts/doctor.sh
	@mkdir -p build
	@[ "$(DOCTOR)" = no ] || { CC="$(CC)" WINCC="$(WINCC)" WINCC32="$(WINCC32)" sh scripts/doctor.sh --quiet --scope $* && touch $@; }

# ---------------------------------------------------------------- generated
gen: $(BUILDGEN) $(GEN_SML) $(GEN_C)

$(BUILDGEN) &: sources.txt sources-doc.txt scripts/gen-build-files.sh
	sh scripts/gen-build-files.sh "$(ROOT)"

$(GEN_SML) $(GEN_C) &: vm/opcodes.def vm/prims.def scripts/gen-opcodes.sh
	sh scripts/gen-opcodes.sh

# ---------------------------------------------------------------- compiler
# The compiler has no built-in library path, so each bin/rune* is a wrapper
# that passes --lib; the payload of a host build sits next to it as .bin.
# A --lib of the caller's comes later on the command line and so wins.
mlton: bin/rune-mlton

smlnj: bin/rune-smlnj

smlnj32: bin/rune-smlnj32

polyml: bin/rune-polyml

host-builds: mlton smlnj smlnj32 polyml runedoc-host-builds

bin/rune-mlton.bin: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/mlton-main.sml | build/.doctor-mlton
	@mkdir -p bin
	$(MLTON) -output $@ build/rune.mlb

bin/rune-mlton: bin/rune-mlton.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/rune-mlton.bin" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/rune-smlnj: $(BUILDGEN) $(SOURCES) $(GEN_SML) Makefile | build/.doctor-smlnj
	@mkdir -p bin
	$(MLBUILD) build/rune.cm Main.main bin/rune-smlnj.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/rune-smlnj.heap" --lib "$$d/../lib" "$$@"\n' "$(SMLNJ)" > $@
	chmod +x $@

# The 32-bit SML/NJ (31-bit int and word) catches code that depends on the
# width of int. After the 64-bit build: CM keeps both in the same .cm
# directories.
bin/rune-smlnj32: $(BUILDGEN) $(SOURCES) $(GEN_SML) Makefile | build/.doctor-smlnj32 bin/rune-smlnj
	@mkdir -p bin
	$(MLBUILD32) build/rune.cm Main.main bin/rune-smlnj32.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/rune-smlnj32.heap" --lib "$$d/../lib" "$$@"\n' "$(SMLNJ32)" > $@
	chmod +x $@

bin/rune-polyml.bin: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/polyml-main.sml | build/.doctor-polyml
	@mkdir -p bin
	$(POLYC) -o $@ build/polyml-build.sml

bin/rune-polyml: bin/rune-polyml.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/rune-polyml.bin" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

# ---------------------------------------------------------------- runedoc
# The documentation generator (docs/plans/docgen.md): the sources of
# sources-doc.txt, built like the compiler by every host and by the compiler
# itself (bin/runedoc, on runevm). The SML/NJ builds come one after another
# and after the compiler's: CM keeps them all in the same .cm directories.
runedoc-host-builds: bin/runedoc-mlton bin/runedoc-smlnj bin/runedoc-smlnj32 bin/runedoc-polyml

bin/runedoc-mlton.bin: $(BUILDGEN) $(SOURCES_DOC) $(GEN_SML) src/main/runedoc-mlton-main.sml | build/.doctor-mlton
	@mkdir -p bin
	$(MLTON) -output $@ build/runedoc.mlb

bin/runedoc-mlton: bin/runedoc-mlton.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runedoc-mlton.bin" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/runedoc-smlnj: $(BUILDGEN) $(SOURCES_DOC) $(GEN_SML) Makefile | build/.doctor-smlnj bin/rune-smlnj32
	@mkdir -p bin
	$(MLBUILD) build/runedoc.cm DocMain.main bin/runedoc-smlnj.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/runedoc-smlnj.heap" --lib "$$d/../lib" "$$@"\n' "$(SMLNJ)" > $@
	chmod +x $@

bin/runedoc-smlnj32: $(BUILDGEN) $(SOURCES_DOC) $(GEN_SML) Makefile | build/.doctor-smlnj32 bin/runedoc-smlnj
	@mkdir -p bin
	$(MLBUILD32) build/runedoc.cm DocMain.main bin/runedoc-smlnj32.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/runedoc-smlnj32.heap" --lib "$$d/../lib" "$$@"\n' "$(SMLNJ32)" > $@
	chmod +x $@

bin/runedoc-polyml.bin: $(BUILDGEN) $(SOURCES_DOC) $(GEN_SML) src/main/runedoc-polyml-main.sml | build/.doctor-polyml
	@mkdir -p bin
	$(POLYC) -o $@ build/runedoc-polyml-build.sml

bin/runedoc-polyml: bin/runedoc-polyml.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runedoc-polyml.bin" --lib "$$d/../lib" "$$@"\n' > $@
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

# ---------------------------------------------------------- Windows (apart)
# `make windows` builds the VM for Windows with mingw-w64, for 64 bits
# (bin/runevm.exe) and for 32 bits (bin/runevm32.exe), and `make
# test-windows` runs the language suite, tests/vm and the Basis Library
# suite (the rune:windows configurations of tests/basis/run-matrix.sh) on
# both. Neither is part of any other target, and nothing else in the tree
# depends on vm/sys_win.c: the toolchain is only on a machine that has it,
# and running the result needs Windows, or WSL, which starts an .exe for
# you. The library, the compiler and the bytecode are the same as
# everywhere else -- only the VM differs -- so the suites are compiled with
# the ordinary bin/rune and run on each VM.
#
# The 32-bit VM computes with SSE2 as the 64-bit one does (x87 arithmetic
# rounds differently) and is linked large-address-aware, which gives it
# 4 GiB of address space under 64-bit Windows instead of 2. An .exe that
# imports a DLL of the toolchain rather than of Windows (libwinpthread,
# libgcc_s) would not start without it beside it, so the link is refused.
#
# What the system layer of Windows does and does not do is in the header of
# vm/sys_win.c; tests/windows-skip.txt lists the programs that need what it
# does not and why, and docs/plans/windows.md what is left to do.
WINCC       ?= x86_64-w64-mingw32-gcc
WINCC32     ?= i686-w64-mingw32-gcc
WINCFLAGS   ?= -std=c99 -O2 -Wall -Wextra -D__USE_MINGW_ANSI_STDIO=1
WINCFLAGS32 ?= -msse2 -mfpmath=sse -Wl,--large-address-aware
WIN_SRCS    := vm/main.c vm/heap.c vm/loader.c vm/interp.c vm/prims.c vm/sys_win.c
WIN_LIBS    :=

# windows_dlls CC: refuse $@ when it imports a DLL whose name starts with lib
define windows_dlls
	@for d in $$($$($(1) -print-prog-name=objdump) -p $@ | sed -n 's/^[[:space:]]*DLL Name: //p'); do \
	  case $$d in [Ll][Ii][Bb]*) echo "make windows: $@ imports $$d, which is not part of Windows"; \
	    rm -f $@; exit 1 ;; esac; \
	done
endef

windows: bin/runevm.exe bin/runevm32.exe

bin/runevm.exe: $(VM_SRCS) $(VM_HDRS) vm/sys_win.c | build/.doctor-windows
	@mkdir -p bin
	$(WINCC) $(WINCFLAGS) -o $@ $(WIN_SRCS) -Ivm $(WIN_LIBS)
	$(call windows_dlls,$(WINCC))

bin/runevm32.exe: $(VM_SRCS) $(VM_HDRS) vm/sys_win.c | build/.doctor-windows
	@mkdir -p bin
	$(WINCC32) $(WINCFLAGS) $(WINCFLAGS32) -o $@ $(WIN_SRCS) -Ivm $(WIN_LIBS)
	$(call windows_dlls,$(WINCC32))

test-windows: bin/runevm.exe bin/runevm32.exe $(RUNE)
	sh tests/run-windows.sh -j $(JOBS) --rune $(RUNE) --vm bin/runevm.exe --vm bin/runevm32.exe
	RUNE=$(abspath $(RUNE)) sh tests/basis/run-matrix.sh -j $(JOBS) --configs windows

# ---------------------------------------------------------------- tests
# Depending on $(RUNE) builds whichever compiler the override names.
test: $(RUNE) vm | build/.doctor-check
	sh tests/run-tests.sh -j $(JOBS) --rune $(RUNE) --vm $(RUNEVM)
	sh tests/vm/run-vm-tests.sh --vm $(RUNEVM)

test-all: host-builds vm | build/.doctor-check
	@for c in mlton smlnj smlnj32 polyml; do \
	  echo "=== testing with $$c build ==="; \
	  sh tests/run-tests.sh -j $(JOBS) --rune bin/rune-$$c --vm bin/runevm || exit 1; \
	done

check-cross: host-builds bin/rune-boot bin/runedoc-boot | build/.doctor-check
	sh scripts/check-cross.sh -j $(JOBS)

check-docs: $(RUNE) $(RUNEDOC)
	sh scripts/check-docs.sh
	RUNE=$(RUNE) sh scripts/gen-basis-sigs.sh --check
	$(RUNE) --basis-check
	$(RUNEDOC) --lint lib/basis/*.sml src/*/*.sml && echo "lint-docs: OK (the comments of lib/basis and src are in the language of doc comments)"
	sh tests/basis/gen-annotations.sh --check
	$(RUNEDOC) $(DOCS_BASIS) --check
	sh tests/basis/check-claims.sh
	sh tests/basis/check-notes.sh

# The generated documentation (docs/plans/docgen.md): `make docs` writes it,
# and it is committed; check-docs fails when it is not what the sources give.
# tests/basis/annotations.txt is what the suite knows about other implementations,
# made from deviations.txt by tests/basis/gen-annotations.sh and committed.
DOCS_BASIS := --lib lib --library basis --tests tests/basis --annotations tests/basis/annotations.txt \
              --out docs/generated/basis --title "The Standard ML Basis Library"

docs: $(RUNEDOC)
	$(RUNEDOC) $(DOCS_BASIS)

# ---------------------------------------------------------------- Basis Library suite
# tests/basis/README.md. The matrix targets compare Rune with other systems
# and are not part of `make check`.
# run-matrix.sh runs each program in its own directory, so $(RUNE) goes in absolute.
# Then the examples of the documentation that are equations are tried
# (tests/basis/run-examples.sh).
test-basis: $(RUNE) $(RUNEDOC) vm | build/.doctor-check
	RUNE=$(abspath $(RUNE)) RUNEVM=$(abspath $(RUNEVM)) \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs rune
	RUNE=$(RUNE) RUNEVM=$(RUNEVM) RUNEDOC=$(RUNEDOC) sh tests/basis/run-examples.sh

# Deterministic budgets on what `runevm --count` reports, for benchmark
# programs, the hello compile and the bootstrap (tests/perf/run-perf.sh;
# --update after a deliberate change). About 10 seconds.
# The tests of the documentation generator (tests/doc), with bin/runedoc;
# `make test-doc RUNEDOC=bin/runedoc-mlton` is the faster loop.
test-doc: $(RUNEDOC) vm
	RUNEDOC=$(RUNEDOC) sh tests/doc/run-doc-tests.sh

perf-check: $(RUNE) bin/runedoc vm | build/.doctor-check
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

MATRIX_DOCTOR := build/.doctor-mlton build/.doctor-smlnj build/.doctor-smlnj32 build/.doctor-polyml build/.doctor-check

matrix-quick: $(RUNE) vm | $(MATRIX_DOCTOR)
	RUNE=$(abspath $(RUNE)) RUNEVM=$(abspath $(RUNEVM)) \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs rune,xc1

matrix: $(RUNE) vm | $(MATRIX_DOCTOR)
	RUNE=$(abspath $(RUNE)) RUNEVM=$(abspath $(RUNEVM)) \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs all

PERF_CONFIGS ?= all

perf: $(RUNE) vm | $(MATRIX_DOCTOR)
	RUNE=$(abspath $(RUNE)) RUNEVM=$(abspath $(RUNEVM)) \
	  sh tests/basis/run-matrix.sh --perf --configs $(PERF_CONFIGS)

# ---------------------------------------------------------------- bootstrap
# Stage 1: a host build compiles the compiler to bytecode. bin/rune-boot runs
# it on runevm and is what bin/rune names; `bootstrap` checks that it
# reproduces itself byte for byte. check-cross knows the build as `boot`.
# All host builds emit the same bytecode, so BOOTHOST (mlton, smlnj, smlnj32
# or polyml) only decides which one builds stage 1, not what comes out.
bin/rune.rbc: bin/rune-$(BOOTHOST) bin/runevm $(BOOT_SRCS) lib/basis/MANIFEST $(wildcard lib/basis/*.sml)
	bin/rune-$(BOOTHOST) -o $@ $(BOOT_SRCS)

bin/rune-boot: bin/rune.rbc Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" --heap-size $(RUNE_HEAP) "$$d/rune.rbc" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/rune: bin/rune-boot
	ln -sf rune-boot $@

boot: bin/rune

# runedoc compiled by the self-hosted compiler.
DOC_SRCS := build/config.sml $(SOURCES_DOC) src/main/runedoc-rune-main.sml

bin/runedoc.rbc: bin/rune bin/rune.rbc $(DOC_SRCS)
	bin/rune -o $@ $(DOC_SRCS)

bin/runedoc-boot: bin/runedoc.rbc Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" --heap-size $(RUNE_HEAP) "$$d/runedoc.rbc" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/runedoc: bin/runedoc-boot
	ln -sf runedoc-boot $@

runedoc: bin/runedoc

bootstrap: bin/rune-boot
	bin/rune-boot -o bin/rune.stage2.rbc $(BOOT_SRCS)
	cmp bin/rune.rbc bin/rune.stage2.rbc
	@echo "bootstrap: bin/rune.rbc reproduces itself"

# Steps run one after another: the suite runs share tests/out, and each step
# keeps JOBS CPUs busy by itself. bootstrap is a single process, so it runs
# alongside the suite.
check:
	@$(MAKE) --no-print-directory host-builds vm boot runedoc
	@$(MAKE) --no-print-directory test bootstrap
	@$(MAKE) --no-print-directory test-doc
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
	  $(MAKE) --no-print-directory $(if $(HOST),vm $(HOST) $(if $(filter smlnj,$(HOST)),bin/runedoc-smlnj,bin/runedoc-$(HOST)),all); \
	fi
	RUNE_HEAP=$(RUNE_HEAP) SMLNJ=$(SMLNJ) sh scripts/install.sh $(INSTALL_FLAGS)

uninstall:
	sh scripts/install.sh --uninstall $(INSTALL_FLAGS)
