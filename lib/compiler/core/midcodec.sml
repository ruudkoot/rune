(* A function of Mid in bytes, its names written and read by the caller
   (functors-units.md, M6b; a prototype, under --functors=functions): what a
   unit's basis keeps of a functor marked to be inlined (UnitBasis.funcode),
   so that a unit that applies it expands its body (Expand). The names a
   function binds -- its parameters, its locals, its join points -- are its
   own, numbered from 0 in the order the writing meets them, and read back
   as the names the reader gives (fresh ones); every other name, a global, a
   type name, a type variable, is the caller's to write and read. The
   encoding is UnitMid's, a type written once and then by its number. *)
structure MidCodec =
struct
  structure P = Pickle
  open Mid

  type namer = {stamp : int -> unit, tycon : int -> unit, tvar : int -> unit, file : string -> unit}
  type unnamer = {stamp : unit -> int, tycon : unit -> int, tvar : unit -> int, file : unit -> string, local' : int -> int}

  exception Bad of string

  (* the names f binds *)
  fun binders (f : fundef) : unit IntTable.table =
    let
      val t : unit IntTable.table = IntTable.table 256
      fun bind x = IntTable.insert (t, x, ())
      fun fundef ({name, params, body, ...} : fundef) = (bind name; List.app (bind o #1) params; exp body)
      and exp e =
        case e of
          Let (x, _, _, b) => (bind x; exp b)
        | Fun (fs, b) => (List.app fundef fs; exp b)
        | Join (j, ps, b, sc) => (bind j; List.app (bind o #1) ps; exp b; exp sc)
        | If (_, a, b) => (exp a; exp b)
        | Handle (b, x, h) => (exp b; bind x; exp h)
        | Mark (_, b) => exp b
        | _ => ()
    in List.app (bind o #1) (#params f); exp (#body f); t end

  fun write (w : P.writer, {stamp = global, tycon, tvar, file} : namer) (f : fundef) : unit =
    let
      val own = binders f
      val locals : int IntTable.table = IntTable.table 256
      val nlocals = ref 0
      (* its own names, newest first, in the order met *)
      val met : int list ref = ref []
      fun stamp x =
        if isSome (IntTable.find (own, x)) then
          (P.byte (w, 0);
           P.nat (w, case IntTable.find (locals, x) of
                       SOME i => i
                     | NONE => let val i = !nlocals
                               in IntTable.insert (locals, x, i); nlocals := i + 1; met := x :: !met; i end))
        else (P.byte (w, 1); global x)
      fun list g l = P.list (fn (_, a) => g a) (w, l)
      val written : int IntTable.table = IntTable.table 256
      val nwritten = ref 0
      fun ty t =
        case IntTable.find (written, Ty.id t) of
          SOME k => (P.byte (w, 6); P.nat (w, k))
        | NONE =>
            ((case Ty.view t of
                Ty.Gen i => (P.byte (w, 0); tvar i)
              | Ty.Var i => (P.byte (w, 1); tvar i)
              | Ty.Con (s, n, args) => (P.byte (w, 2); tycon s; P.string (w, n); list ty args)
              | Ty.Tuple ts => (P.byte (w, 3); list ty ts)
              | Ty.Arrow (a, b) => (P.byte (w, 4); ty a; ty b)
              | Ty.ExnCon => P.byte (w, 5));
             IntTable.insert (written, Ty.id t, !nwritten);
             nwritten := !nwritten + 1)
      fun const (c : Lambda.const) =
        case c of
          Lambda.CInt i => (P.byte (w, 0); P.string (w, IntInf.toString i))
        | Lambda.CWord i => (P.byte (w, 1); P.string (w, IntInf.toString i))
        | Lambda.CInt64 i => (P.byte (w, 2); P.string (w, IntInf.toString i))
        | Lambda.CWord64 i => (P.byte (w, 3); P.string (w, IntInf.toString i))
        | Lambda.CReal s => (P.byte (w, 4); P.string (w, s))
        | Lambda.CString s => (P.byte (w, 5); P.string (w, s))
        | Lambda.CChar n => (P.byte (w, 6); P.nat (w, n))
      fun span ({file = f, start, stop} : Source.span) = (file f; P.nat (w, start); P.nat (w, stop))
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
    in
      (* the function's name is the caller's (a global), its parameters its own *)
      global (#name f);
      list tvar (#tyvars f); params (#params f); ty (#result f); exp (#body f);
      (* the names of the functions it binds (Translate.funNames, by their
         first parameter), by its own numbers *)
      list (fn (x, n) => (stamp x; P.string (w, n)))
           (List.mapPartial (fn x => Option.map (fn n => (x, n)) (IntMap.find (!Translate.funNames, x))) (List.rev (!met)))
    end

  (* the function, its own names given by local' (from their numbers), and
     the names of the functions it binds *)
  fun read (r : P.reader, {stamp = global, tycon, tvar, file, local'} : unnamer) : fundef * (int * string) list =
    let
      fun bad m = raise Bad m
      fun stamp () = case P.rbyte r of 0 => local' (P.rnat r) | 1 => global () | _ => bad "not a name"
      fun list f = P.rlist (fn _ => f ()) r
      val read' : Ty.ty IntTable.table = IntTable.table 256
      val nread = ref 0
      fun ty () : Ty.ty =
        case P.rbyte r of
          6 => (case IntTable.find (read', P.rnat r) of SOME t => t | NONE => bad "a type before it is written")
        | b =>
            let
              val t =
                case b of
                  0 => Ty.gen (tvar ())
                | 1 => Ty.var (tvar ())
                | 2 => let val s = tycon () val n = P.rstring r in Ty.con (s, n, list ty) end
                | 3 => Ty.tuple (list ty)
                | 4 => let val a = ty () in Ty.arrow (a, ty ()) end
                | 5 => Ty.exnCon
                | _ => bad "not a type"
            in IntTable.insert (read', !nread, t); nread := !nread + 1; t end
      fun int s = case IntInf.fromString s of SOME i => i | NONE => bad "not a number"
      fun const () =
        case P.rbyte r of
          0 => Lambda.CInt (int (P.rstring r))
        | 1 => Lambda.CWord (int (P.rstring r))
        | 2 => Lambda.CInt64 (int (P.rstring r))
        | 3 => Lambda.CWord64 (int (P.rstring r))
        | 4 => Lambda.CReal (P.rstring r)
        | 5 => Lambda.CString (P.rstring r)
        | 6 => Lambda.CChar (P.rnat r)
        | _ => bad "not a constant"
      fun span () = let val f = file () val a = P.rnat r in {file = f, start = a, stop = P.rnat r} : Source.span end
      fun atom () =
        case P.rbyte r of
          0 => let val x = stamp () in Var (x, list ty) end
        | 1 => let val x = stamp () in Global (x, list ty) end
        | 2 => let val c = const () in Const (c, ty ()) end
        | 3 => let val tag = P.rnat r in Con0 (tag, ty ()) end
        | 4 => Unit
        | _ => bad "not an atom"
      fun rhs () =
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
        | _ => bad "not a step"
      fun scheme () = let val vs = list tvar in (vs, ty ()) end
      fun params () = list (fn () => let val x = stamp () in (x, ty ()) end)
      fun fundef () : fundef =
        let val n = stamp () val tvs = list tvar val ps = params () val res = ty ()
        in {name = n, tyvars = tvs, params = ps, result = res, body = exp ()} end
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
        | 8 => let val sp = span ()
                   val frames = list (fn () => let val n = P.rstring r in {name = n, site = P.roption (fn _ => span ()) r} end)
               in Mark ((sp, frames), exp ()) end
        | _ => bad "not an expression"
      val name = global ()
      val tvs = list tvar
      val ps = params ()
      val res = ty ()
      val body = exp ()
      val names = list (fn () => let val x = stamp () in (x, P.rstring r) end)
    in ({name = name, tyvars = tvs, params = ps, result = res, body = body}, names) end
end
