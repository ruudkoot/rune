(* HsIface: a unit's interface written as bytes and read back. A number
   is a varint, seven bits a byte, the least first, a whole number
   zigzagged; a string is the number of its place in the table of strings
   the text begins with, each written once, in the order the interface
   first names it, so that the keys and names an interface repeats cost a
   number each to write and to read, and are one string each once read; a
   list is its length and its items; a choice is a byte. *)
structure HsIface :> HS_IFACE =
struct
  structure T = HsTypes
  structure Mo = HsModules

  type t = {modules : HsModIface.t list, unfoldings : string list}

  exception Bad of string

  val magic = "HsIface"
  val version = 2

  (* ---- writing ---- *)

  (* bytes gathered in place, in an array that doubles when it is full *)
  type buffer = {bytes : CharArray.array ref, used : int ref}
  fun buffer () : buffer = {bytes = ref (CharArray.array (256, #"\000")), used = ref 0}
  fun room ({bytes, used} : buffer, n : int) =
    if !used + n <= CharArray.length (!bytes) then ()
    else
      let val bigger = CharArray.array (Int.max (2 * CharArray.length (!bytes), !used + n), #"\000")
      in CharArray.copy {src = !bytes, dst = bigger, di = 0}; bytes := bigger end
  fun byte (b as {bytes, used} : buffer, n : int) = (room (b, 1); CharArray.update (!bytes, !used, Char.chr n); used := !used + 1)
  fun chars (b as {bytes, used} : buffer, s : string) =
    (room (b, size s); CharArray.copyVec {src = s, dst = !bytes, di = !used}; used := !used + size s)
  fun contents ({bytes, used} : buffer) = String.substring (CharArray.vector (!bytes), 0, !used)
  fun nat (b, n : int) = if n < 128 then byte (b, n) else (byte (b, 128 + n mod 128); nat (b, n div 128))

  (* a writer: the interface's bytes, and its strings by their places *)
  type w = {out : buffer, places : int HsStringMap.map ref, strings : string list ref, count : int ref}
  fun int (w : w, n : int) = nat (#out w, if n >= 0 then 2 * n else ~2 * n - 1)
  fun str (w : w, s : string) =
    case HsStringMap.find (!(#places w), s) of
      SOME i => nat (#out w, i)
    | NONE =>
        let val i = !(#count w)
        in #places w := HsStringMap.insert (!(#places w), s, i); #strings w := s :: !(#strings w); #count w := i + 1;
           nat (#out w, i)
        end
  fun tag (w : w, c : char) = byte (#out w, Char.ord c)
  fun bool (w, b) = tag (w, if b then #"t" else #"f")
  fun list f (w : w, xs) = (nat (#out w, length xs); List.app (fn x => f (w, x)) xs)
  fun option f (w, x) = case x of NONE => tag (w, #"n") | SOME v => (tag (w, #"s"); f (w, v))

  fun kind (w, k : T.kind) =
    case k of
      T.KStar => tag (w, #"*")
    | T.KFun (a, b) => (tag (w, #"F"); kind (w, a); kind (w, b))
    | T.KVar (ref (T.KLink k')) => kind (w, k')
    | T.KVar (ref (T.KFree _)) => tag (w, #"*")   (* Haskell 98 defaults an unsolved kind to * (4.6) *)
  fun ty (w, t : T.ty) =
    case t of
      T.TCon c => (tag (w, #"C"); str (w, c))
    | T.TAp (a, b) => (tag (w, #"A"); ty (w, a); ty (w, b))
    | T.TGen i => (tag (w, #"G"); int (w, i))
    | T.TMeta (ref (T.Link t')) => ty (w, t')
    | T.TMeta (ref (T.Free {id, ...})) => raise Bad ("an interface's type holds the unsolved variable " ^ Int.toString id)
    | T.TRigid {id, name} => (tag (w, #"R"); int (w, id); str (w, name))
  fun pred (w, {cls, ty = t} : T.pred) = (str (w, cls); ty (w, t))
  fun scheme (w, {vars, ctx, ty = t} : T.scheme) = (int (w, vars); list pred (w, ctx); ty (w, t))
  fun space (w, s) = tag (w, case s of Mo.Value => #"v" | Mo.Type => #"t")
  fun entity (w, {space = sp, home, name} : Mo.entity) = (space (w, sp); str (w, home); str (w, name))
  fun sort (w, s) =
    tag (w, case s of Mo.Var => #"v" | Mo.Con => #"c" | Mo.Field => #"f" | Mo.Method => #"m" | Mo.TyCon => #"t"
                    | Mo.Synonym => #"s" | Mo.Class => #"k")
  fun def (w, {entity = e, sort = s, parent, arity, span = {file, start, stop}} : Mo.def) =
    (entity (w, e); sort (w, s); option entity (w, parent); int (w, arity); str (w, file); int (w, start); int (w, stop))
  fun fixity (w, (k, (f, p))) =
    (str (w, k); tag (w, case f of HsAst.Infix => #"n" | HsAst.Infixl => #"l" | HsAst.Infixr => #"r"); int (w, p))

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
     list (fn (w, (k, {tycon, arity, fields})) => (str (w, k); str (w, tycon); int (w, arity); list str (w, fields))) (w, cons);
     list (fn (w, (k, {tycon, ty = t, cons})) =>
             (str (w, k); str (w, tycon); ty (w, t); list (fn (w, (c, i)) => (str (w, c); int (w, i))) (w, cons)))
          (w, fields);
     list (fn (w, (k, {cls, scheme = s})) => (str (w, k); str (w, cls); scheme (w, s))) (w, methods))

  fun moduleTo (w, {id, exports, defs, fixities, checked} : HsModIface.t) =
    (str (w, id); list entity (w, exports); list def (w, defs); list fixity (w, fixities); part (w, checked))

  (* the mark and the version, the table of strings, then what f writes *)
  fun written f x =
    let
      val w = {out = buffer (), places = ref HsStringMap.empty, strings = ref [], count = ref 0}
      val () = f (w, x)
      val all = buffer ()
      val () = (nat (all, size magic); chars (all, magic); nat (all, version))
      val () = (nat (all, !(#count w)); List.app (fn s => (nat (all, size s); chars (all, s))) (List.rev (!(#strings w))))
    in
      contents all ^ contents (#out w)
    end

  fun encodeModule m = written moduleTo m
  fun encode ({modules, unfoldings} : t) =
    written (fn (w, ()) => (list moduleTo (w, modules); list str (w, unfoldings))) ()

  (* ---- reading ---- *)

  type r = {s : string, pos : int ref, strings : string vector}
  fun bad (r : r, what) = raise Bad ("at " ^ Int.toString (!(#pos r)) ^ ": " ^ what ^ " is wanted")
  fun rbyte (r as {s, pos, ...} : r) =
    if !pos >= size s then bad (r, "a byte") else Char.ord (String.sub (s, !pos)) before pos := !pos + 1
  fun rnat r =
    let
      fun go (scale, acc, k) =
        let val b = rbyte r
        in
          if b < 128 then acc + scale * b
          else if k = 4 then bad (r, "a number in range")
          else go (scale * 128, acc + scale * (b - 128), k + 1)
        end
    in go (1, 0, 0) handle Overflow => bad (r, "a number in range") end
  fun rint r = let val n = rnat r in if n mod 2 = 0 then n div 2 else ~(n div 2) - 1 end
  fun rstr (r as {strings, ...} : r) =
    let val i = rnat r
    in if i < Vector.length strings then Vector.sub (strings, i) else bad (r, "a string of the table") end
  fun rtag r = Char.chr (rbyte r)
  fun rbool r = case rtag r of #"t" => true | #"f" => false | _ => bad (r, "t or f")
  fun rlist f r =
    let
      val n = rnat r
      fun go (0, acc) = List.rev acc
        | go (k, acc) = go (k - 1, f r :: acc)
    in go (n, []) end
  fun roption f r = case rtag r of #"n" => NONE | #"s" => SOME (f r) | _ => bad (r, "n or s")

  fun rkind r =
    case rtag r of
      #"*" => T.KStar
    | #"F" => let val a = rkind r in T.KFun (a, rkind r) end
    | _ => bad (r, "a kind")
  fun rty r =
    case rtag r of
      #"C" => T.TCon (rstr r)
    | #"A" => let val a = rty r in T.TAp (a, rty r) end
    | #"G" => T.TGen (rint r)
    | #"R" => let val i = rint r in T.TRigid {id = i, name = rstr r} end
    | _ => bad (r, "a type")
  fun rpred r = let val c = rstr r in {cls = c, ty = rty r} end
  fun rscheme r = let val v = rint r val c = rlist rpred r in {vars = v, ctx = c, ty = rty r} end
  fun rspace r = case rtag r of #"v" => Mo.Value | #"t" => Mo.Type | _ => bad (r, "v or t")
  fun rentity r = let val sp = rspace r val h = rstr r in {space = sp, home = h, name = rstr r} end
  fun rsort r =
    case rtag r of
      #"v" => Mo.Var | #"c" => Mo.Con | #"f" => Mo.Field | #"m" => Mo.Method | #"t" => Mo.TyCon | #"s" => Mo.Synonym
    | #"k" => Mo.Class | _ => bad (r, "a sort")
  fun rdef r =
    let
      val e = rentity r val s = rsort r val p = roption rentity r val a = rint r
      val file = rstr r val start = rint r val stop = rint r
    in {entity = e, sort = s, parent = p, arity = a, span = {file = file, start = start, stop = stop}} end
  fun rfixity r =
    let
      val k = rstr r
      val f = case rtag r of #"n" => HsAst.Infix | #"l" => HsAst.Infixl | #"r" => HsAst.Infixr | _ => bad (r, "a fixity")
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
      val cons = rlist (fn r => let val k = rstr r val tycon = rstr r val arity = rint r
                                in (k, {tycon = tycon, arity = arity, fields = rlist rstr r}) end) r
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

  (* the mark, the version and the table of strings, then what f reads,
     to the end *)
  fun reading f s =
    let
      val r0 = {s = s, pos = ref 0, strings = Vector.fromList []}
      fun rchars n =
        let val p = !(#pos r0)
        in if n < 0 orelse p + n > size s then bad (r0, "a string") else String.substring (s, p, n) before #pos r0 := p + n end
      val () = if rchars (rnat r0) = magic then () else bad (r0, "HsIface's mark")
      val () = if rnat r0 = version then () else bad (r0, "HsIface's version " ^ Int.toString version)
      val strings = Vector.fromList (List.tabulate (rnat r0, fn _ => rchars (rnat r0)))
      val r = {s = s, pos = #pos r0, strings = strings}
      val x = f r
    in if !(#pos r) = size s then x else bad (r, "the end") end

  fun decodeModule s = reading rmodule s
  fun decode s =
    reading (fn r =>
               let val modules = rlist rmodule r
               in {modules = modules, unfoldings = rlist rstr r} end)
            s
end
