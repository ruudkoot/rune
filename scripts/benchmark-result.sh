# Shared measurement-result classification. The caller supplies phase_exit,
# phase_dir, rounds and status; classify sets category, validate also records
# whether this run may contribute samples. Correctness exceptions use the
# explicit "incorrect result" marker, including General.exnMessage's Fail prefix.
classify() {
  category=pass
  if [ "$phase_exit" = 124 ]; then category=timeout
  elif [ "$phase_exit" = 125 ]; then category=limit-setup-failure
  elif grep -Eiq 'out of memory|allocation failed|cannot allocate memory|heap limit|insufficient memory|unable to reserve' "$phase_dir/stderr" "$phase_dir/stdout"; then category=memory-limit
  elif [ "$phase_exit" != 0 ]; then category=$1
  fi
}
validate() {
  classify runtime-failure
  if grep -Eq '^FAIL .* -- (Fail: |Fail ")?(incorrect result|expected )' "$phase_dir/stdout"; then category=incorrect-result; fi
  if [ "$category" = pass ]; then
    if ! grep -q "^SUMMARY $rounds checks, 0 failed$" "$phase_dir/stdout" || \
       grep -q '^FAIL ' "$phase_dir/stdout" || \
       [ "$(grep -c '^PASS ' "$phase_dir/stdout")" != "$rounds" ]; then category=incorrect-result; fi
  fi
  [ "$category" = pass ] || status=1
}
