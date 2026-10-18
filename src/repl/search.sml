(* `:search` (docs/plans/repl.md, D15 and M8): the values of the session --
   the top level and its structures' members, the library's own left out --
   whose name holds the text, or, where the text is a type (it has `->`),
   whose type is like it. "Like" is Rittri's matching modulo isomorphism: a
   function's arguments as a bag, curried or in a tuple alike, so that
   `int -> 'a list -> 'a` finds `List.nth : 'a list * int -> 'a`; the type
   variables of the value may be instantiated, by first-order unification,
   those of the query not: a value that works for what is asked. Each
   result has a distance, after Runciman and Toyn's: 0 for the same type,
   and one more for each argument out of order, for a change between curried
   and tupled, and for each variable instantiated; the nearest come first. *)
structure ReplSearch =
struct
  datatype var = Q of int | K of int       (* the query's, a candidate's *)
  datatype term = V of var | C of int * term list | R of (string * term) list | F of term * term

  fun termOf (side : int -> var) (t : Types.ty) : term =
    case Types.prune t of
      (* an operator overloaded over a class (`+`, `size`) is at the type it
         defaults to, as the printer shows it, and is no variable that any
         type instantiates *)
      Types.TVar (ref (Types.Unbound {kind = Types.KOverload kinds, id, ...})) =>
        (case List.find (fn (k, _) => List.exists (fn k' => k' = k) kinds)
                        [("int", Types.intTycon), ("real", Types.realTycon), ("word", Types.wordTycon),
                         ("char", Types.charTycon), ("string", Types.stringTycon)] of
           SOME (_, c) => C (#stamp c, [])
         | NONE => V (side id))
    | Types.TVar (ref (Types.Unbound {id, ...})) => V (side id)
    | Types.TVar _ => C (~1, [])
    | Types.TCon (c, args) => C (#stamp c, List.map (termOf side) args)
    | Types.TRecord fs => R (List.map (fn (l, a) => (l, termOf side a)) fs)
    | Types.TArrow (a, b) => F (termOf side a, termOf side b)

  fun isTuple (fs : (string * term) list) =
    List.length fs >= 2
    andalso #2 (List.foldl (fn ((l, _), (i, ok)) => (i + 1, ok andalso l = Int.toString i)) (1, true) fs)

  (* a function's arguments, curried or in tuples, and its result; whether
     an argument was a tuple *)
  fun shape (t : term) : term list * term * bool =
    case t of
      F (R fs, r) =>
        if isTuple fs then let val (more, res, _) = shape r in (List.map #2 fs @ more, res, true) end
        else let val (more, res, tup) = shape r in (R fs :: more, res, tup) end
    | F (a, r) => let val (more, res, tup) = shape r in (a :: more, res, tup) end
    | other => ([], other, false)

  (* ---- unification on terms, a substitution as a list ---- *)

  fun walk (s : (var * term) list) (t : term) : term =
    case t of
      V v => (case List.find (fn (w, _) => w = v) s of SOME (_, u) => walk s u | NONE => t)
    | _ => t

  fun occurs (s, v, t) =
    case walk s t of
      V w => v = w
    | C (_, ts) => List.exists (fn u => occurs (s, v, u)) ts
    | R fs => List.exists (fn (_, u) => occurs (s, v, u)) fs
    | F (a, b) => occurs (s, v, a) orelse occurs (s, v, b)

  (* a candidate's variables may be instantiated, the query's not: the
     candidate must be at least as general as what is asked for *)
  fun unify (s : (var * term) list, a : term, b : term) : (var * term) list option =
    case (walk s a, walk s b) of
      (V v, V w) =>
        if v = w then SOME s
        else (case (v, w) of
                (K _, _) => SOME ((v, V w) :: s)
              | (_, K _) => SOME ((w, V v) :: s)
              | _ => NONE)
    | (V (v as K _), t) => if occurs (s, v, t) then NONE else SOME ((v, t) :: s)
    | (t, V (v as K _)) => if occurs (s, v, t) then NONE else SOME ((v, t) :: s)
    | (V (Q _), _) => NONE
    | (_, V (Q _)) => NONE
    | (C (c, xs), C (d, ys)) => if c = d andalso List.length xs = List.length ys then unifyAll (s, xs, ys) else NONE
    | (R fs, R gs) =>
        if List.length fs = List.length gs andalso ListPair.all (fn ((l, _), (m, _)) => l = m) (fs, gs)
        then unifyAll (s, List.map #2 fs, List.map #2 gs) else NONE
    | (F (a1, b1), F (a2, b2)) => (case unify (s, a1, a2) of SOME s => unify (s, b1, b2) | NONE => NONE)
    | _ => NONE
  and unifyAll (s, [], []) = SOME s
    | unifyAll (s, x :: xs, y :: ys) = (case unify (s, x, y) of SOME s => unifyAll (s, xs, ys) | NONE => NONE)
    | unifyAll _ = NONE

  (* the variables a substitution made something other than a variable *)
  fun instantiated (s : (var * term) list) : int =
    List.length (List.filter (fn (_, t) => case walk s t of V _ => false | _ => true) s)

  fun permutations [] = [[]]
    | permutations xs =
        List.concat (List.map (fn x => List.map (fn p => x :: p) (permutations (List.filter (fn y => y <> x) xs))) xs)

  (* the distance from the query to a candidate's type, or NONE where they
     are not alike *)
  fun distance (query : term, candidate : term) : int option =
    let
      val (qa, qr, qt) = shape query
      val (ca, cr, ct) = shape candidate
      val n = List.length qa
    in
      if n <> List.length ca then NONE
      else
        let
          val orders = if n <= 4 then permutations (List.tabulate (n, fn i => i)) else [List.tabulate (n, fn i => i)]
          val cv = Vector.fromList ca
          fun cost order =
            case unifyAll ([], qr :: qa, cr :: List.map (fn i => Vector.sub (cv, i)) order) of
              SOME s =>
                SOME (instantiated s + #1 (List.foldl (fn (i, (k, j)) => (if i = j then k else k + 1, j + 1)) (0, 0) order)
                      + (if qt = ct then 0 else 1))
            | NONE => NONE
        in
          List.foldl (fn (order, best) =>
                        case (cost order, best) of
                          (SOME c, SOME b) => SOME (Int.min (c, b))
                        | (SOME c, NONE) => SOME c
                        | (NONE, b) => b)
                     NONE orders
        end
    end

  (* ---- the values of the session ---- *)

  fun private (n : string) = String.isPrefix "Rune" n orelse String.isPrefix "RUNE" n

  (* each value with its path and type: the top level, then its structures
     to a depth of three, the library's own left out *)
  fun values (env : Env.env) : (string * Types.ty) list =
    let
      fun valsOf (prefix, e) =
        StringMap.foldri (fn (n, Env.Val {scheme, ...}, acc) => (prefix ^ n, scheme) :: acc
                           | (n, Env.Prim {scheme, ...}, acc) => (prefix ^ n, scheme) :: acc
                           | (_, _, acc) => acc) [] (Env.vals e)
      fun go (prefix, e, depth) =
        valsOf (prefix, e)
        @ (if depth = 0 then []
           else List.concat (StringMap.foldri (fn (n, s, acc) => if private n then acc else go (prefix ^ n ^ ".", s, depth - 1) :: acc)
                                              [] (Env.strs e)))
    in go ("", env, 3) end

  fun line (env : Env.env) (name : string, t : Types.ty) : string =
    ReplFront.paint "repl.name" name ^ " : " ^ ReplHighlight.paint (env, ReplShow.typeIn env t, ReplHighlight.aType)

  fun limited (k : int, results : string list) : string =
    let val shown = List.take (results, Int.min (k, List.length results))
    in
      String.concat (List.map (fn r => r ^ "\n") shown)
      ^ (if List.length results > k then ReplFront.paint "repl.ui" ("... and " ^ Int.toString (List.length results - k) ^ " more") ^ "\n"
         else "")
    end

  fun byName (env : Env.env, text : string) : string =
    let
      val lower = String.map Char.toLower text
      fun holds name = String.isSubstring lower (String.map Char.toLower name)
      val found = List.filter (fn (n, _) => holds (List.last (String.fields (fn c => c = #".") n))) (values env)
      (* the top level first, then by length *)
      fun shorter ((a, _), (b, _)) = String.size a < String.size b orelse (String.size a = String.size b andalso a < b)
      fun sort [] = []
        | sort (x :: xs) = sort (List.filter (fn y => shorter (y, x)) xs) @ [x] @ sort (List.filter (fn y => not (shorter (y, x))) xs)
    in
      case sort found of
        [] => "no value's name holds " ^ text ^ "\n"
      | sorted => limited (40, List.map (line env) sorted)
    end

  fun byType (env : Env.env, text : string) : string =
    let
      val query =
        case Types.prune (ReplQuery.typeOf ("fn (x : " ^ text ^ ") => x")) of
          Types.TArrow (q, _) => termOf Q q
        | _ => raise Fail ("not a type: " ^ text)
      val scored = List.mapPartial (fn (n, t) => Option.map (fn d => (d, n, t)) (distance (query, termOf K t))) (values env)
      fun before' ((d1, n1, _), (d2, n2, _)) = d1 < d2 orelse (d1 = d2 andalso (String.size n1 < String.size n2
                                                                               orelse (String.size n1 = String.size n2 andalso n1 < n2)))
      fun sort [] = []
        | sort (x :: xs) = sort (List.filter (fn y => before' (y, x)) xs) @ [x] @ sort (List.filter (fn y => not (before' (y, x))) xs)
    in
      case sort scored of
        [] => "no value's type is like " ^ text ^ "\n"
      | sorted => limited (30, List.map (fn (_, n, t) => line env (n, t)) sorted)
    end

  fun search (env : Env.env, text : string) : string =
    if String.isSubstring "->" text then byType (env, text) else byName (env, text)
end
