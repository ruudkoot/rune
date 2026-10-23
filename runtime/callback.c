#include "vm.h"
#include "callback.h"

uint64_t vm_callback_live(VM *vm, const FrameRef *frame) {
    for (CallbackScope *s = vm->callback_scope; s; s = s->parent)
        if (s->has_live && s->parked_frame == frame->id) return s->parked_live;
    return vm->frame_live(vm, frame->func, frame->pc);
}

int vm_callback_apply(VM *vm, size_t handle, const char *input, size_t length,
                      char *output, size_t capacity, size_t *written) {
    if (!vm->callback_loop || vm->callback_depth >= 64 || length > UINT32_MAX) return -1;
    Value cv = vm_handle_get(vm, handle);
    if (!val_is_ptr(cv) || obj_kind(val_ptr(cv)) != K_CLOSURE) return -1;
    uint32_t f = (uint32_t)val_imm(obj_field(val_ptr(cv), 0));
    if (f >= vm->prog.nfuncs) return -1;
    FrameRef parked;
    if (!vm_frame_top(vm, &parked)) return -1;
    CallbackScope scope = {vm->callback_scope, parked.id, vm->top_live, vm_frame_top_live(vm, &parked)};
    size_t old_sp = vm->sp, old_hp = vm->hp, old_boundary = vm->callback_frame;
    uint32_t old_pc = vm->pc;
    NativeSafepoints saved;
    vm_safepoints_save(vm, &saved);
    uint64_t old_live = vm->top_live;
    vm->callback_scope = &scope;
    vm->callback_depth++;
    vm->interrupt_mask++;
    vm->top_frame = NULL;
    vm->verify_frame = NULL;
    /* Preserve the input in a handle before pushing the callback frame. */
    Obj *arg = vm_string_from(vm, input, (uint32_t)length);
    size_t argument = vm_handle_new(vm, mk_ptr(arg));
    cv = vm_handle_get(vm, handle);
    const Function *fn = &vm->prog.funcs[f];
    size_t base = vm_frame_push(vm, f, val_ptr(cv), old_pc, old_sp);
    for (uint32_t i = 0; i < fn->nlocals; i++) vm->stack[base + i] = mk_unit();
    vm->stack[base] = vm_handle_get(vm, argument);
    vm_handle_free(vm, argument);
    vm->sp = base + fn->nlocals;
    vm->pc = fn->code_offset;
    vm->callback_frame = vm_frame_id(vm);
    int status = vm->callback_loop(vm);
    Value result = vm->callback_result;
    int ok = status == 3 && vm->hp == old_hp && val_is_ptr(result) && obj_kind(val_ptr(result)) == K_STRING && obj_len(val_ptr(result)) <= capacity;
    if (ok) {
        *written = obj_len(val_ptr(result));
        memcpy(output, obj_bytes(val_ptr(result)), *written);
    }
    vm_frame_drop(vm);
    vm->sp = old_sp; vm->hp = old_hp; vm->pc = old_pc;
    vm->callback_frame = old_boundary;
    vm->callback_result = mk_unit();
    vm->callback_scope = scope.parent;
    vm->callback_depth--;
    vm->interrupt_mask--;
    vm->top_live = old_live;
    vm_safepoints_restore(vm, &saved);
    return ok ? 0 : -1;
}
