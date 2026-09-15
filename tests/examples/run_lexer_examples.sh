#!/bin/sh

set -u

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
POSITIVE="$ROOT/tests/examples/positive"
NEGATIVE="$ROOT/tests/examples/negative"
TMPDIR=${TMPDIR:-/tmp}/rune-lexer-examples.$$
FAILURES=0
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT HUP INT TERM

printf '%s\n' 'suite,case,category,status,duration,toolchain,diagnostic'

emit() {
  printf '%s,%s,%s,%s,%s,%s,%s\n' "$@"
}

csv_diag() {
  printf '%s' "$1" | tr '\n' ' ' | tr ',' ';' | cut -c1-240
}

run_command() {
  if output=$("$@" 2>&1); then
    RUN_STATUS=0
  else
    RUN_STATUS=$?
  fi
  RUN_OUTPUT=$output
}

make_native_driver() {
  driver=$1
  source_file=$2
  {
    printf 'val _ = (\n'
    cat "$source_file"
    printf '\n);\n'
  } >"$driver"
}

make_rune_driver() {
  driver=$1
  source_file=$2
  category=$3
  cat >"$driver" <<EOF
use "$ROOT/src/sml/ast.sml";
use "$ROOT/src/sml/lexer.sml";
use "$ROOT/src/sml/parser.sml";
use "$ROOT/src/sml/tycheck.sml";
use "$ROOT/src/sml/emit.sml";
use "$ROOT/src/sml/rune.sml";
val source = TextIO.inputAll (TextIO.openIn "$source_file");
EOF
  if [ "$category" = positive ]; then
    cat >>"$driver" <<'EOF'
val _ = (RuneCompiler.compile source; print "PASS\n");
EOF
  else
    cat >>"$driver" <<'EOF'
val _ =
  ((RuneLexer.lex source; print "WRONG_ACCEPT\n";
    OS.Process.exit OS.Process.failure)
   handle Fail message =>
     if String.isSubstring "invalid character" message orelse
        String.isSubstring "invalid integer" message
     then print "PASS\n"
     else (print ("WRONG_ERROR:" ^ message ^ "\n");
           OS.Process.exit OS.Process.failure)
        | Overflow =>
            (print "WRONG_ERROR:overflow\n";
             OS.Process.exit OS.Process.failure));
EOF
  fi
}

make_rune_mlton_driver() {
  driver=$1
  cat >"$driver" <<'EOF'
val reversed = List.rev (CommandLine.arguments());
val category = List.hd reversed;
val source_file = List.hd (List.tl reversed);
val source = TextIO.inputAll (TextIO.openIn source_file);
val _ =
  if category = "positive" then
    (RuneCompiler.compile source; print "PASS\n")
  else
    ((RuneLexer.lex source; print "WRONG_ACCEPT\n";
      OS.Process.exit OS.Process.failure)
     handle Fail message =>
       if String.isSubstring "invalid character" message orelse
          String.isSubstring "invalid integer" message
       then print "PASS\n"
       else (print ("WRONG_ERROR:" ^ message ^ "\n");
             OS.Process.exit OS.Process.failure)
          | Overflow =>
              (print "WRONG_ERROR:overflow\n";
               OS.Process.exit OS.Process.failure));
EOF
}

make_rune_batch_driver() {
  driver=$1
  source_dir=$2
  category=$3
  {
    printf 'use "%s/src/sml/ast.sml";\n' "$ROOT"
    printf 'use "%s/src/sml/lexer.sml";\n' "$ROOT"
    printf 'use "%s/src/sml/parser.sml";\n' "$ROOT"
    printf 'use "%s/src/sml/tycheck.sml";\n' "$ROOT"
    printf 'use "%s/src/sml/emit.sml";\n' "$ROOT"
    printf 'use "%s/src/sml/rune.sml";\n' "$ROOT"
    printf 'val cases = [\n'
    first=true
    for source_file in "$source_dir"/*.sml; do
      name=$(basename "$source_file" .sml)
      if [ "$first" = true ]; then first=false; else printf ',\n'; fi
      printf '  ("%s", "%s")' "$name" "$source_file"
    done
    printf '];\n'
    cat <<EOF
fun checkCase (name, path) =
  let val source = TextIO.inputAll (TextIO.openIn path)
  in
    if "$category" = "positive" then
      (RuneCompiler.compile source; print ("RESULT," ^ name ^ ",pass\n"))
    else
      ((RuneLexer.lex source; print ("RESULT," ^ name ^ ",fail\n"))
       handle Fail message =>
         if String.isSubstring "invalid character" message orelse
            String.isSubstring "invalid integer" message
         then print ("RESULT," ^ name ^ ",pass\n")
         else print ("RESULT," ^ name ^ ",fail\n")
            | Overflow => print ("RESULT," ^ name ^ ",fail\n"))
  end
val _ = app checkCase cases;
EOF
  } >"$driver"
}

run_native() {
  toolchain=$1
  command_name=$2
  source_file=$3
  category=$4
  case=$5
  driver="$TMPDIR/native-$toolchain-$case.sml"
  make_native_driver "$driver" "$source_file"
  case "$toolchain" in
    smlnj) run_command sml "$driver" </dev/null ;;
    polyml) run_command poly --script "$driver" ;;
    mlton)
      binary="$TMPDIR/native-$case"
      run_command mlton -output "$binary" "$driver"
      if [ "$RUN_STATUS" -eq 0 ]; then
        run_command "$binary"
      fi
      ;;
  esac
  if [ "$category" = positive ] &&
     [ "$RUN_STATUS" -eq 0 ] &&
     ! printf '%s' "$RUN_OUTPUT" | grep -q 'Error'; then
    status=pass
  elif [ "$category" = negative ] &&
       { [ "$RUN_STATUS" -ne 0 ] ||
         printf '%s' "$RUN_OUTPUT" | grep -q 'Error'; }; then
    status=pass
  else
    status=fail
    FAILURES=$((FAILURES + 1))
  fi
  emit lexer_examples "$case" "$category" "$status" 0 "$toolchain" \
    "$(csv_diag "$RUN_OUTPUT")"
}

run_rune() {
  toolchain=$1
  source_file=$2
  category=$3
  case=$4
  if [ "$toolchain" = rune-mlton ] && [ -n "${RUNE_MLTON_BINARY:-}" ]; then
    run_command "$RUNE_MLTON_BINARY" "$source_file" "$category"
    if [ "$RUN_STATUS" -eq 0 ] && printf '%s' "$RUN_OUTPUT" | grep -q 'PASS'; then
      status=pass
    else
      status=fail
      FAILURES=$((FAILURES + 1))
    fi
    emit lexer_examples "$case" "$category" "$status" 0 "$toolchain" \
      "$(csv_diag "$RUN_OUTPUT")"
    return
  fi
  driver="$TMPDIR/rune-$toolchain-$case.sml"
  make_rune_driver "$driver" "$source_file" "$category"
  case "$toolchain" in
    rune-smlnj) run_command sml "$driver" </dev/null ;;
    rune-polyml) run_command poly --script "$driver" ;;
    rune-mlton)
      binary="$TMPDIR/rune-$case"
      run_command mlton -output "$binary" "$driver"
      if [ "$RUN_STATUS" -eq 0 ]; then
        run_command "$binary"
      fi
      ;;
  esac
  if [ "$RUN_STATUS" -eq 0 ] && printf '%s' "$RUN_OUTPUT" | grep -q 'PASS'; then
    status=pass
  else
    status=fail
    FAILURES=$((FAILURES + 1))
  fi
  emit lexer_examples "$case" "$category" "$status" 0 "$toolchain" \
    "$(csv_diag "$RUN_OUTPUT")"
}

run_configuration() {
  toolchain=$1
  category=$2
  source_dir=$3
  command_name=$4
  if ! command -v "$command_name" >/dev/null 2>&1; then
    for source_file in "$source_dir"/*.sml; do
      name=$(basename "$source_file" .sml)
      emit lexer_examples "$name" "$category" skip 0 "$toolchain" \
        "$command_name not installed"
    done
    return
  fi
  if [ "$toolchain" = rune-mlton ]; then
    RUNE_MLTON_DRIVER="$TMPDIR/rune-mlton-driver.sml"
    RUNE_MLTON_BINARY="$TMPDIR/rune-mlton-driver"
    RUNE_MLTON_MLB="$TMPDIR/rune-mlton.mlb"
    make_rune_mlton_driver "$RUNE_MLTON_DRIVER"
    {
      printf '$(SML_LIB)/basis/basis.mlb\n'
      printf '%s/src/sml/ast.sml\n' "$ROOT"
      printf '%s/src/sml/lexer.sml\n' "$ROOT"
      printf '%s/src/sml/parser.sml\n' "$ROOT"
      printf '%s/src/sml/tycheck.sml\n' "$ROOT"
      printf '%s/src/sml/emit.sml\n' "$ROOT"
      printf '%s/src/sml/rune.sml\n' "$ROOT"
      printf '%s\n' "$RUNE_MLTON_DRIVER"
    } >"$RUNE_MLTON_MLB"
    run_command mlton -output "$RUNE_MLTON_BINARY" "$RUNE_MLTON_MLB"
    if [ "$RUN_STATUS" -ne 0 ]; then
      printf 'rune-mlton driver failed: %s\n' "$(csv_diag "$RUN_OUTPUT")" >&2
      FAILURES=$((FAILURES + 1))
      return
    fi
    export RUNE_MLTON_BINARY
  fi
  case "$toolchain" in
    rune-smlnj|rune-polyml)
      batch="$TMPDIR/$toolchain-$category.sml"
      make_rune_batch_driver "$batch" "$source_dir" "$category"
      case "$toolchain" in
        rune-smlnj) run_command sml "$batch" </dev/null ;;
        rune-polyml) run_command poly --script "$batch" ;;
      esac
      for source_file in "$source_dir"/*.sml; do
        name=$(basename "$source_file" .sml)
        if printf '%s' "$RUN_OUTPUT" | grep -q "RESULT,$name,pass"; then
          status=pass
        else
          status=fail
          FAILURES=$((FAILURES + 1))
        fi
        emit lexer_examples "$name" "$category" "$status" 0 "$toolchain" \
          "$(csv_diag "$RUN_OUTPUT")"
      done
      return
      ;;
  esac
  if [ "$toolchain" = mlton ] && [ "$category" = positive ]; then
    aggregate="$TMPDIR/native-mlton-positive.sml"
    : >"$aggregate"
    for source_file in "$source_dir"/*.sml; do
      printf 'val _ = (\n' >>"$aggregate"
      cat "$source_file" >>"$aggregate"
      printf '\n);\n' >>"$aggregate"
    done
    binary="$TMPDIR/native-mlton-positive"
    run_command mlton -output "$binary" "$aggregate"
    for source_file in "$source_dir"/*.sml; do
      name=$(basename "$source_file" .sml)
      if [ "$RUN_STATUS" -eq 0 ]; then
        status=pass
      else
        status=fail
        FAILURES=$((FAILURES + 1))
      fi
      emit lexer_examples "$name" "$category" "$status" 0 "$toolchain" \
        "$(csv_diag "$RUN_OUTPUT")"
    done
    return
  fi
  if [ "$toolchain" = polyml ] && [ "$category" = positive ]; then
    aggregate="$TMPDIR/native-polyml-positive.sml"
    : >"$aggregate"
    for source_file in "$source_dir"/*.sml; do
      printf 'val _ = (\n' >>"$aggregate"
      cat "$source_file" >>"$aggregate"
      printf '\n);\n' >>"$aggregate"
    done
    run_command poly --script "$aggregate"
    for source_file in "$source_dir"/*.sml; do
      name=$(basename "$source_file" .sml)
      if [ "$RUN_STATUS" -eq 0 ]; then
        status=pass
      else
        status=fail
        FAILURES=$((FAILURES + 1))
      fi
      emit lexer_examples "$name" "$category" "$status" 0 "$toolchain" \
        "$(csv_diag "$RUN_OUTPUT")"
    done
    return
  fi
  for source_file in "$source_dir"/*.sml; do
    name=$(basename "$source_file" .sml)
    case "$toolchain" in
      smlnj|polyml|mlton)
        run_native "$toolchain" "$command_name" "$source_file" "$category" "$name"
        ;;
      *)
        run_rune "$toolchain" "$source_file" "$category" "$name"
        ;;
    esac
  done
}

for positive in "$POSITIVE"/*.sml; do
  case=$(basename "$positive")
  if [ ! -f "$NEGATIVE/$case" ]; then
    printf 'missing negative pair for %s\n' "$case" >&2
    exit 1
  fi
done
for negative in "$NEGATIVE"/*.sml; do
  case=$(basename "$negative")
  if [ ! -f "$POSITIVE/$case" ]; then
    printf 'missing positive pair for %s\n' "$case" >&2
    exit 1
  fi
done

run_configuration smlnj positive "$POSITIVE" sml
run_configuration smlnj negative "$NEGATIVE" sml
run_configuration polyml positive "$POSITIVE" poly
run_configuration polyml negative "$NEGATIVE" poly
run_configuration mlton positive "$POSITIVE" mlton
run_configuration mlton negative "$NEGATIVE" mlton
run_configuration rune-smlnj positive "$POSITIVE" sml
run_configuration rune-smlnj negative "$NEGATIVE" sml
run_configuration rune-polyml positive "$POSITIVE" poly
run_configuration rune-polyml negative "$NEGATIVE" poly
run_configuration rune-mlton positive "$POSITIVE" mlton
run_configuration rune-mlton negative "$NEGATIVE" mlton

if [ "$FAILURES" -ne 0 ]; then
  printf '%s\n' "lexer example failures: $FAILURES" >&2
  exit 1
fi
