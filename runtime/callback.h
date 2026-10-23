#ifndef RUNE_CALLBACK_H
#define RUNE_CALLBACK_H
/* This scope is a C activation, never serialized. Frame identities and
   masks survive moving value stacks and frame arrays. */
typedef struct CallbackScope {
    struct CallbackScope *parent;
    size_t parked_frame;
    uint64_t parked_live;
    int has_live;
} CallbackScope;
#endif
