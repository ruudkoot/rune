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
#   make check      everything above

SHELL   := /bin/sh
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

.PHONY: all mlton smlnj polyml all3 vm vm-asan gen test test-all check-cross check-docs check clean

all: mlton vm

# ---------------------------------------------------------------- generated
gen: $(BUILDGEN) $(GEN_SML) $(GEN_C)

$(BUILDGEN): sources.txt scripts/gen-build-files.sh
	RUNE_LIB="$(RUNE_LIB)" sh scripts/gen-build-files.sh "$(ROOT)"

$(GEN_SML) $(GEN_C): vm/opcodes.def vm/prims.def scripts/gen-opcodes.sh
	sh scripts/gen-opcodes.sh

# ---------------------------------------------------------------- compiler
mlton: bin/rune-mlton
	ln -sf rune-mlton bin/rune

smlnj: bin/rune-smlnj

polyml: bin/rune-polyml

all3: mlton smlnj polyml

bin/rune-mlton: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/mlton-main.sml
	@mkdir -p bin
	mlton -output $@ build/rune.mlb

bin/rune-smlnj: $(BUILDGEN) $(SOURCES) $(GEN_SML)
	@mkdir -p bin
	ml-build build/rune.cm Main.main bin/rune-smlnj.heap
	printf '#!/bin/sh\nd=$$(dirname "$$0")\nexec sml @SMLload="$$d/rune-smlnj.heap" "$$@"\n' > $@
	chmod +x $@

bin/rune-polyml: $(BUILDGEN) $(SOURCES) $(GEN_SML) src/main/polyml-main.sml
	@mkdir -p bin
	polyc -o $@ build/polyml-build.sml

# ---------------------------------------------------------------- VM
vm: bin/runevm

bin/runevm: $(VM_SRCS) $(VM_HDRS)
	@mkdir -p bin
	$(CC) $(CFLAGS) -o $@ $(VM_SRCS) -lm

vm-asan: bin/runevm-asan

bin/runevm-asan: $(VM_SRCS) $(VM_HDRS)
	@mkdir -p bin
	$(CC) -std=c99 -g -O1 -Wall -Wextra -fsanitize=address,undefined -fno-omit-frame-pointer -o $@ $(VM_SRCS) -lm

# ---------------------------------------------------------------- tests
test: mlton vm
	sh tests/run-tests.sh --rune bin/rune --vm bin/runevm

test-all: all3 vm
	@for c in mlton smlnj polyml; do \
	  echo "=== testing with $$c build ==="; \
	  sh tests/run-tests.sh --rune bin/rune-$$c --vm bin/runevm || exit 1; \
	done

check-cross: all3
	sh scripts/check-cross.sh

check-docs:
	sh scripts/check-docs.sh

check: test test-all check-cross check-docs

clean:
	rm -rf bin build $(GEN_SML) $(GEN_C) tests/out
