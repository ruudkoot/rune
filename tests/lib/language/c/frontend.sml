(* C11 translation phases and declaration grammar, with hand-derived
   expectations. Independent clang agreement is tested separately. *)
structure CFrontendTests =
struct
  val checks = ref 0
  fun check (name, condition) = (checks := !checks + 1; if condition then () else raise Fail name)
  fun lex text = CLex.scan {file = "fixture.h", text = text}
  fun texts tokens = List.map (fn (t : CLex.token) => #text t) tokens
  fun scan text = List.filter (fn (t : CLex.token) => #kind t <> CLex.Newline) (lex text)
  val () = check ("maximal tokens", texts (scan "a->b >>= 1 ... .5 0x1p+3 u8\"a\" L'x'") =
    ["a", "->", "b", ">>=", "1", "...", ".5", "0x1p+3", "u8\"a\"", "L'x'"])
  val spliced = scan "fi\\\nrst /* comment */ second\nthird"
  val () = check ("splicing precedes lexing", texts spliced = ["first", "second", "third"])
  val () = check ("physical location survives splice", #line (#location (List.nth (spliced, 2))) = 3)
  val () = check ("comment makes separating space", #space (List.nth (spliced, 1)))
  val () = check ("trigraphs precede line splicing", texts (scan "??=define X va??/\nlue") = ["#", "define", "X", "value"])
  val () = check ("remaining preprocessing characters", texts (scan "param\\t dollar$name") = ["param", "\\", "t", "dollar$name"])
  val () = check ("BOM at source start", texts (scan "\239\187\191int x;") = ["int", "x", ";"])
  fun lexFails text = ((ignore (lex text); false) handle CLex.Error _ => true)
  val () = List.app (fn s => check ("bad lexical input", lexFails s)) ["/*", "\"unterminated", "'x\n'", "\000"]
  fun eval width text = CConst.evaluate {width = width, lookup = fn _ => NONE, tokens = scan text}
  fun integer text = #integer (eval 64 text)
  val () = check ("precedence", integer "1 + 2 * 3 << 2" = 28)
  val () = check ("unary and bit operations", integer "~0 & 0xff" = 255)
  val () = check ("C quotient and remainder", integer "-7/3" = ~2 andalso integer "-7%3" = ~1)
  val () = check ("short circuit", integer "0 && (1/0)" = 0 andalso integer "1 || (1/0)" = 1)
  val () = check ("lazy conditional", integer "1 ? 42 : (1/0)" = 42)
  val () = check ("conditional usual conversion", integer "(1 ? -1 : 1U) > 0" = 1)
  val () = check ("unsigned wrap", #integer (eval 32 "0xffffffffU + 1") = 0)
  val () = check ("64-bit unsigned maximum", integer "0xffffffffffffffffULL" = 18446744073709551615)
  val () = check ("Microsoft integer suffix", integer "0xffffffffffffffffui64" = 18446744073709551615)
  val () = check ("character escapes", integer "'\\n' + '\\x20' + '\\101'" = 107)
  fun constFails text = ((ignore (eval 64 text); false) handle CConst.Error _ => true)
  val () = List.app (fn s => check ("invalid constant", constFails s))
    ["1/0", "1 << -1", "1 << 64", "9223372036854775807 + 1", "09", "1 +", "1 2", "'ab'", "(-9223372036854775807 - 1) % -1",
     "'\\xFFFFFFFFFFFFFFFFFFFFFFFF'", "0 && unresolved", "0 && 18446744073709551616U"]
  fun preprocess text = CPreprocess.run {source = {file = "fixture.h", text = text}, predefined = [],
    resolve = fn {name, ...} => if name = "guard.h" then SOME {file = "guard.h", text =
      "#ifndef GUARD\n#define GUARD\nheader\n#include <guard.h>\n#endif\n"} else NONE,
    width = 64, maxDepth = 8, maxExpansions = 10000}
  fun pp text = texts (#tokens (preprocess text))
  val () = check ("function alias rescans", pp "#define F(x) (x)\n#define A F\nA(42)\n" = ["(", "42", ")"])
  val () = check ("nested arguments", pp "#define F(x) x x\nF(F(1))\n" = ["1", "1", "1", "1"])
  val () = check ("self macro hides", pp "#define X X\nX X\n" = ["X", "X"])
  val () = check ("paste and empty arguments", pp "#define C(a,b) a ## b\nC(2,1) C(,x) C(x,) C(,)\n" = ["21", "x", "x"])
  val () = check ("stringification versus expansion", pp "#define S(x) #x\n#define E(x) S(x)\n#define N 42\nS(N) E(N) S(a + b)\n" =
    ["\"N\"", "\"42\"", "\"a + b\""])
  val () = check ("variadic replacement", pp "#define V(x,...) x __VA_ARGS__\nV(1,+2,+3)\n" = ["1", "+", "2", ",", "+", "3"])
  val () = check ("conditional inactive arithmetic", pp "#if 0\n#if 1/0\n#error no\n#endif\n#elif defined(NO)\nno\n#else\nyes\n#endif\n" = ["yes"])
  val guarded = preprocess "#include <guard.h>\n#include <guard.h>\n"
  val () = check ("recursive include guard", texts (#tokens guarded) = ["header"] andalso #dependencies guarded = ["fixture.h", "guard.h"])
  val () = check ("include presence and expansion", pp "#define H <guard.h>\n#if __has_include(H)\nyes\n#endif\n" = ["yes"])
  val () = check ("literal header names do not expand", pp "#define guard not_a_header\n#include <guard.h>\n" = ["header"])
  val () = check ("include probe header names do not expand", pp "#define guard absent\n#if __has_include(<guard.h>)\nyes\n#endif\n" = ["yes"])
  val () = check ("line and counter builtins", pp "__LINE__ __COUNTER__\n__LINE__ __COUNTER__\n" = ["1", "0", "2", "1"])
  val () = check ("pragma macro stack", pp "#define X 1\n#pragma push_macro(\"X\")\n#undef X\n#define X 2\nX\n#pragma pop_macro(\"X\")\nX\n" = ["2", "1"])
  val origins = #tokens (preprocess "#define N 42\nN\n")
  val () = check ("macro source provenance", #line (#location (hd origins)) = 1 andalso #line (hd (#origins (hd origins))) = 2)
  val nestedOrigins = #tokens (preprocess "#define A B\n#define B 42\nA\n")
  val () = check ("nested macro provenance", length (#origins (hd nestedOrigins)) = 2 andalso
    #line (hd (#origins (hd nestedOrigins))) = 3)
  val () = check ("macro diagnostic uses invocation", ((ignore (CConst.evaluate {width = 64, lookup = fn _ => NONE,
    tokens = #tokens (preprocess "#define BAD (1/0)\nBAD\n")}); false)
    handle CConst.Error ({line, ...}, message) => line = 2 andalso String.isSubstring "expanded from" message))
  fun ppFails text = ((ignore (preprocess text); false) handle CPreprocess.Error _ => true)
  val () = List.app (fn s => check ("invalid preprocessing", ppFails s))
    ["#if 1\n", "#else\n", "#if 1\n#else\n#else\n#endif\n", "#include <absent.h>\n",
     "#define X 1\n#define X 2\n", "#define F(x,) x\n", "#define F(x,x) x\n", "#define F(x) x\nF(1,2)\n",
     "#define P(a,b) a ## b\nP(+,*)\n", "#define P(a,b) a ## b\nP(/,*)\n", "#define X ## x\n", "#error expected\n"]
  fun parse text = #declarations (CParse.translationUnit {tokens = scan text, predefinedTypes = []})
  val macroDeclarations = #declarations (CParse.translationUnit {tokens = #tokens (preprocess
    "#define API extern\nAPI int function(void);\n"), predefinedTypes = []})
  val () = check ("declaration location uses original invocation", case hd macroDeclarations of
    CParse.Declaration {location = {line, ...}, ...} => line = 2 | _ => false)
  val declarations = parse "typedef int T; T *array[3]; T (*pointer)[3]; typedef int (*callback)(void *, int); enum e {A, B=3}; struct s {unsigned lo:3; double v;};"
  val () = check ("declaration count", length declarations = 6)
  val () = check ("array of pointers", case List.nth (declarations, 1) of
    CParse.Declaration {ctype = CParse.Array {element = CParse.Pointer {target = CParse.Named "T", ...}, ...}, ...} => true | _ => false)
  val () = check ("pointer to array", case List.nth (declarations, 2) of
    CParse.Declaration {ctype = CParse.Pointer {target = CParse.Array {element = CParse.Named "T", ...}, ...}, ...} => true | _ => false)
  val () = check ("function pointer", case List.nth (declarations, 3) of
    CParse.Declaration {ctype = CParse.Pointer {target = CParse.Function {parameters, variadic = false, ...}, ...}, ...} => length parameters = 2 | _ => false)
  val () = check ("bitfields retained", case List.nth (declarations, 5) of
    CParse.Declaration {ctype = CParse.Record {fields = SOME (CParse.Field {bits, ...} :: _), ...}, ...} => texts bits = ["3"] | _ => false)
  val () = check ("abstract and unnamed parameters", length (parse "int f(void); int (*g(int (*)(int)))(double); int *h(int, ...);") = 3)
  val () = check ("inline body retained", case hd (parse "static inline int twice(int x) { if (x) { return x*2; } return 0; }") of
    CParse.Declaration {body, storage, ...} => not (null body) andalso storage = ["static", "inline"] | _ => false)
  val packed = #declarations (CParse.translationUnit {tokens = #tokens (preprocess
    "#pragma pack(push,1)\nstruct s {char c; int n;};\n#pragma pack(pop)\nstruct t {int n;};\n"), predefinedTypes = []})
  val () = check ("packing retained and restored", case packed of
    [CParse.Declaration {ctype = CParse.Record {pack = SOME 1, ...}, ...},
     CParse.Declaration {ctype = CParse.Record {pack = NONE, ...}, ...}] => true | _ => false)
  val pragmaAttribute = #declarations (CParse.translationUnit {tokens = #tokens (preprocess
    "typedef struct __declspec(align(16)) __pragma(warning(push)) __declspec(no_init_all) __pragma(warning(pop)) s {int x;} T;"), predefinedTypes = []})
  val () = check ("MS attributes and embedded pragmas", length pragmaAttribute = 1)
  val () = check ("static assertions retained", case hd (parse "_Static_assert(1,\"ok\");") of CParse.StaticAssert _ => true | _ => false)
  val enumerators = CEnumConst.collect (parse "enum e { EA=-3, EB, EC=1U<<5, ED }; struct s {enum {EE=4, EF} field;} a,b;")
  fun enum name = #integer (CEnumConst.evaluate {environment = enumerators, width = 64, name = name})
  val () = check ("negative implicit enumerator", enum "EB" = ~2)
  val () = check ("enum expression and implicit successor", enum "ED" = 33)
  val () = check ("aggregate enum is collected once", enum "EF" = 5)
  val () = check ("forward enum reference rejected", ((ignore (CEnumConst.evaluate {environment =
    CEnumConst.collect (parse "enum e {A=B,B=1};"), width = 64, name = "A"}); false) handle CEnumConst.Error _ => true))
  fun parseFails s = ((ignore (parse s); false) handle CParse.Error _ => true)
  val () = List.app (fn s => check ("invalid declaration", parseFails s))
    ["int x", "int (*f)(int;", "struct { int x;", "typedef int;", "int a[3);", "unknown x;", "struct s {int x = 1;};"]
  val originalFile=CFiles.read "tests/ffi/preprocess.h"
  val ()=check("file source identity is absolute",OS.Path.isAbsolute(#file originalFile) andalso size(#text originalFile)>0)
  val fileResolver=CFiles.resolver["tests/ffi"]
  val ()=check("relative include roots produce the same canonical source",case fileResolver{from="<fixture>",name="preprocess.h",system=true,next=false} of
    SOME resolved=>resolved=originalFile | NONE=>false)
  val ()=check("include_next recognizes canonical source root",not(isSome(fileResolver{from= #file originalFile,name="preprocess.h",system=true,next=true})))
  val nextResolver=CFiles.resolver["tests/ffi","tests"]
  val ()=check("include_next searches the following root",case nextResolver{from= #file originalFile,name="ffi/preprocess.h",system=true,next=true} of
    SOME resolved=>resolved=originalFile | NONE=>false)
  val () = print ("PASS language/c: " ^ Int.toString (!checks) ^ " checks\n")
end
