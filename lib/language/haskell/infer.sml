(* Implements: HS_INFER *)
structure HsInfer :> HS_INFER =
struct
  structure A = HsAst
  structure T = HsTypes
  structure E = HsEvidence
  structure C = HsClasses
  structure K = HsKinds
  structure M = HsStringMap
  structure Mo = HsModules

  datatype cycleDefault = PerModule | PerGroup

  type module_ = {id : string, ast : A.module, library : bool}

  (* a constructor: its type, its fields by position ("" for none) *)
  type coninfo = {tycon : string, arity : int, fields : string list}

  (* a field: its type, the constructors it is in, at which position *)
  type fieldinfo = {tycon : string, ty : T.ty, cons : (string * int) list}

  (* a method: its class, and its type with the class's variable `TGen 0`
     and its own context, the class's assertion not among it *)
  type methodinfo = {cls : string, scheme : T.scheme}

  type env = {values : T.scheme M.map, tycons : K.env, classes : C.env, cons : coninfo M.map,
              fields : fieldinfo M.map, methods : methodinfo M.map}

  fun valueScheme ({values, ...} : env, k) = M.find (values, k)
  fun classes ({classes, ...} : env) = classes

  (* ---- a module's part of the environment (M21's interfaces) ---- *)

  type part = {values : (string * T.scheme) list, tycons : K.tycon list, classes : C.class list,
               instances : C.instance list, cons : (string * coninfo) list, fields : (string * fieldinfo) list,
               methods : (string * methodinfo) list}

  (* the module of an entity's key, `space home TAB name` *)
  fun homeOfKey k =
    case String.fields (fn c => c = #"\t") k of
      [sh, _] => if size sh > 1 then String.extract (sh, 1, NONE) else ""
    | _ => ""

  fun part (env : env, mine : string -> bool) : part =
    let
      fun own m = List.filter (fn (k, _) => mine (homeOfKey k)) (M.listItems m)
    in
      {values = own (#values env), tycons = List.map #2 (own (#tycons env)),
       classes = List.filter (fn (c : C.class) => mine (homeOfKey (#key c))) (C.classList (#classes env)),
       instances = List.filter (fn (i : C.instance) => mine (#home i)) (C.instances (#classes env)),
       cons = own (#cons env), fields = own (#fields env), methods = own (#methods env)}
    end

  fun extend (env : env, p : part) : env =
    let
      fun add (m, kvs) = List.foldl (fn ((k, v), m) => M.insert (m, k, v)) m kvs
    in
      {values = add (#values env, #values p),
       tycons = List.foldl (fn (t : K.tycon, m) => M.insert (m, #key t, t)) (#tycons env) (#tycons p),
       classes = List.foldl (fn (i, e) => C.addInstance (e, i))
                   (List.foldl (fn (c, e) => C.addClass (e, c)) (#classes env) (#classes p)) (#instances p),
       cons = add (#cons env, #cons p), fields = add (#fields env, #fields p), methods = add (#methods env, #methods p)}
    end

  (* ---- the built-in constructors ---- *)

  val listScheme : T.scheme = {vars = 1, ctx = [], ty = T.list (T.TGen 0)}
  val consScheme : T.scheme = {vars = 1, ctx = [], ty = T.fn_ (T.TGen 0, T.fn_ (T.list (T.TGen 0), T.list (T.TGen 0)))}

  fun tupleScheme n : T.scheme =
    let val vs = List.tabulate (n, T.TGen)
    in {vars = n, ctx = [], ty = List.foldr T.fn_ (T.tuple vs) vs} end

  fun builtinCon name : T.scheme option =
    if name = "()" then SOME {vars = 0, ctx = [], ty = T.unit}
    else if name = "[]" then SOME listScheme
    else if name = ":" then SOME consScheme
    else if size name >= 3 andalso String.isPrefix "(," name then SOME (tupleScheme (size name - 1))
    else NONE

  fun builtinConInfo name : coninfo option =
    if name = "()" then SOME {tycon = "()", arity = 0, fields = []}
    else if name = "[]" then SOME {tycon = "[]", arity = 0, fields = []}
    else if name = ":" then SOME {tycon = "[]", arity = 2, fields = ["", ""]}
    else if size name >= 3 andalso String.isPrefix "(," name then
      SOME {tycon = name, arity = size name - 1, fields = List.tabulate (size name - 1, fn _ => "")}
    else NONE

  fun initial {primitives} : env =
    {values = List.foldl (fn (k, m) => M.insert (m, k, {vars = 1, ctx = [], ty = T.TGen 0})) M.empty primitives,
     tycons = M.empty, classes = C.empty, cons = M.empty, fields = M.empty, methods = M.empty}

  (* ---- dictionaries while inference runs ---- *)

  datatype idict =
      IParam of string
    | IInst of string * T.ty list * cell list
    | ISuper of idict * string * string
  and cellv = Pending | Solved of idict
  withtype cell = cellv ref

  (* a predicate wanted, its dictionary's cell, where and why it arose:
     its module, what it arose from (`` `show` `` or "a literal") and the
     binding it arose in *)
  type wanted = {pred : T.pred, cell : cell, span : HsSource.span, home : string, origin : string, binding : string}

  (* ---- the state of a check ---- *)

  exception Fail of HsSource.span * string

  val errors : (HsSource.span * string) list ref = ref []
  fun err (span, msg) = errors := (span, msg) :: !errors

  (* an error said once in a unit, the same message elsewhere not again *)
  val said : string list ref = ref []
  fun once (span, msg) = if List.exists (fn m => m = msg) (!said) then () else (said := msg :: !said; err (span, msg))

  val level = ref 0
  val home = ref ""
  val curSpan = ref HsSource.noSpan
  val curBinding = ref ""
  (* where a literal or a variable stands, as a message says it: "the
     argument of `f`" while the argument of an application is a literal or
     a variable *)
  val argOf = ref ""
  fun inBinding () = if !curBinding = "" then "" else " in `" ^ !curBinding ^ "`"
  val wanted : wanted list ref = ref []
  val givens : (T.pred * idict) list ref = ref []
  val rigidLevels : int M.map ref = ref M.empty
  val pendingRecords : (string * (unit -> E.record)) list ref = ref []
  val counter = ref 0
  fun fresh prefix = (counter := !counter + 1; prefix ^ Int.toString (!counter))

  fun renumber n = (if !counter < n then counter := n else (); T.renumber n)
  fun numberFrom n = (counter := n; T.numberFrom n)

  (* the environment of the unit being checked *)
  val genv : env ref = ref (initial {primitives = []})
  val preludeKey : (string * string -> string option) ref = ref (fn _ => NONE)
  val cycle : cycleDefault ref = ref PerModule
  val unitModules : string list ref = ref []
  val defaultsOf : (T.ty list * bool) M.map ref = ref M.empty   (* a module's default list, and whether written *)
  val fixityOfKey : (string -> (A.fixity * int) option) ref = ref (fn _ => NONE)
  val crossFixings : (string * string * HsSource.span * int) list ref = ref []   (* home, fixing module, where, variable *)

  fun record (kind, span, f) = pendingRecords := (E.node (kind, span), f) :: !pendingRecords

  fun prelude (space, name) = !preludeKey (space, name)
  fun preludeTy name = case prelude ("t", name) of SOME k => T.TCon k | NONE => T.TCon ("?" ^ name)
  fun preludeClass name = getOpt (prelude ("t", name), "?" ^ name)

  fun newMeta () = T.newMeta (!level, !home)

  (* types for a message: unsolved variables named a, b, ... in order *)
  fun readable (ts : T.ty list) : T.ty list =
    let
      val ms = List.foldl (fn (t, acc) => acc @ List.filter (fn r => not (List.exists (fn r' => r' = r) acc)) (T.metas t)) [] ts
      fun letter i = if i < 26 then str (Char.chr (97 + i)) else "t" ^ Int.toString i
      fun go t =
        case T.repr t of
          T.TMeta r =>
            (case List.find (fn (r', _) => r' = r) (ListPair.zip (ms, List.tabulate (length ms, fn i => i))) of
               SOME (_, i) => T.TCon (letter i)
             | NONE => t)
        | T.TAp (a, b) => T.TAp (go a, go b)
        | t' => t'
    in
      List.map go ts
    end

  fun showPreds (ps : T.pred list) =
    let val ts = readable (List.map #ty ps)
    in
      case ListPair.map (fn ({cls, ...}, t) => T.showPred {cls = cls, ty = t}) (ps, ts) of
        [p] => p
      | qs => "(" ^ String.concatWith ", " qs ^ ")"
    end

  fun showTypes (a, b) = case readable [a, b] of [x, y] => (T.show x, T.show y) | _ => (T.show a, T.show b)

  (* the watch of unification: a rigid variable may not escape to a
     shallower variable, and in a cycle under PerModule a variable a
     restriction left monomorphic at the top level is fixed only by its
     own module's code *)
  fun containsRigidDeeper (t, lvl) =
    case T.repr t of
      T.TRigid {id, ...} => (case M.find (!rigidLevels, Int.toString id) of SOME l => l > lvl | NONE => false)
    | T.TAp (a, b) => containsRigidDeeper (a, lvl) orelse containsRigidDeeper (b, lvl)
    | _ => false

  exception Escape of T.meta ref * T.ty

  (* the top-level binders a restriction left monomorphic, by their variables *)
  val monoOwners : (int * string) list ref = ref []

  fun watch (r, t) =
    (if containsRigidDeeper (t, T.metaLevel r) then raise Escape (r, t) else ();
     if T.metaLevel r = 0 andalso T.metaHome r <> !home andalso length (!unitModules) > 1 then
       (case T.repr t of
          T.TMeta _ => ()
        | _ => crossFixings := (T.metaHome r, !home, !curSpan, T.metaId r) :: !crossFixings)
     else ())

  (* the variables in scope a message names: the monomorphic locals *)
  val relevant : (unit -> string) ref = ref (fn () => "")

  fun unifyAt (span, what) (a, b) =
    T.unify watch (a, b)
    handle T.Mismatch (a', b') =>
             let
               val (x, y) = showTypes (T.zonk a, T.zonk b)
               val (x', y') = showTypes (T.zonk a', T.zonk b')
               val inner = if x' = x andalso y' = y then "" else ", for `" ^ x' ^ "` is not `" ^ y' ^ "`"
             in
               raise Fail (span, what ^ ": the type `" ^ x ^ "` does not match `" ^ y ^ "`" ^ inner ^ !relevant ())
             end
         | T.Occurs _ =>
             let val (x, y) = showTypes (T.zonk a, T.zonk b)
             in raise Fail (span, what ^ ": the type `" ^ x ^ "` would contain itself, as `" ^ y ^ "` (an infinite type)") end
         | Escape (r, t) =>
             raise Fail (span, what ^ ": " ^
                               (case List.find (fn (id, _) => id = T.metaId r) (!monoOwners) of
                                  SOME (_, owner) => "the type of `" ^ owner ^ "`, which the monomorphism restriction keeps " ^
                                                     "monomorphic (4.5.5), would be `" ^ T.show (T.zonk t) ^ "`, a variable of a signature"
                                | NONE => "the type `" ^ T.show (T.zonk t) ^ "` holds a variable of a signature, which would escape " ^
                                          "its scope") ^
                               ": the binding is less polymorphic than its signature says")

  (* ---- types equal, and the dictionary of a predicate ---- *)

  fun eqTy (a, b) =
    case (T.repr a, T.repr b) of
      (T.TCon x, T.TCon y) => x = y
    | (T.TAp (f, x), T.TAp (g, y)) => eqTy (f, g) andalso eqTy (x, y)
    | (T.TMeta r, T.TMeta r') => r = r'
    | (T.TRigid {id, ...}, T.TRigid {id = id', ...}) => id = id'
    | (T.TGen i, T.TGen j) => i = j
    | _ => false

  (* the given dictionary of a predicate, through superclasses *)
  fun fromGivens (p : T.pred) =
    let
      fun try [] = NONE
        | try (({cls, ty}, d) :: rest) =
            if eqTy (ty, #ty p) then
              case C.superPath (#classes (!genv), cls, #cls p) of
                SOME path =>
                  let
                    fun walk (d, c :: (rest as s :: _)) = walk (ISuper (d, c, s), rest)
                      | walk (d, _) = d
                  in
                    SOME (walk (d, path))
                  end
              | NONE => try rest
            else try rest
    in
      try (!givens)
    end

  fun headOf t = #1 (T.spine t)

  (* "no instance of `Num` for `Char`, which `+` needs in `f`" *)
  fun noInstance ({cls, ty} : T.pred, origin, binding) =
    "no instance of `" ^ T.nameOfKey cls ^ "` for `" ^ (case readable [T.zonk ty] of [t] => T.show t | _ => T.show ty) ^ "`" ^
    (if origin = "" then "" else ", which " ^ origin ^ " needs") ^ (if binding = "" then "" else " in `" ^ binding ^ "`")

  (* `byInstance (p, span)`: the instance's dictionary for p, its
     context's predicates as new wanted ones, or NONE where p's type is
     headed by no constructor *)
  fun byInstance ({cls, ty} : T.pred, span, h, origin, binding) : (idict * wanted list) option =
    case T.spine ty of
      (T.TCon tc, args) =>
        (case C.findInstance (#classes (!genv), cls, tc) of
           SOME {id, vars, ctx, ...} =>
             if vars <> length args then raise Fail (span, noInstance ({cls = cls, ty = ty}, origin, binding))
             else
               let
                 val subs = List.map (fn {cls, ty} => {pred = {cls = cls, ty = T.substGen (args, ty)}, cell = ref Pending,
                                                       span = span, home = h, origin = origin, binding = binding}) ctx
               in
                 SOME (IInst (id, args, List.map #cell subs), subs)
               end
         | NONE => raise Fail (span, noInstance ({cls = cls, ty = ty}, origin, binding)))
    | _ => NONE

  (* Solving: what can be solved now by instances and givens is; the rest,
     on unification variables, is given back. *)
  fun solve (ws : wanted list) : wanted list =
    let
      fun one (w as {pred, cell, span, home = h, origin, binding} : wanted, acc) =
        let val p = {cls = #cls pred, ty = T.zonk (#ty pred)}
        in
          case fromGivens p of
            SOME d => (cell := Solved d; acc)
          | NONE =>
              case headOf (#ty p) of
                T.TCon _ =>
                  ((case byInstance (p, span, h, origin, binding) of
                      SOME (d, subs) => (cell := Solved d; List.foldl one acc subs)
                    | NONE => acc)
                   handle Fail e => (once e; acc))
              | T.TRigid _ =>
                  (once (span, noInstance (p, origin, binding) ^ ", and the context in scope does not give it: a signature's " ^
                               "context must say it");
                   acc)
              | _ => {pred = p, cell = cell, span = span, home = h, origin = origin, binding = binding} :: acc
        end
    in
      List.rev (List.foldl one [] ws)
    end

  (* ---- defaulting (4.3.4, R22) ---- *)

  val standard : (string -> bool) ref = ref (fn _ => false)
  fun isStandard cls = !standard cls

  fun isNumeric cls =
    let val num = preludeClass "Num"
    in cls = num orelse List.exists (fn s => s = num) (C.superclasses (#classes (!genv), cls)) end

  (* whether every predicate holds at t, by instances alone *)
  fun holdsAt (preds : T.pred list, t) =
    let
      fun holds {cls, ty} =
        case T.spine ty of
          (T.TCon tc, args) =>
            (case C.findInstance (#classes (!genv), cls, tc) of
               SOME {vars, ctx, ...} =>
                 vars = length args andalso List.all (fn {cls, ty} => holds {cls = cls, ty = T.substGen (args, ty)}) ctx
             | NONE => false)
        | _ => false
    in
      List.all (fn {cls, ...} => holds {cls = cls, ty = t}) preds
    end

  (* the default list for a module *)
  fun defaultsFor m = case M.find (!defaultsOf, m) of SOME (ts, _) => ts | NONE => [preludeTy "Integer", preludeTy "Double"]

  fun sameDefaults (a, b) = ListPair.allEq eqTy (defaultsFor a, defaultsFor b)

  (* `default (r, ws)` defaults the variable r, whose wanted predicates
     are ws; true where it did *)
  fun default (r, ws : wanted list) : bool =
    let
      val preds = List.map #pred ws
      val simple = List.all (fn {ty, ...} => case T.repr ty of T.TMeta r' => r = r' | _ => false) preds
      val classes = List.map #cls preds
      val homes = List.foldl (fn ({home = h, ...} : wanted, acc) => if List.exists (fn x => x = h) acc then acc else acc @ [h]) [] ws
      val span = #span (hd ws)
      val m =
        case !cycle of
          PerGroup => hd (!unitModules)
        | PerModule => hd homes
      val agree =
        case !cycle of
          PerModule => List.all (fn h => sameDefaults (h, hd homes)) homes
        | PerGroup => List.all (fn h => sameDefaults (h, hd (!unitModules))) (!unitModules)
    in
      if not simple orelse not (List.exists isNumeric classes) orelse not (List.all isStandard classes) then false
      else if not agree then
        (err (span, "the type variable of `" ^ showPreds preds ^ "` arose in " ^
                    (case !cycle of PerModule => "modules" | PerGroup => "a cycle of modules") ^
                    " whose default declarations differ (" ^
                    String.concatWith ", " (List.map Mo.moduleName (case !cycle of PerModule => homes | PerGroup => !unitModules)) ^
                    "), so it has no one default (D30)" ^
                    (case !cycle of PerGroup => ": under --cycle-default=scc a cycle has one default" | PerModule => ""));
         true)
      else
        case List.find (fn t => holdsAt (preds, t)) (defaultsFor m) of
          NONE => false
        | SOME t =>
            let
              val var = "t" ^ Int.toString (T.metaId (ref (!r)))
              val name = "t" ^ Int.toString (T.metaId r)
              val candidates = defaultsFor m
            in
              r := T.Link t;
              List.app (fn {cell, pred, span, home = h, origin, binding} =>
                          case byInstance ({cls = #cls pred, ty = t}, span, h, origin, binding) of
                            SOME (d, subs) => (cell := Solved d; ignore (solve subs))
                          | NONE => ())
                ws;
              record ("default", span, fn () => E.Defaulted {var = name, preds = List.map (fn cls => {cls = cls, ty = t})
                                                                                   (List.foldl (fn (c, acc) => if List.exists (fn x => x = c) acc then acc else acc @ [c]) [] classes),
                                                             candidates = candidates, module_ = m, choice = t});
              true
            end
    end

  (* group wanted predicates by the variable at their head *)
  fun byHead (ws : wanted list) : (T.meta ref * wanted list) list =
    List.foldl
      (fn (w, acc) =>
         case T.repr (headOf (#ty (#pred w))) of
           T.TMeta r =>
             (case List.partition (fn (r', _) => r' = r) acc of
                ([(_, l)], rest) => rest @ [(r, l @ [w])]
              | _ => acc @ [(r, [w])])
         | _ => acc)
      [] ws

  (* defaulting what must be: the ambiguous, and at the end of a module *)
  fun defaultAll (ws : wanted list, why) : unit = defaultWith (ws, why, NONE)

  (* `defaultWith (ws, why, message)`: as defaultAll, with `message` for
     what no default resolves, where it is given *)
  and defaultWith (ws : wanted list, why, message : (wanted list -> string) option) : unit =
    List.app
      (fn (r, group) =>
         if default (r, group) then ()
         else if not (null (!errors)) then ()     (* an ambiguity is most often another error's *)
         else
           err (#span (hd group),
                case message of SOME f => f group | NONE =>
                (case List.foldl (fn ({origin, ...} : wanted, acc) => if origin = "" orelse List.exists (fn o' => o' = origin) acc then acc
                                                                       else acc @ [origin]) [] (List.rev group) of
                   [] => ""
                 | os => "the type of " ^ String.concatWith " and " os ^ " here is ambiguous: ") ^
                "the type variable of `" ^ showPreds (List.map #pred group) ^ "`, of the classes " ^
                String.concatWith " and " (List.foldl (fn ({pred, ...} : wanted, acc) =>
                                                         let val c = "`" ^ T.nameOfKey (#cls pred) ^ "`"
                                                         in if List.exists (fn x => x = c) acc then acc else acc @ [c] end) [] group) ^
                ", is ambiguous" ^ why ^
                (case #binding (hd group) of "" => "" | b => " (in `" ^ b ^ "`)") ^
                ", and no default resolves it (4.3.4: a numeric class among its classes, all of them standard, and a type of " ^
                "the default list an instance of each)"))
      (byHead ws)

  (* ---- dictionaries made final ---- *)

  fun finalDict (d : idict) : E.dict =
    case d of
      IParam p => E.DParam p
    | IInst (inst, tys, cells) => E.DInst {inst = inst, tys = List.map T.zonk tys, args = List.map finalCell cells}
    | ISuper (d, c, s) => E.DSuper {dict = finalDict d, cls = c, super = s}
  and finalCell (ref (Solved d)) = finalDict d
    | finalCell (ref Pending) = E.DParam "?"

  (* ---- the environment of names ---- *)

  datatype vbind =
      Mono of T.ty                          (* a binder not generalised *)
    | Poly of T.scheme                      (* a binder generalised *)
    | Rec of T.ty * (HsSource.span * T.ty list ref * cell list ref) list ref
                                            (* a binder of the group being inferred: its uses, made final with it *)

  val locals : vbind M.map ref = ref M.empty
  val unitValues : vbind M.map ref = ref M.empty

  fun localName k =
    let
      fun go i =
        if i < 0 then k
        else if Char.isDigit (String.sub (k, i)) then go (i - 1)
        else if String.sub (k, i) = #"#" andalso i > 0 andalso i < size k - 1 then String.substring (k, 0, i)
        else k
    in
      go (size k - 1)
    end

  val () =
    relevant :=
      (fn () =>
         let
           val monos = List.mapPartial (fn (k, Mono t) => SOME (localName k, T.zonk t) | _ => NONE) (M.listItems (!locals))
           val shown = List.take (monos, Int.min (4, length monos))
         in
           if null shown then ""
           else " (in scope: " ^ String.concatWith ", " (ListPair.map (fn ((n, _), t) => "`" ^ n ^ "`, of type `" ^ T.show t ^ "`")
                                                            (shown, readable (List.map #2 shown))) ^ ")"
         end)

  fun nameKey (A.Name (_, {qual, name})) =
    if qual = "" then name else Mo.key {space = Mo.Value, home = qual, name = name}

  fun nameSpan (A.Name ({span, ...}, _)) = span
  (* a name as the source wrote it: a local's without the renamer's `#n` *)
  fun nameText (A.Name (_, {name, ...})) =
    let
      fun go i =
        if i < 0 then name
        else if Char.isDigit (String.sub (name, i)) then go (i - 1)
        else if String.sub (name, i) = #"#" andalso i > 0 andalso i < size name - 1 then String.substring (name, 0, i)
        else name
    in
      go (size name - 1)
    end

  (* the type of a use of a variable or a constructor, its evidence recorded *)
  fun useScheme (span, scheme : T.scheme, origin) =
    let
      val (tys, preds, t) = T.instantiate (scheme, !level, !home)
      val cells = List.map (fn p => let val c = ref Pending
                                    in wanted := {pred = p, cell = c, span = span, home = !home, origin = origin,
                                                  binding = !curBinding} :: !wanted; c end) preds
    in
      record ("use", span, fn () => E.Use {tys = List.map T.zonk tys, dicts = List.map finalCell cells});
      t
    end

  fun lookupValue (n as A.Name ({span, ...}, {qual, name})) : T.ty =
    let
      val k = nameKey n
      val origin = "`" ^ nameText n ^ "`" ^ (if !argOf = "" then "" else ", " ^ !argOf ^ ",")
    in
      case (if qual = "" then M.find (!locals, k) else NONE) of
        SOME b => bindUse (span, b, origin)
      | NONE =>
          case M.find (!unitValues, k) of
            SOME b => bindUse (span, b, origin)
          | NONE =>
              case M.find (#values (!genv), k) of
                SOME s => useScheme (span, s, origin)
              | NONE =>
                  case (if qual = "" then builtinCon name else NONE) of
                    SOME s => useScheme (span, s, origin)
                  | NONE => newMeta ()     (* not in scope: the renamer said so *)
    end
  and bindUse (span, b, origin) =
    case b of
      Mono t => (record ("use", span, fn () => E.Use {tys = [], dicts = []}); t)
    | Poly s => useScheme (span, s, origin)
    | Rec (t, uses) =>
        let val tys = ref [] and cells = ref []
        in
          uses := (span, tys, cells) :: !uses;
          record ("use", span, fn () => E.Use {tys = List.map T.zonk (!tys), dicts = List.map finalCell (!cells)});
          t
        end

  fun conInfo (n as A.Name (_, {qual, name})) : coninfo option =
    let val k = nameKey n
    in
      case M.find (#cons (!genv), k) of
        SOME c => SOME c
      | NONE => if qual = "" then builtinConInfo name else NONE
    end

  (* ---- types written in the program ---- *)

  fun classKindOf key =
    case C.findClass (#classes (!genv), key) of
      SOME {kind, ...} => SOME kind
    | NONE => NONE

  (* a signature's type and context as a scheme, its variables in order of
     appearance; with their names *)
  fun schemeOf (ctx, t) : T.scheme * string list =
    let
      val names = K.tyVars t
      val ctxNames = case ctx of SOME c => K.tyVars c | NONE => []
      val all = names @ List.filter (fn n => not (List.exists (fn m => m = n) names)) ctxNames
      fun var n =
        case List.find (fn (m, _) => m = n) (ListPair.zip (all, List.tabulate (length all, fn i => i))) of
          SOME (_, i) => T.TGen i
        | NONE => T.TGen 0
      val vars = ref M.empty
      val kenv = {env = #tycons (!genv), classKind = classKindOf, vars = vars}
      val () = K.checkContext kenv ctx
      val () = K.checkType kenv (t, T.KStar)
      val () = M.foldl (fn (_, k, ()) => ignore (T.defaultKind k)) () (!vars)
      (* 4.3.4: a context's variable that the type does not have is ambiguous *)
      val () =
        case List.filter (fn n => not (List.exists (fn m => m = n) names)) ctxNames of
          [] => ()
        | v :: _ =>
            raise Fail (case ctx of SOME (A.T ({span, ...}, _)) => span | NONE => HsSource.noSpan,
                        "the signature's context names `" ^ v ^ "`, which its type does not: an ambiguous type (4.3.4)")
    in
      ({vars = length all, ctx = K.contextPreds (#tycons (!genv), var) ctx, ty = K.convert (#tycons (!genv), var) t}, all)
    end

  (* rigid variables for a scheme's, at the current level *)
  fun skolemise (names : string list) =
    List.map (fn n =>
                let
                  val () = counter := !counter + 1
                  val r = {id = !counter, name = n ^ "_" ^ Int.toString (!counter)}
                in
                  rigidLevels := M.insert (!rigidLevels, Int.toString (#id r), !level);
                  T.TRigid r
                end)
      names

  fun rigidName t = case T.repr t of T.TRigid {name, ...} => name | t' => T.show t'

  (* ---- patterns ---- *)

  fun litPred (span, kind, ty, classes) =
    let
      val origin =
        (case kind of
           "lit" => "a literal" | "neg" => "a negation" | "enum" => "an enumeration" | "do" => "a `do`"
         | "patlit" => "a literal pattern" | "npk" => "an n+k pattern" | k => k) ^
        (if !argOf = "" then "" else ", " ^ !argOf ^ ",")
      val cells = List.map (fn c => let val cell = ref Pending in wanted := {pred = {cls = c, ty = ty}, cell = cell, span = span,
                                                                             home = !home, origin = origin,
                                                                             binding = !curBinding} :: !wanted;
                                                                   (c, cell) end) classes
    in
      record (kind, span, fn () => E.Overloaded {ty = T.zonk ty, dicts = List.map (fn (c, cell) => (c, finalCell cell)) cells})
    end

  fun litType (A.Lit ({span, ...}, l)) =
    case l of
      A.LInt _ => let val t = newMeta () in litPred (span, "lit", t, [preludeClass "Num"]); t end
    | A.LFloat _ => let val t = newMeta () in litPred (span, "lit", t, [preludeClass "Fractional"]); t end
    | A.LChar _ => preludeTy "Char"
    | A.LString _ => T.list (preludeTy "Char")

  (* `pat bind p` is the type of p; `bind (name, ty)` binds a variable *)
  fun pat (bind : A.name * T.ty -> unit) (p as A.P ({span, ...}, x)) : T.ty =
    (curSpan := span;
     case x of
       A.PVar v => let val t = newMeta () in bind (v, t); t end
     | A.PWild => newMeta ()
     | A.PLit (l as A.Lit ({span = ls, ...}, lit)) =>
         (case lit of
            A.LInt _ => let val t = newMeta () in litPred (ls, "patlit", t, [preludeClass "Eq", preludeClass "Num"]); t end
          | A.LFloat _ => let val t = newMeta () in litPred (ls, "patlit", t, [preludeClass "Eq", preludeClass "Fractional"]); t end
          | _ => litType l)
     | A.PNegLit (A.Lit (_, lit)) =>
         let val t = newMeta ()
         in
           litPred (span, "patlit", t, [preludeClass "Eq", case lit of A.LFloat _ => preludeClass "Fractional" | _ => preludeClass "Num"]);
           t
         end
     | A.PCon (c, ps) => conPat (bind, span, c, ps)
     | A.PRec (c, fs) =>
         let
           val ct = lookupValue c
           val (args, res) = arrows ct
           val info = conInfo c
         in
           List.app
             (fn (f, fp) =>
                let
                  val pt = pat bind fp
                  val k = nameKey f
                in
                  case (info, Option.map (fn i => #fields i) info) of
                    (SOME _, SOME fields) =>
                      (case List.find (fn (fk, _) => fk = k) (ListPair.zip (fields, List.tabulate (length fields, fn i => i))) of
                         SOME (_, i) => unifyAt (span, "a field of the pattern") (List.nth (args, i), pt)
                       | NONE => err (nameSpan f, "the constructor has no field `" ^ nameText f ^ "`"))
                  | _ => ()
                end)
             fs;
           res
         end
     | A.PTuple ps => T.tuple (List.map (pat bind) ps)
     | A.PList ps =>
         let val t = newMeta ()
         in List.app (fn q => unifyAt (span, "an element of the list pattern") (t, pat bind q)) ps; T.list t end
     | A.PParen q => pat bind q
     | A.PAs (v, q) => let val t = pat bind q in bind (v, t); t end
     | A.PLazy q => pat bind q
     | A.PNPlusK (v, _) =>
         let val t = newMeta ()
         in litPred (span, "npk", t, [preludeClass "Integral"]); bind (v, t); t end
     | A.PSeq [A.PA l, A.PO (A.ConOp c), A.PA r] => conPat (bind, span, c, [l, r])
     | A.PSeq items => (List.app (fn A.PA q => ignore (pat bind q) | _ => ()) items; newMeta ())
     | A.PJux ps => (List.app (fn q => ignore (pat bind q)) ps; newMeta ()))

  and conPat (bind, span, c, ps) =
    let
      val ct = lookupValue c
      val (args, res) = arrows ct
    in
      if length args <> length ps then newMeta ()     (* the renamer said so *)
      else (ListPair.app (fn (a, q) => unifyAt (span, "an argument of the constructor `" ^ nameText c ^ "`") (a, pat bind q)) (args, ps);
            res)
    end

  (* the leaves of a type *)
  and gensOf t =
    case T.repr t of
      T.TAp (a, b) => gensOf a @ gensOf b
    | t' => [t']

  (* a constructor's type taken apart: its fields and its result *)
  and arrows t =
    case T.spine t of
      (T.TCon "->", [a, b]) => let val (args, r) = arrows b in (a :: args, r) end
    | _ => ([], t)

  fun binderOf (name : A.name, t : T.ty) =
    (locals := M.insert (!locals, nameKey name, Mono t);
     record ("bind", nameSpan name, fn () => E.Mono (T.zonk t)))

  (* A binding of a declaration group: a function's clauses, together, or
     a pattern binding and the variables it binds, with its module. *)
  datatype binding =
      FunB of {name : A.name, clauses : (A.funlhs * A.rhs) list, home : string}
    | PatB of {pat : A.pat, rhs : A.rhs, vars : A.name list, home : string}

  fun funName (A.F (_, x)) =
    case x of
      A.FPrefix (v, _) => v
    | A.FInfix (_, A.VarOp v, _) => v
    | A.FInfix (_, A.ConOp v, _) => v
    | A.FParen (l, _) => funName l

  fun funArgs (A.F (_, x)) =
    case x of
      A.FPrefix (_, ps) => ps
    | A.FInfix (p1, _, p2) => [p1, p2]
    | A.FParen (l, ps) => funArgs l @ ps

  fun patVars (A.P (_, x)) =
    case x of
      A.PVar v => [v]
    | A.PCon (_, ps) => List.concat (List.map patVars ps)
    | A.PRec (_, fs) => List.concat (List.map (fn (_, p) => patVars p) fs)
    | A.PTuple ps => List.concat (List.map patVars ps)
    | A.PList ps => List.concat (List.map patVars ps)
    | A.PParen p => patVars p
    | A.PAs (v, p) => v :: patVars p
    | A.PLazy p => patVars p
    | A.PNPlusK (v, _) => [v]
    | A.PSeq items => List.concat (List.map (fn A.PA p => patVars p | _ => []) items)
    | _ => []

  (* the bindings of declarations, the clauses of a function together *)
  fun collect ds =
    let
      fun go ([], acc) = List.rev acc
        | go ((h, A.D (_, x)) :: rest, acc) =
            case x of
              A.DFun (f, r) =>
                let val n = funName f
                in
                  case acc of
                    FunB {name, clauses, home = h'} :: more =>
                      if nameKey name = nameKey n then go (rest, FunB {name = name, clauses = clauses @ [(f, r)], home = h'} :: more)
                      else go (rest, FunB {name = n, clauses = [(f, r)], home = h} :: acc)
                  | _ => go (rest, FunB {name = n, clauses = [(f, r)], home = h} :: acc)
                end
            | A.DPat (p, r) => go (rest, PatB {pat = p, rhs = r, vars = patVars p, home = h} :: acc)
            | _ => go (rest, acc)
    in
      go (ds, [])
    end

  (* a binding's keys: its binders', or, for a pattern binding that binds
     nothing, one of its own *)
  fun bkeys b =
    case b of
      FunB {name, ...} => [nameKey name]
    | PatB {vars = [], pat = A.P ({span, ...}, _), ...} => ["#pattern@" ^ #file span ^ ":" ^ Int.toString (#start span)]
    | PatB {vars, ...} => List.map nameKey vars
  fun bkey b = case bkeys b of k :: _ => k | [] => "?"
  fun bhome b = case b of FunB {home, ...} => home | PatB {home, ...} => home
  fun bname b = case b of FunB {name, ...} => name | PatB {vars = v :: _, ...} => v
                        | PatB {pat = A.P (a, _), ...} => A.Name (a, {qual = "", name = "_"})

  fun sortStrings xs =
    let
      fun insert (x, []) = [x]
        | insert (x, y :: ys) = if String.<= (x, y) then x :: y :: ys else y :: insert (x, ys)
    in
      List.foldl insert [] xs
    end

  (* ---- expressions ---- *)

  val bool = fn () => preludeTy "Bool"

  fun exp (A.E ({span, ...}, x)) : T.ty =
    (curSpan := span;
     case x of
       A.EVar n => lookupValue n
     | A.ECon n => lookupValue n
     | A.ELit l => litType l
     | A.EApp (f, a) =>
         let
           fun head (A.E (_, x)) =
             case x of
               A.EApp (g, _) => head g
             | A.EVar n => SOME n
             | A.ECon n => SOME n
             | A.EParen g => head g
             | _ => NONE
           fun simple (A.E (_, x)) = case x of A.ELit _ => true | A.EVar _ => true | A.ECon _ => true | A.EParen e => simple e | _ => false
           val tf = exp f
           val saved = !argOf
           val () = argOf := (case (head f, simple a) of (SOME n, true) => "the argument of `" ^ nameText n ^ "`" | _ => "")
           val ta = exp a handle e => (argOf := saved; raise e)
           val () = argOf := saved
           val r = newMeta ()
         in
           (unifyAt (span, "an application") (tf, T.fn_ (ta, r))
            handle Fail _ =>
              let
                val (x, y) = case readable [T.zonk ta, T.zonk tf] of [x, y] => (T.show x, T.show y) | _ => ("", "")
              in
                raise Fail (span, (case head f of
                                     SOME n => "an argument of `" ^ nameText n ^ "`"
                                   | NONE => "an argument") ^
                                  " has the type `" ^ x ^ "`, where the function, of type `" ^ y ^ "`, takes another" ^ inBinding ())
              end);
           r
         end
     | A.ESeq [A.EA l, A.EO q, A.EA r] =>
         let
           val top = qop q
           val tl = exp l
           val tr = exp r
           val res = newMeta ()
         in
           unifyAt (span, "the operands of `" ^ (case q of A.VarOp n => nameText n | A.ConOp n => nameText n) ^ "`" ^ inBinding ())
             (top, T.fn_ (tl, T.fn_ (tr, res)));
           res
         end
     | A.ESeq [A.ENeg, A.EA e] =>
         let val t = exp e
         in litPred (span, "neg", t, [preludeClass "Num"]); t end
     | A.ESeq items => (List.app (fn A.EA e => ignore (exp e) | _ => ()) items; newMeta ())
     | A.ELam (ps, b) =>
         let
           val saved = !locals
           val ts = List.map (pat binderOf) ps
           val tb = exp b
         in
           locals := saved; List.foldr T.fn_ tb ts
         end
     | A.ELet (ds, b) =>
         let val saved = !locals
         in bindings (ds, false); exp b before locals := saved end
     | A.EIf (c, t, e) =>
         let
           val () = unifyAt (span, "the condition of `if`") (exp c, bool ())
           val tt = exp t
         in
           unifyAt (span, "the branches of `if`") (tt, exp e); tt
         end
     | A.ECase (e, alts) =>
         let
           val te = exp e
           val r = newMeta ()
         in
           List.app (fn A.Alt ({span = asp, ...}, p, rh) =>
                       let val saved = !locals
                       in
                         unifyAt (asp, "an alternative's pattern") (te, pat binderOf p);
                         unifyAt (asp, "an alternative's result") (r, rhs rh);
                         locals := saved
                       end)
             alts;
           r
         end
     | A.EDo ss =>
         let
           (* do {e} = e, and a `let` is a `let`: only a statement that is
              not the last, a binding or an expression, needs a monad (3.14) *)
           val needsMonad =
             case List.rev ss of
               _ :: earlier => List.exists (fn A.S (_, A.SLet _) => false | _ => true) earlier
             | [] => false
           val m = newMeta ()
           val () = if needsMonad then litPred (span, "do", m, [preludeClass "Monad"]) else ()
           val saved = !locals
           fun go [] = raise Fail (span, "a `do` with no statement")
             | go [A.S ({span = ssp, ...}, A.SExp e)] =
                 let val t = exp e val a = newMeta ()
                 in if needsMonad then unifyAt (ssp, "the last statement of a `do`") (t, T.TAp (m, a)) else (); t end
             | go [A.S ({span = ssp, ...}, _)] = raise Fail (ssp, "the last statement of a `do` is not an expression")
             | go (A.S ({span = ssp, ...}, s) :: rest) =
                 (case s of
                    A.SBind (p, e) =>
                      let
                        val te = exp e
                        val tp = pat binderOf p
                      in
                        unifyAt (ssp, "a statement of a `do`, of the `Monad` the `do` is in") (te, T.TAp (m, tp)); go rest
                      end
                  | A.SLet ds => (bindings (ds, false); go rest)
                  | A.SExp e => (unifyAt (ssp, "a statement of a `do`, of the `Monad` the `do` is in") (exp e, T.TAp (m, newMeta ())); go rest))
         in
           go ss before locals := saved
         end
     | A.ETuple es => T.tuple (List.map exp es)
     | A.EParen e => exp e
     | A.EList es =>
         let val t = newMeta ()
         in List.app (fn e => unifyAt (span, "an element of the list") (t, exp e)) es; T.list t end
     | A.EEnum (f, t, u) =>
         let
           val a = exp f
           val () = Option.app (fn e => unifyAt (span, "an enumeration") (a, exp e)) t
           val () = Option.app (fn e => unifyAt (span, "an enumeration") (a, exp e)) u
         in
           litPred (span, "enum", a, [preludeClass "Enum"]); T.list a
         end
     | A.EComp (e, qs) =>
         let
           val saved = !locals
           val () =
             List.app (fn A.S ({span = ssp, ...}, s) =>
                         case s of
                           A.SBind (p, g) =>
                             let val tg = exp g in unifyAt (ssp, "a generator") (tg, T.list (pat binderOf p)) end
                         | A.SLet ds => bindings (ds, false)
                         | A.SExp g => unifyAt (ssp, "a guard of a comprehension") (exp g, bool ()))
               qs
           val t = exp e
         in
           locals := saved; T.list t
         end
     | A.ELeftSec (e, q) =>
         let
           val top = qop q
           val te = exp e
           val b = newMeta ()
           val r = newMeta ()
         in
           unifyAt (span, "a left section") (top, T.fn_ (te, T.fn_ (b, r))); T.fn_ (b, r)
         end
     | A.ERightSec (q, e) =>
         let
           val top = qop q
           val te = exp e
           val a = newMeta ()
           val r = newMeta ()
         in
           unifyAt (span, "a right section") (top, T.fn_ (a, T.fn_ (te, r))); T.fn_ (a, r)
         end
     | A.ERecCon (c, fs) =>
         let
           val ct = lookupValue c
           val (args, res) = arrows ct
           val info = conInfo c
         in
           List.app
             (fn (f, e) =>
                let val te = exp e
                in
                  case info of
                    SOME {fields, ...} =>
                      (case List.find (fn (fk, _) => fk = nameKey f) (ListPair.zip (fields, List.tabulate (length fields, fn i => i))) of
                         SOME (_, i) => unifyAt (span, "a field of the record") (List.nth (args, i), te)
                       | NONE => err (nameSpan f, "the constructor `" ^ nameText c ^ "` has no field `" ^ nameText f ^ "`"))
                  | NONE => ()
                end)
             fs;
           res
         end
     | A.ERecUpd (e, fs) =>
         let
           val te = exp e
         in
           case fs of
             [] => te
           | (f0, _) :: _ =>
               case M.find (#fields (!genv), nameKey f0) of
                 NONE => (List.app (fn (_, v) => ignore (exp v)) fs; te)
               | SOME {tycon, ...} =>
                   let
                     val (params, cons) = case K.find (#tycons (!genv), tycon) of SOME {params, cons, ...} => (params, cons) | NONE => (0, [])
                     val updated = List.map (fn (f, _) => nameKey f) fs
                     (* 3.15.3: a parameter that only updated fields have may change *)
                     val kept =
                       List.concat
                         (List.map
                            (fn ck =>
                               case (M.find (#cons (!genv), ck), M.find (#values (!genv), ck)) of
                                 (SOME {fields, ...}, SOME {ty, ...}) =>
                                   if List.all (fn u => List.exists (fn f => f = u) fields) updated then
                                     let
                                       val (args, _) = arrows ty
                                     in
                                       List.concat (ListPair.map (fn (f, a) => if List.exists (fn u => u = f) updated then []
                                                                               else List.mapPartial (fn T.TGen i => SOME i | _ => NONE) (gensOf a))
                                                      (fields, args))
                                     end
                                   else []
                               | _ => [])
                            cons)
                     val tin = List.tabulate (params, fn _ => newMeta ())
                     val tout = List.tabulate (params, fn i => if List.exists (fn k => k = i) kept then List.nth (tin, i) else newMeta ())
                   in
                     unifyAt (span, "the record updated") (te, T.apply (T.TCon tycon, tin));
                     List.app
                       (fn (f, v) =>
                          let val tv = exp v
                          in
                            case M.find (#fields (!genv), nameKey f) of
                              SOME {tycon = tc, ty, ...} =>
                                if tc = tycon then unifyAt (span, "a field updated") (T.substGen (tout, ty), tv)
                                else err (nameSpan f, "the field `" ^ nameText f ^ "` is not of the type of `" ^ nameText f0 ^ "`")
                            | NONE => ()
                          end)
                       fs;
                     T.apply (T.TCon tycon, tout)
                   end
         end
     | A.ESig (e, c, t) =>
         let
           val (s, names) = schemeOf (c, t)
         in
           explicitExp (span, e, s, names, case e of A.E (_, A.EVar n) => "the signature on `" ^ nameText n ^ "`"
                                                   | _ => "the expression's signature");
           useScheme (span, s, "the expression's signature")
         end)
    handle Fail e => (err e; newMeta ())

  and qop q =
    case q of
      A.VarOp n => lookupValue n
    | A.ConOp n => lookupValue n

  and rhs (A.Rhs ({span, ...}, x)) : T.ty =
    let
      val saved = !locals
      fun wh w = case w of SOME ds => bindings (ds, false) | NONE => ()
      val t =
        case x of
          A.Plain (e, w) => (wh w; exp e)
        | A.Guarded (gs, w) =>
            let
              val () = wh w
              val r = newMeta ()
            in
              List.app (fn A.Guard ({span = gsp, ...}, g, e) =>
                          (unifyAt (gsp, "a guard") (exp g, bool ()) handle Fail e => err e;
                           unifyAt (gsp, "a guarded expression") (r, exp e) handle Fail e => err e))
                gs;
              r
            end
    in
      locals := saved; t
    end

  (* an expression with a signature, checked against it *)
  and explicitExp (span, e, s : T.scheme, names, what) =
    let
      val () = level := !level + 1
      val savedW = !wanted
      val savedG = !givens
      val () = wanted := []
      val rigids = skolemise names
      val params = List.map (fn p => (fresh "d", {cls = #cls p, ty = T.substGen (rigids, #ty p)})) (#ctx s)
      val () = givens := List.map (fn (n, p) => (p, IParam n)) params @ !givens
      val t = T.substGen (rigids, #ty s)
      val () = (unifyAt (span, what ^ inBinding ()) (t, exp e)) handle Fail e => err e
      val ws = solve (!wanted)
      val () = level := !level - 1
      val (deep, outer) = List.partition (fn {pred, ...} => List.exists (fn r => T.metaLevel r > !level) (T.metas (#ty pred))) ws
    in
      givens := savedG;
      wanted := outer @ savedW;
      defaultAll (deep, "");
      record ("sig", span, fn () => E.Binding {scheme = {vars = List.map rigidName rigids, ctx = List.map #2 params, ty = T.zonk t},
                                               params = List.map #1 params})
    end

  (* ---- binding groups (4.5) ---- *)

  and bindings (ds : A.decl list, top : bool) : unit = groupsOf (List.map (fn d => (!home, d)) ds, top)

  and groupsOf (ds : (string * A.decl) list, top : bool) : unit =
    let
      val bs = collect ds
      val sigs : (T.scheme * string list * HsSource.span) M.map =
        List.foldl
          (fn ((h, A.D ({span, ...}, A.DSig (vs, c, t))), m) =>
                ((home := h;
                  let val (s, names) = schemeOf (c, t)
                  in List.foldl (fn (v, m) => M.insert (m, nameKey v, (s, names, span))) m vs end)
                 handle HsSource.Error e => (err e; m) | Fail e => (err e; m))
            | (_, m) => m)
          M.empty ds
      fun simple b = case b of PatB {pat = A.P (_, A.PVar _), ...} => true | _ => false
      fun explicit b =
        case b of
          FunB {name, ...} => M.member (sigs, nameKey name)
        | PatB {vars = [v], ...} => simple b andalso M.member (sigs, nameKey v)
        | PatB _ => false
      (* R19: a pattern binding that is not simple is monomorphic in its
         constrained variables, whatever signature is given: a signature
         with a context for one of its variables is refused; one without
         is the variable's type *)
      val () =
        List.app (fn b as PatB {vars, ...} =>
                       if simple b then ()
                       else List.app (fn v => case M.find (sigs, nameKey v) of
                                                SOME (s, _, _) =>
                                                  if null (#ctx s) then ()
                                                  else err (nameSpan v, "a signature with a context for `" ^ nameText v ^
                                                                        "`, which a pattern binding that is not simple binds: its " ^
                                                                        "constrained variables stay monomorphic, whatever the " ^
                                                                        "signature (4.5.5, R19)")
                                              | NONE => ()) vars
                   | _ => ())
          bs
      fun sigOf k = Option.map #1 (M.find (sigs, k))
      val byKey = List.foldl (fn (b, m) => List.foldl (fn (k, m) => M.insert (m, k, b)) m (bkeys b)) M.empty bs
      fun freeVars b =
        let
          val out = ref []
          fun n nm = out := nameKey nm :: !out
          fun e (A.E (_, x)) =
            case x of
              A.EVar v => n v
            | A.EApp (f, a) => (e f; e a)
            | A.ESeq items => List.app (fn A.EA x => e x | A.EO (A.VarOp v) => n v | _ => ()) items
            | A.ELam (_, b) => e b
            | A.ELet (ds, b) => (List.app d ds; e b)
            | A.EIf (a, b, c) => (e a; e b; e c)
            | A.ECase (x, alts) => (e x; List.app (fn A.Alt (_, _, r) => rh r) alts)
            | A.EDo ss => List.app st ss
            | A.ETuple es => List.app e es
            | A.EParen x => e x
            | A.EList es => List.app e es
            | A.EEnum (a, b, c) => (e a; Option.app e b; Option.app e c)
            | A.EComp (x, qs) => (e x; List.app st qs)
            | A.ELeftSec (x, q) => (e x; case q of A.VarOp v => n v | _ => ())
            | A.ERightSec (q, x) => ((case q of A.VarOp v => n v | _ => ()); e x)
            | A.ERecCon (_, fs) => List.app (fn (_, x) => e x) fs
            | A.ERecUpd (x, fs) => (e x; List.app (fn (_, y) => e y) fs)
            | A.ESig (x, _, _) => e x
            | _ => ()
          and st (A.S (_, s)) = case s of A.SBind (_, x) => e x | A.SLet ds => List.app d ds | A.SExp x => e x
          and rh (A.Rhs (_, x)) =
            case x of
              A.Plain (x, w) => (e x; Option.app (List.app d) w)
            | A.Guarded (gs, w) => (List.app (fn A.Guard (_, g, x) => (e g; e x)) gs; Option.app (List.app d) w)
          and d (A.D (_, x)) = case x of A.DFun (_, r) => rh r | A.DPat (_, r) => rh r | _ => ()
        in
          (case b of FunB {clauses, ...} => List.app (fn (_, r) => rh r) clauses | PatB {rhs = r, ...} => rh r);
          !out
        end
      val keys = List.map bkey bs
      fun deps k =
        case M.find (byKey, k) of
          SOME b => List.mapPartial (fn v => Option.map bkey (M.find (byKey, v))) (freeVars b)
        | NONE => []
      (* R21(b): the signatures of one declaration group, made by binding
         alone, have contexts identical up to renaming *)
      val () =
        List.app
          (fn group =>
             case List.mapPartial (fn k => case M.find (byKey, k) of
                                             SOME b => if explicit b then Option.map (fn s => (s, b)) (M.find (sigs, k)) else NONE
                                           | NONE => NONE) group of
               ((s0, _, sp0), b0) :: rest =>
                 List.app (fn ((s, _, _), b) =>
                             if sameContext (#ctx s0, #ctx s) then ()
                             else once (sp0, "the signatures of `" ^ nameText (bname b0) ^ "` and `" ^
                                             nameText (bname b) ^ "`, one declaration group, have contexts that differ, which " ^
                                             "4.5.2 requires to be identical up to renaming (R21)"))
                   rest
             | [] => ())
          (HsScc.sccs (keys, deps))
      fun bindVar (k, b) = if top then unitValues := M.insert (!unitValues, k, b) else locals := M.insert (!locals, k, b)
      val () =
        List.app (fn b => if explicit b then
                            List.app (fn k => case M.find (sigs, k) of SOME (s, _, _) => bindVar (k, Poly s) | NONE => ()) (bkeys b)
                          else ())
          bs
      (* R21(c): a declaration group is made by binding alone (4.5.1), a
         signature cutting nothing, and its implicitly typed bindings are
         typed as one, each monomorphic in the group (4.4.1; Typing Haskell
         in Haskell's conformant form, 11.6.3), not split again by their
         dependencies on one another *)
      val implicitKeys = List.map bkey (List.filter (not o explicit) bs)
      val groups =
        List.filter (not o null)
          (List.map (List.filter (fn k => List.exists (fn w => w = k) implicitKeys)) (HsScc.sccs (keys, deps)))
    in
      List.app (fn g => implicitGroup (List.map (fn k => valOf (M.find (byKey, k))) g, bindVar, sigOf)) groups;
      List.app (fn b => if explicit b then explicitBinding (b, valOf (M.find (sigs, bkey b))) else ()) bs
    end

  (* contexts identical up to renaming: the same predicates, once each
     variable is named by where it first appears *)
  and sameContext (a : T.pred list, b : T.pred list) =
    let
      fun canon ps =
        let
          val order = ref []
          fun name t =
            case T.repr t of
              T.TGen i =>
                (case List.find (fn (j, _) => j = i) (!order) of
                   SOME (_, k) => "v" ^ Int.toString k
                 | NONE => (order := !order @ [(i, length (!order))]; "v" ^ Int.toString (length (!order) - 1)))
            | t' => T.show t'
        in
          sortStrings (List.map (fn {cls, ty} => cls ^ " " ^ name ty) ps)
        end
    in
      canon a = canon b
    end

  (* the type a binding's body has: its clauses' or its right-hand side's *)
  and bindingBody (b, bindPatVar : A.name * T.ty -> unit) : T.ty =
    case b of
      FunB {name, clauses, ...} =>
        let
          val t = newMeta ()
        in
          List.app
            (fn (f as A.F ({span, ...}, _), r) =>
               let
                 val saved = !locals
                 val args = List.map (pat binderOf) (funArgs f)
                 val tr = rhs r
               in
                 (unifyAt (span, "a clause of `" ^ nameText name ^ "`") (t, List.foldr T.fn_ tr args) handle Fail e => err e);
                 locals := saved
               end)
            clauses;
          t
        end
    | PatB {pat = p, rhs = r, ...} =>
        let
          val tp = pat bindPatVar p
          val tr = rhs r
        in
          (unifyAt (case p of A.P ({span, ...}, _) => span,
                    "the binding of " ^ String.concatWith " and " (List.map (fn v => "`" ^ nameText v ^ "`") (patVars p)) ^
                    (case r of
                       A.Rhs (_, A.Plain (A.E (_, A.EVar n), NONE)) => " to `" ^ nameText n ^ "`"
                     | _ => "") ^
                    monoGlobals r)
                   (tp, tr) handle Fail e => err e);
          tp
        end

  (* the monomorphic variables of the top level a right-hand side names,
     with their types, for a message *)
  and monoGlobals (A.Rhs (_, x)) =
    let
      val out = ref []
      fun e (A.E (_, x)) =
        case x of
          A.EVar n =>
            let val k = nameKey n
            in
              case (M.find (!unitValues, k), M.find (#values (!genv), k)) of
                (SOME (Mono t), _) => out := (nameText n, t) :: !out
              | (SOME (Poly {vars = 0, ctx = [], ty}), _) => out := (nameText n, ty) :: !out
              | (NONE, SOME {vars = 0, ctx = [], ty}) => out := (nameText n, ty) :: !out
              | _ => ()
            end
        | A.EApp (f, a) => (e f; e a)
        | A.ESeq items => List.app (fn A.EA x => e x | _ => ()) items
        | A.EParen x => e x
        | A.ETuple es => List.app e es
        | A.EList es => List.app e es
        | _ => ()
      val () = case x of A.Plain (x, _) => e x | A.Guarded (gs, _) => List.app (fn A.Guard (_, _, x) => e x) gs
      val found = List.rev (!out)
    in
      if null found then ""
      else " (from " ^ String.concatWith ", " (List.map (fn (n, t) => "`" ^ n ^ "`, of type `" ^ T.show (T.zonk t) ^ "`") found) ^ ")"
    end

  (* An implicitly typed group: inferred, then generalised, its
     constrained variables left open where Rule 1 restricts it. *)
  and implicitGroup (bs : binding list, bindVar, sigOf : string -> T.scheme option) =
    let
      val outerBinding = !curBinding
      val outer = !level
      val () = level := outer + 1
      val savedW = !wanted
      val () = wanted := []
      (* each binder's type, and its uses inside the group *)
      val binders =
        List.concat
          (List.map (fn b => case b of
                               FunB {name, ...} => [(name, newMeta (), ref [])]
                             | PatB {vars, ...} => List.map (fn v => (v, newMeta (), ref [])) vars) bs)
      val () = List.app (fn (n, t, uses) => bindVar (nameKey n, Rec (t, uses))) binders
      fun typeOf n = case List.find (fn (m, _, _) => nameKey m = nameKey n) binders of SOME (_, t, _) => t | NONE => newMeta ()
      val () =
        List.app
          (fn b =>
             (home := bhome b;
              curBinding := (case b of FunB {name, ...} => nameText name
                                     | PatB {vars, ...} => String.concatWith ", " (List.map nameText vars));
              case b of
                FunB {name, ...} =>
                  (unifyAt (nameSpan name, "the clauses of `" ^ nameText name ^ "`") (typeOf name, bindingBody (b, fn _ => ()))
                   handle Fail e => err e)
              | PatB {vars, ...} =>
                  (ignore (bindingBody (b, fn (v, t) => (unifyAt (nameSpan v, "a variable of a pattern binding") (typeOf v, t)
                                                         handle Fail e => err e)));
                   (* a signature without a context: the variable's type *)
                   List.app (fn v => case sigOf (nameKey v) of
                                       SOME s => if null (#ctx s) then
                                                   (unifyAt (nameSpan v, "the signature of `" ^ nameText v ^ "`")
                                                      (typeOf v, #3 (T.instantiate (s, !level, !home)))
                                                    handle Fail e => err e)
                                                 else ()
                                     | NONE => ()) vars)))
          bs
      val ws = solve (!wanted)
      val () = level := outer
      val () = curBinding := outerBinding
      val restricted = List.exists (fn PatB _ => true | _ => false) bs
      fun deep r = T.metaLevel r > outer
      val (cand, deferred) = List.partition (fn {pred, ...} => List.exists deep (T.metas (#ty pred))) ws
      (* Rule 1: a restricted group's constrained variables are not generalised *)
      val (retained, deferred) =
        if restricted then
          (List.app (fn {pred, ...} => List.app (fn r => if deep r then T.setLevel (r, outer) else ()) (T.metas (#ty pred))) cand;
           List.app (fn (n, t, _) => List.app (fn r => if T.metaLevel r <= outer then monoOwners := (T.metaId r, nameText n) :: !monoOwners
                                                       else ()) (T.metas t))
             binders;
           ([], cand @ deferred))
        else (cand, deferred)
      val types = List.map (fn (n, t, _) => (n, T.zonk t)) binders
      val typeMetas = List.concat (List.map (fn (_, t) => List.filter deep (T.metas t)) types)
      fun inTypes r = List.exists (fn r' => r' = r) typeMetas
      (* ambiguous: a predicate on a variable no binder's type has *)
      val (ambiguous, retained) = List.partition (fn {pred, ...} => not (List.all inTypes (List.filter deep (T.metas (#ty pred))))) retained
      val () = defaultAll (ambiguous, "")
      val retained = solve retained
      (* One context for the group (R21(a)): a predicate on a variable that
         some binder's type does not have is ambiguous for that binder, and
         is defaulted, for the group, or refused *)
      fun inAll r = List.all (fn (_, t) => List.exists (fn r' => r' = r) (T.metas t)) types
      val (partial, retained) = List.partition (fn {pred, ...} => not (List.all inAll (List.filter deep (T.metas (#ty pred))))) retained
      val () =
        defaultWith
          (partial, "",
           SOME (fn group =>
                   let
                     val missing = List.filter (fn (n, t) => List.exists (fn {pred, ...} : wanted =>
                                                                            List.exists (fn r => deep r andalso not (List.exists (fn r' => r' = r) (T.metas t)))
                                                                              (T.metas (#ty pred))) group) types
                   in
                     "the type of " ^ String.concatWith " and " (List.map (fn (n, _) => "`" ^ nameText n ^ "`") missing) ^
                     " is ambiguous: its declaration group, of " ^
                     String.concatWith " and " (List.map (fn (m, _) => "`" ^ nameText m ^ "`") types) ^
                     ", has one context for all its variables (4.5.2, R21), whose `" ^ showPreds (List.map #pred group) ^
                     "` names a variable that type does not have, and no default resolves it (4.3.4)"
                   end))
      val retained = solve retained
      (* the dictionary parameters: one for each predicate, those a superclass's gives aside *)
      val unique =
        List.foldl (fn (w as {pred, ...}, acc) =>
                      if List.exists (fn ({pred = q, ...} : wanted, _) => #cls q = #cls pred andalso eqTy (#ty q, #ty pred)) acc then acc
                      else acc @ [(w, fresh "d")])
          [] retained
      fun bySuper (p : T.pred) =
        List.find (fn ({pred = q, ...} : wanted, _) =>
                     #cls q <> #cls p andalso eqTy (#ty q, #ty p) andalso isSome (C.superPath (#classes (!genv), #cls q, #cls p)))
          unique
      val params = List.filter (fn ({pred, ...} : wanted, _) => not (isSome (bySuper pred))) unique
      fun dictFor (p : T.pred) =
        case List.find (fn ({pred = q, ...} : wanted, _) => #cls q = #cls p andalso eqTy (#ty q, #ty p)) params of
          SOME (_, name) => IParam name
        | NONE =>
            case bySuper p of
              SOME ({pred = q, ...}, _) =>
                let
                  val path = valOf (C.superPath (#classes (!genv), #cls q, #cls p))
                  fun walk (d, c :: (rest as s :: _)) = walk (ISuper (d, c, s), rest)
                    | walk (d, _) = d
                in
                  walk (dictFor q, path)
                end
            | NONE => IParam "?"
      val () = List.app (fn {pred, cell, ...} => cell := Solved (dictFor pred)) retained
      (* generalisation: each variable deeper than the group's level a rigid one, named *)
      val gens = List.foldl (fn (r, acc) => if List.exists (fn r' => r' = r) acc then acc else acc @ [r]) []
                   (typeMetas @ List.concat (List.map (fn ({pred, ...}, _) => List.filter deep (T.metas (#ty pred))) params))
      val gens = List.filter deep gens
      val rigids =
        List.map (fn r => let val rg = {id = (counter := !counter + 1; !counter), name = "t" ^ Int.toString (T.metaId r)}
                          in r := T.Link (T.TRigid rg); rg end) gens
      val ctx = List.map (fn ({pred, ...}, _) => {cls = #cls pred, ty = T.zonk (#ty pred)}) params
      val paramNames = List.map #2 params
      fun abstract (vars : T.rigid list) t =
        case T.repr t of
          T.TRigid {id, ...} =>
            (case List.find (fn (({id = id', ...} : T.rigid), _) => id = id') (ListPair.zip (vars, List.tabulate (length vars, fn i => i))) of
               SOME (_, i) => T.TGen i
             | NONE => t)
        | T.TAp (a, b) => T.TAp (abstract vars a, abstract vars b)
        | t' => t'
    in
      List.app
        (fn (n, t, uses) =>
           let
             val tz = T.zonk t
             val vars = List.filter (fn {id, ...} => occursRigid (id, tz)) rigids
             val scheme = {vars = length vars, ctx = List.map (fn {cls, ty} => {cls = cls, ty = abstract vars ty}) ctx,
                           ty = abstract vars tz}
           in
             bindVar (nameKey n, Poly scheme);
             List.app (fn (_, tys, cells) =>
                         (tys := List.map T.TRigid vars;
                          cells := List.map (fn p => ref (Solved (IParam p))) paramNames))
               (!uses);
             record ("bind", nameSpan n,
                     fn () => E.Binding {scheme = {vars = List.map #name vars, ctx = List.map (fn {cls, ty} => {cls = cls, ty = T.zonk ty}) ctx,
                                                   ty = T.zonk tz},
                                         params = paramNames})
           end)
        binders;
      wanted := deferred @ savedW
    end

  and occursRigid (id, t) =
    case T.repr t of
      T.TRigid {id = id', ...} => id = id'
    | T.TAp (a, b) => occursRigid (id, a) orelse occursRigid (id, b)
    | _ => false

  (* A binding checked against a type, with givens: an explicitly typed
     binding, an instance's method, a class's default. *)
  and checkAgainst (b, names : string list, s : T.scheme, prefix : T.ty list, more : (string * T.pred) list, span) =
    let
      val outer = !level
      val () = level := outer + 1
      val savedW = !wanted
      val savedG = !givens
      val () = wanted := []
      val rigids = skolemise names
      val tys = prefix @ rigids
      val params = List.map (fn p => (fresh "d", {cls = #cls p, ty = T.substGen (tys, #ty p)})) (#ctx s)
      val () = givens := List.map (fn (n, p) => (p, IParam n)) (params @ more) @ !givens
      val t = T.substGen (tys, #ty s)
      val () = home := bhome b
      val outerBinding = !curBinding
      val () = curBinding := (case b of FunB {name, ...} => nameText name
                                      | PatB {vars, ...} => String.concatWith ", " (List.map nameText vars))
      val () =
        case b of
          FunB _ => (unifyAt (span, "the signature of `" ^ nameText (case b of FunB {name, ...} => name | _ => raise Match) ^ "`")
                       (t, bindingBody (b, fn _ => ())) handle Fail e => err e)
        | PatB {pat, ...} =>
            ignore (bindingBody (b, fn (v, tv) => (unifyAt (nameSpan v, "the signature of `" ^ nameText v ^ "`") (t, tv)
                                                   handle Fail e => err e)))
      val ws = solve (!wanted)
      val () = level := outer
      val () = curBinding := outerBinding
      val (deep, outerWs) = List.partition (fn {pred, ...} => List.exists (fn r => T.metaLevel r > outer) (T.metas (#ty pred))) ws
    in
      givens := savedG;
      wanted := outerWs @ savedW;
      defaultAll (deep, "");
      (List.map rigidName rigids, List.map #2 params, List.map #1 params, t)
    end

  and explicitBinding (b, (s : T.scheme, names, span)) =
    let
      val (vars, ctx, params, t) = checkAgainst (b, names, s, [], [], span)
      val n = case b of FunB {name, ...} => name | PatB {vars = [v], ...} => v | _ => raise Fail (span, "a binding")
    in
      record ("bind", nameSpan n, fn () => E.Binding {scheme = {vars = vars, ctx = List.map (fn {cls, ty} => {cls = cls, ty = T.zonk ty}) ctx,
                                                               ty = T.zonk t},
                                                      params = params})
    end
    handle Fail e => err e

  (* ---- declarations of a unit ---- *)

  fun declsOf (m : module_) = let val A.Module (_, {decls, ...}) = #ast m in List.map (fn d => (#id m, d)) decls end

  fun typeVarNames vs = List.map (fn A.Name (_, {name, ...}) => name) vs

  fun varIndex names n =
    case List.find (fn (m, _) => m = n) (ListPair.zip (names, List.tabulate (length names, fn i => i))) of
      SOME (_, i) => T.TGen i
    | NONE => raise Fail (HsSource.noSpan, "the type variable `" ^ n ^ "` is not a parameter of its declaration")

  fun constrParts (A.C (_, x)) =
    case x of
      A.CPlain (n, args) => (n, List.map #2 args, List.map (fn _ => NONE) args)
    | A.CInfix ((_, l), n, (_, r)) => (n, [l, r], [NONE, NONE])
    | A.CRec (n, fs) =>
        let val each = List.concat (List.map (fn A.Field (_, vs, _, t) => List.map (fn v => (v, t)) vs) fs)
        in (n, List.map #2 each, List.map (SOME o #1) each) end

  (* the constructors and fields of `data` and `newtype` *)
  fun dataDecl (h, A.D ({span, ...}, x)) =
    let
      val (cx, c, vs, cs) =
        case x of
          A.DData (cx, c, vs, cs, _) => (cx, c, vs, cs)
        | A.DNewtype (cx, c, vs, k, _) => (cx, c, vs, [k])
        | _ => raise Fail (span, "")
      val names = typeVarNames vs
      val tycon = K.keyOf c
      val result = T.apply (T.TCon tycon, List.tabulate (length names, T.TGen))
      val tenv = #tycons (!genv)
      val ctx = K.contextPreds (tenv, varIndex names) cx
      fun one k =
        let
          val (n, tys, fieldNames) = constrParts k
          val fts = List.map (K.convert (tenv, varIndex names)) tys
          val used = List.concat (List.map (fn t => List.mapPartial (fn T.TGen i => SOME i | _ => NONE) (gens t)) fts)
          val cctx = List.filter (fn {ty, ...} => case ty of T.TGen i => List.exists (fn j => j = i) used | _ => false) ctx
          val ckey = nameKey n
          val scheme = {vars = length names, ctx = cctx, ty = List.foldr T.fn_ result fts}
          val fields = List.map (fn SOME f => nameKey f | NONE => "") fieldNames
          val {values, tycons, classes, cons, fields = fs, methods} = !genv
          val fs' =
            ListPair.foldl
              (fn (SOME f, ft, m) =>
                    let val fk = nameKey f
                    in
                      case M.find (m, fk) of
                        SOME {tycon, ty, cons} => M.insert (m, fk, {tycon = tycon, ty = ty, cons = cons @ [(ckey, 0)]})
                      | NONE => M.insert (m, fk, {tycon = tycon, ty = ft, cons = [(ckey, 0)]})
                    end
                | (NONE, _, m) => m)
              fs (fieldNames, fts)
          val values' =
            ListPair.foldl
              (fn (SOME f, ft, m) => M.insert (m, nameKey f, {vars = length names, ctx = [], ty = T.fn_ (result, ft)})
                | (NONE, _, m) => m)
              (M.insert (values, ckey, scheme)) (fieldNames, fts)
        in
          genv := {values = values', tycons = tycons, classes = classes,
                   cons = M.insert (cons, ckey, {tycon = tycon, arity = length fts, fields = fields}), fields = fs', methods = methods}
        end
    in
      List.app one cs
    end
  and gens t =
    case T.repr t of
      T.TAp (a, b) => gens a @ gens b
    | t' => [t']

  (* a class: its superclasses and methods *)
  fun classDecl (h, A.D ({span, ...}, A.DClass (cx, c, v, body)), kinds) =
        let
          val key = K.keyOf c
          val vname = case v of A.Name (_, {name, ...}) => name
          val kind = case List.find (fn (k, _) => k = key) kinds of SOME (_, k) => k | NONE => T.KStar
          val supers =
            List.map #cls (K.contextPreds (#tycons (!genv), fn n => if n = vname then T.TGen 0
                                                                     else raise Fail (span, "the context of the class `" ^ nameText c ^
                                                                                            "` names `" ^ n ^ "`, where only its variable `" ^
                                                                                            vname ^ "` may stand (4.3.1)")) cx)
          val methods =
            List.concat
              (List.map
                 (fn A.D (_, A.DSig (ms, mc, mt)) =>
                       let
                         val others = List.filter (fn n => n <> vname) (K.tyVars mt @ (case mc of SOME t => K.tyVars t | NONE => []))
                         val others = List.foldl (fn (n, acc) => if List.exists (fn m => m = n) acc then acc else acc @ [n]) [] others
                         val names = vname :: others
                         val vars = ref (M.insert (M.empty, vname, kind))
                         val kenv = {env = #tycons (!genv), classKind = classKindOf, vars = vars}
                         val () = (K.checkContext kenv mc; K.checkType kenv (mt, T.KStar)) handle HsSource.Error e => err e
                         val own = {vars = length names, ctx = K.contextPreds (#tycons (!genv), varIndex names) mc,
                                    ty = K.convert (#tycons (!genv), varIndex names) mt}
                         val () =
                           if List.exists (fn {ty, ...} => (case T.repr ty of T.TGen 0 => true | _ => false)) (#ctx own) then
                             err (span, "a method's context constrains its class's variable `" ^ vname ^ "` (4.3.1)")
                           else ()
                       in
                         List.map (fn m => (nameKey m, own)) ms
                       end
                   | _ => [])
                 (getOpt (body, [])))
          val {values, tycons, classes, cons, fields, methods = ms} = !genv
          val values' =
            List.foldl (fn ((k, own : T.scheme), m) =>
                          M.insert (m, k, {vars = #vars own, ctx = {cls = key, ty = T.TGen 0} :: #ctx own, ty = #ty own}))
              values methods
        in
          genv := {values = values', tycons = tycons, cons = cons, fields = fields,
                   classes = C.addClass (classes, {key = key, supers = supers, methods = List.map #1 methods, kind = kind}),
                   methods = List.foldl (fn ((k, own), m) => M.insert (m, k, {cls = key, scheme = own})) ms methods}
        end
    | classDecl _ = ()

  fun addInstance (i : C.instance, span) =
    let val {values, tycons, classes, cons, fields, methods} = !genv
    in
      if isSome (C.findInstance (classes, #cls i, #tycon i)) then
        err (span, "two instances of `" ^ T.nameOfKey (#cls i) ^ "` at `" ^ T.nameOfKey (#tycon i) ^ "`, where a program has one")
      else genv := {values = values, tycons = tycons, classes = C.addInstance (classes, i), cons = cons, fields = fields,
                    methods = methods}
    end

  (* an instance's head: its type constructor and variables *)
  fun instanceHead (span, t : A.ty) =
    let
      fun astHead (A.T (_, x)) = case x of A.TApp (f, _) => astHead f | A.TParen u => astHead u | A.TCon n => SOME n | _ => NONE
      val () =
        case astHead t of
          SOME n =>
            (case K.find (#tycons (!genv), K.keyOf n) of
               SOME {synonym = SOME _, ...} =>
                 raise Fail (span, "an instance at the type synonym `" ^ nameText n ^ "`, where an instance is at a data type " ^
                                   "or a newtype (4.3.2)")
             | _ => ())
        | NONE => ()
      val names = K.tyVars t
      val ht = K.convert (#tycons (!genv), varIndex names) t
      val (h, args) = T.spine ht
      val distinct = List.all (fn (i, a) => case T.repr a of T.TGen j => i = j | _ => false)
                       (ListPair.zip (List.tabulate (length args, fn i => i), args))
    in
      case h of
        T.TCon tc =>
          if distinct andalso length args = length names then (tc, names)
          else raise Fail (span, "an instance's type is a type constructor applied to distinct type variables (4.3.2)")
      | _ => raise Fail (span, "an instance's type is a type constructor applied to distinct type variables (4.3.2)")
    end

  fun writtenInstance (h, A.D ({span, ...}, A.DInstance (cx, c, t, _))) =
        (let
           val cls = K.keyOf c
           val (tc, names) = instanceHead (span, t)
           val () = case K.find (#tycons (!genv), tc) of
                      SOME {synonym = SOME _, ...} => raise Fail (span, "an instance at the type synonym `" ^ T.nameOfKey tc ^
                                                                         "`, where an instance is at a data type or newtype (4.3.2)")
                    | _ => ()
           val vars = ref M.empty
           val kenv = {env = #tycons (!genv), classKind = classKindOf, vars = vars}
           val () = (K.checkContext kenv cx;
                     case classKindOf cls of SOME k => K.checkType kenv (t, k) | NONE => ())
                    handle HsSource.Error e => err e
           val ctx = K.contextPreds (#tycons (!genv), varIndex names) cx
         in
           addInstance ({id = C.instanceId (cls, tc), cls = cls, tycon = tc, vars = length names, ctx = ctx, derived = false,
                         home = h}, span)
         end
         handle Fail e => err e)
    | writtenInstance _ = ()

  (* the derived instances of a data type, their contexts empty until the
     fixpoint; each with the types of its fields *)
  (* a constructor as deriving reads it *)
  fun derivedConstr (A.C (_, x)) : HsDerive.constr =
    let
      val (n, arity, fields, isInf) =
        case x of
          A.CPlain (n, args) => (n, length args, [], false)
        | A.CInfix (_, n, _) => (n, 2, [], true)
        | A.CRec (n, fs) => let val vs = List.concat (List.map (fn A.Field (_, vs, _, _) => vs) fs) in (n, length vs, vs, false) end
    in
      {name = n, arity = arity, fields = fields, isInfix = isInf, fixity = getOpt (!fixityOfKey (nameKey n), (A.Infixl, 9))}
    end

  fun derivedInstances (h, A.D ({span, ...}, x)) =
    let
      val parts =
        case x of
          A.DData (cx, c, vs, cs, SOME (A.Deriv (_, _, classes))) => SOME (cx, c, vs, cs, classes)
        | A.DNewtype (cx, c, vs, k, SOME (A.Deriv (_, _, classes))) => SOME (cx, c, vs, [k], classes)
        | _ => NONE
    in
      case parts of
        NONE => []
      | SOME (cx, c, vs, cs, classes) =>
          let
            val names = typeVarNames vs
            (* 4.3.3: a derived instance's context has the data type's *)
            val dataCtx = K.contextPreds (#tycons (!genv), varIndex names) cx
            val tc = K.keyOf c
            val fields = List.concat (List.map (fn k => let val (_, tys, _) = constrParts k
                                                        in List.map (K.convert (#tycons (!genv), varIndex names)) tys end) cs)
            val enumeration = List.all (fn k => let val (_, tys, _) = constrParts k in null tys end) cs
            val derivable = List.mapPartial (fn n => prelude ("t", n)) ["Eq", "Ord", "Enum", "Bounded", "Show", "Read", "Ix"]
          in
            List.mapPartial
              (fn cn =>
                 let val cls = K.keyOf cn
                 in
                   if not (List.exists (fn d => d = cls) derivable) then
                     (err (nameSpan cn, "the class `" ^ nameText cn ^ "` cannot be derived: only Eq, Ord, Enum, Bounded, Show, " ^
                                        "Read and Ix can (10)");
                      NONE)
                   else if (cls = preludeClass "Enum") andalso not enumeration then
                     (err (nameSpan cn, "`Enum` is derived only for an enumeration, a type whose constructors take no field (10.2)"); NONE)
                   else if (cls = preludeClass "Bounded" orelse cls = preludeClass "Ix") andalso not enumeration andalso length cs <> 1 then
                     (err (nameSpan cn, "`" ^ nameText cn ^ "` is derived only for an enumeration or a type of one constructor (10)"); NONE)
                   else
                     (addInstance ({id = C.instanceId (cls, tc), cls = cls, tycon = tc, vars = length names, ctx = [], derived = true,
                                    home = h}, nameSpan cn);
                      SOME {id = C.instanceId (cls, tc), cls = cls, vars = length names, fields = fields, dataCtx = dataCtx, span = nameSpan cn,
                            home = h, tycon = tc, constrs = List.map derivedConstr cs})
                 end)
              classes
          end
    end

  (* 10.1: the derived instances' contexts, the least that make every
     field's type an instance, by a fixpoint *)
  fun deriveContexts derived =
    let
      exception NoInstance of T.pred
      fun reduce (p as {cls, ty} : T.pred) : T.pred list =
        case T.spine ty of
          (T.TGen _, []) => [p]
        | (T.TGen _, _) => raise NoInstance p
        | (T.TCon tc, args) =>
            (case C.findInstance (#classes (!genv), cls, tc) of
               SOME {ctx, vars, ...} =>
                 if vars = length args then List.concat (List.map (fn {cls, ty} => reduce {cls = cls, ty = T.substGen (args, ty)}) ctx)
                 else raise NoInstance p
             | NONE => raise NoInstance p)
        | _ => raise NoInstance p
      fun simplify ps =
        let
          val unique = List.foldl (fn (p, acc) => if List.exists (fn q => #cls q = #cls p andalso eqTy (#ty q, #ty p)) acc then acc else acc @ [p]) [] ps
        in
          List.filter (fn p => not (List.exists (fn q => #cls q <> #cls p andalso eqTy (#ty q, #ty p) andalso
                                                         isSome (C.superPath (#classes (!genv), #cls q, #cls p))) unique)) unique
        end
      fun key ps = sortStrings (List.map (fn {cls, ty} => cls ^ " " ^ T.show ty) ps)
      val failed = ref []
      fun round 0 = ()
        | round n =
            let
              val changed =
                List.foldl
                  (fn ({id, cls, vars, fields, span, dataCtx, ...}, changed) =>
                     if List.exists (fn f => f = id) (!failed) then changed
                     else
                       let
                         val ctx = simplify (dataCtx @ List.concat (List.map (fn f => reduce {cls = cls, ty = f}) fields))
                                   handle NoInstance p =>
                                     (failed := id :: !failed;
                                      err (span, "`" ^ T.nameOfKey cls ^ "` cannot be derived: no instance for `" ^
                                                 T.showPred p ^ "`, which a field's type needs" ^
                                                 (case T.spine (#ty p) of (T.TGen _, _ :: _) => ", a context that is not simple (R23)"
                                                                         | _ => ""));
                                      [])
                         val old = case List.find (fn i => #id i = id) (C.instances (#classes (!genv))) of SOME i => #ctx i | NONE => []
                       in
                         if key ctx = key old then changed
                         else
                           let val {values, tycons, classes, cons, fields, methods} = !genv
                           in
                             genv := {values = values, tycons = tycons, classes = C.withContext (classes, id, ctx), cons = cons,
                                      fields = fields, methods = methods};
                             true
                           end
                       end)
                  false derived
            in
              if changed then round (n - 1) else ()
            end
    in
      round 50;
      !failed
    end

  (* an instance's context's dictionaries and its class's superclasses'
     dictionaries at its type (4.3.2), recorded *)
  fun instanceEvidence (span, i : C.instance, names : string list) =
    let
      val outer = !level
      val () = level := outer + 1
      val savedW = !wanted
      val savedG = !givens
      val () = wanted := []
      val () = home := #home i
      val rigids = skolemise names
      val headTy = T.apply (T.TCon (#tycon i), rigids)
      val params = List.map (fn {cls, ty} => (fresh "d", {cls = cls, ty = T.substGen (rigids, ty)})) (#ctx i)
      val () = givens := List.map (fn (n, p) => (p, IParam n)) params @ !givens
      val supers = case C.findClass (#classes (!genv), #cls i) of SOME {supers, ...} => supers | NONE => []
      val cells =
        List.map (fn s => let val c = ref Pending
                          in wanted := {pred = {cls = s, ty = headTy}, cell = c, span = span, home = #home i,
                                        origin = "the instance's superclass `" ^ T.nameOfKey s ^ "`", binding = ""} :: !wanted; c end)
          supers
      val rest = solve (!wanted)
      val () = List.app (fn {pred, span, ...} => err (span, "the instance needs `" ^ T.showPred pred ^ "`, its superclass's, which its context does not give (4.3.2)")) rest
    in
      level := outer;
      wanted := savedW;
      record ("instance", span, fn () => E.Instance {inst = #id i, vars = List.map rigidName rigids, params = List.map #1 params,
                                                      supers = List.map finalCell cells});
      (rigids, params)
      before givens := savedG
    end

  (* the methods of an instance, each checked at the instance's type *)
  (* the methods of an instance, each checked at the instance's type *)
  fun checkMethods (h, span, cls, headTy, params, body : A.decl list) =
    List.app
      (fn b =>
         let
           val n = case b of FunB {name, ...} => name | PatB {vars = v :: _, ...} => v | _ => raise Fail (span, "a method")
         in
           case M.find (#methods (!genv), nameKey n) of
             SOME {cls = mc, scheme = own} =>
               if mc <> cls then err (nameSpan n, "`" ^ nameText n ^ "` is no method of the class `" ^ T.nameOfKey cls ^ "`")
               else
                 let
                   val ownNames = List.tabulate (#vars own - 1, fn i => "m" ^ Int.toString (i + 1))
                   val s = {vars = #vars own, ctx = #ctx own, ty = #ty own}
                   val (vars, ctx, ps, ty) = checkAgainst (b, ownNames, s, [headTy], params, nameSpan n)
                 in
                   record ("bind", nameSpan n, fn () => E.Binding {scheme = {vars = vars, ctx = List.map (fn {cls, ty} => {cls = cls, ty = T.zonk ty}) ctx,
                                                                            ty = T.zonk ty},
                                                                   params = ps})
                 end
           | NONE => err (nameSpan n, "`" ^ nameText n ^ "` is no method of the class `" ^ T.nameOfKey cls ^ "`")
         end
         handle Fail e => err e)
      (collect (List.map (fn d => (h, d)) body))

  fun instanceBodies (h, A.D ({span, ...}, A.DInstance (cx, c, t, body))) =
        (let
           val cls = K.keyOf c
           val (tc, names) = instanceHead (span, t)
         in
           case C.findInstance (#classes (!genv), cls, tc) of
             SOME i =>
               if #home i <> h then ()
               else
                 let
                   val (rigids, params) = instanceEvidence (span, i, names)
                 in
                   checkMethods (h, span, cls, T.apply (T.TCon tc, rigids), params, getOpt (body, []))
                 end
           | NONE => ()
         end
         handle Fail e => err e)
    | instanceBodies _ = ()

  (* the default methods of a class *)
  fun classBodies (h, A.D ({span, ...}, A.DClass (_, c, v, body))) =
        let
          val cls = K.keyOf c
          val vname = case v of A.Name (_, {name, ...}) => name
          val p = fresh "d"
          val () = record ("class", span, fn () => E.Class {param = p})
        in
          List.app
            (fn b =>
               (let
                  val n = case b of FunB {name, ...} => name | PatB {vars = v :: _, ...} => v | _ => raise Fail (span, "a method")
                in
                  case M.find (#methods (!genv), nameKey n) of
                    SOME {scheme = own, ...} =>
                      let
                        val outerLevel = !level
                        val () = level := outerLevel + 1
                        val cv = case skolemise [vname] of [r] => r | _ => T.unit
                        val () = level := outerLevel
                        val ownNames = List.tabulate (#vars own - 1, fn i => "m" ^ Int.toString (i + 1))
                        val (vars, ctx, ps, ty) =
                          checkAgainst (b, ownNames, own, [cv], [(p, {cls = cls, ty = cv})], nameSpan n)
                      in
                        record ("bind", nameSpan n, fn () => E.Binding {scheme = {vars = rigidName cv :: vars,
                                                                                  ctx = List.map (fn {cls, ty} => {cls = cls, ty = T.zonk ty}) ctx,
                                                                                  ty = T.zonk ty},
                                                                        params = p :: ps})
                      end
                  | NONE => err (nameSpan n, "`" ^ nameText n ^ "` is no method of the class `" ^ nameText c ^ "`")
                end
                handle Fail e => err e))
            (collect (List.map (fn d => (h, d)) (List.filter (fn A.D (_, A.DSig _) => false | A.D (_, A.DFixity _) => false | _ => true)
                                                   (getOpt (body, [])))))
        end
    | classBodies _ = ()

  (* a module's `default` (4.3.4): each type an instance of Num *)
  fun defaultDecl (h, A.D ({span, ...}, A.DDefault ts)) =
        let
          val tys = List.map (fn t => (K.checkType {env = #tycons (!genv), classKind = classKindOf, vars = ref M.empty} (t, T.KStar);
                                       K.convert (#tycons (!genv), fn _ => raise Fail (span, "a default type has no variable")) t)) ts
                    handle HsSource.Error e => (err e; []) | Fail e => (err e; [])
          val num = preludeClass "Num"
        in
          List.app (fn t => if holdsAt ([{cls = num, ty = t}], t) then () else
                              err (span, "the default type `" ^ T.show t ^ "` is not an instance of `Num` (4.3.4)")) tys;
          if M.member (!defaultsOf, h) then err (span, "two `default` declarations in one module (4.3.4)")
          else defaultsOf := M.insert (!defaultsOf, h, (tys, true))
        end
    | defaultDecl _ = ()

  (* a type closed for the records: what no binding generalised and no
     default fixed is `()` *)
  fun ground t =
    case T.repr t of
      T.TMeta r => (r := T.Link T.unit; T.unit)
    | T.TAp (a, b) => T.TAp (ground a, ground b)
    | t' => t'

  fun check {env, unit, cycleDefault, prelude = pre, fixity, evidence} =
    let
      val () = (errors := []; said := []; monoOwners := []; argOf := ""; curBinding := ""; level := 0; wanted := []; givens := []; rigidLevels := M.empty; pendingRecords := [];
                genv := env; preludeKey := pre; cycle := cycleDefault; unitModules := List.map #id unit; defaultsOf := M.empty;
                crossFixings := []; locals := M.empty; unitValues := M.empty; fixityOfKey := fixity;
                standard := (fn cls => String.isPrefix "thaskell98:" cls))
      val decls = List.concat (List.map declsOf unit)
      (* kinds, then the type constructors, classes, constructors *)
      val typeDecls = List.filter (fn (_, A.D (_, x)) => case x of A.DData _ => true | A.DNewtype _ => true | A.DType _ => true
                                                                 | A.DClass _ => true | _ => false) decls
      val {env = tenv, classKinds, errors = kerrs} = K.infer {env = #tycons (!genv), classKind = classKindOf, decls = typeDecls}
      val () = List.app err kerrs
      val () = let val {values, classes, cons, fields, methods, ...} = !genv
               in genv := {values = values, tycons = tenv, classes = classes, cons = cons, fields = fields, methods = methods} end
      val () = List.app (fn d => (classDecl (#1 d, #2 d, classKinds) handle Fail e => err e | HsSource.Error e => err e)) decls
      val () = List.app (fn (h, d as A.D (_, x)) => case x of
                                                      A.DData _ => (dataDecl (h, d) handle Fail e => err e | HsSource.Error e => err e)
                                                    | A.DNewtype _ => (dataDecl (h, d) handle Fail e => err e | HsSource.Error e => err e)
                                                    | _ => ()) decls
      (* instances, written and derived *)
      val () = List.app writtenInstance decls
      val derived = List.concat (List.map (fn d => (derivedInstances d handle Fail e => (err e; []) | HsSource.Error e => (err e; []))) decls)
      val underived = deriveContexts derived
      val () = List.app defaultDecl decls
      (* the values of the unit, joined *)
      val values = List.filter (fn (_, A.D (_, x)) => case x of A.DFun _ => true | A.DPat _ => true | A.DSig _ => true | _ => false) decls
      val () = groupsOf (values, true)
      (* the derived instances' evidence, and the bodies of classes and instances *)
      val () = List.app classBodies decls
      val () = List.app instanceBodies decls
      (* the derived instances: their evidence, and their methods made by
         HsDerive (D33's C) and checked as a user's (M14) *)
      val generated =
        List.mapPartial
          (fn {id, cls, vars, span, home = h, tycon, constrs, ...} =>
             if List.exists (fn f => f = id) underived then NONE      (* an instance that cannot be derived, said *)
             else
             case List.find (fn i => #id i = id) (C.instances (#classes (!genv))) of
               SOME i =>
                 let
                   val (rigids, params) = instanceEvidence (span, i, List.tabulate (vars, fn k => "a" ^ Int.toString (k + 1)))
                   val file = "derived " ^ C.showInstance id ^ " in " ^ h
                 in
                   case HsDerive.methods {cls = cls, constrs = constrs, entity = !preludeKey, file = file} of
                     SOME ds => (home := h; checkMethods (h, span, cls, T.apply (T.TCon tycon, rigids), params, ds); SOME (h, id, ds))
                   | NONE => NONE
                 end
             | NONE => NONE)
          derived
      (* Rule 2: what the top level left open, defaulted at the end of the module *)
      val () = defaultAll (solve (!wanted), ", left open by the monomorphism restriction to the end of its module (4.5.5, R20)")
      val () = wanted := []
      val () =
        case !cycle of
          PerModule =>
            List.app (fn (h, by, span, id) =>
                        err (span, (case List.find (fn (i, _) => i = id) (!monoOwners) of
                                      SOME (_, owner) => "`" ^ owner ^ "` of " ^ Mo.moduleName h ^ ", which its restriction leaves monomorphic (4.5.5),"
                                    | NONE => "a variable of " ^ Mo.moduleName h ^ " that its restriction leaves monomorphic (4.5.5)") ^
                                   " takes its type from a use in " ^ Mo.moduleName by ^ ", while Rule 2 closes it at the end " ^
                                   "of its own module (D30; --cycle-default=scc closes it at the end of the cycle)"))
              (List.rev (!crossFixings))
        | PerGroup => ()
      (* main has the type IO t (5) *)
      val () =
        List.app
          (fn {id, ...} =>
             if Mo.moduleName id <> "Main" then ()
             else
               case M.find (!unitValues, Mo.key {space = Mo.Value, home = id, name = "main"}) of
                 SOME b =>
                   let
                     val t = case b of Poly s => #3 (T.instantiate (s, 0, id)) | Mono t => t | Rec (t, _) => t
                   in
                     T.unify (fn _ => ()) (t, T.TAp (preludeTy "IO", T.newMeta (0, id)))
                     handle T.Mismatch _ => err (HsSource.noSpan, "`main` has the type `" ^ T.show (T.zonk t) ^
                                                                  "`, where a program's main is of type `IO t` (5)")
                   end
               | NONE => ())
          unit
      (* the records, closed *)
      val () = List.app (fn (k, f) => E.add (evidence, k, closeRecord (f ()))) (List.rev (!pendingRecords))
      val () = pendingRecords := []
      val {tycons, classes, cons, fields, methods, values} = !genv
      val values =
        M.foldl (fn (k, b, m) =>
                   M.insert (m, k, case b of
                                     Poly {vars, ctx, ty} => {vars = vars, ctx = List.map (fn {cls, ty} => {cls = cls, ty = ground ty}) ctx,
                                                              ty = ground ty}
                                   | Mono t => {vars = 0, ctx = [], ty = ground t}
                                   | Rec (t, _) => {vars = 0, ctx = [], ty = ground t}))
          values (!unitValues)
      val result = {values = values, tycons = tycons, classes = classes, cons = cons, fields = fields, methods = methods}
    in
      unitValues := M.empty; locals := M.empty;
      {env = result, errors = List.rev (!errors), derived = generated}
    end

  and closeRecord r =
    case r of
      E.Use {tys, dicts} => E.Use {tys = List.map ground tys, dicts = List.map closeDict dicts}
    | E.Overloaded {ty, dicts} => E.Overloaded {ty = ground ty, dicts = List.map (fn (c, d) => (c, closeDict d)) dicts}
    | E.Binding {scheme = {vars, ctx, ty}, params} =>
        E.Binding {scheme = {vars = vars, ctx = List.map (fn {cls, ty} => {cls = cls, ty = ground ty}) ctx, ty = ground ty}, params = params}
    | E.Mono t => E.Mono (ground t)
    | E.Instance {inst, vars, params, supers} => E.Instance {inst = inst, vars = vars, params = params, supers = List.map closeDict supers}
    | E.Defaulted {var, preds, candidates, module_, choice} =>
        E.Defaulted {var = var, preds = List.map (fn {cls, ty} => {cls = cls, ty = ground ty}) preds, candidates = candidates,
                     module_ = module_, choice = ground choice}
    | r => r

  and closeDict d =
    case d of
      E.DParam _ => d
    | E.DInst {inst, tys, args} => E.DInst {inst = inst, tys = List.map ground tys, args = List.map closeDict args}
    | E.DSuper {dict, cls, super} => E.DSuper {dict = closeDict dict, cls = cls, super = super}
end
