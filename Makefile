CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic
BUILD_DIR ?= build

.PHONY: all setup check check-sml check-lexer check-lexer-fixtures check-lexer-examples check-polyml check-mlton check-runtime test clean

all: check

setup:
	./scripts/setup-environment.sh

check: check-sml check-lexer check-lexer-fixtures check-lexer-examples check-polyml check-mlton check-runtime test

check-sml:
	@if command -v sml >/dev/null 2>&1; then \
		printf '%s\n' 'SML/NJ: checking bootstrap'; \
		printf '%s\n' 'use "src/sml/ast.sml"; use "src/sml/lexer.sml"; use "src/sml/parser.sml"; use "src/sml/tycheck.sml"; use "src/sml/emit.sml"; use "src/sml/rune.sml"; use "tests/sml/bootstrap.sml";' | sml >/dev/null; \
	else \
		printf '%s\n' 'SML/NJ: skipped (sml not installed)'; \
	fi

check-lexer:
	@if command -v sml >/dev/null 2>&1; then \
		printf '%s\n' 'SML/NJ: checking lexer test suite'; \
		printf '%s\n' 'use "src/sml/lexer.sml"; use "tests/unit/sml/lexer/lexer_tests.sml";' | sml; \
	else \
		printf '%s\n' 'SML/NJ lexer tests: skipped (sml not installed)'; \
	fi

check-lexer-fixtures:
	@if command -v sml >/dev/null 2>&1; then \
		printf '%s\n' 'SML/NJ: checking positive lexer fixture'; \
		printf '%s\n' 'use "src/sml/lexer.sml"; use "tests/unit/sml/lexer/positive/lexer_positive.sml";' | sml >/dev/null; \
		printf '%s\n' 'SML/NJ: checking negative lexer fixture'; \
		printf '%s\n' 'use "src/sml/lexer.sml"; use "tests/unit/sml/lexer/negative/lexer_negative.sml";' | sml >/dev/null; \
	else \
		printf '%s\n' 'SML/NJ lexer fixtures: skipped (sml not installed)'; \
	fi

check-lexer-examples:
	@printf '%s\n' 'Lexer examples: checking six compiler configurations'; \
	tests/examples/run_lexer_examples.sh

check-polyml:
	@if command -v poly >/dev/null 2>&1; then \
		printf '%s\n' 'Poly/ML: checking compiler module'; \
		printf '%s\n' 'use "src/sml/ast.sml"; use "src/sml/lexer.sml"; use "src/sml/parser.sml"; use "src/sml/tycheck.sml"; use "src/sml/emit.sml"; use "src/sml/rune.sml"; use "tests/sml/bootstrap.sml";' | poly >/dev/null; \
		printf '%s\n' 'Poly/ML: checking lexer fixtures'; \
		printf '%s\n' 'use "src/sml/lexer.sml"; use "tests/unit/sml/lexer/positive/lexer_positive.sml";' | poly >/dev/null; \
		printf '%s\n' 'use "src/sml/lexer.sml"; use "tests/unit/sml/lexer/negative/lexer_negative.sml";' | poly >/dev/null; \
	else \
		printf '%s\n' 'Poly/ML: skipped (poly not installed)'; \
	fi

check-mlton:
	@if command -v mlton >/dev/null 2>&1; then \
		printf '%s\n' 'MLton: checking compiler module'; \
		mkdir -p $(BUILD_DIR); \
		mlton -output $(BUILD_DIR)/rune-compiler src/sml/rune.mlb; \
		printf '%s\n' 'MLton: checking bootstrap MLB'; \
		mlton -output $(BUILD_DIR)/rune-bootstrap-tests tests/sml/bootstrap.mlb; \
		printf '%s\n' 'MLton: checking positive lexer fixture'; \
		mlton -output $(BUILD_DIR)/rune-lexer-positive tests/unit/sml/lexer/positive/positive.mlb; \
		printf '%s\n' 'MLton: checking negative lexer fixture'; \
		mlton -output $(BUILD_DIR)/rune-lexer-negative tests/unit/sml/lexer/negative/negative.mlb; \
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
