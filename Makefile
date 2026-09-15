.DEFAULT_GOAL := build
HOST ?= mlton
CC ?= cc
CFLAGS ?= -O2
PYTHON ?= python3
export SML ML_BUILD POLY MLTON CC CFLAGS

.PHONY: build compiler vm all-hosts doctor test test-all check-docs generate clean test-builds test-sanitize

build: compiler vm

compiler:
	@sh scripts/build.sh "$(HOST)"

vm:
	@sh scripts/build-vm.sh

all-hosts: vm
	@$(MAKE) HOST=smlnj compiler
	@$(MAKE) HOST=polyml compiler
	@$(MAKE) HOST=mlton compiler

doctor:
	@sh scripts/doctor.sh

test: build check-docs
	$(PYTHON) scripts/test.py --hosts $(HOST)

test-all: all-hosts check-docs
	$(PYTHON) scripts/test.py --hosts smlnj polyml mlton

test-builds:
	$(PYTHON) scripts/test_builds.py

test-sanitize:
	@$(MAKE) HOST=mlton compiler
	@mkdir -p build/vm
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -Werror -g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer -fno-pie -no-pie vm/vm.c -o build/vm/rune-vm-sanitize
	$(PYTHON) scripts/test.py --hosts mlton --vm build/vm/rune-vm-sanitize

check-docs:
	$(PYTHON) scripts/generate.py --check
	$(PYTHON) scripts/check_docs.py

generate:
	$(PYTHON) scripts/generate.py

clean:
	rm -rf build
