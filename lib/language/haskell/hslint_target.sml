(* HsLint's target check (the haskell98 roadmap's M16, D54's C; Hall et
   al. 1996, 5.2, the soundness of the translation): the elaborated
   program, Core, which CoreLint types by its rules, is at the translation
   of its source types as HsLint's own second inference found them.

   The translation is HsLint's own, from the Core naming desugaring keeps
   (HsDsEnv's: an entity of the top level is its module's identity, a dot
   and its name; a class the data type of its dictionaries, of its name):

   - a type: a type constructor of the program its entity, the Prelude's
     `Bool` Core's, a type the library declares with no constructor (or
     with the one `PrimT` of `T`) Core's own of its name, `IOError` Core's
     `Exn`; a function Core's; a predicate `C t` the type of `C`'s
     dictionaries at `t`;
   - a scheme: a `forall` over its variables, of a function of its
     context's dictionaries giving its type.

   - [target]: each value of the top level, each method's selector and
     each superclass's, and each default method, where Core has it, is of
     the translation of its type, up to the names and order of its
     variables and the order of its dictionaries, since several
     elaborations are right;
   - [dictionary]: each class's data type has one constructor, its
     direct superclasses' dictionaries, in the class's order, then its
     methods' types, in its declaration's order: the slots;
   - [dfun]: each instance's dictionary function, where Core has it, is
     of a function of its context's dictionaries giving the class's
     dictionary at its head.

   That a term is of its declared type is CoreLint's, which rhc runs
   before; this holds the declared types to the source's. Every route to
   a superclass is then right, since CoreLint sees only types.

   RHC_HSLINT_FAULT=RULE reads the first type RULE compares corrupted. *)
structure HsLintTarget =
struct
  structure T = HsLintTypes
  structure C = HsLintClasses
  structure E = HsLintEnv
  structure M = HsStringMap
  structure K = Core

  fun breach (rule, msg) = raise T.Refuse (HsSource.noSpan, "[" ^ rule ^ "] " ^ msg)

  val fault = ref ""
  fun faulty rule = if !fault = rule then (fault := ""; true) else false

  val rules =
    [("target", "a value of the top level is of the translation of its source type (Hall et al. 1996, 5.2)"),
     ("dictionary", "a class's dictionary holds its superclasses' dictionaries, then its methods, in order"),
     ("dfun", "an instance's dictionary function takes its context's dictionaries and gives the class's at its head")]

  (* ---- the translation ---- *)

  (* an entity's name in Core *)
  fun coreName ({qual, name} : T.id) = if qual = "" then name else qual ^ "." ^ name

  fun kind T.Star = K.Star
    | kind (T.KFun (a, b)) = K.Arrow (kind a, kind b)

  (* a type of the library with no constructor, or with the one `PrimT`
     of no field, is Core's own *)
  fun primitive (id : T.id) =
    String.isPrefix "haskell98:" (#qual id)
    andalso (case M.find (!E.tydefs, T.idKey id) of
               SOME (E.Data {cons = [], ...}) => true
             | SOME (E.Data {cons = [k], ...}) =>
                 #name k = "Prim" ^ #name id
                 andalso (case M.find (!E.cons, T.idKey k) of SOME {arity = 0, ...} => true | _ => false)
             | _ => false)

  fun tycon (id : T.id) =
    if #qual id = "" then #name id
    else if T.idEq (id, E.preludeId "Bool") then "Bool"
    else if primitive id then (if #name id = "IOError" then "Exn" else #name id)
    else coreName id

  (* a type whose generic variables are `gens`; a variable left free, of
     no binding's type, is `()` *)
  fun ty (gens : K.ty vector) (t : T.ty) : K.ty =
    case T.prune t of
      T.TGen i => Vector.sub (gens, i)
    | T.TVar _ => K.TCon "()"
    | T.TAp (T.TAp (T.TCon {id = {qual = "", name = "(->)"}, ...}, a), b) => K.TFun (ty gens a, ty gens b)
    | T.TAp (f, a) => K.TApp (ty gens f, ty gens a)
    | T.TCon {id, ...} => K.TCon (tycon id)

  fun predTy gens (T.IsIn (c, t)) = K.TApp (K.TCon (coreName c), ty gens t)

  (* a scheme, its variables `g1` on, and how many dictionaries it takes;
     those of `fixed` are given, not bound *)
  fun schemeTy (fixed : K.ty list) (T.Forall (ks, (ps, t))) : K.ty * int =
    let
      val names = List.tabulate (length ks - length fixed, fn i => "g" ^ Int.toString (i + 1))
      val gens = Vector.fromList (fixed @ List.map K.TVar names)
      val body = List.foldr (fn (p, acc) => K.TFun (predTy gens p, acc)) (ty gens t) ps
      val bound = List.drop (ks, length fixed)
    in
      (ListPair.foldr (fn (n, k, acc) => K.TForall (n, kind k, acc)) body (names, bound), length ps)
    end

  (* ---- the comparison, up to variables' names and dictionaries' order ---- *)

  fun showKind K.Star = "*"
    | showKind K.Unlifted = "#"
    | showKind (K.Arrow (a, b)) = "(" ^ showKind a ^ " -> " ^ showKind b ^ ")"

  (* a type's text, its free variables named by `env` and those a nested
     `forall` binds by where they are bound *)
  fun txt (env0 : (string * string) list) (t : K.ty) : string =
    let
      val depth = ref 0
      fun go env t =
        case t of
          K.TVar v => (case List.find (fn (w, _) => w = v) env of SOME (_, n) => n | NONE => v)
        | K.TCon c => c
        | K.TApp (a, b) => "(" ^ go env a ^ " " ^ go env b ^ ")"
        | K.TFun (a, b) => "(" ^ go env a ^ " -> " ^ go env b ^ ")"
        | K.TForall (v, k, b) =>
            let val n = (depth := !depth + 1; "%" ^ Int.toString (!depth))
            in "(forall " ^ n ^ ":" ^ showKind k ^ ". " ^ go ((v, n) :: env) b ^ ")" end
        | K.TEval a => "!" ^ go env a
        | K.TUTuple ts => "(utuple " ^ String.concatWith " " (List.map (go env) ts) ^ ")"
    in
      go env0 t
    end

  (* a type as a message shows it *)
  val show = txt []

  (* the free variables of a type, in the order they stand *)
  fun occurrences (t : K.ty) : string list =
    let
      fun go bound t =
        case t of
          K.TVar v => if List.exists (fn w => w = v) bound then [] else [v]
        | K.TCon _ => []
        | K.TApp (a, b) => go bound a @ go bound b
        | K.TFun (a, b) => go bound a @ go bound b
        | K.TForall (v, _, b) => go (v :: bound) b
        | K.TEval a => go bound a
        | K.TUTuple ts => List.concat (List.map (go bound) ts)
    in
      go [] t
    end

  fun peelForalls (K.TForall (v, k, b)) = let val (vs, t) = peelForalls b in ((v, k) :: vs, t) end
    | peelForalls t = ([], t)

  fun peelArgs (0, t) = ([], t)
    | peelArgs (n, K.TFun (a, b)) = let val (args, t) = peelArgs (n - 1, b) in (a :: args, t) end
    | peelArgs (_, t) = ([], t)

  fun sortBy key xs =
    let
      fun ins (x, []) = [x]
        | ins (x, y :: ys) = if String.< (key x, key y) then x :: y :: ys else y :: ins (x, ys)
    in
      List.foldl ins [] xs
    end

  (* the canonical text of a type of `dicts` dictionaries, `free` its
     variables bound elsewhere, with their canonical names: its variables
     named in the order they stand after its dictionaries, then in its
     dictionaries, those sorted *)
  fun canonical (free : (string * string) list) (t : K.ty, dicts : int) : string =
    let
      val (vs, rest) = peelForalls t
      val (args, body) = peelArgs (dicts, rest)
      val tops = List.map #1 vs
      val blank = List.map (fn v => (v, "_")) tops @ free
      val args = sortBy (txt blank) args
      val order =
        List.foldl (fn (v, acc) => if List.exists (fn w => w = v) acc orelse not (List.exists (fn w => w = v) tops) then acc
                                   else acc @ [v])
          [] (occurrences body @ List.concat (List.map occurrences args))
      val names = ListPair.map (fn (v, i) => (v, "v" ^ Int.toString i)) (order, List.tabulate (length order, fn i => i))
      val env = names @ free
      val kinds = List.map (fn (v, n) => n ^ ":" ^ showKind (#2 (valOf (List.find (fn (w, _) => w = v) vs)))) names
      val unused = length vs - length names
    in
      "forall " ^ String.concatWith " " kinds ^ (if unused = 0 then "" else " and " ^ Int.toString unused) ^
      ". {" ^ String.concatWith ", " (T.sortStrings (List.map (txt env) args)) ^ "} " ^ txt env body
    end

  (* ---- what the second inference found, as Core's types ---- *)

  (* each value of the top level, each selector and default method, with
     how many dictionaries it takes; each class's data type; each
     instance's dictionary function *)
  type target = {values : (string * K.ty * int) list,
                 classes : {name : string, con : string, kind : K.kind, fields : (K.ty * int) list} list,
                 dfuns : (string * K.ty * int) list}

  (* the class's methods, in its declaration's order *)
  fun methodsOf (cls : T.id) : T.id list =
    case List.find (fn {class, ...} : E.classDecl => T.idEq (class, cls)) (!E.classDecls) of
      SOME {decls, ...} =>
        List.concat (List.map (fn HsAst.D (_, HsAst.DSig (vs, _, _)) => List.map (fn HsAst.Name (_, q) => q) vs | _ => [])
                       decls)
    | NONE => []

  fun collect (bindings : {id : T.id, scheme : T.scheme} list) : target =
    let
      val values = List.map (fn {id, scheme} => let val (t, n) = schemeTy [] scheme in (coreName id, t, n) end) bindings
      val classList = M.foldl (fn (_, c, acc) => c :: acc) [] (!C.classes)
      val selectors =
        List.concat
          (List.map
             (fn {id = cls, ...} : C.class =>
                List.concat
                  (List.map (fn m =>
                               case M.find (!E.methods, T.idKey m) of
                                 SOME {scheme, ...} =>
                                   let val (t, n) = schemeTy [] scheme
                                   in [(coreName m, t, n), ("%dm:" ^ coreName m, t, n)] end
                               | NONE => [])
                     (methodsOf cls))
                @ List.map (fn s => ("%super:" ^ coreName cls ^ ">" ^ coreName s,
                                     K.TForall ("g1", kind (#kind (valOf (M.find (!C.classes, T.idKey cls)))),
                                                K.TFun (K.TApp (K.TCon (coreName cls), K.TVar "g1"),
                                                        K.TApp (K.TCon (coreName s), K.TVar "g1"))),
                                     1))
                    (C.supers cls))
             classList)
      val classes =
        List.map
          (fn {id = cls, kind = k, ...} : C.class =>
             let
               val a = K.TVar "%c"
               val supers = List.map (fn s => (K.TApp (K.TCon (coreName s), a), 0)) (C.supers cls)
               val methods =
                 List.mapPartial
                   (fn m =>
                      case M.find (!E.methods, T.idKey m) of
                        SOME {scheme = T.Forall (ks, (_ :: own, t)), ...} =>
                          SOME (schemeTy [a] (T.Forall (ks, (own, t))))
                      | _ => NONE)
                   (methodsOf cls)
             in
               {name = coreName cls, con = "%dict:" ^ coreName cls, kind = kind k, fields = supers @ methods}
             end)
          classList
      val dfuns =
        M.foldl
          (fn (_, is, acc) =>
             List.mapPartial
               (fn {head = T.IsIn (cls, h), context, arity, ...} : C.inst =>
                  case E.headTycon (T.IsIn (cls, h)) of
                    SOME tc =>
                      let
                        val ks = List.take (E.argKinds (getOpt (E.tyconKind tc, T.Star)), arity) handle Subscript => []
                        (* the class at its head, `C h`, the dictionary's type *)
                        val (t, n) = schemeTy [] (T.Forall (ks, (context, T.TAp (T.TCon {id = cls, kind = T.Star}, h))))
                      in
                        SOME ("%inst:" ^ coreName cls ^ "@" ^ coreName tc, t, n)
                      end
                  | NONE => NONE)
               is
             @ acc)
          [] (!C.insts)
    in
      {values = values @ selectors, classes = classes, dfuns = dfuns}
    end

  (* ---- the check ---- *)

  fun check ({values, classes, dfuns} : target, p : K.program, f : string) =
    let
      val () = fault := f
      val vals = List.foldl (fn (K.Val (x, t, _), m) => M.insert (m, x, t)
                              | (K.Import (x, t), m) => M.insert (m, x, t)
                              | (_, m) => m)
                   M.empty p
      val datas = List.foldl (fn (K.Data (x, ps, cs), m) => M.insert (m, x, (ps, cs)) | (_, m) => m) M.empty p
      fun corrupt rule t = if faulty rule then K.TFun (K.TCon "HsLintFault", t) else t
      fun value rule (x, mine, n) =
        case M.find (vals, x) of
          SOME theirs =>
            let val theirs = corrupt rule theirs
            in
              if canonical [] (mine, n) = canonical [] (theirs, n) then ()
              else breach (rule, "`" ^ x ^ "` is of the Core type " ^ show theirs ^ ", and the translation of its " ^
                                 "source type, as the second inference has it, is " ^ show mine)
            end
        | NONE => ()
      fun dictionary {name, con, kind = k, fields} =
        case M.find (datas, name) of
          SOME ([(a, k')], [(con', theirs)]) =>
            let
              val theirs = case theirs of t :: rest => corrupt "dictionary" t :: rest | [] => theirs
              (* a field of theirs, its dictionaries counted as ours are *)
              val ok = con' = con andalso k' = k andalso length theirs = length fields
                       andalso ListPair.all (fn ((mine, n), t) => canonical [("%c", "%c")] (mine, n) = canonical [(a, "%c")] (t, n))
                                 (fields, theirs)
            in
              if ok then ()
              else breach ("dictionary", "the class " ^ name ^ "'s dictionary is " ^ con' ^ " of " ^
                                         String.concatWith ", " (List.map show theirs) ^ ", and its source gives " ^ con ^
                                         " of " ^ String.concatWith ", " (List.map (show o #1) fields) ^
                                         " (its superclasses' dictionaries, then its methods, in order)")
            end
        | SOME (ps, cs) =>
            breach ("dictionary", "the class " ^ name ^ "'s dictionary has " ^ Int.toString (length ps) ^ " parameters and " ^
                                  Int.toString (length cs) ^ " constructors, and a class's has one of each")
        | NONE => ()
    in
      List.app (value "target") values;
      List.app dictionary classes;
      List.app (value "dfun") dfuns;
      fault := ""
    end
end
