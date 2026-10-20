/* runtime/register's debug loop (the REPL roadmap's D22 and M12;
   runtime/debug.c), in a file of its own beside interp.c's loops: the same
   bodies (reg_loop.h), with the debugger's words. */
#include "reg_words.h"

/* The debug loop (the REPL roadmap's D22, M12; runtime/debug.c), which the
   driver runs while debug mode is on: interpreted throughout -- no code of
   the JIT is entered, a frame whose caller is compiled code returning into
   the interpreter, which the frame's state allows, as an image's does --
   and, while something may stop the program, each instruction looked at
   first: a new line in its frame, a frame left by a step, a pause asked
   for. A call makes a new frame of the lines; the user's interrupt is a
   pause where the debugger says so. When debug mode ends it gives the
   program back to the driver. */
#define DEBUG_BEGUN() ((void)0)
#define HANDOVER(f) do { (void)(f); if (vm->dbg->check) dbg_new_frame(vm); } while (0)
#define BACKWARD(t) ((void)(t))
#define RESUME_NATIVE(f, at_pc) ((void)(f), (void)(at_pc))
#define RETURN_NATIVE(at_) ((void)(at_))
#define RETURN_LANDING(w, v) ((void)(w), (void)(v))
#define RAISED() NEXT
#define NEW_PROGRAM() ((void)jit)
#define POLL(len) \
    if (vm->interrupt & 1) { \
        if (!vm->interrupt_mask) { \
            if (vm->dbg->pauses && dbg_pause(vm)) { pc -= (len); count--; NEXT; } \
            SYNC(); vm_interrupt(vm); RELOAD(); RAISED(); \
        } \
    } else (void)0
#define DBG_CHECK() \
    do { \
        Debugger *d_ = vm->dbg; \
        if (d_->check) { \
            if (!d_->on && !d_->in_hook) { SYNC(); return RUN_INTERP; } \
            uint32_t k_ = dbg_key(vm, d_, vm->func, pc); \
            if (vm->fp >= d_->nframe_keys || k_ != d_->frame_key[vm->fp] || vm->fp < d_->step_fp || d_->pending) { \
                SYNC(); \
                if (dbg_event(vm, pc, k_)) RELOAD(); \
            } \
        } \
    } while (0)
#define LOOP_NAME loop_debug_body
#define TRACED 0
#include "reg_loop.h"
#undef LOOP_NAME
#undef TRACED

int loop_debug(VM *vm, JitProgram *jit) { return loop_debug_body(vm, jit); }

