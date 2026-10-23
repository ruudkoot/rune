/* Independent regression input: compare Rune tokens with clang -E -P. */
#define OBJECT 17
#define TWICE(x) ((x) + (x))
#define ALIAS TWICE
#define SELF SELF
#define INDIRECT FIRST
#define FIRST(x) x
#define CAT(a,b) a ## b
#define STRING(x) #x
#define EXPAND_STRING(x) STRING(x)
#define VAR(first,...) first __VA_ARGS__
#define EMPTY(x)
#define JOIN_EMPTY(x,y) x ## y
#if defined(OBJECT) && !defined(MISSING) && (0 && (1 / 0) || 1)
TWICE(OBJECT)
ALIAS(3)
CAT(0x,ff)
STRING(a + "b")
EXPAND_STRING(OBJECT)
SELF
INDIRECT(INDIRECT)(4)
VAR(9, + 2, + 3)
JOIN_EMPTY(,end) JOIN_EMPTY(start,) JOIN_EMPTY(,)
EMPTY(ignored)
#endif
#if 0
#error inactive
#elif (1 ? -1 : 1U) > 0
unsigned_conditional
#else
#error incorrect conditional type
#endif
#define SPLICED va\
lue
SPLICED
/* Across lines and a directive's block comment. */
#define COMMENTED /* multi
line */ 42
COMMENTED
