# scripts/perf-groups.awk -- the samples of `perf script -F period,ip,sym,dso` (with callchains, the
# frame-pointer build; perf-cycles.sh --profile) grouped by where the time goes; -v top=N prints the
# top N symbols too. A sample is its period (perf report's weight); libc's
# memcpy, memmove, memset and memcmp go to the group of their caller.
# The JIT's code is named jitT:FUNCTION by runevm --jit-perf-map, T its
# tier; the collector is the generational one of runtime/gc (minor.c, the
# nursery's collections; the rest the old generation's: marking, sweeping
# Immix's lines, segregated fits and the large-object space, the
# low-pause cycle, compaction, and the copier's full collection). The
# frames are runevm's in the value stack (native-frames.md, M3 to M5): their
# walk, which the collector asks of each frame above the watermark, a
# frame's live registers, the return barrier's pass, and the stack's clean
# room claimed as it deepens.
function group2(s) {
  if (s ~ /^(vm_frames?_[a-z_]+|reg_frames?_[a-z_]+|reg_barrier_[a-z]+|step_down|read_header|frame_at|barrier_arm|frames_lower|vm_claim_stack|vm_clean_stack)$/) return "frames: walks, liveness, the barrier"
  if (s ~ /^(collect_minor|minor_(pass|into|stack)|promote|promote_(obj|value|global)|copy_small|scan_(card|dirty|object|range)|gc_(born|queue|write)|nursery_(start|adapt))$/) return "collector: minor"
  if (s ~ /^(mark_[a-z_]+|at_limit|bits_clear|chunk_bits_next|chunk_object_covering|old_place|immix_[a-z_]+|by_free|first_line|free_block|free_lines|list_blocks|next_hole|reset_holes|next|segfit_[a-z_]+|block_first|cells_of|classes|descriptor|forget_blocks|marked|push|new_chunk|los_[a-z_]+|take_run|units?_of|first_in|cycle_[a-z_]+|gc_shade_old|gray_left|mark_some|push_gray|shade|shade_(obj|value)|slice_point|compact_[a-z_]+|forward_(fields|obj|value)|fwd_(after|next)|collect_(into|pass)|copy_(next|obj|value)|fill_of|gc_after_cycle|gc_stack_roots|grown|vm_collect|vm_gc|chunk_(append|give|give_later|layout|take)|heap_chunks_release|pool_(keep|trim)|heap_check|heap_verify|check_(fail|marked|old|parse|ptr|value)|out_of_memory|heap_init)$/) return "collector: major"
  if (s ~ /^(vm_alloc|vm_alloc_fields|vm_alloc_string|vm_string_from|vm_cons|jit_h_alloc|jit_alloc_slow|payload_size|alloc_young|alloc_next|alloc_view|raw_array|los_alloc)$/) return "allocation"
  if (s ~ /^(jit_h_box_(num|real)|alloc_box|mk_box_vm|mk_(int|int64|word|word64)_vm|mk_real|real_boxes_make)$/) return "boxes (64-bit numbers, reals)"
  if (s ~ /^(values_equal|values_equal\.cold|p_imm_eq|p_poly_eq|p_ptr_eq|p_real_eq|jit_h_values_equal)$/) return "equality (runtime)"
  if (s ~ /^(p_string_|str_cmp$|jit_h_string_order$)/) return "string order (runtime)"
  if (s ~ /^(vm_raise|vm_raise_builtin|vm_push_handler|vm_pop_handler|jit_h_raise|jit_h_push_handler|print_exn_payload)$/) return "exceptions (runtime)"
  if (s ~ /^(p_intinf|intinf_|p_inf_|mpz|__gmp)/) return "IntInf primitives"
  if (s ~ /^(p_|jit_h_prim$|jit_h_primpush$|real_|decimal_|int_list$|from_list$|mk_some$|push_|put$|c_string|string_array|get_string$|prim_fast|list_length$|length_at$)/) return "primitives"
  if (s ~ /^(vm_loop|loop_fast|loop_traced|loop_debug|vm_run$|vm_start$|check_tag|expect_obj|op_[A-Z]|closure_function)/) return "interpreter"
  if (s ~ /^(jit_run$|jit_h_(call|called|ret|tailcall|grow|grow_frames|setenv|interrupt|fatal|fatal_at)$|vm_grow_|jit_landing$|jit_osr$|jit_site$|stack_overflow|make_room$|poll_slow$|vm_interrupt$|native_)/) return "JIT stubs and calls"
  if (s ~ /^(jit_compile|jit_tier_up$|jit_make$|jit_fill|jit_depend$|jit_label$|jit_program$|jit_region_init$|jit_invalidate$|jit_unsupported$|jit_print_stats$|jit_check$|perf_map$|ms_|x64_|a64_|asm_|emit_|modrm_mem$|rex$|rel32$|sse_|op_rr|alloc$|branch$|called$|closure$|equal$|set_order$|floor_div$|index_of$|checked_tag$|to_callee|room$|room_dynamic$|frame_room$|ref_room$|home_to_slot$|slot_to_home$|result_at|uses_defs|fill_unit_dynamic$|count_arg$|bug$|live_|choose_homes|reg_(uses_defs|liveness)$|as_|writeback|rd_svar$|jit_fatal$)/) return "JIT compiler"
  if (s ~ /^(_int_malloc|malloc|malloc_consolidate|cfree|_int_free|realloc|__libc_calloc|__libc_malloc|unlink_chunk|free@plt|malloc@plt|__printf_buffer|__vsnprintf|__snprintf|_itoa_word)/) return "libc: malloc and printf"
  if (s ~ /^(image_|loader_|load_|validate_program|heap_relocate$|heap_read_|relocate_(fields|obj|value)$|read_segment$|heap_number$|heap_offset_of$|number_lines$)/) return "image and loader"
  return "other"
}
function group(s, dso, c,    cg) {
  if (dso ~ /kernel/) return "kernel"
  if (s ~ /^jit2:/) return "tier 2 code"
  if (s ~ /^jit1:/) return "tier 1 code"
  if (s ~ /^jit[0-9]+:/) return "JIT code, other tiers"
  if (s ~ /#[0-9]+$/) return "native code"
  if (s ~ /^_*mem(cpy|move|set|cmp)|^__mem|^_*memchr|^_*(str|wcs)(len|cmp|chr|nlen)/) {
    cg = group2(c)
    if (cg != "other" && cg != "interpreter" && cg != "JIT stubs and calls" && cg != "JIT compiler") return cg
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
  n = split("tier 2 code|tier 1 code|JIT code, other tiers|native code|interpreter|JIT stubs and calls|frames: walks, liveness, the barrier|collector: minor|collector: major|allocation|boxes (64-bit numbers, reals)|equality (runtime)|string order (runtime)|exceptions (runtime)|IntInf primitives|primitives|JIT compiler|image and loader|libc: malloc and printf|memmove/memcpy (other callers)|kernel|other", order, "|")
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
