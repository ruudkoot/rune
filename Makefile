CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic
BUILD_DIR ?= build

.PHONY: all setup check check-sml check-polyml check-mlton check-runtime test clean

all: check

setup:
	./scripts/setup-environment.sh

check: check-sml check-polyml check-mlton check-runtime test

check-sml:
	@if command -v sml >/dev/null 2>&1; then \
		printf '%s\n' 'SML/NJ: checking bootstrap'; \
		printf 'use "tests/sml/bootstrap.sml";\n' | sml >/dev/null; \
	else \
		printf '%s\n' 'SML/NJ: skipped (sml not installed)'; \
	fi

check-polyml:
	@if command -v poly >/dev/null 2>&1; then \
		printf '%s\n' 'Poly/ML: checker available'; \
	else \
		printf '%s\n' 'Poly/ML: skipped (poly not installed)'; \
	fi

check-mlton:
	@if command -v mlton >/dev/null 2>&1; then \
		printf '%s\n' 'MLton: checker available'; \
	else \
		printf '%s\n' 'MLton: skipped (mlton not installed)'; \
	fi

check-runtime:
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -Isrc/runtime src/runtime/rune.c src/runtime/rune_vm.c -o $(BUILD_DIR)/rune
	$(BUILD_DIR)/rune

test:
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -Isrc/runtime tests/runtime/test_rune_vm.c src/runtime/rune_vm.c -o $(BUILD_DIR)/test_rune_vm
	$(BUILD_DIR)/test_rune_vm

clean:
	rm -rf $(BUILD_DIR)
