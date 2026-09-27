# scripts/perf-groups.awk -- the samples of `perf script -F period,ip,sym,dso` (with callchains, the
# frame-pointer build; perf-cycles.sh --profile) grouped by where the time goes; -v top=N prints the
# top N symbols too. A sample is its period (perf report's weight); libc's
# memcpy, memmove, memset and memcmp go to the group of their caller.
function group2(s) {
  if (s ~ /^(copy_obj|collect_into|vm_gc|copy_value|heap_init|grown|fill_of)$/) return "collector"
  if (s ~ /^(vm_alloc|vm_alloc_fields|vm_alloc_string|vm_string_from|vm_cons|jit_h_alloc|jit_alloc_slow|payload_size)$/) return "allocation"
  if (s ~ /^(values_equal|values_equal\.cold|p_imm_eq|p_poly_eq|jit_h_values_equal)$/) return "values_equal/imm_eq"
  if (s ~ /^(p_string_|str_cmp$|jit_h_string_order$)/) return "string prims"
  if (s ~ /^(p_|jit_h_prim$|jit_h_primpush$|real_|decimal_|int_list$|from_list$|mk_some$|push_|put$|c_string|string_array|get_string$|prim_fast)/) return "primitives"
  if (s ~ /^(vm_loop|loop_fast|loop_traced|vm_run$|jit_run$|jit_h_(call|ret|tailcall|called|grow|grow_frames|raise|push_handler|fatal)$|vm_grow_|vm_push_handler$|vm_raise|jit_landing$|jit_osr$|jit_site$|check_tag|expect_obj|op_[A-Z]|closure_function|stack_overflow|native_)/) return "dispatch"
  if (s ~ /^(jit_compile|jit_tier_up$|jit_fill|jit_depend$|jit_label$|jit_program$|jit_region_init$|jit_invalidate$|jit_unsupported$|jit_print_stats$|jit_check$|ms_|x64_|emit_|modrm_mem$|rex$|rel32$|sse_|op_rr|alloc$|branch$|called$|closure$|equal$|set_order$|floor_div$|index_of$|checked_tag$|to_callee|room$|room_dynamic$|frame_room$|ref_room$|home_to_slot$|slot_to_home$|result_at|uses_defs|fill_unit_dynamic$|count_arg$|bug$)/) return "JIT compiler"
  return "other"
}
function group(s, dso, c,    cg) {
  if (dso ~ /kernel/) return "kernel"
  if (s ~ /^jit[0-9]+:/) return "JIT code"
  if (s ~ /#[0-9]+$/) return "native code"
  if (s ~ /^_*mem(cpy|move|set|cmp)|^__mem|^_*memchr|^_*(str|wcs)(len|cmp|chr|nlen)/) {
    cg = group2(c)
    if (cg == "collector") return "collector (memcpy from copy_obj)"
    if (cg == "string prims" || cg == "allocation" || cg == "values_equal/imm_eq" || cg == "primitives") return cg
    return "memmove/memcpy (other callers)"
  }
  return group2(s)
}
function flush(   g) {
  if (period > 0) {
    g = group(leaf, leafdso, caller)
    grp[g] += period
    key = leaf
    if (leafdso !~ /rune|runevm|native|perf-[0-9]+\.map/) key = leaf " " leafdso
    sym[key] += period
    total += period
  }
  period = 0; leaf = ""; leafdso = ""; caller = ""; depth = 0
}
# a sample: its period alone when callchains follow (tab-indented frames,
# leaf first), else the period, address, symbol and object on one line
/^[^\t]/ { flush(); period = $1 + 0; if (NF >= 3) { leaf = $3; leafdso = $4 } next }
/^\t/ { depth++; if (depth == 1) { leaf = $2; leafdso = $3 } else if (depth == 2) caller = $2; next }
END {
  flush()
  if (total == 0) { print "total 0"; exit }
  n = split("dispatch|collector|collector (memcpy from copy_obj)|allocation|primitives|values_equal/imm_eq|string prims|JIT code|native code|JIT compiler|memmove/memcpy (other callers)|kernel|other", order, "|")
  printf "total %d\n", total
  for (i = 1; i <= n; i++) printf "group\t%s\t%.2f\n", order[i], 100 * grp[order[i]] / total
  for (g in grp) { seen = 0; for (i = 1; i <= n; i++) if (order[i] == g) seen = 1; if (!seen) printf "group\t%s\t%.2f\n", g, 100 * grp[g] / total }
  if (top > 0) {
    m = 0
    for (k in sym) { m++; keys[m] = k }
    for (i = 1; i <= m; i++) for (j = i + 1; j <= m; j++) if (sym[keys[j]] > sym[keys[i]]) { t = keys[i]; keys[i] = keys[j]; keys[j] = t }
    for (i = 1; i <= m && i <= top; i++) printf "sym\t%s\t%.2f\n", keys[i], 100 * sym[keys[i]] / total
  }
}
