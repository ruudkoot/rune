(* The export basis of a unit, as bytes (docs/units.md, *The export basis*;
   the incremental roadmap's D3, D4 and M6): what the units after it need
   of it to be compiled -- the environment it declared, its fixity
   directives, signatures, functors and overloading, and the compiler's
   tables of what it declared: each value's scheme, each exception's
   argument, each datatype's constructors, what each opaque type stands for,
   the primitives some values are, the functions that may be called by
   name -- in a form that does not depend on what was compiled before it.

   Every name -- a stamp (Elaborate.stampCounter: values, exceptions and the
   variables of the IRs), a type name (Types.tyconCounter), a type variable
   (Types.tvarCounter) -- is written as one of three:
   * a built-in one, made before any unit, as itself;
   * one of this unit's own, by a number of its own, given in the order the
     writing meets them, so that the same declarations always get the same
     numbers whatever came before (D3: Elsman's equality up to renaming);
   * one of an earlier unit's, by that unit's identity and its number there.
   Loading a unit gives its numbers names of the session again, a range of
   each kind after everything before it, and registers the range, so that
   the units after it name what it declared by its identity.

   A unit's identity is its name and the hash of its basis without the
   counts of what its compile used: a unit whose body changed and whose
   basis did not keeps it, and what was compiled against it stays valid
   (the cut-off). Every unit of a compile in units is loaded this way right
   after it is compiled (Main, the REPL), and the units after it see only
   what the bytes say: a unit compiled now and one taken from the cache are
   the same to them, byte for byte.

   A functor's body is not written: its place in the unit's source is, and
   loading parses the source again for it, the fixity of the unit's start
   in force. Its basis is the unit's start, which loading has, and what the
   unit declared before it. *)
structure UnitBasis =
struct
  structure P = Pickle
  structure T = Types

  (* a pickle that names a unit the session has not loaded *)
  exception Missing of string

  val version = 1
  val magic = "RBI"

  (* ---- the kinds of names ---- *)
  val kStamp = 0
  val kTycon = 1
  val kTvar = 2
  fun counter k = if k = kStamp then Elaborate.stampCounter else if k = kTycon then T.tyconCounter else T.tvarCounter
  fun counters () = Vector.tabulate (3, fn k => !(counter k))
  fun setCounters (v : int vector) = Vector.appi (fn (k, c) => counter k := c) v

  fun bug msg = raise Fail ("UnitBasis: " ^ msg)

  (* ---- the units of the session ---- *)

  (* A unit loaded: its identity, its name, the name its source has in
     spans, where its numbers start in the session, how many of each kind,
     and its functors, by where their bodies begin in its source, which a
     later unit's functor may have in its basis. *)
  type loaded = {identity : string, name : string, file : string, base : int vector, count : int vector,
                 funs : Elaborate.funinfo IntMap.map}

  val units : loaded list ref = ref []                        (* newest first *)
  val byIdentity : loaded StringMap.map ref = ref StringMap.empty
  (* every name below these is built in *)
  val builtin : int vector ref = ref (Vector.fromList [0, 0, 0])
  (* per kind, the ranges of the units by base, for writing: (base, count, unit) *)
  val ranges : (int * int * loaded) vector array = Array.array (3, Vector.fromList [])
  (* the type variables of the units loaded, by their ids: one cell for each *)
  val tvars : T.tvar ref IntTable.table ref = ref (IntTable.table 1024)

  (* Who bound each name of the top level the session has, by its kind and
     name as Usage records them ("v x", "s A", "fix ++", ...): the identity of
     the unit; a name not here is the initial basis's *)
  val binders : string StringMap.map ref = ref StringMap.empty

  (* A session begins: what exists now is built in. *)
  fun startSession () =
    (units := []; byIdentity := StringMap.empty; builtin := counters ();
     Array.modify (fn _ => Vector.fromList []) ranges; tvars := IntTable.table 1024; binders := StringMap.empty)

  fun binderOf (key : string) : string = case StringMap.find (!binders, key) of SOME i => i | NONE => ""

  (* The usages of a compile: each name it looked up (Usage), with the unit
     that bound it in the session as it is now, where the unit begins *)
  fun usagesOf (names : string list) : (string * string) list = List.map (fn k => (k, binderOf k)) names

  (* the first usage that does not hold in the session as it is, if one *)
  fun broken (us : (string * string) list) : string option =
    Option.map #1 (List.find (fn (k, i) => binderOf k <> i) us)

  fun register (u : loaded) =
    (units := u :: !units;
     byIdentity := StringMap.insert (!byIdentity, #identity u, u);
     List.app (fn k => if Vector.sub (#count u, k) = 0 then ()
                       else Array.update (ranges, k, Vector.concat [Array.sub (ranges, k),
                                                                     Vector.fromList [(Vector.sub (#base u, k),
                                                                                       Vector.sub (#count u, k), u)]]))
              [kStamp, kTycon, kTvar])

  (* the unit whose range of kind k holds v *)
  fun rangeOf (k, v) : (int * loaded) option =
    let
      val rs = Array.sub (ranges, k)
      fun search (lo, hi) =
        if lo >= hi then NONE
        else
          let
            val mid = (lo + hi) div 2
            val (b, c, u) = Vector.sub (rs, mid)
          in
            if v < b then search (lo, mid)
            else if v >= b + c then search (mid + 1, hi)
            else SOME (b, u)
          end
    in search (0, Vector.length rs) end

  (* ---- the state a unit begins in ---- *)

  (* What a unit's compile begins with, which its loading goes back to
     (Main, the REPL): the counters, the environment and fixity, the
     elaborator's tables, the primitives' aliases and the functions known
     by name *)
  type start = {counters : int vector, env : Env.env, fixity : Fixity.env, snapshot : Elaborate.snapshot,
                primAliases : string IntMap.map, knownBefore : unit IntMap.map}

  fun begin (env : Env.env, fixity : Fixity.env) : start =
    (Elaborate.insertedSigs := []; Elaborate.insertedFuns := []; Env.session := SOME env;
     {counters = counters (), env = env, fixity = fixity, snapshot = Elaborate.snapshot (),
      primAliases = !Translate.primAliases, knownBefore = !Lower.knownBefore})

  (* the tables back as the unit found them, before its basis is loaded *)
  fun undo (s : start) =
    (Elaborate.restore (#snapshot s); Translate.primAliases := #primAliases s; Lower.knownBefore := #knownBefore s)

  (* ---- writing ---- *)

  type enc = {w : P.writer,
              start : int vector,
              own : int IntTable.table vector,         (* per kind: a value -> its number *)
              count : int ref vector,
              queue : (int * int) list ref,            (* own names whose tables are to be written, newest first *)
              names : int StringMap.map ref,           (* the identities named, by their place in the header *)
              nameList : string list ref,              (* the same, newest first *)
              tycons : int IntTable.table, ntycons : int ref,
              funsDone : unit IntTable.table,          (* own functors written, by where their bodies begin *)
              base : Env.env,                          (* the unit's start *)
              file : string,                           (* the unit's source, as its spans name it *)
              text : unit -> string}                   (* the source *)

  fun ownNumber (e : enc, k, v) : int =
    let val t = Vector.sub (#own e, k)
    in
      case IntTable.find (t, v) of
        SOME i => i
      | NONE =>
          let val c = Vector.sub (#count e, k) val i = !c
          in IntTable.insert (t, v, i); c := i + 1; #queue e := (k, v) :: !(#queue e); i end
    end

  fun unitRef (e : enc, identity : string) : int =
    case StringMap.find (!(#names e), identity) of
      SOME i => i
    | NONE =>
        let val i = StringMap.numItems (!(#names e))
        in #names e := StringMap.insert (!(#names e), identity, i); #nameList e := identity :: !(#nameList e); i end

  fun name (e : enc, k : int, v : int) : unit =
    let val w = #w e
    in
      if v < Vector.sub (!builtin, k) then (P.byte (w, 0); P.int (w, v))
      else if v >= Vector.sub (#start e, k) then (P.byte (w, 1); P.nat (w, ownNumber (e, k, v)))
      else
        case rangeOf (k, v) of
          SOME (b, u) => (P.byte (w, 2); P.nat (w, unitRef (e, #identity u)); P.nat (w, v - b))
        | NONE => bug ("a name of no unit: kind " ^ Int.toString k ^ ", " ^ Int.toString v)
    end

  fun tycon (e : enc, c : T.tycon) : unit =
    let val w = #w e
    in
      case IntTable.find (#tycons e, #stamp c) of
        SOME i => (P.byte (w, 1); P.nat (w, i))
      | NONE =>
          (IntTable.insert (#tycons e, #stamp c, !(#ntycons e)); #ntycons e := !(#ntycons e) + 1;
           P.byte (w, 0); name (e, kTycon, #stamp c); P.string (w, #name c); P.nat (w, #arity c); P.bool (w, #eq c))
    end

  fun tkind (e : enc, k : T.kind) : unit =
    let val w = #w e
    in
      case k of
        T.KPlain => P.byte (w, 0)
      | T.KRigid s => (P.byte (w, 1); P.string (w, s))
      | T.KOverload ss => (P.byte (w, 2); P.list P.string (w, ss))
      | T.KFlex _ => bug "a flexible record in a unit's basis"
    end

  fun ty (e : enc, t : T.ty) : unit =
    let val w = #w e
    in
      case T.prune t of
        T.TVar (ref (T.Unbound {id, level, kind, eq})) =>
          (P.byte (w, 0); name (e, kTvar, id); P.nat (w, if level = T.genericLevel then 0 else level + 1);
           tkind (e, kind); P.bool (w, eq))
      | T.TVar _ => bug "a type pruned to a bound variable"
      | T.TCon (c, args) => (P.byte (w, 1); tycon (e, c); P.list (fn (_, a) => ty (e, a)) (w, args))
      | T.TRecord fs => (P.byte (w, 2); P.list (fn (_, (l, a)) => (P.string (w, l); ty (e, a))) (w, fs))
      | T.TArrow (a, b) => (P.byte (w, 3); ty (e, a); ty (e, b))
    end

  fun tyfcn (e : enc, f : T.tyfcn) : unit =
    case f of
      T.TName c => (P.byte (#w e, 0); tycon (e, c))
    | T.TAbbrev (ids, t) => (P.byte (#w e, 1); P.list (fn (_, i) => name (e, kTvar, i)) (#w e, ids); ty (e, t))

  (* the types of the IRs (Ty) *)
  fun irTy (e : enc, t : Ty.ty) : unit =
    let val w = #w e
    in
      case t of
        Ty.Gen i => (P.byte (w, 0); name (e, kTvar, i))
      | Ty.Var i => (P.byte (w, 1); name (e, kTvar, i))
      | Ty.Con (s, n, args) => (P.byte (w, 2); name (e, kTycon, s); P.string (w, n); P.list (fn (_, a) => irTy (e, a)) (w, args))
      | Ty.Tuple ts => (P.byte (w, 3); P.list (fn (_, a) => irTy (e, a)) (w, ts))
      | Ty.Arrow (a, b) => (P.byte (w, 4); irTy (e, a); irTy (e, b))
      | Ty.ExnCon => P.byte (w, 5)
    end

  fun coninfo (e : enc, {name = n, tag, hasArg, ncons, isRef, siblings} : Ast.coninfo) =
    let val w = #w e
    in
      P.string (w, n); P.nat (w, tag); P.bool (w, hasArg); P.nat (w, ncons); P.bool (w, isRef);
      P.list (fn (w, (s, b)) => (P.string (w, s); P.bool (w, b))) (w, siblings)
    end

  fun exninfo (e : enc, {name = n, stamp, isGlobal, hasArg, builtin = b} : Ast.exninfo) =
    let val w = #w e
    in P.string (w, n); name (e, kStamp, stamp); P.bool (w, isGlobal); P.bool (w, hasArg); P.option P.int (w, b) end

  fun valstatus (e : enc, v : Env.valstatus) : unit =
    let val w = #w e
    in
      case v of
        Env.Val {scheme, stamp, global} => (P.byte (w, 0); ty (e, scheme); name (e, kStamp, stamp); P.bool (w, global))
      | Env.Con {scheme, info} => (P.byte (w, 1); ty (e, scheme); coninfo (e, info))
      | Env.Exn {ty = t, info} => (P.byte (w, 2); ty (e, t); exninfo (e, info))
      | Env.Prim {scheme, name = n} => (P.byte (w, 3); ty (e, scheme); P.string (w, n))
      | Env.ConAsVal {scheme, info} => (P.byte (w, 4); ty (e, scheme); coninfo (e, info))
      | Env.ExnAsVal {ty = t, info} => (P.byte (w, 5); ty (e, t); exninfo (e, info))
    end

  fun tystatus (e : enc, Env.TyStr {fcn, cons}) : unit =
    (tyfcn (e, fcn); P.list (fn (w, (n, v)) => (P.string (w, n); valstatus (e, v))) (#w e, cons))

  fun env (e : enc, Env.Env {vals, tys, strs}) : unit =
    let val w = #w e
    in
      P.list (fn (w, (n, v)) => (P.string (w, n); valstatus (e, v))) (w, StringMap.listItemsi vals);
      P.list (fn (w, (n, t)) => (P.string (w, n); tystatus (e, t))) (w, StringMap.listItemsi tys);
      P.list (fn (w, (n, s)) => (P.string (w, n); env (e, s))) (w, StringMap.listItemsi strs)
    end

  fun sigma (e : enc, {bound, env = en} : SigMatch.sigma) : unit =
    (P.list (fn (_, c) => tycon (e, c)) (#w e, bound); env (e, en))

  (* ---- what of an environment is not the unit's start ---- *)

  (* the type name a constructor's scheme ends in *)
  fun resultTycon (t : T.ty) : int =
    case T.prune t of
      T.TArrow (_, r) => resultTycon r
    | T.TCon (c, _) => #stamp c
    | _ => ~1

  fun sameType (a : T.ty, b : T.ty) : bool =
    case (T.prune a, T.prune b) of
      (T.TVar r1, T.TVar r2) => r1 = r2
    | (T.TCon (c1, a1), T.TCon (c2, a2)) => #stamp c1 = #stamp c2 andalso ListPair.allEq sameType (a1, a2)
    | (T.TRecord f1, T.TRecord f2) =>
        ListPair.allEq (fn ((l1, t1), (l2, t2)) => l1 = l2 andalso sameType (t1, t2)) (f1, f2)
    | (T.TArrow (a1, b1), T.TArrow (a2, b2)) => sameType (a1, a2) andalso sameType (b1, b2)
    | _ => false

  fun sameVal (a : Env.valstatus, b : Env.valstatus) : bool =
    case (a, b) of
      (Env.Val x, Env.Val y) => #stamp x = #stamp y
    | (Env.Con x, Env.Con y) => #tag (#info x) = #tag (#info y) andalso #name (#info x) = #name (#info y)
                                andalso resultTycon (#scheme x) = resultTycon (#scheme y)
    | (Env.ConAsVal x, Env.ConAsVal y) => #tag (#info x) = #tag (#info y) andalso #name (#info x) = #name (#info y)
                                          andalso resultTycon (#scheme x) = resultTycon (#scheme y)
    | (Env.Exn x, Env.Exn y) => #stamp (#info x) = #stamp (#info y)
    | (Env.ExnAsVal x, Env.ExnAsVal y) => #stamp (#info x) = #stamp (#info y)
    | (Env.Prim x, Env.Prim y) => #name x = #name y andalso sameType (#scheme x, #scheme y)
    | _ => false

  fun sameTy (Env.TyStr a, Env.TyStr b) : bool =
    (case (#fcn a, #fcn b) of
       (T.TName c1, T.TName c2) => #stamp c1 = #stamp c2
     | (T.TAbbrev (i1, t1), T.TAbbrev (i2, t2)) => i1 = i2 andalso sameType (t1, t2)
     | _ => false)
    andalso ListPair.allEq (fn ((n1, v1), (n2, v2)) => n1 = n2 andalso sameVal (v1, v2)) (#cons a, #cons b)

  fun sameEnv (Env.Env a, Env.Env b) : bool =
    let
      fun same eq (m1, m2) =
        StringMap.numItems m1 = StringMap.numItems m2
        andalso StringMap.foldli (fn (n, x, ok) => ok andalso (case StringMap.find (m2, n) of
                                                                 SOME y => eq (x, y)
                                                               | NONE => false)) true m1
    in same sameVal (#vals a, #vals b) andalso same sameTy (#tys a, #tys b) andalso same sameEnv (#strs a, #strs b) end

  (* What of x is not as it is in base: x holds every name of base (an
     environment only grows from the unit's start), and those it binds
     otherwise are the delta, which the start plus the delta gives back. *)
  fun envDelta (base : Env.env, x : Env.env) : Env.env =
    let
      fun keep eq (bm, xm) = StringMap.filteri (fn (n, v) => case StringMap.find (bm, n) of
                                                               SOME b => not (eq (b, v))
                                                             | NONE => true) xm
    in
      Env.Env {vals = keep sameVal (Env.vals base, Env.vals x), tys = keep sameTy (Env.tys base, Env.tys x),
               strs = keep sameEnv (Env.strs base, Env.strs x)}
    end

  (* ---- functors ---- *)

  (* A functor's body, by where it begins in its unit's source *)
  fun bodyAt (body : Ast.strexp) : Source.span = Ast.spanOfStrexp body

  (* A functor: one of this unit's, written whole the first time and then by
     where its body begins (a functor declared again leaves the first in the
     basis of those declared between); or an earlier unit's, by that unit and
     the same *)
  fun funref (e : enc, f as Elaborate.FunInfo {body, origin, ...}) : unit =
    let
      val w = #w e
      val {start = at, ...} = bodyAt body
    in
      if origin = "" then
        if IntTable.find (#funsDone e, at) = NONE then (IntTable.insert (#funsDone e, at, ()); P.byte (w, 2); funinfo (e, f))
        else (P.byte (w, 0); P.nat (w, at))
      else (P.byte (w, 1); P.nat (w, unitRef (e, origin)); P.nat (w, at))
    end

  and funinfo (e : enc, Elaborate.FunInfo {param, paramSig, body, defEnv, allowPrim, defSigs, defFuns, ...}) : unit =
    let
      val w = #w e
      val {file, start = at, stop} = bodyAt body
      val () = if file = #file e then () else bug ("a functor of another unit's source: " ^ file)
      (* the body's text, by its hash: a unit whose functor's body changed
         has another basis, and the units that apply it are compiled
         again *)
      val bodyText = String.substring (#text e (), at, stop - at)
                     handle Subscript => bug "a functor's body out of its source"
      (* the signatures and functors the unit declared, as they were when
         this one was *)
      fun declared (names, m) =
        StringMap.listItemsi (List.foldl (fn (n, acc) => case StringMap.find (m, n) of
                                                          SOME v => StringMap.insert (acc, n, v)
                                                        | NONE => acc) StringMap.empty names)
    in
      P.option P.string (w, param); sigma (e, paramSig); P.nat (w, at); P.string (w, P.hash bodyText);
      env (e, envDelta (#base e, defEnv));
      P.bool (w, allowPrim);
      P.list (fn (w, (n, s)) => (P.string (w, n); sigma (e, s))) (w, declared (!Elaborate.insertedSigs, defSigs));
      P.list (fn (w, (n, f)) => (P.string (w, n); funref (e, f))) (w, declared (!Elaborate.insertedFuns, defFuns))
    end

  (* ---- overloading ---- *)

  fun overload (e : enc, (s, {kind, ops, literal} : Overload.entry)) : unit =
    let val w = #w e
    in
      name (e, kTycon, s); P.string (w, kind);
      P.list (fn (w, (n, i)) => (P.string (w, n);
                                 case i of
                                   Overload.Prim p => (P.byte (w, 0); P.string (w, p))
                                 | Overload.Global g => (P.byte (w, 1); name (e, kStamp, g))))
             (w, StringMap.listItemsi ops);
      case literal of
        Overload.Bits b => (P.byte (w, 0); P.int (w, b))
      | Overload.Via g => (P.byte (w, 1); name (e, kStamp, g))
    end

  (* ---- the tables, for each own name as the writing met it ---- *)

  fun tables (e : enc) : unit =
    let
      val w = #w e
      (* the queue, oldest first, until writing an entry adds no name *)
      fun drain () =
        case List.rev (!(#queue e)) of
          [] => ()
        | items => (#queue e := []; List.app entry items; drain ())
      and entry (k, v) =
        if k = kStamp then
          (P.byte (w, 1); P.nat (w, ownNumber (e, k, v));
           P.option (fn (_, t) => ty (e, t)) (w, IntTable.find (Ty.binders, v));
           P.option (P.option (fn (_, t) => ty (e, t))) (w, IntTable.find (Ty.exnArgs, v));
           P.option P.string (w, IntMap.find (!Translate.primAliases, v));
           P.bool (w, IntMap.member (!Lower.knownBefore, v)))
        else if k = kTycon then
          (P.byte (w, 2); P.nat (w, ownNumber (e, k, v));
           P.option (fn (w, {params, cons} : Ty.datatypeInfo) =>
                       (P.list (fn (_, i) => name (e, kTvar, i)) (w, params);
                        P.list (fn (w, (tag, n, a)) =>
                                  (P.nat (w, tag); P.string (w, n);
                                   P.option (fn (w, arg) =>
                                               case arg of
                                                 Ty.FromElab t => (P.byte (w, 0); ty (e, t))
                                               | Ty.Direct t => (P.byte (w, 1); irTy (e, t))) (w, a)))
                               (w, cons)))
                    (w, IntMap.find (!Ty.datatypes, v));
           P.option (fn (_, f) => tyfcn (e, f)) (w, IntTable.find (Ty.realizations, v));
           P.option (P.list (fn (w, (n, s)) => (P.string (w, n); valstatus (e, s)))) (w, IntMap.find (!Elaborate.dataCons, v)))
        else ()
    in drain (); P.byte (w, 0) end

  (* ---- a unit's basis ---- *)

  (* What export gives: the bytes, the unit's identity, and the number each
     of its own names was given, for the code of the unit (relative) *)
  type exported = {pickle : string, identity : string, own : int IntTable.table vector, counts : int vector}

  (* export {start, name, file, text, delta, fixity}: the basis of the unit
     compiled since start, which declared delta and left the fixity given;
     name is how it is known, file how its spans name its source, text the
     source *)
  fun export {start : start, name = uname : string, file : string, text : unit -> string, delta : Env.env,
              fixity : Fixity.env} : exported =
    let
      val w = P.writer ()
      val e : enc = {w = w, start = #counters start, own = Vector.tabulate (3, fn _ => IntTable.table 256),
                     count = Vector.tabulate (3, fn _ => ref 0), queue = ref [], names = ref StringMap.empty,
                     nameList = ref [], tycons = IntTable.table 256, ntycons = ref 0, funsDone = IntTable.table 16,
                     base = #env start, file = file, text = text}
      (* fixity: the directives the unit added, newest first *)
      val directives = List.take (#list fixity, List.length (#list fixity) - List.length (#list (#fixity start)))
      val () = P.list (fn (w, (n, f)) => (P.string (w, n);
                                         case f of
                                           Fixity.Nonfix => P.byte (w, 0)
                                         | Fixity.Infix p => (P.byte (w, 1); P.nat (w, p))
                                         | Fixity.Infixr p => (P.byte (w, 2); P.nat (w, p))))
                      (w, directives)
      val () = env (e, delta)
      (* signatures and functors, in the order the unit declared them, the
         last of each name *)
      (* names newest first, each once, at its newest *)
      fun distinct names =
        List.rev (List.foldl (fn (n, acc) => if List.exists (fn m => m = n) acc then acc else n :: acc) [] names)
      val sigNames = List.rev (distinct (!Elaborate.insertedSigs))
      val funNames = List.rev (distinct (!Elaborate.insertedFuns))
      val () = P.list (fn (w, n) => (P.string (w, n);
                                     case StringMap.find (!Elaborate.sigs, n) of
                                       SOME s => sigma (e, s)
                                     | NONE => bug ("no signature " ^ n))) (w, sigNames)
      val () = P.list (fn (w, n) => (P.string (w, n);
                                     case StringMap.find (!Elaborate.funs, n) of
                                       SOME f => funref (e, f)
                                     | NONE => bug ("no functor " ^ n))) (w, funNames)
      val before' = #overloads (#snapshot start)
      val () = P.list (fn (_, x) => overload (e, x))
                      (w, IntMap.listItemsi (IntMap.filteri (fn (s, _) => not (IntMap.member (before', s))) (!Overload.table)))
      val () = tables e
      val body = P.contents w
      val counts = Vector.map ! (#count e)
      (* the header: the name, the identities it names, the counts of its own *)
      val h = P.writer ()
      val () = (P.bytes (h, magic); P.nat (h, version); P.string (h, uname);
                P.list P.string (h, List.rev (!(#nameList e)));
                Vector.app (fn c => P.nat (h, c)) counts)
      val hashed = P.contents h ^ body
      (* what the compile used of each kind, which loading puts aside first,
         and the hash of the source, which a functor's body is parsed from
         again: neither is the basis's, nor in its identity *)
      val used = Vector.tabulate (3, fn k => !(counter k) - Vector.sub (#counters start, k))
      val u = P.writer ()
      val () = Vector.app (fn c => P.nat (u, c)) used
      val () = P.string (u, P.hash (text ()))
    in
      {pickle = P.contents u ^ hashed, identity = uname ^ "@" ^ P.hash hashed, own = #own e, counts = counts}
    end

  (* ---- a unit's code, by keys ---- *)

  (* The code of the unit just exported (x), its names made keys: its own by
     the numbers its basis gave them, and those the basis did not give --
     what no later unit can name -- numbers after those, in the order the
     code names them; an earlier unit's by that unit's identity and its
     number there (Link.unitCode) *)
  fun relative (x : exported, u : Link.sessionCode) : Link.unitCode =
    let
      val own = Vector.sub (#own x, kStamp)
      val start = Vector.sub (#counts x, kStamp)
      val private : int IntTable.table = IntTable.table 64
      val nprivate = ref 0
      fun key (s : int) : Link.key =
        if s = Link.next then Link.nextKey
        else
          case IntTable.find (own, s) of
            SOME n => {unit = #identity x, number = n}
          | NONE =>
              if s >= Vector.sub (!builtin, kStamp) then
                case rangeOf (kStamp, s) of
                  SOME (b, lu) => {unit = #identity lu, number = s - b}
                | NONE =>
                    {unit = #identity x,
                     number = case IntTable.find (private, s) of
                                SOME n => n
                              | NONE => let val n = start + !nprivate
                                        in IntTable.insert (private, s, n); nprivate := !nprivate + 1; n end}
              else bug ("a built-in name in a unit's code: " ^ Int.toString s)
      (* a global the unit sets is its own: no unit before it has it *)
      val () = List.app (fn s => if #unit (key s) = #identity x then () else bug "a global set by a unit is another's")
                        (#defines u)
    in
      {code = #code u, identity = #identity x, globals = List.map (fn (s, ix) => (key s, ix)) (#globals u),
       imports = List.map (fn (ix, s) => (ix, key s)) (#imports u),
       exports = List.map (fn (s, ix) => (#number (key s), ix)) (#exports u)}
    end

  (* ---- reading ---- *)

  type dec = {r : P.reader, base : int vector, units : loaded vector, ntycons : int ref, tycons : T.tycon array ref}

  fun rname (d : dec, k : int) : int =
    let val r = #r d
    in
      case P.rbyte r of
        0 => P.rint r
      | 1 => Vector.sub (#base d, k) + P.rnat r
      | 2 =>
          let
            val u = P.rnat r
            val i = P.rnat r
            val () = if u >= Vector.length (#units d) then raise P.Bad "a unit out of range" else ()
            val lu = Vector.sub (#units d, u)
          in
            if i >= Vector.sub (#count lu, k) then raise P.Bad "a name out of its unit's range"
            else Vector.sub (#base lu, k) + i
          end
      | _ => raise P.Bad "not a name"
    end

  fun rtycon (d : dec) : T.tycon =
    let
      val r = #r d
      val arr = #tycons d
      val n = #ntycons d
    in
      case P.rbyte r of
        0 =>
          let
            val s = rname (d, kTycon)
            val nm = P.rstring r
            val ar = P.rnat r
            val eq = P.rbool r
            val c = {name = nm, stamp = s, arity = ar, eq = eq}
          in
            if !n >= Array.length (!arr) then
              arr := Array.tabulate (2 * Array.length (!arr) + 16,
                                     fn i => if i < Array.length (!arr) then Array.sub (!arr, i) else c)
            else ();
            Array.update (!arr, !n, c); n := !n + 1; c
          end
      | 1 => let val i = P.rnat r in if i < !n then Array.sub (!arr, i) else raise P.Bad "a type name out of range" end
      | _ => raise P.Bad "not a type name"
    end

  fun rkind (d : dec) : T.kind =
    case P.rbyte (#r d) of
      0 => T.KPlain
    | 1 => T.KRigid (P.rstring (#r d))
    | 2 => T.KOverload (P.rlist P.rstring (#r d))
    | _ => raise P.Bad "not a kind"

  fun rty (d : dec) : T.ty =
    let val r = #r d
    in
      case P.rbyte r of
        0 =>
          let
            val id = rname (d, kTvar)
            val lv = P.rnat r
            val kind = rkind d
            val eq = P.rbool r
          in
            case IntTable.find (!tvars, id) of
              SOME cell => T.TVar cell
            | NONE =>
                let val cell = ref (T.Unbound {id = id, level = if lv = 0 then T.genericLevel else lv - 1, kind = kind, eq = eq})
                in IntTable.insert (!tvars, id, cell); T.TVar cell end
          end
      | 1 => let val c = rtycon d in T.TCon (c, P.rlist (fn _ => rty d) r) end
      | 2 => T.TRecord (P.rlist (fn r => let val l = P.rstring r in (l, rty d) end) r)
      | 3 => let val a = rty d in T.TArrow (a, rty d) end
      | _ => raise P.Bad "not a type"
    end

  fun rtyfcn (d : dec) : T.tyfcn =
    case P.rbyte (#r d) of
      0 => T.TName (rtycon d)
    | 1 => let val ids = P.rlist (fn _ => rname (d, kTvar)) (#r d) in T.TAbbrev (ids, rty d) end
    | _ => raise P.Bad "not a type function"

  fun rirTy (d : dec) : Ty.ty =
    let val r = #r d
    in
      case P.rbyte r of
        0 => Ty.Gen (rname (d, kTvar))
      | 1 => Ty.Var (rname (d, kTvar))
      | 2 => let val s = rname (d, kTycon) val n = P.rstring r in Ty.Con (s, n, P.rlist (fn _ => rirTy d) r) end
      | 3 => Ty.Tuple (P.rlist (fn _ => rirTy d) r)
      | 4 => let val a = rirTy d in Ty.Arrow (a, rirTy d) end
      | 5 => Ty.ExnCon
      | _ => raise P.Bad "not a type of the IRs"
    end

  fun rconinfo (d : dec) : Ast.coninfo =
    let
      val r = #r d
      val n = P.rstring r
      val tag = P.rnat r
      val hasArg = P.rbool r
      val ncons = P.rnat r
      val isRef = P.rbool r
      val siblings = P.rlist (fn r => let val s = P.rstring r in (s, P.rbool r) end) r
    in {name = n, tag = tag, hasArg = hasArg, ncons = ncons, isRef = isRef, siblings = siblings} end

  fun rexninfo (d : dec) : Ast.exninfo =
    let
      val r = #r d
      val n = P.rstring r
      val stamp = rname (d, kStamp)
      val isGlobal = P.rbool r
      val hasArg = P.rbool r
      val b = P.roption P.rint r
    in {name = n, stamp = stamp, isGlobal = isGlobal, hasArg = hasArg, builtin = b} end

  fun rvalstatus (d : dec) : Env.valstatus =
    case P.rbyte (#r d) of
      0 => let val s = rty d val st = rname (d, kStamp) in Env.Val {scheme = s, stamp = st, global = P.rbool (#r d)} end
    | 1 => let val s = rty d in Env.Con {scheme = s, info = rconinfo d} end
    | 2 => let val t = rty d in Env.Exn {ty = t, info = rexninfo d} end
    | 3 => let val s = rty d in Env.Prim {scheme = s, name = P.rstring (#r d)} end
    | 4 => let val s = rty d in Env.ConAsVal {scheme = s, info = rconinfo d} end
    | 5 => let val t = rty d in Env.ExnAsVal {ty = t, info = rexninfo d} end
    | _ => raise P.Bad "not a value's status"

  fun rmap (d : dec) (f : dec -> 'a) : 'a StringMap.map =
    List.foldl (fn ((n, v), m) => StringMap.insert (m, n, v)) StringMap.empty
               (P.rlist (fn r => let val n = P.rstring r in (n, f d) end) (#r d))

  fun rtystatus (d : dec) : Env.tystatus =
    let val fcn = rtyfcn d
    in Env.TyStr {fcn = fcn, cons = P.rlist (fn r => let val n = P.rstring r in (n, rvalstatus d) end) (#r d)} end

  fun renv (d : dec) : Env.env =
    let
      val vals = rmap d rvalstatus
      val tys = rmap d rtystatus
      val strs = rmap d renv
    in Env.Env {vals = vals, tys = tys, strs = strs} end

  fun rsigma (d : dec) : SigMatch.sigma =
    let val bound = P.rlist (fn _ => rtycon d) (#r d) in {bound = bound, env = renv d} end

  (* ---- loading ---- *)

  (* The top-level functor declarations of a source, by where their bodies
     begin *)
  fun functorsOf (decs : Ast.dec list) : Ast.strexp IntMap.map =
    let
      fun dec (Ast.DFunctor (bs, _), m) =
            List.foldl (fn (b : Ast.funbind, m) => IntMap.insert (m, #start (bodyAt (#body b)), #body b)) m bs
        | dec (Ast.DLocal (a, b, _), m) = List.foldl dec (List.foldl dec m a) b
        | dec (_, m) = m
    in List.foldl dec IntMap.empty decs end

  (* What load gives: the unit, the environment it declared, and its
     fixity directives, newest first, which the caller adds to the start;
     and the names of the signatures and functors it declared *)
  type result = {unit : loaded, delta : Env.env, directives : (string * Fixity.fixity) list,
                 sigs : string list, funs : string list}

  (* What the unit of r declared is the session's: the names it bound, by
     the unit, for the usages of the units after it. The caller says when:
     at once, or once the unit has run (the REPL: a declaration that raises
     binds nothing) *)
  fun bind ({unit, delta, directives, sigs, funs} : result) : unit =
    let
      val id = #identity unit
      fun put (kind, names) = List.app (fn n => binders := StringMap.insert (!binders, kind ^ " " ^ n, id)) names
    in
      put ("v", StringMap.listKeys (Env.vals delta));
      put ("t", StringMap.listKeys (Env.tys delta));
      put ("s", StringMap.listKeys (Env.strs delta));
      put ("fix", List.map #1 directives);
      put ("sig", sigs);
      put ("fun", funs)
    end

  (* load {pickle, file, at, env, fixity, text}: the unit whose basis pickle
     is, loaded after the units of the session: its numbers given the names
     of the session that follow at's counters and what its compile used,
     its tables entered, its signatures, functors and overloading declared,
     and the unit registered. env and fixity are the unit's start; text
     gives its source, which spans name file, for its functors' bodies.
     Raises Missing where it names a unit the session has not, and
     Pickle.Bad where the bytes are not a basis. *)
  fun load {pickle : string, file : string, at : int vector, env = startEnv : Env.env,
            fixity = startFixity : Fixity.env, text : unit -> string} : result =
    let
      val r = P.reader pickle
      val used = Vector.tabulate (3, fn _ => P.rnat r)
      val sourceHash = P.rstring r
      val hashed = String.extract (pickle, !(#pos r), NONE)
      val () = if P.rbytes (r, 3) = magic then () else raise P.Bad "not a unit's basis"
      val () = if P.rnat r = version then () else raise P.Bad "a basis of another version"
      val uname = P.rstring r
      val identity = uname ^ "@" ^ P.hash hashed
      val identities = P.rlist P.rstring r
      val us = Vector.fromList (List.map (fn i => case StringMap.find (!byIdentity, i) of
                                                    SOME u => u
                                                  | NONE => raise Missing i) identities)
      val counts = Vector.tabulate (3, fn _ => P.rnat r)
      val base = Vector.tabulate (3, fn k => Vector.sub (at, k) + Vector.sub (used, k))
      val () = List.app (fn k => counter k := Vector.sub (base, k) + Vector.sub (counts, k)) [kStamp, kTycon, kTvar]
      val d : dec = {r = r, base = base, units = us, ntycons = ref 0, tycons = ref (Array.fromList [])}
      fun rfixity r =
        case P.rbyte r of
          0 => Fixity.Nonfix
        | 1 => Fixity.Infix (P.rnat r)
        | 2 => Fixity.Infixr (P.rnat r)
        | _ => raise P.Bad "not a fixity"
      val directives = P.rlist (fn r => let val n = P.rstring r in (n, rfixity r) end) r
      val delta = renv d
      val sigs = P.rlist (fn r => let val n = P.rstring r in (n, rsigma d) end) r
      (* functors: their bodies from the source parsed again, once *)
      val bodies : Ast.strexp IntMap.map option ref = ref NONE
      fun bodyOf at =
        let
          val m =
            case !bodies of
              SOME m => m
            | NONE =>
                let
                  val t = text ()
                  val () = if P.hash t = sourceHash then () else raise P.Bad "its source is not the one it was made from"
                  val src = Source.fromString (file, t)
                  val () = Source.register src
                  val (decs, _) = Parser.parseTokensWith (Lexer.tokenize src, startFixity)
                  val m = functorsOf decs
                in bodies := SOME m; m end
        in
          case IntMap.find (m, at) of
            SOME b => b
          | NONE => raise P.Bad "no functor where the basis says"
        end
      (* a unit's own functors by where they begin, those read so far; the
         signatures and functors of the unit's start, which a functor's
         basis adds the unit's to *)
      val ownFuns : Elaborate.funinfo IntMap.map ref = ref IntMap.empty
      val startSigs = !Elaborate.sigs
      val startFuns = !Elaborate.funs
      fun rfunref (r : P.reader) : Elaborate.funinfo =
        case P.rbyte r of
          2 => rfuninfo r
        | 0 => let val at = P.rnat r
               in case IntMap.find (!ownFuns, at) of
                    SOME f => f
                  | NONE => raise P.Bad "a functor named before it is declared"
               end
        | 1 =>
            let
              val u = P.rnat r
              val at = P.rnat r
              val () = if u >= Vector.length us then raise P.Bad "a unit out of range" else ()
            in
              case IntMap.find (#funs (Vector.sub (us, u)), at) of
                SOME f => f
              | NONE => raise P.Bad "no functor of that unit there"
            end
        | _ => raise P.Bad "not a functor"
      and rfuninfo (r : P.reader) : Elaborate.funinfo =
        let
          val param = P.roption P.rstring r
          val paramSig = rsigma d
          val at = P.rnat r
          val _ = P.rstring r   (* the hash of its body's text, in the unit's identity *)
          val defDelta = renv d
          val allowPrim = P.rbool r
          val defSigs = P.rlist (fn r => let val n = P.rstring r in (n, rsigma d) end) r
          val defFuns = P.rlist (fn r => let val n = P.rstring r in (n, rfunref r) end) r
          val f =
            Elaborate.FunInfo
              {param = param, paramSig = paramSig, body = bodyOf at, defEnv = Env.plus (startEnv, defDelta),
               allowPrim = allowPrim, origin = identity,
               defSigs = List.foldl (fn ((n, s), m) => StringMap.insert (m, n, s)) startSigs defSigs,
               defFuns = List.foldl (fn ((n, f), m) => StringMap.insert (m, n, f)) startFuns defFuns}
        in ownFuns := IntMap.insert (!ownFuns, at, f); f end
      val funs = P.rlist (fn r => let val n = P.rstring r in (n, rfunref r) end) r
      val overloads =
        P.rlist (fn r =>
                   let
                     val s = rname (d, kTycon)
                     val kind = P.rstring r
                     val ops = P.rlist (fn r => let val n = P.rstring r
                                                in (n, case P.rbyte r of
                                                         0 => Overload.Prim (P.rstring r)
                                                       | 1 => Overload.Global (rname (d, kStamp))
                                                       | _ => raise P.Bad "not an operator")
                                                end) r
                     val literal = case P.rbyte r of
                                     0 => Overload.Bits (P.rint r)
                                   | 1 => Overload.Via (rname (d, kStamp))
                                   | _ => raise P.Bad "not a literal"
                   in
                     (s, {kind = kind, ops = List.foldl (fn ((n, i), m) => StringMap.insert (m, n, i)) StringMap.empty ops,
                          literal = literal})
                   end) r
      (* the tables *)
      fun entries () =
        case P.rbyte r of
          0 => ()
        | 1 =>
            let
              val v = Vector.sub (base, kStamp) + P.rnat r
              val binder = P.roption (fn _ => rty d) r
              val exnArg = P.roption (P.roption (fn _ => rty d)) r
              val alias = P.roption P.rstring r
              val known = P.rbool r
            in
              Option.app (fn t => Ty.bindVar (v, t)) binder;
              Option.app (fn a => Ty.bindExn (v, a)) exnArg;
              Option.app (fn p => Translate.primAliases := IntMap.insert (!Translate.primAliases, v, p)) alias;
              if known then Lower.knownBefore := IntMap.insert (!Lower.knownBefore, v, ()) else ();
              entries ()
            end
        | 2 =>
            let
              val c = Vector.sub (base, kTycon) + P.rnat r
              val dt = P.roption (fn r =>
                                    let
                                      val params = P.rlist (fn _ => rname (d, kTvar)) r
                                      val cons = P.rlist (fn r =>
                                                            let
                                                              val tag = P.rnat r
                                                              val n = P.rstring r
                                                              val a = P.roption (fn r => case P.rbyte r of
                                                                                           0 => Ty.FromElab (rty d)
                                                                                         | 1 => Ty.Direct (rirTy d)
                                                                                         | _ => raise P.Bad "not an argument") r
                                                            in (tag, n, a) end) r
                                    in {params = params, cons = cons} : Ty.datatypeInfo end) r
              val real = P.roption (fn _ => rtyfcn d) r
              val dcons = P.roption (P.rlist (fn r => let val n = P.rstring r in (n, rvalstatus d) end)) r
            in
              Option.app (fn i => (Ty.extras := Ty.Unknown; Ty.datatypes := IntMap.insert (!Ty.datatypes, c, i))) dt;
              Option.app (fn f => IntTable.insert (Ty.realizations, c, f)) real;
              Option.app (fn l => Elaborate.dataCons := IntMap.insert (!Elaborate.dataCons, c, l)) dcons;
              entries ()
            end
        | _ => raise P.Bad "not a table's entry"
      val () = entries ()
      val () = if P.atEnd r then () else raise P.Bad "bytes after the basis"
      (* declared: signatures, functors, overloading *)
      val () = List.app (fn (n, s) => Elaborate.sigs := StringMap.insert (!Elaborate.sigs, n, s)) sigs
      val () = List.app (fn (n, f) => Elaborate.funs := StringMap.insert (!Elaborate.funs, n, f)) funs
      val () = List.app (fn (s, x) => Overload.table := IntMap.insert (!Overload.table, s, x)) overloads
      val u : loaded = {identity = identity, name = uname, file = file, base = base,
                        count = counts, funs = !ownFuns}
    in
      register u;
      {unit = u, delta = delta, directives = directives, sigs = List.map #1 sigs, funs = List.map #1 funs}
    end
    handle Overflow => raise P.Bad "a number out of range"
         | Subscript => raise P.Bad "out of range"
end
