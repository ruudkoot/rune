(* A unit's Mid in bytes (the incremental roadmap's M7; D6): what ToMid made
   of the unit, with the datatypes its types name and its functions' names
   (MidCanon.unitMid), kept in its cache entry beside its basis and code, so
   that a whole program can be made of its units' Mid whether each unit was
   compiled or taken from the cache (rune --units --whole).

   Each name -- a variable, global or join point (a stamp), a type name, a
   type variable -- is written as one of four, as a basis writes them
   (UnitBasis): built in; the unit's own that its basis gives a number, by
   that number; an earlier unit's, by that unit's identity and its number
   there; or the unit's own that no unit after it can name, by its place
   among those, which reading gives fresh names. So the Mid read back names
   what the session names, and MidCanon gives the program it makes the
   same names whichever way each unit came. *)
structure UnitMid =
struct
  structure P = Pickle
  structure B = UnitBasis
  open Mid

  val magic = "RBM"
  val version = 2

  exception Bad of string

  (* ---- writing ---- *)

  (* write (x, um): um, the Mid of the unit x was exported from, as it was
     captured before its basis was loaded again *)
  fun write (x : B.exported, {mid, datatypes, funNames} : MidCanon.unitMid) : string =
    let
      val w = P.writer ()
      val identities : string list ref = ref []
      val nidentities = ref 0
      val unitIndex : int StringMap.map ref = ref StringMap.empty
      fun unitRef i =
        case StringMap.find (!unitIndex, i) of
          SOME n => n
        | NONE => let val n = !nidentities
                  in unitIndex := StringMap.insert (!unitIndex, i, n); identities := i :: !identities;
                     nidentities := n + 1; n end
      val privates = Vector.tabulate (3, fn _ => (IntTable.table 256 : int IntTable.table, ref 0))
      (* the source files its positions are in, by number, as a unit's code
         names them: a unit from the cache has them renamed where they are
         now (relocate) *)
      val files : string list ref = ref []
      val nfiles = ref 0
      val fileIndex : int StringMap.map ref = ref StringMap.empty
      fun fileRef f =
        case StringMap.find (!fileIndex, f) of
          SOME n => n
        | NONE => let val n = !nfiles
                  in fileIndex := StringMap.insert (!fileIndex, f, n); files := f :: !files; nfiles := n + 1; n end
      (* a name of kind k, as one of the four *)
      fun name (k : int) (s : int) : unit =
        if s < Vector.sub (!B.builtin, k) then (P.byte (w, 0); P.int (w, s))
        else
          case IntTable.find (Vector.sub (#own x, k), s) of
            SOME n => (P.byte (w, 1); P.nat (w, n))
          | NONE =>
              case B.rangeOf (k, s) of
                SOME (b, lu) => (P.byte (w, 2); P.nat (w, unitRef (#identity lu)); P.nat (w, s - b))
              | NONE =>
                  let
                    val (t, n) = Vector.sub (privates, k)
                    val i = case IntTable.find (t, s) of
                              SOME i => i
                            | NONE => let val i = !n in IntTable.insert (t, s, i); n := i + 1; i end
                  in P.byte (w, 3); P.nat (w, i) end
      val stamp = name B.kStamp
      val tycon = name B.kTycon
      val tvar = name B.kTvar
      fun list f l = P.list (fn (_, a) => f a) (w, l)
      fun ty t =
        case t of
          Ty.Gen i => (P.byte (w, 0); tvar i)
        | Ty.Var i => (P.byte (w, 1); tvar i)
        | Ty.Con (s, n, args) => (P.byte (w, 2); tycon s; P.string (w, n); list ty args)
        | Ty.Tuple ts => (P.byte (w, 3); list ty ts)
        | Ty.Arrow (a, b) => (P.byte (w, 4); ty a; ty b)
        | Ty.ExnCon => P.byte (w, 5)
      fun const (c : Lambda.const) =
        case c of
          Lambda.CInt i => (P.byte (w, 0); P.string (w, IntInf.toString i))
        | Lambda.CWord i => (P.byte (w, 1); P.string (w, IntInf.toString i))
        | Lambda.CInt64 i => (P.byte (w, 2); P.string (w, IntInf.toString i))
        | Lambda.CWord64 i => (P.byte (w, 3); P.string (w, IntInf.toString i))
        | Lambda.CReal s => (P.byte (w, 4); P.string (w, s))
        | Lambda.CString s => (P.byte (w, 5); P.string (w, s))
        | Lambda.CChar n => (P.byte (w, 6); P.nat (w, n))
      fun span ({file, start, stop} : Source.span) = (P.nat (w, fileRef file); P.nat (w, start); P.nat (w, stop))
      fun atom a =
        case a of
          Var (x, ts) => (P.byte (w, 0); stamp x; list ty ts)
        | Global (x, ts) => (P.byte (w, 1); stamp x; list ty ts)
        | Const (c, t) => (P.byte (w, 2); const c; ty t)
        | Con0 (tag, t) => (P.byte (w, 3); P.nat (w, tag); ty t)
        | Unit => P.byte (w, 4)
      fun rhs r =
        case r of
          Atom a => (P.byte (w, 0); atom a)
        | App (f, args) => (P.byte (w, 1); atom f; list atom args)
        | Prim (n, t, args) => (P.byte (w, 2); P.string (w, n); ty t; list atom args)
        | Tuple args => (P.byte (w, 3); list atom args)
        | Select (i, a) => (P.byte (w, 4); P.nat (w, i); atom a)
        | Con (tag, t, a) => (P.byte (w, 5); P.nat (w, tag); ty t; atom a)
        | Decon (tag, t, a) => (P.byte (w, 6); P.nat (w, tag); ty t; atom a)
        | ConTag a => (P.byte (w, 7); atom a)
        | NewExn s => (P.byte (w, 8); P.string (w, s))
        | BuiltinExn i => (P.byte (w, 9); P.int (w, i))
        | MkExn (a, b) => (P.byte (w, 10); atom a; atom b)
        | ExnCon a => (P.byte (w, 11); atom a)
        | ExnArg (t, a) => (P.byte (w, 12); ty t; atom a)
        | SetGlobal (g, a) => (P.byte (w, 13); stamp g; atom a)
      fun scheme ((vs, t) : scheme) = (list tvar vs; ty t)
      fun params ps = list (fn (x, t) => (stamp x; ty t)) ps
      fun fundef ({name = n, tyvars, params = ps, result, body} : fundef) =
        (stamp n; list tvar tyvars; params ps; ty result; exp body)
      and exp e =
        case e of
          Let (x, s, r, b) => (P.byte (w, 0); stamp x; scheme s; rhs r; exp b)
        | Fun (fs, b) => (P.byte (w, 1); list fundef fs; exp b)
        | Join (j, ps, b, sc) => (P.byte (w, 2); stamp j; params ps; exp b; exp sc)
        | Jump (j, args) => (P.byte (w, 3); stamp j; list atom args)
        | If (a, t, f) => (P.byte (w, 4); atom a; exp t; exp f)
        | Handle (b, x, h) => (P.byte (w, 5); exp b; stamp x; exp h)
        | Raise a => (P.byte (w, 6); atom a)
        | Return r => (P.byte (w, 7); rhs r)
        | Mark ((sp, frames), b) =>
            (P.byte (w, 8); span sp;
             list (fn {name = n, site} => (P.string (w, n); P.option (fn (_, s) => span s) (w, site))) frames;
             exp b)
      fun def d =
        case d of
          Val (g, s, e) => (P.byte (w, 0); stamp g; scheme s; exp e)
        | Funs fs => (P.byte (w, 1); list fundef fs)
        | Do (gs, e) => (P.byte (w, 2); list (fn (g, s) => (stamp g; scheme s)) gs; exp e)
      val () = list def mid
      val () = list (fn (s, {params = ps, cons}) =>
                       (tycon s; list tvar ps;
                        list (fn (tag, n, a) => (P.nat (w, tag); P.string (w, n); P.option (fn (_, t) => ty t) (w, a))) cons))
                    datatypes
      val () = list (fn (s, n) => (stamp s; P.string (w, n))) funNames
      val body = P.contents w
      val h = P.writer ()
      val () = (P.bytes (h, magic); P.nat (h, version); P.list P.string (h, List.rev (!identities));
                Vector.app (fn (_, n) => P.nat (h, !n)) privates; P.list P.string (h, List.rev (!files)))
    in P.contents h ^ body end

  (* a unit's Mid with its files named where they are now (UnitBasis.movedTo):
     its header written again, its body as it is *)
  fun relocate (s : string, file : string -> string) : string =
    let
      val r = P.reader s
      val () = if P.rbytes (r, 3) = magic then () else raise Bad "not a unit's Mid"
      val () = if P.rnat r = version then () else raise Bad "a unit's Mid of another version"
      val identities = P.rlist P.rstring r
      val counts = List.tabulate (3, fn _ => P.rnat r)
      val files = P.rlist P.rstring r
      val h = P.writer ()
      val () = (P.bytes (h, magic); P.nat (h, version); P.list P.string (h, identities);
                List.app (fn n => P.nat (h, n)) counts; P.list P.string (h, List.map file files))
    in P.contents h ^ String.extract (s, !(#pos r), NONE) end

  (* ---- reading ---- *)

  (* read (s, u, remap, file): the Mid of the unit u -- loaded, from the
     cache, against remap (UnitBasis.remapping) -- in the session's names,
     its sources named where they are now (file, as UnitBasis.movedTo) *)
  fun read (s : string, u : B.loaded, remap : B.remap, file : string -> string) : MidCanon.unitMid =
    let
      val r = P.reader s
      val () = if P.rbytes (r, 3) = magic then () else raise Bad "not a unit's Mid"
      val () = if P.rnat r = version then () else raise Bad "a unit's Mid of another version"
      val identities = Vector.fromList (P.rlist P.rstring r)
      val counts = Vector.tabulate (3, fn _ => P.rnat r)
      val files = Vector.fromList (List.map file (P.rlist P.rstring r))
      (* the unit's own that no unit after it names, given fresh names *)
      val fresh = Vector.tabulate (3, fn k => Array.tabulate (Vector.sub (counts, k), fn _ =>
                                                  let val c = B.counter k val n = !c in c := n + 1; n end))
      fun unitOf i =
        case StringMap.find (!B.byIdentity, i) of
          SOME lu => (lu, NONE)
        | NONE =>
            case List.find (fn (o', _, _) => o' = i) remap of
              SOME (_, new, maps) => (new, SOME maps)
            | NONE => raise B.Missing i
      fun name k () : int =
        case P.rbyte r of
          0 => P.rint r
        | 1 => Vector.sub (#base u, k) + P.rnat r
        | 2 =>
            let
              val i = P.rnat r
              val n = P.rnat r
              val () = if i >= Vector.length identities then raise Bad "a unit out of range" else ()
              val (lu, maps) = unitOf (Vector.sub (identities, i))
            in
              case maps of
                NONE => Vector.sub (#base lu, k) + n
              | SOME m => (case IntMap.find (Vector.sub (m, k), n) of
                             SOME s => s
                           | NONE => raise B.Missing (#identity lu ^ " (a name no path of it reaches)"))
            end
        | 3 => Array.sub (Vector.sub (fresh, k), P.rnat r)
        | _ => raise Bad "not a name"
      val stamp = name B.kStamp
      val tycon = name B.kTycon
      val tvar = name B.kTvar
      fun list f = P.rlist (fn _ => f ()) r
      fun ty () : Ty.ty =
        case P.rbyte r of
          0 => Ty.Gen (tvar ())
        | 1 => Ty.Var (tvar ())
        | 2 => let val s = tycon () val n = P.rstring r in Ty.Con (s, n, list ty) end
        | 3 => Ty.Tuple (list ty)
        | 4 => let val a = ty () in Ty.Arrow (a, ty ()) end
        | 5 => Ty.ExnCon
        | _ => raise Bad "not a type"
      fun const () : Lambda.const =
        let fun big () = case IntInf.fromString (P.rstring r) of SOME i => i | NONE => raise Bad "not a number"
        in
          case P.rbyte r of
            0 => Lambda.CInt (big ())
          | 1 => Lambda.CWord (big ())
          | 2 => Lambda.CInt64 (big ())
          | 3 => Lambda.CWord64 (big ())
          | 4 => Lambda.CReal (P.rstring r)
          | 5 => Lambda.CString (P.rstring r)
          | 6 => Lambda.CChar (P.rnat r)
          | _ => raise Bad "not a constant"
        end
      fun span () : Source.span =
        let
          val i = P.rnat r
          val () = if i >= Vector.length files then raise Bad "a file out of range" else ()
          val a = P.rnat r
          val b = P.rnat r
        in {file = Vector.sub (files, i), start = a, stop = b} end
      fun atom () : atom =
        case P.rbyte r of
          0 => let val x = stamp () in Var (x, list ty) end
        | 1 => let val x = stamp () in Global (x, list ty) end
        | 2 => let val c = const () in Const (c, ty ()) end
        | 3 => let val tag = P.rnat r in Con0 (tag, ty ()) end
        | 4 => Unit
        | _ => raise Bad "not an atom"
      fun rhs () : rhs =
        case P.rbyte r of
          0 => Atom (atom ())
        | 1 => let val f = atom () in App (f, list atom) end
        | 2 => let val n = P.rstring r val t = ty () in Prim (n, t, list atom) end
        | 3 => Tuple (list atom)
        | 4 => let val i = P.rnat r in Select (i, atom ()) end
        | 5 => let val tag = P.rnat r val t = ty () in Con (tag, t, atom ()) end
        | 6 => let val tag = P.rnat r val t = ty () in Decon (tag, t, atom ()) end
        | 7 => ConTag (atom ())
        | 8 => NewExn (P.rstring r)
        | 9 => BuiltinExn (P.rint r)
        | 10 => let val a = atom () in MkExn (a, atom ()) end
        | 11 => ExnCon (atom ())
        | 12 => let val t = ty () in ExnArg (t, atom ()) end
        | 13 => let val g = stamp () in SetGlobal (g, atom ()) end
        | _ => raise Bad "not a right-hand side"
      fun scheme () : scheme = let val vs = list tvar in (vs, ty ()) end
      fun params () = list (fn () => let val x = stamp () in (x, ty ()) end)
      fun fundef () : fundef =
        let
          val n = stamp ()
          val tyvars = list tvar
          val ps = params ()
          val result = ty ()
        in {name = n, tyvars = tyvars, params = ps, result = result, body = exp ()} end
      and exp () : exp =
        case P.rbyte r of
          0 => let val x = stamp () val s = scheme () val rh = rhs () in Let (x, s, rh, exp ()) end
        | 1 => let val fs = list fundef in Fun (fs, exp ()) end
        | 2 => let val j = stamp () val ps = params () val b = exp () in Join (j, ps, b, exp ()) end
        | 3 => let val j = stamp () in Jump (j, list atom) end
        | 4 => let val a = atom () val t = exp () in If (a, t, exp ()) end
        | 5 => let val b = exp () val x = stamp () in Handle (b, x, exp ()) end
        | 6 => Raise (atom ())
        | 7 => Return (rhs ())
        | 8 =>
            let
              val sp = span ()
              val frames = list (fn () => let val n = P.rstring r in {name = n, site = P.roption (fn _ => span ()) r} end)
            in Mark ((sp, frames), exp ()) end
        | _ => raise Bad "not an expression"
      fun def () : def =
        case P.rbyte r of
          0 => let val g = stamp () val s = scheme () in Val (g, s, exp ()) end
        | 1 => Funs (list fundef)
        | 2 => let val gs = list (fn () => let val g = stamp () in (g, scheme ()) end) in Do (gs, exp ()) end
        | _ => raise Bad "not a definition"
      val mid = list def
      val datatypes =
        list (fn () =>
                let
                  val s = tycon ()
                  val ps = list tvar
                  val cons = list (fn () => let val tag = P.rnat r val n = P.rstring r
                                            in (tag, n, P.roption (fn _ => ty ()) r) end)
                in (s, {params = ps, cons = cons}) end)
      val funNames = list (fn () => let val s = stamp () in (s, P.rstring r) end)
    in
      if P.atEnd r then () else raise Bad "bytes after a unit's Mid";
      {mid = mid, datatypes = datatypes, funNames = funNames}
    end
    handle Overflow => raise Bad "a number out of range"
         | Subscript => raise Bad "out of range"
end
