(* A small executable model of the unit cache: the statement of what the
   checks of the cache are for (docs/units.md, Checking it; docs/testing.md,
   The checks of the cache; the build-system roadmap, D1, D18, D20).
   Not Rune's code: a model of what its cache must satisfy.

   A project is a list of units in order. Each unit declares names. A declaration is a constant
   the compiler may see through (Con), a value it may not (Dyn), or another name (Ref). An import
   has three layers, as a unit's interface would:
     static          its type
     ABI             what a client's code may be built on: here, a known constant
     implementation  the rest: here, the number inside a Dyn
   Compiling a Ref reads the import's type always, and its known constant if the policy inlines.

   The property is S41: a warm build after any edit equals a cold build of the edited project, in
   the code and in what each unit exports.

   Each policy says what the compiler reads and what the key holds. The claim under test: a policy
   holds S41 exactly when its key covers everything its compile reads. *)

datatype ty = I | S
datatype rhs = Con of ty * int | Dyn of ty * int | Ref of string
type source = {name : string, decls : (string * rhs) list}
type binding = {owner : string, ident : string, ty : ty, known : int option}
datatype instr = Imm of int | Load of string * string

type result = {code : instr list, exports : (string * binding) list}

datatype read = Static | StaticAndAbi

type policy =
  {name : string,
   reads : read,                                    (* what a compile reads of an import *)
   fp : binding option -> string,                   (* what the key holds of an import *)
   record : string -> bool}                         (* which reads become usages *)

fun tyName I = "I" | tyName S = "S"
fun intName n = Int.toString n
fun optName NONE = "-" | optName (SOME n) = intName n
fun rhsName (Con (t, n)) = "C" ^ tyName t ^ intName n
  | rhsName (Dyn (t, n)) = "D" ^ tyName t ^ intName n
  | rhsName (Ref x) = "R" ^ x
fun sourceName ({name, decls} : source) =
  String.concatWith ";" (name :: map (fn (x, r) => x ^ "=" ^ rhsName r) decls)

fun lookup (env : (string * binding) list) x =
  Option.map #2 (List.find (fn (y, _) => y = x) env)

(* Compile one unit: its code, its exports, and the names it read *)
fun compile (p : policy) env ({name, decls} : source) =
  let
    fun step ((x, r), (code, out, usedNames)) =
      let
        val scope = out @ env
        fun own (ty, known) = {owner = name, ident = "", ty = ty, known = known} : binding
      in
        case r of
          Con (t, n) => (Imm n :: code, (x, own (t, SOME n)) :: out, usedNames)
        | Dyn (t, n) => (Imm n :: code, (x, own (t, NONE)) :: out, usedNames)
        | Ref y =>
            (case lookup scope y of
               NONE => (Imm ~1 :: code, (x, own (I, NONE)) :: out, y :: usedNames)
             | SOME (b : binding) =>
                 let val known = case #reads p of Static => NONE | StaticAndAbi => #known b
                     val i = case known of SOME n => Imm n | NONE => Load (#owner b, y)
                 in (i :: code, (x, own (#ty b, known)) :: out, y :: usedNames) end)
      end
    val (code, out, usedNames) = List.foldl step ([], [], []) decls
    val usages = List.mapPartial
      (fn y => if #record p y then SOME (y, #fp p (lookup env y)) else NONE) (rev usedNames)
    (* an identity is Merkle: the source and what its usages held *)
    val ident = sourceName {name = name, decls = decls} ^ "<" ^
                String.concatWith "," (map (fn (y, f) => y ^ ":" ^ f) usages) ^ ">"
    val out = map (fn (x, b : binding) =>
                     (x, {owner = #owner b, ident = ident, ty = #ty b, known = #known b})) out
  in ({code = rev code, exports = out} : result, usages) end

type entry = {key : string, usages : (string * string) list, result : result}

(* A build: in order, each unit from the cache where a usage set holds, else compiled *)
fun build (p : policy) (cache : entry list ref) (project : source list) =
  let
    fun holds env (y, f) = #fp p (lookup env y) = f
    fun unit (src, (env, results, compiled)) =
      let val key = sourceName src
      in
        case List.find (fn (e : entry) => #key e = key andalso List.all (holds env) (#usages e)) (!cache) of
          SOME e => (#exports (#result e) @ env, #result e :: results, compiled)
        | NONE =>
            let val (r, usages) = compile p env src
                val () = cache := {key = key, usages = usages, result = r} :: !cache
            in (#exports r @ env, r :: results, compiled + 1) end
      end
    val (_, results, compiled) = List.foldl unit ([], [], 0) project
  in (rev results, compiled) end

(* What a program can observe: not a binder's identity, which is the key's business *)
fun observe (r : result) =
  (#code r, map (fn (x, b : binding) => (x, #owner b, #ty b, #known b)) (#exports r))

fun same (a, b) = ListPair.allEq (fn (x, y) => observe x = observe y) (a, b)

fun imm (r : result) = length (List.filter (fn Imm _ => true | _ => false) (#code r))

(* The small projects: three units, every choice of each, and every edit from one to another *)
val xs = [Con (I, 1), Con (I, 2), Con (S, 1), Dyn (I, 1), Dyn (I, 2), Dyn (S, 1)]
val ys = [Ref "x", Con (I, 1), Dyn (I, 1)]
val zs = [Ref "y", Ref "x", Con (I, 1)]
val projects =
  List.concat (map (fn x => List.concat (map (fn y => map (fn z =>
    [{name = "A", decls = [("x", x)]}, {name = "B", decls = [("y", y)]}, {name = "C", decls = [("z", z)]}] : source list)
    zs) ys)) xs)

fun fpOf f NONE = "unbound"
  | fpOf f (SOME b) = f b
fun all _ = true

val policies : policy list =
  [{name = "binder identity, inlining", reads = StaticAndAbi, record = all,
    fp = fpOf (fn (b : binding) => #ident b)},
   {name = "static + ABI, inlining", reads = StaticAndAbi, record = all,
    fp = fpOf (fn (b : binding) => #owner b ^ tyName (#ty b) ^ optName (#known b))},
   {name = "static only, inlining (the hole)", reads = StaticAndAbi, record = all,
    fp = fpOf (fn (b : binding) => #owner b ^ tyName (#ty b))},
   {name = "ABI only, inlining (the hole)", reads = StaticAndAbi, record = all,
    fp = fpOf (fn (b : binding) => #owner b ^ optName (#known b))},
   {name = "static + ABI, a usage dropped (x)", reads = StaticAndAbi, record = fn y => y <> "x",
    fp = fpOf (fn (b : binding) => #owner b ^ tyName (#ty b) ^ optName (#known b))},
   {name = "static only, compile reads static (firewall)", reads = Static, record = all,
    fp = fpOf (fn (b : binding) => #owner b ^ tyName (#ty b))}]

fun run (p : policy) =
  let
    val pairs = ref 0
    val bad = ref 0
    val rebuilt = ref 0
    val inlined = ref 0
    fun cold project = build p (ref []) project
    fun one (before', after') =
      let
        val cache = ref []
        val _ = build p cache before'
        val (warm, n) = build p cache after'
        val (fresh, _) = cold after'
      in
        pairs := !pairs + 1;
        rebuilt := !rebuilt + n;
        inlined := !inlined + List.foldl (fn (r, k) => k + imm r) 0 fresh;
        if same (warm, fresh) then () else bad := !bad + 1
      end
  in
    List.app (fn a => List.app (fn b => one (a, b)) projects) projects;
    print (StringCvt.padRight #" " 46 (#name p) ^
           StringCvt.padLeft #" " 6 (Int.toString (!bad)) ^ " of " ^ Int.toString (!pairs) ^
           StringCvt.padLeft #" " 9 (Int.toString (!rebuilt)) ^
           StringCvt.padLeft #" " 9 (Int.toString (!inlined)) ^ "\n")
  end

val () = print (StringCvt.padRight #" " 46 "policy" ^ "wrong (S41)        rebuilt   constants inlined\n")
val () = List.app run policies
