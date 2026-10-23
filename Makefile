# Rune: Standard ML '97 to bytecode compiler + portable C VM.
#
#   make hosts      install the SML systems Rune is built and compared with
#                   (MLton, SML/NJ 110.99.9 in 64 and 32 bits, SML/NJ 2026.2,
#                   Poly/ML, MLKit) under ~/.local/rune-hosts; needed once,
#                   before anything else
#   make            build bin/rune (the self-hosted compiler), bin/runevm, bin/runevm-stack, and
#                   bin/runedoc and bin/runeopt, which the compiler compiles
#   make mlton|smlnj-legacy|smlnj32|smlnj-dev|polyml|mlkit   build the compiler with one of them
#   make host-builds  build the compiler with all six
#   make vm         build bin/runevm (runtime/register, the register bytecode's VM) and bin/runevm-stack
#   make boot       bin/rune.rbc (the compiler compiled by bin/rune-$(BOOTHOST)),
#                   the bin/rune-boot wrapper that runs it on runevm, and bin/rune -> it; bin/rune.stack.rbc is the stack bytecode of the same
#   make test       run the test suite with bin/rune
#   make install    install rune, runevm, runevm-stack, runedoc, runeopt and the basis library under PREFIX
#                   (/usr/local as root, ~/.local otherwise); as root nothing
#                   is built, so run `make` as yourself first
#   make uninstall  remove them again
#   make dist       write dist/rune-<version>-linux.tar.gz and
#                   dist/rune-<version>-windows.zip
#   make test-all   run the suite with each of the five host builds
#   make check-cross  verify all six builds emit byte-identical bytecode
#   make check-positions  verify every instruction names a line that exists
#   make check-docs verify docs/language.md, tests and .def files are in sync
#   make test-basis run the Basis Library suite (tests/basis) with bin/rune
#   make perf-check verify the instruction and allocation budgets (tests/perf)
#   make test-stress  both suites with a collection before every GC_STRESS-th
#                   (101; Basis Library suite: GC_STRESS_BASIS-th, 1009) allocation:
#                   the interpreters with no nursery, the JIT with one of 4 KiB
#   make bootstrap  verify that the self-hosted compiler reproduces bin/rune.rbc
#   make check      everything above
#   make doctor     check that the tools all targets need are installed
#   make envcheck   report on the machine: CPU, instruction set, cores and
#                   neighbours, memory, disk and network (docs/envcheck.md);
#                   ENVCHECK=--slow for steadier figures, --commit-test to
#                   find how much memory can be used (it may be killed)
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
#   make test-register   the suites through runtime/register's first loop and the register
#                   bytecode (docs/bytecode.md); part of make check
#
# bin/rune is the compiler Rune ships: itself, on the VM. The host builds
# bin/rune-mlton, bin/rune-smlnj-legacy, bin/rune-smlnj32, bin/rune-smlnj-dev,
# bin/rune-polyml and bin/rune-mlkit exist to bootstrap it and to check that
# all seven agree (check-cross). Every target that runs the compiler uses
# $(RUNE), so `make test RUNE=bin/rune-mlton` is the fast loop.
# `make BOOTHOST=smlnj-legacy` bootstraps with another host.
#
# The SML systems are the releases scripts/fetch-hosts.sh installs under
# $(HOSTS), never ones the machine has on its PATH: MLTON, MLBUILD, SMLNJ,
# MLBUILD32, SMLNJ32, MLBUILD_DEV, SMLNJ_DEV, POLYC and MLKIT name their
# commands (MLKIT_LIB its library, which it is given as SML_LIB).
#
# The build and test targets check their own tools once before they first run
# (scripts/doctor.sh); `make DOCTOR=no ...` skips that.
#
# Recipes and test programs run in parallel on all available CPUs;
# `make JOBS=N ...` uses N instead.

SHELL   := /bin/sh
.DEFAULT_GOAL := all
ifndef JOBS
JOBS    := $(shell sh scripts/ncpus.sh)
endif
ifeq ($(MAKELEVEL),0)
MAKEFLAGS += -j$(JOBS)
endif
CC      ?= cc
CFLAGS  ?= -std=c17 -O2 -Wall -Wextra -pedantic
# Every C file of runtime/ names a header of another folder by its path from
# runtime/ (sys/sys.h, register/jit.h): the one include path of every build.
RT_INC  := -Iruntime
ROOT    := $(CURDIR)

# The compiler and VM the test targets run. Override to test another build:
# `make test RUNE=bin/rune-mlton`.
RUNE    ?= bin/rune
# $(RUNE) pinned to the stack bytecode, which the suites that run bin/runevm-stack
# need: the compiler makes the register bytecode of bin/runevm unless
# told otherwise. It is written whenever make reads this file, and renamed
# into place, since the steps of make check that run at once each read
# this file while the others' tests run it.
RUNE_STACK := bin/rune-stack
$(shell mkdir -p bin && printf '#!/bin/sh\nexec "%s" --target=stack "$$@"\n' '$(abspath $(RUNE))' > $(RUNE_STACK).$$$$ && chmod +x $(RUNE_STACK).$$$$ && mv -f $(RUNE_STACK).$$$$ $(RUNE_STACK))
RUNEVM  ?= bin/runevm-stack
# The register VM with its JIT, which runs what $(RUNE) makes: the default for
# the suites of the libraries, the examples and the laws (the owner,
# 2026-10-09). The stack VM is what they are compared with: run a suite's
# script with RUNE=bin/rune-stack RUNEVM=bin/runevm-stack.
RUNEVM_REGISTER ?= bin/runevm
RUNEDOC ?= bin/runedoc
RUNEOPT ?= bin/runeopt

SOURCES  := $(shell sh scripts/build-files.sh rune.build)
GEN_SML  := src/backend/opcodes.sml src/backend/prims.sml src/backend/regcodes.sml
GEN_C    := runtime/isa.h runtime/stack/opcodes.h runtime/prims_table.h runtime/stack/interp_cases.h runtime/stack/interp_labels.h runtime/stack/ops.h runtime/register/regops.h runtime/register/reg_cases.h
SOURCES_DOC := $(shell sh scripts/build-files.sh runedoc.build)
SOURCES_OPT := $(shell sh scripts/build-files.sh runeopt.build)
SOURCES_ISA := $(shell sh scripts/build-files.sh runeisa.build)
BUILDFILES := build/rune.mlb build/rune.cm build/polyml-build.sml build/rune-mlkit.mlb build/runedoc.mlb build/runedoc.cm build/runedoc-polyml-build.sml build/runedoc-mlkit.mlb build/runeopt.mlb build/runeopt.cm build/runeopt-polyml-build.sml build/runeopt-mlkit.mlb build/runeisa.mlb build/runeisa.cm build/runeisa-polyml-build.sml build/runeisa-mlkit.mlb
VERSIONGEN := build/config.sml runtime/version.h
BUILDGEN := $(BUILDFILES) $(VERSIONGEN)

# The core VM is ISO C99; what needs the operating system is in runtime/sys/sys.h and
# one of its implementations. `make SYS=none` builds without POSIX, and the
# library then reports ENOSYS for what it cannot do.
#
# A VM is the runtime, RT_SRCS and a system layer, with the dispatch loop and
# the command line on top (runtime/stack/interp.c, runtime/main.c). The runtime is also
# build/librune.a, which bin/runevm-stack links, and so will a program runeopt
# makes (docs/native.md); the other VMs compile the same list.
#
# Under MSYS2 the compiler of a MinGW environment (UCRT64, MINGW64,
# CLANG64) makes programs of Windows, so the VMs are built there as `make
# windows` builds them: with the system layer of Windows, mingw-w64's printf
# and the libraries of Windows that layer calls (docs/building.md, MSYS2).
MINGW   := $(if $(filter MINGW%,$(shell uname -s)),yes)
ifeq ($(MINGW),yes)
SYS     ?= win
CFLAGS  += -D__USE_MINGW_ANSI_STDIO=1
endif
SYS ?= posix
# what a VM links beside the runtime
VM_LIBS  = -lm $(if $(MINGW),$(WIN_LIBS)) $(FFI_LIBS)
# libffi is optional. Native flags never enter another target's compile.
# Cross builds use explicit target prefixes or deterministic ENOSYS stubs.
FFI ?= auto
ifeq ($(filter $(FFI),auto yes no),)
$(error FFI must be auto, yes or no)
endif
FFI_FOUND := $(shell pkg-config --exists libffi 2>/dev/null && echo yes)
FFI_ENABLED := $(if $(filter no,$(FFI)),0,$(if $(filter none,$(SYS)),0,$(if $(filter yes,$(FFI_FOUND)),1,0)))
ifeq ($(FFI),yes)
ifneq ($(FFI_ENABLED),1)
$(error FFI=yes requires libffi headers and pkg-config on this target)
endif
endif
FFI_FLAGS := -DRUNE_FFI=$(FFI_ENABLED) $(if $(filter 1,$(FFI_ENABLED)),$(shell pkg-config --cflags libffi))
FFI_LIBS := $(if $(filter 1,$(FFI_ENABLED)),$(shell pkg-config --libs libffi) $(if $(filter posix,$(SYS)),-ldl))
RT_SRCS := runtime/foreign.c runtime/intinf.c runtime/runtime.c runtime/heap.c runtime/gc/chunk.c runtime/gc/copy.c runtime/gc/minor.c runtime/gc/los.c runtime/gc/mark.c runtime/gc/immix.c runtime/gc/segfit.c runtime/gc/compact.c runtime/gc/cycle.c runtime/gc/check.c runtime/gc/log.c runtime/gc/share.c runtime/loader.c runtime/debug.c runtime/stack/isa_stack.c runtime/prims.c runtime/image.c
VM_SRCS := runtime/main.c runtime/stack/interp.c $(RT_SRCS) runtime/sys/sys_$(SYS).c
VM_HDRS := runtime/foreign.h runtime/foreign_prim.h runtime/intinf.h runtime/vm.h runtime/frames_array.inc runtime/value.h runtime/gc/gc.h runtime/native/native_offsets.h runtime/stack/loop.h runtime/sys/sys.h runtime/version.h $(GEN_C)
RT_OBJS := $(patsubst runtime/%.c,build/librune/%.o,$(RT_SRCS) runtime/sys/sys_$(SYS).c)
AR      ?= ar

# Bootstrap build policy is Standard ML, compiled by the installed native host.
# This graph is deliberately independent of every Rune VM/compiler/GMP target.
BUILDER_LIB_SRCS := lib/unicode/utf8_sig.sml lib/unicode/utf8.sml lib/json/json_sig.sml lib/json/json.sml \
                    lib/digest/digest_sig.sml lib/digest/sha256.sml lib/digest/hex_sig.sml lib/digest/hex.sml
BUILDER_MODEL_SRCS := tools/builder/common.sml tools/builder/options.sml tools/builder/runtime-inputs.sml \
                    tools/builder/gmp-config.sml tools/builder/runtime-record.sml tools/builder/cross-vm.sml \
                    tools/builder/formats.sml tools/builder/archive.sml tools/builder/dist.sml \
                    tools/builder/gmp-build.sml tools/builder/relink.sml tools/builder/package-runtime.sml \
                    tools/builder/setup-mlton.sml
BUILDER_NATIVE_SRCS := $(BUILDER_LIB_SRCS) tools/builder/io.sig tools/builder/native-io.sml $(BUILDER_MODEL_SRCS) tools/builder/main.sml
bin/rune-build.bin: $(BUILDER_NATIVE_SRCS) tools/builder/native.mlb | build/.doctor-mlton
	@mkdir -p bin
	$(MLTON) -output $@ tools/builder/native.mlb
bin/rune-build: bin/rune-build.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_BUILD_ROOT:-}" ]; then RUNE_BUILD_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_BUILD_ROOT; fi\nexec "$$d/rune-build.bin" "$$@"\n' > $@
	chmod +x $@

# Optional arithmetic is linked ahead of the GMP-free archive. Stack/native
# programs keep the archive's SML-only implementation and the same primitives.
GMP ?= auto
GMP_PREFIX ?=
GMP_KEY := $(shell printf '%s\n' '$(GMP)' '$(GMP_PREFIX)' '$(CC)' '$(CFLAGS)' | cksum | cut -d' ' -f1)
GMP_DIR := build/gmp/$(GMP_KEY)
$(GMP_DIR)/config.mk: bin/rune-build $(if $(GMP_PREFIX),$(wildcard $(GMP_PREFIX)/include/gmp.h $(GMP_PREFIX)/lib/libgmp.a $(GMP_PREFIX)/rune-gmp.json))
	bin/rune-build configure-gmp --mode '$(GMP)' --prefix '$(GMP_PREFIX)' --cc '$(CC)' --cflags '$(CFLAGS)' --out $(GMP_DIR)
# Pre-host provisioning and the independent native tool cannot depend on
# target configuration. Explicit dependency provisioning likewise precedes it.
GMP_CONFIG_GOALS := $(if $(MAKECMDGOALS),$(filter-out hosts doctor envcheck clean gmp-dep gmp-dep-windows gmp-dep-portability gmp-dep-dist-native bin/rune-build bin/rune-build.bin,$(MAKECMDGOALS)),all)
ifneq ($(strip $(GMP_CONFIG_GOALS)),)
include $(GMP_DIR)/config.mk
endif
GMP_FLAGS = $(GMP_CPPFLAGS) -include $(GMP_DIR)/config.h
.PHONY: gmp-force gmp-dep
gmp-force:
# Remade by every make, and the runner starts several at once in one tree:
# each writes a temporary file of its own (the shell's PID; one recipe line,
# so one shell) and renames it over the old one only where it differs.
build/gmp/selected: gmp-force
	@mkdir -p build/gmp
	@t=$@.tmp.$$$$; printf '%s\n' '$(GMP_KEY)' > $$t && { cmp -s $$t $@ && rm -f $$t || mv -f $$t $@; }
gmp-dep: bin/rune-build
	bin/rune-build build-gmp $(if $(filter x86_64 i686 i386,$(shell uname -m)),--enable-fat) --jobs $(JOBS)
$(GMP_DIR)/intinf.o: runtime/intinf.c $(VM_HDRS) $(GMP_DIR)/config.mk
	$(CC) $(CFLAGS) $(RT_INC) $(GMP_FLAGS) -c -o $@ runtime/intinf.c

# The host SML systems (`make hosts`).
HOSTS     ?= $(or $(RUNE_HOSTS),$(HOME)/.local/rune-hosts)
MLTON     ?= $(HOSTS)/mlton/bin/mlton
MLBUILD   ?= $(HOSTS)/smlnj-legacy/bin/ml-build
SMLNJ     ?= $(HOSTS)/smlnj-legacy/bin/sml
MLBUILD32 ?= $(HOSTS)/smlnj32/bin/ml-build
SMLNJ32   ?= $(HOSTS)/smlnj32/bin/sml
MLBUILD_DEV ?= $(HOSTS)/smlnj-dev/bin/ml-build
SMLNJ_DEV ?= $(HOSTS)/smlnj-dev/bin/sml
POLYC     ?= $(HOSTS)/polyml/bin/polyc
MLKIT     ?= $(HOSTS)/mlkit/bin/mlkit
MLKIT_LIB ?= $(HOSTS)/mlkit/lib/mlkit
export RUNE_HOSTS := $(HOSTS)
export MLTON SMLNJ SMLNJ32 SMLNJ_DEV POLYC MLKIT MLKIT_LIB
# What the tests compare must not depend on colour forced from outside
# (docs/diagnostics.md).
unexport FORCE_COLOR CLICOLOR_FORCE

# Sources of the compiler as compiled by itself, the host build that compiles
# stage 1, and the initial semispace of the VM that bin/rune runs on. The heap
# grows on demand; this only sets how much is mapped up front (measured: 32 MiB
# to 256 MiB are within 3% of each other on the bootstrap, and the smaller
# sizes keep the resident set of JOBS parallel compilers down).
BOOT_SRCS := build/config.sml $(SOURCES) src/main/rune-main.sml
BOOTHOST ?= mlton
RUNE_HEAP ?= 67108864
# what every rune wrapper does first: `rune -i ARGS` is the REPL beside it,
# bin/rune-repl (docs/repl.md), with ARGS
RUNE_I = [ "$$1" = -i ] && shift && exec "$$d/rune-repl" "$$@"\n

.PHONY: check-docs-generated test-mutants manifests isa check-isa test-ir check-levels check-units test-incremental test-deps test-dynamic test-build test-install test-dist check-reproducible test-serve basis-cache repl test-repl test-terminal test-diagnostics test-repl-protocol kernel test-kernel dap test-dap test-register test-register-jit test-register-asan vm-census test-census test-gc heapsim check-heapsim check-gcsim check-layouts gcbench check-gcbench templates check-templates mlkit windows test-windows portability test-portability docs test-doc test-lib test-lib-hosts test-laws runeopt runeopt-host-builds test-opt test-native test-native-stress test-native-asan all mlton smlnj-legacy smlnj32 smlnj-dev polyml host-builds runedoc runedoc-host-builds vm vm-asan gen test test-all check-cross check-positions check-docs boot bootstrap check check-tools quick check-units-steps test-steps test-heap-steps test-native-steps test-register-jit-steps clean doctor envcheck test-basis perf-check test-stress hosts matrix-quick matrix perf install uninstall dist test-int64 test-laws-hosts

all: vm boot runedoc runeopt manifests basis-cache

# The MANIFEST of each library (BasisManifest; docs/build.md), what each of
# its files provides and requires, made from the library's build file and
# its sources by the first host's compiler, which builds before any rune
# (rune --basis-index)
# the libraries of docs/plans/repl.md (The libraries)
REPL_LIBS := unicode json terminal digest jsonrpc dap pretty markdown zmtp jupyter
manifests: lib/basis/MANIFEST lib/random/MANIFEST lib/test/property/MANIFEST lib/test/property/basis/MANIFEST lib/test/unit/MANIFEST lib/test/runner/MANIFEST lib/language/c/MANIFEST lib/ffi/model/MANIFEST lib/ffi/marshal/MANIFEST lib/ffi/runtime/MANIFEST $(foreach l,$(REPL_LIBS),lib/$(l)/MANIFEST)
lib/basis/MANIFEST: lib/basis/library.build $(wildcard lib/basis/*.sml) bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/basis
lib/random/MANIFEST: lib/random/library.build $(wildcard lib/random/*.sml) lib/basis/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/random
lib/test/property/MANIFEST: lib/test/property/library.build $(wildcard lib/test/property/*.sml) lib/random/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/test/property
lib/test/property/basis/MANIFEST: lib/test/property/basis/library.build $(wildcard lib/test/property/basis/*.sml lib/test/property/basis/*/*.sml) lib/test/property/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/test/property/basis
# the unit-testing library (docs/plans/unit-testing.md, M1), written on test/property
lib/test/unit/MANIFEST: lib/test/unit/library.build $(wildcard lib/test/unit/*.sml) lib/test/property/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/test/unit
# the runner (docs/plans/unit-testing.md, M3), written on test/unit and terminal
lib/test/runner/MANIFEST: lib/test/runner/library.build $(wildcard lib/test/runner/*.sml) lib/test/unit/MANIFEST lib/terminal/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/test/runner
# the libraries of docs/plans/repl.md (The libraries), each after those it
# is written on
lib/unicode/MANIFEST: lib/unicode/library.build $(wildcard lib/unicode/*.sml) lib/basis/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/unicode
lib/json/MANIFEST: lib/json/library.build $(wildcard lib/json/*.sml) lib/basis/MANIFEST lib/unicode/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/json
lib/language/c/MANIFEST: lib/language/c/library.build $(wildcard lib/language/c/*.sml) lib/basis/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/language/c
lib/terminal/MANIFEST: lib/terminal/library.build $(wildcard lib/terminal/*.sml) lib/basis/MANIFEST lib/unicode/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/terminal
lib/pretty/MANIFEST: lib/pretty/library.build $(wildcard lib/pretty/*.sml) lib/basis/MANIFEST lib/unicode/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/pretty
lib/markdown/MANIFEST: lib/markdown/library.build $(wildcard lib/markdown/*.sml) lib/basis/MANIFEST lib/pretty/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/markdown
lib/digest/MANIFEST: lib/digest/library.build $(wildcard lib/digest/*.sml) lib/basis/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/digest
lib/jsonrpc/MANIFEST: lib/jsonrpc/library.build $(wildcard lib/jsonrpc/*.sml) lib/basis/MANIFEST lib/json/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/jsonrpc
lib/dap/MANIFEST: lib/dap/library.build $(wildcard lib/dap/*.sml) lib/basis/MANIFEST lib/jsonrpc/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/dap
lib/zmtp/MANIFEST: lib/zmtp/library.build $(wildcard lib/zmtp/*.sml) lib/basis/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/zmtp
lib/jupyter/MANIFEST: lib/jupyter/library.build $(wildcard lib/jupyter/*.sml) lib/basis/MANIFEST lib/zmtp/MANIFEST lib/json/MANIFEST lib/digest/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/jupyter

lib/ffi/model/MANIFEST: lib/ffi/model/library.build $(wildcard lib/ffi/model/*.sml) lib/json/MANIFEST lib/language/c/MANIFEST lib/basis/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/ffi/model
lib/ffi/marshal/MANIFEST: lib/ffi/marshal/library.build $(wildcard lib/ffi/marshal/*.sml) lib/unicode/MANIFEST lib/basis/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/ffi/marshal
lib/ffi/runtime/MANIFEST: lib/ffi/runtime/library.build $(wildcard lib/ffi/runtime/*.sml) lib/ffi/marshal/MANIFEST lib/basis/MANIFEST bin/rune-$(BOOTHOST)
	bin/rune-$(BOOTHOST) --basis-index lib/ffi/runtime

# The frozen Basis Library (docs/units.md, The cache): every unit of
# lib/basis compiled once, for each bytecode, into lib/cache, which every
# compile in units reads after its own cache and never writes; made again,
# empty first, when the compiler or the library changes
basis-cache: lib/cache/made
lib/cache/made: bin/rune bin/rune.rbc bin/runevm $(wildcard lib/basis/*.sml) lib/basis/MANIFEST
	rm -rf lib/cache
	bin/rune --units --basis all --cache-dir lib/cache examples/hello.sml -o build/basis-cache.rbc
	bin/rune --units --basis all --target=stack --cache-dir lib/cache examples/hello.sml -o build/basis-cache.stack.rbc
	touch $@

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

# ENVCHECK passes options to scripts/envcheck.sh: --slow, --commit-test,
# --json FILE, --markdown.
envcheck:
	@sh scripts/envcheck.sh $(ENVCHECK)

build/.doctor-%: scripts/doctor.sh
	@mkdir -p build
	@[ "$(DOCTOR)" = no ] || { CC="$(CC)" WINCC="$(WINCC)" WINCC32="$(WINCC32)" sh scripts/doctor.sh --quiet --scope $* && touch $@; }

# ---------------------------------------------------------------- generated
gen: $(BUILDGEN)

$(BUILDFILES) &: rune.build runedoc.build runeopt.build runeisa.build scripts/build-files.sh scripts/gen-build-files.sh
	sh scripts/gen-build-files.sh "$(ROOT)"

# The version is git's (scripts/gen-version.sh): asked on every make, and
# written only when it changes, so that a new commit, a checkout or the first
# edit of a clean tree rebuilds what says it and nothing else does.
$(VERSIONGEN) &: FORCE
	@sh scripts/gen-version.sh "$(ROOT)"

.PHONY: FORCE
FORCE:

# The instruction sets are described in src/isa (docs/plans/middle-end.md,
# M1); runeisa writes from them the tables of the VM and the compiler and
# the .def files the scripts read, $(ISA_OUT). They are committed, so that
# the VM builds with a C compiler alone: `make isa` writes them again after
# a change to src/isa, and `make check-isa` (part of make check) fails when
# one of them is not what the descriptions give, with runeisa built by
# MLton and by the self-hosted compiler.
ISA_OUT := runtime/stack/opcodes.def runtime/prims.def $(GEN_C) $(GEN_SML)

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
	$(RUNE_STACK) -o $@ build/config.sml $(SOURCES_ISA) src/main/runeisa-rune-main.sml

# ---------------------------------------------------------------- compiler
# The compiler has no built-in library path, so each bin/rune* is a wrapper
# that passes --lib; the payload of a host build sits next to it as .bin.
# A --lib of the caller's comes later on the command line and so wins.
mlton: bin/rune-mlton

smlnj-legacy: bin/rune-smlnj-legacy

smlnj32: bin/rune-smlnj32

smlnj-dev: bin/rune-smlnj-dev

polyml: bin/rune-polyml

mlkit: bin/rune-mlkit

host-builds: mlton smlnj-legacy smlnj32 smlnj-dev polyml mlkit runedoc-host-builds runeopt-host-builds

bin/rune-mlton.bin: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/mlton-main.sml | build/.doctor-mlton
	@mkdir -p bin
	$(MLTON) -output $@ build/rune.mlb

bin/rune-mlton: bin/rune-mlton.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\n$(RUNE_I)exec "$$d/rune-mlton.bin" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/rune-smlnj-legacy: $(BUILDGEN) $(SOURCES) $(GEN_SML) Makefile | build/.doctor-smlnj-legacy
	@mkdir -p bin
	$(MLBUILD) build/rune.cm Main.main bin/rune-smlnj-legacy.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\n$(RUNE_I)exec "%s" @SMLload="$$d/rune-smlnj-legacy.heap" --lib "$$d/../lib" "$$@"\n' "$(SMLNJ)" > $@
	chmod +x $@

# The 32-bit SML/NJ (31-bit int and word) catches code that depends on the
# width of int. After the 64-bit build: CM keeps both in the same .cm
# directories.
bin/rune-smlnj32: $(BUILDGEN) $(SOURCES) $(GEN_SML) Makefile | build/.doctor-smlnj32 bin/rune-smlnj-legacy
	@mkdir -p bin
	$(MLBUILD32) build/rune.cm Main.main bin/rune-smlnj32.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\n$(RUNE_I)exec "%s" @SMLload="$$d/rune-smlnj32.heap" --lib "$$d/../lib" "$$@"\n' "$(SMLNJ32)" > $@
	chmod +x $@

# 2026.2 writes CM metadata in .cm, as 110.99.9 does, and that name is fixed
# in its heap. The group it compiles is a copy under build/smlnj-dev-root
# whose sources are symlinks, so the binfiles are not the legacy compilers'.
# The three dev artifacts share that tree and so come one after another.
bin/rune-smlnj-dev: $(BUILDGEN) $(SOURCES) $(GEN_SML) Makefile | build/.doctor-smlnj-dev
	@mkdir -p bin
	cm=$$(sh scripts/smlnj-dev-root.sh build/rune.cm); \
	  $(MLBUILD_DEV) "$$cm" Main.main bin/rune-smlnj-dev.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\n$(RUNE_I)exec "%s" @SMLload="$$d/rune-smlnj-dev.heap" --lib "$$d/../lib" "$$@"\n' "$(SMLNJ_DEV)" > $@
	chmod +x $@

# Poly/ML's programs start with a heap of POLYML_HEAP megabytes (-H): at
# Poly/ML's own initial size its collector takes most of the compiler's time,
# the more so the larger the program (the compiler compiling itself: 22G
# instructions with one collector thread, 3.6G with -H 1024, as many as
# MLton's build; docs/plans/performance.md, M1). The heap still grows
# beyond it, and only what is used is resident.
POLYML_HEAP ?= 1024

bin/rune-polyml.bin: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/polyml-main.sml | build/.doctor-polyml
	@mkdir -p bin
	$(POLYC) -o $@ build/polyml-build.sml

bin/rune-polyml: bin/rune-polyml.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\n$(RUNE_I)exec "$$d/rune-polyml.bin" -H $(POLYML_HEAP) --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

# MLKit finds its library through SML_LIB and keeps its object files in MLB/
# beside every source and in the directory it runs from, so its builds of the
# compiler, runedoc and runeopt come one after another, as SML/NJ's do.
MLKIT_BUILD = SML_LIB=$(MLKIT_LIB) $(MLKIT) -j $(JOBS)

bin/rune-mlkit.bin: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/mlkit-main.sml | build/.doctor-mlkit
	@mkdir -p bin
	$(MLKIT_BUILD) -o $@ build/rune-mlkit.mlb

bin/rune-mlkit: bin/rune-mlkit.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\n$(RUNE_I)exec "$$d/rune-mlkit.bin" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

# ---------------------------------------------------------------- runedoc
# The documentation generator (docs/plans/docgen.md): the sources of
# runedoc.build, built like the compiler by every host and by the compiler
# itself (bin/runedoc, on runevm). The SML/NJ builds come one after another
# and after the compiler's: CM keeps them all in the same .cm directories.
runedoc-host-builds: bin/runedoc-mlton bin/runedoc-smlnj-legacy bin/runedoc-smlnj32 bin/runedoc-smlnj-dev bin/runedoc-polyml bin/runedoc-mlkit

bin/runedoc-mlton.bin: $(BUILDGEN) $(SOURCES_DOC) $(GEN_SML) src/main/runedoc-mlton-main.sml | build/.doctor-mlton
	@mkdir -p bin
	$(MLTON) -output $@ build/runedoc.mlb

bin/runedoc-mlton: bin/runedoc-mlton.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runedoc-mlton.bin" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/runedoc-smlnj-legacy: $(BUILDGEN) $(SOURCES_DOC) $(GEN_SML) Makefile | build/.doctor-smlnj-legacy bin/rune-smlnj32
	@mkdir -p bin
	$(MLBUILD) build/runedoc.cm DocMain.main bin/runedoc-smlnj-legacy.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/runedoc-smlnj-legacy.heap" --lib "$$d/../lib" "$$@"\n' "$(SMLNJ)" > $@
	chmod +x $@

bin/runedoc-smlnj32: $(BUILDGEN) $(SOURCES_DOC) $(GEN_SML) Makefile | build/.doctor-smlnj32 bin/runedoc-smlnj-legacy
	@mkdir -p bin
	$(MLBUILD32) build/runedoc.cm DocMain.main bin/runedoc-smlnj32.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/runedoc-smlnj32.heap" --lib "$$d/../lib" "$$@"\n' "$(SMLNJ32)" > $@
	chmod +x $@

bin/runedoc-smlnj-dev: $(BUILDGEN) $(SOURCES_DOC) $(GEN_SML) Makefile | build/.doctor-smlnj-dev bin/rune-smlnj-dev
	@mkdir -p bin
	cm=$$(sh scripts/smlnj-dev-root.sh build/runedoc.cm); \
	  $(MLBUILD_DEV) "$$cm" DocMain.main bin/runedoc-smlnj-dev.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/runedoc-smlnj-dev.heap" --lib "$$d/../lib" "$$@"\n' "$(SMLNJ_DEV)" > $@
	chmod +x $@

bin/runedoc-polyml.bin: $(BUILDGEN) $(SOURCES_DOC) $(GEN_SML) src/main/runedoc-polyml-main.sml | build/.doctor-polyml
	@mkdir -p bin
	$(POLYC) -o $@ build/runedoc-polyml-build.sml

bin/runedoc-polyml: bin/runedoc-polyml.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runedoc-polyml.bin" -H $(POLYML_HEAP) --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/runedoc-mlkit.bin: $(BUILDGEN) $(SOURCES_DOC) $(GEN_SML) src/main/runedoc-mlkit-main.sml | build/.doctor-mlkit bin/rune-mlkit.bin
	@mkdir -p bin
	$(MLKIT_BUILD) -o $@ build/runedoc-mlkit.mlb

bin/runedoc-mlkit: bin/runedoc-mlkit.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runedoc-mlkit.bin" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

# ---------------------------------------------------------------- runeopt
# The native code generator (docs/native.md): the sources of
# runeopt.build, built like runedoc by every host and by the compiler itself
# (bin/runeopt, on runevm). It reads no library; its wrappers pass instead the
# directory of the runtime a program is linked with (build/librune.a and
# build/rune-offsets.s). The SML/NJ builds come after runedoc's, for the same
# reason as runedoc's do.
runeopt-host-builds: bin/runeopt-mlton bin/runeopt-smlnj-legacy bin/runeopt-smlnj32 bin/runeopt-smlnj-dev bin/runeopt-polyml bin/runeopt-mlkit

# The translations bin/runevm-native keeps are by the checksum of the bytecode
# alone: a new runeopt or runtime empties them, or the suites would run the
# programs the old ones made.
bin/runeopt-mlton.bin: $(BUILDGEN) $(SOURCES_OPT) $(GEN_SML) src/main/runeopt-mlton-main.sml | build/.doctor-mlton build/librune.a
	@mkdir -p bin
	$(MLTON) -output $@ build/runeopt.mlb
	rm -rf tests/out/opt-cache tests/out/opt-cache-asan

bin/runeopt-mlton: bin/runeopt-mlton.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runeopt-mlton.bin" --runtime "$$d/../build" "$$@"\n' > $@
	chmod +x $@

bin/runeopt-smlnj-legacy: $(BUILDGEN) $(SOURCES_OPT) $(GEN_SML) Makefile | build/.doctor-smlnj-legacy bin/runedoc-smlnj32
	@mkdir -p bin
	$(MLBUILD) build/runeopt.cm OptMain.main bin/runeopt-smlnj-legacy.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/runeopt-smlnj-legacy.heap" --runtime "$$d/../build" "$$@"\n' "$(SMLNJ)" > $@
	chmod +x $@

bin/runeopt-smlnj32: $(BUILDGEN) $(SOURCES_OPT) $(GEN_SML) Makefile | build/.doctor-smlnj32 bin/runeopt-smlnj-legacy
	@mkdir -p bin
	$(MLBUILD32) build/runeopt.cm OptMain.main bin/runeopt-smlnj32.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/runeopt-smlnj32.heap" --runtime "$$d/../build" "$$@"\n' "$(SMLNJ32)" > $@
	chmod +x $@

bin/runeopt-smlnj-dev: $(BUILDGEN) $(SOURCES_OPT) $(GEN_SML) Makefile | build/.doctor-smlnj-dev bin/runedoc-smlnj-dev
	@mkdir -p bin
	cm=$$(sh scripts/smlnj-dev-root.sh build/runeopt.cm); \
	  $(MLBUILD_DEV) "$$cm" OptMain.main bin/runeopt-smlnj-dev.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "%s" @SMLload="$$d/runeopt-smlnj-dev.heap" --runtime "$$d/../build" "$$@"\n' "$(SMLNJ_DEV)" > $@
	chmod +x $@

bin/runeopt-polyml.bin: $(BUILDGEN) $(SOURCES_OPT) $(GEN_SML) src/main/runeopt-polyml-main.sml | build/.doctor-polyml
	@mkdir -p bin
	$(POLYC) -o $@ build/runeopt-polyml-build.sml

bin/runeopt-polyml: bin/runeopt-polyml.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runeopt-polyml.bin" -H $(POLYML_HEAP) --runtime "$$d/../build" "$$@"\n' > $@
	chmod +x $@

bin/runeopt-mlkit.bin: $(BUILDGEN) $(SOURCES_OPT) $(GEN_SML) src/main/runeopt-mlkit-main.sml | build/.doctor-mlkit bin/runedoc-mlkit.bin
	@mkdir -p bin
	$(MLKIT_BUILD) -o $@ build/runeopt-mlkit.mlb

bin/runeopt-mlkit: bin/runeopt-mlkit.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runeopt-mlkit.bin" --runtime "$$d/../build" "$$@"\n' > $@
	chmod +x $@

# ---------------------------------------------------------------- VM
vm: bin/runevm-stack bin/runevm

build/librune/%.o: runtime/%.c $(VM_HDRS) build/foreign-selected | build/.doctor-vm
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(RT_INC) $(FFI_FLAGS) -c -o $@ $<

# Publish metadata atomically: a nested test build can overlap runeopt's read.
define foreign_metadata
	@set -e; rune_ffi_meta=$$(mktemp $(1).XXXXXX); \
	printf '%s\n' '$(2)' > "$$rune_ffi_meta"; \
	if cmp -s "$$rune_ffi_meta" $(1); then rm -f "$$rune_ffi_meta"; else mv -f "$$rune_ffi_meta" $(1); fi
endef
.PHONY: foreign-select
foreign-select:
	@mkdir -p build
	$(call foreign_metadata,build/foreign-selected,$(CC) $(CFLAGS) $(FFI_FLAGS) $(FFI_LIBS))
	$(call foreign_metadata,build/foreign-libs,$(FFI_LIBS))
build/foreign-selected: foreign-select
	@:

# native.o is the main of a program runeopt makes and what its code calls
# (runtime/native/native.c): it is in the library, but nothing of runevm-stack refers to it,
# so no VM links it. rune-offsets.s is the layout of the VM for the code.
# Under MinGW the library goes without it: a program of runeopt is for Linux
# on x86-64, and native.c is written against POSIX.
NATIVE_OBJ := $(if $(MINGW),,build/librune/native/native.o)
build/librune.a: $(RT_OBJS) $(NATIVE_OBJ) build/rune-offsets.s
	rm -f $@
	$(AR) rcs $@ $(RT_OBJS) $(NATIVE_OBJ)
	rm -rf tests/out/opt-cache

build/rune-offsets.s: runtime/native/native_offsets.c runtime/native/native_offsets.h $(VM_HDRS) | build/.doctor-vm
	@mkdir -p build/librune
	$(CC) $(CFLAGS) $(RT_INC) -o build/librune/native-offsets runtime/native/native_offsets.c
	build/librune/native-offsets > $@

bin/runevm-stack: runtime/main.c runtime/stack/interp.c build/librune.a $(VM_HDRS) | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) $(RT_INC) -o $@ runtime/main.c runtime/stack/interp.c build/librune.a $(VM_LIBS)

# runtime/register's first loop (docs/plans/middle-end.md, M5): the register bytecode,
# on the runtime of runevm-stack. Its own instruction set's part (runtime/register/isa_regs.c)
# is linked before build/librune.a, whose runtime/stack/isa_stack.c it takes the place of.
NEW_HDRS := runtime/register/regvm.h runtime/register/live.h runtime/register/regops.h runtime/register/reg_cases.h runtime/register/reg_labels.h runtime/register/reg_loop.h runtime/register/reg_words.h runtime/register/fastprim.h runtime/register/jit.h runtime/register/jit/x64.h runtime/register/jit/masm.h runtime/register/jit/compile.h runtime/register/jit_emit.h runtime/register/jit_cases.h
# RUNE_JIT=0 builds it without the JIT (docs/plans/jit.md): the
# interpreter alone, which refuses --jit.
RUNE_JIT ?= 1
JIT_SRCS := runtime/register/jit.c runtime/register/jit/x64.c runtime/register/jit/asm_x64.c runtime/register/jit/masm.c runtime/register/jit/compile.c runtime/register/jit/emit.c runtime/register/jit/dump.c
JIT_HDRS := runtime/register/jit.h runtime/register/jit/x64.h runtime/register/jit/asm.h runtime/register/jit/masm.h runtime/register/jit/compile.h runtime/register/jit_emit.h runtime/register/jit_cases.h
NEW_LOOP := runtime/main.c runtime/register/interp.c runtime/register/debug_loop.c runtime/register/isa_regs.c runtime/register/live.c $(JIT_SRCS)
bin/runevm: $(NEW_LOOP) $(GMP_DIR)/intinf.o build/gmp/selected build/librune.a $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) bin/rune-build | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -DRUNE_JIT=$(RUNE_JIT) $(RT_INC) -o $@ $(NEW_LOOP) $(GMP_DIR)/intinf.o build/librune.a $(GMP_LDLIBS) $(VM_LIBS)
	bin/rune-build record-vm-build --vm $@ --cc '$(CC)' --cflags='$(CFLAGS) $(FFI_FLAGS) -DRUNE_JIT=$(RUNE_JIT)' \
	  --ldlibs='$(VM_LIBS)' --config $(GMP_DIR) --out build/gmp/native-build.json --sources $(NEW_SRCS) --headers $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS)

bin/runevm-sml: $(NEW_LOOP) build/librune.a $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) | build/.doctor-vm
	$(CC) $(CFLAGS) -DRUNE_JIT=$(RUNE_JIT) $(RT_INC) -o $@ $(NEW_LOOP) build/librune.a $(VM_LIBS)

vm-asan: bin/runevm-stack-asan bin/runevm-asan

# The language suite on runtime/register built with the sanitizers (not part of make
# check; run for every change to runtime/register, as the ASan runevm-stack is for the VM).
test-register-asan: bin/runevm-asan $(RUNE) bin/rune-test
	$(RUNE_TEST) --tier test-register-asan

bin/runevm-stack-asan: build/foreign-selected $(VM_SRCS) $(VM_HDRS) | build/.doctor-asan
	@mkdir -p bin
	$(CC) -std=c17 -g -O1 -Wall -Wextra -fsanitize=address,undefined -fno-omit-frame-pointer $(RT_INC) $(FFI_FLAGS) -o $@ $(VM_SRCS) $(VM_LIBS)

# runtime/register with the sanitizers: its loop, its instruction set's part, and the
# runtime but for the stack bytecode's part
NEW_SRCS := runtime/main.c runtime/register/interp.c runtime/register/debug_loop.c runtime/register/isa_regs.c runtime/register/live.c $(JIT_SRCS) $(filter-out runtime/stack/isa_stack.c,$(RT_SRCS)) runtime/sys/sys_$(SYS).c
bin/runevm-asan: build/foreign-selected $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) $(GMP_DIR)/config.mk build/gmp/selected | build/.doctor-asan
	@mkdir -p bin
	$(CC) -std=c17 -g -O1 -Wall -Wextra -fsanitize=address,undefined -fno-omit-frame-pointer $(RT_INC) $(GMP_FLAGS) $(FFI_FLAGS) -o $@ $(NEW_SRCS) $(GMP_LDLIBS) $(VM_LIBS)

# The word's switches (docs/plans/heap-layout.md, D2 and D3), each a VM of its
# own for measurements: ints and words that keep 64 bits (D2 A; a compiler
# given --int-bits=64 makes its bytecode), and every real in a box (D3 B).
# Not part of make check.
bin/runevm-int64: build/foreign-selected $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) $(GMP_DIR)/config.mk build/gmp/selected | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -DRUNE_JIT=$(RUNE_JIT) -DRUNE_INT64 $(RT_INC) $(GMP_FLAGS) $(FFI_FLAGS) -o $@ $(NEW_SRCS) $(GMP_LDLIBS) $(VM_LIBS)
# The JIT on the first (tests/register/int64-box-home.sml), at every tier,
# and with raw homes: a word past 63 bits is a box, which a home that holds
# the word must not keep across a collection. Not part of make check.
test-int64: bin/runevm-int64 bin/runevm-rawhomes $(RUNE) bin/rune-test
	$(RUNE_TEST) --tier test-int64
bin/runevm-realboxed: build/foreign-selected $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) $(GMP_DIR)/config.mk build/gmp/selected | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -DRUNE_JIT=$(RUNE_JIT) -DRUNE_REAL_BOXED $(RT_INC) $(GMP_FLAGS) $(FFI_FLAGS) -o $@ $(NEW_SRCS) $(GMP_LDLIBS) $(VM_LIBS)
# D2 A with tier 2's homes of ints and words holding the 64 bits (D5 A as the
# roadmap states it): faster where words pass 63 bits, slower where a small
# int crosses a slot at every call.
bin/runevm-rawhomes: build/foreign-selected $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) $(GMP_DIR)/config.mk build/gmp/selected | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -DRUNE_JIT=$(RUNE_JIT) -DRUNE_INT64 -DRUNE_RAW_HOMES $(RT_INC) $(GMP_FLAGS) $(FFI_FLAGS) -o $@ $(NEW_SRCS) $(GMP_LDLIBS) $(VM_LIBS)
# The hooks for the collector to come (docs/plans/heap-layout.md, M7), each a
# VM of its own to test or to measure with: the collector sets the header's
# four bits on every object it copies and every reader of a kind masks them;
# and the barrier marks a card at every store into an object that exists.
bin/runevm-gcbits: build/foreign-selected $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) $(GMP_DIR)/config.mk build/gmp/selected | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -DRUNE_JIT=$(RUNE_JIT) -DRUNE_GC_BITS $(RT_INC) $(GMP_FLAGS) $(FFI_FLAGS) -o $@ $(NEW_SRCS) $(GMP_LDLIBS) $(VM_LIBS)
bin/runevm-cards: build/foreign-selected $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) $(GMP_DIR)/config.mk build/gmp/selected | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -DRUNE_JIT=$(RUNE_JIT) -DRUNE_BARRIER_CARDS $(RT_INC) $(GMP_FLAGS) $(FFI_FLAGS) -o $@ $(NEW_SRCS) $(GMP_LDLIBS) $(VM_LIBS)
# The instrument of docs/plans/performance-64bit.md's experiments 1 and 5
# (x86-64): compiled code counts every conversion between a raw number in a
# home and its word, by the instruction that makes it; runevm-conv
# --jit-stats prints the table.
bin/runevm-conv: build/foreign-selected $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) $(GMP_DIR)/config.mk build/gmp/selected | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -DRUNE_JIT=$(RUNE_JIT) -DRUNE_JIT_CONV $(RT_INC) $(GMP_FLAGS) $(FFI_FLAGS) -o $@ $(NEW_SRCS) $(GMP_LDLIBS) $(VM_LIBS)

# The census VM (docs/census.md; docs/plans/heap-layout.md, M1, and
# docs/plans/garbage-collector-v2.md, M1): runtime/register's loop on the runtime
# with -DRUNE_CENSUS, which enables the hooks of runtime/census/census.h. It
# interprets everything (the JIT allocates in line) and prints the stock VM's
# --count line, which tests/runner/heapchecks.sml checks.
CENSUS_SRCS := $(NEW_SRCS) runtime/census/census.c runtime/census/census_static.c
vm-census: bin/runevm-census
bin/runevm-census: build/foreign-selected $(CENSUS_SRCS) $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) runtime/census/census.h runtime/census/layouts.h $(GMP_DIR)/config.mk build/gmp/selected | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -DRUNE_JIT=1 -DRUNE_CENSUS $(RT_INC) $(GMP_FLAGS) $(FFI_FLAGS) -o $@ $(CENSUS_SRCS) $(GMP_LDLIBS) $(VM_LIBS)

# The census VM against the stock one on a small program: the same --count
# line, every byte and object in census.txt, the trace's own consistency
# (the SML reader in tests/runner/tracecheck.sml), summary and static modes.
# Part of make check, with no NumPy requirement.
test-census: bin/runevm-census bin/runevm $(RUNE) bin/rune-test bin/rune-heap-check
	$(RUNE_TEST) --tier test-census

# The heap-layout tools (docs/plans/heap-layout.md, M2): the trace-driven
# simulator bin/heapsim and its synthetic-trace generator bin/heapsim-gen
# (tools/heapsim), and the layout harness (tests/layouts). check-heapsim
# runs the simulator's unit tests against the generator and holds its copier
# model to the stock VM's --stats on two small workloads that collect
# (their census traces made on the way); check-layouts builds the harness with $(CC) and
# checks that every kernel's checksum is the same under every layout. The
# second generation's simulator bin/gcsim (docs/plans/garbage-collector-v2.md,
# *The simulator*; tools/heapsim/README.md): check-gcsim holds its models to
# traces whose answers are known in closed form, and to bin/heapsim's
# copier, nursery and sticky models. All three are part of make check.
bin/heapsim: tools/heapsim/sim.c runtime/census/layouts.h | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) $(RT_INC) -o $@ tools/heapsim/sim.c -lm
bin/heapsim-gen: tools/heapsim/gen.c runtime/census/layouts.h | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) $(RT_INC) -o $@ tools/heapsim/gen.c -lm
bin/gcsim: tools/heapsim/gcsim.c runtime/census/layouts.h | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) $(RT_INC) -o $@ tools/heapsim/gcsim.c -lm
heapsim: bin/heapsim bin/heapsim-gen bin/gcsim
# The census of the validation is taken every 8192 instructions, in traces
# of its own: at bin/rune-measure census's 32768 the lower band of compile-sigs
# missed a collection that the stock VM made at 4 MiB, where the live data
# crossed its trigger between two samples (2026-10-11, when Position and
# SysWord became types of their own and the workload grew a little).
check-heapsim: heapsim bin/runevm-census bin/runevm $(RUNE) bin/rune.rbc bin/rune-test bin/rune-heap-check
	$(RUNE_TEST) --tier check-heapsim
check-gcsim: heapsim bin/rune-test bin/rune-heap-check
	$(RUNE_TEST) --tier check-gcsim
check-layouts: bin/rune-test bin/rune-heap-check
	$(RUNE_TEST) --tier check-layouts

# The collector harness (docs/plans/garbage-collector-v2.md, *The harness*;
# tests/gcbench/README.md): `make gcbench` builds tests/out/gcbench/gcbench
# with $(CC). check-gcbench runs every experiment at tiny sizes with its
# self-checks on (tests/runner/heapchecks.sml: nothing timed,
# no perf needed). The harness is for Linux on x86-64: elsewhere
# check-gcbench says so and does nothing. Part of make check.
gcbench:
	$(MAKE) --no-print-directory -C tests/gcbench CC=$(CC)
check-gcbench: bin/rune-test bin/rune-heap-check
	$(RUNE_TEST) --tier check-gcbench

# runeopt's templates for the layout of values and objects, generated from
# the JIT's macro-assembler run against the text backend of its assembler
# (runtime/register/jit/templates.c, asm_text.c; docs/plans/heap-layout.md D11, M3):
# `make templates` remakes src/opt/x64_layout.sml after a change to masm.c;
# check-templates (part of test-native) refuses a stale file.
TEMPLATES_SRCS := runtime/register/jit/templates.c runtime/register/jit/masm.c runtime/register/jit/asm_text.c
bin/runeopt-templates: $(TEMPLATES_SRCS) runtime/register/jit/masm.h runtime/register/jit/asm.h runtime/register/jit/asm_text.h runtime/native/native_offsets.h $(VM_HDRS) | build/.doctor-vm
	@mkdir -p bin
	$(CC) $(CFLAGS) -DRUNE_ASM_TEXT -DRUNE_JIT=1 $(RT_INC) -o $@ $(TEMPLATES_SRCS)
templates: bin/runeopt-templates
	bin/runeopt-templates > src/opt/x64_layout.sml
check-templates: bin/runeopt-templates bin/rune-test bin/rune-native-check
	$(RUNE_TEST) --tier check-templates

# ---------------------------------------------------------- Windows (apart)
# `make windows` builds the VM for Windows with mingw-w64, for 64 bits
# (bin/runevm-stack.exe) and for 32 bits (bin/runevm-stack32.exe), and `make
# test-windows` runs the language suite, tests/runtime and the Basis Library
# suite (the rune:windows configurations of bin/rune-matrix) on
# both. Neither is part of any other target, and nothing else in the tree
# depends on runtime/sys/sys_win.c: the toolchain is only on a machine that has it,
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
# runtime/sys/sys_win.c; tests/windows-skip.txt lists the programs that need what it
# does not and why, and docs/runtime.md what a program can count on.
WINCC       ?= x86_64-w64-mingw32-gcc
WINCC32     ?= i686-w64-mingw32-gcc
WINCFLAGS   ?= -std=c17 -O2 -Wall -Wextra -D__USE_MINGW_ANSI_STDIO=1
WINCFLAGS32 ?= -msse2 -mfpmath=sse -Wl,--large-address-aware
WIN_SRCS    := runtime/main.c runtime/stack/interp.c $(RT_SRCS) runtime/sys/sys_win.c
# runtime/register for Windows: its loop and its instruction set's part in place of
# the stack bytecode's (runtime/stack/isa_stack.c), as bin/runevm-asan is built
WIN_NEW_SRCS := runtime/main.c runtime/register/interp.c runtime/register/debug_loop.c runtime/register/isa_regs.c runtime/register/live.c $(JIT_SRCS) $(filter-out runtime/stack/isa_stack.c,$(RT_SRCS)) runtime/sys/sys_win.c
WIN_LIBS    := -lws2_32 -ladvapi32 -lshell32 -luser32 -lpsapi
FFI_WIN64_PREFIX ?= build/deps/libffi-win64/install
FFI_WIN32_PREFIX ?= build/deps/libffi-win32/install
FFI_WIN64_ENABLED := $(if $(filter no,$(FFI)),,$(wildcard $(FFI_WIN64_PREFIX)/include/ffi.h))
FFI_WIN32_ENABLED := $(if $(filter no,$(FFI)),,$(wildcard $(FFI_WIN32_PREFIX)/include/ffi.h))
FFI_WIN64_FLAGS := $(if $(FFI_WIN64_ENABLED),-DRUNE_FFI=1 -I$(FFI_WIN64_PREFIX)/include,-DRUNE_FFI=0)
FFI_WIN32_FLAGS := $(if $(FFI_WIN32_ENABLED),-DRUNE_FFI=1 -I$(FFI_WIN32_PREFIX)/include,-DRUNE_FFI=0)
FFI_WIN64_LIBS := $(if $(FFI_WIN64_ENABLED),$(FFI_WIN64_PREFIX)/lib/libffi.a)
FFI_WIN32_LIBS := $(if $(FFI_WIN32_ENABLED),$(FFI_WIN32_PREFIX)/lib/libffi.a)
.PHONY: foreign-win-select
foreign-win-select:
	@mkdir -p build
	$(call foreign_metadata,build/foreign-win64-selected,$(WINCC) $(WINCFLAGS) $(FFI_WIN64_FLAGS) $(FFI_WIN64_LIBS))
	$(call foreign_metadata,build/foreign-win32-selected,$(WINCC32) $(WINCFLAGS) $(WINCFLAGS32) $(FFI_WIN32_FLAGS) $(FFI_WIN32_LIBS))
build/foreign-win64-selected build/foreign-win32-selected: foreign-win-select
	@:

GMP_CROSS_PREFIX ?= build/deps/gmp
GMP_WIN64_PREFIX ?= $(GMP_CROSS_PREFIX)/windows64
GMP_WIN32_PREFIX ?= $(GMP_CROSS_PREFIX)/windows32
GMP_CROSS_TOOL := bin/rune-build $(BUILDER_NATIVE_SRCS)

.PHONY: gmp-dep-windows
gmp-dep-windows: bin/rune-build
	bin/rune-build build-gmp --prefix '$(GMP_WIN64_PREFIX)' --cc '$(WINCC)' --host x86_64-w64-mingw32 --enable-fat --jobs $(JOBS)
	bin/rune-build build-gmp --prefix '$(GMP_WIN32_PREFIX)' --cc '$(WINCC32)' --host i686-w64-mingw32 --enable-fat --abi 32 --jobs $(JOBS)

# windows_dlls CC: refuse $@ when it imports a DLL whose name starts with lib
define windows_dlls
	bin/rune-build check-windows-imports --cc '$(1)' --vm '$@'
endef

windows: bin/runevm-stack.exe bin/runevm-stack32.exe bin/runevm.exe bin/runevm32.exe

bin/runevm-stack.exe: build/foreign-win64-selected $(FFI_WIN64_LIBS) $(VM_SRCS) $(VM_HDRS) runtime/sys/sys_win.c bin/rune-build | build/.doctor-windows
	@mkdir -p bin
	$(WINCC) $(WINCFLAGS) $(FFI_WIN64_FLAGS) -o $@ $(WIN_SRCS) $(RT_INC) $(WIN_LIBS) $(FFI_WIN64_LIBS)
	$(call windows_dlls,$(WINCC))

bin/runevm-stack32.exe: build/foreign-win32-selected $(FFI_WIN32_LIBS) $(VM_SRCS) $(VM_HDRS) runtime/sys/sys_win.c bin/rune-build | build/.doctor-windows
	@mkdir -p bin
	$(WINCC32) $(WINCFLAGS) $(WINCFLAGS32) $(FFI_WIN32_FLAGS) -o $@ $(WIN_SRCS) $(RT_INC) $(WIN_LIBS) $(FFI_WIN32_LIBS)
	$(call windows_dlls,$(WINCC32))

# share/rune.png, as a resource, so Explorer shows it on the executable.
# windres writes a COFF object of one machine, so the two widths differ.
build/rune.ico: share/rune.png share/rune.ico tools/builder/data/branding.json bin/rune-build
	@mkdir -p build
	bin/rune-build make-dist --write-ico $@

build/runevm.rc: build/rune.ico
	printf '%s\n' '1 ICON "rune.ico"' > $@

build/runevm-x64.o: build/runevm.rc build/rune.ico | build/.doctor-windows
	cd build && $(patsubst %gcc,%windres,$(WINCC)) -O coff -i runevm.rc -o runevm-x64.o

build/runevm-x86.o: build/runevm.rc build/rune.ico | build/.doctor-windows
	cd build && $(patsubst %gcc,%windres,$(WINCC32)) -O coff -i runevm.rc -o runevm-x86.o

bin/runevm.exe: $(WIN_NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) $(GMP_CROSS_TOOL) build/runevm-x64.o gmp-force | build/.doctor-windows
	bin/rune-build build-gmp-vm --mode '$(GMP)' --prefix '$(GMP_WIN64_PREFIX)' --cc '$(WINCC)' \
	  --cflags='$(WINCFLAGS) $(FFI_WIN64_FLAGS)' --ldlibs='$(WIN_LIBS) $(FFI_WIN64_LIBS)' --config build/gmp/windows64 --out $@ --windows \
	  --objects build/runevm-x64.o \
	  --sources $(WIN_NEW_SRCS) --headers $(VM_HDRS) $(NEW_HDRS) Makefile

bin/runevm32.exe: $(WIN_NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) $(GMP_CROSS_TOOL) build/runevm-x86.o gmp-force | build/.doctor-windows
	bin/rune-build build-gmp-vm --mode '$(GMP)' --prefix '$(GMP_WIN32_PREFIX)' --cc '$(WINCC32)' \
	  --cflags='$(WINCFLAGS) $(WINCFLAGS32) $(FFI_WIN32_FLAGS)' --ldlibs='$(WIN_LIBS) $(FFI_WIN32_LIBS)' --config build/gmp/windows32 --out $@ --windows \
	  --objects build/runevm-x86.o \
	  --sources $(WIN_NEW_SRCS) --headers $(VM_HDRS) $(NEW_HDRS) Makefile

# The suites on the Windows VMs of both bytecodes: the stack one compiled
# by bin/rune-stack, the register one by bin/rune, each on its two VMs
# (bin/rune-windows), then the Basis Library suite on all four; then the
# REPL on a console, its debug adapter, and its Jupyter kernel where Windows
# has a Python.
# The runtime/register VMs run with every function given to the JIT (RUNEVM_JIT,
# which WSLENV passes to a program of Windows), so that the JIT's Windows
# convention is what the suites test there.
.PHONY: test-windows-text
test-windows-text: bin/rune-test bin/rune-windows windows $(RUNE) bin/rune.rbc bin/rune.stack.rbc
	RUNE=$(RUNE) WINCC='$(WINCC)' WINCC32='$(WINCC32)' $(RUNE_TEST) --tier test-windows-text

test-windows: bin/rune-matrix bin/rune-test bin/rune-windows bin/rune-protocol-check bin/rune-terminal windows $(RUNE) bin/rune.rbc bin/rune.stack.rbc bin/rune-repl bin/rune-repl.cmd bin/rune-dap bin/rune-kernel
	RUNE=$(RUNE) WINCC='$(WINCC)' WINCC32='$(WINCC32)' $(RUNE_TEST) --tier test-windows
	WSLENV=RUNEVM_INTINF:RUNEVM_JIT:$$WSLENV RUNEVM_JIT=all RUNE=$(abspath $(RUNE_STACK)) bin/rune-matrix -j $(JOBS) --configs windows
	bin/rune-protocol-check dap --windows
	bin/rune-protocol-check kernel --windows

# ------------------------------------------------------------- portability
# The VM on machines this one is not: a 32-bit x86, where a pointer is four
# bytes, and a 64-bit PowerPC, where a number is the other way round. Both
# are Linux, so only the VM differs -- the bytecode is the same file -- and
# the point is what they do not share with the machine that built them: the
# width of a pointer, the alignment an ABI gives an int64_t, and the order of
# the bytes in a word. An image written by one is read by another, which is
# the strongest thing the format claims (runtime/image.c).
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
# aarch64 (docs/plans/jit.md, M12): the second target of runtime/register's JIT,
# built with the same cross toolchain pattern (libc6-dev-arm64-cross,
# libgcc-13-dev-arm64-cross, binutils-aarch64-linux-gnu) and run by
# qemu-aarch64, with the JIT on
A64CC      ?= clang
A64ROOT    ?= /usr/aarch64-linux-gnu
A64FLAGS   ?= --target=aarch64-linux-gnu -B$(A64ROOT)/bin -L$(A64ROOT)/lib -I$(A64ROOT)/include \
              -Wl,-dynamic-linker,$(A64ROOT)/lib/ld-linux-aarch64.so.1 -Wl,-rpath,$(A64ROOT)/lib
# The VMs make dist ships. The portability binaries keep the sysroot
# interpreter, which a fork under binfmt opens by that path; a machine of
# that architecture opens /lib/ld-linux-aarch64.so.1 and /lib64/ld64.so.1.
DIST_A64FLAGS ?= --target=aarch64-linux-gnu -B$(A64ROOT)/bin -L$(A64ROOT)/lib -I$(A64ROOT)/include \
              -Wl,-dynamic-linker,/lib/ld-linux-aarch64.so.1
DIST_PPCFLAGS ?= --target=powerpc64-linux-gnu -B$(PPCROOT)/bin -L$(PPCROOT)/lib -I$(PPCROOT)/include \
              -Wl,-dynamic-linker,/lib64/ld64.so.1
QEMUA64    ?= qemu-aarch64
JIT_SRCS_A64 := runtime/register/jit.c runtime/register/jit/a64.c runtime/register/jit/asm_a64.c runtime/register/jit/masm.c runtime/register/jit/compile.c runtime/register/jit/emit.c runtime/register/jit/dump.c
NEW_SRCS_A64 := runtime/main.c runtime/register/interp.c runtime/register/debug_loop.c runtime/register/isa_regs.c runtime/register/live.c $(JIT_SRCS_A64) $(filter-out runtime/stack/isa_stack.c,$(RT_SRCS)) runtime/sys/sys_$(SYS).c
PORT_TIMEOUT ?= 900
GMP_LINUX32_PREFIX ?= $(GMP_CROSS_PREFIX)/linux32
GMP_PPC64_PREFIX ?= $(GMP_CROSS_PREFIX)/ppc64
# The clang/PPC optimized GMP build fails the retained division probe.
GMP_PPC64_FLAGS ?= --disable-assembly
GMP_AARCH64_PREFIX ?= $(GMP_CROSS_PREFIX)/aarch64

.PHONY: gmp-dep-portability
gmp-dep-portability: bin/rune-build
	bin/rune-build build-gmp --prefix '$(GMP_LINUX32_PREFIX)' --cc '$(PORTCC32)' --cflags='-O2 $(PORTFLAGS32)' --host i686-pc-linux-gnu --abi 32 --enable-fat --with-pic --jobs $(JOBS)
	bin/rune-build build-gmp --prefix '$(GMP_PPC64_PREFIX)' --cc '$(PPCCC)' --cflags='-O2 $(PPCFLAGS)' --host powerpc64-linux-gnu --runner '$(QEMUPPC) -L $(PPCROOT)' $(GMP_PPC64_FLAGS) --with-pic --jobs $(JOBS)
	bin/rune-build build-gmp --prefix '$(GMP_AARCH64_PREFIX)' --cc '$(A64CC)' --cflags='-O2 $(A64FLAGS)' --host aarch64-linux-gnu --runner '$(QEMUA64) -L $(A64ROOT)' --with-pic --jobs $(JOBS)

portability: bin/runevm-stack32 bin/runevm-stack-ppc64 bin/runevm32 bin/runevm-ppc64 bin/runevm-aarch64

bin/runevm-stack32: $(VM_SRCS) $(VM_HDRS) Makefile | build/.doctor-portability
	@mkdir -p bin
	$(PORTCC32) $(CFLAGS) $(PORTFLAGS32) $(RT_INC) -o $@ $(VM_SRCS) -lm

# As with the host builds of the compiler, the name is a wrapper and the
# payload sits beside it: every runner takes --vm bin/runevm-stack-ppc64 and needs
# to know nothing of qemu.
bin/runevm-stack-ppc64.bin: $(VM_SRCS) $(VM_HDRS) Makefile | build/.doctor-portability
	@mkdir -p bin
	$(PPCCC) $(CFLAGS) $(PPCFLAGS) $(RT_INC) -o $@ $(VM_SRCS) -lm

bin/runevm-stack-ppc64: bin/runevm-stack-ppc64.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec %s "$$d/runevm-stack-ppc64.bin" "$$@"\n' '$(QEMUPPC) -L $(PPCROOT)' > $@
	chmod +x $@

# runtime/register for the same two machines, from the sources bin/runevm-asan is
# built from (its instruction set's part in place of the stack bytecode's)
bin/runevm32: build/foreign-selected $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) Makefile $(GMP_CROSS_TOOL) gmp-force | build/.doctor-portability
	bin/rune-build build-gmp-vm --mode '$(GMP)' --prefix '$(GMP_LINUX32_PREFIX)' --cc '$(PORTCC32)' \
	  --cflags='$(CFLAGS) $(PORTFLAGS32)' --runner '' --config build/gmp/linux32 --out $@ \
	  --sources $(NEW_SRCS) --headers $(VM_HDRS) $(NEW_HDRS) Makefile

bin/runevm-ppc64.bin: build/foreign-selected $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) Makefile $(GMP_CROSS_TOOL) gmp-force | build/.doctor-portability
	bin/rune-build build-gmp-vm --mode '$(GMP)' --prefix '$(GMP_PPC64_PREFIX)' --cc '$(PPCCC)' \
	  --cflags='$(CFLAGS) $(PPCFLAGS)' --runner '$(QEMUPPC) -L $(PPCROOT)' --config build/gmp/ppc64 --out $@ \
	  --sources $(NEW_SRCS) --headers $(VM_HDRS) $(NEW_HDRS) Makefile

bin/runevm-ppc64: bin/runevm-ppc64.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec %s "$$d/runevm-ppc64.bin" "$$@"\n' '$(QEMUPPC) -L $(PPCROOT)' > $@
	chmod +x $@

# the register VM for aarch64, its JIT included (M12): the encoder a64.c
# and the portable assembler's aarch64 side in place of x64.c's
bin/runevm-aarch64.bin: $(NEW_SRCS_A64) $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) runtime/register/jit/a64.h runtime/register/jit/asm.h Makefile $(GMP_CROSS_TOOL) gmp-force | build/.doctor-portability
	bin/rune-build build-gmp-vm --mode '$(GMP)' --prefix '$(GMP_AARCH64_PREFIX)' --cc '$(A64CC)' \
	  --cflags='$(CFLAGS) $(A64FLAGS) -DRUNE_JIT=1' --runner '$(QEMUA64) -L $(A64ROOT)' --config build/gmp/aarch64 --out $@ \
	  --sources $(NEW_SRCS_A64) --headers $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) runtime/register/jit/a64.h runtime/register/jit/asm.h Makefile

bin/runevm-aarch64: bin/runevm-aarch64.bin Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec %s "$$d/runevm-aarch64.bin" "$$@"\n' '$(QEMUA64) -L $(A64ROOT)' > $@
	chmod +x $@

# The VMs make dist ships. The portability and Windows builds follow
# GMP=auto, which uses the SML fallback when the pinned library is absent
# and, on this machine, links bin/runevm to the shared libgmp.so. An
# archive has to run without that library, so these targets require the
# static GMP (--mode yes) and keep their own config directories.
# --with-pic on the packages: the VMs are PIE, and a non-PIC archive can
# need text relocations (docs/building.md).
GMP_DIST_NATIVE_PREFIX ?= $(GMP_CROSS_PREFIX)/native-dist
.PHONY: gmp-dep-dist-native
gmp-dep-dist-native: bin/rune-build
	bin/rune-build build-gmp --prefix '$(GMP_DIST_NATIVE_PREFIX)' \
	  $(if $(filter x86_64 i686 i386,$(shell uname -m)),--enable-fat) \
	  --with-pic --jobs $(JOBS)

bin/dist/runevm: $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) Makefile $(GMP_CROSS_TOOL) gmp-force gmp-dep-dist-native | build/.doctor-vm
	@mkdir -p bin/dist
	bin/rune-build build-gmp-vm --mode yes --prefix '$(GMP_DIST_NATIVE_PREFIX)' --cc '$(CC)' \
	  --cflags='$(CFLAGS) $(FFI_FLAGS) -DRUNE_JIT=$(RUNE_JIT)' --ldlibs='$(VM_LIBS)' \
	  --config build/gmp/native-dist --out $@ \
	  --sources $(NEW_SRCS) --headers $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) Makefile

bin/dist/runevm32: $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) Makefile $(GMP_CROSS_TOOL) gmp-force gmp-dep-portability | build/.doctor-portability
	@mkdir -p bin/dist
	bin/rune-build build-gmp-vm --mode yes --prefix '$(GMP_LINUX32_PREFIX)' --cc '$(PORTCC32)' \
	  --cflags='$(CFLAGS) $(PORTFLAGS32)' --runner '' --config build/gmp/linux32-dist --out $@ \
	  --sources $(NEW_SRCS) --headers $(VM_HDRS) $(NEW_HDRS) Makefile

bin/dist/runevm.exe: $(WIN_NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) Makefile $(GMP_CROSS_TOOL) build/runevm-x64.o gmp-force gmp-dep-windows | build/.doctor-windows
	@mkdir -p bin/dist
	bin/rune-build build-gmp-vm --mode yes --prefix '$(GMP_WIN64_PREFIX)' --cc '$(WINCC)' \
	  --cflags='$(WINCFLAGS) $(FFI_WIN64_FLAGS)' --ldlibs='$(WIN_LIBS) $(FFI_WIN64_LIBS)' --config build/gmp/windows64-dist --out $@ --windows \
	  --objects build/runevm-x64.o \
	  --sources $(WIN_NEW_SRCS) --headers $(VM_HDRS) $(NEW_HDRS) Makefile

bin/dist/runevm32.exe: $(WIN_NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) Makefile $(GMP_CROSS_TOOL) build/runevm-x86.o gmp-force gmp-dep-windows | build/.doctor-windows
	@mkdir -p bin/dist
	bin/rune-build build-gmp-vm --mode yes --prefix '$(GMP_WIN32_PREFIX)' --cc '$(WINCC32)' \
	  --cflags='$(WINCFLAGS) $(WINCFLAGS32) $(FFI_WIN32_FLAGS)' --ldlibs='$(WIN_LIBS) $(FFI_WIN32_LIBS)' --config build/gmp/windows32-dist --out $@ --windows \
	  --objects build/runevm-x86.o \
	  --sources $(WIN_NEW_SRCS) --headers $(VM_HDRS) $(NEW_HDRS) Makefile

bin/dist/runevm-aarch64: $(NEW_SRCS_A64) $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) runtime/register/jit/a64.h runtime/register/jit/asm.h Makefile $(GMP_CROSS_TOOL) gmp-force gmp-dep-portability | build/.doctor-portability
	@mkdir -p bin/dist
	bin/rune-build build-gmp-vm --mode yes --prefix '$(GMP_AARCH64_PREFIX)' --cc '$(A64CC)' \
	  --cflags='$(CFLAGS) $(DIST_A64FLAGS) -DRUNE_JIT=1' --runner '$(QEMUA64) -L $(A64ROOT)' --config build/gmp/aarch64-dist --out $@ \
	  --sources $(NEW_SRCS_A64) --headers $(VM_HDRS) $(NEW_HDRS) $(JIT_HDRS) runtime/register/jit/a64.h runtime/register/jit/asm.h Makefile

bin/dist/runevm-ppc64: $(NEW_SRCS) $(VM_HDRS) $(NEW_HDRS) Makefile $(GMP_CROSS_TOOL) gmp-force gmp-dep-portability | build/.doctor-portability
	@mkdir -p bin/dist
	bin/rune-build build-gmp-vm --mode yes --prefix '$(GMP_PPC64_PREFIX)' --cc '$(PPCCC)' \
	  --cflags='$(CFLAGS) $(DIST_PPCFLAGS)' --runner '$(QEMUPPC) -L $(PPCROOT)' --config build/gmp/ppc64-dist --out $@ \
	  --sources $(NEW_SRCS) --headers $(VM_HDRS) $(NEW_HDRS) Makefile

# The PowerPC VM runs under an emulator and is about ten times slower, so the
# Basis suite gets longer than the two minutes a program is otherwise given:
# the largest of the monomorphic tests takes 34 s here and about six minutes
# there.
test-portability: portability $(RUNE) vm bin/rune-test
	$(RUNE_TEST) --tier test-portability

# ---------------------------------------------------------------- tests
# Depending on $(RUNE) builds whichever compiler the override names. The
# programs of tests/lang and tests/errors run on bin/rune-test, in the ways
# of the targets below (tests/runner/lang.sml), each target's by its tag:
# make test is test-steps, the rest of what it ran, and the runner's tier
# test. RUNE_TEST is the runner as these targets run it. RUNEVM goes into
# its environment only when it is overridden, as make would put it there:
# the scripts of the steps it runs read a RUNEVM, from other directories.
RUNE_TEST = GC_STRESS=$(GC_STRESS) $(if $(filter command line environment,$(origin RUNEVM)),RUNEVM=$(RUNEVM)) \
            NATIVE_HOST=$(NATIVE_HOST) MAKE='$(CHECK_MAKE)' \
            bin/rune-test run $(if $(filter command line environment,$(origin JOBS)),-j $(JOBS))
LOW_LEVEL_BINS := build/heap_test build/heap_test-gcbits build/heap_test-cards \
                  build/register/x64_test build/register/a64_test build/register/masm_test
.PHONY: $(LOW_LEVEL_BINS)
build/heap_test: tests/runtime/heap_test.c $(RT_SRCS) runtime/sys/sys_$(SYS).c $(VM_HDRS) Makefile
	@mkdir -p build
	$(CC) $(CFLAGS) $(RT_INC) -o $@ tests/runtime/heap_test.c $(RT_SRCS) runtime/sys/sys_$(SYS).c $(VM_LIBS)
build/heap_test-gcbits: tests/runtime/heap_test.c $(RT_SRCS) runtime/sys/sys_$(SYS).c $(VM_HDRS) Makefile
	@mkdir -p build
	$(CC) $(CFLAGS) -DRUNE_GC_BITS $(RT_INC) -o $@ tests/runtime/heap_test.c $(RT_SRCS) runtime/sys/sys_$(SYS).c $(VM_LIBS)
build/heap_test-cards: tests/runtime/heap_test.c $(RT_SRCS) runtime/sys/sys_$(SYS).c $(VM_HDRS) Makefile
	@mkdir -p build
	$(CC) $(CFLAGS) -DRUNE_BARRIER_CARDS $(RT_INC) -o $@ tests/runtime/heap_test.c $(RT_SRCS) runtime/sys/sys_$(SYS).c $(VM_LIBS)
test-steps: $(RUNE) vm bin/rune-windows bin/rune-test build/heap_test | build/.doctor-check
	$(RUNE_TEST) --tier test-low-level
test: $(RUNE) vm bin/rune-windows bin/rune-test build/heap_test | build/.doctor-check
	$(RUNE_TEST) --tier test

# The collector and its hooks (docs/plans/heap-layout.md, M7;
# docs/plans/garbage-collector-v2.md, M2 and M3). The C
# test of them (tests/runtime/heap_test.c) on the runtime as built and as
# built with each switch: the header's four bits set by the collector on
# every object it copies (RUNE_GC_BITS), and the barrier as a card mark
# (RUNE_BARRIER_CARDS). Then tests/lang on the VM of the first, as it comes
# and with every function compiled and a collection at every GC_STRESS-th
# allocation, as make test-stress has it (101 by default; GC_STRESS=1 at
# every one, which takes a quarter of an hour), so
# that a reader of a kind that does not mask the bits fails, and on the VM
# of the second; and on bin/runevm with the heap checked before and after
# every collection of a heap of 64 KiB and a nursery of 8 KiB (--gc-verify),
# the barrier's cards with it. Part of make check.
test-heap-steps: bin/rune-test build/heap_test build/heap_test-gcbits build/heap_test-cards | build/.doctor-check
	$(RUNE_TEST) --tier test-heap-hooks
test-heap: build/heap_test build/heap_test-gcbits build/heap_test-cards bin/runevm-gcbits bin/runevm-cards $(RUNE) vm bin/rune-test
	$(RUNE_TEST) --tier test-heap

# The two collectors (docs/runtime.md, *The garbage collector*;
# docs/plans/garbage-collector-v2.md, D3): tests/lang under each, on both
# VMs, with the heap checked before and after every collection of a heap of
# 64 KiB and a nursery of 8 KiB, and the low-pause one with every function
# compiled and a collection at every GC_STRESS-th allocation (make
# test-stress runs the default, throughput); and each with the old space
# compacted at every full collection (--gc-compact, D4). Part of make check.
test-gc: $(RUNE) vm bin/rune-test | build/.doctor-check
	$(RUNE_TEST) --tier test-gc

test-all: host-builds vm bin/rune-test | build/.doctor-check
	$(RUNE_TEST) --tier test-all

check-cross: host-builds bin/rune-boot bin/runedoc-boot bin/rune.stack.rbc bin/runedoc.stack.rbc bin/runeopt.stack.rbc bin/rune-test | build/.doctor-check
	$(RUNE_TEST) --tier check-cross

# Every instruction says where it came from, and the line is one the file has.
# The intermediate representations (docs/ir.md): the dumps of tests/ir, and
# every program of tests/lang and tests/perf the same at -O0 and -O2 with the
# lint of every pass on (docs/plans/middle-end.md, M2).
test-ir: $(RUNE) bin/rune-test
	$(RUNE_TEST) --tier test-ir

check-levels: $(RUNE) $(RUNEVM) bin/rune-test
	$(RUNE_TEST) --tier check-levels

# Every program of tests/lang and tests/perf compiled a unit per file (--units)
# prints, traces and exits as the program compiled whole, at -O0 to -O2, on
# both bytecodes; the programs of several files of tests/units do what they
# expect; and the compiler compiled in units compiles itself to bin/rune.rbc
# (docs/units.md; docs/plans/incremental-compilation.md, M2).
check-units: $(RUNE) bin/rune-boot bin/runevm bin/runevm-stack bin/rune-test bin/rune-scenarios
	$(RUNE_TEST) --tier check-units
check-units-steps: $(RUNE) bin/rune-boot bin/runevm bin/runevm-stack bin/rune-test
	$(RUNE_TEST) --tier check-units-bootstrap

# rune-repl (docs/repl.md): the compiler and the REPL, compiled a unit per
# file into bin/rune-repl.units (their units in order, and the sources they
# came from), and loaded unit by unit by bin/rune-repl.load.rbc, so that the
# REPL and what it compiles share one Basis Library (incremental roadmap, M4)
# lib/terminal's editor (docs/plans/repl.md, M6), lib/pretty's layout (M7),
# lib/markdown (M8) and lib/jsonrpc (M10), after the compiler, which has
# lib/unicode and lib/json already
REPL_TERMINAL := $(addprefix lib/terminal/,style_sig.sml style.sml key_sig.sml key.sml device_sig.sml device.sml \
                   history_sig.sml history.sml line_edit_sig.sml line_edit_fn.sml line_edit.sml)
REPL_SRCS := build/config.sml $(SOURCES) $(REPL_TERMINAL) lib/pretty/pretty_sig.sml lib/pretty/pretty.sml \
             lib/markdown/entities.sml lib/markdown/markdown_sig.sml lib/markdown/markdown.sml \
             lib/jsonrpc/framing_sig.sml lib/jsonrpc/framing.sml lib/jsonrpc/jsonrpc_sig.sml lib/jsonrpc/jsonrpc.sml \
             src/repl/show.sml src/repl/session.sml src/repl/scan.sml src/repl/highlight.sml src/repl/complete.sml \
             src/repl/front.sml src/repl/doc.sml src/repl/search.sml src/repl/repl.sml src/repl/debug.sml src/repl/commands.sml \
             src/repl/engine.sml src/repl/protocol.sml src/main/repl-main.sml
bin/rune-repl.units/units: bin/rune-boot $(REPL_SRCS) lib/basis/MANIFEST $(wildcard lib/basis/*.sml)
	rm -rf bin/rune-repl.units
	bin/rune-boot --units --basis all --emit-units bin/rune-repl.units -o bin/rune-repl.rbc $(REPL_SRCS)
bin/rune-repl.load.rbc: bin/rune-boot src/repl/load.sml lib/basis/MANIFEST
	bin/rune-boot -o $@ src/repl/load.sml
# the REPL started once and saved once it has compiled its library again
# (docs/repl.md): what bin/rune-repl restores, its arguments the files to
# use; it reads the Basis's documentation for :doc before it is saved
bin/rune-repl.img: bin/rune-repl.units/units bin/rune-repl.load.rbc bin/runevm docs/lib/basis/members.json
	bin/runevm --heap-size 67108864 bin/rune-repl.load.rbc bin/rune-repl.units/units --make-image $@ < /dev/null
bin/rune-repl: bin/rune-repl.img
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ "$$1" = --dap ]; then shift; exec "$$d/rune-dap" "$$@"; fi\nexec "$$d/runevm" --heap-size 67108864 --restore "$$d/rune-repl.img" -- "$$@"\n' > $@
	chmod +x $@
# the same for Windows' command prompt, beside runevm.exe (M6)
bin/rune-repl.cmd: Makefile
	printf '@echo off\r\n"%%~dp0runevm.exe" --heap-size 67108864 --restore "%%~dp0rune-repl.img" -- %%*\r\n' > $@
repl: bin/rune-repl bin/rune-repl.cmd

# The REPL's transcripts, on every mode of the JIT (docs/repl.md)
test-repl: bin/rune-repl bin/runevm bin/rune-test
	$(RUNE_TEST) --tier test-repl

# rune-kernel, a Jupyter kernel for Standard ML (docs/kernel.md): a bridge
# in SML over lib/jupyter that drives the REPL's engine as its child
bin/rune-kernel.rbc: $(RUNE) src/front/engine.sml src/dap/translate.sml src/util/ident.sml src/kernel/kernel.sml manifests \
                     $(wildcard lib/jupyter/*.sml lib/zmtp/*.sml lib/digest/*.sml lib/json/*.sml lib/jsonrpc/*.sml lib/unicode/*.sml)
	$(RUNE) --library jupyter --library jsonrpc --library digest --library unicode src/front/engine.sml src/dap/translate.sml \
	  src/util/ident.sml src/kernel/kernel.sml -o $@
bin/rune-kernel: bin/rune-kernel.rbc bin/rune-repl.img bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" "$$d/rune-kernel.rbc" --vm "$$d/runevm" --image "$$d/rune-repl.img" --program "$$d/rune-kernel.rbc" "$$@"\n' > $@
	chmod +x $@
kernel: bin/rune-kernel
# and again with the engine's channel a connection, as on Windows
# (src/front/engine.sml)
test-kernel: bin/rune-kernel bin/rune-test
	$(RUNE_TEST) --tier test-kernel

# rune-dap, the Debug Adapter Protocol for Standard ML (docs/dap.md): an
# adapter in SML over lib/dap that drives the REPL's engine as its child;
# `rune-repl --dap` is it
bin/rune-dap.rbc: $(RUNE) src/front/engine.sml src/dap/translate.sml src/dap/adapter.sml manifests $(wildcard lib/dap/*.sml lib/json/*.sml lib/jsonrpc/*.sml)
	$(RUNE) --library dap --library jsonrpc src/front/engine.sml src/dap/translate.sml src/dap/adapter.sml -o $@
bin/rune-dap: bin/rune-dap.rbc bin/rune-repl.img bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" "$$d/rune-dap.rbc" --vm "$$d/runevm" --image "$$d/rune-repl.img" "$$@"\n' > $@
	chmod +x $@
dap: bin/rune-dap
test-dap: bin/rune-dap bin/rune-repl bin/rune-test
	$(RUNE_TEST) --tier test-dap

# The REPL's engine and its protocol (docs/repl-protocol.md): each script
# of tests/repl-protocol played to rune-repl --engine, as a front drives it
test-repl-protocol: bin/rune-repl bin/runevm bin/rune-test
	$(RUNE_TEST) --tier test-repl-protocol

# Programs on a terminal (docs/plans/repl.md, M1): each script of
# tests/terminal starts a program through the runtime PTY and checks its
# terminal model; its capability probe exercises that PTY boundary.
test-terminal: bin/rune-repl bin/runevm $(RUNE) bin/rune-terminal bin/rune-test
	$(RUNE_TEST) --tier test-terminal

# diagnostics rendered with colour, and the palette's contrast (docs/diagnostics.md)
test-diagnostics: $(RUNE) bin/rune-test
	$(RUNE_TEST) --tier test-diagnostics

# the cache's scenarios (tests/incremental/SCENARIOS.md; docs/units.md, The cache)
test-deps: $(RUNE) vm bin/rune-test bin/rune-scenarios
	$(RUNE_TEST) --tier test-deps

test-dynamic: $(RUNE) vm bin/rune-test bin/rune-scenarios
	$(RUNE_TEST) --tier test-dynamic

# build files (docs/build.md)
test-build: $(RUNE) vm bin/rune-test bin/rune-scenarios
	$(RUNE_TEST) --tier test-build

# make install staged and checked (bin/rune-scenarios install): the bytecode
# compiler's, and that of a host build of each kind, a program and a heap
test-install: all repl dap kernel mlton smlnj-legacy bin/runedoc-mlton bin/runeopt-mlton bin/runedoc-smlnj-legacy bin/runeopt-smlnj-legacy bin/rune-scenarios bin/rune-test
	RUNE_HEAP=$(RUNE_HEAP) SMLNJ=$(SMLNJ) $(RUNE_TEST) --tier test-install

# the distribution archives, with stand-in binaries (bin/rune-scenarios dist)
test-dist: bin/rune-scenarios bin/rune-test
	$(RUNE_TEST) --tier test-dist

# the compiler as a service, a prototype (src/driver/serve.sml)
test-serve: $(RUNE) vm basis-cache bin/rune-test
	$(RUNE_TEST) --tier test-serve

# the compiler the same bytes every way it is built (docs/units.md, Parallel builds)
check-reproducible: $(RUNE) vm basis-cache bin/rune.rbc bin/rune-test
	$(RUNE_TEST) --tier check-reproducible

test-incremental: $(RUNE) vm basis-cache bin/rune-repl bin/rune-test bin/rune-incremental bin/rune-external
	$(RUNE_TEST) --tier test-incremental

check-positions: $(RUNE) $(RUNEVM) bin/rune-test
	$(RUNE_TEST) --tier check-positions

check-docs: check-docs-generated bin/rune-test bin/rune-doc-check
	$(RUNE_TEST) --tier docs-consistency

check-docs-generated: $(RUNE) $(RUNEDOC) manifests
	$(RUNE_STACK) --basis-check
	$(RUNEDOC) --lint lib/basis/*.sml lib/random/*.sml lib/test/property/*.sml lib/test/property/basis/*.sml lib/test/property/basis/*/*.sml lib/test/unit/*.sml lib/test/runner/*.sml lib/language/c/*.sml lib/ffi/model/*.sml lib/ffi/marshal/*.sml lib/ffi/runtime/*.sml $(foreach l,$(REPL_LIBS),lib/$(l)/*.sml) src/*/*.sml && echo "lint-docs: OK (the comments of the libraries and of src are in the language of doc comments)"
	$(RUNEDOC) $(DOCS_BASIS) --check
	$(RUNEDOC) $(DOCS_RANDOM) --check
	$(RUNEDOC) $(DOCS_PROPERTY) --check
	$(RUNEDOC) $(DOCS_PROPERTY_BASIS) --check
	$(RUNEDOC) $(DOCS_UNIT) --check
	$(RUNEDOC) $(DOCS_RUNNER) --check
	$(RUNEDOC) $(DOCS_C) --check
	$(RUNEDOC) $(DOCS_FFI_MODEL) --check
	$(RUNEDOC) $(DOCS_FFI_MARSHAL) --check
	$(RUNEDOC) $(DOCS_FFI_RUNTIME) --check
	$(foreach l,$(REPL_LIBS),$(RUNEDOC) $(call docs_lib,$(l)) --check &&) true
	$(RUNEDOC) $(DOCS_OVERVIEW) --check
	$(RUNEDOC) --palette docs/lib/palette --check

# The generated documentation (docs/plans/docgen.md): `make docs` writes it,
# and it is committed; check-docs fails when it is not what the sources give.
# tests/basis/annotations.txt is what the suite knows about other implementations,
# made from deviations.txt by bin/rune-generate annotations and committed.
DOCS_BASIS := --lib lib --library basis --tests tests/basis --annotations tests/basis/annotations.txt \
              --law-skips tests/basis/law-skips.txt \
              --out docs/lib/basis \
              --conventions ../conventions.md --emit-conventions
# the libraries beside it (docs/plans/quickcheck.md, D1)
DOCS_RANDOM := --lib lib --library random --out docs/lib/random --basis-docs ../basis \
               --conventions ../conventions.md
DOCS_PROPERTY := --lib lib --library test/property --out docs/lib/test/property --basis-docs ../../basis \
                 --conventions ../../conventions.md
# the arbitraries of the Basis Library's types, the library beside it (in a
# directory of its own: runedoc removes from its output what it did not write)
DOCS_PROPERTY_BASIS := --lib lib --library test/property/basis --out docs/lib/test/property-basis \
                       --basis-docs ../../basis --library-docs test/property ../property \
                       --conventions ../../conventions.md
# the unit-testing library (docs/plans/unit-testing.md, M1)
DOCS_UNIT := --lib lib --library test/unit --out docs/lib/test/unit --basis-docs ../../basis \
             --library-docs test/property ../property \
             --conventions ../../conventions.md
# the runner (docs/plans/unit-testing.md, M3)
DOCS_RUNNER := --lib lib --library test/runner --out docs/lib/test/runner --basis-docs ../../basis \
               --library-docs test/unit ../unit --library-docs terminal ../../terminal \
               --conventions ../../conventions.md
DOCS_FFI_RUNTIME := --lib lib --library ffi/runtime --out docs/lib/ffi/runtime --basis-docs ../../basis \
                    --library-docs ffi/marshal ../marshal --conventions ../../conventions.md
DOCS_FFI_MARSHAL := --lib lib --library ffi/marshal --out docs/lib/ffi/marshal --basis-docs ../../basis \
                    --library-docs unicode ../../unicode --conventions ../../conventions.md
DOCS_FFI_MODEL := --lib lib --library ffi/model --out docs/lib/ffi/model --basis-docs ../../basis \
                  --library-docs json ../../json --library-docs language/c ../../language/c \
                  --conventions ../../conventions.md
DOCS_C := --lib lib --library language/c --out docs/lib/language/c --basis-docs ../../basis \
          --conventions ../../conventions.md
# the libraries of docs/plans/repl.md (The libraries), each in
# docs/lib/NAME (REPL_LIBS, with the manifests). The heading of the library's
# README.md is its name, on its pages and in the overview below.
docs_lib = --lib lib --library $(1) --out docs/lib/$(1) --basis-docs ../basis \
           --conventions ../conventions.md
# docs/lib/README.md, the overview of every library above, grouped by the
# Area of its README.md. The order here is the order of the areas and of
# the libraries in one. REL differs from the library's name only for
# test/property/basis, whose pages cannot share test/property: runedoc
# removes from an output directory what it did not write.
DOCS_OVERVIEW := --lib lib --overview docs/lib \
	--library-page basis \
	--library-page random \
	--library-page test/property \
	--library-page test/property/basis test/property-basis \
	--library-page test/unit \
	--library-page test/runner \
	--library-page unicode \
	--library-page pretty \
	--library-page markdown \
	--library-page terminal \
	--library-page json \
	--library-page jsonrpc \
	--library-page dap \
	--library-page zmtp \
	--library-page jupyter \
	--library-page digest \
	--library-page language/c \
	--library-page ffi/model \
	--library-page ffi/marshal \
	--library-page ffi/runtime

docs: $(RUNEDOC) manifests
	$(RUNEDOC) $(DOCS_BASIS)
	$(RUNEDOC) $(DOCS_RANDOM)
	$(RUNEDOC) $(DOCS_PROPERTY)
	$(RUNEDOC) $(DOCS_PROPERTY_BASIS)
	$(RUNEDOC) $(DOCS_UNIT)
	$(RUNEDOC) $(DOCS_RUNNER)
	$(RUNEDOC) $(DOCS_C)
	$(RUNEDOC) $(DOCS_FFI_MODEL)
	$(RUNEDOC) $(DOCS_FFI_MARSHAL)
	$(RUNEDOC) $(DOCS_FFI_RUNTIME)
	$(foreach l,$(REPL_LIBS),$(RUNEDOC) $(call docs_lib,$(l)) &&) true
	$(RUNEDOC) $(DOCS_OVERVIEW)
	$(RUNEDOC) --palette docs/lib/palette

# ---------------------------------------------------------------- Basis Library suite
# tests/basis/README.md. make test-basis is the suite in the configuration
# rune on the runner, and the examples of the documentation that are
# equations (tests/runner/basis.sml). The matrix targets compare Rune with
# other systems and are not part of `make check`; rune-matrix runs each
# program in its own directory, so $(RUNE) goes in absolute.
test-basis: $(RUNE) $(RUNEDOC) vm build/basis-examples/.done bin/rune-test | build/.doctor-check
	$(RUNE_TEST) --tier test-basis

# The examples of the Basis Library's documentation that are equations, a
# program for each signature that has them (runedoc --examples), which the
# runner compiles and runs (tests/runner/basis.sml)
build/basis-examples/.done: $(RUNEDOC) $(wildcard lib/basis/*.sml)
	rm -rf build/basis-examples && mkdir -p build/basis-examples
	$(RUNEDOC) --lib lib --library basis --examples build/basis-examples > build/basis-examples.log 2>&1 \
	  || { cat build/basis-examples.log; exit 1; }
	touch $@

# The tests of the documentation generator (tests/doc), with bin/runedoc;
# `make test-doc RUNEDOC=bin/runedoc-mlton` is the faster loop.
test-doc: $(RUNEDOC) vm manifests bin/rune-test
	$(RUNE_TEST) --tier test-doc

# The libraries beside the basis library and rune --library (tests/lib;
# docs/plans/quickcheck.md, D1).
test-lib: $(RUNE) $(RUNEDOC) vm manifests bin/rune-test
	$(RUNE_TEST) --tier test-lib

# The laws of the Basis Library's documentation, each at every structure that
# implements its signature (docs/plans/quickcheck.md, M8): every law holds,
# or tests/basis/law-skips.txt lists it (D12). In `make check` since the end
# of the hunt (M9); RUNE_PROPERTY_DEEP=1 runs the deep mode.
test-laws: $(RUNE) $(RUNEDOC) vm manifests build/laws/.done bin/rune-test
	$(RUNE_TEST) --tier test-laws

# The programs of the laws, one for each signature with a law (runedoc
# --laws), which the runner compiles and runs (tests/runner/laws.sml)
build/laws/.done: $(RUNEDOC) $(wildcard lib/basis/*.sml)
	rm -rf build/laws && mkdir -p build/laws
	$(RUNEDOC) --lib lib --library basis --laws build/laws > build/laws.log 2>&1 || { cat build/laws.log; exit 1; }
	touch $@

# The same libraries on the hosts, against their own Basis Library (after a
# change to a library, as matrix-quick is after one to lib/basis).
test-lib-hosts: manifests bin/rune-test
	$(RUNE_TEST) --tier test-lib-hosts

# The laws of the Basis Library's documentation on the other compilers
# (docs/plans/quickcheck.md, D10): the differences from Rune's last run of
# test-laws that tests/basis/law-deviations.txt does not explain. Not part of
# `make check`.
test-laws-hosts: $(RUNEDOC) manifests bin/rune-test bin/rune-laws-hosts
	RUNEDOC=$(RUNEDOC) bin/rune-laws-hosts

# The native code generator's own tests (tests/opt): after the suites, whose
# programs it checks and disassembles.
test-opt: $(RUNEOPT) $(RUNE) vm build/librune.a bin/rune.stack.rbc bin/runedoc.stack.rbc bin/rune-native-check bin/rune-test
	RUNEOPT=$(RUNEOPT) $(RUNE_TEST) --tier test-opt

# Deterministic budgets on what `runevm --count` reports, for benchmark
# programs, the compiler's compiles (hello, the bootstrap, programs that
# scale the module language) and runedoc (bin/rune-budget; --update
# after a deliberate change): Rune as shipped, bin/rune and bin/runevm, then
# the stack bytecode on runevm-stack against tests/perf/stack. About a minute.
perf-check: $(RUNE) bin/runedoc vm bin/rune.rbc bin/runedoc.rbc bin/rune.stack.rbc bin/runedoc.stack.rbc bin/rune-test bin/rune-budget bin/rune-bench-check | build/.doctor-check
	$(RUNE_TEST) --tier perf-check

# Not part of `make check`: a collection before every allocation makes a few
# tests quadratic. For VM changes, next to `make vm-asan`.
# The Basis Library suite keeps vectors of 200000 elements alive, so it gets
# a longer interval and time limit (about 4 minutes).
# The tested programs run on the stressed VM; the compiler keeps the plain one
# (bin/rune names bin/runevm outright), or every compile would be quadratic too.
GC_STRESS ?= 101
GC_STRESS_BASIS ?= 1009
test-stress: $(RUNE) vm bin/rune-test | build/.doctor-check
	GC_STRESS_BASIS=$(GC_STRESS_BASIS) $(RUNE_TEST) --tier test-stress

# ------------------------------------------------------------- native code
# The suites with every program translated by runeopt and run as native
# code (docs/native.md, Tests). bin/runevm-native takes what runevm-stack takes and
# does so (tests/runner/nativevm.sml), keeping each translation by the checksum
# of its bytecode, so every runner takes it as --vm. test-native runs
# tests/lang (tests/opt-skip.txt lists what native code does not do yet, and
# why) and the Basis Library suite (the rune:opt configuration) that way,
# checks that every program of tests/lang counts what runevm-stack counts, that
# the compiler, translated, compiles itself to bin/rune.stack.rbc, and that the
# debug information of those programs and the compiler is their line table
# (tests/runner/nativechecks.sml), and gdb and lldb stop where it says. Programs of
# runeopt are for Linux on x86-64: elsewhere it says so and does nothing.
NATIVE_HOST := $(shell [ "$$(uname -s) $$(uname -m)" = "Linux x86_64" ] && echo yes)

NATIVE_VM_SRCS := tests/runner/sh.sml tests/runner/children.sml tests/runner/nativevm.sml tests/runner/nativevm-main.sml
bin/runevm-native.rbc: $(RUNE) $(NATIVE_VM_SRCS) manifests
	$(RUNE) --library test/runner --library digest $(NATIVE_VM_SRCS) -o $@
bin/runevm-native: bin/runevm-native.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" "$$d/runevm-native.rbc" "$$d/.." "$$@"\n' > $@
	chmod +x $@

ifeq ($(NATIVE_HOST),yes)
# test-native-steps reads the stack compiler's bytecode of every program of
# tests/lang in tests/out, which the runner's tier makes first.
test-native: bin/runevm-native bin/runeopt-mlton bin/rune-native-check build/librune.a $(RUNE) vm bin/rune.stack.rbc bin/rune-test | build/.doctor-native
	$(RUNE_TEST) --tier test-native
# Compatibility entry point for the native generator's count/debug/bootstrap checks.
test-native-steps: bin/runevm-native bin/runeopt-mlton bin/rune-native-check build/librune.a $(RUNE) vm bin/rune.stack.rbc bin/rune-test | build/.doctor-native
	$(RUNE_TEST) 'native/code/*'

# Extra stress ways use the same cases and limits as the normal native way.
test-native-stress: bin/runevm-native bin/runeopt-mlton build/librune.a $(RUNE) vm bin/rune-test | build/.doctor-native
	GC_STRESS_BASIS=$(GC_STRESS_BASIS) $(RUNE_TEST) --tier test-native-stress

ASAN_CFLAGS := -std=c17 -g -O1 -Wall -Wextra -fsanitize=address,undefined -fno-omit-frame-pointer

build/asan/librune.a: build/foreign-selected $(RT_SRCS) runtime/sys/sys_$(SYS).c runtime/native/native.c build/rune-offsets.s $(VM_HDRS) | build/.doctor-asan
	@mkdir -p build/asan/obj
	for f in $(RT_SRCS) runtime/sys/sys_$(SYS).c runtime/native/native.c; do \
	  $(CC) $(ASAN_CFLAGS) $(RT_INC) $(FFI_FLAGS) -c -o build/asan/obj/$$(basename $$f .c).o $$f || exit 1; done
	cp build/rune-offsets.s build/asan/rune-offsets.s
	cp build/foreign-libs build/asan/foreign-libs
	rm -f $@
	$(AR) rcs $@ build/asan/obj/*.o
	rm -rf tests/out/opt-cache-asan

test-native-asan: bin/runevm-native bin/runeopt-mlton build/asan/librune.a $(RUNE) vm bin/rune-test | build/.doctor-native
	$(RUNE_TEST) --tier test-native-asan

else
test-native test-native-steps test-native-stress test-native-asan:
	@echo "$@: runeopt makes programs for Linux on x86-64, and this is not one: nothing to test"
endif

hosts: | build/.doctor-matrix
	sh scripts/fetch-hosts.sh

MATRIX_DOCTOR := build/.doctor-mlton build/.doctor-smlnj-legacy build/.doctor-smlnj32 build/.doctor-smlnj-dev build/.doctor-polyml build/.doctor-mlkit build/.doctor-check

matrix-quick: $(RUNE) vm bin/rune-matrix bin/rune-test | $(MATRIX_DOCTOR)
	RUNE=$(abspath $(RUNE_STACK)) RUNEVM=$(abspath $(RUNEVM)) \
	  bin/rune-matrix -j $(JOBS) --configs rune,xc1

matrix: $(RUNE) vm bin/rune-matrix bin/rune-test | $(MATRIX_DOCTOR)
	RUNE=$(abspath $(RUNE_STACK)) RUNEVM=$(abspath $(RUNEVM)) \
	  bin/rune-matrix -j $(JOBS) --configs all

# The wall-clock times of tests/perf (tests/out/perf/wall.md): `rune` is Rune
# as shipped, bin/rune and bin/runevm at its default JIT level; the stack VM
# is the configuration rune:stack (PERF_CONFIGS=rune,rune:stack,hosts).
PERF_CONFIGS ?= all

perf: $(RUNE) vm bin/rune-matrix bin/rune-test | $(MATRIX_DOCTOR)
	RUNE=$(abspath $(RUNE_STACK)) RUNEVM=$(abspath $(RUNEVM)) \
	  RUNE_NEW=$(abspath $(RUNE)) RUNEVM_NEW=$(abspath $(RUNEVM_REGISTER)) \
	  bin/rune-matrix --perf --configs $(PERF_CONFIGS)

# ---------------------------------------------------------------- bootstrap
# Stage 1: a host build compiles the compiler to bytecode. bin/rune-boot runs
# it on runevm and is what bin/rune names; `bootstrap` checks that it
# reproduces itself byte for byte. check-cross knows the build as `boot`.
# All host builds emit the same bytecode, so BOOTHOST (mlton, smlnj-legacy,
# smlnj32, smlnj-dev, polyml or mlkit) only decides which one builds stage 1,
# not what comes out.
bin/rune.rbc: bin/rune-$(BOOTHOST) bin/runevm $(BOOT_SRCS) lib/basis/MANIFEST $(wildcard lib/basis/*.sml)
	bin/rune-$(BOOTHOST) --lint --mid-roundtrip -o $@ $(BOOT_SRCS)

# The same compiler in the stack bytecode, which runevm-stack runs: what the
# suites of the stack VM, runeopt's translations and its budgets are made of.
bin/rune.stack.rbc: bin/rune-$(BOOTHOST) bin/runevm-stack $(BOOT_SRCS) lib/basis/MANIFEST $(wildcard lib/basis/*.sml)
	bin/rune-$(BOOTHOST) --target=stack --lint --mid-roundtrip -o $@ $(BOOT_SRCS)

# bin/rune making the register bytecode of runtime/register
# The suites through runtime/register's first loop (docs/plans/middle-end.md, M5): the
# tests of the language, allocation and the bootstrap against runevm-stack, and
# the Basis Library.
test-register: bin/runevm $(RUNE) vm bin/rune.stack.rbc bin/rune-test
	$(RUNE_TEST) --tier test-register

# The suites through runtime/register with every function given to the JIT
# (--jit=all; docs/plans/jit.md, M3, M4): tests/lang on a wrapper that
# passes the option; every program of tests/lang and tests/perf, and the
# primitives on their edge cases, printing and counting the same
# interpreted and compiled (tests/runner/oracles.sml (jit)); the Basis Library suite
# as rune:jit; the executable memory of the system layer (--jit-check);
# and a recursion 200,000 deep under a machine stack of 1 MB, which holds
# the driver to never nesting, compiled at load and while tiering up and
# invalidating (M6).
build/register/x64_test: tests/register/x64_test.c runtime/register/jit/x64.c runtime/sys/sys_$(SYS).c $(VM_HDRS) Makefile
	@mkdir -p build/register
	$(CC) $(CFLAGS) $(RT_INC) -o $@ tests/register/x64_test.c runtime/register/jit/x64.c runtime/sys/sys_$(SYS).c
build/register/a64_test: tests/register/a64_test.c runtime/register/jit/a64.c $(VM_HDRS) Makefile
	@mkdir -p build/register
	$(CC) $(CFLAGS) $(RT_INC) -o $@ tests/register/a64_test.c runtime/register/jit/a64.c
build/register/masm_test: tests/register/masm_test.c runtime/register/jit/masm.c runtime/register/jit/x64.c runtime/register/jit/asm_x64.c runtime/sys/sys_$(SYS).c $(VM_HDRS) Makefile
	@mkdir -p build/register
	$(CC) $(CFLAGS) $(RT_INC) -o $@ tests/register/masm_test.c runtime/register/jit/masm.c runtime/register/jit/x64.c runtime/register/jit/asm_x64.c runtime/sys/sys_$(SYS).c
bin/runevm-jit: bin/runevm Makefile
	printf '#!/bin/sh\nexec "$(ROOT)/bin/runevm" --jit=all "$$@"\n' > $@
	chmod +x $@
bin/runevm-opt: bin/runevm Makefile
	printf '#!/bin/sh\nexec "$(ROOT)/bin/runevm" --jit=all --jit-tier=2 "$$@"\n' > $@
	chmod +x $@
test-register-jit: bin/runevm-jit bin/runevm-opt $(LOW_LEVEL_BINS) $(RUNE) bin/rune-test
	$(RUNE_TEST) --tier test-register-jit
test-register-jit-steps: bin/runevm-jit bin/runevm-opt $(LOW_LEVEL_BINS) $(RUNE) bin/rune-test
	$(RUNE_TEST) --tier test-register-jit-steps

bin/rune-boot: bin/rune.rbc Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\n$(RUNE_I)exec "$$d/runevm" --heap-size $(RUNE_HEAP) "$$d/rune.rbc" --lib "$$d/../lib" "$$@"\n' > $@
	chmod +x $@

bin/rune: bin/rune-boot
	ln -sf rune-boot $@

boot: bin/rune

# runedoc compiled by the self-hosted compiler.
DOC_SRCS := build/config.sml $(SOURCES_DOC) src/main/runedoc-rune-main.sml

bin/runedoc.rbc: bin/rune bin/rune.rbc $(DOC_SRCS)
	bin/rune -o $@ $(DOC_SRCS)

# runedoc in the stack bytecode, which the budgets of runevm-stack measure
# (bin/rune-budget --stack) and runeopt translates (tests/opt).
bin/runedoc.stack.rbc: bin/rune bin/rune.rbc $(DOC_SRCS)
	bin/rune --target=stack -o $@ $(DOC_SRCS)

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

# runeopt in the stack bytecode, which runeopt itself translates in the
# cross-check of its builds (tests/runner/oracles.sml (cross)).
bin/runeopt.stack.rbc: bin/rune bin/rune.rbc $(OPT_SRCS)
	bin/rune --target=stack -o $@ $(OPT_SRCS)

bin/runeopt-boot: bin/runeopt.rbc Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" --heap-size $(RUNE_HEAP) "$$d/runeopt.rbc" --runtime "$$d/../build" "$$@"\n' > $@
	chmod +x $@
	rm -rf tests/out/opt-cache tests/out/opt-cache-asan

bin/runeopt: bin/runeopt-boot
	ln -sf runeopt-boot $@

runeopt: bin/runeopt

bootstrap: bin/rune-boot bin/rune.stack.rbc bin/rune-test
	$(RUNE_TEST) --tier bootstrap

check test test-all test-opt test-native test-register test-register-jit test-stress test-heap test-windows test-portability perf-check: export RUNEVM_INTINF = sml
# The test runner (docs/plans/unit-testing.md, M3; docs/testing.md, Running
# the tests): the inventory of tests/runner over lib/test/runner, compiled
# by $(RUNE) and run on the register VM with its JIT.
RUNNER_SRCS := tests/runner/canary.sml tests/runner/langchecks.sml tests/runner/lang.sml tests/runner/basis.sml tests/runner/laws.sml tests/runner/sh.sml \
               tests/runner/hosts.sml tests/runner/libhosts.sml tests/runner/hostchecks.sml \
               tests/runner/migration.sml \
               tests/runner/children.sml tests/runner/buildchecks.sml tests/runner/bytecode.sml tests/runner/windowsdir.sml tests/runner/nativevm.sml tests/runner/nativechecks.sml tests/runner/nativefaults.sml tests/runner/native.sml \
               tests/runner/matrixmodel.sml tests/runner/matrixprobe.sml tests/runner/matrixhost.sml tests/runner/smlscan.sml tests/runner/programselect.sml tests/runner/hostlaws.sml tests/runner/matrixfaults.sml \
               tests/runner/docchecks.sml tests/runner/mutants.sml tests/runner/docfaults.sml \
               tests/runner/matrixload.sml tests/runner/matrixprepare.sml tests/runner/matrixsuite.sml tests/runner/matrixprogram.sml tests/runner/matrixperf.sml tests/runner/matrixexecutionfaults.sml tests/runner/matrixcachefaults.sml tests/runner/matrix.sml \
               tests/runner/tracecheck.sml tests/runner/heapchecks.sml tests/runner/censustrace.sml tests/runner/heapfaults.sml tests/runner/jitdumpcheck.sml tests/runner/heap.sml \
               examples/benchmarks/shared/catalog.sml tests/runner/budgets.sml tests/runner/budgetfaults.sml tests/runner/benchcases.sml tests/runner/benchchecks.sml \
               tests/runner/benchmarkrun.sml tests/runner/benchmarkextras.sml tests/runner/benchmarkfaults.sml tests/runner/benchmarkmeasurement.sml tests/runner/inventorytests.sml tests/runner/benchmarks.sml \
               tests/runner/scenarios.sml tests/runner/installchecks.sml tests/runner/binaryfixtures.sml tests/runner/archivecheck.sml tests/runner/distchecks.sml tests/runner/scenariojobs.sml \
               tests/runner/cacheplant.sml tests/runner/incrementalfixtures.sml tests/runner/incremental.sml tests/runner/incrementalextra.sml tests/runner/intinfjobs.sml tests/runner/measurementjobs.sml tests/runner/gmpjobs.sml \
               tests/runner/oracles.sml tests/runner/tools.sml tests/runner/terminaljobs.sml tests/runner/protocols.sml tests/runner/vmchecks.sml tests/runner/vmoracles.sml tests/runner/windowschecks.sml tests/runner/platformfaults.sml tests/runner/windowsjobs.sml tests/runner/portability.sml \
               tests/runner/ffimodeljobs.sml tests/runner/ffijobs.sml tests/runner/main.sml
bin/rune-test.rbc: $(RUNE) $(RUNNER_SRCS) manifests \
                   $(wildcard lib/test/runner/*.sml lib/test/unit/*.sml lib/test/property/*.sml lib/random/*.sml lib/terminal/*.sml lib/json/*.sml lib/digest/*.sml)
	$(RUNE) --library test/runner --library json --library digest $(RUNNER_SRCS) -o $@
bin/rune-test: bin/rune-test.rbc bin/runevm Makefile bin/rune-generate bin/rune-inventory
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" "$$d/rune-test.rbc" "$$@"\n' > $@
	chmod +x $@

# Individual SML native checks avoid rebuilding the complete test inventory
# in every worker process. Scheduling and requirements remain in rune-test.
NATIVE_CHECK_SRCS := tests/runner/sh.sml tests/runner/children.sml tests/runner/bytecode.sml \
                     tests/runner/nativevm.sml tests/runner/nativechecks.sml tests/runner/nativechecks-main.sml
bin/rune-native-check.rbc: $(RUNE) $(NATIVE_CHECK_SRCS) manifests
	$(RUNE) --library test/runner --library digest $(NATIVE_CHECK_SRCS) -o $@
bin/rune-native-check: bin/rune-native-check.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" "$$d/rune-native-check.rbc" "$$@"\n' > $@
	chmod +x $@

# Bounded heap/census actions share the same runner metadata and supervisor.
HEAP_CHECK_SRCS := tests/runner/sh.sml tests/runner/children.sml tests/runner/bytecode.sml \
                   tests/runner/tracecheck.sml tests/runner/heapchecks.sml tests/runner/censustrace.sml \
                   tests/runner/heapfaults.sml tests/runner/jitdumpcheck.sml tests/runner/heap.sml tests/runner/heapchecks-main.sml
bin/rune-heap-check.rbc: $(RUNE) $(HEAP_CHECK_SRCS) manifests
	$(RUNE) --library test/runner $(HEAP_CHECK_SRCS) -o $@
bin/rune-heap-check: bin/rune-heap-check.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-heap-check.rbc" "$$@"\n' > $@
	chmod +x $@

HOST_LAWS_SRCS := tests/runner/sh.sml tests/runner/hosts.sml tests/runner/children.sml tests/runner/windowsdir.sml \
                  tests/runner/matrixmodel.sml tests/runner/matrixprobe.sml tests/runner/matrixhost.sml \
                  tests/runner/smlscan.sml tests/runner/programselect.sml tests/runner/hostlaws.sml
bin/rune-laws-hosts.rbc: $(RUNE) $(HOST_LAWS_SRCS) tests/runner/hostlaws-main.sml manifests
	$(RUNE) --library test/runner $(HOST_LAWS_SRCS) tests/runner/hostlaws-main.sml -o $@
bin/rune-laws-hosts: bin/rune-laws-hosts.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-laws-hosts.rbc" "$$@"\n' > $@
	chmod +x $@

DOC_CHECK_SRCS := $(HOST_LAWS_SRCS) tests/runner/bytecode.sml tests/runner/docchecks.sml \
                  tests/runner/mutants.sml tests/runner/docfaults.sml tests/runner/docchecks-main.sml
bin/rune-doc-check.rbc: $(RUNE) $(DOC_CHECK_SRCS) manifests
	$(RUNE) --library test/runner $(DOC_CHECK_SRCS) -o $@
bin/rune-doc-check: bin/rune-doc-check.rbc bin/runevm Makefile bin/rune-generate bin/rune-inventory
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-doc-check.rbc" "$$@"\n' > $@
	chmod +x $@
test-mutants: $(RUNEDOC) vm manifests bin/rune-test bin/rune-doc-check
	bin/rune-doc-check mutants $(if $(filter command line environment,$(origin JOBS)),-j $(JOBS))

MATRIX_SRCS := $(HOST_LAWS_SRCS) tests/runner/matrixload.sml tests/runner/matrixprepare.sml \
               tests/runner/matrixsuite.sml tests/runner/matrixprogram.sml tests/runner/matrixperf.sml tests/runner/matrixexecutionfaults.sml tests/runner/matrixcachefaults.sml tests/runner/matrix.sml
bin/rune-matrix.rbc: $(RUNE) $(MATRIX_SRCS) tests/runner/matrix-main.sml manifests
	$(RUNE) --library test/runner --library digest $(MATRIX_SRCS) tests/runner/matrix-main.sml -o $@
bin/rune-matrix: bin/rune-matrix.rbc bin/runevm Makefile bin/rune-generate bin/rune-inventory
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-matrix.rbc" "$$@"\n' > $@
	chmod +x $@

# Everything a step of make check needs, built before the runner starts, so
# that two steps that run at once never build one file (each step is a make
# of its own).
CHECK_TOOLS := host-builds vm boot runedoc runeopt manifests basis-cache all repl dap kernel mlton smlnj-legacy \
               bin/rune-boot bin/rune.rbc bin/rune.stack.rbc bin/runedoc.rbc bin/runedoc.stack.rbc bin/runeopt.stack.rbc \
               bin/runedoc-mlton bin/runeopt-mlton bin/runedoc-smlnj-legacy bin/runeopt-smlnj-legacy \
               build/librune.a bin/runevm-gcbits bin/runevm-cards \
               bin/runevm-census heapsim bin/runeisa-mlton bin/runeisa.rbc build/bench-catalog.rbc \
               build/.doctor-check bin/rune-test build/basis-examples/.done build/laws/.done \
               $(if $(filter yes,$(NATIVE_HOST)),bin/runevm-native bin/runeopt-templates build/.doctor-native)
check-tools: $(LOW_LEVEL_BINS) bin/runevm-jit bin/runevm-opt bin/rune-build bin/rune-build.rbc bin/rune-generate bin/rune-inventory bin/rune-measure $(CHECK_TOOLS) bin/runevm-sml build/intinf-alloc-test bin/rune-native-check bin/rune-heap-check bin/rune-laws-hosts bin/rune-doc-check bin/rune-matrix bin/rune-budget bin/rune-bench-check bin/rune-scenarios bin/rune-incremental bin/rune-external bin/rune-intinf bin/rune-windows bin/rune-suite bin/rune-protocol-check bin/rune-terminal bin/rune-ffi-check build/bench-counts.rbc

# The tier quick: tests/lang in its first way, the libraries, tests/doc and
# the canaries, under a minute (docs/testing.md, Tiers, profiles and what
# changed).
quick: $(RUNE) vm runedoc manifests bin/rune-test | build/.doctor-check
	$(RUNE_TEST) --tier quick

# The tests of the tier check, each step of the old recipe a test of the
# runner, run at once where they share no files (tests/runner/main.sml), on
# the CPUs of the machine less its load from outside, or on JOBS when it is
# set. Each step is a make of its own, by the make that runs this one (named
# through a variable of its own, or make would take the runner for a make).
CHECK_MAKE := $(MAKE)
check: check-tools
	$(RUNE_TEST) --tier check

clean:
	rm -rf bin build tests/out dist
	find . -type d \( -name .cm -o -name MLB \) -prune -exec rm -rf {} +

.PHONY: test-intinf
test-intinf: $(RUNE) bin/runevm bin/runevm-stack bin/rune-intinf bin/rune-test
	INTINF_RUNE=$(abspath $(RUNE)) $(RUNE_TEST) --tier test-intinf

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
	  $(MAKE) --no-print-directory $(if $(HOST),vm $(HOST) $(if $(filter smlnj-legacy,$(HOST)),bin/runedoc-smlnj-legacy bin/runeopt-smlnj-legacy,bin/runedoc-$(HOST) bin/runeopt-$(HOST)) build/librune.a,all repl bin/rune-build bin/rune-build.rbc); \
	fi
	RUNE_HEAP=$(RUNE_HEAP) SMLNJ=$(SMLNJ) sh scripts/install.sh $(INSTALL_FLAGS)

uninstall:
	sh scripts/install.sh --uninstall $(INSTALL_FLAGS)

# Distribution archives (docs/building.md, Distribution). The version is
# git's, the one runtime/version.h already carries. Phony: the archives
# land in the dist/ directory, whose stamp is not the archives'.
dist: bin/rune-build runtime/version.h manifests bin/rune.rbc bin/rune-repl.img \
      bin/dist/runevm bin/dist/runevm32 bin/dist/runevm-aarch64 bin/dist/runevm-ppc64 \
      bin/dist/runevm.exe bin/dist/runevm32.exe
	@mkdir -p dist
	bin/rune-build make-dist --out dist \
	  --version "$$(sed -n 's/^#define RUNE_VERSION "\(.*\)"$$/\1/p' runtime/version.h)" \
	  --lib lib --compiler bin/rune.rbc --repl bin/rune-repl.img \
	  --linux x86_64=bin/dist/runevm --linux i686=bin/dist/runevm32 \
	  --linux aarch64=bin/dist/runevm-aarch64 --linux ppc64=bin/dist/runevm-ppc64 \
	  --windows x86_64=bin/dist/runevm.exe --windows i686=bin/dist/runevm32.exe

# Portable suite correctness, serial measurements and deterministic counts
# (docs/plans/benchmarks.md). Timing thresholds stay outside make check.
BENCH_PROFILE ?= $(if $(filter bench bench-count bench-stats,$(MAKECMDGOALS)),normal,smoke)
# timed: `rune` is Rune as shipped (bin/rune-measure benchmarks); the stack
# VM is rune:stack
BENCH_TIMING_CONFIGS = rune,native:mlton,native:smlnj-legacy,native:polyml
BENCH_COUNT_CONFIGS = rune,rune:jit,rune:stack,rune:opt
BENCH_CHECK_CONFIGS = rune,hosts
BENCH_CONFIGS ?= $(if $(filter bench-count bench-stats,$(MAKECMDGOALS)),$(BENCH_COUNT_CONFIGS),$(if $(filter bench,$(MAKECMDGOALS)),$(BENCH_TIMING_CONFIGS),$(BENCH_CHECK_CONFIGS)))
BENCH_FILTER ?=
.PHONY: bench-check bench-check-all bench-smoke bench bench-count bench-stats
build/bench-catalog.rbc: examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/catalog-main.sml $(RUNE)
	$(RUNE_STACK) --lint examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/catalog-main.sml -o $@

build/bench-coverage.rbc: examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/coverage.sml examples/benchmarks/shared/coverage-main.sml $(RUNE)
	$(RUNE) --lint examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/coverage.sml examples/benchmarks/shared/coverage-main.sml -o $@

.PHONY: bench-coverage
bench-coverage: build/bench-coverage.rbc vm
	bin/runevm build/bench-coverage.rbc --check

bench-check: build/bench-catalog.rbc vm bin/rune-test bin/rune-bench-check
	bin/runevm-stack build/bench-catalog.rbc --check
	BENCH_PROFILE=$(BENCH_PROFILE) BENCH_CONFIGS=$(BENCH_CONFIGS) BENCH_FILTER='$(BENCH_FILTER)' bin/rune-bench-check catalogue

# Bounded correctness/metadata only; wall-clock thresholds stay outside check.
bench-smoke: build/bench-catalog.rbc build/bench-report.rbc build/bench-counts.rbc build/bench-coverage.rbc vm bin/rune-test bin/rune-bench-check
	bin/runevm build/bench-coverage.rbc --check
	$(RUNE_TEST) --tier bench-smoke

# Every imported program has a smoke and normal profile. This explicit target
# covers the complete catalogue; request extra hosts/engines through filters.
bench-check-all: build/bench-catalog.rbc vm bin/rune-test bin/rune-bench-check
	bin/runevm-stack build/bench-catalog.rbc --check
	bin/rune-bench-check catalogue --profile smoke --configs '$(BENCH_CONFIGS)' --filter '$(BENCH_FILTER)'
	bin/rune-bench-check catalogue --profile normal --configs '$(BENCH_CONFIGS)' --filter '$(BENCH_FILTER)'

build/bench-report.rbc: examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/report.sml examples/benchmarks/shared/report-main.sml $(RUNE)
	$(RUNE_STACK) --lint examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/report.sml examples/benchmarks/shared/report-main.sml -o $@

build/bench-counts.rbc: examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/counts.sml examples/benchmarks/shared/counts-main.sml $(RUNE)
	$(RUNE_STACK) --lint examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/counts.sml examples/benchmarks/shared/counts-main.sml -o $@

bench bench-count bench-stats: bin/rune-measure build/bench-catalog.rbc build/bench-report.rbc build/bench-counts.rbc vm
	bin/runevm-stack build/bench-catalog.rbc --check
	BENCH_PROFILE=$(BENCH_PROFILE) BENCH_CONFIGS=$(BENCH_CONFIGS) BENCH_FILTER='$(BENCH_FILTER)' BENCH_LEVEL=$(BENCH_LEVEL) BENCH_MODE=$(BENCH_MODE) BENCH_SAMPLES=$(BENCH_SAMPLES) BENCH_REPETITIONS=$(BENCH_REPETITIONS) bin/rune-measure benchmarks $(if $(filter bench-count,$@),count,$(if $(filter bench-stats,$@),stats,time))

.PHONY: test-intinf-backends
test-intinf-backends: $(RUNE) bin/runevm bin/runevm-sml bin/rune-intinf bin/rune-test
	INTINF_RUNE=$(abspath $(RUNE)) $(RUNE_TEST) --tier test-intinf-backends

build/intinf-alloc-test: tests/intinf/alloc-failure.c runtime/intinf.c build/librune.a $(VM_HDRS) $(GMP_DIR)/config.mk build/gmp/selected
	$(CC) $(CFLAGS) $(RT_INC) $(GMP_FLAGS) -o $@ tests/intinf/alloc-failure.c build/librune.a $(GMP_LDLIBS) $(VM_LIBS)

.PHONY: test-intinf-hardening
test-intinf-hardening: $(RUNE) $(RUNEOPT) vm bin/runevm-sml build/intinf-alloc-test bin/rune-intinf bin/rune-test
	INTINF_RUNE=$(abspath $(RUNE)) NATIVE_HOST=$(NATIVE_HOST) $(RUNE_TEST) --tier test-intinf-hardening


.PHONY: test-intinf-cross
test-intinf-cross: bin/rune-intinf
	bin/rune-intinf prepare-cross --jobs $(JOBS) --prefix '$(if $(GMP_PREFIX),$(GMP_PREFIX),build/deps/gmp/native)'
	bin/rune-intinf dependency --require-all
	bin/rune-intinf cross --sml-vms tests/out/intinf/cross-builds/sml-vms

.PHONY: test-intinf-dependency
test-intinf-dependency: bin/rune-intinf bin/rune-test
	$(RUNE_TEST) --tier test-intinf-dependency

# SML benchmark/scenario workers. Entry scripts only locate their payloads.
BUDGET_SRCS := tests/runner/sh.sml tests/runner/children.sml tests/runner/budgets.sml tests/runner/budgets-main.sml
bin/rune-budget.rbc: $(RUNE) $(BUDGET_SRCS) manifests
	$(RUNE) --library test/runner $(BUDGET_SRCS) -o $@
BENCH_CHECK_SRCS := $(HOST_LAWS_SRCS) tests/runner/matrixload.sml tests/runner/matrixprepare.sml tests/runner/matrixsuite.sml tests/runner/matrixprogram.sml \
                    examples/benchmarks/shared/catalog.sml tests/runner/budgets.sml tests/runner/budgetfaults.sml tests/runner/benchcases.sml tests/runner/benchchecks.sml \
                    tests/runner/benchmarkrun.sml tests/runner/benchmarkextras.sml tests/runner/benchmarkfaults.sml tests/runner/benchmarkmeasurement.sml \
                    tests/runner/inventorytests.sml tests/runner/benchmarks.sml tests/runner/benchmarks-main.sml
bin/rune-bench-check.rbc: $(RUNE) $(BENCH_CHECK_SRCS) tests/runner/benchmark-cases.json tests/runner/inventory-cases.json manifests
	$(RUNE) --library test/runner --library json --library digest $(BENCH_CHECK_SRCS) -o $@
SCENARIO_SRCS := tests/runner/sh.sml tests/runner/hosts.sml tests/runner/children.sml tests/runner/scenarios.sml tests/runner/windowsdir.sml tests/runner/installchecks.sml \
                 tests/runner/binaryfixtures.sml tests/runner/archivecheck.sml tests/runner/distchecks.sml tests/runner/scenariojobs.sml tests/runner/scenarios-main.sml
bin/rune-scenarios.rbc: $(RUNE) $(SCENARIO_SRCS) manifests
	$(RUNE) --library test/runner --library json $(SCENARIO_SRCS) -o $@
bin/rune-budget bin/rune-bench-check bin/rune-scenarios: bin/%: bin/%.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/$(notdir $@).rbc" "$$@"\n' > $@
	chmod +x $@

# Incremental edits, cache corruption and externally provisioned corpora.
INCREMENTAL_BASE_SRCS := tests/runner/sh.sml tests/runner/hosts.sml tests/runner/children.sml tests/runner/scenarios.sml \
                         tests/runner/cacheplant.sml tests/runner/incrementalfixtures.sml tests/runner/incremental.sml
INCREMENTAL_SRCS := $(INCREMENTAL_BASE_SRCS) tests/runner/incrementalextra.sml tests/runner/smlscan.sml \
                    tests/runner/mutationproject.sml tests/runner/mutationchecks.sml tests/runner/mutationhistory.sml \
                    tests/runner/mltonincremental.sml tests/runner/incrementalfaults.sml tests/runner/incremental-main.sml
bin/rune-incremental.rbc: $(RUNE) $(INCREMENTAL_SRCS) tests/runner/incremental-edits-v1.json manifests
	$(RUNE) --library test/runner --library json $(INCREMENTAL_SRCS) -o $@
bin/rune-incremental: bin/rune-incremental.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-incremental.rbc" "$$@"\n' > $@
	chmod +x $@
EXTERNAL_SRCS := $(INCREMENTAL_BASE_SRCS) tests/runner/externalchecks.sml tests/runner/external-main.sml
bin/rune-external.rbc: $(RUNE) $(EXTERNAL_SRCS) manifests
	$(RUNE) --library test/runner --library json $(EXTERNAL_SRCS) -o $@
bin/rune-external: bin/rune-external.rbc bin/runevm Makefile bin/rune-generate bin/rune-inventory
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-external.rbc" "$$@"\n' > $@
	chmod +x $@

INTINF_SRCS := $(INCREMENTAL_BASE_SRCS) tests/runner/bytecode.sml tests/runner/commandwords.sml \
               tests/runner/intinfchecks.sml tests/runner/measured.sml tests/runner/intinfmeasurements.sml \
               tests/runner/intinfbackends.sml tests/runner/intinfhardening.sml tests/runner/intinfstorage.sml \
               tests/runner/windowsdir.sml tests/runner/gmpchecks.sml tests/runner/gmpdownloadchecks.sml tests/runner/gmpinstallchecks.sml tests/runner/gmpplatformchecks.sml tests/runner/intinffaults.sml tests/runner/intinffixtures.sml tests/runner/intinf-main.sml
bin/rune-intinf.rbc: $(RUNE) $(INTINF_SRCS) $(wildcard tests/intinf/fixtures/*) manifests
	$(RUNE) --library test/runner --library json --library digest $(INTINF_SRCS) -o $@
bin/rune-intinf: bin/rune-intinf.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-intinf.rbc" "$$@"\n' > $@
	chmod +x $@

FFI_CHECK_SRCS := tests/runner/sh.sml tests/runner/children.sml tests/ffi/check.sml
bin/rune-ffi-check.rbc: $(RUNE) $(FFI_CHECK_SRCS) manifests
	$(RUNE) --library test/runner --library json --library digest $(FFI_CHECK_SRCS) -o $@
bin/rune-ffi-check: bin/rune-ffi-check.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-ffi-check.rbc" "$$@"\n' > $@
	chmod +x $@
bin/rune-cfrontend.rbc: $(RUNE) tools/cfrontend/main.sml $(wildcard lib/language/c/*.sml) manifests
	$(RUNE) --library json --library language/c tools/cfrontend/main.sml -o $@
bin/rune-cfrontend: bin/rune-cfrontend.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" "$$d/rune-cfrontend.rbc" "$$@"\n' > $@
	chmod +x $@
bin/rune-ffi-model.rbc: $(RUNE) tools/ffimodel/main.sml $(wildcard lib/ffi/model/*.sml) manifests
	$(RUNE) --library ffi/model tools/ffimodel/main.sml -o $@
bin/rune-ffi-model: bin/rune-ffi-model.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec "$$d/runevm" "$$d/rune-ffi-model.rbc" "$$@"\n' > $@
	chmod +x $@

FFI_MODEL_CHECK_SRCS := tests/runner/sh.sml tests/runner/hosts.sml tests/runner/children.sml tests/ffi/model-check.sml
check-tools: bin/rune-ffi-model bin/rune-ffi-model-check
bin/rune-ffi-model-check.rbc: $(RUNE) $(FFI_MODEL_CHECK_SRCS) manifests
	$(RUNE) --library test/runner --library json $(FFI_MODEL_CHECK_SRCS) -o $@
bin/rune-ffi-model-check: bin/rune-ffi-model-check.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-ffi-model-check.rbc" "$$@"\n' > $@
	chmod +x $@
.PHONY: test-ffi-model test-ffi-model-windows test-ffi-model-hosts
test-ffi-model: $(RUNE) vm bin/rune-ffi-model bin/rune-ffi-model-check bin/rune-test
	$(RUNE_TEST) --tier test-ffi-model
test-ffi-model-windows: $(RUNE) vm bin/rune-ffi-model bin/rune-ffi-model-check bin/rune-test bin/rune-windows
	$(RUNE_TEST) --tier test-ffi-model-windows
test-ffi-model-hosts: $(RUNE) vm bin/rune-ffi-model-check bin/rune-test bin/rune-generate
	$(RUNE_TEST) --tier test-ffi-model-hosts

FFI_SHIM_CHECK_SRCS := tests/runner/sh.sml tests/runner/hosts.sml tests/runner/children.sml tests/ffi/shim-check.sml
check-tools: bin/rune-ffi-shim-check
bin/rune-ffi-shim-check.rbc: $(RUNE) $(FFI_SHIM_CHECK_SRCS) manifests
	$(RUNE) --library test/runner $(FFI_SHIM_CHECK_SRCS) -o $@
bin/rune-ffi-shim-check: bin/rune-ffi-shim-check.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-ffi-shim-check.rbc" "$$@"\n' > $@
	chmod +x $@
.PHONY: test-ffi-shims test-ffi-shims-hosts
test-ffi-shims: $(RUNE) vm bin/rune-ffi-shim-check bin/rune-test bin/rune-windows
	$(RUNE_TEST) --tier test-ffi-shims
test-ffi-shims-hosts: $(RUNE) vm bin/rune-ffi-shim-check bin/rune-test
	$(RUNE_TEST) --tier test-ffi-shims-hosts

C_LAYOUT_CHECK_SRCS := tests/runner/sh.sml tests/runner/children.sml tests/ffi/layout-check.sml
check-tools: bin/rune-c-layout-check
bin/rune-c-layout-check.rbc: $(RUNE) $(C_LAYOUT_CHECK_SRCS) $(wildcard lib/language/c/*.sml) manifests
	$(RUNE) --library test/runner --library language/c $(C_LAYOUT_CHECK_SRCS) -o $@
bin/rune-c-layout-check: bin/rune-c-layout-check.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-c-layout-check.rbc" "$$@"\n' > $@
	chmod +x $@
.PHONY: test-c-layout
test-c-layout: $(RUNE) vm bin/rune-c-layout-check bin/rune-test
	$(RUNE_TEST) --tier test-c-layout

HEADER_LAYOUT_CHECK_SRCS := tests/runner/sh.sml tests/runner/hosts.sml tests/runner/children.sml tests/ffi/header-layout-check.sml
check-tools: bin/rune-header-layout-check
bin/rune-header-layout-probe.rbc: $(RUNE) tests/ffi/header-layout.sml $(wildcard lib/ffi/model/*.sml) $(wildcard lib/language/c/*.sml) manifests
	$(RUNE) --library ffi/model tests/ffi/header-layout.sml -o $@
bin/rune-real32-probe.rbc: $(RUNE) tests/ffi/real32.sml $(wildcard lib/ffi/marshal/*.sml) manifests
	$(RUNE) --library ffi/marshal tests/ffi/real32.sml -o $@
bin/rune-header-layout-check.rbc: $(RUNE) $(HEADER_LAYOUT_CHECK_SRCS) manifests
	$(RUNE) --library test/runner --library ffi/model $(HEADER_LAYOUT_CHECK_SRCS) -o $@
bin/rune-header-layout-check: bin/rune-header-layout-check.rbc bin/rune-header-layout-probe.rbc bin/rune-real32-probe.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-header-layout-check.rbc" "$$@"\n' > $@
	chmod +x $@
.PHONY: test-ffi-header-layout test-ffi-real32
test-ffi-header-layout: $(RUNE) vm bin/rune-header-layout-check bin/rune-test
	$(RUNE_TEST) --tier test-ffi-header-layout
test-ffi-real32: $(RUNE) vm bin/rune-header-layout-check bin/rune-test
	$(RUNE_TEST) --tier test-ffi-real32

C_FRONTEND_CHECK_SRCS := tests/runner/sh.sml tests/runner/hosts.sml tests/runner/children.sml tests/ffi/frontend-check.sml
check-tools: bin/rune-c-check
bin/rune-c-check.rbc: $(RUNE) $(C_FRONTEND_CHECK_SRCS) $(wildcard lib/language/c/*.sml) manifests
	$(RUNE) --library test/runner --library json --library language/c $(C_FRONTEND_CHECK_SRCS) -o $@
bin/rune-c-check: bin/rune-c-check.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-c-check.rbc" "$$@"\n' > $@
	chmod +x $@
.PHONY: test-c-frontend test-c-frontend-windows
test-c-frontend: $(RUNE) vm bin/rune-c-check bin/rune-test
	$(RUNE_TEST) --tier test-c-frontend
test-c-frontend-windows: $(RUNE) vm bin/rune-c-check bin/rune-test
	$(RUNE_TEST) --tier test-c-frontend-windows
.PHONY: test-ffi-contracts test-ffi-windows test-ffi-libffi
test-ffi-contracts: $(RUNE) vm bin/rune-ffi-check bin/rune-test
	$(RUNE_TEST) --tier test-ffi-contracts
test-ffi-windows: $(RUNE) vm bin/rune-ffi-check bin/rune-test bin/rune-windows
	$(RUNE_TEST) --tier test-ffi-windows
test-ffi-libffi: $(RUNE) vm bin/rune-ffi-check bin/rune-test
	$(RUNE_TEST) --tier test-ffi-libffi

.PHONY: test-ffi-runtime test-ffi-runtime-asan test-ffi-runtime-windows
test-ffi-runtime: $(RUNE) $(RUNEOPT) vm bin/rune-ffi-check bin/rune-test
	$(RUNE_TEST) --tier test-ffi-runtime
test-ffi-runtime-asan: $(RUNE) vm vm-asan bin/rune-ffi-check bin/rune-test
	$(RUNE_TEST) --tier test-ffi-runtime-asan
test-ffi-runtime-windows: $(RUNE) vm windows bin/rune-ffi-check bin/rune-test bin/rune-windows
	$(RUNE_TEST) --tier test-ffi-runtime-windows

WINDOWS_SRCS := tests/runner/langchecks.sml $(HOST_LAWS_SRCS) tests/runner/bytecode.sml \
                tests/runner/matrixload.sml tests/runner/vmchecks.sml tests/runner/vmoracles.sml \
                tests/runner/windowschecks.sml tests/runner/platformfaults.sml tests/runner/windowsjobs.sml tests/runner/windows-main.sml
bin/rune-windows.rbc: $(RUNE) $(WINDOWS_SRCS) manifests
	$(RUNE) --library test/runner --library digest $(WINDOWS_SRCS) -o $@
bin/rune-suite.rbc: $(RUNE) tests/runner/sh.sml tests/runner/suite-main.sml manifests
	$(RUNE) --library test/runner tests/runner/sh.sml tests/runner/suite-main.sml -o $@
bin/rune-windows: bin/rune-windows.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-windows.rbc" "$$@"\n' > $@
	chmod +x $@
bin/rune-suite: bin/rune-suite.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-suite.rbc" "$$@"\n' > $@
	chmod +x $@

PROTOCOL_SRCS := tests/runner/sh.sml tests/runner/hosts.sml tests/runner/children.sml tests/runner/windowsdir.sml \
                 tests/runner/protocolio.sml tests/runner/protocoljson.sml tests/runner/replprotocolchecks.sml \
                 tests/runner/dapchecks.sml tests/runner/kernelchecks.sml tests/runner/protocolchecks.sml tests/runner/protocolfaults.sml tests/runner/protocol-main.sml
bin/rune-protocol-check.rbc: $(RUNE) $(PROTOCOL_SRCS) manifests
	$(RUNE) --library test/runner --library jupyter --library dap --library unicode $(PROTOCOL_SRCS) -o $@
bin/rune-protocol-check: bin/rune-protocol-check.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-protocol-check.rbc" "$$@"\n' > $@
	chmod +x $@

TERMINAL_SRCS := tests/runner/sh.sml tests/runner/hosts.sml tests/runner/children.sml tests/runner/commandwords.sml tests/runner/windowsdir.sml \
                 tests/runner/terminalpattern.sml tests/runner/terminalio.sml tests/runner/terminalchecks.sml tests/runner/terminalraw.sml \
                 tests/runner/terminaldisplay.sml tests/runner/terminalplatform.sml tests/runner/terminalfaults.sml tests/runner/terminal-main.sml
bin/rune-terminal.rbc: $(RUNE) $(TERMINAL_SRCS) manifests
	$(RUNE) --library test/runner $(TERMINAL_SRCS) -o $@
bin/rune-terminal: bin/rune-terminal.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-terminal.rbc" "$$@"\n' > $@
	chmod +x $@

# Development measurements and captured-report readers (P2.14).
MEASURE_SRCS := tests/runner/sh.sml tests/runner/children.sml tests/runner/commandwords.sml \
                tests/runner/terminalpattern.sml examples/benchmarks/shared/catalog.sml tools/measure/common.sml \
                tools/measure/basics.sml tools/measure/group-rules.sml tools/measure/profile.sml tools/measure/mmu.sml \
                tools/measure/mmu-cli.sml tools/measure/format.sml tools/measure/score-text.sml \
                tools/measure/gc-score.sml tools/measure/census.sml tools/measure/gc-eval.sml tools/measure/jit-dump.sml \
                tools/measure/perf-repl.sml tools/measure/hol.sml tools/measure/lex-corpus.sml \
                tools/measure/gc-tables.sml tools/measure/check-old.sml tools/measure/timeline-data.sml \
                tools/measure/timeline.sml tools/measure/pause-text.sml tools/measure/pauses.sml \
                tools/measure/sim-sweeps.sml tools/measure/sim-validate.sml tools/measure/tabular.sml \
                tools/measure/layout-text.sml tools/measure/layout-tables.sml tools/measure/validation-text.sml \
                tools/measure/sim-report3.sml tools/measure/sim-report-data.sml tools/measure/sim-report2.sml \
                tools/measure/sim-report1-data.sml tools/measure/sim-report1.sml tools/measure/gc-report-data.sml \
                tools/measure/gc-report.sml tools/measure/gc-measure.sml tools/measure/benchmarks.sml \
                tools/measure/layout-measure.sml tools/measure/gc-roadmap.sml tools/measure/gc-probe.sml \
                tools/measure/perf-units.sml tools/measure/perf-cycles.sml tools/measure/intinf-common.sml \
                tools/measure/intinf-compare.sml tools/measure/intinf-dispatch.sml tools/measure/intinf-conversion.sml \
                tools/measure/intinf-design.sml tools/measure/main.sml
bin/rune-measure.rbc: $(RUNE) $(MEASURE_SRCS) $(wildcard tools/measure/fixtures/*) manifests
	$(RUNE) --library test/runner --library json --library digest $(MEASURE_SRCS) -o $@
bin/rune-measure: bin/rune-measure.rbc bin/runevm Makefile bin/rune-generate bin/rune-inventory bin/rune-matrix build/bench-report.rbc build/bench-counts.rbc
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-measure.rbc" "$$@"\n' > $@
	chmod +x $@

# Post-bootstrap generators (P2.15); pre-host build-list/version adapters stay independent.
GENERATE_SRCS := tests/runner/sh.sml tests/runner/children.sml tests/runner/commandwords.sml \
                 tests/runner/terminalpattern.sml tests/runner/smlscan.sml tools/measure/common.sml \
                 tools/generate/text.sml tools/generate/perf.sml tools/generate/fxp.sml tools/generate/fixtures.sml \
                 tools/generate/annotations.sml tools/generate/host-basis.sml tools/generate/mlb.sml \
                 tools/generate/flatten.sml tools/generate/toposort.sml tools/generate/signatures.sml \
                 tools/generate/unicode-base.sml tools/generate/unicode-normal.sml tools/generate/unicode-render.sml \
                 tools/generate/unicode-profile.sml tools/generate/unicode-security.sml tools/generate/unicode.sml \
                 tools/generate/rewrites.sml tools/generate/rewrite-poly.sml tools/generate/rewrite-nj.sml \
                 tools/generate/mlton-prims.sml tools/generate/xc2.sml tools/generate/xc2-poly.sml \
                 tools/generate/xc2-nj.sml tools/generate/structures.sml tools/generate/inventory-base.sml \
                 tools/generate/inventory-discover.sml tools/generate/inventory-classify.sml \
                 tools/generate/inventory-credits.sml tools/generate/inventory-build.sml tools/generate/inventory.sml \
                 tools/generate/main.sml
bin/rune-generate.rbc: $(RUNE) $(GENERATE_SRCS) $(wildcard tools/generate/data/*) manifests
	$(RUNE) --library test/runner --library json --library digest $(GENERATE_SRCS) -o $@
bin/rune-generate bin/rune-inventory: bin/rune-generate.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_TEST_ROOT:-}" ]; then RUNE_TEST_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_TEST_ROOT; fi\nexec "$$d/runevm" "$$d/rune-generate.rbc" $(if $(filter bin/rune-inventory,$@),inventory )"$$@"\n' > $@
	chmod +x $@

# Portable relinking controller: post-bootstrap only, never a GMP/VM prerequisite.
BUILDER_RUNE_SRCS := tools/builder/io.sig tools/builder/rune-io.sml $(BUILDER_MODEL_SRCS) tools/builder/main.sml
bin/rune-build.rbc: $(RUNE) $(BUILDER_RUNE_SRCS) manifests
	$(RUNE) --library json --library digest $(BUILDER_RUNE_SRCS) -o $@
bin/rune-build-rune: bin/rune-build.rbc bin/runevm Makefile
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nif [ -z "$${RUNE_BUILD_ROOT:-}" ]; then RUNE_BUILD_ROOT=$$(CDPATH= cd "$$d/.." && pwd); export RUNE_BUILD_ROOT; fi\nexec "$$d/runevm" "$$d/rune-build.rbc" "$$@"\n' > $@
	chmod +x $@
