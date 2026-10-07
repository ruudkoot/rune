/* --gc-log FILE (docs/runtime.md, *The collector's log*): a line for every
   pass of the collector, in the columns its header names, and lines at
   exit that agree with --count and --stats. */
#include "gc/gc.h"
#include "sys/sys.h"

/* What a pass began with: the allocation clock (deterministic: bytes and
   objects the program allocated, instructions executed, the boxes apart),
   the bytes in the heap and the clocks. The thread's processor time is
   read where there is a log alone. */
void log_pass_begin(VM *vm, PassMark *m) {
    m->bytes = vm->bytes_allocated;
    m->objects = vm->objects_allocated;
    m->instrs = vm->instructions;
    m->boxes = vm->boxes_allocated;
    m->box_bytes = vm->box_bytes_allocated;
    m->used_before = USED_STOCK(vm);
    m->cpu0 = vm->gc_log ? sys_thread_time_ns() : 0;
    m->t0 = sys_clock_ns();
}

void log_pass_end(VM *vm, const PassMark *m, const char *kind, int64_t pause) {
    if (!vm->gc_log) return;
    int64_t cpu = sys_thread_time_ns() - m->cpu0;
    uint64_t resident, peak_resident, peak_virtual;
    sys_mem_usage(&resident, &peak_resident, &peak_virtual);
    /* seq kind vmgc bytes objects instrs boxes box_bytes used_before copied
       copied_objs promoted slots live_slots frames other_roots cards_dirty
       cards_scanned remembered live_after heap_size pause_ns cpu_ns
       rss_bytes t_ns cards_young fields_scanned */
    /* copied: a minor's promotion, a full's whole copy */
#ifdef RUNE_CENSUS
    uint64_t copied = kind[0] == 'm' ? vm->gc_counts.promoted : (uint64_t)vm->gc.to_used_stock;
#else
    uint64_t copied = kind[0] == 'm' ? vm->gc_counts.promoted : (uint64_t)vm->gc.to_used;
#endif
    fprintf(vm->gc_log, "%llu %s %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %lld %lld %llu %lld %llu %llu\n",
            (unsigned long long)vm->gc_count, kind, (unsigned long long)vm->gc_calls,
            (unsigned long long)m->bytes, (unsigned long long)m->objects, (unsigned long long)m->instrs,
            (unsigned long long)m->boxes, (unsigned long long)m->box_bytes, (unsigned long long)m->used_before,
            (unsigned long long)copied, (unsigned long long)vm->gc_counts.objects,
            (unsigned long long)vm->gc_counts.promoted,
            (unsigned long long)vm->gc_counts.slots, (unsigned long long)vm->gc_counts.live_slots,
            (unsigned long long)vm->gc_counts.frames, (unsigned long long)vm->gc_counts.other_roots,
            (unsigned long long)vm->gc_counts.cards_dirty, (unsigned long long)vm->gc_counts.cards_scanned,
            (unsigned long long)vm->gc_counts.remembered,
            (unsigned long long)USED_STOCK(vm), (unsigned long long)vm->gc.size,
            (long long)pause, (long long)cpu, (unsigned long long)resident, (long long)(m->t0 - vm->gc_log_t0),
            (unsigned long long)vm->gc_counts.cards_young, (unsigned long long)vm->gc_counts.fields);
}

void heap_log_open(VM *vm, const char *path) {
    vm->gc_log = fopen(path, "w");
    if (!vm->gc_log) { fprintf(stderr, "runevm: --gc-log %s: cannot open\n", path); exit(2); }
    fprintf(vm->gc_log, "# rune-gc-log 1 nursery=%zu heap=%zu fill=%u limit=%zu\n", vm->gc.nursery_size, vm->gc.size, vm->heap_fill, vm->heap_limit);
    fprintf(vm->gc_log, "# seq kind vmgc bytes objects instrs boxes box_bytes used_before copied copied_objs promoted "
            "slots live_slots frames other_roots cards_dirty cards_scanned remembered live_after heap_size "
            "pause_ns cpu_ns rss_bytes t_ns cards_young fields_scanned\n");
    vm->gc_log_t0 = sys_clock_ns();
}

/* the end of the run: the clock where it stopped, and the peaks */
void heap_log_close(VM *vm) {
    if (!vm->gc_log) return;
    uint64_t resident, peak_resident, peak_virtual;
    sys_mem_usage(&resident, &peak_resident, &peak_virtual);
    fprintf(vm->gc_log, "# end bytes %llu objects %llu instrs %llu boxes %llu box_bytes %llu collections %llu gc_ns %llu "
            "vmpeak_kb %llu vmhwm_kb %llu\n",
            (unsigned long long)vm->bytes_allocated, (unsigned long long)vm->objects_allocated,
            (unsigned long long)vm->instructions, (unsigned long long)vm->boxes_allocated,
            (unsigned long long)vm->box_bytes_allocated, (unsigned long long)vm->gc_count,
            (unsigned long long)vm->gc_ns, (unsigned long long)(peak_virtual / 1024),
            (unsigned long long)(peak_resident / 1024));
    fprintf(vm->gc_log, "# wall_ns %lld\n", (long long)(sys_clock_ns() - vm->gc_log_t0));
    fclose(vm->gc_log);
    vm->gc_log = NULL;
}
