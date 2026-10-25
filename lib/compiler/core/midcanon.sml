(* Mid renumbered canonically (the incremental roadmap's M7; D6): every name
   of a program -- each variable, global and join point, which share the
   elaborator's stamps; each type name that is not built in; each type
   variable -- given a number by where it first appears, from a base of its
   kind, and the tables Mid's passes read by those names entered again
   under the new ones: each datatype's constructors (Ty.datatypes, as
   Ty.datatypeOf gives them) and each function's name (Translate.funNames).
   The counters the passes take fresh names from are set after the last.

   So two programs that say the same are the same program whatever stamps
   their compiles gave them: the one a compile of the whole makes, and the
   one its units' Mid makes concatenated (M7's oracle: the whole-program
   build from the cache is the bytes of the one from source). *)
structure MidCanon =
struct
  open Mid

  (* above every name a compile makes, and in a host's 31 bits *)
  val base = 268435456

  (* the type name after the last a program was given (program): where
     the expansion (Expand) takes those of the datatypes its copies
     declare *)
  val nextTycon = ref base
  val () = CompilerState.cellRoot ("MidCanon.nextTycon", nextTycon)

  (* p with each name of each kind renamed by the functions given -- stamp
     for a variable, global or join point, tycon for a type name, tvar for a
     type variable -- called in the order the names appear, binders and uses
     alike, left to right *)
  (* A renaming of types: each node once, which calls tycon and tvar as a
     walk of the type as a tree would call them for the first time (a node
     met again names nothing new) *)
  fun renamer {tycon : int -> int, tvar : int -> int} : Ty.ty -> Ty.ty =
    let
      val done : Ty.ty IntTable.table = IntTable.table 256
      fun ty t =
        case IntTable.find (done, Ty.id t) of
          SOME u => u
        | NONE =>
            let
              val u =
                case Ty.view t of
                  Ty.Gen i => Ty.gen (tvar i)
                | Ty.Var i => Ty.var (tvar i)
                | Ty.Con (s, n, args) => let val s' = tycon s in Ty.con (s', n, List.map ty args) end
                | Ty.Tuple ts => Ty.tuple (List.map ty ts)
                | Ty.Arrow (a, b) => let val a' = ty a in Ty.arrow (a', ty b) end
                | Ty.ExnCon => Ty.exnCon
            in IntTable.insert (done, Ty.id t, u); u end
    in ty end

  fun rename {stamp : int -> int, tycon : int -> int, tvar : int -> int} (p : program) : program =
    let
      val ty = renamer {tycon = tycon, tvar = tvar}
      fun tys ts = List.map ty ts
      fun scheme ((vs, t) : scheme) = let val vs' = List.map tvar vs in (vs', ty t) end
      fun atom a =
        case a of
          Var (x, ts) => let val x' = stamp x in Var (x', tys ts) end
        | Global (x, ts) => let val x' = stamp x in Global (x', tys ts) end
        | Const (c, t) => Const (c, ty t)
        | Con0 (tag, t) => Con0 (tag, ty t)
        | Unit => Unit
      fun atoms l = List.map atom l
      fun rhs r =
        case r of
          Atom a => Atom (atom a)
        | App (f, args) => let val f' = atom f in App (f', atoms args) end
        | Prim (n, t, args) => let val t' = ty t in Prim (n, t', atoms args) end
        | Tuple args => Tuple (atoms args)
        | Select (i, a) => Select (i, atom a)
        | Con (tag, t, a) => let val t' = ty t in Con (tag, t', atom a) end
        | Decon (tag, t, a) => let val t' = ty t in Decon (tag, t', atom a) end
        | ConTag a => ConTag (atom a)
        | NewExn s => NewExn s
        | BuiltinExn i => BuiltinExn i
        | MkExn (a, b) => let val a' = atom a in MkExn (a', atom b) end
        | ExnCon a => ExnCon (atom a)
        | ExnArg (t, a) => let val t' = ty t in ExnArg (t', atom a) end
        | SetGlobal (g, a) => let val g' = stamp g in SetGlobal (g', atom a) end
      fun params ps = List.map (fn (x, t) => let val x' = stamp x in (x', ty t) end) ps
      fun fundef ({name, tyvars, params = ps, result, body} : fundef) : fundef =
        let
          val name' = stamp name
          val tyvars' = List.map tvar tyvars
          val ps' = params ps
          val result' = ty result
        in {name = name', tyvars = tyvars', params = ps', result = result', body = exp body} end
      and fundefs fs =
        (* the names first, which the bodies call one another by *)
        (List.app (fn (f : fundef) => ignore (stamp (#name f))) fs; List.map fundef fs)
      and exp e =
        case e of
          Let (x, s, r, b) => let val x' = stamp x val s' = scheme s val r' = rhs r in Let (x', s', r', exp b) end
        | Fun (fs, b) => let val fs' = fundefs fs in Fun (fs', exp b) end
        | Join (j, ps, b, sc) => let val j' = stamp j val ps' = params ps val b' = exp b in Join (j', ps', b', exp sc) end
        | Jump (j, args) => let val j' = stamp j in Jump (j', atoms args) end
        | If (a, t, f) => let val a' = atom a val t' = exp t in If (a', t', exp f) end
        | Handle (b, x, h) => let val b' = exp b val x' = stamp x in Handle (b', x', exp h) end
        | Raise a => Raise (atom a)
        | Return r => Return (rhs r)
        | Mark (pos, b) => Mark (pos, exp b)
      fun def d =
        case d of
          Val (g, s, e) => let val g' = stamp g val s' = scheme s in Val (g', s', exp e) end
        | Funs fs => Funs (fundefs fs)
        | Do (gs, e) => let val gs' = List.map (fn (g, s) => let val g' = stamp g in (g', scheme s) end) gs
                        in Do (gs', exp e) end
    in List.map def p end

  (* a type renamed the same way *)
  fun renameTy (fs : {tycon : int -> int, tvar : int -> int}) (t : Ty.ty) : Ty.ty = renamer fs t

  type datatypeInfo = {params : int list, cons : (int * string * Ty.ty option) list}

  fun builtin s = s < base andalso (List.exists (fn (c : Types.tycon) => #stamp c = s) Types.builtinTycons
                                     orelse isSome (Ty.flatOf s))

  (* What a unit's Mid needs of the compile's tables, which the compile of
     the next unit does not keep: each datatype its types name, and those
     theirs name, by stamp; each function's name (Translate.funNames) *)
  (* and the layouts a body fixed of the
     datatypes (Ty.pinned) and those a parameter leaves open (Ty.openTypes) *)
  type unitMid = {mid : program, datatypes : (int * datatypeInfo) list, funNames : (int * string) list,
                  pins : (int * (int * int option) list) list, opens : int list}

  fun capture (p : program) : unitMid =
    let
      val seen : unit IntTable.table = IntTable.table 64
      val found : (int * datatypeInfo) list ref = ref []
      fun visit s =
        if builtin s orelse isSome (IntTable.find (seen, s)) then ()
        else
          (IntTable.insert (seen, s, ());
           case Ty.datatypeOf s of
             SOME info => (found := (s, info) :: !found;
                           List.app (fn (_, _, a) => Option.app (ignore o visitTy) a) (#cons info))
           | NONE => ())
      (* visit is called again for a node met again, and does nothing *)
      and visitTy t = renameTy {tycon = fn c => (visit c; c), tvar = fn v => v} t
      val _ = rename {stamp = fn x => x, tycon = fn c => (visit c; c), tvar = fn v => v} p
      val found = List.rev (!found)
    in
      {mid = p, datatypes = found, funNames = IntMap.listItemsi (!Translate.funNames),
       pins = List.mapPartial (fn (s, _) => Option.map (fn l => (s, l)) (IntMap.find (!Ty.pinned, s))) found,
       opens = List.mapPartial (fn (s, _) => if Ty.isOpen s then SOME s else NONE) found}
    end

  (* a unit's Mid with its names renamed, its tables' too *)
  fun renameUnit (names as {stamp, tycon, tvar}) ({mid, datatypes, funNames, pins, opens} : unitMid) : unitMid =
    let val ty = renamer {tycon = tycon, tvar = tvar}
    in
      {mid = rename names mid,
       datatypes = List.map (fn (s, {params, cons}) =>
                               (tycon s, {params = List.map tvar params,
                                          cons = List.map (fn (t, n, a) => (t, n, Option.map ty a)) cons}))
                            datatypes,
       funNames = List.map (fn (s, n) => (stamp s, n)) funNames,
       pins = List.map (fn (s, l) => (tycon s, l)) pins, opens = List.map tycon opens}
    end

  (* units' Mid made one program, their tables entered *)
  fun concat (us : unitMid list) : program =
    (List.app (fn {datatypes, ...} => List.app Ty.bindDatatypeDirect datatypes) us;
     List.app (fn {pins, opens, ...} => (List.app Ty.pinLayout pins; List.app Ty.markOpen opens)) us;
     Translate.funNames := List.foldl (fn ({funNames, ...}, m) => List.foldl (fn ((s, n), m) => IntMap.insert (m, s, n)) m funNames)
                                      (!Translate.funNames) us;
     List.concat (List.map #mid us))

  fun program (p : program) : program =
    let
      val stamps : int IntTable.table = IntTable.table 4096
      val nstamps = ref 0
      val tycons : int IntTable.table = IntTable.table 256
      val ntycons = ref 0
      val tvars : int IntTable.table = IntTable.table 256
      val ntvars = ref 0
      fun number (t, n) x =
        case IntTable.find (t, x) of
          SOME y => y
        | NONE => let val y = base + !n in IntTable.insert (t, x, y); n := !n + 1; y end
      val stamp = number (stamps, nstamps)
      val tvar = number (tvars, ntvars)
      (* the datatypes met, in the order met, to be entered again *)
      val met : (int * int) list ref = ref []
      fun tycon s =
        if builtin s then s
        else
          case IntTable.find (tycons, s) of
            SOME y => y
          | NONE =>
              let val y = base + !ntycons
              in IntTable.insert (tycons, s, y); ntycons := !ntycons + 1; met := (s, y) :: !met; y end
      val p' = rename {stamp = stamp, tycon = tycon, tvar = tvar} p
      (* after p's, which calls tycon first for what p names *)
      val ty = renamer {tycon = tycon, tvar = tvar}
      (* each datatype met entered under its new name, its constructors'
         types renamed too: which may meet more, until none comes. They are
         entered once all are met: entering one makes Ty work out the extra
         parameters of every datatype again (Ty.extras) at the next
         datatypeOf, which was quadratic in the datatypes (performance M3);
         one entered under a name of its own changes no other's. *)
      val entered = ref []
      fun enter () =
        case !met of
          [] => ()
        | (s, y) :: rest =>
            (met := rest;
             case Ty.datatypeOf s of
               SOME {params = ps, cons} =>
                 let
                   val ps' = List.map tvar ps
                   val cons' = List.map (fn (tag, n, a) => (tag, n, Option.map ty a)) cons
                 in entered := (y, {params = ps', cons = cons'}) :: !entered end
             | NONE => ();
             (* its fixed layout, and whether it is open *)
             Option.app (fn l => Ty.pinLayout (y, l)) (IntMap.find (!Ty.pinned, s));
             if Ty.isOpen s then Ty.markOpen y else ();
             enter ())
      val () = enter ()
      val () = List.app Ty.bindDatatypeDirect (List.rev (!entered))
      (* each function's name, under its new stamp *)
      val () =
        Translate.funNames :=
          IntMap.foldli (fn (s, n, m) => case IntTable.find (stamps, s) of SOME s' => IntMap.insert (m, s', n) | NONE => m)
                        (!Translate.funNames) (!Translate.funNames)
    in
      (* fresh names after the last: the same in every build that says the same *)
      Elaborate.stampCounter := base + !nstamps;
      nextTycon := base + !ntycons;
      p'
    end
end
