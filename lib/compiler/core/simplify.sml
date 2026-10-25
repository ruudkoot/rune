(* The simplifier (docs/ir.md; docs/plans/middle-end.md, M7): shrinking
   reductions on Mid, which leave it no larger (Appel and Jim 1997), in a
   few rounds, each after a census of the uses of every variable, join point
   and function:
   * a variable bound to an atom is the atom, where it abstracts over no
     type variables;
   * a step nothing uses is dropped where it has no effect (Prims.removable);
   * what is known is used: the tag of a constructor made in the same
     function, a field of a tuple or constructor made there, an If on a
     known bool;
   * a primitive of int, word or char on constants is folded, at the
     target's precision (Target.t's intBits), unless it would raise, which
     is left to run -- a division by 0, an overflow;
   * a join point nothing jumps to goes, and one jumped to once is put
     where the jump is;
   * a join point that tests its one parameter, a bool, where a jump gives
     it a constant, is two, one for each branch, and the jump goes to its
     branch's -- andalso and orelse as branches;
   * a raise in a handler's region, in the region's own code, is a jump to
     the handler, which becomes a join point;
   * a function nothing uses goes, and one called once, where it is made,
     is put where the call is; a function of the top level small enough,
     where it is called, within a budget of growth (M10) -- its positions
     then name it as a frame inlined where it was called (Mid.pos);
   * a function that only calls another with its parameter is the other
     (eta), where it abstracts over no type variables.
   Every rewrite asks Pass.spend first, so that --fuel can find one that
   breaks a program. The types are kept: what is put in a variable's place
   has its type, and a function put in place is at the types it is called
   at. *)
structure Simplify =
struct
  open Mid

  fun bug msg = Error.bug ("Simplify: " ^ msg)

  (* Pass.spend, and whether this round has rewritten anything: a round
     that has not is the last. *)
  val changed = ref false
  val () = CompilerState.cellRoot ("Simplify.changed", changed)
  fun spend () = Pass.spend () andalso (changed := true; true)

  (* ---- the census ---- *)

  (* The uses of every variable and the jumps to every join point of an
     expression. Stamps are unique, so the census, and what a round knows
     of each variable, are tables of stamps, which are only asked (IntTable).
     What a rewrite makes is added to the census of the round (censusInto),
     rather than a census taken again of all around it, which is quadratic
     where a function has many calls inlined: a use counted more than there
     is only keeps what could go, but every one there is must be counted. *)
  type census = {vars : int IntTable.table, labels : int IntTable.table}

  fun bump (t, k) = IntTable.bump (t, k)

  fun censusInto (c as {vars, labels} : census, e : exp) : unit =
    let
      fun atom a = case a of Var (x, _) => bump (vars, x) | _ => ()
      fun rhs r =
        case r of
          Atom a => atom a
        | App (f, xs) => (atom f; List.app atom xs)
        | Prim (_, _, xs) => List.app atom xs
        | Tuple xs => List.app atom xs
        | Select (_, a) => atom a
        | Con (_, _, a) => atom a
        | Decon (_, _, a) => atom a
        | ConTag a => atom a
        | MkExn (x, y) => (atom x; atom y)
        | ExnCon a => atom a
        | ExnArg (_, a) => atom a
        | SetGlobal (_, a) => atom a
        | _ => ()
      fun exp e =
        case e of
          Let (_, _, r, b) => (rhs r; exp b)
        | Fun (fs, b) => (List.app (fn f => exp (#body f)) fs; exp b)
        | Join (_, _, body, s) => (exp body; exp s)
        | Jump (j, xs) => (List.app atom xs; bump (labels, j))
        | If (a, t, f) => (atom a; exp t; exp f)
        | Handle (a, _, h) => (exp a; exp h)
        | Raise a => atom a
        | Return r => rhs r
        | Mark (_, a) => exp a
    in
      exp e
    end

  fun census (e : exp) : census =
    let val c = {vars = IntTable.table 64, labels = IntTable.table 16}
    in censusInto (c, e); c end

  (* The uses of atoms that are no longer there. *)
  fun uncount (c : census, xs : atom list) : unit =
    List.app (fn Var (x, _) =>
                   (case IntTable.find (#vars c, x) of
                      SOME n => IntTable.insert (#vars c, x, Int.max (n - 1, 0))
                    | NONE => ())
               | _ => ()) xs

  fun uses (c : census, x) = case IntTable.find (#vars c, x) of SOME n => n | NONE => 0
  fun jumps (c : census, j) = case IntTable.find (#labels c, j) of SOME n => n | NONE => 0

  (* ---- what may go ---- *)

  (* A step that may be dropped where nothing uses its value: it has no
     effect but to make that value. A deconstruction or a field is only made
     where the translation has tested what it takes apart. *)
  fun removable (r : rhs) : bool =
    case r of
      Atom _ => true
    | App _ => false
    | Prim (p, _, _) => Prims.removable p
    | SetGlobal _ => false
    | _ => true

  (* ---- constants ---- *)

  (* int and word at the target's precision (Target.intBits), whose powers
     of two are worked out once; the 64-bit types' primitives are not folded *)
  local
    val known = ref (0, IntInf.fromInt 0, IntInf.fromInt 0)   (* the bits, 2^(bits - 1), 2^bits *)
    val () = CompilerState.cellRoot ("Simplify.known", known)
    fun powers () =
      let val bits = !Target.intBits
      in
        if #1 (!known) = bits then ()
        else known := (bits, IntInf.pow (IntInf.fromInt 2, bits - 1), IntInf.pow (IntInf.fromInt 2, bits));
        !known
      end
  in
    fun fitsInt i = let val (_, half, _) = powers () in IntInf.>= (i, IntInf.~ half) andalso IntInf.< (i, half) end
    fun wrapWord w = IntInf.mod (w, #3 (powers ()))
  end

  fun boolAtom b = Con0 (if b then 1 else 0, Ty.bool)

  (* A primitive of constants, where its result is known and it does not
     raise: an atom. *)
  fun fold (p : string, pty : Ty.ty, xs : atom list) : atom option =
    let
      val result = case Ty.view pty of Ty.Arrow (_, r) => r | _ => Ty.int
      fun ints () = case xs of [Const (Lambda.CInt a, _), Const (Lambda.CInt b, _)] => SOME (a, b) | _ => NONE
      fun words () = case xs of [Const (Lambda.CWord a, _), Const (Lambda.CWord b, _)] => SOME (a, b) | _ => NONE
      fun int f = case ints () of
                    SOME (a, b) => let val r = f (a, b) in if fitsInt r then SOME (Const (Lambda.CInt r, result)) else NONE end
                  | NONE => NONE
      (* a division by 0 raises Div, and the least int's div or quot by ~1
         Overflow (its quotient fits no int): those are left to run *)
      fun intDiv f = case ints () of SOME (_, b) => if IntInf.sign b = 0 then NONE else int f | NONE => NONE
      fun intCmp f = case ints () of SOME (a, b) => SOME (boolAtom (f (a, b))) | NONE => NONE
      fun word f = case words () of SOME (a, b) => SOME (Const (Lambda.CWord (wrapWord (f (a, b))), result)) | NONE => NONE
      fun wordDiv f = case words () of SOME (_, b) => if IntInf.sign b = 0 then NONE else word f | NONE => NONE
      fun wordCmp f = case words () of SOME (a, b) => SOME (boolAtom (f (a, b))) | NONE => NONE
      fun eqs () =
        case xs of
          [Const (Lambda.CInt a, _), Const (Lambda.CInt b, _)] => SOME (boolAtom (a = b))
        | [Const (Lambda.CWord a, _), Const (Lambda.CWord b, _)] => SOME (boolAtom (a = b))
        | [Const (Lambda.CChar a, _), Const (Lambda.CChar b, _)] => SOME (boolAtom (a = b))
        | [Con0 (a, _), Con0 (b, _)] => SOME (boolAtom (a = b))
        | [Const (Lambda.CString a, _), Const (Lambda.CString b, _)] => SOME (boolAtom (a = b))
        | _ => NONE
    in
      case p of
        "int_add" => int IntInf.+
      | "int_sub" => int IntInf.-
      | "int_mul" => int IntInf.*
      | "int_div" => intDiv IntInf.div
      | "int_mod" => intDiv IntInf.mod
      | "int_quot" => intDiv IntInf.quot
      | "int_rem" => intDiv IntInf.rem
      | "int_lt" => intCmp IntInf.<
      | "int_le" => intCmp IntInf.<=
      | "int_gt" => intCmp IntInf.>
      | "int_ge" => intCmp IntInf.>=
      | "word_add" => word IntInf.+
      | "word_sub" => word IntInf.-
      | "word_mul" => word IntInf.*
      | "word_div" => wordDiv IntInf.div
      | "word_mod" => wordDiv IntInf.mod
      | "word_lt" => wordCmp IntInf.<
      | "word_le" => wordCmp IntInf.<=
      | "word_gt" => wordCmp IntInf.>
      | "word_ge" => wordCmp IntInf.>=
      | "poly_eq" => eqs ()
      | "imm_eq" => eqs ()
      | "ptr_eq" =>
          (case xs of
             [Global (a, []), Global (b, [])] => if a = b then SOME (boolAtom true) else NONE
           | [Var (a, []), Var (b, [])] => if a = b then SOME (boolAtom true) else NONE
           | [Con0 (a, _), Con0 (b, _)] => SOME (boolAtom (a = b))
           | _ => NONE)
      | "string_eq" =>
          (case xs of
             [Var (a, []), Var (b, [])] => if a = b then SOME (boolAtom true) else NONE
           | _ => eqs ())
      | _ => NONE
    end

  (* ---- the rewriting ---- *)

  (* What a variable is known to be: a step that made it, of those whose
     parts can be read back. *)
  datatype known = Made of rhs
                 | Fields of atom vector   (* a tuple made of these, read a field in a step: a functor's record
                                              of many (--functors=functions) *)

  (* What a round knows: the atom each variable it has dropped is, and what
     made each variable whose parts can be read back. A variable is used only
     where it is in scope, so neither need forget. *)
  type env = {subst : atom IntTable.table, known : known IntTable.table}

  fun substAtom (env : env, a : atom) : atom =
    case a of
      Var (x, []) => (case IntTable.find (#subst env, x) of SOME b => b | NONE => a)
    | _ => a

  fun substRhs (env, r : rhs) : rhs =
    let fun at a = substAtom (env, a)
    in
      case r of
        Atom a => Atom (at a)
      | App (f, xs) => App (at f, List.map at xs)
      | Prim (p, t, xs) => Prim (p, t, List.map at xs)
      | Tuple xs => Tuple (List.map at xs)
      | Select (i, a) => Select (i, at a)
      | Con (tag, t, a) => Con (tag, t, at a)
      | Decon (tag, t, a) => Decon (tag, t, at a)
      | ConTag a => ConTag (at a)
      | MkExn (c, a) => MkExn (at c, at a)
      | ExnCon a => ExnCon (at a)
      | ExnArg (t, a) => ExnArg (t, at a)
      | SetGlobal (g, a) => SetGlobal (g, at a)
      | _ => r
    end

  (* What a step is, now that what is known is used: an atom where it can
     be. *)
  (* Whether the values of a type are never in the heap, nor unit: ints,
     words, chars, and the nullary constructors of a datatype that has no
     other (bool, order). `=` of them is imm_eq (M11). *)
  fun immediate (t : Ty.ty) : bool =
    case Ty.view t of
      Ty.Con (stamp, _, _) =>
        List.exists (fn c => stamp = #stamp c) [Types.intTycon, Types.wordTycon, Types.charTycon, Types.boolTycon]
        orelse (case Ty.datatypeOf stamp of
                  SOME {cons = cons as _ :: _, ...} => List.all (fn (_, _, arg) => not (isSome arg)) cons
                | _ => false)
    | _ => false

  (* Whether a type's values are compared by identity: a ref, an array,
     an array of bytes or of reals, whose `=` is their address. *)
  fun identity (t : Ty.ty) : bool =
    case Ty.view t of
      Ty.Con (stamp, _, _) =>
        List.exists (fn c => stamp = #stamp c)
                    [Types.refTycon, Types.arrayTycon, Types.bytearrayTycon, Types.realarrayTycon]
    | _ => false

  fun isString (t : Ty.ty) : bool =
    case Ty.view t of
      Ty.Con (stamp, _, []) => stamp = #stamp Types.stringTycon
    | _ => false

  (* What `=` of values of type t is, given its arguments, where the type
     says more than poly_eq's walk (M11; performance M5, D7 B): imm_eq for
     values never in the heap; ptr_eq for values compared by identity, and
     where one argument is a nullary constructor -- an immediate, which no
     value in the heap equals (`l = []`, `x = NONE`); string_eq for
     strings. *)
  fun eqByType (t : Ty.ty, xs : atom list) : string option =
    if immediate t then SOME "imm_eq"
    else if identity t orelse List.exists (fn Con0 _ => true | _ => false) xs then SOME "ptr_eq"
    else if isString t then SOME "string_eq"
    else NONE

  fun freshStamp () = Elaborate.freshStamp ()

  (* a type as a key of a table: its node's number, which is the type's
     (Ty.id) -- a key only looked up, so that the number's order is no
     order of the output *)
  fun tyKey (t : Ty.ty) : string = Int.toString (Ty.id t)

  val inlinable : fundef IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Simplify.inlinable", inlinable, IntTable.copy)
  (* whether inlining is on, for the local functions registered as they are
     met (keepFun) *)
  val inlining = ref false
  val () = CompilerState.cellRoot ("Simplify.inlining", inlining)

  (* ---- equality functions (performance M5, D7 C) ---- *)

  (* The optional pass `equality`, from -O2 (D7 C, an opt-in by the owner's
     decision of 2026-10-12): `=` of a datatype at a type with no type
     variable, or of a tuple of such parts, is a call of a function made for
     that type, as MLton's poly-equal pass makes them: identity first, in a
     wrapper small enough to be put where it is called, then in a worker the
     tags, then each field by its own type -- imm_eq, ptr_eq, string_eq, the
     function of its type, or poly_eq where the type is not known. One
     function for each type (by tyKey), made where `=` is first used at it
     and put before the definition with the copies of specialisation
     (withCopies). Such a comparison is compiled code, which
     --equality-work's limit on the runtime's walk does not stop. Measured
     against B: HOL's kernel work 0.49% and boyer 2.2% fewer machine
     instructions, the compiler compiling itself 0.44% more, in 1% more
     code (docs/plans/performance.md, M5). *)
  val equalities = ref false
  val () = CompilerState.cellRoot ("Simplify.equalities", equalities)
  val eqFuns : var StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("Simplify.eqFuns", eqFuns)
  val pendingEqs : fundef list ref = ref []
  val () = CompilerState.cellRoot ("Simplify.pendingEqs", pendingEqs)

  fun groundTy (t : Ty.ty) : bool =
    case Ty.view t of
      Ty.Con (_, _, ts) => List.all groundTy ts
    | Ty.Tuple ts => List.all groundTy ts
    | _ => false

  (* The constructors of a datatype at the arguments given, each its tag and
     its argument's type. *)
  fun consAt (t : Ty.ty) : (int * Ty.ty option) list option =
    case Ty.view t of
      Ty.Con (stamp, _, args) =>
        (case Ty.datatypeOf stamp of
           SOME {params, cons = cons as _ :: _} =>
             if List.length params <> List.length args then NONE
             else
               let val s = ListPair.foldl (fn (p, a, m) => IntMap.insert (m, p, a)) IntMap.empty (params, args)
               in SOME (List.map (fn (tag, _, arg) => (tag, Option.map (Ty.subst s) arg)) cons) end
         | _ => NONE)
    | _ => NONE

  datatype eqKind = EqPrim of string | EqTrue | EqFun | EqTuple of Ty.ty list

  (* a datatype of a functor's parameter with a constructor whose layout
     the argument gives (--functors=functions, D4), which no function made
     here may take apart *)
  fun openLayout (t : Ty.ty) : bool =
    case Ty.view t of Ty.Con (stamp, _, _) => Ty.isOpen stamp | _ => false

  fun eqKindOf (t : Ty.ty) : eqKind =
    case eqByType (t, []) of
      SOME p => EqPrim p
    | NONE =>
        (case Ty.view t of
           Ty.Tuple [] => EqTrue
         | Ty.Tuple ts => EqTuple ts
         | _ => if groundTy t andalso isSome (consAt t) andalso not (openLayout t) then EqFun else EqPrim "poly_eq")

  fun eqTy t = Ty.arrow (Ty.tuple [t, t], Ty.bool)

  (* the function of `=` at t, made where there is none yet *)
  fun eqFunOf (t : Ty.ty) : var =
    let val key = tyKey t
    in
      case StringMap.find (!eqFuns, key) of
        SOME h => h
      | NONE =>
          let
            val h = freshStamp ()
            val () = eqFuns := StringMap.insert (!eqFuns, key, h)
            val x = freshStamp ()
            val y = freshStamp ()
            val () = Translate.funNames := IntMap.insert (!Translate.funNames, x, "=")
            val cons = case consAt t of SOME cs => cs | NONE => []
            val withArg = List.filter (fn (_, a) => isSome a) cons
            fun arm (tag, arg) =
              let val a = freshStamp () val b = freshStamp () val at = valOf arg
              in
                Let (a, ([], at), Decon (tag, t, Var (x, [])),
                     Let (b, ([], at), Decon (tag, t, Var (y, [])), eqReturn (at, Var (a, []), Var (b, []))))
              end
            (* x's constructor, tested against each of those with an
               argument; the last needs no test where every constructor has
               one, and a nullary one, the same in both, would have been
               the same immediate *)
            fun dispatch [] = Return (Atom (boolAtom false))
              | dispatch [c] = if List.length withArg = List.length cons then arm c else test c (dispatch [])
              | dispatch (c :: rest) = test c (dispatch rest)
            and test (c as (tag, _)) no =
              let val k = freshStamp () val e = freshStamp ()
              in
                Let (k, ([], Ty.int), ConTag (Var (x, [])),
                     Let (e, ([], Ty.bool), Prim ("imm_eq", eqTy Ty.int, [Var (k, []), Const (Lambda.CInt (IntInf.fromInt tag), Ty.int)]),
                          If (Var (e, []), arm c, no)))
              end
            val same = freshStamp ()
            val tx = freshStamp ()
            val ty = freshStamp ()
            val tags = freshStamp ()
            (* a tuple: its fields; a datatype: the tags, then the
               argument of the constructor *)
            val rest =
              case Ty.view t of
                Ty.Tuple ts => fields (ts, 0, Var (x, []), Var (y, []), NONE)
              | _ =>
                  Let (tx, ([], Ty.int), ConTag (Var (x, [])),
                       Let (ty, ([], Ty.int), ConTag (Var (y, [])),
                            Let (tags, ([], Ty.bool), Prim ("imm_eq", eqTy Ty.int, [Var (tx, []), Var (ty, [])]),
                                 If (Var (tags, []), dispatch withArg, Return (Atom (boolAtom false))))))
            (* identity first, in a wrapper small enough to be put where
               it is called; the rest in a worker *)
            val w = freshStamp ()
            val a = freshStamp ()
            val b = freshStamp ()
            val () = Translate.funNames := IntMap.insert (!Translate.funNames, a, "=")
            val wrapper =
              {name = h, tyvars = [], params = [(a, t), (b, t)], result = Ty.bool,
               body = Let (same, ([], Ty.bool), Prim ("ptr_eq", eqTy t, [Var (a, []), Var (b, [])]),
                           If (Var (same, []), Return (Atom (boolAtom true)),
                               Return (App (Global (w, []), [Var (a, []), Var (b, [])]))))}
            val worker = {name = w, tyvars = [], params = [(x, t), (y, t)], result = Ty.bool, body = rest}
          in
            if !inlining then IntTable.insert (!inlinable, h, wrapper) else ();
            pendingEqs := wrapper :: worker :: !pendingEqs;
            h
          end
    end

  (* whether a and b, of type t, are equal, as what is returned *)
  and eqReturn (t : Ty.ty, a : atom, b : atom) : exp =
    case eqKindOf t of
      EqPrim p => Return (Prim (p, eqTy t, [a, b]))
    | EqTrue => Return (Atom (boolAtom true))
    | EqFun => Return (App (Global (eqFunOf t, []), [a, b]))
    | EqTuple ts => fields (ts, 0, a, b, NONE)

  (* whether a and b, of type t, are equal: yes () where they are, else false
     returned *)
  and eqTest (t : Ty.ty, a : atom, b : atom, yes : unit -> exp) : exp =
    let
      fun test r = let val c = freshStamp () in Let (c, ([], Ty.bool), r, If (Var (c, []), yes (), Return (Atom (boolAtom false)))) end
    in
      case eqKindOf t of
        EqPrim p => test (Prim (p, eqTy t, [a, b]))
      | EqTrue => yes ()
      | EqFun => test (App (Global (eqFunOf t, []), [a, b]))
      | EqTuple ts => fields (ts, 0, a, b, SOME yes)
    end

  (* the fields of two tuples from i, each tested in turn: then yes (),
     or, where there is none, the last one's equality returned *)
  and fields (ts : Ty.ty list, i : int, a : atom, b : atom, yes : (unit -> exp) option) : exp =
    case ts of
      [] => (case yes of SOME k => k () | NONE => Return (Atom (boolAtom true)))
    | t :: rest =>
        let
          val fa = freshStamp ()
          val fb = freshStamp ()
          val (va, vb) = (Var (fa, []), Var (fb, []))
        in
          Let (fa, ([], t), Select (i, a),
               Let (fb, ([], t), Select (i, b),
                    case (rest, yes) of
                      ([], NONE) => eqReturn (t, va, vb)
                    | ([], SOME k) => eqTest (t, va, vb, k)
                    | _ => eqTest (t, va, vb, fn () => fields (rest, i + 1, a, b, yes))))
        end

  (* `=` at t, where its type says no more (eqByType): a call of t's
     function, for a datatype or a tuple whose parts are known *)
  fun eqCallable (t : Ty.ty) : bool =
    !equalities andalso
    (case eqKindOf t of
       EqFun => true
     | EqTuple ts => groundTy t andalso List.exists (fn u => case eqKindOf u of EqPrim "poly_eq" => false | _ => true) ts
     | _ => false)

  fun known (env : env, r : rhs) : rhs =
    let
      fun madeOf (Var (x, [])) = IntTable.find (#known env, x)
        | madeOf _ = NONE
    in
      case r of
        Select (i, a) =>
          (case madeOf a of
             SOME (Fields v) => if i < Vector.length v andalso spend () then Atom (Vector.sub (v, i)) else r
           | _ => r)
      | Prim ("poly_eq", pty, xs) =>
          (case Ty.view pty of
             Ty.Arrow (d, _) =>
               (case Ty.view d of
                  Ty.Tuple [t, _] =>
                    (case eqByType (t, xs) of
                       SOME p => if spend () then Prim (p, pty, xs) else r
                     | NONE => if eqCallable t andalso spend () then App (Global (eqFunOf t, []), xs) else r)
                | _ => r)
           | _ => r)
      | Decon (tag, _, a) =>
          (case madeOf a of
             SOME (Made (Con (tag', _, x))) => if tag = tag' andalso spend () then Atom x else r
           | _ => r)
      | ExnCon a =>
          (case madeOf a of
             SOME (Made (MkExn (con, _))) => if spend () then Atom con else r
           | _ => r)
      | ConTag a =>
          (case (a, madeOf a) of
             (Con0 (tag, _), _) => if spend () then Atom (Const (Lambda.CInt (IntInf.fromInt tag), Ty.int)) else r
           | (_, SOME (Made (Con (tag, _, _)))) =>
               if spend () then Atom (Const (Lambda.CInt (IntInf.fromInt tag), Ty.int)) else r
           | _ => r)
      | Prim (p, t, xs) =>
          (case fold (p, t, xs) of
             SOME a => if spend () then Atom a else r
           | NONE => r)
      | _ => r
    end

  (* e with f applied to every atom, and ty to every type it says. *)
  fun mapExp (f : atom -> atom, ty : Ty.ty -> Ty.ty) (e : exp) : exp =
    let
      fun rhs r =
        case r of
          Atom a => Atom (f a)
        | App (g, xs) => App (f g, List.map f xs)
        | Prim (p, t, xs) => Prim (p, ty t, List.map f xs)
        | Tuple xs => Tuple (List.map f xs)
        | Select (i, a) => Select (i, f a)
        | Con (tag, t, a) => Con (tag, ty t, f a)
        | Decon (tag, t, a) => Decon (tag, ty t, f a)
        | ConTag a => ConTag (f a)
        | MkExn (c, a) => MkExn (f c, f a)
        | ExnCon a => ExnCon (f a)
        | ExnArg (t, a) => ExnArg (ty t, f a)
        | SetGlobal (g, a) => SetGlobal (g, f a)
        | _ => r
      fun fundef ({name, tyvars, params, result, body} : fundef) =
        {name = name, tyvars = tyvars, params = List.map (fn (x, t) => (x, ty t)) params, result = ty result,
         body = exp body}
      and exp e =
        case e of
          Let (x, (tvs, t), r, b) => Let (x, (tvs, ty t), rhs r, exp b)
        | Fun (fs, b) => Fun (List.map fundef fs, exp b)
        | Join (j, ps, body, sc) => Join (j, List.map (fn (x, t) => (x, ty t)) ps, exp body, exp sc)
        | Jump (j, xs) => Jump (j, List.map f xs)
        | If (c, t, e) => If (f c, exp t, exp e)
        | Handle (a, x, h) => Handle (exp a, x, exp h)
        | Raise a => Raise (f a)
        | Return r => Return (rhs r)
        | Mark (sp, a) => Mark (sp, exp a)
    in exp e end

  (* e with f applied to every step, in the functions made in it too. *)
  fun mapRhs (f : rhs -> rhs) (e : exp) : exp =
    let
      fun go e =
        case e of
          Let (x, s, r, b) => Let (x, s, f r, go b)
        | Fun (fs, b) =>
            Fun (List.map (fn {name, tyvars, params, result, body} =>
                             {name = name, tyvars = tyvars, params = params, result = result, body = go body}) fs,
                 go b)
        | Join (j, ps, jb, sc) => Join (j, ps, go jb, go sc)
        | If (a, t, e) => If (a, go t, go e)
        | Handle (a, x, h) => Handle (go a, x, go h)
        | Return r => Return (f r)
        | Mark (sp, a) => Mark (sp, go a)
        | _ => e
    in go e end

  (* The body of a function called once where it is made, in place of the
     call, is at the types of the call: its type variables are those types. *)
  fun substTypes (s : Ty.ty IntMap.map) (e : exp) : exp =
    if IntMap.isEmpty s then e
    else
      let
        val ty = Ty.subst s
        fun atom a =
          case a of
            Var (x, ts) => Var (x, List.map ty ts)
          | Global (g, ts) => Global (g, List.map ty ts)
          | Const (c, t) => Const (c, ty t)
          | Con0 (tag, t) => Con0 (tag, ty t)
          | Unit => Unit
      in mapExp (atom, ty) e end

  (* e with the variable x, which abstracts over no type, replaced by b. *)
  fun substVar (x : var, b : atom) (e : exp) : exp =
    mapExp (fn a as Var (y, []) => if y = x then b else a | a => a, fn t => t) e

  (* ---- inlining (M10) ---- *)

  (* e with every binder in it bound afresh, and its uses renamed to match:
     a copy that can stand beside the original. A function copied keeps its
     name for traces (Translate.funNames, by its first parameter). *)
  fun copy (e : exp) : exp = copyWith (IntMap.empty, e)

  (* A copy in which the variables free in e that s0 names are renamed too:
     the parameters of a function whose body is copied, renamed on the same
     walk. *)
  and copyWith (s0 : var IntMap.map, e : exp) : exp =
    let
      (* the new name of each binder: one table for the whole copy, since
         stamps are unique and so no name is bound twice in it *)
      val t : var IntTable.table = IntTable.table 64
      val () = IntMap.appi (fn (x, y) => IntTable.insert (t, x, y)) s0
      fun fresh x = let val y = freshStamp () in IntTable.insert (t, x, y); y end
      fun name x = case IntTable.find (t, x) of SOME y => y | NONE => x
      fun atom a = case a of Var (x, ts) => Var (name x, ts) | _ => a
      fun rhs r =
        case r of
          Atom a => Atom (atom a)
        | App (f, xs) => App (atom f, List.map atom xs)
        | Prim (p, ty, xs) => Prim (p, ty, List.map atom xs)
        | Tuple xs => Tuple (List.map atom xs)
        | Select (i, a) => Select (i, atom a)
        | Con (tag, ty, a) => Con (tag, ty, atom a)
        | Decon (tag, ty, a) => Decon (tag, ty, atom a)
        | ConTag a => ConTag (atom a)
        | MkExn (c, a) => MkExn (atom c, atom a)
        | ExnCon a => ExnCon (atom a)
        | ExnArg (ty, a) => ExnArg (ty, atom a)
        | SetGlobal (g, a) => SetGlobal (g, atom a)
        | _ => r
      fun params ps = List.map (fn (x, ty) => (fresh x, ty)) ps
      fun exp e =
        case e of
          Let (x, sc, r, b) => let val r = rhs r val y = fresh x in Let (y, sc, r, exp b) end
        | Fun (fs, b) =>
            let
              val () = List.app (fn f => ignore (fresh (#name f))) fs
              fun fundef ({name = f, tyvars, params = ps, result, body} : fundef) =
                let
                  val ps' = params ps
                in
                  case (ps, ps') of
                    ((x, _) :: _, (y, _) :: _) =>
                      (case IntMap.find (!Translate.funNames, x) of
                         SOME n => Translate.funNames := IntMap.insert (!Translate.funNames, y, n)
                       | NONE => ())
                  | _ => ();
                  {name = name f, tyvars = tyvars, params = ps', result = result, body = exp body}
                end
            in Fun (List.map fundef fs, exp b) end
        | Join (j, ps, body, sc) =>
            let val j' = fresh j val ps' = params ps
            in Join (j', ps', exp body, exp sc) end
        | Jump (j, xs) => Jump (name j, List.map atom xs)
        | If (c, th, el) => If (atom c, exp th, exp el)
        | Handle (a, x, h) => let val y = fresh x in Handle (exp a, y, exp h) end
        | Raise a => Raise (atom a)
        | Return r => Return (rhs r)
        | Mark (p, a) => Mark (p, exp a)
    in exp e end

  (* e's positions with a frame more, outermost -- the function e's code
     comes from, called from where the frames are -- in the code that runs
     in the activation e is put into: not in a function made there. *)
  fun inlinedFrom (frame : frame, outer : frame list) (e : exp) : exp =
    let
      fun go e =
        case e of
          Let (x, s, r, b) => Let (x, s, r, go b)
        | Fun (fs, b) => Fun (fs, go b)
        | Join (j, ps, body, sc) => Join (j, ps, go body, go sc)
        | If (c, t, f) => If (c, go t, go f)
        | Handle (a, x, h) => Handle (go a, x, go h)
        | Mark ((sp, frames), a) => Mark ((sp, frames @ frame :: outer), go a)
        | _ => e
    in go e end

  (* The calls in tail position of e, outside its handlers' regions, at the
     position p: where e is the code of a function put where it was called
     other than in tail position, such a call would have taken the place of
     that function's frame, and so shows as made from where it was called. *)
  fun markTailCalls (p : pos) (e : exp) : exp =
    let
      fun go e =
        case e of
          Let (x, s, r, b) => Let (x, s, r, go b)
        | Fun (fs, b) => Fun (fs, go b)
        | Join (j, ps, jb, sc) => Join (j, ps, go jb, go sc)
        | If (c, t, f) => If (c, go t, go f)
        | Handle (a, x, h) => Handle (a, x, go h)
        | Return (r as App _) => Mark (p, Return r)
        | Mark (sp, a) => Mark (sp, go a)
        | _ => e
    in go e end

  (* The code of the function called name, put where it was called, at p: a
     frame of it in its positions, where the call was -- none where it was
     a tail call (tail, and not in a handler's region), which takes the
     place of the caller's frame -- so that a trace shows what it would have
     shown, had the call been made. *)
  fun framed (name : string, p as (sp, outer) : pos, region : bool, tail : bool) (e : exp) : exp =
    if tail andalso not region then inlinedFrom ({name = name, site = NONE}, outer) e
    else markTailCalls p (inlinedFrom ({name = name, site = SOME sp}, outer) e)

  (* The nodes of an expression, for the inliner's sizes and budget. *)
  fun size (e : exp) : int =
    case e of
      Let (_, _, _, b) => 1 + size b
    | Fun (fs, b) => List.foldl (fn (f, n) => n + size (#body f)) (1 + size b) fs
    | Join (_, _, b, s) => 1 + size b + size s
    | If (_, t, f) => 1 + size t + size f
    | Handle (a, _, h) => 1 + size a + size h
    | Mark (_, a) => size a
    | _ => 1

  (* Whether e has no more than n nodes, found without counting them all. *)
  fun sizeAtMost (e : exp, n : int) : bool =
    let
      exception Over
      fun go (e, k) =
        if k > n then raise Over
        else
          case e of
            Let (_, _, _, b) => go (b, k + 1)
          | Fun (fs, b) => List.foldl (fn (f, k) => go (#body f, k)) (go (b, k + 1)) fs
          | Join (_, _, b, s) => go (s, go (b, k + 1))
          | If (_, t, f) => go (f, go (t, k + 1))
          | Handle (a, _, h) => go (h, go (a, k + 1))
          | Mark (_, a) => go (a, k)
          | _ => k + 1
    in go (e, 0) <= n handle Over => false end

  (* The functions of the top level small enough to put where they are
     called, by name: of no more than inlineSize nodes, and calling
     themselves nowhere. What a definition may grow by is its budget; where
     it is spent, no more is inlined in it. The functions of the top level
     named once, by a call, are put there whatever their size, which grows
     nothing: the budget grows by it, and the function goes from once, so
     that it is put in one place only (a copy of the call, made before,
     stays a call; what is left of the function Shake removes). The
     position a call is at is here. *)
  val inlineSize = 12
  (* A function that makes functions and returns them, alone or in a
     tuple -- a record of closures made at each call, as MLton's peek's
     addPeek makes them -- may be twice as big: put where it is called, the
     functions it makes are known there, to be called, inlined or given to
     copies (performance M8). *)
  fun inlineLimit (f : fundef) : int =
    let fun isFun t = case Ty.view t of Ty.Arrow _ => true | _ => false
    in
      case Ty.view (#result f) of
        Ty.Tuple ts => if List.exists isFun ts then 2 * inlineSize else inlineSize
      | _ => if isFun (#result f) then 2 * inlineSize else inlineSize
    end
  val knownConSize = 16
  (* Whether e always raises: a call of a function that does is on the way
     to an error, where what the call costs does not matter, so it is not
     inlined. *)
  fun raises (e : exp) : bool =
    case e of
      Let (_, _, _, b) => raises b
    | Fun (_, b) => raises b
    | Join (_, _, body, s) => raises body andalso raises s
    | If (_, t, f) => raises t andalso raises f
    | Handle (a, _, h) => raises a andalso raises h
    | Raise _ => true
    | Mark (_, a) => raises a
    | _ => false

  val once : fundef option IntTable.table ref = ref (IntTable.table 16)     (* NONE: put in place already *)
  val () = CompilerState.refRoot ("Simplify.once", once, IntTable.copy)
  fun onceOf g = case IntTable.find (!once, g) of SOME (SOME f) => SOME f | _ => NONE
  val budget = ref 0
  val () = CompilerState.cellRoot ("Simplify.budget", budget)
  val here : pos ref = ref (Source.noSpan, [])
  val () = CompilerState.cellRoot ("Simplify.here", here)
  (* how many handlers' regions of its function the code being simplified
     is in: a call in tail position there is no tail call *)
  val inHandler = ref 0
  val () = CompilerState.cellRoot ("Simplify.inHandler", inHandler)

  fun nameOf (f : fundef) : string =
    case #params f of
      (x, _) :: _ => (case IntMap.find (!Translate.funNames, x) of SOME n => n | NONE => "fn")
    | [] => "fn"

  (* A call of g at ts with args, which may be inlined: g's body, copied,
     its type variables those types, its parameters bound to the
     arguments, and its positions in a frame of g, called from here; k is
     given each result of it (a return). *)
  fun inlined (g : var, ts : Ty.ty list, args : atom list, k : (rhs -> exp) option) : exp option =
    case (onceOf g, IntTable.find (!inlinable, g)) of
      (NONE, NONE) => NONE
    | (onceF, smallF) =>
        let
          val f as {tyvars, params, body, ...} = case onceF of SOME f => f | NONE => valOf smallF
          val n = size body
        in
          if List.length params <> List.length args orelse List.length tyvars <> List.length ts
             orelse (not (isSome onceF) andalso !budget < n) orelse not (spend ())
          then NONE
          else
            let
              val () =
                if isSome onceF then (IntTable.insert (!once, g, NONE); budget := !budget + n)
                else budget := !budget - n
              val inst = ListPair.foldl (fn (a, t, s) => IntMap.insert (s, a, t)) IntMap.empty (tyvars, ts)
              (* the parameters, renamed like the rest of the copy *)
              val ps = List.map (fn (x, t) => (x, freshStamp (), Ty.subst inst t)) params
              val renamed = List.foldl (fn ((x, y, _), m) => IntMap.insert (m, x, y)) IntMap.empty ps
              val body = framed (nameOf f, !here, !inHandler > 0, not (isSome k)) (copyWith (renamed, substTypes inst body))
              val body = ListPair.foldr (fn ((_, y, t), a, e) => Let (y, ([], t), Atom a, e)) (retarget (k, body)) (ps, args)
            in SOME body end
        end

  (* body's results given to k, where there is one *)
  and retarget (k, body) =
    case k of
      NONE => body
    | SOME k =>
        let
          fun go e =
            case e of
              Let (x, s, r, b) => Let (x, s, r, go b)
            | Fun (fs, b) => Fun (fs, go b)
            | Join (j, ps, jb, s) => Join (j, ps, go jb, go s)
            | If (a, t, e) => If (a, go t, go e)
            | Handle (a, x, h) => Handle (go a, x, go h)
            | Return r => k r
            | Mark (sp, a) => Mark (sp, go a)
            | _ => e
        in go body end

  (* ---- specialisation (M10) ---- *)

  (* A function of the top level that calls itself, each time with some of
     its parameters of function type passed on as they are (static), is
     copied for a call that gives those functions of the top level: in the
     copy they are known, so the calls of them are known calls, and small
     ones are inlined -- List.map of a known function is a loop that calls
     it directly (item 6 of performance.md). Only at types with no type
     variable of a scheme, so that the copy is of none; one copy for each
     function, types and functions given, which a call made later uses too.
     The copies are simplified after the definition whose calls made them,
     and put before it. A function that does not call itself is copied too,
     but only from a copy, given the local functions the copy was given
     (performance M8: the loop of MLton's peek calls a function with the
     closures it is given, whose results that function takes apart); from
     elsewhere, copies of every small function of functions grew the
     compiler by 4% and made it slower. *)
  val specialisable : (fundef * int list * bool) IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Simplify.specialisable", specialisable, IntTable.copy)
  val globalFuns : unit IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Simplify.globalFuns", globalFuns, IntTable.copy)
  val copies : var StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("Simplify.copies", copies)
  val pendingCopies : fundef list ref = ref []
  val () = CompilerState.cellRoot ("Simplify.pendingCopies", pendingCopies)
  val specialiseSize = 64

  (* The places of f's static parameters of function type: none where f
     does not call itself. *)
  fun staticParams (f : fundef) : int list =
    let
      val n = List.length (#params f)
      val ps = Vector.fromList (#params f)
      val static = Array.tabulate (n, fn i => case Ty.view (#2 (Vector.sub (ps, i))) of Ty.Arrow _ => true | _ => false)
      val self = ref false
      fun given (_, []) = ()
        | given (i, a :: rest) =
            ((case a of
                Var (x, []) => if x = #1 (Vector.sub (ps, i)) then () else Array.update (static, i, false)
              | _ => Array.update (static, i, false));
             given (i + 1, rest))
      fun rhs r =
        case r of
          App (Global (g, _), args) =>
            if g <> #name f then ()
            else
              (self := true;
               if List.length args <> n then Array.modify (fn _ => false) static else given (0, args))
        | _ => ()
      fun exp e =
        case e of
          Let (_, _, r, b) => (rhs r; exp b)
        | Fun (fs, b) => (List.app (fn g => exp (#body g)) fs; exp b)
        | Join (_, _, b, sc) => (exp b; exp sc)
        | If (_, t, f) => (exp t; exp f)
        | Handle (a, _, h) => (exp a; exp h)
        | Return r => rhs r
        | Mark (_, a) => exp a
        | _ => ()
      val () = exp (#body f)
    in
      List.filter (fn i => Array.sub (static, i)) (List.tabulate (n, fn i => i))
    end

  (* whether a type names no generic variable *)
  fun closedTy (t : Ty.ty) : bool = List.null (Ty.gens t)

  (* What a static parameter is given in a copy: a function of the top
     level, or a local function (performance M8, D8 A, step 5) -- its code
     made a function of the top level of what it captured and its
     parameter, those it captured the copy's parameters after its own. *)
  datatype fix = FixAtom of atom | FixClosure of var * (var * Ty.ty) list * Ty.ty list option

  fun dropFixed (fixed : (int * 'b) list, xs : 'a list) : 'a list =
    List.mapPartial (fn (i, x) => if List.exists (fn (j, _) => j = i) fixed then NONE else SOME x)
                    (ListPair.zip (List.tabulate (List.length xs, fn i => i), xs))

  (* the local functions alone in their groups, of one parameter and no
     type variables, that do not name themselves, by name, as simplified
     (keepFun); the scheme of each variable bound, as simp meets its binder;
     and each local function made a function of the top level for a copy,
     by its name, with what it captured *)
  val localFuns : fundef IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Simplify.localFuns", localFuns, IntTable.copy)
  val liftedFuns : (var * Ty.ty list option) IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Simplify.liftedFuns", liftedFuns, IntTable.copy)
  (* the types of the variables bound in the expression a round simplifies,
     and the parameters of its function, worked out where a local function
     given asks for them, once a round *)
  val roundInput : exp ref = ref (Return (Atom Unit))
  val () = CompilerState.cellRoot ("Simplify.roundInput", roundInput)
  val roundParams : (var * Ty.ty) list ref = ref []
  val () = CompilerState.cellRoot ("Simplify.roundParams", roundParams)
  val roundTypes : scheme IntTable.table option ref = ref NONE
  val () = CompilerState.refRoot ("Simplify.roundTypes", roundTypes, Option.map IntTable.copy)
  fun typeOf (x : var) : scheme option =
    let
      val t =
        case !roundTypes of
          SOME t => t
        | NONE =>
            let
              val t = IntTable.table 256
              fun bind (y, s) = IntTable.insert (t, y, s)
              fun exp e =
                case e of
                  Let (y, s, _, b) => (bind (y, s); exp b)
                | Fun (fs, b) => (List.app (fn f => (bind (#name f, (#tyvars f, funTy f));
                                                     List.app (fn (y, u) => bind (y, ([], u))) (#params f);
                                                     exp (#body f))) fs;
                                  exp b)
                | Join (_, ps, jb, sc) => (List.app (fn (y, u) => bind (y, ([], u))) ps; exp jb; exp sc)
                | If (_, a, b) => (exp a; exp b)
                | Handle (a, y, h) => (exp a; bind (y, ([], Ty.exn)); exp h)
                | Mark (_, a) => exp a
                | _ => ()
            in
              List.app (fn (y, u) => bind (y, ([], u))) (!roundParams); exp (!roundInput); roundTypes := SOME t; t
            end
    in IntTable.find (t, x) end
  (* how many copies and lifted functions deep the function being simplified
     is, of those made for local functions given: a copy whose body gives a
     local function of its own to another copy would go on for ever, where
     two functions give each other new ones *)
  val closureDepth : int IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Simplify.closureDepth", closureDepth, IntTable.copy)
  (* the local functions a copy made of a local function it gives on
     (makeCopy), which a copy for them is made for whatever the budget *)
  val wrapperFuns : unit IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Simplify.wrapperFuns", wrapperFuns, IntTable.copy)
  val currentDepth = ref 0
  val () = CompilerState.cellRoot ("Simplify.currentDepth", currentDepth)
  val maxClosureDepth = 2
  (* The variables free in f, by stamp: f's own name among them where it
     calls itself. *)
  fun freeVars (f : fundef) : var list =
    let
      val bound : unit IntTable.table = IntTable.table 32
      val free : unit IntMap.map ref = ref IntMap.empty
      fun bind x = IntTable.insert (bound, x, ())
      fun atom a = case a of Var (x, _) => if isSome (IntTable.find (bound, x)) then () else free := IntMap.insert (!free, x, ()) | _ => ()
      fun rhs r =
        case r of
          Atom a => atom a
        | App (g, xs) => List.app atom (g :: xs)
        | Prim (_, _, xs) => List.app atom xs
        | Tuple xs => List.app atom xs
        | Select (_, a) => atom a
        | Con (_, _, a) => atom a
        | Decon (_, _, a) => atom a
        | ConTag a => atom a
        | MkExn (c, a) => (atom c; atom a)
        | ExnCon a => atom a
        | ExnArg (_, a) => atom a
        | SetGlobal (_, a) => atom a
        | _ => ()
      fun exp e =
        case e of
          Let (x, _, r, b) => (rhs r; bind x; exp b)
        | Fun (fs, b) => (List.app (fn g => bind (#name g)) fs;
                          List.app (fn g => (List.app (fn (x, _) => bind x) (#params g); exp (#body g))) fs; exp b)
        | Join (_, ps, jb, sc) => (List.app (fn (x, _) => bind x) ps; exp jb; exp sc)
        | Jump (_, xs) => List.app atom xs
        | If (a, t, e) => (atom a; exp t; exp e)
        | Handle (a, x, h) => (exp a; bind x; exp h)
        | Raise a => atom a
        | Return r => rhs r
        | Mark (_, a) => exp a
    in
      List.app (fn (x, _) => bind x) (#params f); exp (#body f);
      IntMap.listKeys (!free)
    end

  (* Whether the parameter p, at place i of h's, is only called in e, or
     given to h's calls of itself at its place, or to a function that may
     be specialised on it in turn, at a static place of its, where a copy of
     that function may be made from the copy. *)
  fun onlyCalled (p : var, i : int, h : var, e : exp) : bool = calledOrPassed (true, p, i, h, e)
  (* where pass, the function given it may be copied for it in turn, and
     only calls it there: a copy that gives it on is then sure to be given
     a copy, and never makes a closure the call did not (makeCopy) *)
  and calledOrPassed (pass : bool, p : var, i : int, h : var, e : exp) : bool =
    let
      fun no a = case a of Var (x, _) => x <> p | _ => true
      val deeper = pass andalso !currentDepth + 1 < maxClosureDepth
      fun passed (g, k) =
        deeper andalso (case IntTable.find (!specialisable, g) of
                          SOME (gf, is, _) =>
                            List.exists (fn j => j = k) is
                            (* a copy keeps a parameter: one of all of them
                               fixed is not made *)
                            andalso List.length is < List.length (#params gf)
                            andalso calledOrPassed (false, #1 (List.nth (#params gf, k)), k, g, #body gf)
                        | NONE => false)
      fun indexed xs = ListPair.zip (List.tabulate (List.length xs, fn k => k), xs)
      fun rhs r =
        case r of
          App (Var (x, _), xs) => (x = p orelse true) andalso List.all no xs
        | App (Global (g, _), xs) =>
            if g = h then List.all (fn (k, a) => k = i orelse no a) (indexed xs)
            else List.all (fn (k, a) => no a orelse passed (g, k)) (indexed xs)
        | App (g, xs) => List.all no (g :: xs)
        | Atom a => no a
        | Prim (_, _, xs) => List.all no xs
        | Tuple xs => List.all no xs
        | Select (_, a) => no a
        | Con (_, _, a) => no a
        | Decon (_, _, a) => no a
        | ConTag a => no a
        | MkExn (c, a) => no c andalso no a
        | ExnCon a => no a
        | ExnArg (_, a) => no a
        | SetGlobal (_, a) => no a
        | _ => true
      fun exp e =
        case e of
          Let (_, _, r, b) => rhs r andalso exp b
        | Fun (fs, b) => List.all (fn g => exp (#body g)) fs andalso exp b
        | Join (_, _, jb, sc) => exp jb andalso exp sc
        | Jump (_, xs) => List.all no xs
        | If (a, t, e) => no a andalso exp t andalso exp e
        | Handle (a, _, h) => exp a andalso exp h
        | Raise a => no a
        | Return r => rhs r
        | Mark (_, a) => exp a
    in exp e end

  (* Whether every use of x in e takes a field of it. *)
  fun selectedOnly (x : var, e : exp) : bool =
    let
      fun no a = case a of Var (y, _) => y <> x | _ => true
      fun rhs r =
        case r of
          Select (_, Var _) => true
        | Atom a => no a
        | App (g, xs) => List.all no (g :: xs)
        | Prim (_, _, xs) => List.all no xs
        | Tuple xs => List.all no xs
        | Select (_, a) => no a
        | Con (_, _, a) => no a
        | Decon (_, _, a) => no a
        | ConTag a => no a
        | MkExn (c, a) => no c andalso no a
        | ExnCon a => no a
        | ExnArg (_, a) => no a
        | SetGlobal (_, a) => no a
        | _ => true
      fun exp e =
        case e of
          Let (_, _, r, b) => rhs r andalso exp b
        | Fun (fs, b) => List.all (fn g => exp (#body g)) fs andalso exp b
        | Join (_, _, jb, sc) => exp jb andalso exp sc
        | Jump (_, xs) => List.all no xs
        | If (a, t, e) => no a andalso exp t andalso exp e
        | Handle (a, _, h) => exp a andalso exp h
        | Raise a => no a
        | Return r => rhs r
        | Mark (_, a) => exp a
    in exp e end

  (* The local function f made a function of the top level (once): what it
     captured, then its parameter -- or, where that is a tuple it only takes
     apart, its fields, which a call then gives (the fields' types). *)
  fun liftedOf (f as {name, params, result, body, ...} : fundef, caps : (var * Ty.ty) list) : var * Ty.ty list option =
    case IntTable.find (!liftedFuns, name) of
      SOME l => l
    | NONE =>
        let
          val g = freshStamp ()
          val caps' = List.map (fn (x, t) => (x, freshStamp (), t)) caps
          val flat =
            case params of
              [(p, t)] =>
                (case Ty.view t of
                   Ty.Tuple (ts as _ :: _ :: _) => if selectedOnly (p, body) then SOME (p, ts) else NONE
                 | _ => NONE)
            | _ => NONE
          val ps' =
            case flat of
              SOME (_, ts) => List.map (fn t => (~1, freshStamp (), t)) ts
            | NONE => List.map (fn (x, t) => (x, freshStamp (), t)) params
          val s0 = List.foldl (fn ((x, y, _), m) => if x < 0 then m else IntMap.insert (m, x, y)) IntMap.empty (caps' @ ps')
          val params' = List.map (fn (_, y, t) => (y, t)) (caps' @ ps')
          val () = case params' of
                     (y, _) :: _ => Translate.funNames := IntMap.insert (!Translate.funNames, y, nameOf f)
                   | [] => ()
          val body' = copyWith (s0, body)
          val body' =
            case flat of
              SOME (p, _) =>
                mapRhs (fn r as Select (i, Var (y, _)) => if y = p then Atom (Var (#2 (List.nth (ps', i)), [])) else r
                         | r => r) body'
            | NONE => body'
          val f' = {name = g, tyvars = [], params = params', result = result, body = body'}
          val l = (g, Option.map #2 flat)
        in
          IntTable.insert (!liftedFuns, name, l);
          IntTable.insert (!closureDepth, g, !currentDepth + 1);
          (* given to a copy as it is, where it captured nothing *)
          IntTable.insert (!globalFuns, g, ());
          pendingCopies := f' :: !pendingCopies;
          l
        end

  (* f's copy named h', at the types ts, with the static parameters fixed
     given those atoms, and its calls of itself calls of the copy. *)
  fun makeCopy (f as {name, tyvars, params, result, body} : fundef, h' : var, ts : Ty.ty list,
                fixed : (int * fix) list) : fundef =
    let
      val inst = ListPair.foldl (fn (a, t, s) => IntMap.insert (s, a, t)) IntMap.empty (tyvars, ts)
      val kept = List.map (fn (x, t) => (x, freshStamp (), Ty.subst inst t)) (dropFixed (fixed, params))
      (* what each local function given captured, the copy's parameters
         after its own *)
      val extra =
        List.map (fn (i, FixClosure (g, caps, flat)) => (i, g, List.map (fn (_, t) => (freshStamp (), t)) caps, flat)
                   | (i, FixAtom _) => (i, ~1, [], NONE)) fixed
      val extraParams = List.concat (List.map #3 extra)
      val extraArgs = List.map (fn (y, _) => Var (y, [])) extraParams
      val renamed = List.foldl (fn ((x, y, _), m) => IntMap.insert (m, x, y)) IntMap.empty kept
      val body = copyWith (renamed, substTypes inst body)
      val body = List.foldl (fn ((i, FixAtom a), e) => substVar (#1 (List.nth (params, i)), a) e | (_, e) => e) body fixed
      (* a call of a local function given: of the function of the top level
         made of it, given what it captured *)
      fun closureOf p =
        List.find (fn (i, g, _, _) => g >= 0 andalso #1 (List.nth (params, i)) = p) extra
      (* a call of a local function given, and the steps that take apart
         its argument, where its function takes the fields *)
      fun call (r, k : rhs -> exp) =
        case r of
          App (Global (g, _), args) => k (if g = name then App (Global (h', []), dropFixed (fixed, args) @ extraArgs) else r)
        | App (Var (p, _), args) =>
            (case closureOf p of
               SOME (_, g, ys, NONE) => k (App (Global (g, []), List.map (fn (y, _) => Var (y, [])) ys @ args))
             | SOME (_, g, ys, SOME ts) =>
                 let
                   val a = hd args
                   val zs = List.map (fn t => (freshStamp (), t)) ts
                   val call = App (Global (g, []), List.map (fn (y, _) => Var (y, [])) ys @ List.map (fn (z, _) => Var (z, [])) zs)
                 in
                   #2 (List.foldr (fn ((z, t), (i, e)) => (i - 1, Let (z, ([], t), Select (i, a), e)))
                                  (List.length zs - 1, k call) zs)
                 end
             | NONE => k r)
        | _ => k r
      fun exp e =
        case e of
          Let (x, sc, r, b) => call (r, fn r' => Let (x, sc, r', exp b))
        | Fun (fs, b) =>
            Fun (List.map (fn {name, tyvars, params, result, body} =>
                             {name = name, tyvars = tyvars, params = params, result = result, body = exp body}) fs,
                 exp b)
        | Join (j, ps, jb, sc) => Join (j, ps, exp jb, exp sc)
        | If (a, t, e) => If (a, exp t, exp e)
        | Handle (a, x, h) => Handle (exp a, x, exp h)
        | Return r => call (r, Return)
        | Mark (sp, a) => Mark (sp, exp a)
        | _ => e
      (* a local function given that the copy gives on, to a function
         that may be specialised on it in turn (onlyCalled): a local
         function again, which calls the function of the top level made of
         the one given -- where nothing gives it on, it goes *)
      val wrappers =
        List.mapPartial (fn (i, g, _, _) =>
                           if g < 0 then NONE
                           else
                             let val (p, t) = List.nth (params, i)
                             in
                               case Ty.view (Ty.subst inst t) of
                                 Ty.Arrow (a, b) =>
                                   let val z = freshStamp () val w = freshStamp ()
                                   in
                                     IntTable.insert (!wrapperFuns, w, ());
                                     SOME (p, {name = w, tyvars = [], params = [(z, a)], result = b,
                                               body = call (App (Var (p, []), [Var (z, [])]), Return)})
                                   end
                               | _ => NONE
                             end) extra
      (* named as f, for traces *)
      val () =
        case kept of
          (_, y, _) :: _ => Translate.funNames := IntMap.insert (!Translate.funNames, y, nameOf f)
        | [] => ()
    in
      {name = h', tyvars = [], params = List.map (fn (_, y, t) => (y, t)) kept @ extraParams, result = Ty.subst inst result,
       body = List.foldl (fn ((p, w), e) => Fun ([w], substVar (p, Var (#name w, [])) e)) (exp body) wrappers}
    end

  (* A call of a function that may be specialised, where it gives functions
     of the top level for some of the static parameters: a call of the copy
     for those. *)
  fun specialised (r : rhs) : rhs =
    case r of
      App (Global (h, ts), args) =>
        (case IntTable.find (!specialisable, h) of
           NONE => r
         | SOME (_, _, false) => if !currentDepth = 0 then r else specialisedOn r
         | SOME _ => specialisedOn r)
    | _ => r
  and specialisedOn (r : rhs) : rhs =
    case r of
      App (Global (h, ts), args) =>
        (case IntTable.find (!specialisable, h) of
           NONE => r
         | SOME (f, is, _) =>
             let
               (* a local function given: one alone in its group, of
                  closed types, which captures only variables of closed
                  types, where the copy only calls it *)
               fun closure (i, g) =
                 case (if !currentDepth < maxClosureDepth then IntTable.find (!localFuns, g) else NONE) of
                   NONE => NONE
                 | SOME lf =>
                     let
                       val fvs = freeVars lf
                       val caps = List.map (fn x => (x, typeOf x)) fvs
                     in
                       if not (List.exists (fn x => x = g) fvs)
                          andalso List.all (fn (_, SOME ([], t)) => closedTy t | _ => false) caps
                          andalso closedTy (funTy lf)
                          andalso onlyCalled (#1 (List.nth (#params f, i)), i, h, #body f)
                       then SOME (lf, List.map (fn (x, SOME (_, t)) => (x, t) | (x, NONE) => (x, Ty.unit)) caps)
                       else NONE
                     end
               val fixed =
                 List.mapPartial (fn i => case List.nth (args, i) of
                                            a as Global (g, ts') =>
                                              if isSome (IntTable.find (!globalFuns, g)) andalso List.all closedTy ts'
                                              then SOME (i, a, NONE) else NONE
                                          | a as Var (g, []) =>
                                              (case closure (i, g) of
                                                 SOME c => SOME (i, a, SOME c)
                                               | NONE => NONE)
                                          | _ => NONE) is
             in
               if null fixed orelse List.length args <> List.length (#params f)
                  orelse List.length fixed = List.length args orelse not (List.all closedTy ts) orelse not (spend ())
               then r
               else
                 let
                   fun given (i, Global (g, ts'), _) =
                         Int.toString i ^ ":" ^ Int.toString g ^ "[" ^ String.concatWith "," (List.map tyKey ts') ^ "]"
                     | given (i, Var (g, _), _) = Int.toString i ^ ":L" ^ Int.toString g
                     | given _ = ""
                   val key = String.concatWith ";" (Int.toString h :: List.map tyKey ts @ List.map given fixed)
                   fun fixes () =
                     List.map (fn (i, a, NONE) => (i, FixAtom a)
                                | (i, _, SOME (lf, caps)) =>
                                    let val (g, flat) = liftedOf (lf, caps) in (i, FixClosure (g, caps, flat)) end) fixed
                   val capArgs =
                     List.concat (List.map (fn (_, _, SOME (_, caps)) => List.map (fn (x, _) => Var (x, [])) caps
                                             | _ => []) fixed)
                   val closures = List.exists (fn (_, _, c) => isSome c) fixed
                   val h' =
                     case StringMap.find (!copies, key) of
                       SOME h' => SOME h'
                     | NONE =>
                         (* a copy for local functions grows the definition,
                            as inlining does: within its budget *)
                         if closures andalso !budget < size (#body f)
                            andalso not (List.all (fn (_, _, SOME (lf, _)) => isSome (IntTable.find (!wrapperFuns, #name lf))
                                                    | _ => true) fixed)
                         then NONE
                         else
                           let val h' = freshStamp ()
                           in
                             if closures
                             then (IntTable.insert (!closureDepth, h', !currentDepth + 1); budget := !budget - size (#body f))
                             else ();
                             copies := StringMap.insert (!copies, key, h');
                             pendingCopies := makeCopy (f, h', ts, fixes ()) :: !pendingCopies;
                             SOME h'
                           end
                 in
                   case h' of
                     SOME h' => App (Global (h', []), dropFixed (List.map (fn (i, _, c) => (i, c)) fixed, args) @ capArgs)
                   | NONE => r
                 end
             end)
    | _ => r

  (* The function a call calls, where it may be put in the call's place: one
     of the top level, or a local one registered as small (keepFun). *)
  fun calleeOf (f : atom) : (var * Ty.ty list) option =
    case f of
      Global (g, ts) => SOME (g, ts)
    | Var (g, ts) => if isSome (IntTable.find (!inlinable, g)) then SOME (g, ts) else NONE
    | _ => NONE

  (* A round: e simplified in env, with the census taken before. *)
  fun simp (c : census, env : env, e : exp) : exp =
    case e of
      Let (x, s as (tvs, t), r, body) =>
        let val r = specialised (known (env, substRhs (env, r)))
        in
          case (r, tvs) of
            (App (f, args), []) =>
              (case calleeOf f of
                 SOME (g, ts) =>
                   (* a call of a small function: its body, whose results go
                      to a join point for what follows, which is where the
                      call was *)
                   let
                     val j = freshStamp ()
                     val site = !here
                     fun give (Atom a) = Jump (j, [a])
                       | give r = let val v = freshStamp () in Let (v, ([], t), r, Jump (j, [Var (v, [])])) end
                   in
                     case inlined (g, ts, args, SOME give) of
                       SOME b => (uncount (c, f :: args); censusInto (c, b);
                                  simp (c, env, Join (j, [(x, t)], Mark (site, body), b)))
                     | NONE => letStep (c, env, x, s, r, body)
                   end
               | NONE => letStep (c, env, x, s, r, body))
          | _ => letStep (c, env, x, s, r, body)
        end
    | Fun (fs, body) =>
        if List.all (fn f => uses (c, #name f) = 0) fs andalso spend () then simp (c, env, body)
        else
          (case (fs, etaOf fs, callOnce (c, fs, body)) of
             ([f], SOME a, _) =>
               if spend () then (IntTable.insert (#subst env, #name f, substAtom (env, a)); simp (c, env, body))
               else keepFun (c, env, fs, body)
           | ([f], NONE, true) =>
               (case inlineCall (c, env, f, body) of
                  SOME e => simp (census e, env, e)
                | NONE => keepFun (c, env, fs, body))
           | _ => keepFun (c, env, fs, body))
    | Join (j, ps, jbody, scope) =>
        (case knownBool (c, j, ps, jbody, scope) of
           SOME e => simp (c, env, e)
         | NONE =>
             case knownCon (c, j, ps, jbody, scope) of
               SOME e => simp (c, env, e)
             | NONE =>
                 case flattenJoin (c, j, ps, jbody, scope) of
                   SOME e => simp (c, env, e)
                 | NONE =>
                     case (ps, jbody) of
                       ([(p, _)], Return (Atom (Var (p', [])))) =>
                         if p = p' andalso spend () then
                           (* a join point that only returns its parameter:
                              each jump to it a return of what it gives *)
                           let
                             fun redirect e =
                               case e of
                                 Jump (j', [a]) => if j' = j then Return (Atom a) else e
                               | Let (y, s, r, b) => Let (y, s, r, redirect b)
                               | Fun (fs, b) => Fun (fs, redirect b)
                               | Join (k, qs, kb, sc) => Join (k, qs, redirect kb, redirect sc)
                               | If (a, t, f) => If (a, redirect t, redirect f)
                               | Handle (a, y, h) => Handle (redirect a, y, redirect h)
                               | Mark (sp, a) => Mark (sp, redirect a)
                               | _ => e
                           in simp (c, env, redirect scope) end
                         else simpJoin (c, env, j, ps, jbody, scope)
                     | _ => simpJoin (c, env, j, ps, jbody, scope))
    | Jump (j, xs) => Jump (j, List.map (fn a => substAtom (env, a)) xs)
    | If (cond, t, f) =>
        (case substAtom (env, cond) of
           Con0 (1, _) => if spend () then simp (c, env, t) else If (Con0 (1, Ty.bool), simp (c, env, t), simp (c, env, f))
         | Con0 (0, _) => if spend () then simp (c, env, f) else If (Con0 (0, Ty.bool), simp (c, env, t), simp (c, env, f))
         | a => If (a, simp (c, env, t), simp (c, env, f)))
    | Handle (a, x, h) =>
        if raisesHere a andalso spend () then
          let
            val jh = freshStamp ()
            val y = freshStamp ()
            val e = Join (jh, [(x, Ty.exn)], h, Handle (raisesTo jh a, y, Jump (jh, [Var (y, [])])))
          in simp (census e, env, e) end
        else
          let
            val () = inHandler := !inHandler + 1
            val a = simp (c, env, a)
            val () = inHandler := !inHandler - 1
          in Handle (a, x, simp (c, env, h)) end
    | Raise a => Raise (substAtom (env, a))
    | Return r =>
        (case specialised (known (env, substRhs (env, r))) of
           r as App (f, args) =>
             (case calleeOf f of
                SOME (g, ts) =>
                  (case inlined (g, ts, args, NONE) of
                     SOME b => simp (census b, env, b)
                   | NONE => Return r)
              | NONE => Return r)
         | r => Return r)
    | Mark (sp, a) =>
        let
          val saved = !here
          val () = here := sp
          val a = simp (c, env, a)
        in here := saved; Mark (sp, a) end

  (* A step, now what is known of it is used: a variable bound to an atom is
     the atom, one nothing uses goes, and what made it is known. *)
  and letStep (c, env, x, s as (tvs, _), r, body) =
    case r of
      Atom a =>
        if null tvs andalso spend () then (IntTable.insert (#subst env, x, a); simp (c, env, body))
        else Let (x, s, r, simp (c, env, body))
    | _ =>
        (* a tuple or a constructor whose value is returned at once: made
           in the return (Lower's results in globals, performance M8) *)
        if (case (r, body) of
              (Tuple _, Return (Atom (Var (y, [])))) => y = x
            | (Con _, Return (Atom (Var (y, [])))) => y = x
            | _ => false)
           andalso null tvs andalso uses (c, x) = 1 andalso spend ()
        then Return r
        else if uses (c, x) = 0 andalso removable r andalso spend () then simp (c, env, body)
        else
          (case r of
             Tuple xs => IntTable.insert (#known env, x, Fields (Vector.fromList xs))
           | Con _ => IntTable.insert (#known env, x, Made r)
           | MkExn _ => IntTable.insert (#known env, x, Made r)
           | _ => ();
           Let (x, s, r, simp (c, env, body)))

  and simpJoin (c, env, j, ps, jbody, scope) =
        if jumps (c, j) = 0 andalso spend () then simp (c, env, scope)
        else
          (case (if jumps (c, j) = 1 then placeJump (j, ps, jbody, scope) else NONE) of
             SOME e => if spend () then simp (c, env, e) else Join (j, ps, simp (c, env, jbody), simp (c, env, scope))
           | NONE => Join (j, ps, simp (c, env, jbody), simp (c, env, scope)))

  and keepFun (c, env, fs, body) =
    let
      (* a function's body is in no handler's region of its own *)
      fun inside b =
        let val saved = !inHandler
        in inHandler := 0; let val b = simp (c, env, b) in inHandler := saved; b end end
      val fs =
        List.map (fn {name, tyvars, params, result, body = b} =>
                    {name = name, tyvars = tyvars, params = params, result = result, body = inside b}) fs
      (* one alone in its group, which a copy may be specialised on *)
      val () =
        case fs of
          [f as {tyvars = [], params = [_], ...}] => IntTable.insert (!localFuns, #name f, f)
        | _ => ()
      (* a small one may be put where it is called in what follows, as a
         function of the top level may: what it names is in scope there too
         (M12) *)
      val () =
        if !inlining then
          List.app (fn f => if size (#body f) <= inlineSize andalso not (usesItself f) andalso not (raises (#body f))
                            then IntTable.insert (!inlinable, #name f, f) else ()) fs
        else ()
    in
      Fun (fs, simp (c, env, body))
    end

  (* The one function of fs, where it abstracts over no type variables and
     its body only calls another function with its parameter: that
     function, which is an atom, so to use it for this one changes nothing
     but that a call is saved. *)
  and etaOf (fs : fundef list) : atom option =
    let
      (* the call the body ends in, past copies of the parameter, which it
         may be given as any of them (xs) *)
      fun tail (Return r, xs) = SOME (r, xs)
        | tail (Mark (_, e), xs) = tail (e, xs)
        | tail (Let (y, ([], _), Atom (Var (z, [])), b), xs) =
            if List.exists (fn x => x = z) xs then tail (b, y :: xs) else NONE
        | tail _ = NONE
    in
      case fs of
        [{name, tyvars = [], params = [(x, _)], body, ...}] =>
          (case tail (body, [x]) of
             SOME (App (g, [Var (y, [])]), xs) =>
               if not (List.exists (fn x => x = y) xs) then NONE
               else
                 (case g of
                    Var (h, _) => if h <> name andalso not (List.exists (fn x => x = h) xs) then SOME g else NONE
                  | Global _ => SOME g
                  | _ => NONE)
           | _ => NONE)
      | _ => NONE
    end

  (* Whether the one function of fs is used once, by a call in body, where
     it is made -- not from inside a function of body, whose place would
     then be another's. *)
  and callOnce (c : census, fs : fundef list, body : exp) : bool =
    case fs of
      [f] => uses (c, #name f) = 1 andalso not (usesItself f) andalso calledHere (#name f, body)
    | _ => false

  and usesItself (f : fundef) : bool = uses (census (#body f), #name f) > 0

  (* The call of f in body: in body's own code, not a nested function's. *)
  and calledHere (f : int, e : exp) : bool =
    case e of
      Let (_, _, App (Var (g, _), [_]), b) => g = f orelse calledHere (f, b)
    | Let (_, _, _, b) => calledHere (f, b)
    | Fun (_, b) => calledHere (f, b)
    | Join (_, _, body, s) => calledHere (f, body) orelse calledHere (f, s)
    | If (_, t, e) => calledHere (f, t) orelse calledHere (f, e)
    | Handle (a, _, h) => calledHere (f, a) orelse calledHere (f, h)
    | Return (App (Var (g, _), [_])) => g = f
    | Mark (_, a) => calledHere (f, a)
    | _ => false

  (* The function f put where body calls it once: a call whose value goes
     on (Let) becomes a join point for what follows, which each return of f
     jumps to; a call in tail position becomes f's body. What is put in
     place has join points and variables the census of the round does not
     know of, so it is simplified after a census of its own -- which is
     whole: nothing it binds is used outside it. *)
  and inlineCall (c : census, env : env, f : fundef, body : exp) : exp option =
    let
      val param = case #params f of [(p, _)] => p | _ => bug "a function of other than one parameter"
      fun instance ts =
        ListPair.foldl (fn (a, t, s) => IntMap.insert (s, a, t)) IntMap.empty (#tyvars f, ts)
      fun paramTy ts = Ty.subst (instance ts) (#2 (hd (#params f)))
      (* f's body, its returns to k *)
      fun returnsTo (e : exp, k : rhs -> exp) : exp =
        case e of
          Let (x, s, r, b) => Let (x, s, r, returnsTo (b, k))
        | Fun (fs, b) => Fun (fs, returnsTo (b, k))
        | Join (j, ps, jb, s) => Join (j, ps, returnsTo (jb, k), returnsTo (s, k))
        | If (a, t, e) => If (a, returnsTo (t, k), returnsTo (e, k))
        | Handle (a, x, h) => Handle (returnsTo (a, k), x, returnsTo (h, k))
        | Return r => k r
        | Mark (sp, a) => Mark (sp, returnsTo (a, k))
        | _ => e
      (* the call of f in e, at the position p, in a handler's region or
         not: f's body there, in a frame of f (framed) *)
      fun place (e : exp, p : pos, region : bool) : exp option =
        case e of
          Let (x, s as (_, t), App (Var (g, ts), [arg]), rest) =>
            if g = #name f then
              if not (spend ()) then NONE
              else
                let
                  val j = freshStamp ()
                  val b = framed (nameOf f, p, region, false) (substTypes (instance ts) (#body f))
                  fun give r = let val v = freshStamp () in Let (v, ([], t), r, Jump (j, [Var (v, [])])) end
                in
                  SOME (Join (j, [(x, t)], Mark (p, rest),
                              Let (param, ([], paramTy ts), Atom arg,
                                   returnsTo (b, fn (Atom a) => Jump (j, [a]) | r => give r))))
                end
            else Option.map (fn rest' => Let (x, s, App (Var (g, ts), [arg]), rest')) (place (rest, p, region))
        | Let (x, s, r, rest) => Option.map (fn rest' => Let (x, s, r, rest')) (place (rest, p, region))
        | Return (App (Var (g, ts), [arg])) =>
            if g = #name f andalso spend () then
              SOME (Let (param, ([], paramTy ts), Atom arg,
                         framed (nameOf f, p, region, true) (substTypes (instance ts) (#body f))))
            else NONE
        | Fun (fs, b) => Option.map (fn b' => Fun (fs, b')) (place (b, p, region))
        | Join (j, ps, jb, s) =>
            (case place (jb, p, region) of
               SOME jb' => SOME (Join (j, ps, jb', s))
             | NONE => Option.map (fn s' => Join (j, ps, jb, s')) (place (s, p, region)))
        | If (a, t, e) =>
            (case place (t, p, region) of
               SOME t' => SOME (If (a, t', e))
             | NONE => Option.map (fn e' => If (a, t, e')) (place (e, p, region)))
        | Handle (a, x, h) =>
            (case place (a, p, true) of
               SOME a' => SOME (Handle (a', x, h))
             | NONE => Option.map (fn h' => Handle (a, x, h')) (place (h, p, region)))
        | Mark (sp, a) => Option.map (fn a' => Mark (sp, a')) (place (a, sp, region))
        | _ => NONE
    in
      place (body, !here, !inHandler > 0)
    end

  (* A join point whose body tests its one parameter, where some jump gives
     it a constant: a join point for each branch, the parameter that
     branch's constant in it, and the jumps with a constant made jumps to
     theirs; the others still go through the test. What this makes is
     added to the round's census (censusInto). *)
  and knownBool (c : census, j : label, ps : (var * Ty.ty) list, jbody : exp, scope : exp) : exp option =
    case (ps, jbody) of
      ([(x, _)], If (Var (x', []), t, f)) =>
        if x = x' andalso jumpsWith (j, scope) andalso spend () then
          let
            val jt = freshStamp ()
            val jf = freshStamp ()
            fun redirect e =
              case e of
                Jump (j', [Con0 (tag, _)]) => if j' = j then Jump (if tag = 1 then jt else jf, []) else e
              | Let (y, s, r, b) => Let (y, s, r, redirect b)
              | Fun (fs, b) => Fun (fs, redirect b)
              | Join (k, qs, kb, s) => Join (k, qs, redirect kb, redirect s)
              | If (a, t, f) => If (a, redirect t, redirect f)
              | Handle (a, y, h) => Handle (redirect a, y, redirect h)
              | Mark (sp, a) => Mark (sp, redirect a)
              | _ => e
            val scope = redirect scope
            val test = If (Var (x, []), Jump (jt, []), Jump (jf, []))
          in
            censusInto (c, scope); censusInto (c, test);
            SOME (Join (jt, [], substVar (x, boolAtom true) t,
                        Join (jf, [], substVar (x, boolAtom false) f, Join (j, ps, test, scope))))
          end
        else NONE
    | _ => NONE

  (* A join point of one parameter whose body is small, where some jump --
     not from inside a handler's region the join point is outside of --
     gives it a nullary constructor: at each such jump a copy of the body,
     the parameter that constructor, which the tests of its tag in it then
     fold (case of a known constructor: an inlined compare, say, and the
     case on its result). What this makes is added to the round's census. *)
  and knownCon (c : census, j : label, ps : (var * Ty.ty) list, jbody : exp, scope : exp) : exp option =
    case ps of
      [(x, _)] =>
        if sizeAtMost (jbody, knownConSize) andalso constantOutside (j, scope) andalso spend () then
          let
            fun redirect e =
              case e of
                Jump (j', [a as Con0 _]) => if j' = j then copy (substVar (x, a) jbody) else e
              | Let (y, s, r, b) => Let (y, s, r, redirect b)
              | Fun (fs, b) => Fun (fs, redirect b)
              | Join (k, qs, kb, s) => Join (k, qs, redirect kb, redirect s)
              | If (a, t, f) => If (a, redirect t, redirect f)
              | Handle (a, y, h) => Handle (a, y, redirect h)
              | Mark (sp, a) => Mark (sp, redirect a)
              | _ => e
            val scope = redirect scope
          in censusInto (c, scope); SOME (Join (j, ps, jbody, scope)) end
        else NONE
    | _ => NONE

  (* A join point with a parameter that is a tuple, whose body only takes
     its fields, where some jump gives it a tuple made there (performance
     M8, D8 A, step 1: `val (a, b) = if c then (x, y) else (z, w)`): the
     fields are its parameters instead, a jump gives the tuple's parts, or
     the fields of what it gives, and the tuple, used no more, goes. One
     rewrite, since the body's fields and the jumps' arguments change
     together. What this makes is added to the round's census. *)
  and flattenJoin (c : census, j : label, ps : (var * Ty.ty) list, jbody : exp, scope : exp) : exp option =
    let
      (* the tuples made in scope, by their variables *)
      val made : atom list IntTable.table = IntTable.table 16
      fun collect e =
        case e of
          Let (x, _, Tuple xs, b) => (IntTable.insert (made, x, xs); collect b)
        | Let (_, _, _, b) => collect b
        | Fun (_, b) => collect b
        | Join (_, _, jb, sc) => (collect jb; collect sc)
        | If (_, t, f) => (collect t; collect f)
        | Handle (a, _, h) => (collect a; collect h)
        | Mark (_, a) => collect a
        | _ => ()
      fun madeOf (Var (x, [])) = IntTable.find (made, x)
        | madeOf _ = NONE
      (* the arguments the jumps to j give the parameter at k *)
      fun argsAt (k, e) : atom list =
        case e of
          Jump (j', xs) => if j' = j then [List.nth (xs, k)] else []
        | Let (_, _, _, b) => argsAt (k, b)
        | Fun (_, b) => argsAt (k, b)
        | Join (_, _, jb, sc) => argsAt (k, jb) @ argsAt (k, sc)
        | If (_, t, f) => argsAt (k, t) @ argsAt (k, f)
        | Handle (a, _, h) => argsAt (k, a) @ argsAt (k, h)
        | Mark (_, a) => argsAt (k, a)
        | _ => []
      (* the walks only where some parameter is a tuple *)
      val tuples = List.exists (fn (_, t) => case Ty.view t of Ty.Tuple (_ :: _) => true | _ => false) ps
      val indexed = if tuples then ListPair.zip (List.tabulate (List.length ps, fn k => k), ps) else []
      val () = if tuples then collect scope else ()
      val flat =
        if not tuples then []
        else
        List.mapPartial (fn (k, (x, t)) =>
                           case Ty.view t of
                             Ty.Tuple (ts as _ :: _) =>
                               if onlySelected (x, jbody) andalso List.exists (isSome o madeOf) (argsAt (k, scope))
                               then SOME (k, ts) else NONE
                           | _ => NONE) indexed
    in
      if null flat orelse not (spend ()) then NONE
      else
        let
          fun flatAt k = List.find (fn (k', _) => k' = k) flat
          (* each parameter, or its fields as parameters *)
          val fieldsOf : var list IntTable.table = IntTable.table 4
          val ps' =
            List.concat
              (List.map (fn (k, (x, t)) =>
                           case flatAt k of
                             SOME (_, ts) =>
                               let val ys = List.map (fn _ => freshStamp ()) ts
                               in IntTable.insert (fieldsOf, x, ys); ListPair.zip (ys, ts) end
                           | NONE => [(x, t)]) indexed)
          fun field (i, x) = Atom (Var (List.nth (valOf (IntTable.find (fieldsOf, x)), i), []))
          val jbody' =
            mapRhs (fn r as Select (i, Var (x, [])) => if isSome (IntTable.find (fieldsOf, x)) then field (i, x) else r
                     | r => r) jbody
          (* a jump: each flattened argument its parts, or its fields
             taken where it is not a tuple made there *)
          fun jump xs =
            let
              fun go (k, a) =
                case flatAt k of
                  NONE => ([], [a])
                | SOME (_, ts) =>
                    (case madeOf a of
                       SOME parts => ([], parts)
                     | NONE =>
                         let val ys = List.map (fn t => (freshStamp (), t)) ts
                         in (List.tabulate (List.length ts, fn i => (#1 (List.nth (ys, i)), #2 (List.nth (ys, i)), Select (i, a))),
                             List.map (fn (y, _) => Var (y, [])) ys)
                         end)
              val parts = List.map go (ListPair.zip (List.tabulate (List.length xs, fn k => k), xs))
              val lets = List.concat (List.map #1 parts)
            in
              List.foldr (fn ((y, t, r), e) => Let (y, ([], t), r, e)) (Jump (j, List.concat (List.map #2 parts))) lets
            end
          fun redirect e =
            case e of
              Jump (j', xs) => if j' = j then jump xs else e
            | Let (y, s, r, b) => Let (y, s, r, redirect b)
            | Fun (fs, b) => Fun (fs, redirect b)
            | Join (k, qs, kb, sc) => Join (k, qs, redirect kb, redirect sc)
            | If (a, t, f) => If (a, redirect t, redirect f)
            | Handle (a, y, h) => Handle (redirect a, y, redirect h)
            | Mark (sp, a) => Mark (sp, redirect a)
            | _ => e
          val scope' = redirect scope
        in
          censusInto (c, jbody'); censusInto (c, scope');
          SOME (Join (j, ps', jbody', scope'))
        end
    end

  (* Whether every use of x in e takes a field of it. *)
  and onlySelected (x : var, e : exp) : bool =
    let
      fun atom a = case a of Var (y, _) => y <> x | _ => true
      fun rhs r =
        case r of
          Select (_, Var (y, _)) => true
        | Atom a => atom a
        | App (f, xs) => List.all atom (f :: xs)
        | Prim (_, _, xs) => List.all atom xs
        | Tuple xs => List.all atom xs
        | Select (_, a) => atom a
        | Con (_, _, a) => atom a
        | Decon (_, _, a) => atom a
        | ConTag a => atom a
        | MkExn (y, z) => atom y andalso atom z
        | ExnCon a => atom a
        | ExnArg (_, a) => atom a
        | SetGlobal (_, a) => atom a
        | _ => true
      fun go e =
        case e of
          Let (_, _, r, b) => rhs r andalso go b
        | Fun (fs, b) => List.all (fn f => go (#body f)) fs andalso go b
        | Join (_, _, jb, sc) => go jb andalso go sc
        | Jump (_, xs) => List.all atom xs
        | If (a, t, f) => atom a andalso go t andalso go f
        | Handle (a, _, h) => go a andalso go h
        | Raise a => atom a
        | Return r => rhs r
        | Mark (_, a) => go a
    in go e end

  (* Whether a jump in e, not in a handler's region, gives j a nullary
     constructor. *)
  and constantOutside (j : label, e : exp) : bool =
    case e of
      Jump (j', [Con0 _]) => j' = j
    | Let (_, _, _, b) => constantOutside (j, b)
    | Fun (_, b) => constantOutside (j, b)
    | Join (_, _, kb, s) => constantOutside (j, kb) orelse constantOutside (j, s)
    | If (_, t, f) => constantOutside (j, t) orelse constantOutside (j, f)
    | Handle (_, _, h) => constantOutside (j, h)
    | Mark (_, a) => constantOutside (j, a)
    | _ => false

  (* Whether a jump in e gives j a constant. *)
  and jumpsWith (j : label, e : exp) : bool =
    case e of
      Jump (j', [Con0 _]) => j' = j
    | Let (_, _, _, b) => jumpsWith (j, b)
    | Fun (_, b) => jumpsWith (j, b)
    | Join (_, _, kb, s) => jumpsWith (j, kb) orelse jumpsWith (j, s)
    | If (_, t, f) => jumpsWith (j, t) orelse jumpsWith (j, f)
    | Handle (a, _, h) => jumpsWith (j, a) orelse jumpsWith (j, h)
    | Mark (_, a) => jumpsWith (j, a)
    | _ => false

  (* Whether a handler's region e raises in its own code: not in a function
     made there, nor in the region of a handler inside it -- though in that
     handler's code, which runs in e's region. *)
  and raisesHere (e : exp) : bool =
    case e of
      Raise _ => true
    | Let (_, _, _, b) => raisesHere b
    | Fun (_, b) => raisesHere b
    | Join (_, _, jb, s) => raisesHere jb orelse raisesHere s
    | If (_, t, f) => raisesHere t orelse raisesHere f
    | Handle (_, _, h) => raisesHere h
    | Mark (_, a) => raisesHere a
    | _ => false

  (* e with each raise raisesHere finds a jump to jh. *)
  and raisesTo (jh : label) (e : exp) : exp =
    case e of
      Raise a => Jump (jh, [a])
    | Let (x, s, r, b) => Let (x, s, r, raisesTo jh b)
    | Fun (fs, b) => Fun (fs, raisesTo jh b)
    | Join (j, ps, jb, s) => Join (j, ps, raisesTo jh jb, raisesTo jh s)
    | If (a, t, f) => If (a, raisesTo jh t, raisesTo jh f)
    | Handle (a, x, h) => Handle (a, x, raisesTo jh h)
    | Mark (sp, a) => Mark (sp, raisesTo jh a)
    | _ => e

  (* A join point jumped to once: its body where the jump is, the
     parameters bound to the arguments -- but not into the body of a
     handler's region, which would catch what the join point's body raises
     where the jump left the region first. *)
  and placeJump (j : label, ps : (var * Ty.ty) list, jbody : exp, scope : exp) : exp option =
    let
      fun go e : exp option =
        case e of
          Jump (j', xs) =>
            if j' = j then SOME (ListPair.foldr (fn ((x, t), a, b) => Let (x, ([], t), Atom a, b)) jbody (ps, xs))
            else NONE
        | Let (x, s, r, b) => Option.map (fn b' => Let (x, s, r, b')) (go b)
        | Fun (fs, b) => Option.map (fn b' => Fun (fs, b')) (go b)
        | Join (j', ps', jb, s) =>
            (case go jb of
               SOME jb' => SOME (Join (j', ps', jb', s))
             | NONE => Option.map (fn s' => Join (j', ps', jb, s')) (go s))
        | If (a, t, f) =>
            (case go t of
               SOME t' => SOME (If (a, t', f))
             | NONE => Option.map (fn f' => If (a, t, f')) (go f))
        | Handle (a, x, h) => Option.map (fn h' => Handle (a, x, h')) (go h)
        | Mark (sp, a) => Option.map (fn a' => Mark (sp, a')) (go a)
        | _ => NONE
    in go scope end

  (* The rounds over an expression of the top level: three at most, and
     none after one that rewrote nothing. *)
  fun rounds (n : int, e : exp) : exp =
    if n = 0 then e
    else
      let
        val c = census e
        val () = (changed := false; roundInput := e; roundTypes := NONE)
        val e' = simp (c, {subst = IntTable.table 64, known = IntTable.table 64}, e)
      in
        if !changed then rounds (n - 1, e') else e'
      end

  (* Whether e names the global g. *)
  fun names (g : var, e : exp) : bool =
    let
      fun atom a = case a of Global (h, _) => h = g | _ => false
      fun rhs r =
        case r of
          Atom a => atom a
        | App (f, xs) => List.exists atom (f :: xs)
        | Prim (_, _, xs) => List.exists atom xs
        | Tuple xs => List.exists atom xs
        | Select (_, a) => atom a
        | Con (_, _, a) => atom a
        | Decon (_, _, a) => atom a
        | ConTag a => atom a
        | MkExn (c, a) => atom c orelse atom a
        | ExnCon a => atom a
        | ExnArg (_, a) => atom a
        | SetGlobal (h, a) => h = g orelse atom a
        | _ => false
      fun go e =
        case e of
          Let (_, _, r, b) => rhs r orelse go b
        | Fun (fs, b) => List.exists (fn f => go (#body f)) fs orelse go b
        | Join (_, _, body, s) => go body orelse go s
        | Jump (_, xs) => List.exists atom xs
        | If (c, t, f) => atom c orelse go t orelse go f
        | Handle (a, _, h) => go a orelse go h
        | Raise a => atom a
        | Return r => rhs r
        | Mark (_, a) => go a
    in go e end

  (* How many times each global is named in p, and how many of those are
     calls of it. *)
  fun globalUses (p : program) : (int * int) IntTable.table =
    let
      val t = IntTable.table 256
      fun name (g, call) =
        let val (n, c) = case IntTable.find (t, g) of SOME nc => nc | NONE => (0, 0)
        in IntTable.insert (t, g, (n + 1, if call then c + 1 else c)) end
      fun atom a = case a of Global (g, _) => name (g, false) | _ => ()
      fun rhs r =
        case r of
          Atom a => atom a
        | App (Global (g, _), xs) => (name (g, true); List.app atom xs)
        | App (f, xs) => List.app atom (f :: xs)
        | Prim (_, _, xs) => List.app atom xs
        | Tuple xs => List.app atom xs
        | Select (_, a) => atom a
        | Con (_, _, a) => atom a
        | Decon (_, _, a) => atom a
        | ConTag a => atom a
        | MkExn (x, y) => (atom x; atom y)
        | ExnCon a => atom a
        | ExnArg (_, a) => atom a
        | SetGlobal (g, a) => (name (g, false); atom a)
        | _ => ()
      fun exp e =
        case e of
          Let (_, _, r, b) => (rhs r; exp b)
        | Fun (fs, b) => (List.app (fn f => exp (#body f)) fs; exp b)
        | Join (_, _, body, s) => (exp body; exp s)
        | Jump (_, xs) => List.app atom xs
        | If (a, t, f) => (atom a; exp t; exp f)
        | Handle (a, _, h) => (exp a; exp h)
        | Raise a => atom a
        | Return r => rhs r
        | Mark (_, a) => exp a
    in
      List.app (fn Val (_, _, e) => exp e | Funs fs => List.app (fn f => exp (#body f)) fs | Do (_, e) => exp e) p;
      t
    end

  (* a functor's function (--functors=functions; Translate.functorFun
     names it so), which is not put where it is called: that is the
     expansion's (functors-units.md, M6), with its budget, and M5's
     applications are calls *)
  fun functorFun ({params, ...} : fundef) : bool =
    case params of
      (x, _) :: _ => (case IntMap.find (!Translate.funNames, x) of SOME n => String.isPrefix "functor " n | NONE => false)
    | [] => false

  fun program (p : program) : program =
    let
      (* inlining is an optional pass of its own name, which runs here *)
      val inline = Pass.enabled ("inline", 1)
      val () = inlining := inline
      val uses = globalUses p
      fun calledOnce g = IntTable.find (uses, g) = SOME (1, 1)
      val () = inlinable := IntTable.table 1024
      val () = once := IntTable.table 256
      val () =
        if not inline then ()
        else
          List.app (fn Funs fs =>
                         List.app (fn f =>
                                     if size (#body f) <= inlineLimit f andalso not (names (#name f, #body f))
                                        andalso not (raises (#body f)) andalso not (functorFun f)
                                     then IntTable.insert (!inlinable, #name f, f) else ()) fs
                     | _ => ()) p
      (* called once in the program; in a unit, a unit after it may call it
         too (Pass.whole) *)
      val () =
        if not inline orelse not (!Pass.whole) then ()
        else
          List.app (fn Funs [f] =>
                         if calledOnce (#name f) andalso not (names (#name f, #body f)) andalso not (functorFun f)
                         then IntTable.insert (!once, #name f, SOME f) else ()
                     | _ => ()) p
      val () = equalities := Pass.enabled ("equality", 2)
      val () = eqFuns := StringMap.empty
      val () = pendingEqs := []
      val specialise = Pass.enabled ("specialise", 1)
      val () = specialisable := IntTable.table 64
      val () = copies := StringMap.empty
      val () = pendingCopies := []
      val () = (localFuns := IntTable.table 256; liftedFuns := IntTable.table 64;
                closureDepth := IntTable.table 64; currentDepth := 0; wrapperFuns := IntTable.table 16)
      val () = globalFuns := IntTable.table 1024
      val () = List.app (fn Funs fs => List.app (fn f => IntTable.insert (!globalFuns, #name f, ())) fs | _ => ()) p
      (* each definition may grow by about its size by inlining: twice that
         runs the compiler no faster, in more code *)
      fun simplify e = (budget := size e + 32; here := (Source.noSpan, []); inHandler := 0; rounds (3, e))
      (* a definition's value is made with a continuation (Lower), not
         returned: a call in its tail is none, and a function put there keeps
         the frame of the code around it, as at -O0 (the review of M6,
         finding 4) -- under --functors=functions, whose copies' declarations
         are definitions; off, as before *)
      fun simplifyDef e =
        (roundParams := []; budget := size e + 32; here := (Source.noSpan, []);
         inHandler := (if !Elaborate.functorFunctions then 1 else 0); rounds (3, e))
      (* a function is put where it is called as it is simplified, where it
         still may be, and specialised as it is, where it may be *)
      fun fundef ({name, tyvars, params, result, body} : fundef) =
        let
          val () = roundParams := params
          val () = currentDepth := (case IntTable.find (!closureDepth, name) of SOME d => d | NONE => 0)
          val f' = {name = name, tyvars = tyvars, params = params, result = result, body = simplify body}
          val () = currentDepth := 0
        in
          if isSome (onceOf name) then IntTable.insert (!once, name, SOME f') else ();
          (* small once simplified, whatever it was before (performance
             M8: a worker's body shrinks by the copies of its parameters;
             the measure of three sizes for the functions that call something
             found the compiler compiling itself 2% slower for this, in 5%
             more code, and MLton's programs allocating 3 to 7% less) *)
          if inline andalso size (#body f') <= inlineLimit f' andalso not (names (name, #body f'))
             andalso (isSome (IntTable.find (!inlinable, name)) orelse not (raises (#body f')))
             andalso not (functorFun f')
          then IntTable.insert (!inlinable, name, f') else ();
          if specialise andalso size (#body f') <= specialiseSize then
            (case staticParams f' of
               [] => ()
             | is => IntTable.insert (!specialisable, name, (f', is, names (name, #body f'))))
          else ();
          f'
        end
      (* the copies a definition's calls made, simplified -- which may make
         more -- as one group before it *)
      fun withCopies d =
        let
          fun drain acc =
            case !pendingCopies @ !pendingEqs of
              [] => acc
            | fs => (pendingCopies := []; pendingEqs := []; drain (List.map fundef (List.rev fs) @ acc))
        in
          case drain [] of
            [] => [d]
          | fs => [Funs fs, d]
        end
    in
      List.concat
        (List.map (fn d => withCopies (case d of
                                         Val (g, s, e) => Val (g, s, simplifyDef e)
                                       | Funs fs => Funs (List.map fundef fs)
                                       | Do (gs, e) => Do (gs, simplifyDef e))) p)
    end
end
