# Process/file metadata for the selected Rune tools; no workload logic.
bench_tool_repository() {
  provenance_role=$1
  provenance_tool=$2
  provenance_bundle=$3
  provenance_directory=$(dirname "$provenance_tool")
  provenance_repo=$(git -C "$provenance_directory" rev-parse --show-toplevel 2>/dev/null || true)
  {
    printf 'tool\t%s\n' "$provenance_tool"
    if [ -n "$provenance_repo" ]; then
      printf 'repository\t%s\nrevision\t%s\n' "$provenance_repo" "$(git -C "$provenance_repo" rev-parse HEAD)"
      printf 'dirty\t%s\n' "$(git -C "$provenance_repo" status --porcelain | wc -l)"
      printf 'identity_scope\tselected tool repository at measurement time; payload hashes identify actual bytes\n'
    else
      printf 'repository\tunavailable\nrevision\tunavailable\ndirty\tunavailable\n'
      printf 'identity_scope\tcustom or installed tool; repository identity unavailable, executable hash retained\n'
    fi
  } > "$provenance_bundle/$provenance_role-repository.tsv"
  : > "$provenance_bundle/$provenance_role-payloads.sha256"
  if [ -n "$provenance_repo" ]; then
    for provenance_payload in rune.rbc rune.stack.rbc rune.new.rbc rune-mlton.bin rune-polyml.bin runevm runevm-stack runevm-new runevm-native runeopt-mlton runeopt-mlton.bin; do
      if [ -f "$provenance_repo/bin/$provenance_payload" ]; then
        sha256sum "$provenance_repo/bin/$provenance_payload" >> "$provenance_bundle/$provenance_role-payloads.sha256"
      fi
    done
    if [ "$provenance_role" = compiler ] && [ -f "$provenance_repo/lib/basis/MANIFEST" ]; then
      (cd "$provenance_repo" && sha256sum lib/basis/MANIFEST lib/basis/*.sml) > "$provenance_bundle/basis.sha256"
    fi
  fi
}
