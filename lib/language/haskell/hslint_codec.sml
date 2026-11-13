(* HsLint's part of a unit as bytes (the haskell98 roadmap's M16, D45's
   units; the lead's ruling 66 (a)): what one check inferred alone, its
   environment's entries, its findings and the target check's data, kept in
   a unit's entry of the store and read back for the units after it.

   The form is Pickle's (lib/compiler/util/pickle.sml), which this library
   does not see: a number a varint, natural ones as themselves and others
   zigzagged, a string by its length, a list by its length; a magic word
   first. Types are written as the inference left them, a variable resolved
   to its type; one still free comes back a fresh variable of its kind, the
   same for each of its occurrences. Declaration bodies are not written:
   the units after one never infer its instances or class defaults again. *)
structure HsLintCodec =
struct
  structure T = HsLintTypes
  structure C = HsLintClasses
  structure E = HsLintEnv
  structure I = HsLintInfer
  structure G = HsLintTarget
  structure M = HsStringMap
  structure K = Core

  exception Bad of string

  (* what one check inferred alone *)
  type part = {modules : string list, env : E.saved, infer : I.saved, counter : int, target : G.target}

  val magic = "rhc-hslint-part-2"

  (* ---- writing ---- *)

  type writer = string list ref

  fun byte (w : writer, n : int) = w := String.str (Char.chr n) :: !w
  fun nat (w : writer, n : int) =
    if n < 0 then raise Fail "HsLintCodec.nat: a negative number"
    else if n < 128 then byte (w, n)
    else (byte (w, 128 + n mod 128); nat (w, n div 128))
  fun int (w : writer, n : int) = nat (w, if n >= 0 then 2 * n else ~2 * n - 1)
  fun bool (w : writer, b : bool) = byte (w, if b then 1 else 0)
  fun string (w : writer, s : string) = (nat (w, size s); w := s :: !w)
  fun list f (w : writer, xs) = (nat (w, length xs); List.app (fn x => f (w, x)) xs)
  fun option f (w : writer, x) = case x of NONE => byte (w, 0) | SOME v => (byte (w, 1); f (w, v))
  fun map f (w : writer, m) = list (fn (w, (k, v)) => (string (w, k); f (w, v))) (w, M.listItems m)

  fun id (w, {qual, name} : T.id) = (string (w, qual); string (w, name))
  fun kind (w, k) =
    case k of
      T.Star => byte (w, 0)
    | T.KFun (a, b) => (byte (w, 1); kind (w, a); kind (w, b))
  fun ty (w, t) =
    case T.prune t of
      T.TVar (T.TV {id = n, kind = k, ...}) => (byte (w, 0); nat (w, n); kind (w, k))
    | T.TCon {id = i, kind = k} => (byte (w, 1); id (w, i); kind (w, k))
    | T.TAp (a, b) => (byte (w, 2); ty (w, a); ty (w, b))
    | T.TGen n => (byte (w, 3); nat (w, n))
  fun pred (w, T.IsIn (c, t)) = (id (w, c); ty (w, t))
  fun scheme (w, T.Forall (ks, (ps, t))) = (list kind (w, ks); list pred (w, ps); ty (w, t))
  fun span (w, {file, start, stop} : HsSource.span) = (string (w, file); nat (w, start); nat (w, stop))

  fun tydef (w, d) =
    case d of
      E.Data {kind = k, cons, newtype} => (byte (w, 0); kind (w, k); list id (w, cons); bool (w, newtype))
    | E.Synonym {kind = k, arity, rhs} => (byte (w, 1); kind (w, k); nat (w, arity); ty (w, rhs))
  fun con (w, {id = i, scheme = s, arity, fields, strict, tycon, args, context} : E.con) =
    (id (w, i); scheme (w, s); nat (w, arity); list (option id) (w, fields); list bool (w, strict); id (w, tycon);
     list ty (w, args); list pred (w, context))
  fun field (w, {id = i, tycon, scheme = s, cons} : E.field) =
    (id (w, i); id (w, tycon); scheme (w, s); list (fn (w, (c, n)) => (id (w, c); nat (w, n))) (w, cons))
  fun method (w, {id = i, class, scheme = s} : E.method) = (id (w, i); id (w, class); scheme (w, s))
  fun instance (w, {class, head, context, arity, module, span = sp, ...} : E.instance) =
    (id (w, class); ty (w, head); list pred (w, context); nat (w, arity); string (w, module); span (w, sp))
  fun classDecl (w, {class, module, ...} : E.classDecl) = (id (w, class); string (w, module))
  fun cls (w, {id = i, kind = k, supers, std} : C.class) = (id (w, i); kind (w, k); list id (w, supers); bool (w, std))
  fun inst (w, {head, context, arity, span = sp, derived} : C.inst) =
    (pred (w, head); list pred (w, context); nat (w, arity); span (w, sp); bool (w, derived))

  fun env (w, s : E.saved) =
    (map tydef (w, #tydefs s); map con (w, #cons s); map field (w, #fields s); map method (w, #methods s);
     map kind (w, #classKinds s); map (list ty) (w, #defaults s); list instance (w, #instances s);
     list classDecl (w, #classDecls s); string (w, #prelude s); map bool (w, #programModules s);
     map cls (w, #classes s); map (list inst) (w, #insts s); option id (w, #numId s);
     map (list string) (w, #imports s); map string (w, #fileModule s))

  fun default (w, {module, span = sp, preds, choice, ruleTwo} : I.default) =
    (string (w, module); span (w, sp); list pred (w, preds); ty (w, choice); bool (w, ruleTwo))
  fun binding (w, {module, id = i, scheme = s, signed, restricted, span = sp} : I.binding) =
    (string (w, module); id (w, i); scheme (w, s); bool (w, signed); bool (w, restricted); span (w, sp))
  fun infer (w, s : I.saved) =
    (map scheme (w, #tops s); list ty (w, #topMono s); list default (w, #chosen s); list binding (w, #bindings s))

  fun ckind (w, k) =
    case k of
      K.Star => byte (w, 0)
    | K.Unlifted => byte (w, 1)
    | K.Arrow (a, b) => (byte (w, 2); ckind (w, a); ckind (w, b))
  fun cty (w, t) =
    case t of
      K.TVar v => (byte (w, 0); string (w, v))
    | K.TCon c => (byte (w, 1); string (w, c))
    | K.TApp (a, b) => (byte (w, 2); cty (w, a); cty (w, b))
    | K.TFun (a, b) => (byte (w, 3); cty (w, a); cty (w, b))
    | K.TForall (v, k, b) => (byte (w, 4); string (w, v); ckind (w, k); cty (w, b))
    | K.TEval a => (byte (w, 5); cty (w, a))
    | K.TUTuple ts => (byte (w, 6); list cty (w, ts))
  fun valued (w, (x, t, n)) = (string (w, x); cty (w, t); nat (w, n))
  fun target (w, {values, classes, dfuns} : G.target) =
    (list valued (w, values);
     list (fn (w, {name, con, kind = k, fields}) =>
             (string (w, name); string (w, con); ckind (w, k); list (fn (w, (t, n)) => (cty (w, t); nat (w, n))) (w, fields)))
       (w, classes);
     list valued (w, dfuns))

  fun encode ({modules, env = e, infer = i, counter, target = t} : part) : string =
    let val w : writer = ref []
    in
      string (w, magic); list string (w, modules); env (w, e); infer (w, i); nat (w, counter); target (w, t);
      String.concat (List.rev (!w))
    end

  (* ---- reading ---- *)

  type reader = {s : string, pos : int ref, vars : (int * T.ty) list ref}

  fun rbyte ({s, pos, ...} : reader) =
    if !pos >= size s then raise Bad "cut short" else Char.ord (String.sub (s, !pos)) before pos := !pos + 1
  fun rnat (r : reader) =
    let
      fun go (scale, acc, k) =
        let val b = rbyte r
        in if b < 128 then acc + scale * b
           else if k = 4 then raise Bad "a number out of range"
           else go (scale * 128, acc + scale * (b - 128), k + 1)
        end
    in go (1, 0, 0) handle Overflow => raise Bad "a number out of range" end
  fun rint r = let val n = rnat r in if n mod 2 = 0 then n div 2 else ~(n div 2) - 1 end
  fun rbool r = case rbyte r of 0 => false | 1 => true | _ => raise Bad "not a bool"
  fun rstring (r as {s, pos, ...} : reader) =
    let val n = rnat r
    in if n > size s - !pos then raise Bad "cut short" else String.substring (s, !pos, n) before pos := !pos + n end
  fun rlist f r = let fun go (0, acc) = List.rev acc | go (k, acc) = go (k - 1, f r :: acc) in go (rnat r, []) end
  fun roption f r = case rbyte r of 0 => NONE | 1 => SOME (f r) | _ => raise Bad "not an option"
  fun rmap f r = List.foldl (fn ((k, v), m) => M.insert (m, k, v)) M.empty (rlist (fn r => let val k = rstring r in (k, f r) end) r)

  fun rid r = let val q = rstring r in {qual = q, name = rstring r} : T.id end
  fun rkind r = case rbyte r of 0 => T.Star | 1 => let val a = rkind r in T.KFun (a, rkind r) end | _ => raise Bad "a kind"
  fun rty (r : reader) =
    case rbyte r of
      0 => let val n = rnat r val k = rkind r
           in case List.find (fn (m, _) => m = n) (!(#vars r)) of
                SOME (_, t) => t
              | NONE => let val t = T.newTVar k in #vars r := (n, t) :: !(#vars r); t end
           end
    | 1 => let val i = rid r in T.TCon {id = i, kind = rkind r} end
    | 2 => let val a = rty r in T.TAp (a, rty r) end
    | 3 => T.TGen (rnat r)
    | _ => raise Bad "a type"
  fun rpred r = let val c = rid r in T.IsIn (c, rty r) end
  fun rscheme r = let val ks = rlist rkind r val ps = rlist rpred r in T.Forall (ks, (ps, rty r)) end
  fun rspan r = let val f = rstring r val a = rnat r in {file = f, start = a, stop = rnat r} : HsSource.span end

  fun rtydef r =
    case rbyte r of
      0 => let val k = rkind r val cs = rlist rid r in E.Data {kind = k, cons = cs, newtype = rbool r} end
    | 1 => let val k = rkind r val n = rnat r in E.Synonym {kind = k, arity = n, rhs = rty r} end
    | _ => raise Bad "a type constructor"
  fun rcon r : E.con =
    let
      val i = rid r val s = rscheme r val n = rnat r val fs = rlist (roption rid) r val st = rlist rbool r
      val tc = rid r val args = rlist rty r
    in {id = i, scheme = s, arity = n, fields = fs, strict = st, tycon = tc, args = args, context = rlist rpred r} end
  fun rfield r : E.field =
    let val i = rid r val tc = rid r val s = rscheme r
    in {id = i, tycon = tc, scheme = s, cons = rlist (fn r => let val c = rid r in (c, rnat r) end) r} end
  fun rmethod r : E.method = let val i = rid r val c = rid r in {id = i, class = c, scheme = rscheme r} end
  fun rinstance r : E.instance =
    let val c = rid r val h = rty r val cx = rlist rpred r val n = rnat r val m = rstring r
    in {class = c, head = h, context = cx, arity = n, decls = [], module = m, span = rspan r} end
  fun rclassDecl r : E.classDecl = let val c = rid r in {class = c, decls = [], module = rstring r} end
  fun rcls r : C.class =
    let val i = rid r val k = rkind r val ss = rlist rid r in {id = i, kind = k, supers = ss, std = rbool r} end
  fun rinst r : C.inst =
    let val h = rpred r val cx = rlist rpred r val n = rnat r val sp = rspan r
    in {head = h, context = cx, arity = n, span = sp, derived = rbool r} end

  fun renv r : E.saved =
    let
      val tydefs = rmap rtydef r val cons = rmap rcon r val fields = rmap rfield r val methods = rmap rmethod r
      val classKinds = rmap rkind r val defaults = rmap (rlist rty) r val instances = rlist rinstance r
      val classDecls = rlist rclassDecl r val prelude = rstring r val programModules = rmap rbool r
      val classes = rmap rcls r val insts = rmap (rlist rinst) r val numId = roption rid r
      val imports = rmap (rlist rstring) r
    in
      {tydefs = tydefs, cons = cons, fields = fields, methods = methods, classKinds = classKinds, defaults = defaults,
       instances = instances, classDecls = classDecls, prelude = prelude, programModules = programModules,
       classes = classes, insts = insts, numId = numId, imports = imports, fileModule = rmap rstring r}
    end

  fun rdefault r : I.default =
    let val m = rstring r val sp = rspan r val ps = rlist rpred r val c = rty r
    in {module = m, span = sp, preds = ps, choice = c, ruleTwo = rbool r} end
  fun rbinding r : I.binding =
    let val m = rstring r val i = rid r val s = rscheme r val sg = rbool r val rs = rbool r
    in {module = m, id = i, scheme = s, signed = sg, restricted = rs, span = rspan r} end
  fun rinfer r : I.saved =
    let val tops = rmap rscheme r val topMono = rlist rty r val chosen = rlist rdefault r
    in {tops = tops, topMono = topMono, chosen = chosen, bindings = rlist rbinding r} end

  fun rckind r =
    case rbyte r of
      0 => K.Star
    | 1 => K.Unlifted
    | 2 => let val a = rckind r in K.Arrow (a, rckind r) end
    | _ => raise Bad "a kind of Core"
  fun rcty r =
    case rbyte r of
      0 => K.TVar (rstring r)
    | 1 => K.TCon (rstring r)
    | 2 => let val a = rcty r in K.TApp (a, rcty r) end
    | 3 => let val a = rcty r in K.TFun (a, rcty r) end
    | 4 => let val v = rstring r val k = rckind r in K.TForall (v, k, rcty r) end
    | 5 => K.TEval (rcty r)
    | 6 => K.TUTuple (rlist rcty r)
    | _ => raise Bad "a type of Core"
  fun rvalued r = let val x = rstring r val t = rcty r in (x, t, rnat r) end
  fun rtarget r : G.target =
    let
      val values = rlist rvalued r
      val classes = rlist (fn r => let val n = rstring r val c = rstring r val k = rckind r
                                   in {name = n, con = c, kind = k,
                                       fields = rlist (fn r => let val t = rcty r in (t, rnat r) end) r} end) r
    in {values = values, classes = classes, dfuns = rlist rvalued r} end

  fun decode (s : string) : part =
    let
      val r : reader = {s = s, pos = ref 0, vars = ref []}
      val () = if rstring r = magic then () else raise Bad "not HsLint's part of a unit"
      val modules = rlist rstring r
      val e = renv r
      val i = rinfer r
      val counter = rnat r
      val t = rtarget r
    in
      if !(#pos r) = size s then {modules = modules, env = e, infer = i, counter = counter, target = t}
      else raise Bad "bytes after the part"
    end
    handle Subscript => raise Bad "cut short"
end
