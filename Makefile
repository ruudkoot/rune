# Rune: Standard ML '97 to bytecode compiler + portable C VM.
#
#   make hosts      install the SML systems Rune is built and compared with
#                   (MLton, SML/NJ in 64 and 32 bits, Poly/ML) under
#                   ~/.local/rune-hosts; needed once, before anything else
#   make            build bin/rune (the self-hosted compiler), bin/runevm, and
#                   bin/runedoc and bin/runeopt, which the compiler compiles
#   make mlton|smlnj|smlnj32|polyml   build the compiler with one of them
#   make host-builds  build the compiler with all four
#   make vm         build bin/runevm, and bin/runevm-new, vm/new's first loop
#   make boot       bin/rune.rbc (the compiler compiled by bin/rune-$(BOOTHOST)),
#                   the bin/rune-boot wrapper that runs it, and bin/rune -> it
#   make test       run the test suite with bin/rune
#   make install    install rune, runevm, runedoc, runeopt and the basis library under PREFIX
#                   (/usr/local as root, ~/.local otherwise); as root nothing
#                   is built, so run `make` as yourself first
#   make uninstall  remove them again
#   make test-all   run the suite with each of the four host builds
#   make check-cross  verify all five builds emit byte-identical bytecode
#   make check-positions  verify every instruction names a line that exists
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
#   make portability  the VM for a 32-bit x86 and for a big-endian 64-bit
#                   PowerPC; make test-portability runs both suites on them,
#                   the PowerPC one under qemu, and checks that an image of
#                   one is read by the others
#   make perf       the wall-clock times of tests/perf in the configurations of
#                   the matrix
#   make test-native  the suites with every program translated to native code
#                   by runeopt (docs/native.md); part of make check
#   make test-new   the suites through vm/new's first loop and the register
#                   bytecode (docs/bytecode.md); part of make check
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
RUNEOPT ?= bin/runeopt

SOURCES  := $(shell grep -v '^[[:space:]]*\#' sources.txt | grep -v '^[[:space:]]*$$')
GEN_SML  := src/backend/opcodes.sml src/backend/prims.sml src/backend/regcodes.sml
GEN_C    := vm/opcodes.h vm/prims_table.h vm/interp_cases.h vm/ops.h vm/new/regops.h vm/new/reg_cases.h
SOURCES_DOC := $(shell grep -v '^[[:space:]]*\#' sources-doc.txt | grep -v '^[[:space:]]*$$')
SOURCES_OPT := $(shell grep -v '^[[:space:]]*\#' sources-opt.txt | grep -v '^[[:space:]]*$$')
SOURCES_ISA := $(shell grep -v '^[[:space:]]*\#' sources-isa.txt | grep -v '^[[:space:]]*$$')
BUILDGEN := build/rune.mlb build/rune.cm build/polyml-build.sml build/runedoc.mlb build/runedoc.cm build/runedoc-polyml-build.sml build/runeopt.mlb build/runeopt.cm build/runeopt-polyml-build.sml build/runeisa.mlb build/runeisa.cm build/runeisa-polyml-build.sml build/config.sml vm/version.h

# The core VM is ISO C99; what needs the operating system is in vm/sys.h and
# one of its implementations. `make SYS=none` builds without POSIX, and the
# library then reports ENOSYS for what it cannot do.
#
# A VM is the runtime, RT_SRCS and a system layer, with the dispatch loop and
# the command line on top (vm/interp.c, vm/main.c). The runtime is also
# build/librune.a, which bin/runevm links, and so will a program runeopt
# makes (docs/native.md); the other VMs compile the same list.
SYS ?= posix
RT_SRCS := vm/runtime.c vm/heap.c vm/loader.c vm/isa_stack.c vm/prims.c vm/image.c
VM_SRCS := vm/main.c vm/interp.c $(RT_SRCS) vm/sys_$(SYS).c
VM_HDRS := vm/vm.h vm/sys.h vm/version.h $(GEN_C)
RT_OBJS := $(patsubst vm/%.c,build/librune/%.o,$(RT_SRCS) vm/sys_$(SYS).c)
AR      ?= ar

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

.PHONY: isa check-isa test-ir check-levels test-new windows test-windows portability test-portability docs test-doc runeopt runeopt-host-builds test-opt test-native test-native-stress test-native-asan all mlton smlnj smlnj32 polyml host-builds runedoc runedoc-host-builds vm vm-asan gen test test-all check-cross check-positions check-docs boot bootstrap check clean doctor test-basis perf-check test-stress hosts matrix-quick matrix perf install uninstall

all: vm boot runedoc runeopt

# ---------------------------------------------------------------- environment
# `make doctor` reports on everything. Targets depend (order-only) on a stamp
# per doctor scope, so each scope is checked once: again after `make clean` or
# when the script changes.
doctor:
	@CC="$(CC)" sh scripts/doctor.sh
	@WINCC="$(WINCC)" WINCC32="$(WINCC32)" sh scripts/doctor.sh --scope windows || \
	  echo "doctor: the Windows tools are optional: only make windows and make test-windows need them"
	@PORTCC32="$(PORTCC32)" PPCCC="$(PPCCC)" PPCROOT="$(PPCROOT)" QEMUPPC="$(QEMUPPC)" \
	  sh scripts/doctor.sh --scope portability || \
	  echo "doctor: these are optional too: only make portability and make test-portability need them"

build/.doctor-%: scripts/doctor.sh
	@mkdir -p build
	@[ "$(DOCTOR)" = no ] || { CC="$(CC)" WINCC="$(WINCC)" WINCC32="$(WINCC32)" sh scripts/doctor.sh --quiet --scope $* && touch $@; }

# ---------------------------------------------------------------- generated
gen: $(BUILDGEN)

$(BUILDGEN) &: sources.txt sources-doc.txt sources-opt.txt sources-isa.txt scripts/gen-build-files.sh
	sh scripts/gen-build-files.sh "$(ROOT)"

# The instruction sets are described in src/isa (docs/plans/middle-end.md,
# M1); runeisa writes from them the tables of the VM and the compiler and
# the .def files the scripts read, $(ISA_OUT). They are committed, so that
# the VM builds with a C compiler alone: `make isa` writes them again after
# a change to src/isa, and `make check-isa` (part of make check) fails when
# one of them is not what the descriptions give, with runeisa built by
# MLton and by the self-hosted compiler.
ISA_OUT := vm/opcodes.def vm/prims.def $(GEN_C) $(GEN_SML)

isa: bin/runeisa-mlton
	bin/runeisa-mlton --root .

check-isa: bin/runeisa-mlton bin/runeisa.rbc vm
	bin/runeisa-mlton --root . --check
	$(RUNEVM) bin/runeisa.rbc --root . --check

bin/runeisa-mlton.bin: $(BUILDGEN) $(SOURCES_ISA) src/main/runeisa-mlton-main.sml | build/.doctor-mlton
	@mkdir -p bin
	$(MLTON) -output $@ build/runeisa.mlb

bin/runeisa-mlton: bin/runeisa-mlton.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runeisa-mlton.bin" "$$@"\n' > $@
	chmod +x $@

bin/runeisa.rbc: bin/rune bin/rune.rbc build/config.sml $(SOURCES_ISA) src/main/runeisa-rune-main.sml
	$(RUNE) -o $@ build/config.sml $(SOURCES_ISA) src/main/runeisa-rune-main.sml

# ---------------------------------------------------------------- compiler
# The compiler has no built-in library path, so each bin/rune* is a wrapper
# that passes --lib; the payload of a host build sits next to it as .bin.
# A --lib of the caller's comes later on the command line and so wins.
mlton: bin/rune-mlton

smlnj: bin/rune-smlnj

smlnj32: bin/rune-smlnj32

polyml: bin/rune-polyml

host-builds: mlton smlnj smlnj32 polyml runedoc-host-builds runeopt-host-builds

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

# ---------------------------------------------------------------- runeopt
# The native code generator (docs/native.md): the sources of
# sources-opt.txt, built like runedoc by every host and by the compiler itself
# (bin/runeopt, on runevm). It reads no library; its wrappers pass instead the
# directory of the runtime a program is linked with (build/librune.a and
# build/rune-offsets.s). The SML/NJ builds come after runedoc's, for the same
# reason as runedoc's do.
runeopt-host-builds: bin/runeopt-mlton bin/runeopt-smlnj bin/runeopt-smlnj32 bin/runeopt-polyml

# The translations bin/runevm-opt keeps are by the checksum of the bytecode
# alone: a new runeopt or runtime empties them, or the suites would run the
# programs the old ones made.
bin/runeopt-mlton.bin: $(BUILDGEN) $(SOURCES_OPT) $(GEN_SML) src/main/runeopt-mlton-main.sml | build/.doctor-mlton build/librune.a
	@mkdir -p bin
	$(MLTON) -output $@ build/runeopt.mlb
	rm -rf tests/out/opt-cache tests/out/opt-cache-asan

bin/runeopt-mlton: bin/runeopt-mlton.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runeopt-mlton.bin" --runtime "$$d/../build" "$$@"\n' > $@
	chmod +x $@

bin/runeopt-smlnj: $(BUILDGEN) $(SOURCES_OPT) $(GEN_SML) Makefile | build/.doctor-smlnj bin/runedoc-smlnj32
	@mkdir -p bin
	$(MLBUILD) build/runeopt.cm OptMain.main bin/runeopt-smlnj.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/runeopt-smlnj.heap" --runtime "$$d/../build" "$$@"\n' "$(SMLNJ)" > $@
	chmod +x $@

bin/runeopt-smlnj32: $(BUILDGEN) $(SOURCES_OPT) $(GEN_SML) Makefile | build/.doctor-smlnj32 bin/runeopt-smlnj
	@mkdir -p bin
	$(MLBUILD32) build/runeopt.cm OptMain.main bin/runeopt-smlnj32.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/runeopt-smlnj32.heap" --runtime "$$d/../build" "$$@"\n' "$(SMLNJ32)" > $@
	chmod +x $@

bin/runeopt-polyml.bin: $(BUILDGEN) $(SOURCES_OPT) $(GEN_SML) src/main/runeopt-polyml-main.sml | build/.doctor-polyml
	@mkdir -p bin
	$(POLYC) -o $@ build/runeopt-polyml-build.sml

bin/runeopt-polyml: bin/runeopt-polyml.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runeopt-polyml.bin" --runtime "$$d/../build" "$$@"\n' > $@
	chmod +x $@

# ---------------------------------------------------------------- VM
vm: bin/runevm bin/runevm-new

build/librune/%.o: vm/%.c $(VM_HDRS) | build/.doctor-vm
	@mkdir -p build/librune
	$(CC) $(CFLAGS) -c -o $@ $<

# native.o is the main of a program runeopt makes and what its code calls
# (vm/native.c): it is in the library, but nothing of runevm refers to it,
# so no VM links it. rune-offsets.s is the layout of the VM for the code.
build/librune.a: $(RT_OBJS) build/librune/native.o build/rune-offsets.s
	rm -f $@
	$(AR) rcs $@ $(RT_OBJS) build/librune/native.o
	rm -rf tests/out/opt-cache

build/rune-offsets.s: vm/native_offsets.c $(VM_HDRS) | build/.doctor-vm
	@mkdir -p build/librune
	$(CC) $(CFLAGS) -o build/librune/native-offsets vm/native_offsets.c
	build/librune/native-offsets > $@

bin/runevm: vm/main.c vm/interp.c build/librune.a $(VM_HDRS) | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -o $@ vm/main.c vm/interp.c build/librune.a -lm

# vm/new's first loop (docs/plans/middle-end.md, M5): the register bytecode,
# on the runtime of runevm. Its own instruction set's part (vm/new/isa_regs.c)
# is linked before build/librune.a, whose vm/isa_stack.c it takes the place of.
NEW_HDRS := vm/new/regvm.h
bin/runevm-new: vm/main.c vm/new/interp.c vm/new/isa_regs.c build/librune.a $(VM_HDRS) $(NEW_HDRS) | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -Ivm -o $@ vm/main.c vm/new/interp.c vm/new/isa_regs.c build/librune.a -lm

vm-asan: bin/runevm-asan bin/runevm-new-asan

bin/runevm-asan: $(VM_SRCS) $(VM_HDRS) | build/.doctor-asan
	@mkdir -p bin
	$(CC) -std=c99 -g -O1 -Wall -Wextra -fsanitize=address,undefined -fno-omit-frame-pointer -o $@ $(VM_SRCS) -lm

# vm/new with the sanitizers: its loop, its instruction set's part, and the
# runtime but for the stack bytecode's part
NEW_SRCS := vm/main.c vm/new/interp.c vm/new/isa_regs.c $(filter-out vm/isa_stack.c,$(RT_SRCS)) vm/sys_$(SYS).c
bin/runevm-new-asan: $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) | build/.doctor-asan
	@mkdir -p bin
	$(CC) -std=c99 -g -O1 -Wall -Wextra -fsanitize=address,undefined -fno-omit-frame-pointer -Ivm -o $@ $(NEW_SRCS) -lm

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
# does not and why, and docs/runtime.md what a program can count on.
WINCC       ?= x86_64-w64-mingw32-gcc
WINCC32     ?= i686-w64-mingw32-gcc
WINCFLAGS   ?= -std=c99 -O2 -Wall -Wextra -D__USE_MINGW_ANSI_STDIO=1
WINCFLAGS32 ?= -msse2 -mfpmath=sse -Wl,--large-address-aware
WIN_SRCS    := vm/main.c vm/interp.c $(RT_SRCS) vm/sys_win.c
WIN_LIBS    := -lws2_32 -ladvapi32 -lshell32 -luser32

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

# ------------------------------------------------------------- portability
# The VM on machines this one is not: a 32-bit x86, where a pointer is four
# bytes, and a 64-bit PowerPC, where a number is the other way round. Both
# are Linux, so only the VM differs -- the bytecode is the same file -- and
# the point is what they do not share with the machine that built them: the
# width of a pointer, the alignment an ABI gives an int64_t, and the order of
# the bytes in a word. An image written by one is read by another, which is
# the strongest thing the format claims (vm/image.c).
#
# The 64-bit PowerPC VM is big-endian and runs under qemu; its compiler is
# clang, which cross-compiles without a gcc for the target, with the linker
# and headers of the sysroot the distribution's binutils and libc provide.
PORTCC32   ?= $(CC)
# -msse2 -mfpmath=sse for the same reason the 32-bit Windows VM has them: the
# x87 stack holds a double with more bits than a double has, so arithmetic that
# stays in a register rounds differently from arithmetic on any other machine.
# Without them `Real.round` of a number just below a half gives 1 here and 0
# everywhere else.
PORTFLAGS32 ?= -m32 -msse2 -mfpmath=sse
PPCCC      ?= clang
PPCROOT    ?= /usr/powerpc64-linux-gnu
# -rpath as well as -L: the sysroot's libraries are not on the loader's path,
# and the VM must be loadable however it is started -- by the wrapper, which
# gives qemu -L, and by the kernel through binfmt_misc, which gives it nothing
# (that is what a fork by a second VM needs; tests/portability-skip.txt).
PPCFLAGS   ?= --target=powerpc64-linux-gnu -B$(PPCROOT)/bin -L$(PPCROOT)/lib -I$(PPCROOT)/include \
              -Wl,-dynamic-linker,$(PPCROOT)/lib/ld64.so.1 -Wl,-rpath,$(PPCROOT)/lib
QEMUPPC    ?= qemu-ppc64
PORT_TIMEOUT ?= 900

portability: bin/runevm32 bin/runevm-ppc64

bin/runevm32: $(VM_SRCS) $(VM_HDRS) Makefile | build/.doctor-portability
	@mkdir -p bin
	$(PORTCC32) $(CFLAGS) $(PORTFLAGS32) -o $@ $(VM_SRCS) -lm

# As with the host builds of the compiler, the name is a wrapper and the
# payload sits beside it: every runner takes --vm bin/runevm-ppc64 and needs
# to know nothing of qemu.
bin/runevm-ppc64.bin: $(VM_SRCS) $(VM_HDRS) Makefile | build/.doctor-portability
	@mkdir -p bin
	$(PPCCC) $(CFLAGS) $(PPCFLAGS) -o $@ $(VM_SRCS) -lm

bin/runevm-ppc64: bin/runevm-ppc64.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec %s "$$d/runevm-ppc64.bin" "$$@"\n' '$(QEMUPPC) -L $(PPCROOT)' > $@
	chmod +x $@

# The PowerPC VM runs under an emulator and is about ten times slower, so the
# Basis suite gets longer than the two minutes a program is otherwise given:
# the largest of the monomorphic tests takes 34 s here and about six minutes
# there.
test-portability: portability $(RUNE) vm
	sh tests/run-portability.sh -j $(JOBS) --rune $(RUNE) --vm bin/runevm32 --vm bin/runevm-ppc64
	RUNE=$(abspath $(RUNE)) RUNE_MATRIX_TIMEOUT=$(PORT_TIMEOUT) \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs portability

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

# Every instruction says where it came from, and the line is one the file has.
# The intermediate representations (docs/ir.md): the dumps of tests/ir, and
# every program of tests/lang and tests/perf the same at -O0 and -O2 with the
# lint of every pass on (docs/plans/middle-end.md, M2).
test-ir: $(RUNE)
	sh tests/ir/run-ir-tests.sh --rune $(RUNE)

check-levels: $(RUNE) $(RUNEVM)
	sh scripts/check-levels.sh --rune $(RUNE) --vm $(RUNEVM) -j $(JOBS)

check-positions: $(RUNE) $(RUNEVM)
	sh scripts/check-positions.sh -j $(JOBS) --rune $(RUNE) --vm $(RUNEVM)

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

# The native code generator's own tests (tests/opt): after the suites, whose
# programs it checks and disassembles.
test-opt: $(RUNEOPT) $(RUNE) vm build/librune.a
	sh tests/opt/run-opt-tests.sh -j $(JOBS) --runeopt $(RUNEOPT) --rune $(RUNE) --vm $(RUNEVM)

perf-check: $(RUNE) bin/runedoc vm bin/rune.new.rbc bin/runedoc.new.rbc | build/.doctor-check
	RUNE=$(RUNE) RUNEVM=$(RUNEVM) sh tests/perf/run-perf.sh
	RUNE=$(RUNE) sh tests/perf/run-perf.sh --new

# Not part of `make check`: a collection before every allocation makes a few
# tests quadratic. For VM changes, next to `make vm-asan`.
# The Basis Library suite keeps vectors of 200000 elements alive, so it gets
# a longer interval and time limit (about 4 minutes).
# The tested programs run on the stressed VM; the compiler keeps the plain one
# (bin/rune names bin/runevm outright), or every compile would be quadratic too.
GC_STRESS ?= 101
GC_STRESS_BASIS ?= 1009
test-stress: $(RUNE) vm bin/rune-new | build/.doctor-check
	printf '#!/bin/sh\nexec "$(ROOT)/bin/runevm" --gc-stress "$${RUNE_GC_STRESS:-1}" "$$@"\n' > bin/runevm-stress
	chmod +x bin/runevm-stress
	printf '#!/bin/sh\nexec "$(ROOT)/bin/runevm-new" --gc-stress "$${RUNE_GC_STRESS:-1}" "$$@"\n' > bin/runevm-new-stress
	chmod +x bin/runevm-new-stress
	RUNE_GC_STRESS=$(GC_STRESS) sh tests/run-tests.sh -j $(JOBS) --rune $(RUNE) --vm bin/runevm-stress
	RUNE_GC_STRESS=$(GC_STRESS) sh tests/run-tests.sh -j $(JOBS) --rune bin/rune-new --vm bin/runevm-new-stress --out tests/out/new-stress
	RUNE_GC_STRESS=$(GC_STRESS_BASIS) RUNE_MATRIX_TIMEOUT=900 \
	  RUNE=$(abspath $(RUNE)) RUNEVM="$(ROOT)/bin/runevm-stress" \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs rune

# ------------------------------------------------------------- native code
# The suites with every program translated by runeopt and run as native
# code (docs/native.md, Tests). bin/runevm-opt takes what runevm takes and
# does so (scripts/runevm-opt.sh), keeping each translation by the checksum
# of its bytecode, so every runner takes it as --vm. test-native runs
# tests/lang (tests/opt-skip.txt lists what native code does not do yet, and
# why) and the Basis Library suite (the rune:opt configuration) that way,
# checks that every program of tests/lang counts what runevm counts, that
# the compiler, translated, compiles itself to bin/rune.rbc, and that the
# debug information of those programs and the compiler is their line table
# (tests/opt/run-debug.sh), and gdb and lldb stop where it says. Programs of
# runeopt are for Linux on x86-64: elsewhere it says so and does nothing.
NATIVE_HOST := $(shell [ "$$(uname -s) $$(uname -m)" = "Linux x86_64" ] && echo yes)

bin/runevm-opt: scripts/runevm-opt.sh
	@mkdir -p bin
	cp scripts/runevm-opt.sh $@
	chmod +x $@

ifeq ($(NATIVE_HOST),yes)
test-native: bin/runevm-opt bin/runeopt-mlton build/librune.a $(RUNE) vm | build/.doctor-native
	sh tests/run-tests.sh -j $(JOBS) --rune $(RUNE) --vm bin/runevm-opt --skip tests/opt-skip.txt
	sh tests/opt/run-counts.sh -j $(JOBS) $$(for t in tests/lang/*.sml; do echo tests/out/$$(basename $$t .sml).rbc; done)
	RUNE=$(abspath $(RUNE)) RUNE_MATRIX_BYTECODE="$(ROOT)/tests/out/matrix/rune" \
	  sh tests/basis/run-matrix.sh -j $(JOBS) --configs rune:opt
	RUNE_HEAP=$(RUNE_HEAP) sh tests/opt/run-bootstrap.sh
	@mkdir -p tests/out/opt-debug
	$(RUNE) examples/nqueens.sml -o tests/out/opt-debug/nqueens.rbc
	sh tests/opt/run-debug.sh -j $(JOBS) --debuggers tests/out/opt-debug/nqueens.rbc bin/rune.rbc \
	  $$(for t in tests/lang/*.sml; do echo tests/out/$$(basename $$t .sml).rbc; done)

# The native suite with a collection before every GC_STRESS-th allocation, which
# is what finds an address of the heap that the code keeps across a call; and
# with a runtime built with the address and undefined behaviour sanitizers.
# Neither is part of make check.
test-native-stress: bin/runevm-opt bin/runeopt-mlton build/librune.a $(RUNE) vm | build/.doctor-native
	printf '#!/bin/sh\nexec "$(ROOT)/bin/runevm-opt" --gc-stress "$${RUNE_GC_STRESS:-1}" "$$@"\n' > bin/runevm-opt-stress
	chmod +x bin/runevm-opt-stress
	RUNE_GC_STRESS=$(GC_STRESS) sh tests/run-tests.sh -j $(JOBS) --rune $(RUNE) --vm bin/runevm-opt-stress --skip tests/opt-skip.txt
	RUNE_GC_STRESS=$(GC_STRESS_BASIS) RUNE_MATRIX_TIMEOUT=900 RUNE=$(abspath $(RUNE)) \
	  RUNEVM_OPT="$(ROOT)/bin/runevm-opt-stress" sh tests/basis/run-matrix.sh -j $(JOBS) --configs rune:opt

ASAN_CFLAGS := -std=c99 -g -O1 -Wall -Wextra -fsanitize=address,undefined -fno-omit-frame-pointer

build/asan/librune.a: $(RT_SRCS) vm/sys_$(SYS).c vm/native.c build/rune-offsets.s $(VM_HDRS) | build/.doctor-asan
	@mkdir -p build/asan/obj
	for f in $(RT_SRCS) vm/sys_$(SYS).c vm/native.c; do \
	  $(CC) $(ASAN_CFLAGS) -c -o build/asan/obj/$$(basename $$f .c).o $$f || exit 1; done
	cp build/rune-offsets.s build/asan/rune-offsets.s
	rm -f $@
	$(AR) rcs $@ build/asan/obj/*.o
	rm -rf tests/out/opt-cache-asan

test-native-asan: bin/runevm-opt bin/runeopt-mlton build/asan/librune.a $(RUNE) vm | build/.doctor-native
	printf '#!/bin/sh\nexec $(CC) -fsanitize=address,undefined "$$@"\n' > build/asan/cc
	chmod +x build/asan/cc
	RUNEOPT_RUNTIME="$(ROOT)/build/asan" RUNEOPT_CC="$(ROOT)/build/asan/cc" RUNEOPT_CACHE="$(ROOT)/tests/out/opt-cache-asan" \
	  sh tests/run-tests.sh -j $(JOBS) --rune $(RUNE) --vm bin/runevm-opt --skip tests/opt-skip.txt
else
test-native test-native-stress test-native-asan:
	@echo "$@: runeopt makes programs for Linux on x86-64, and this is not one: nothing to test"
endif

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
	bin/rune-$(BOOTHOST) --lint --mid-roundtrip -o $@ $(BOOT_SRCS)

# bin/rune making the register bytecode of vm/new
bin/rune-new: bin/rune Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/rune" --target=registers "$$@"\n' > $@
	chmod +x $@

# The suites through vm/new's first loop (docs/plans/middle-end.md, M5): the
# tests of the language, allocation and the bootstrap against runevm, and
# the Basis Library.
test-new: bin/rune-new bin/runevm-new $(RUNE) vm
	sh tests/run-tests.sh -j $(JOBS) --rune bin/rune-new --vm bin/runevm-new --out tests/out/new
	sh scripts/check-new.sh -j $(JOBS)
	RUNE_NEW=$(abspath bin/rune-new) RUNEVM_NEW=$(abspath bin/runevm-new) sh tests/basis/run-matrix.sh -j $(JOBS) --configs rune:new

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

# The compiler and runedoc in the register bytecode, which vm/new's budgets
# measure (tests/perf/run-perf.sh --new).
bin/rune.new.rbc: bin/rune-$(BOOTHOST) $(BOOT_SRCS) lib/basis/MANIFEST $(wildcard lib/basis/*.sml)
	bin/rune-$(BOOTHOST) --target=registers -o $@ $(BOOT_SRCS)

bin/runedoc.new.rbc: bin/rune bin/rune.rbc $(DOC_SRCS)
	bin/rune --target=registers -o $@ $(DOC_SRCS)

bin/runedoc-boot: bin/runedoc.rbc Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" --heap-size $(RUNE_HEAP) "$$d/runedoc.rbc" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/runedoc: bin/runedoc-boot
	ln -sf runedoc-boot $@

runedoc: bin/runedoc

# runeopt compiled by the self-hosted compiler.
OPT_SRCS := build/config.sml $(SOURCES_OPT) src/main/runeopt-rune-main.sml

bin/runeopt.rbc: bin/rune bin/rune.rbc $(OPT_SRCS)
	bin/rune -o $@ $(OPT_SRCS)

bin/runeopt-boot: bin/runeopt.rbc Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" --heap-size $(RUNE_HEAP) "$$d/runeopt.rbc" --runtime "$$d/../build" "$$@"\n' > $@
	chmod +x $@
	rm -rf tests/out/opt-cache tests/out/opt-cache-asan

bin/runeopt: bin/runeopt-boot
	ln -sf runeopt-boot $@

runeopt: bin/runeopt

bootstrap: bin/rune-boot
	bin/rune-boot -o bin/rune.stage2.rbc $(BOOT_SRCS)
	cmp bin/rune.rbc bin/rune.stage2.rbc
	@echo "bootstrap: bin/rune.rbc reproduces itself"

# Steps run one after another: the suite runs share tests/out, and each step
# keeps JOBS CPUs busy by itself. bootstrap is a single process, so it runs
# alongside the suite.
check:
	@$(MAKE) --no-print-directory host-builds vm boot runedoc runeopt
	@$(MAKE) --no-print-directory test bootstrap
	@$(MAKE) --no-print-directory test-doc
	@$(MAKE) --no-print-directory test-all
	@$(MAKE) --no-print-directory test-basis
	@$(MAKE) --no-print-directory test-opt
	@$(MAKE) --no-print-directory test-ir check-levels
	@$(MAKE) --no-print-directory test-native
	@$(MAKE) --no-print-directory test-new
	@$(MAKE) --no-print-directory perf-check
	@$(MAKE) --no-print-directory check-positions
	@$(MAKE) --no-print-directory check-cross check-docs check-isa

clean:
	rm -rf bin build tests/out
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
	  $(MAKE) --no-print-directory $(if $(HOST),vm $(HOST) $(if $(filter smlnj,$(HOST)),bin/runedoc-smlnj bin/runeopt-smlnj,bin/runedoc-$(HOST) bin/runeopt-$(HOST)) build/librune.a,all); \
	fi
	RUNE_HEAP=$(RUNE_HEAP) SMLNJ=$(SMLNJ) sh scripts/install.sh $(INSTALL_FLAGS)

uninstall:
	sh scripts/install.sh --uninstall $(INSTALL_FLAGS)
