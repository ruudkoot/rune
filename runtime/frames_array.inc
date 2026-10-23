/* The frames as an array of records (vm->frames, vm.h's Frame), as the
   runtime walks them (vm.h, *The frames, as the runtime reads them*;
   docs/plans/native-frames.md, M3): included by the instruction sets
   whose engines keep their frames so -- runtime/stack/isa_stack.c --
   which defines these for the rest of the runtime. A frame's id is its
   index. (runtime/register's frames are in the value stack, isa_regs.c:
   native-frames.md, M4.) */

/* frame i as the runtime reads it: its pc is the VM's where it runs, else
   where the frame above it returns to */
static void frame_at(VM *vm, size_t i, FrameRef *f) {
    const Frame *fr = &vm->frames[i];
    f->func = fr->func;
    f->ret_pc = fr->ret_pc;
    f->base = fr->base;
    f->id = i;
    f->head = fr->base;
    f->closure = fr->closure;
    f->closure_root = &vm->frames[i].closure;
    f->closure_slot = NULL;
    f->stale_slot = NULL;
    f->pc = i == vm->fp ? vm->pc : vm->frames[i + 1].ret_pc;
    f->bottom = i == 0;
    f->caller_base = i ? vm->frames[i - 1].base : 0;
    f->caller_func = i ? vm->frames[i - 1].func : 0;
}

const uint32_t isa_frame_header = 0;

size_t vm_frame_id(const VM *vm) { return vm->fp; }

int vm_frame_top(VM *vm, FrameRef *f) {
    if (!vm->frames_active || vm->fp >= vm->frames_cap) return 0;   /* (a fatal error may come before the frame is pushed) */
    frame_at(vm, vm->fp, f);
    return 1;
}

int vm_frame_down(VM *vm, FrameRef *f) {
    if (f->id == 0) return 0;
    frame_at(vm, f->id - 1, f);
    return 1;
}

int vm_frame_find(VM *vm, size_t id, FrameRef *f) {
    if (!vm->frames_active || id > vm->fp) return 0;
    frame_at(vm, id, f);
    return 1;
}

size_t vm_frames_from(VM *vm, size_t low, FrameRef **out) {
    *out = NULL;
    if (!vm->frames_active || low > vm->fp) return 0;
    size_t n = vm->fp - low + 1;
    if (n > vm->frame_buf_cap) {
        size_t cap = vm->frame_buf_cap ? vm->frame_buf_cap : 64;
        while (cap < n) cap *= 2;
        FrameRef *b = realloc(vm->frame_buf, cap * sizeof *b);
        if (!b) vm_fatal(vm, "out of memory (the frames walked)");
        vm->frame_buf = b;
        vm->frame_buf_cap = cap;
    }
    for (size_t k = 0; k < n; k++) frame_at(vm, low + k, &vm->frame_buf[k]);
    *out = vm->frame_buf;
    return n;
}

int vm_frame_top_live(const VM *vm, const FrameRef *top) { return vm->top_frame == (const void *)&vm->frames[top->id]; }

void vm_frames_mark_low(VM *vm, size_t id) { vm_set_fp_low(vm, id); }
const char *vm_frames_check(VM *vm) { (void)vm; return NULL; }

size_t vm_frames_low(const VM *vm) { return vm->fp_low; }

size_t vm_frame_push(VM *vm, uint32_t func, Obj *closure, uint32_t ret_pc, size_t top) {
    vm_push_frame(vm, func, closure, ret_pc, top);
    return top;
}

void vm_frame_drop(VM *vm) { vm_frame_pop(vm); }

void vm_frame_top_level(VM *vm) {
    vm->sp = 0;
    vm_push(vm, mk_unit());
    for (uint32_t i = 1; i < vm->prog.funcs[0].nlocals; i++) vm_push(vm, mk_unit());
    vm_push_frame(vm, 0, NULL, 0, 0);
}

void vm_frame_unwind(VM *vm, size_t id, uint32_t func) {
    (void)func;
    vm->fp = id;
    if (vm->fp < vm->fp_low) vm_set_fp_low(vm, vm->fp);
}

int vm_frames_install(VM *vm, const FrameRecord *frames, size_t n, const char **err) {
    *err = "out of memory";
    free(vm->frames);
    vm->frames = NULL;
    vm->frames_active = n > 0;
    vm->fp = n ? n - 1 : 0;
    if (!n) return 1;
    vm->frames_cap = n < 256 ? 256 : n;
    vm->frames = malloc(vm->frames_cap * sizeof(Frame));
    if (!vm->frames) return 0;
    for (size_t i = 0; i < n; i++) {
        vm->frames[i].func = frames[i].func;
        vm->frames[i].ret_pc = frames[i].ret_pc;
        vm->frames[i].base = frames[i].base;
        vm->frames[i].closure = frames[i].closure;
        vm->frames[i].native_ret = NULL;          /* not in an image: the VM's return trampoline (vm_become, make_room) */
        vm->frames[i].result = UINT32_MAX;        /* the loop reads it from the code at ret_pc */
    }
    return 1;
}

void vm_frames_to_interpreter(VM *vm) {
    for (size_t i = 0; vm->frames_active && i <= vm->fp; i++) {
        vm->frames[i].native_ret = vm->ret_tramp;
        vm->frames[i].result = UINT32_MAX;   /* the loop's RET reads it from the code (vm.h, Frame) */
    }
}

/* Native safepoints in this instruction set name separate frame records. */
void vm_safepoints_save(const VM *vm, NativeSafepoints *saved) {
    saved->has_top = vm->top_frame != NULL;
    saved->has_verify = vm->verify_frame != NULL;
    saved->top = saved->has_top ? (const Frame *)vm->top_frame - vm->frames : 0;
    saved->verify = saved->has_verify ? (const Frame *)vm->verify_frame - vm->frames : 0;
}
void vm_safepoints_restore(VM *vm, const NativeSafepoints *saved) {
    vm->top_frame = saved->has_top ? (const void *)(vm->frames + saved->top) : NULL;
    vm->verify_frame = saved->has_verify ? (const void *)(vm->frames + saved->verify) : NULL;
}
