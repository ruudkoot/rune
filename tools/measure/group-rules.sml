(* Declarative profiling categories preserved from the AWK baseline. *)
structure MeasureGroupRules =
struct
  val rules =
    [("^(vm_frames?_[a-z_]+|reg_frames?_[a-z_]+|reg_barrier_[a-z]+|step_down|read_header|frame_at|barrier_arm|frames_lower|vm_claim_stack|vm_clean_stack)$","frames: walks, liveness, the barrier"),
     ("^(collect_minor|minor_(pass|into|stack)|promote|promote_(obj|value|global)|copy_small|scan_(card|dirty|object|range)|gc_(born|queue|write)|nursery_(start|adapt))$","collector: minor"),
     ("^(mark_[a-z_]+|at_limit|bits_clear|chunk_bits_next|chunk_object_covering|old_place|immix_[a-z_]+|by_free|first_line|free_block|free_lines|list_blocks|next_hole|reset_holes|next|segfit_[a-z_]+|block_first|cells_of|classes|descriptor|forget_blocks|marked|push|new_chunk|los_[a-z_]+|take_run|units?_of|first_in|cycle_[a-z_]+|gc_shade_old|gray_left|mark_some|push_gray|shade|shade_(obj|value)|slice_point|compact_[a-z_]+|forward_(fields|obj|value)|fwd_(after|next)|collect_(into|pass)|copy_(next|obj|value)|fill_of|gc_after_cycle|gc_stack_roots|grown|vm_collect|vm_gc|chunk_(append|give|give_later|layout|take)|heap_chunks_release|pool_(keep|trim)|heap_check|heap_verify|check_(fail|marked|old|parse|ptr|value)|out_of_memory|heap_init)$","collector: major"),
     ("^(vm_alloc|vm_alloc_fields|vm_alloc_string|vm_string_from|vm_cons|jit_h_alloc|jit_alloc_slow|payload_size|alloc_young|alloc_next|alloc_view|raw_array|los_alloc)$","allocation"),
     ("^(jit_h_box_(num|real)|alloc_box|mk_box_vm|mk_(int|int64|word|word64)_vm|mk_real|real_boxes_make)$","boxes (64-bit numbers, reals)"),
     ("^(values_equal|values_equal\\.cold|p_imm_eq|p_poly_eq|p_ptr_eq|p_real_eq|jit_h_values_equal)$","equality (runtime)"),
     ("^(p_string_|str_cmp$|jit_h_string_order$)","string order (runtime)"),
     ("^(vm_raise|vm_raise_builtin|vm_push_handler|vm_pop_handler|jit_h_raise|jit_h_push_handler|print_exn_payload)$","exceptions (runtime)"),
     ("^(p_intinf|intinf_|p_inf_|mpz|__gmp)","IntInf primitives"),
     ("^(p_|jit_h_prim$|jit_h_primpush$|real_|decimal_|int_list$|from_list$|mk_some$|push_|put$|c_string|string_array|get_string$|prim_fast|list_length$|length_at$)","primitives"),
     ("^(vm_loop|loop_fast|loop_traced|loop_debug|vm_run$|vm_start$|check_tag|expect_obj|op_[A-Z]|closure_function)","interpreter"),
     ("^(jit_run$|jit_h_(call|called|ret|tailcall|grow|grow_frames|setenv|interrupt|fatal|fatal_at)$|vm_grow_|jit_landing$|jit_osr$|jit_site$|stack_overflow|make_room$|poll_slow$|vm_interrupt$|native_)","JIT stubs and calls"),
     ("^(jit_compile|jit_tier_up$|jit_make$|jit_fill|jit_depend$|jit_label$|jit_program$|jit_region_init$|jit_invalidate$|jit_unsupported$|jit_print_stats$|jit_check$|perf_map$|ms_|x64_|a64_|asm_|emit_|modrm_mem$|rex$|rel32$|sse_|op_rr|alloc$|branch$|called$|closure$|equal$|set_order$|floor_div$|index_of$|checked_tag$|to_callee|room$|room_dynamic$|frame_room$|ref_room$|home_to_slot$|slot_to_home$|result_at|uses_defs|fill_unit_dynamic$|count_arg$|bug$|live_|choose_homes|reg_(uses_defs|liveness)$|as_|writeback|rd_svar$|jit_fatal$)","JIT compiler"),
     ("^(_int_malloc|malloc|malloc_consolidate|cfree|_int_free|realloc|__libc_calloc|__libc_malloc|unlink_chunk|free@plt|malloc@plt|__printf_buffer|__vsnprintf|__snprintf|_itoa_word)","libc: malloc and printf"),
     ("^(image_|loader_|load_|validate_program|heap_relocate$|heap_read_|relocate_(fields|obj|value)$|read_segment$|heap_number$|heap_offset_of$|number_lines$)","image and loader")]
end
