(* HsIface: a unit's interface written as text and read back. Words
   apart by spaces: a number as its digits, a string as its length, a
   colon and its bytes, a list as its length and its items, a choice as a
   letter. *)
structure HsIface :> HS_IFACE =
struct
  structure T = HsTypes
  structure Mo = HsModules

  type t = {modules : HsModIface.t list, desugar : string, unfoldings : string list}

  exception Bad of string

  val magic = "HsIface"
  val version = 2

  (* ---- writing ---- *)

  type w = string list ref
  fun put (w : w, s : string) = w := s :: !w
  fun int (w, n : int) = put (w, Int.toString n ^ " ")
  fun str (w, s : string) = put (w, Int.toString (size s) ^ ":" ^ s ^ " ")
  fun tag (w, c : string) = put (w, c ^ " ")
  fun bool (w, b) = tag (w, if b then "t" else "f")
  fun list f (w, xs) = (int (w, length xs); List.app (fn x => f (w, x)) xs)
  fun option f (w, x) = case x of NONE => tag (w, "n") | SOME v => (tag (w, "s"); f (w, v))

  fun kind (w, k : T.kind) =
    case k of
      T.KStar => tag (w, "*")
    | T.KFun (a, b) => (tag (w, "F"); kind (w, a); kind (w, b))
    | T.KVar (ref (T.KLink k')) => kind (w, k')
    | T.KVar (ref (T.KFree _)) => tag (w, "*")   (* Haskell 98 defaults an unsolved kind to * (4.6) *)
  fun ty (w, t : T.ty) =
    case t of
      T.TCon c => (tag (w, "C"); str (w, c))
    | T.TAp (a, b) => (tag (w, "A"); ty (w, a); ty (w, b))
    | T.TGen i => (tag (w, "G"); int (w, i))
    | T.TMeta (ref (T.Link t')) => ty (w, t')
    | T.TMeta (ref (T.Free {id, ...})) => raise Bad ("an interface's type holds the unsolved variable " ^ Int.toString id)
    | T.TRigid {id, name} => (tag (w, "R"); int (w, id); str (w, name))
  fun pred (w, {cls, ty = t} : T.pred) = (str (w, cls); ty (w, t))
  fun scheme (w, {vars, ctx, ty = t} : T.scheme) = (int (w, vars); list pred (w, ctx); ty (w, t))
  fun space (w, s) = tag (w, case s of Mo.Value => "v" | Mo.Type => "t")
  fun entity (w, {space = sp, home, name} : Mo.entity) = (space (w, sp); str (w, home); str (w, name))
  fun sort (w, s) =
    tag (w, case s of Mo.Var => "v" | Mo.Con => "c" | Mo.Field => "f" | Mo.Method => "m" | Mo.TyCon => "t"
                    | Mo.Synonym => "s" | Mo.Class => "k")
  fun def (w, {entity = e, sort = s, parent, arity, span = {file, start, stop}} : Mo.def) =
    (entity (w, e); sort (w, s); option entity (w, parent); int (w, arity); str (w, file); int (w, start); int (w, stop))
  fun fixity (w, (k, (f, p))) =
    (str (w, k); tag (w, case f of HsAst.Infix => "n" | HsAst.Infixl => "l" | HsAst.Infixr => "r"); int (w, p))

  fun part (w, {values, tycons, classes, instances, cons, fields, methods} : HsInfer.part) =
    (list (fn (w, (k, s)) => (str (w, k); scheme (w, s))) (w, values);
     list (fn (w, {key, kind = k, params, synonym, cons, newtype}) =>
             (str (w, key); kind (w, k); int (w, params); option ty (w, synonym); list str (w, cons); bool (w, newtype)))
          (w, tycons);
     list (fn (w, {key, supers, methods, kind = k}) => (str (w, key); list str (w, supers); list str (w, methods); kind (w, k)))
          (w, classes);
     list (fn (w, {id, cls, tycon, vars, ctx, derived, home}) =>
             (str (w, id); str (w, cls); str (w, tycon); int (w, vars); list pred (w, ctx); bool (w, derived); str (w, home)))
          (w, instances);
     list (fn (w, (k, {tycon, arity, fields, strict})) =>
             (str (w, k); str (w, tycon); int (w, arity); list str (w, fields); list bool (w, strict)))
          (w, cons);
     list (fn (w, (k, {tycon, ty = t, cons})) =>
             (str (w, k); str (w, tycon); ty (w, t); list (fn (w, (c, i)) => (str (w, c); int (w, i))) (w, cons)))
          (w, fields);
     list (fn (w, (k, {cls, scheme = s})) => (str (w, k); str (w, cls); scheme (w, s))) (w, methods))

  fun moduleTo (w, {id, exports, defs, fixities, checked} : HsModIface.t) =
    (str (w, id); list entity (w, exports); list def (w, defs); list fixity (w, fixities); part (w, checked))

  fun written f x = let val w = ref [] in f (w, x); String.concat (List.rev (!w)) end

  fun encodeModule m = written moduleTo m
  fun encode ({modules, desugar, unfoldings} : t) =
    written (fn (w, ()) => (str (w, magic); int (w, version); list moduleTo (w, modules); str (w, desugar);
                            list str (w, unfoldings)))
            ()

  (* ---- reading ---- *)

  type r = {s : string, pos : int ref}
  fun bad (r : r, what) = raise Bad ("at " ^ Int.toString (!(#pos r)) ^ ": " ^ what ^ " is wanted")
  fun word (r as {s, pos} : r) : string =
    let
      fun stop i = if i < size s andalso String.sub (s, i) <> #" " then stop (i + 1) else i
      val i = !pos
      val j = stop i
    in
      if j = i orelse j >= size s then bad (r, "a word")
      else (pos := j + 1; String.substring (s, i, j - i))
    end
  fun rint r = case Int.fromString (word r) of SOME n => n | NONE => bad (r, "a number")
  fun rstr (r as {s, pos} : r) : string =
    let
      fun colon i = if i < size s andalso String.sub (s, i) <> #":" then colon (i + 1) else i
      val i = !pos
      val c = colon i
      val n = if c >= size s then bad (r, "a string") else case Int.fromString (String.substring (s, i, c - i)) of
                                                              SOME n => n | NONE => bad (r, "a string's length")
    in
      if c + 1 + n + 1 > size s orelse String.sub (s, c + 1 + n) <> #" " then bad (r, "a string")
      else (pos := c + 1 + n + 1; String.substring (s, c + 1, n))
    end
  fun rtag r = word r
  fun rbool r = case rtag r of "t" => true | "f" => false | _ => bad (r, "t or f")
  fun rlist f r = List.tabulate (rint r, fn _ => f r)
  fun roption f r = case rtag r of "n" => NONE | "s" => SOME (f r) | _ => bad (r, "n or s")

  fun rkind r =
    case rtag r of
      "*" => T.KStar
    | "F" => let val a = rkind r in T.KFun (a, rkind r) end
    | _ => bad (r, "a kind")
  fun rty r =
    case rtag r of
      "C" => T.TCon (rstr r)
    | "A" => let val a = rty r in T.TAp (a, rty r) end
    | "G" => T.TGen (rint r)
    | "R" => let val i = rint r in T.TRigid {id = i, name = rstr r} end
    | _ => bad (r, "a type")
  fun rpred r = let val c = rstr r in {cls = c, ty = rty r} end
  fun rscheme r = let val v = rint r val c = rlist rpred r in {vars = v, ctx = c, ty = rty r} end
  fun rspace r = case rtag r of "v" => Mo.Value | "t" => Mo.Type | _ => bad (r, "v or t")
  fun rentity r = let val sp = rspace r val h = rstr r in {space = sp, home = h, name = rstr r} end
  fun rsort r =
    case rtag r of
      "v" => Mo.Var | "c" => Mo.Con | "f" => Mo.Field | "m" => Mo.Method | "t" => Mo.TyCon | "s" => Mo.Synonym
    | "k" => Mo.Class | _ => bad (r, "a sort")
  fun rdef r =
    let
      val e = rentity r val s = rsort r val p = roption rentity r val a = rint r
      val file = rstr r val start = rint r val stop = rint r
    in {entity = e, sort = s, parent = p, arity = a, span = {file = file, start = start, stop = stop}} end
  fun rfixity r =
    let
      val k = rstr r
      val f = case rtag r of "n" => HsAst.Infix | "l" => HsAst.Infixl | "r" => HsAst.Infixr | _ => bad (r, "a fixity")
    in (k, (f, rint r)) end
  fun rpart r : HsInfer.part =
    let
      val values = rlist (fn r => let val k = rstr r in (k, rscheme r) end) r
      val tycons = rlist (fn r => let val key = rstr r val k = rkind r val params = rint r val syn = roption rty r
                                      val cons = rlist rstr r
                                  in {key = key, kind = k, params = params, synonym = syn, cons = cons, newtype = rbool r} end) r
      val classes = rlist (fn r => let val key = rstr r val supers = rlist rstr r val methods = rlist rstr r
                                   in {key = key, supers = supers, methods = methods, kind = rkind r} end) r
      val instances = rlist (fn r => let val id = rstr r val cls = rstr r val tycon = rstr r val vars = rint r
                                         val ctx = rlist rpred r val derived = rbool r
                                     in {id = id, cls = cls, tycon = tycon, vars = vars, ctx = ctx, derived = derived,
                                         home = rstr r} end) r
      val cons = rlist (fn r => let val k = rstr r val tycon = rstr r val arity = rint r val fields = rlist rstr r
                                in (k, {tycon = tycon, arity = arity, fields = fields, strict = rlist rbool r}) end) r
      val fields = rlist (fn r => let val k = rstr r val tycon = rstr r val t = rty r
                                  in (k, {tycon = tycon, ty = t, cons = rlist (fn r => let val c = rstr r in (c, rint r) end) r})
                                  end) r
      val methods = rlist (fn r => let val k = rstr r val cls = rstr r in (k, {cls = cls, scheme = rscheme r}) end) r
    in
      {values = values, tycons = tycons, classes = classes, instances = instances, cons = cons, fields = fields,
       methods = methods}
    end
  fun rmodule r : HsModIface.t =
    let
      val id = rstr r val exports = rlist rentity r val defs = rlist rdef r val fixities = rlist rfixity r
    in {id = id, exports = exports, defs = defs, fixities = fixities, checked = rpart r} end

  fun reading f s =
    let
      val r = {s = s, pos = ref 0}
      val x = f r
    in if !(#pos r) = size s then x else bad (r, "the end") end

  fun decodeModule s = reading rmodule s
  fun decode s =
    reading (fn r =>
               let
                 val () = if rstr r = magic then () else bad (r, "HsIface's mark")
                 val () = if rint r = version then () else bad (r, "HsIface's version " ^ Int.toString version)
                 val modules = rlist rmodule r
                 val desugar = rstr r
               in {modules = modules, desugar = desugar, unfoldings = rlist rstr r} end)
            s
end
