(* Programs of functors, generated, as a property of the compiler
   (docs/testing.md, *Generated functor programs*; functors-units.md, before
   M7): every program prints the same compiled whole and in units, with
   functors compiled as functions and their applications expanded
   (`--functors=functions --datatype-tags=sorted-x`) and as today's copies,
   and compiles clean under `--lint` with the flag on; `--units --whole`
   gives the whole compile's bytes (S42); and so does it with
   `--inline-functor` for its functors, and with a small `--functor-budget`,
   which leaves some applications calls.

   A program is drawn as a plan of choices by lib/test/property, so that a
   failing one is shrunk, and the plan is then made a program that is well
   typed by construction: a reference to a functor, a structure or a field
   that is not there, or an argument that does not match, falls back to one
   that does (a literal structure matches every parameter). Its shapes are
   the module language's hard ones: functors applied in functors' bodies,
   to their parameter, to an inner application, to a literal or an adapter
   of the parameter; datatypes in bodies -- plain, mutually recursive, with
   `withtype`, polymorphic, local, replicated from a parameter's datatype
   spec -- over the parameter's types, some members shown by the result
   signature and some hidden; constructors of tuples, records and
   parameter types; leaves whose types are of every layout; `eqtype` and
   datatype specs (matched by datatypes whose constructors are in another
   order), `where type`, `sharing`, opaque and transparent ascription;
   polymorphic values and type constructors in parameters and results;
   exceptions, refs and effects in bodies, `open`, `local` and nested
   structures. What it prints makes each visible: results through every
   instance, matches on constructors, handled exceptions across instances,
   counts of effects and equalities.

   The units of a program are its files: a prelude of signatures and
   leaves, the functors (a unit for each, or several in one), the
   applications and the prints, so that a functor is declared in one unit
   and applied in another, or in its own. *)
structure FunctorGen =
struct
  structure P = PropertySource

  (* ---- the plan: what a case draws *)

  (* the type of a field of a constructor, as drawn: what is not there where
     it is made (an inner instance in a body without one, a parameter's Sub
     not asked for) is made something that is *)
  datatype field = FInt | FStr | FX | FY | FInner of int | FPair of field * field | FRec of field * field
                 | FSelf | FOther | FSub | FBox of field | FList of field | FOpt of field | FReal | FFun | FTree of field

  type con = {fields : field list, record : bool}

  (* what a functor's body makes its type t: the parameter's or an inner
     instance's; a datatype; two, mutually recursive; one with an
     abbreviation of withtype; a polymorphic datatype's instance; a local
     datatype; the parameter's datatype replicated *)
  datatype rep = RAlias of int | RData of con list | RMutual of con list * con list | RWith of field * con list
               | RCell of field | RLocal of con list | RRepl

  (* a structure of the leaves: the representation of its t, the order of
     its datatype's constructors, its Sub and its box *)
  type leaf = {rep : int, perm : int, sub : int, box : int}

  (* an argument: the parameter, an inner instance, a structure of the top
     level, an adapter of the parameter, an application, a literal *)
  datatype arg = AParam | AInner of int | APath of int | AAdapter of int | AApp of int * arg | ALit of leaf

  type param = {form : int, eq : bool, dt : int option, exn : bool, count : bool, sub : bool, poly : bool,
                named : bool, perm : int, kval : int, tree : bool}
  type body = {tick : bool, openX : bool, hide : bool, inners : (int * arg * int) list, rep : rep, exn : int,
               carry : bool, count : bool, sub : int, poly : int, pair : bool, inner : bool, via : bool,
               probes : bool list}
  type result = {ascr : int, spec : int, named : bool, exn : bool, count : bool, sub : bool, poly : bool,
                 pair : bool, inner : bool}
  type fplan = {param : param, body : body, result : result}
  type app = {target : int, arg : arg, wrap : int, alias : bool}
  type plan = {leaves : leaf list, functors : fplan list, apps : app list, breaks : bool list, budget : int,
               inline : int, budgetUnits : bool}

  (* ---- drawing a plan; each part at a child of its own, so that the
     shrinker changes one and leaves the rest *)
  fun at (s, a) i (g : 'a Gen.gen) : 'a = Gen.draw g (s, P.child (a, i))
  fun choice n : int Gen.gen = Gen.elements (Vector.tabulate (Int.max (n, 1), fn i => i))
  fun weighted (ws : int list) : int Gen.gen =
    Gen.frequency (List.tabulate (length ws, fn i => (List.nth (ws, i), Gen.return i)))
  fun flag pct : bool Gen.gen = Gen.frequency [(100 - pct, Gen.return false), (pct, Gen.return true)]

  fun fieldGen depth : field Gen.gen =
    Gen.primitive (fn sa =>
      let
        val c = if depth <= 0 then 0 else 1
        (*        Int Str X  Y  Inner Pair   Rec    Self Other Sub Box List Opt Real Fun Tree *)
        val ws = [5,  2,  6, 1, 3,    2 * c, 2 * c, 3,   2,    1,  c,  c,   c,  1,   1,  c]
        fun sub i = at sa i (fieldGen (depth - 1))
      in
        case at sa 0 (weighted ws) of
          0 => FInt | 1 => FStr | 2 => FX | 3 => FY | 4 => FInner (at sa 1 (choice 3))
        | 5 => FPair (sub 1, sub 2) | 6 => FRec (sub 1, sub 2) | 7 => FSelf | 8 => FOther | 9 => FSub
        | 10 => FBox (sub 1) | 11 => FList (sub 1) | 12 => FOpt (sub 1) | 13 => FReal | 14 => FFun | _ => FTree (sub 1)
      end)

  val conGen : con Gen.gen =
    Gen.primitive (fn sa => {fields = at sa 0 (Gen.listOf (weighted [3, 5, 3, 1]) (fieldGen 1)), record = at sa 1 (flag 35)})
  fun consGen (lo, hi) = Gen.listOf (Gen.intRange (lo, hi)) conGen

  val repGen : rep Gen.gen =
    Gen.primitive (fn sa =>
      case at sa 0 (weighted [2, 5, 3, 2, 2, 2, 2]) of
        0 => RAlias (at sa 1 (choice 4))
      | 1 => RData (at sa 1 (consGen (1, 4)))
      | 2 => RMutual (at sa 1 (consGen (1, 3)), at sa 2 (consGen (1, 3)))
      | 3 => RWith (at sa 2 (fieldGen 1), at sa 1 (consGen (1, 3)))
      | 4 => RCell (at sa 1 (fieldGen 1))
      | 5 => RLocal (at sa 1 (consGen (1, 3)))
      | _ => RRepl)

  val nShapes = 5
  val nBase = 15
  val leafGen : leaf Gen.gen =
    Gen.primitive (fn sa => {rep = at sa 0 (choice (nBase + nShapes)), perm = at sa 1 (choice 8), sub = at sa 2 (choice 4),
                             box = at sa 3 (choice 6)})

  (* an argument in a body, or (top) at the top level, where there is no
     parameter to adapt *)
  fun argGen (top, depth) : arg Gen.gen =
    Gen.primitive (fn sa =>
      let val app = if depth > 0 then 2 else 0
      in
        case at sa 0 (weighted (if top then [0, 0, 5, 0, app, 1] else [5, 3, 1, 2, app, 1])) of
          0 => AParam | 1 => AInner (at sa 1 (choice 3)) | 2 => APath (at sa 1 (choice 6))
        | 3 => AAdapter (at sa 1 (choice 4)) | 4 => AApp (at sa 1 (choice 8), at sa 2 (argGen (top, depth - 1)))
        | _ => ALit (at sa 1 leafGen)
      end)

  val paramGen : param Gen.gen =
    Gen.primitive (fn sa =>
      {form = at sa 0 (weighted [5, 2, 2, 1, 1, 1, 1]), eq = at sa 1 (flag 40),
       dt = if at sa 2 (flag 20) then SOME (at sa 3 (choice nShapes)) else NONE,
       exn = at sa 4 (flag 30), count = at sa 5 (flag 25), sub = at sa 6 (flag 25), poly = at sa 7 (flag 30),
       named = at sa 8 (flag 30), perm = at sa 9 (choice 8), kval = at sa 10 (choice 9), tree = at sa 11 (flag 20)})

  val bodyGen : body Gen.gen =
    Gen.primitive (fn sa =>
      {tick = at sa 0 (flag 70), openX = at sa 1 (flag 15), hide = at sa 2 (flag 25),
       inners = at sa 3 (Gen.listOf (weighted [3, 4, 2])
                                    (Gen.primitive (fn sb => (at sb 0 (weighted [6, 3, 2, 1, 1, 1]), at sb 1 (argGen (false, 2)),
                                                              at sb 2 (weighted [6, 1, 1]))))),
       rep = at sa 4 repGen, exn = at sa 5 (weighted [4, 4, 1, 1]), carry = at sa 6 (flag 25),
       count = at sa 7 (flag 40), sub = at sa 8 (weighted [5, 1, 1, 1]), poly = at sa 9 (weighted [5, 2, 1, 1]),
       pair = at sa 10 (flag 30), inner = at sa 11 (flag 25), via = at sa 12 (flag 25),
       probes = at sa 13 (Gen.listOf (Gen.return 24) (flag 60))})

  val resultGen : result Gen.gen =
    Gen.primitive (fn sa =>
      {ascr = at sa 0 (weighted [3, 3, 4]), spec = at sa 1 (choice 6), named = at sa 2 (flag 30),
       exn = at sa 3 (flag 70), count = at sa 4 (flag 70), sub = at sa 5 (flag 70), poly = at sa 6 (flag 70),
       pair = at sa 7 (flag 70), inner = at sa 8 (flag 70)})

  val appGen : app Gen.gen =
    Gen.primitive (fn sa => {target = at sa 0 (choice 8), arg = at sa 1 (argGen (true, 2)), wrap = at sa 2 (weighted [6, 1, 1]),
                             alias = at sa 3 (flag 15)})

  (* 1 to n, n the likeliest, 1 the simplest *)
  fun upTo n = Gen.map (fn i => i + 1) (weighted (List.tabulate (n, fn i => i + 1)))

  val planGen : plan Gen.gen =
    Gen.sized (fn size =>
      Gen.primitive (fn sa =>
        {leaves = at sa 0 (Gen.listOf (Gen.intRange (1, 3)) leafGen),
         functors = at sa 1 (Gen.listOf (upTo (Int.min (8, 2 + size div 20)))
                                        (Gen.primitive (fn sb => {param = at sb 0 paramGen, body = at sb 1 bodyGen,
                                                                  result = at sb 2 resultGen}))),
         apps = at sa 2 (Gen.listOf (upTo (Int.min (9, 2 + size div 15))) appGen),
         breaks = at sa 3 (Gen.listOf (Gen.return 16) (flag 50)),
         budget = at sa 4 (choice 5), inline = at sa 5 (choice 4), budgetUnits = at sa 6 Gen.bool}))

  (* ---- what a structure shows *)
  type view = {eq : bool, dt : int option, exn : bool, count : bool, sub : bool, poly : bool,
               cons : (string * bool) list option, pair : bool, inner : bool, int : bool, tree : bool}
  type needs = {eq : bool, dt : int option, exn : bool, count : bool, sub : bool, poly : bool, int : bool, tree : bool}
  val core : view = {eq = false, dt = NONE, exn = false, count = false, sub = false, poly = false, cons = NONE,
                     pair = false, inner = false, int = false, tree = false}
  val nothing : needs = {eq = false, dt = NONE, exn = false, count = false, sub = false, poly = false, int = false, tree = false}
  fun satisfies (v : view, n : needs) =
    (not (#eq n) orelse #eq v) andalso (case #dt n of NONE => true | SOME k => #dt v = SOME k)
    andalso (not (#exn n) orelse #exn v) andalso (not (#count n) orelse #count v)
    andalso (not (#sub n) orelse #sub v) andalso (not (#poly n) orelse #poly v) andalso (not (#int n) orelse #int v)
    andalso (not (#tree n) orelse #tree v)

  fun nth (xs, i) = List.nth (xs, i mod length xs)
  fun paren s = "(" ^ s ^ ")"
  fun str s = "\"" ^ s ^ "\""
  fun commas xs = String.concatWith ", " xs
  fun ints n = Int.toString n

  (* ---- the datatypes of the leaves and of parameters' datatype specs:
     each a fixed set of constructors, written in an order of its own *)
  val shapes : (string * string option) list vector = Vector.fromList
    [[("Ka", SOME "int"), ("Kb", SOME "string * int"), ("Kc", NONE), ("Kd", SOME "{lo : int, hi : int}")],
     [("Ln", NONE), ("Lc", SOME "int * t")],
     [("Ma", NONE), ("Mb", NONE), ("Mc", SOME "bool"), ("Md", NONE)],
     [("Na", SOME "int"), ("Nb", SOME "real")],
     [("Pa", SOME "int"), ("Pb", NONE)]]
  val shapeEq = Vector.fromList [true, true, true, false, true]
  fun shapeCons k = List.map (fn (c, a) => (c, isSome a)) (Vector.sub (shapes, k))
  fun permute (xs, perm) =
    let
      val n = length xs
      val r = perm mod n
      val rot = List.drop (xs, r) @ List.take (xs, r)
    in if (perm div n) mod 2 = 1 then List.rev rot else rot end
  fun shapeDecl (k, perm) =
    "datatype t = " ^ String.concatWith " | " (List.map (fn (c, NONE) => c | (c, SOME ty) => c ^ " of " ^ ty)
                                                         (permute (Vector.sub (shapes, k), perm)))
  fun shapeMk (k, p, mk) =
    "fun " ^ mk ^ " n = "
    ^ (case k of
         0 => "(case n mod 4 of 0 => " ^ p ^ "Ka n | 1 => " ^ p ^ "Kb (Int.toString n, n) | 2 => " ^ p ^ "Kc | _ => " ^ p
              ^ "Kd {lo = n, hi = n + 1})"
       | 1 => "if n <= 0 then " ^ p ^ "Ln else " ^ p ^ "Lc (n, " ^ mk ^ " (n - 1))"
       | 2 => "(case n mod 4 of 0 => " ^ p ^ "Ma | 1 => " ^ p ^ "Mb | 2 => " ^ p ^ "Mc (n mod 3 = 0) | _ => " ^ p ^ "Md)"
       | 3 => "if n mod 2 = 0 then " ^ p ^ "Na n else " ^ p ^ "Nb (real n)"
       | _ => "if n mod 3 = 0 then " ^ p ^ "Pb else " ^ p ^ "Pa n")
  fun shapeObs (k, p, obs) =
    case k of
      0 => "fun " ^ obs ^ " v = (case v of " ^ p ^ "Ka n => n | " ^ p ^ "Kb (s, n) => size s + n | " ^ p ^ "Kc => 100 | "
           ^ p ^ "Kd {lo, hi} => 3 * lo + hi)"
    | 1 => "fun " ^ obs ^ " " ^ p ^ "Ln = 0 | " ^ obs ^ " (" ^ p ^ "Lc (k, r)) = k + 2 * " ^ obs ^ " r"
    | 2 => "fun " ^ obs ^ " v = (case v of " ^ p ^ "Ma => 1 | " ^ p ^ "Mb => 2 | " ^ p ^ "Mc b => (if b then 3 else 4) | "
           ^ p ^ "Md => 5)"
    | 3 => "fun " ^ obs ^ " (" ^ p ^ "Na n) = n | " ^ obs ^ " (" ^ p ^ "Nb r) = 10 * Real.floor r"
    | _ => "fun " ^ obs ^ " " ^ p ^ "Pb = ~5 | " ^ obs ^ " (" ^ p ^ "Pa n) = n"
  (* what a body sees of a parameter's datatype: a match and a constructor *)
  fun shapeProbe (k, p) =
    case k of
      0 => "(case " ^ p ^ "mk 1 of " ^ p ^ "Kb (s, m) => s ^ Int.toString m | " ^ p ^ "Ka m => Int.toString m | _ => \"o\") ^ Int.toString ("
           ^ p ^ "obs " ^ p ^ "Kc)"
    | 1 => "(case " ^ p ^ "mk 2 of " ^ p ^ "Lc (m, _) => Int.toString m | " ^ p ^ "Ln => \"n\") ^ Int.toString (" ^ p ^ "obs ("
           ^ p ^ "Lc (7, " ^ p ^ "Ln)))"
    | 2 => "(case " ^ p ^ "mk 2 of " ^ p ^ "Mc b => Bool.toString b | " ^ p ^ "Ma => \"a\" | _ => \"o\")"
    | 3 => "(case " ^ p ^ "mk 3 of " ^ p ^ "Nb r => Int.toString (Real.floor r) | " ^ p ^ "Na m => Int.toString m)"
    | _ => "(case " ^ p ^ "mk 3 of " ^ p ^ "Pb => \"b\" | " ^ p ^ "Pa m => Int.toString m) ^ Int.toString (" ^ p ^ "obs (" ^ p
           ^ "Pa 4))"

  (* the leaves' representations of t that are not datatypes: of every
     layout, boxed and not, with equality and without *)
  val baseReps : {ty : string, mk : string, obs : string, eq : bool} vector = Vector.fromList
    [{ty = "int", mk = "fun mk n = n", obs = "fun obs v = v", eq = true},
     {ty = "int * int", mk = "fun mk n = (n, n + 1)", obs = "fun obs (a, b) = a + 2 * b", eq = true},
     {ty = "{lo : int, hi : string}", mk = "fun mk n = {lo = n, hi = Int.toString n}", obs = "fun obs {lo, hi} = lo + 3 * size hi",
      eq = true},
     {ty = "string", mk = "fun mk n = Int.toString (n * 3)",
      obs = "fun obs s = size s + (case Int.fromString s of SOME k => k | NONE => 0)", eq = true},
     {ty = "real", mk = "fun mk n = real n / 2.0", obs = "fun obs r = Real.floor (r * 2.0)", eq = false},
     {ty = "unit -> int", mk = "fun mk n = fn () => n * 2", obs = "fun obs f = f ()", eq = false},
     {ty = "int list", mk = "fun mk n = List.tabulate (n mod 4, fn i => i + n)",
      obs = "fun obs l = List.foldl (op +) 0 l + 10 * length l", eq = true},
     {ty = "int option", mk = "fun mk n = if n mod 2 = 0 then NONE else SOME n", obs = "fun obs NONE = ~1 | obs (SOME k) = k",
      eq = true},
     {ty = "int ref", mk = "fun mk n = ref n", obs = "fun obs r = !r", eq = true},
     {ty = "bool", mk = "fun mk n = n mod 2 = 0", obs = "fun obs b = if b then 1 else 0", eq = true},
     {ty = "word", mk = "fun mk n = Word.fromInt (abs n)", obs = "fun obs w = Word.toInt w", eq = true},
     {ty = "char", mk = "fun mk n = Char.chr (97 + n mod 26)", obs = "fun obs c = Char.ord c - 97", eq = true},
     {ty = "unit", mk = "fun mk _ = ()", obs = "fun obs () = 7", eq = true},
     {ty = "int * string * bool", mk = "fun mk n = (n, Int.toString n, n mod 2 = 0)",
      obs = "fun obs (a, s, b) = a + size s + (if b then 1 else 0)", eq = true},
     {ty = "real * int", mk = "fun mk n = (real n, n)", obs = "fun obs (r, k) = Real.floor r + k", eq = false}]

  (* a polymorphic datatype a parameter may specify, its constructors in an
     order of their own *)
  fun treeDecl k =
    "datatype 'a tree = " ^ (if k mod 2 = 0 then "Leaf | Node of 'a tree * 'a * 'a tree" else "Node of 'a tree * 'a * 'a tree | Leaf")

  fun subText k =
    case k mod 4 of
      0 => "structure Sub = struct type u = int fun mk2 n = n * 2 fun obs2 u = u end"
    | 1 => "structure Sub = struct datatype u = Ua of int | Ub fun mk2 n = if n mod 2 = 0 then Ub else Ua n fun obs2 Ub = 0 | obs2 (Ua k) = k end"
    | 2 => "structure Sub = struct type u = string * int fun mk2 n = (Int.toString n, n) fun obs2 (s, k) = size s + k end"
    | _ => "structure Sub = struct type u = real fun mk2 n = real n fun obs2 r = Real.floor r end"
  fun boxText k =
    case k mod 6 of
      0 => "type 'a box = 'a * int fun box x = (x, 1) fun unbox (x, _) = x"
    | 1 => "type 'a box = 'a fun box x = x fun unbox x = x"
    | 2 => "datatype 'a box = Bx of 'a | By of 'a * 'a fun box x = Bx x fun unbox (Bx x) = x | unbox (By (x, _)) = x"
    | 3 => "type 'a box = unit -> 'a fun box x = fn () => x fun unbox f = f ()"
    | 4 => "type 'a box = 'a list fun box x = [x] fun unbox l = hd l"
    | _ => "type 'a box = 'a ref fun box x = ref x fun unbox r = !r"

  (* a structure of the leaves, the representation of its t chosen to meet
     needs: its declarations and what it shows (all but a datatype it lacks) *)
  fun leafDecls (name, l : leaf, n : needs) : string list * view =
    let
      val r = #rep l mod (nBase + nShapes)
      val r = case #dt n of
                SOME k => nBase + k
              | NONE =>
                  if #int n then 0 else
                  if #eq n andalso r < nBase andalso not (#eq (Vector.sub (baseReps, r))) then 0
                  else if #eq n andalso r >= nBase andalso not (Vector.sub (shapeEq, r - nBase)) then nBase
                  else r
      val (decls, eq, dt, cons) =
        if r < nBase then
          let val b = Vector.sub (baseReps, r) in (["type t = " ^ #ty b, #mk b, #obs b], #eq b, NONE, NONE) end
        else
          let val k = r - nBase
          in ([shapeDecl (k, #perm l), shapeMk (k, "", "mk"), shapeObs (k, "", "obs")], Vector.sub (shapeEq, k), SOME k,
              SOME (shapeCons k))
          end
    in
      (decls @ ["val tag = " ^ str name, "exception E of int", "fun fail n = raise E (10 * n)", "val count = ref 0",
                subText (#sub l), boxText (#box l), treeDecl (#perm l div 2)],
       {eq = eq, dt = dt, exn = true, count = true, sub = true, poly = true, cons = cons, pair = false, inner = false, int = r = 0,
        tree = true})
    end

  (* ---- what a field is where it is made: its type in the body and, where
     a signature can name it, there; whether it admits equality; how to make
     one of an int and observe one as an int *)
  type finfo = {ty : string, sty : string option, eq : bool, mk : string -> string, obs : string -> string}

  val counter = ref 0
  fun fresh p = (counter := !counter + 1; p ^ Int.toString (!counter))

  (* the body around a datatype: the parameter's view, whether there is a
     Y shared with X, the inner instances; and the datatype: its own name,
     the other of its group, the abbreviation of withtype *)
  type ctx = {x : view, y : bool, inners : (string * view) list}
  type dctx = {self : string option, other : string option, w : finfo option}
  val plain : dctx = {self = NONE, other = NONE, w = NONE}

  fun resolve (c : ctx, d : dctx) (f : field) : finfo =
    let
      val r = resolve (c, d)
      fun param p = {ty = p ^ ".t", sty = SOME (p ^ ".t"), eq = #eq (#x c), mk = fn e => p ^ ".mk " ^ paren e,
                     obs = fn v => p ^ ".obs " ^ paren v}
      fun named t = {ty = t, sty = SOME t, eq = true, mk = fn e => "mk_" ^ t ^ " (d - 1, " ^ e ^ ")",
                     obs = fn v => "obs_" ^ t ^ " " ^ paren v}
    in
      case f of
        FInt => {ty = "int", sty = SOME "int", eq = true, mk = fn e => e, obs = fn v => v}
      | FStr => {ty = "string", sty = SOME "string", eq = true, mk = fn e => "Int.toString " ^ paren e,
                 obs = fn v => "size " ^ paren v}
      | FX => param "X"
      | FY => param (if #y c then "Y" else "X")
      | FInner i =>
          (case #inners c of
             [] => r FX
           | is => let val (n, v : view) = nth (is, i)
                   in {ty = n ^ ".t", sty = NONE, eq = #eq v, mk = fn e => n ^ ".mk " ^ paren e,
                       obs = fn x => n ^ ".obs " ^ paren x}
                   end)
      | FPair (a, b) =>
          let val fa = r a val fb = r b
          in {ty = paren (#ty fa ^ " * " ^ #ty fb),
              sty = (case (#sty fa, #sty fb) of (SOME x, SOME y) => SOME (paren (x ^ " * " ^ y)) | _ => NONE),
              eq = #eq fa andalso #eq fb, mk = fn e => paren (#mk fa e ^ ", " ^ #mk fb (e ^ " + 1")),
              obs = fn v => let val p = fresh "p" val q = fresh "q"
                            in "(case " ^ v ^ " of (" ^ p ^ ", " ^ q ^ ") => " ^ #obs fa p ^ " + " ^ #obs fb q ^ ")" end}
          end
      | FRec (a, b) =>
          let val fa = r a val fb = r b
          in {ty = "{f1 : " ^ #ty fa ^ ", f2 : " ^ #ty fb ^ "}",
              sty = (case (#sty fa, #sty fb) of (SOME x, SOME y) => SOME ("{f1 : " ^ x ^ ", f2 : " ^ y ^ "}") | _ => NONE),
              eq = #eq fa andalso #eq fb, mk = fn e => "{f1 = " ^ #mk fa e ^ ", f2 = " ^ #mk fb (e ^ " + 2") ^ "}",
              obs = fn v => let val p = fresh "p" val q = fresh "q"
                            in "(case " ^ v ^ " of {f1 = " ^ p ^ ", f2 = " ^ q ^ "} => " ^ #obs fa p ^ " + 2 * " ^ #obs fb q ^ ")" end}
          end
      | FSelf => (case #self d of SOME t => named t | NONE => r FInt)
      | FOther =>
          (case (#w d, #other d) of
             (SOME w, _) => {ty = "w", sty = #sty w, eq = #eq w, mk = #mk w, obs = #obs w}
           | (NONE, SOME u) => named u
           | (NONE, NONE) => r FSelf)
      | FSub =>
          if #sub (#x c) then {ty = "X.Sub.u", sty = SOME "X.Sub.u", eq = false, mk = fn e => "X.Sub.mk2 " ^ paren e,
                               obs = fn v => "X.Sub.obs2 " ^ paren v}
          else r FStr
      | FBox a =>
          if #poly (#x c) then
            let val fa = r a
            in {ty = paren (#ty fa) ^ " X.box", sty = Option.map (fn s => paren s ^ " X.box") (#sty fa), eq = false,
                mk = fn e => "X.box " ^ paren (#mk fa e), obs = fn v => #obs fa (paren ("X.unbox " ^ paren v))}
            end
          else r (FList a)
      | FList a =>
          let val fa = r a
          in {ty = paren (#ty fa) ^ " list", sty = Option.map (fn s => paren s ^ " list") (#sty fa), eq = #eq fa,
              mk = fn e => "[" ^ #mk fa e ^ ", " ^ #mk fa (e ^ " + 1") ^ "]",
              obs = fn v => let val p = fresh "p" val s = fresh "s"
                            in "List.foldl (fn (" ^ p ^ ", " ^ s ^ ") => " ^ s ^ " + " ^ #obs fa p ^ ") 0 " ^ paren v end}
          end
      | FOpt a =>
          let val fa = r a
          in {ty = paren (#ty fa) ^ " option", sty = Option.map (fn s => paren s ^ " option") (#sty fa), eq = #eq fa,
              mk = fn e => "SOME " ^ paren (#mk fa e),
              obs = fn v => let val p = fresh "p" in "(case " ^ v ^ " of NONE => 0 | SOME " ^ p ^ " => " ^ #obs fa p ^ ")" end}
          end
      | FReal => {ty = "real", sty = SOME "real", eq = false, mk = fn e => "real " ^ paren e, obs = fn v => "Real.floor " ^ paren v}
      | FTree a =>
          if #tree (#x c) then
            let val fa = r a
            in {ty = paren (#ty fa) ^ " X.tree", sty = Option.map (fn s => paren s ^ " X.tree") (#sty fa), eq = #eq fa,
                mk = fn e => "X.Node (X.Leaf, " ^ #mk fa e ^ ", X.Node (X.Leaf, " ^ #mk fa (e ^ " + 1") ^ ", X.Leaf))",
                obs = fn v => let val l = fresh "l" val p = fresh "p" val q = fresh "q"
                              in "(case " ^ v ^ " of X.Leaf => 0 | X.Node (" ^ l ^ ", " ^ p ^ ", " ^ q ^ ") => " ^ #obs fa p
                                 ^ " + (case " ^ q ^ " of X.Leaf => 1 | X.Node _ => 2) + (case " ^ l ^ " of X.Leaf => 0 | X.Node _ => 5))" end}
            end
          else r (FList a)
      | FFun => {ty = "(int -> int)", sty = SOME "(int -> int)", eq = false,
                 mk = fn e => let val z = fresh "z" in "(fn " ^ z ^ " => " ^ z ^ " + " ^ paren e ^ ")" end,
                 obs = fn v => paren v ^ " 3"}
    end

  (* a constructor's first must end the recursion: no field of it names
     its group *)
  fun norec f =
    case f of
      FSelf => FInt | FOther => FInt | FPair (a, b) => FPair (norec a, norec b) | FRec (a, b) => FRec (norec a, norec b)
    | FBox a => FBox (norec a) | FList a => FList (norec a) | FOpt a => FOpt (norec a) | FTree a => FTree (norec a) | x => x
  fun firstNorec (cs : con list) : con list =
    case cs of
      [] => [{fields = [], record = false}]
    | {fields, record} :: rest => {fields = List.map norec fields, record = record} :: rest

  (* a constructor resolved: its name, its fields, whether a record *)
  type rcon = string * finfo list * bool

  fun conDecl useSty ((name, fs, record) : rcon) : string option =
    let val tys = List.map (fn f : finfo => if useSty then #sty f else SOME (#ty f)) fs
    in
      if List.exists (not o isSome) tys then NONE
      else
        let val ts = List.map valOf tys
        in
          SOME (case ts of
                  [] => name
                | [t] => name ^ " of " ^ t
                | _ => if record then name ^ " of {" ^ commas (List.tabulate (length ts, fn i => "f" ^ ints (i + 1) ^ " : " ^ List.nth (ts, i))) ^ "}"
                       else name ^ " of " ^ String.concatWith " * " ts)
        end
    end
  fun conMk ((name, fs, record) : rcon) =
    case fs of
      [] => name
    | [f] => name ^ " " ^ paren (#mk f "n")
    | _ =>
        if record then name ^ " {" ^ commas (List.tabulate (length fs, fn i => "f" ^ ints (i + 1) ^ " = " ^ #mk (List.nth (fs, i)) ("n + " ^ ints i))) ^ "}"
        else name ^ " " ^ paren (commas (List.tabulate (length fs, fn i => #mk (List.nth (fs, i)) ("n + " ^ ints i))))
  fun conObs (j, (name, fs, record) : rcon) =
    let
      val ps = List.map (fn _ => fresh "p") fs
      val pat = case ps of
                  [] => name
                | [p] => name ^ " " ^ p
                | _ => if record then name ^ " {" ^ commas (List.tabulate (length ps, fn i => "f" ^ ints (i + 1) ^ " = " ^ List.nth (ps, i))) ^ "}"
                       else name ^ " " ^ paren (commas ps)
    in pat ^ " => " ^ String.concatWith " + " (ints (j + 1) :: ListPair.map (fn (f : finfo, p) => #obs f p) (fs, ps)) end
  fun mkFun (kw, t, cons : rcon list) =
    let val n = length cons
    in
      kw ^ " mk_" ^ t ^ " (d, n) = "
      ^ (if n = 1 then conMk (hd cons)
         else "if d <= 0 then " ^ conMk (hd cons) ^ " else (case n mod " ^ ints n ^ " of "
              ^ String.concatWith " | " (List.tabulate (n, fn j => (if j = n - 1 then "_" else ints j) ^ " => " ^ conMk (List.nth (cons, j))))
              ^ ")")
    end
  fun obsFun (kw, t, cons : rcon list) =
    kw ^ " obs_" ^ t ^ " v = (case v of " ^ String.concatWith " | " (List.tabulate (length cons, fn j => conObs (j, List.nth (cons, j)))) ^ ")"
  fun consEq (cons : rcon list) = List.all (fn (_, fs, _) => List.all (fn f : finfo => #eq f) fs) cons
  fun declOf useSty (t, cons : rcon list) : string option =
    let val ds = List.map (conDecl useSty) cons
    in if List.all isSome ds then SOME (t ^ " = " ^ String.concatWith " | " (List.map valOf ds)) else NONE end
  fun shownCons (cons : rcon list) = List.map (fn (n, fs, _) => (n, not (List.null fs))) cons

  (* whether a field is p or has a part that is *)
  fun mentions p f =
    p f orelse (case f of FPair (a, b) => mentions p a orelse mentions p b | FRec (a, b) => mentions p a orelse mentions p b
                        | FBox a => mentions p a | FList a => mentions p a | FOpt a => mentions p a | FTree a => mentions p a
                        | _ => false)

  (* what a result signature may say of t *)
  type spec = {lines : string list, eq : bool, cons : (string * bool) list option, dt : int option, alias : bool}
  fun spec (lines, eq) : spec = {lines = lines, eq = eq, cons = NONE, dt = NONE, alias = false}
  fun abstractOr eq : spec list = spec (["type t"], false) :: (if eq then [spec (["eqtype t"], true)] else [])

  (* what a body's rep makes: its declarations, whether t admits equality,
     what a signature may say of it, its constructors and its datatype
     shown where nothing is ascribed, and what it is called in coverage *)
  type made = {decls : string list, eq : bool, specs : spec list, cons : (string * bool) list option, dt : int option,
               label : string, cell : bool}

  fun makeRep (c : ctx, k : int, needs : needs, rep : rep) : made =
    let
      val K = ints k
      fun resolveCons (prefix, d, cs) : rcon list =
        List.tabulate (length cs, fn j => let val {fields, record} = List.nth (cs, j)
                                          in (prefix ^ K ^ "_" ^ ints j, List.map (resolve (c, d)) fields, record) end)
      fun alias (p, eq, sty) : made =
        {decls = ["type t = " ^ p ^ ".t", "fun mk_t (_ : int, n) = " ^ p ^ ".mk (n + 1)", "fun obs_t v = " ^ p ^ ".obs v + 1"],
         eq = eq,
         specs = abstractOr eq @ (case sty of SOME s => [{lines = ["type t = " ^ s], eq = eq, cons = NONE, dt = NONE, alias = true}] | NONE => []),
         cons = NONE, dt = NONE, label = "rep:alias", cell = false}
    in
      case rep of
        RAlias i =>
          (case (i mod 4, #inners c) of
             (0, _) => alias ("X", #eq (#x c), SOME "X.t")
           | (1, _) => if #y c then alias ("Y", #eq (#x c), SOME "Y.t") else alias ("X", #eq (#x c), SOME "X.t")
           | (_, []) => alias ("X", #eq (#x c), SOME "X.t")
           | (_, is) => let val (n, v : view) = nth (is, i) in alias (n, #eq v, NONE) end)
      | RData cs =>
          let
            val cons = resolveCons ("C", {self = SOME "t", other = SOME "t", w = NONE}, firstNorec cs)
            val eq = consEq cons
          in
            {decls = ["datatype " ^ valOf (declOf false ("t", cons)), mkFun ("fun", "t", cons), obsFun ("fun", "t", cons)],
             eq = eq,
             specs = abstractOr eq @ (case declOf true ("t", cons) of
                                        SOME s => [{lines = ["datatype " ^ s], eq = eq, cons = SOME (shownCons cons), dt = NONE, alias = false}]
                                      | NONE => []),
             cons = SOME (shownCons cons), dt = NONE, label = "rep:datatype", cell = false}
          end
      | RMutual (ts, us) =>
          let
            val ct = resolveCons ("C", {self = SOME "t", other = SOME "u", w = NONE}, firstNorec ts)
            val cu = resolveCons ("D", {self = SOME "u", other = SOME "t", w = NONE}, firstNorec us)
            val eq = consEq ct andalso consEq cu
            val st = declOf true ("t", ct)
            val su = declOf true ("u", cu)
            val both = case (st, su) of
                         (SOME a, SOME b) => [{lines = ["datatype " ^ a ^ " and " ^ b], eq = eq, cons = SOME (shownCons ct), dt = NONE, alias = false}]
                       | _ => []
            (* with u abstract, t admits equality only where none of its constructors carries a u *)
            val tEq = eq andalso not (List.exists (fn {fields, ...} : con => List.exists (mentions (fn f => f = FOther)) fields) ts)
            val tOnly = case st of SOME a => [{lines = ["type u", "datatype " ^ a], eq = tEq, cons = SOME (shownCons ct), dt = NONE, alias = false}] | NONE => []
            val uOnly = case su of SOME b => [spec (["type t", "datatype " ^ b], false)] | NONE => []
          in
            {decls = ["datatype " ^ valOf (declOf false ("t", ct)) ^ " and " ^ valOf (declOf false ("u", cu)),
                      mkFun ("fun", "t", ct) ^ " " ^ mkFun ("and", "u", cu), obsFun ("fun", "t", ct) ^ " " ^ obsFun ("and", "u", cu)],
             eq = eq, specs = abstractOr eq @ both @ tOnly @ uOnly, cons = SOME (shownCons ct), dt = NONE, label = "rep:mutual",
             cell = false}
          end
      | RWith (wf, cs) =>
          let
            val w = resolve (c, {self = SOME "t", other = NONE, w = NONE}) wf
            val cons = resolveCons ("C", {self = SOME "t", other = SOME "t", w = SOME w}, firstNorec cs)
            val eq = consEq cons andalso #eq w
          in
            {decls = ["datatype " ^ valOf (declOf false ("t", cons)) ^ " withtype w = " ^ #ty w, mkFun ("fun", "t", cons),
                      obsFun ("fun", "t", cons)],
             eq = eq,
             specs = abstractOr eq @ (case declOf true ("t", cons) of
                                        SOME s => [{lines = ["datatype " ^ s], eq = eq, cons = SOME (shownCons cons), dt = NONE, alias = false}]
                                      | NONE => []),
             cons = SOME (shownCons cons), dt = NONE, label = "rep:withtype", cell = false}
          end
      | RCell ef =>
          let
            val e = resolve (c, plain) ef
            val (nl, cs) = ("Nil" ^ K, "Cons" ^ K)
            val v = fresh "e"
            val cellCons = [(nl, false), (cs, true)]
          in
            {decls = ["datatype 'a cell = " ^ nl ^ " | " ^ cs ^ " of 'a * 'a cell",
                      "fun cellSum" ^ K ^ " f " ^ nl ^ " = 0 | cellSum" ^ K ^ " f (" ^ cs ^ " (x, r)) = f x + 2 * cellSum" ^ K ^ " f r",
                      "type t = " ^ paren (#ty e) ^ " cell",
                      "fun mk_t (_ : int, n) = " ^ cs ^ " (" ^ #mk e "n" ^ ", " ^ cs ^ " (" ^ #mk e "n + 1" ^ ", " ^ nl ^ "))",
                      "fun obs_t v = cellSum" ^ K ^ " (fn " ^ v ^ " => " ^ #obs e v ^ ") v"],
             eq = #eq e,
             specs = abstractOr (#eq e)
                     @ (case #sty e of
                          SOME s => [{lines = ["datatype 'a cell = " ^ nl ^ " | " ^ cs ^ " of 'a * 'a cell", "type t = " ^ paren s ^ " cell"],
                                      eq = #eq e, cons = SOME cellCons, dt = NONE, alias = false},
                                     spec (["type 'a cell", "type t = " ^ paren s ^ " cell"], false)]
                        | NONE => []),
             cons = SOME cellCons, dt = NONE, label = "rep:polymorphic-datatype", cell = true}
          end
      | RLocal cs =>
          let
            val cons = resolveCons ("H", {self = SOME "h", other = SOME "h", w = NONE}, firstNorec cs)
            val eq = consEq cons
          in
            {decls = ["local", "  datatype " ^ valOf (declOf false ("h", cons)), "  " ^ mkFun ("fun", "h", cons),
                      "  " ^ obsFun ("fun", "h", cons), "in", "  type t = h", "  fun mk_t (d, n) = mk_h (d, n)",
                      "  fun obs_t v = obs_h v", "end"],
             eq = eq, specs = abstractOr eq, cons = NONE, dt = NONE, label = "rep:local-datatype", cell = false}
          end
      | RRepl =>
          (case #dt (#x c) of
             SOME s =>
               let val eq = Vector.sub (shapeEq, s)
               in
                 {decls = ["datatype t = datatype X.t", shapeMk (s, "", "mkS" ^ K), shapeObs (s, "", "obsS" ^ K),
                           "fun mk_t (_ : int, n) = mkS" ^ K ^ " n", "fun obs_t v = obsS" ^ K ^ " v"],
                  eq = eq,
                  specs = abstractOr eq @ [{lines = ["datatype t = datatype X.t"], eq = eq, cons = SOME (shapeCons s), dt = SOME s, alias = false}],
                  cons = SOME (shapeCons s), dt = SOME s, label = "rep:replication", cell = false}
               end
           | NONE => makeRep (c, k, needs, RAlias 0))
    end

  (* the fields a rep names, for what it needs of its parameter *)
  fun repFields rep =
    case rep of
      RAlias _ => [] | RRepl => [] | RCell f => [f] | RWith (f, cs) => f :: List.concat (List.map #fields cs)
    | RData cs => List.concat (List.map #fields cs) | RLocal cs => List.concat (List.map #fields cs)
    | RMutual (ts, us) => List.concat (List.map #fields (ts @ us))

  (* ---- a functor, as its applications see it *)
  type finfo' = {name : string, form : int, kval : int, needs : needs, view : view, weight : int, depth : int}

  fun applyText (f : finfo', a : string) =
    case #form f of
      0 => #name f ^ " " ^ paren a
    | 1 => #name f ^ " (structure X = " ^ a ^ ")"
    | 2 => #name f ^ " (structure X = " ^ a ^ " val k = " ^ ints (#kval f) ^ ")"
    | 5 => #name f ^ " ()"
    | 6 => #name f ^ " " ^ paren a
    | _ => #name f ^ " (structure X = " ^ a ^ " structure Y = " ^ a ^ ")"
  (* a functor whose argument is named twice, for X and Y *)
  fun needsPath (f : finfo') = #form f = 3 orelse #form f = 4
  fun isPath s = CharVector.all (fn ch => Char.isAlphaNum ch orelse ch = #"." orelse ch = #"_") s

  (* where an argument is made: the parameter's view (NONE at the top
     level), the inner instances, the structures it may name, the functors
     it may apply, and where a structure that must be named is declared *)
  type actx = {x : view option, inners : (string * view) list, paths : (string * view) list, functors : finfo' list,
               hoist : string -> string, note : string -> unit, used : int -> unit}

  fun literal (l : leaf, n : needs) : string * view * int * int =
    let val (decls, v) = leafDecls ("lit", l, n)
    in ("struct " ^ String.concatWith " " decls ^ " end", v, 0, 0) end

  fun adapter (i, xv : view, n : needs) : string * view * int * int =
    let
      val extras =
        (if #exn n then (if #exn xv then ["exception E = X.E", "fun fail n = X.fail n"] else ["exception E of int", "fun fail n = raise E n"]) else [])
        @ (if #count n then ["val count = ref 0"] else [])
        @ (if #sub n then (if #sub xv then ["structure Sub = X.Sub"] else ["structure Sub = struct type u = int fun mk2 n = n + 1 fun obs2 u = u end"]) else [])
        @ (if #poly n then (if #poly xv then ["type 'a box = 'a X.box", "val box = X.box", "val unbox = X.unbox"]
                            else ["type 'a box = 'a * int", "fun box x = (x, 2)", "fun unbox (x, _) = x"]) else [])
        @ (if #tree n then (if #tree xv then ["datatype tree = datatype X.tree"] else [treeDecl 0]) else [])
      val v = {eq = #eq xv, dt = NONE, exn = #exn n, count = #count n, sub = #sub n, poly = #poly n, cons = NONE, pair = false, inner = false,
               int = false, tree = #tree n}
      fun s ds = "struct " ^ String.concatWith " " (ds @ extras) ^ " end"
    in
      case i mod 4 of
        0 => (s ["type t = X.t * int", "fun mk n = (X.mk n, n)", "fun obs (v, m) = X.obs v + m", "val tag = \"ad0\" ^ X.tag"], v, 0, 0)
      | 1 => ("struct open X val tag = \"ad1\" ^ X.tag end", xv, 0, 0)
      | 2 => (s ["datatype t = W of X.t | N of int", "fun mk n = if n mod 2 = 0 then N n else W (X.mk n)",
                 "fun obs (W v) = X.obs v | obs (N m) = m", "val tag = \"ad2\""],
              {eq = #eq xv, dt = NONE, exn = #exn n, count = #count n, sub = #sub n, poly = #poly n,
               cons = SOME [("W", true), ("N", true)], pair = false, inner = false, int = false, tree = #tree n}, 0, 0)
      | _ => (s ["type t = X.t list", "fun mk n = [X.mk n, X.mk (n + 1)]", "fun obs l = List.foldl (fn (v, s) => s + X.obs v) 0 l",
                 "val tag = \"ad3\""], v, 0, 0)
    end

  (* an argument for a functor of needs: its text, its view, the
     applications it makes and how deep they go *)
  fun resolveArg (c : actx) (n : needs) (a : arg) : string * view * int * int =
    let
      fun fallback () = (#note c "arg:literal"; literal ({rep = 0, perm = 1, sub = 0, box = 0}, n))
      fun try (SOME (r as (_, v, _, _))) = if satisfies (v, n) then r else fallback ()
        | try NONE = fallback ()
      fun candidate a =
        case a of
          AParam => (case #x c of SOME v => SOME ("X", v, 0, 0) | NONE => candidate (APath 0))
        | AInner i => (case #inners c of [] => candidate AParam | is => let val (s, v) = nth (is, i) in SOME (s, v, 0, 0) end)
        | APath i => (case #paths c of [] => NONE | ps => let val (s, v) = nth (ps, i) in #note c "arg:path"; SOME (s, v, 0, 0) end)
        | AAdapter i => (case #x c of SOME xv => (#note c "arg:adapter"; SOME (adapter (i, xv, n))) | NONE => candidate (APath i))
        | AApp (j, a') =>
            (case #functors c of
               [] => NONE
             | fs =>
                 let
                   val k = j mod length fs
                   val f = List.nth (fs, k)
                   val (t, _, w, d) = if #form f = 5 then ("", core, 0, 0) else resolveArg c (#needs f) a'
                   val t = if needsPath f andalso not (isPath t) then #hoist c t else t
                 in #note c "arg:application"; #used c k; SOME (applyText (f, t), #view f, w + #weight f, Int.max (d, #depth f)) end)
        | ALit l => (#note c "arg:literal"; SOME (literal (l, n)))
    in try (candidate a) end

  (* ---- the program *)
  type program = {units : string list, functors : string list, budget : int, inline : string list, budgetUnits : bool,
                  labels : string list}

  val budgets = Vector.fromList [0, 5, 20, 60, 200]
  val maxWeight = 40

  fun sigText (lines : string list) = "sig " ^ String.concatWith " " lines ^ " end"
  fun paramSpec (n : needs, perm) =
    (case #dt n of SOME k => shapeDecl (k, perm + 3) | NONE => if #eq n then "eqtype t" else "type t")
    :: ["val mk : int -> t", "val obs : t -> int", "val tag : string"]
    @ (if #exn n then ["exception E of int", "val fail : int -> int"] else [])
    @ (if #count n then ["val count : int ref"] else [])
    @ (if #sub n then ["structure Sub : sig type u val mk2 : int -> u val obs2 : u -> int end"] else [])
    @ (if #poly n then ["type 'a box", "val box : 'a -> 'a box", "val unbox : 'a box -> 'a"] else [])
    @ (if #tree n then [treeDecl (perm + 1)] else [])
  val coreLines = ["type t", "val mk : int -> t", "val obs : t -> int", "val tag : string"]
  val coreSpec = "structure Inner : sig type t val mk : int -> t val obs : t -> int val tag : string end"

  fun elaborate (p : plan) : program =
    let
      val () = counter := 0
      val labels : string list ref = ref []
      fun note l = if List.exists (fn x => x = l) (!labels) then () else labels := l :: !labels
      val sigs : string list ref = ref []
      val leaves = case #leaves p of [] => [{rep = 0, perm = 0, sub = 0, box = 0}] | ls => ls
      val leafViews = List.tabulate (length leaves, fn i => ("A" ^ ints i, #2 (leafDecls ("A" ^ ints i, List.nth (leaves, i), nothing))))
      val prelude =
        ["structure Log = struct",
         "  val n = ref 0",
         "  fun tick s = (n := !n + 1; print (s ^ \" \" ^ Int.toString (!n) ^ \"\\n\"))",
         "  fun ints l = String.concatWith \",\" (List.map Int.toString l)",
         "end"]
        @ List.concat (List.tabulate (length leaves, fn i =>
                                        ["structure A" ^ ints i ^ " = struct"]
                                        @ List.map (fn d => "  " ^ d) (#1 (leafDecls ("A" ^ ints i, List.nth (leaves, i), nothing)))
                                        @ ["end"]))
      val breaks = Vector.fromList (#breaks p @ List.tabulate (16, fn _ => false))
      fun break i = Vector.sub (breaks, i mod 16)
      (* how many times each functor is applied *)
      val uses = Array.array (length (#functors p), 0)
      fun used k = Array.update (uses, k, Array.sub (uses, k) + 1)

      (* a functor *)
      fun functor' (k, fp : fplan, earlier : finfo' list) : string list * finfo' =
        let
          val K = ints k
          val name = "F" ^ K
          val {param, body, result} = fp
          val fields = repFields (#rep body)
          val needsDt = case #rep body of RRepl => SOME (getOpt (#dt param, #perm param mod nShapes)) | _ => #dt param
          val needs : needs =
            {eq = #eq param andalso not (isSome needsDt), dt = needsDt, exn = #exn param orelse #exn body = 3,
             count = #count param, sub = #sub param orelse #sub body = 1 orelse List.exists (mentions (fn f => f = FSub)) fields,
             poly = #poly param orelse #poly body = 2 orelse List.exists (mentions (fn FBox _ => true | _ => false)) fields,
             int = #form param = 6 andalso not (isSome needsDt),
             tree = #tree param orelse List.exists (mentions (fn FTree _ => true | _ => false)) fields}
          (* where type and sharing are not for a datatype spec *)
          val form = if isSome needsDt then (case #form param of 3 => 0 | 4 => 1 | 6 => 2 | f => f) else #form param
          val xview : view = {eq = (case needsDt of SOME s => Vector.sub (shapeEq, s) | NONE => #eq needs orelse #int needs), dt = needsDt,
                              exn = #exn needs, count = #count needs, sub = #sub needs, poly = #poly needs,
                              cons = Option.map shapeCons needsDt, pair = false, inner = false, int = #int needs, tree = #tree needs}
          val () = (if isSome needsDt then note "param:datatype" else if #eq needs then note "param:eqtype" else ();
                    if #sub needs then note "param:structure" else (); if #poly needs then note "param:polymorphic" else ();
                    if #exn needs then note "param:exception" else (); if #count needs then note "param:ref" else ();
                    note (Vector.sub (Vector.fromList ["form:plain", "form:derived", "form:derived-value", "form:sharing", "form:where",
                                                       "form:no-parameter", "form:where-int"], form)))
          val pspec = paramSpec (needs, #perm param)
          val psig = if #named param then (sigs := !sigs @ ["signature P" ^ K ^ " = " ^ sigText pspec]; note "param:named"; "P" ^ K)
                     else sigText pspec
          val head =
            case form of
              0 => "(X : " ^ psig ^ ")"
            | 1 => "(structure X : " ^ psig ^ ")"
            | 2 => "(structure X : " ^ psig ^ " val k : int)"
            | 3 => "(structure X : " ^ psig ^ " structure Y : " ^ psig ^ " sharing type X.t = Y.t)"
            | 4 => "(structure X : " ^ psig ^ " structure Y : " ^ psig ^ " where type t = X.t)"
            | 5 => "()"
            | _ => "(X : " ^ psig ^ " where type t = int)"
          val y = form = 3 orelse form = 4
          (* the body *)
          val lines : string list ref = ref []
          fun emit l = lines := !lines @ [l]
          val hoisted = ref 0
          fun hoist t = let val n = "H" ^ ints (!hoisted) in hoisted := !hoisted + 1; note "arg:named-for-sharing"; emit ("structure " ^ n ^ " = " ^ t); n end
          (* without a parameter, X is the body's first structure *)
          val () = if form = 5 then emit ("structure X = " ^ #1 (literal ({rep = #perm param, perm = #kval param, sub = 1, box = 2}, needs))) else ()
          val () = if #tick body then emit ("val () = Log.tick " ^ str name) else ()
          val () = if #openX body then (note "open"; emit "open X") else ()
          val hidden = #hide body andalso not (List.null (#inners body)) andalso k > 0
          val () = if hidden then (note "local-inners"; emit "local") else ()
          val inners : (string * view) list ref = ref []
          val weight = ref 1
          val depth = ref 0
          val () =
            if k = 0 then ()
            else
              List.app (fn (j, a, ascribe) =>
                          let
                            (* the functors just before, the likelier: deeper nests *)
                            val jj = k - 1 - j mod k
                            val f = List.nth (earlier, jj)
                            val c : actx = {x = SOME xview, inners = !inners, paths = leafViews, functors = earlier, hoist = hoist,
                                            note = note, used = used}
                            val (t, _, w, d) = if #form f = 5 then ("", core, 0, 0) else resolveArg c (#needs f) a
                          in
                            if !weight + w + #weight f > maxWeight then ()
                            else
                              let
                                val t = if needsPath f andalso not (isPath t) then hoist t else t
                                val i = "I" ^ ints (length (!inners))
                              in
                                used jj; weight := !weight + w + #weight f; depth := Int.max (!depth, Int.max (d, #depth f));
                                note "inner-application";
                                (* an inner instance ascribed what every functor shows *)
                                case ascribe of
                                  0 => (emit ("structure " ^ i ^ " = " ^ applyText (f, t)); inners := !inners @ [(i, #view f)])
                                | n => (note "inner-ascription";
                                        emit ("structure " ^ i ^ (if n = 1 then " : " else " :> ") ^ sigText coreLines ^ " = " ^ applyText (f, t));
                                        inners := !inners @ [(i, {eq = n = 1 andalso #eq (#view f), dt = NONE, exn = false, count = false,
                                                                  sub = false, poly = false, cons = NONE, pair = false, inner = false,
                                                                  int = false, tree = false})])
                              end
                          end)
                       (#inners body)
          val inners = !inners
          val () = if hidden then emit "in" else ()
          val c : ctx = {x = xview, y = y, inners = inners}
          val made = makeRep (c, k, needs, #rep body)
          val () = note (#label made)
          val () = if #count body then (note "ref"; emit "val count = ref 0") else ()
          val () = List.app emit (#decls made)
          val () = emit ("fun mk n = " ^ (if #count body then "(count := !count + 1; mk_t (2, n))" else "mk_t (2, n)"))
          val () = emit "fun obs v = obs_t v"
          (* exceptions *)
          val exnInner = List.find (fn (_, v : view) => #exn v) inners
          val exnMode = case (#exn body, exnInner) of (2, NONE) => 1 | (m, _) => m
          val () =
            case exnMode of
              0 => ()
            | 1 => (note "exception"; emit "exception E of int"; emit ("fun fail n = raise E (n + " ^ K ^ ")"))
            | 2 => (note "exception:inner"; emit ("exception E = " ^ #1 (valOf exnInner) ^ ".E"); emit ("fun fail n = raise E (n + " ^ K ^ ")"))
            | _ => (note "exception:parameter"; emit "exception E = X.E"; emit "fun fail n = X.fail (n + 1)")
          val () = if #carry body then (note "exception:carries-t"; emit ("exception Carry" ^ K ^ " of t")) else ()
          val subMode = #sub body
          val () =
            case subMode of
              0 => ()
            | 1 => (note "sub:parameter"; emit "structure Sub = X.Sub")
            | 2 => (note "sub"; emit "structure Sub = struct type u = t * int fun mk2 n = (mk n, n) fun obs2 (v, m) = obs v + m end")
            | _ => (note "sub:datatype";
                    emit ("structure Sub = struct datatype u = U" ^ K ^ " of t | V" ^ K ^ " of int fun mk2 n = if n mod 2 = 0 then V" ^ K
                          ^ " n else U" ^ K ^ " (mk n) fun obs2 (V" ^ K ^ " m) = m | obs2 (U" ^ K ^ " v) = obs v end"))
          val () =
            case #poly body of
              0 => ()
            | 1 => (note "box:datatype"; emit ("datatype 'a box = Box" ^ K ^ " of 'a * int fun box x = Box" ^ K ^ " (x, " ^ K ^ ") fun unbox (Box" ^ K ^ " (x, _)) = x"))
            | 2 => (note "box:parameter"; emit "type 'a box = 'a X.box val box = X.box val unbox = X.unbox")
            | _ => (note "box"; emit "type 'a box = 'a * t fun box x = (x, mk 0) fun unbox (x, _) = x")
          val () = if #pair body then (note "polymorphic-value"; emit "fun pairUp x = (x, mk 1)") else ()
          val innerExport = #inner body andalso not (List.null inners)
          val () = if innerExport then (note "inner-structure"; emit ("structure Inner = " ^ #1 (hd inners))) else ()
          val via = #via body andalso not (List.null inners)
          val () = if via then (note "open-inner"; emit ("local open " ^ #1 (List.last inners) ^ " in fun via" ^ K ^ " n = obs (mk n) end")) else ()
          val probe = Vector.fromList (#probes body @ List.tabulate (24, fn _ => false))
          fun pr i = Vector.sub (probe, i)
          val () = if pr 12 then (note "equality-tyvar"; emit ("fun member" ^ K ^ " (x : ''a) l = List.exists (fn y => y = x) l")) else ()
          (* a polymorphic value of a typed pattern, and one of a constructor *)
          val () = if pr 16 then (note "polymorphic-typed-value"; emit ("val twice" ^ K ^ " : ('a -> 'a) -> 'a -> 'a = fn f => fn x => f (f x)")) else ()
          val () = if pr 15 andalso #cell made then (note "polymorphic-constructor-value"; emit ("val empty" ^ K ^ " = Nil" ^ K)) else ()
          (* a ref, an array and a vector of the parameter's type and of t *)
          val () = if pr 19 then (note "ref-of-parameter-type"; emit ("val cell" ^ K ^ " = ref (X.mk 0)")) else ()
          val () = if pr 20 then (note "array-of-t"; emit ("val arr" ^ K ^ " = Array.array (2, mk 1)");
                                  emit ("val vec" ^ K ^ " = Vector.fromList [X.mk 2, X.mk 3]")) else ()
          (* declarations of the body that branch, bind a refutable pattern or
             close over the parameter's values *)
          val () = if pr 21 then (note "body-if"; emit ("val pick" ^ K ^ " = if X.obs (X.mk 1) > 3 then mk 1 else mk 2")) else ()
          val () = if pr 22 then (note "body-refutable"; emit ("val SOME first" ^ K ^ " = SOME (obs (mk 1))")) else ()
          val () = if pr 23 then (note "body-closure"; emit ("val sel" ^ K ^ " = let val v = X.mk 2 in fn () => X.obs v + 1 end")) else ()
          (* a pattern binding among the body's declarations *)
          val () = if pr 17 then (note "pattern-binding"; emit ("val (lo" ^ K ^ ", hi" ^ K ^ ") = (obs (mk 1), " ^ str "hi" ^ ")")) else ()
          val exnInners = List.filter (fn (_, v : view) => #exn v) inners
          val probes =
            (if pr 0 then ["Int.toString (obs (mk 3))"] else [])
            @ (if pr 1 andalso #eq xview then (note "equality:parameter"; ["Bool.toString (X.mk 1 = X.mk 1)"]) else [])
            @ (if pr 2 andalso #eq made then (note "equality:body"; ["Bool.toString (mk 2 = mk 2) ^ Bool.toString (mk 1 = mk 2)"]) else [])
            @ (case (pr 3, #dt xview) of (true, SOME s) => [shapeProbe (s, "X.")] | _ => [])
            @ (if pr 4 andalso #exn xview then ["Int.toString ((X.fail 2; 0) handle X.E m => m + 1)"] else [])
            @ (if pr 5 andalso #count xview then (note "effect:parameter"; ["(X.count := !X.count + 1; Int.toString (!X.count))"]) else [])
            @ (if pr 6 andalso #sub xview then ["Int.toString (X.Sub.obs2 (X.Sub.mk2 3))"] else [])
            @ (if pr 7 andalso #poly xview then ["Int.toString (X.unbox (X.box 4) + size (X.unbox (X.box \"ab\")))"] else [])
            @ (if pr 8 then List.map (fn (i, _) => "Int.toString (" ^ i ^ ".obs (" ^ i ^ ".mk 2))") inners
                            @ (case inners of (i, _) :: _ => [i ^ ".tag"] | [] => []) else [])
            @ (if pr 9 then (case exnInners of
                               (a, _) :: (b, _) :: _ => (note "exception:generative"; ["((" ^ a ^ ".fail 0; \"none\") handle " ^ b ^ ".E _ => \"shared\" | " ^ a ^ ".E _ => \"own\")"])
                             | _ => []) else [])
            @ (if pr 10 andalso exnMode <> 0 then ["((fail 1; \"none\") handle E m => Int.toString m)"] else [])
            @ (if #carry body then ["Int.toString ((raise Carry" ^ K ^ " (mk 2)) handle Carry" ^ K ^ " v => obs v)"] else [])
            @ (if pr 12 then ["Bool.toString (member" ^ K ^ " 3 [1, 2, 3])" ^ (if #eq made then " ^ Bool.toString (member" ^ K ^ " (mk 1) [mk 0, mk 1])" else "")] else [])
            @ (if via then ["Int.toString (via" ^ K ^ " 2)"] else [])
            @ (if y then ["Int.toString (Y.obs (X.mk 2) + X.obs (Y.mk 3))"] else [])
            @ (if form = 2 then ["Int.toString k"] else [])
            @ (if #cell made andalso pr 15 then ["Int.toString (cellSum" ^ K ^ " (fn i => i) (Cons" ^ K ^ " (4, empty" ^ K ^ ")) + cellSum" ^ K
                                                 ^ " size (Cons" ^ K ^ " (\"ab\", empty" ^ K ^ ")))"] else [])
            @ (if pr 16 then ["Int.toString (twice" ^ K ^ " (fn i => i + 1) 3) ^ twice" ^ K ^ " (fn s => s ^ \"!\") \"w\""] else [])
            @ (if #int needs then ["Int.toString (X.mk 2 + 1)"] else [])
            @ (if pr 17 then ["Int.toString lo" ^ K ^ " ^ hi" ^ K] else [])
            @ (if pr 19 then ["(cell" ^ K ^ " := X.mk 5; Int.toString (X.obs (!cell" ^ K ^ ")))"] else [])
            @ (if pr 21 then ["Int.toString (obs pick" ^ K ^ ")"] else [])
            @ (if pr 22 then ["Int.toString first" ^ K] else [])
            @ (if pr 23 then ["Int.toString (sel" ^ K ^ " ())"] else [])
            @ (if pr 20 then ["(Array.update (arr" ^ K ^ ", 1, mk 4); Int.toString (obs (Array.sub (arr" ^ K ^ ", 1)) + obs (Array.sub (arr" ^ K
                              ^ ", 0)) + Vector.foldl (fn (x, s) => s + X.obs x) 0 vec" ^ K ^ "))"] else [])
            @ (if pr 18 andalso #tree xview then
                 (note "param:polymorphic-datatype";
                  ["Int.toString (let fun sz X.Leaf = 0 | sz (X.Node (l, _, r)) = sz l + 1 + sz r in sz (X.Node (X.Leaf, X.mk 1, X.Node (X.Leaf, X.mk 2, X.Leaf)))"
                   ^ " + 10 * sz (X.Node (X.Leaf, \"s\", X.Leaf)) end)"])
               else [])
          val () = emit ("val tag = \"" ^ name ^ "(\" ^ X.tag ^ \"" ^ (if List.null probes then "" else ":\" ^ " ^ String.concatWith " ^ \",\" ^ " probes ^ " ^ \"") ^ ")\"")
          val () = if hidden then emit "end" else ()
          (* the result *)
          val has = {exn = exnMode <> 0, count = #count body, sub = subMode <> 0, poly = #poly body <> 0, pair = #pair body, inner = innerExport}
          (* without a parameter, a signature cannot name the body's X *)
          fun mentionsXY lines = List.exists (fn l => String.isSubstring "X." l orelse String.isSubstring "Y." l) lines
          val sp = nth (if form = 5 then List.filter (fn sp : spec => not (mentionsXY (#lines sp))) (#specs made) else #specs made,
                        #spec result)
          val ascr = #ascr result
          val () = note (Vector.sub (Vector.fromList ["ascription:none", "ascription:transparent", "ascription:opaque"], ascr))
          val shows = {exn = #exn has andalso (ascr = 0 orelse #exn result), count = #count has andalso (ascr = 0 orelse #count result),
                       sub = #sub has andalso (ascr = 0 orelse #sub result), poly = #poly has andalso (ascr = 0 orelse #poly result),
                       pair = #pair has andalso (ascr = 0 orelse #pair result), inner = #inner has andalso (ascr = 0 orelse #inner result)}
          val () = if ascr <> 0 andalso (#exn has <> #exn shows orelse #count has <> #count shows orelse #sub has <> #sub shows
                                         orelse #poly has <> #poly shows orelse #pair has <> #pair shows orelse #inner has <> #inner shows)
                   then note "result:partly-hidden" else ()
          val view : view =
            if ascr = 0 then {eq = #eq made, dt = #dt made, exn = #exn shows, count = #count shows, sub = #sub shows, poly = #poly shows,
                              cons = #cons made, pair = #pair shows, inner = #inner shows, int = false, tree = false}
            else {eq = if ascr = 1 andalso List.exists (fn l => l = "type t") (#lines sp) then #eq made else #eq sp, dt = #dt sp, exn = #exn shows, count = #count shows, sub = #sub shows,
                  poly = #poly shows, cons = #cons sp, pair = #pair shows, inner = #inner shows, int = false, tree = false}
          val rlines =
            ["val mk : int -> t", "val obs : t -> int", "val tag : string"]
            @ (if #exn shows then ["exception E of int", "val fail : int -> int"] else [])
            @ (if #count shows then ["val count : int ref"] else [])
            @ (if #sub shows then ["structure Sub : sig type u val mk2 : int -> u val obs2 : u -> int end"] else [])
            @ (if #poly shows then ["type 'a box", "val box : 'a -> 'a box", "val unbox : 'a box -> 'a"] else [])
            @ (if #pair shows then ["val pairUp : 'a -> 'a * t"] else [])
            @ (if #inner shows then [coreSpec] else [])
          val () = if isSome (#cons sp) andalso ascr <> 0 then note "result:datatype-shown" else ()
          val mentionsX = mentionsXY (#lines sp)
          val rsig =
            if ascr = 0 then ""
            else if #named result andalso (not mentionsX orelse #alias sp) then
              (note "result:named";
               sigs := !sigs @ ["signature R" ^ K ^ " = " ^ sigText ((if #alias sp then ["type t"] else #lines sp) @ rlines)];
               if #alias sp then (note "result:where-type"; "R" ^ K ^ " where type t = " ^ String.extract (hd (#lines sp), 9, NONE)) else "R" ^ K)
            else sigText (#lines sp @ rlines)
          val text =
            ["functor " ^ name ^ " " ^ head ^ (case ascr of 0 => "" | 1 => " : " ^ rsig | _ => " :> " ^ rsig) ^ " =", "struct"]
            @ List.map (fn l => "  " ^ l) (!lines) @ ["end"]
        in
          (text, {name = name, form = form, kval = #kval param, needs = needs, view = view, weight = !weight, depth = !depth + 1})
        end

      (* the functors, each with those before it *)
      val (ftexts, finfos) =
        List.foldl (fn (fp, (ts, fs)) => let val (t, f) = functor' (length fs, fp, fs) in (ts @ [t], fs @ [f]) end) ([], []) (#functors p)
      val () = if List.exists (fn f : finfo' => #depth f >= 3) finfos then note "depth:3" else ()
      val () = if List.exists (fn f : finfo' => #depth f >= 4) finfos then note "depth:4" else ()

      (* the applications of the top level *)
      val units : string list list ref = ref []
      val cur : string list ref = ref []
      fun newUnit () = if List.null (!cur) then () else (units := !units @ [!cur]; cur := [])
      fun emit l = cur := !cur @ [l]
      val () = (cur := prelude)
      val () = List.app (fn (i, t) => (if i = 0 orelse break i then newUnit () else (); List.app emit t))
                        (List.tabulate (length ftexts, fn i => (i, List.nth (ftexts, i))))
      val structs : (string * view) list ref = ref []   (* printed, in order *)
      val paths : (string * view) list ref = ref leafViews
      val extra : string list ref = ref []               (* other values printed *)
      val hoisted = ref 0
      fun hoist t = let val n = "T" ^ ints (!hoisted) in hoisted := !hoisted + 1; note "arg:named-for-sharing"; emit ("structure " ^ n ^ " = " ^ t); n end
      fun add (s, v : view) = (structs := !structs @ [(s, v)];
                               paths := !paths @ [(s, v)] @ (if #inner v then [(s ^ ".Inner", core)] else []))
      fun apply (i, j, a, wrap, alias) =
        let
          val f = List.nth (finfos, j)
          val c : actx = {x = NONE, inners = [], paths = !paths, functors = finfos, hoist = hoist, note = note, used = used}
          val (t, _, _, _) = if #form f = 5 then ("", core, 0, 0) else resolveArg c (#needs f) a
          val t = if needsPath f andalso not (isPath t) andalso wrap <> 1 then hoist t else t
          val s = "S" ^ ints i
        in
          used j;
          case wrap of
            0 => (emit ("structure " ^ s ^ " = " ^ applyText (f, t)); add (s, #view f))
          | 1 => (note "top:local";
                  if isPath t orelse #form f = 5 then emit ("structure " ^ s ^ " = " ^ applyText (f, t))
                  else emit ("local structure L" ^ ints i ^ " = " ^ t ^ " in structure " ^ s ^ " = " ^ applyText (f, "L" ^ ints i) ^ " end");
                  add (s, #view f))
          | _ => (note "top:nested";
                  emit ("structure " ^ s ^ " = struct structure In = " ^ applyText (f, t) ^ " val v = In.obs (In.mk 1) end");
                  extra := !extra @ [s ^ ".v"]; add (s ^ ".In", #view f));
          if alias then (note "top:alias"; emit ("structure " ^ s ^ "a = " ^ #1 (List.last (!structs))); add (s ^ "a", #2 (List.last (!structs))))
          else ()
        end
      val nf = length finfos
      val () = List.app (fn (i, {target = j, arg, wrap, alias} : app) =>
                           (if break (6 + i) then newUnit () else (); apply (i, j mod nf, arg, wrap, alias)))
                        (List.tabulate (length (#apps p), fn i => (i, List.nth (#apps p, i))))
      (* a functor applied nowhere is applied once *)
      val () = List.app (fn j => if Array.sub (uses, j) = 0 then apply (length (!structs) + 100 + j, j, APath j, 0, false) else ())
                        (List.tabulate (nf, fn j => j))
      (* the prints *)
      val () = if break 15 then newUnit () else ()
      fun printOf (s, v : view) =
        let
          val parts =
            [s ^ ".tag", "Log.ints [" ^ commas (List.map (fn n => s ^ ".obs (" ^ s ^ ".mk " ^ ints n ^ ")") [0, 1, 4]) ^ "]"]
            @ (if #eq v then ["Bool.toString (" ^ s ^ ".mk 2 = " ^ s ^ ".mk 2)", "Bool.toString (" ^ s ^ ".mk 1 = " ^ s ^ ".mk 3)"] else [])
            @ (case #cons v of
                 SOME cs => List.map (fn n => "(case " ^ s ^ ".mk " ^ ints n ^ " of "
                                              ^ String.concatWith " | " (List.map (fn (c, a) => s ^ "." ^ c ^ (if a then " _" else "") ^ " => " ^ str c) cs) ^ ")")
                                     [1, 2]
               | NONE => [])
            @ (if #sub v then ["Int.toString (" ^ s ^ ".Sub.obs2 (" ^ s ^ ".Sub.mk2 5))"] else [])
            @ (if #poly v then ["Int.toString (" ^ s ^ ".unbox (" ^ s ^ ".box 6) + size (" ^ s ^ ".unbox (" ^ s ^ ".box \"xyz\")))"] else [])
            @ (if #pair v then ["#1 (" ^ s ^ ".pairUp \"pp\") ^ Int.toString (" ^ s ^ ".obs (#2 (" ^ s ^ ".pairUp 0)))"] else [])
            @ (if #inner v then [s ^ ".Inner.tag ^ Int.toString (" ^ s ^ ".Inner.obs (" ^ s ^ ".Inner.mk 2))"] else [])
            @ (if #exn v then ["((" ^ s ^ ".fail 3; \"none\") handle " ^ s ^ ".E m => \"E\" ^ Int.toString m)"] else [])
        in "val () = print (String.concatWith \" \" [" ^ str s ^ ", " ^ commas parts ^ "] ^ \"\\n\")" end
      val () = List.app (fn sv => emit (printOf sv)) (!structs)
      val () = List.app (fn v => emit ("val () = print (" ^ str v ^ " ^ \" \" ^ Int.toString " ^ v ^ " ^ \"\\n\")")) (!extra)
      val exns = List.filter (fn (_, v : view) => #exn v) (!structs)
      fun pairs (a :: (rest as b :: _)) = (a, b) :: pairs rest
        | pairs _ = []
      val () = List.app (fn ((a, _), (b, _)) =>
                           emit ("val () = print (\"exn " ^ a ^ " " ^ b ^ " \" ^ ((" ^ a ^ ".fail 1; \"none\") handle " ^ b ^ ".E _ => "
                                 ^ str b ^ " | " ^ a ^ ".E _ => " ^ str a ^ ") ^ \"\\n\")"))
                        (List.take (pairs exns, Int.min (4, length (pairs exns))))
      val counted = List.map #1 (List.filter (fn (_, v : view) => #count v) (leafViews @ !structs))
      val () = emit ("val () = print (\"counts \" ^ Log.ints [" ^ commas (List.map (fn s => "!" ^ s ^ ".count") counted) ^ "] ^ \"\\n\")")
      val () = emit "val () = Log.tick \"end\""
      val () = newUnit ()
      (* the signatures go to the prelude, after Log *)
      val units = case !units of
                    u :: rest => (List.take (u, 5) @ !sigs @ List.drop (u, 5)) :: rest
                  | [] => []
      val names = List.map #name finfos
      val inline = case #inline p mod 4 of
                     0 => names
                   | 1 => List.take (names, Int.max (1, nf div 2))
                   | 2 => List.tabulate ((nf + 1) div 2, fn i => List.nth (names, 2 * i))
                   | _ => [List.last names]
      val () = if length units >= 4 then note "units:4" else ()
    in
      {units = List.map (fn ls => String.concatWith "\n" ls ^ "\n") units, functors = names,
       budget = Vector.sub (budgets, #budget p mod Vector.length budgets), inline = inline, budgetUnits = #budgetUnits p,
       labels = !labels}
    end

  (* ---- a program as text, and back: its units, each after a line that
     names its file, and a last line of the options of its modes *)
  fun show (p : program) : string =
    String.concat (List.tabulate (length (#units p), fn i => "(* unit u" ^ ints i ^ ".sml *)\n" ^ List.nth (#units p, i)))
    ^ "(* options --inline-functor=" ^ String.concatWith "," (#inline p) ^ " --functor-budget=" ^ ints (#budget p)
    ^ (if #budgetUnits p then " budget-in-units" else "") ^ " *)\n"

  fun parse (text : string) : program =
    let
      val lines = String.fields (fn ch => ch = #"\n") text
      fun go ([], cur, acc, opts) = (List.rev (case cur of SOME c => List.rev c :: acc | NONE => acc), opts)
        | go (l :: rest, cur, acc, opts) =
            if String.isPrefix "(* unit " l then go (rest, SOME [], case cur of SOME c => List.rev c :: acc | NONE => acc, opts)
            else if String.isPrefix "(* options " l then go (rest, cur, acc, String.tokens Char.isSpace l)
            else go (rest, Option.map (fn c => l :: c) cur, acc, opts)
      val (units, opts) = go (lines, NONE, [], [])
      fun opt prefix = Option.map (fn o' => String.extract (o', size prefix, NONE)) (List.find (String.isPrefix prefix) opts)
      val inline = case opt "--inline-functor=" of SOME s => String.tokens (fn ch => ch = #",") s | NONE => []
    in
      {units = List.map (fn ls => String.concatWith "\n" ls ^ "\n") units, functors = inline,
       budget = getOpt (Option.mapPartial Int.fromString (opt "--functor-budget="), 0), inline = inline,
       budgetUnits = List.exists (fn o' => o' = "budget-in-units") opts, labels = []}
    end

  (* ---- the modes and their verdict *)
  type config = {rune : string, vm : string, memory : int, timeout : int}

  val flagOn = ["--functors=functions", "--datatype-tags=sorted-x"]
  type mode = {name : string, flags : string list, run : bool}
  fun modes (p : program) : mode list =
    [{name = "off", flags = [], run = true},
     {name = "on", flags = flagOn @ ["--lint"], run = true},
     {name = "off-units", flags = ["--units", "--no-cache"], run = true},
     {name = "on-units", flags = ["--units", "--no-cache"] @ flagOn @ ["--lint"], run = true},
     {name = "on-units-whole", flags = ["--units", "--whole", "--no-cache"] @ flagOn @ ["--lint"], run = false},
     {name = "on-inline-units", flags = ["--units", "--no-cache", "--inline-functor=" ^ String.concatWith "," (#inline p)] @ flagOn @ ["--lint"],
      run = true},
     {name = if #budgetUnits p then "on-budget-units" else "on-budget",
      flags = (if #budgetUnits p then ["--units", "--no-cache"] else []) @ ["--functor-budget=" ^ ints (#budget p)] @ flagOn @ ["--lint"],
      run = true}]

  (* what a mode did *)
  type outcome = {mode : string, command : string, compiled : int, lint : bool, ran : int option, out : string, err : string}

  fun limits (c : config) = {addressSpace = SOME (#memory c * 1024), cpuTime = NONE, fileSize = SOME 100000000, core = SOME 0}

  fun writeUnits (dir, p : program) =
    (Sh.mkdirs dir;
     List.tabulate (length (#units p), fn i => let val f = "u" ^ ints i ^ ".sml" in Sh.write (dir ^ "/" ^ f, List.nth (#units p, i)); f end))

  fun runMode (c : config, dir, files) (m : mode) : outcome =
    let
      val rbc = #name m ^ ".rbc"
      val cmd = [Sh.fromRoot (#rune c)] @ #flags m @ files @ ["-o", rbc]
      val compiled = Sh.execLimited (limits c) (fn e => e)
                                    {cmd = cmd, dir = SOME dir, stdin = "", stdout = dir ^ "/" ^ #name m ^ ".cerr",
                                     stderr = dir ^ "/" ^ #name m ^ ".cerr", timeout = 4 * #timeout c}
      val cerr = Sh.read (dir ^ "/" ^ #name m ^ ".cerr")
      val lint = String.isSubstring "lint after" cerr
      val ran =
        if compiled <> 0 orelse not (#run m) then NONE
        else SOME (Sh.execLimited (limits c) (fn e => e)
                                  {cmd = [Sh.fromRoot (#vm c), "--checked", rbc], dir = SOME dir, stdin = "",
                                   stdout = dir ^ "/" ^ #name m ^ ".out", stderr = dir ^ "/" ^ #name m ^ ".err", timeout = #timeout c})
    in
      {mode = #name m, command = String.concatWith " " (List.map Sh.quote (#rune c :: #flags m @ files @ ["-o", rbc])),
       compiled = compiled, lint = lint, ran = ran,
       out = if isSome ran then Sh.read (dir ^ "/" ^ #name m ^ ".out") else "",
       err = if isSome ran then Sh.read (dir ^ "/" ^ #name m ^ ".err") else cerr}
    end

  (* the failures, each its own class, so that a shrink keeps to one *)
  exception Invalid
  exception TimedOut
  exception CompileOn and LintOn and DiffersOn
  exception CompileOffUnits and DiffersOffUnits
  exception CompileOnUnits and LintOnUnits and DiffersOnUnits
  exception CompileUnitsWhole and LintUnitsWhole and NotS42
  exception CompileInline and LintInline and DiffersInline
  exception CompileBudget and LintBudget and DiffersBudget
  exception CompileBudgetUnits and LintBudgetUnits and DiffersBudgetUnits
  fun failure (kind, mode) =
    case (kind, mode) of
      ("compile", "on") => CompileOn | ("lint", "on") => LintOn | ("differs", "on") => DiffersOn
    | ("compile", "off-units") => CompileOffUnits | ("lint", "off-units") => CompileOffUnits | ("differs", "off-units") => DiffersOffUnits
    | ("compile", "on-units") => CompileOnUnits | ("lint", "on-units") => LintOnUnits | ("differs", "on-units") => DiffersOnUnits
    | ("compile", "on-units-whole") => CompileUnitsWhole | ("lint", "on-units-whole") => LintUnitsWhole
    | ("differs", "on-units-whole") => NotS42
    | ("compile", "on-inline-units") => CompileInline | ("lint", "on-inline-units") => LintInline
    | ("differs", "on-inline-units") => DiffersInline
    | ("compile", "on-budget") => CompileBudget | ("lint", "on-budget") => LintBudget | ("differs", "on-budget") => DiffersBudget
    | ("compile", "on-budget-units") => CompileBudgetUnits | ("lint", "on-budget-units") => LintBudgetUnits
    | ("differs", "on-budget-units") => DiffersBudgetUnits
    | ("timeout", _) => TimedOut
    | _ => Invalid

  (* a failure known and not yet fixed (tests/functors/known.txt): a mode
     (a glob, * for any) and a text its message has; a failure it covers is
     counted and the program goes on to its next mode *)
  type known = {mode : string, text : string, why : string}
  fun glob (pat, s) =
    case String.fields (fn ch => ch = #"*") pat of
      [whole] => whole = s
    | first :: rest =>
        let
          fun go (at, []) = true
            | go (at, [last]) = size s - at >= size last andalso String.isSuffix last s
            | go (at, piece :: more) =
                (case List.find (fn i => String.isPrefix piece (String.extract (s, i, NONE)))
                                (List.tabulate (Int.max (0, size s - at - size piece + 1), fn i => at + i)) of
                   SOME i => go (i + size piece, more)
                 | NONE => false)
        in String.isPrefix first s andalso go (size first, rest) end
    | [] => s = ""
  fun readKnown file : known list =
    List.mapPartial (fn l => case List.map (fn f => String.concatWith " " (String.tokens Char.isSpace f)) (String.fields (fn ch => ch = #"|") l) of
                               [m, t, why] => if String.isPrefix "#" m then NONE else SOME {mode = m, text = t, why = why}
                             | _ => NONE)
                    (Sh.lines (Sh.read file))
  fun describeKnown (k : known) = #mode k ^ " | " ^ #text k
  fun covers (ks : known list) (_ : string, mode, why) = List.find (fn k : known => glob (#mode k, mode) andalso String.isSubstring (#text k) why) ks

  (* the verdict on a program: each mode in turn, until one fails (all of
     them where keepGoing); and the known failures it met *)
  fun examine (c : config, dir : string, keepGoing : bool, ks : known list) (p : program)
      : outcome list * (string * string * string) option * known list =
    let
      val () = Sh.rmTree dir
      val files = writeUnits (dir, p)
      fun same (a, b) = Sh.exists a andalso Sh.exists b andalso Sh.read a = Sh.read b
      fun go ([], done, verdict, _, hits) = (List.rev done, verdict, List.rev hits)
        | go (m :: rest, done, verdict, reference : outcome option, hits) =
            if isSome verdict andalso not keepGoing then (List.rev done, verdict, List.rev hits)
            else
              let
                val o' = runMode (c, dir, files) m
                val v =
                  if #compiled o' = 124 orelse #ran o' = SOME 124 then SOME ("timeout", #mode o', "it takes too long")
                  else if #name m = "off" then
                    (if #compiled o' <> 0 then SOME ("invalid", "off", "the program does not compile with the flag off: "
                                                                     ^ Sh.firstNonEmpty (dir ^ "/off.cerr"))
                     else if #ran o' <> SOME 0 then SOME ("invalid", "off", "the program fails with the flag off")
                     else NONE)
                  else if #compiled o' <> 0 then
                    SOME (if #lint o' then "lint" else "compile", #mode o',
                          case List.find (fn l => String.isSubstring "error" l orelse String.isSubstring "rror:" l)
                                         (Sh.lines (#err o')) of SOME l => l | NONE => Sh.firstNonEmpty (dir ^ "/" ^ #mode o' ^ ".cerr"))
                  else if not (#run m) then
                    (if same (dir ^ "/on.rbc", dir ^ "/" ^ #name m ^ ".rbc") then NONE
                     else SOME ("differs", #mode o', "--units --whole is not the bytes of the whole compile"))
                  else
                    case reference of
                      SOME r => if #out r = #out o' andalso #ran r = #ran o' then NONE
                                else SOME ("differs", #mode o', "it prints otherwise than with the flag off whole: "
                                                                ^ Sh.difference (dir ^ "/off.out", dir ^ "/" ^ #mode o' ^ ".out"))
                    | NONE => NONE
                val (v, hits) = case Option.mapPartial (covers ks) v of
                                  SOME k => (NONE, k :: hits)
                                | NONE => (v, hits)
                val verdict = case verdict of SOME _ => verdict | NONE => v
                val reference = if #name m = "off" then SOME o' else reference
              in
                if #name m = "off" andalso isSome v then (List.rev (o' :: done), verdict, List.rev hits)
                else go (rest, o' :: done, verdict, reference, hits)
              end
    in go (modes p, [], NONE, NONE, []) end

  (* ---- the property, and a run of it *)
  type tally = {known : (known * int) list ref}
  fun count (t : tally) (k : known) =
    #known t := (case List.find (fn (k', _) => describeKnown k' = describeKnown k) (!(#known t)) of
                   SOME _ => List.map (fn (k', n) => if describeKnown k' = describeKnown k then (k', n + 1) else (k', n)) (!(#known t))
                 | NONE => !(#known t) @ [(k, 1)])

  fun property (c : config, dir : string, ks : known list, t : tally) : Prop.prop =
    Prop.forAllGen (Gen.map elaborate planGen, show)
                   (fn p =>
                      let
                        val (_, verdict, hits) = examine (c, dir, false, ks) p
                        val base = case verdict of
                                     NONE => (List.app (count t) hits; Prop.holds true)
                                   | SOME (kind, mode, _) => raise failure (kind, mode)
                      in List.foldl (fn (l, q) => Prop.label l q) base (#labels p @ List.map (fn k => "known: " ^ describeKnown k) hits) end)

  (* a program kept: its units, its text, and what each mode compiled and
     printed (modes.txt) *)
  fun keep (c : config, work : string, dir : string, p : program, ks : known list, class : string)
      : (string * string * string) option * known list =
    let
      val (outcomes, verdict, hits) = examine (c, work, true, ks) p
      val () = Sh.mkdirs dir
      val _ = writeUnits (dir, p)
      val () = Sh.write (dir ^ "/program.sml", show p)
      val summary =
        (if class = "" then "" else "class: " ^ class ^ "\n")
        ^ (case verdict of SOME (k, m, why) => "verdict: " ^ k ^ " in " ^ m ^ ": " ^ why ^ "\n" | NONE => "verdict: passes\n")
        ^ String.concat (List.map (fn k => "known: " ^ describeKnown k ^ "\n") hits)
        ^ String.concat (List.map (fn o' : outcome =>
                                     "\n== " ^ #mode o' ^ "\n$ " ^ #command o' ^ "\ncompile: exit " ^ ints (#compiled o')
                                     ^ (if #lint o' then " (lint)" else "") ^ "\n"
                                     ^ (case #ran o' of SOME code => "run: exit " ^ ints code ^ "\n--- stdout\n" ^ #out o'
                                                       | NONE => "")
                                     ^ (if #err o' = "" then "" else "--- stderr\n" ^ #err o'))
                                  outcomes)
    in Sh.write (dir ^ "/modes.txt", summary); (verdict, hits) end

  type run = {seed : int, count : int, maxSize : int, shrinks : int, out : string, known : known list}

  (* one run of count programs from a seed: PASS with the shapes it met, or
     FAIL with the shrunk program, kept under out/failures *)
  fun check (c : config) (r : run) : bool =
    let
      val work = #out r ^ "/work-" ^ ints (#seed r)
      val config = {seed = SOME (Word64.fromInt (#seed r)), tests = #count r, maxSize = #maxSize r, maxDiscards = 10,
                    maxShrinks = #shrinks r, exhaustiveBelow = 0, smallScope = 0}
      val name = "functor-programs seed " ^ ints (#seed r)
      val t = {known = ref []}
      val result = Check.check config name (property (c, work, #known r, t))
      val knownLines = String.concat (List.map (fn (k, n) => "  known failure met " ^ ints n ^ " times: " ^ describeKnown k ^ "\n") (!(#known t)))
    in
      case result of
        Check.Passed _ => (Sh.say (Check.report name result ^ knownLines); Sh.rmTree work; true)
      | Check.GaveUp _ => (Sh.say (Check.report name result); false)
      | Check.Failed {class, counterexample, shrinks, replay, test, ...} =>
          let
            val dir = #out r ^ "/failures/seed" ^ ints (#seed r) ^ "-case" ^ ints (test + 1)
            val text = case counterexample of t :: _ => t | [] => ""
            val (verdict, _) = keep (c, work, dir, parse text, #known r, class)
          in
            Sh.say ("FAIL " ^ name ^ ": " ^ class ^ " at case " ^ ints (test + 1) ^ ", shrunk in " ^ ints shrinks ^ " runs (replay "
                    ^ replay ^ ")\n"
                    ^ (case verdict of SOME (k, m, why) => "  " ^ k ^ " in " ^ m ^ ": " ^ why ^ "\n" | NONE => "  passes when run again\n")
                    ^ "  kept in " ^ dir ^ "\n" ^ knownLines);
            Sh.rmTree work;
            false
          end
    end

  (* the programs of a directory, each run in every mode: one that fails
     fails, unless a known failure covers it; and a known failure that no
     program meets is stale (fixed: its line goes) *)
  fun regressions (c : config, dir : string, out : string, ks : known list) : bool =
    let
      val files = Sh.glob (dir, ".sml")
      fun one f =
        let
          val name = Sh.basename f
          val (verdict, hits) = keep (c, out ^ "/work", out ^ "/" ^ name, parse (Sh.read f), ks, "")
        in
          case verdict of
            SOME (k, m, why) => (Sh.say ("FAIL functors." ^ name ^ ": " ^ k ^ " in " ^ m ^ ": " ^ why ^ " (" ^ out ^ "/" ^ name ^ "/modes.txt)\n"); (false, hits))
          | NONE => (List.app (fn k => Sh.say ("known functors." ^ name ^ ": " ^ describeKnown k ^ "\n")) hits; (true, hits))
        end
      val results = List.map one files
      val met = List.concat (List.map #2 results)
      val stale = List.filter (fn k => not (List.exists (fn k' => describeKnown k' = describeKnown k) met)) ks
      val () = List.app (fn k => Sh.say ("FAIL functors: no program fails as the known line says, so it is fixed and the line goes: "
                                          ^ describeKnown k ^ "\n")) stale
      val () = Sh.rmTree (out ^ "/work")
    in List.all #1 results andalso List.null stale end

  (* the program of a case: its token's seed and size, as a failure's
     replay names them *)
  fun sample (seed : Word64.word, size : int) : program =
    elaborate (Gen.draw planGen (P.new (seed, size, [], []), P.child (P.root, 1)))
end
