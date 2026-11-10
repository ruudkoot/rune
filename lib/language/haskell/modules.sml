(* Implements: HS_MODULES *)
structure HsModules :> HS_MODULES =
struct
  structure A = HsAst
  structure M = HsStringMap

  datatype space = Value | Type
  type entity = {space : space, home : string, name : string}

  fun spaceChar Value = "v"
    | spaceChar Type = "t"

  fun key ({space, home, name} : entity) = spaceChar space ^ home ^ "\t" ^ name

  fun moduleName id =
    let
      fun go i = if i < 0 then id else if String.sub (id, i) = #":" then String.extract (id, i + 1, NONE) else go (i - 1)
    in
      go (size id - 1)
    end

  datatype sort = Var | Con | Field | Method | TyCon | Synonym | Class

  type def = {entity : entity, sort : sort, parent : entity option, arity : int, span : HsSource.span}

  fun nameOf (A.Name (_, {name, ...})) = name
  fun spanOf (A.Name ({span, ...}, _)) = span

  (* ---- what a module defines ---- *)

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
    | A.PSeq items => List.concat (List.map (fn A.PA p => patVars p | A.PO _ => []) items)
    | A.PJux ps => List.concat (List.map patVars ps)
    | _ => []

  fun funName (A.F (_, x)) =
    case x of
      A.FPrefix (v, _) => v
    | A.FInfix (_, A.VarOp v, _) => v
    | A.FInfix (_, A.ConOp v, _) => v
    | A.FParen (l, _) => funName l

  fun constrParts (A.C (_, x)) =
    case x of
      A.CPlain (n, args) => (n, length args, [])
    | A.CInfix (_, n, _) => (n, 2, [])
    | A.CRec (n, fs) =>
        let val names = List.concat (List.map (fn A.Field (_, vs, _, _) => vs) fs)
        in (n, length names, names) end

  fun defs (home, A.Module (_, {decls, ...})) =
    let
      val out : def list ref = ref []
      val seen : unit M.map ref = ref M.empty
      fun add (space, n, sort, parent, arity) =
        let val e = {space = space, home = home, name = nameOf n}
        in
          if M.member (!seen, key e) then ()
          else (seen := M.insert (!seen, key e, ());
                out := {entity = e, sort = sort, parent = parent, arity = arity, span = spanOf n} :: !out);
          e
        end
      fun datatypeDecl (c, cons) =
        let val t = add (Type, c, TyCon, NONE, 0)
        in
          List.app
            (fn k =>
               let val (n, arity, fields) = constrParts k
               in
                 ignore (add (Value, n, Con, SOME t, arity));
                 List.app (fn f => ignore (add (Value, f, Field, SOME t, 0))) fields
               end)
            cons
        end
      fun one (A.D (_, x)) =
        case x of
          A.DType (c, _, _) => ignore (add (Type, c, Synonym, NONE, 0))
        | A.DData (_, c, _, cons, _) => datatypeDecl (c, cons)
        | A.DNewtype (_, c, _, k, _) => datatypeDecl (c, [k])
        | A.DClass (_, c, _, body) =>
            let val t = add (Type, c, Class, NONE, 0)
            in
              List.app (fn A.D (_, A.DSig (vs, _, _)) => List.app (fn v => ignore (add (Value, v, Method, SOME t, 0))) vs
                         | _ => ())
                (getOpt (body, []))
            end
        | A.DFun (f, _) => ignore (add (Value, funName f, Var, NONE, 0))
        | A.DPat (p, _) => List.app (fn v => ignore (add (Value, v, Var, NONE, 0))) (patVars p)
        | _ => ()
    in
      List.app one decls;
      List.rev (!out)
    end

  (* ---- scopes ---- *)

  type unit_ = {id : string, name : string, ast : A.module, imports : (A.import * string) list}
  type scope = entity list M.map

  fun scopeKey (space, qual, name) = spaceChar space ^ qual ^ "\t" ^ name

  fun lookup (s : scope, space, qual, name) = getOpt (M.find (s, scopeKey (space, qual, name)), [])

  fun addScope (s : scope, k, e : entity) : scope =
    case M.find (s, k) of
      NONE => M.insert (s, k, [e])
    | SOME es => if List.exists (fn x => key x = key e) es then s else M.insert (s, k, es @ [e])

  datatype fixpoint = Least | Greatest

  type solved = {exports : entity list M.map, scopes : scope M.map, errors : (HsSource.span * string) list}

  (* a set of entities, by key *)
  fun setOf (es : entity list) = List.foldl (fn (e, s) => M.insert (s, key e, e)) M.empty es
  fun itemsOf (s : entity M.map) = List.map #2 (M.listItems s)
  fun sameSet (a : entity M.map, b : entity M.map) = List.map #1 (M.listItems a) = List.map #1 (M.listItems b)

  fun solve {group : unit_ list, exportsOf, defOf : string -> def option, universe : entity list, fixpoint} : solved =
    let
      val errors : (HsSource.span * string) list ref = ref []
      val reporting = ref false
      fun report (span, msg) = if !reporting then errors := (span, msg) :: !errors else ()
      fun parentOf (e : entity) = case defOf (key e) of SOME {parent, ...} => parent | NONE => NONE
      fun isSubOf t (e : entity) = case parentOf e of SOME p => key p = key t | NONE => false
      val inGroup = List.foldl (fn (u : unit_, s) => M.insert (s, #id u, ())) M.empty group
      val localsOf : entity list M.map =
        List.foldl (fn (u : unit_, s) => M.insert (s, #id u, List.map #entity (defs (#id u, #ast u)))) M.empty group

      (* What an import's list selects of what the module exports. *)
      fun select (from, exported : entity list, items, hiding) =
        let
          fun named (space, n) = List.filter (fn (e : entity) => #space e = space andalso #name e = n) exported
          fun subsOf t = List.filter (isSubOf t) exported
          fun missing (sp, what) =
            report (sp, (if hiding then "a hiding list names " else "an import list names ") ^ what ^
                        ", which the module " ^ moduleName from ^ " does not export")
          fun one (A.Ent ({span, ...}, x)) =
            case x of
              A.EntVar n =>
                let val r = named (Value, nameOf n)
                in if null r then missing (span, "`" ^ nameOf n ^ "`") else (); r end
            | A.EntType (c, NONE) =>
                let val r = named (Type, nameOf c) @ (if hiding then named (Value, nameOf c) else [])
                in if null r then missing (span, "`" ^ nameOf c ^ "`") else (); r end
            | A.EntType (c, SOME A.SubAll) =>
                let val ts = named (Type, nameOf c)
                in if null ts then missing (span, "`" ^ nameOf c ^ "`") else (); ts @ List.concat (List.map subsOf ts) end
            | A.EntType (c, SOME (A.SubList ns)) =>
                let
                  val ts = named (Type, nameOf c)
                  val subs = List.concat (List.map subsOf ts)
                  fun pick n =
                    let val r = List.filter (fn (e : entity) => #name e = nameOf n) subs
                    in if null r andalso not (null ts) then missing (spanOf n, "`" ^ nameOf n ^ "` as one of `" ^ nameOf c ^ "`'s") else (); r end
                in
                  if null ts then missing (span, "`" ^ nameOf c ^ "`") else ();
                  ts @ List.concat (List.map pick ns)
                end
            | A.EntModule _ => []
        in
          setOf (List.concat (List.map one items))
        end

      fun scopeOf (u : unit_, exportsNow : string -> entity list) : scope =
        let
          val locals = getOpt (M.find (localsOf, #id u), [])
          val s0 =
            List.foldl
              (fn (e, s) => addScope (addScope (s, scopeKey (#space e, "", #name e), e),
                                      scopeKey (#space e, #name u, #name e), e))
              M.empty locals
          fun oneImport ((A.Import (_, {qualified, module = m, as_, hiding, spec}), target), s) =
            let
              val exported = exportsNow target
              val q = case as_ of SOME n => nameOf n | NONE => nameOf m
              val chosen =
                case spec of
                  NONE => exported
                | SOME items =>
                    let val picked = select (target, exported, items, hiding)
                    in List.filter (fn e => M.member (picked, key e) <> hiding) exported end
            in
              List.foldl
                (fn (e, s) =>
                   let val s = addScope (s, scopeKey (#space e, q, #name e), e)
                   in if qualified then s else addScope (s, scopeKey (#space e, "", #name e), e) end)
                s chosen
            end
        in
          List.foldl oneImport s0 (#imports u)
        end

      (* what a module exports, given its scope *)
      fun exportOf (u : unit_, sc : scope) : entity M.map =
        let
          val A.Module (_, {exports, ...}) = #ast u
          val inScope = M.foldl (fn (_, es, s) => List.foldl (fn (e, s) => M.insert (s, key e, e)) s es) M.empty sc
          fun subsInScope t = List.filter (isSubOf t) (itemsOf inScope)
          fun look (space, A.Name (_, {qual, name})) = lookup (sc, space, qual, name)
          fun one (A.Ent ({span, ...}, x)) =
            case x of
              A.EntVar n =>
                let val r = look (Value, n)
                in
                  if null r then report (span, "an export list names `" ^ A.nameText (let val A.Name (_, q) = n in q end) ^
                                               "`, which is not in scope")
                  else if length r > 1 then report (span, "an export list names `" ^ nameOf n ^ "`, which is ambiguous")
                  else ();
                  r
                end
            | A.EntType (c, sub) =>
                let
                  val ts = look (Type, c)
                  val () =
                    if null ts then report (span, "an export list names `" ^ A.nameText (let val A.Name (_, q) = c in q end) ^
                                                  "`, which is not in scope")
                    else if length ts > 1 then report (span, "an export list names `" ^ nameOf c ^ "`, which is ambiguous")
                    else ()
                  val subs =
                    case sub of
                      NONE => []
                    | SOME A.SubAll => List.concat (List.map subsInScope ts)
                    | SOME (A.SubList ns) =>
                        let
                          val all = List.concat (List.map subsInScope ts)
                          fun pick n =
                            let val r = List.filter (fn (e : entity) => #name e = nameOf n) all
                            in
                              if null r andalso not (null ts) then
                                report (spanOf n, "an export list names `" ^ nameOf n ^ "` as one of `" ^ nameOf c ^
                                                  "`'s, and no constructor, field or method `" ^ nameOf n ^ "` of `" ^
                                                  nameOf c ^ "` is in scope")
                              else ();
                              r
                            end
                        in
                          List.concat (List.map pick ns)
                        end
                in
                  ts @ subs
                end
            | A.EntModule m =>
                let
                  val q = nameOf m
                  val known =
                    q = #name u orelse
                    List.exists (fn (A.Import (_, {module = im, as_, ...}), _) =>
                                   (case as_ of SOME n => nameOf n | NONE => nameOf im) = q)
                      (#imports u)
                  val () =
                    if known then ()
                    else report (span, "an export list names the module `" ^ q ^ "`, which the module does not import")
                in
                  (* every entity in scope both unqualified and qualified by q *)
                  M.foldl
                    (fn (k, es, acc) =>
                       if String.isPrefix ("v" ^ q ^ "\t") k orelse String.isPrefix ("t" ^ q ^ "\t") k then
                         let
                           val {space, name, ...} = hd es
                           val un = lookup (sc, space, "", name)
                         in
                           List.filter (fn e => List.exists (fn x => key x = key e) un) es @ acc
                         end
                       else acc)
                    [] sc
                end
        in
          case exports of
            NONE => setOf (getOpt (M.find (localsOf, #id u), []))
          | SOME es => setOf (List.concat (List.map one es))
        end

      (* the exports so far of the group, and those of the rest *)
      fun nowFrom (state : entity M.map M.map) id =
        if M.member (inGroup, id) then itemsOf (getOpt (M.find (state, id), M.empty)) else exportsOf id

      val start : entity M.map M.map =
        case fixpoint of
          Least => List.foldl (fn (u : unit_, s) => M.insert (s, #id u, M.empty)) M.empty group
        | Greatest =>
            let val everything = setOf universe
            in List.foldl (fn (u : unit_, s) => M.insert (s, #id u, everything)) M.empty group end

      fun round state =
        List.foldl
          (fn (u : unit_, (acc, changed)) =>
             let
               val e = exportOf (u, scopeOf (u, nowFrom state))
               val previous = getOpt (M.find (state, #id u), M.empty)
             in
               (M.insert (acc, #id u, e), changed orelse not (sameSet (e, previous)))
             end)
          (state, false) group

      fun iterate state = let val (next, changed) = round state in if changed then iterate next else next end

      val final = iterate start

      (* the errors, from the solution *)
      val () = reporting := true
      val scopes =
        List.foldl (fn (u : unit_, acc) => M.insert (acc, #id u, scopeOf (u, nowFrom final))) M.empty group
      val exportsDone =
        List.foldl
          (fn (u : unit_, acc) =>
             let
               val ex = exportOf (u, getOpt (M.find (scopes, #id u), M.empty))
               val A.Module ({span, ...}, _) = #ast u
               (* 5.2: no two entities exported under one name *)
               val byName =
                 M.foldl (fn (_, e : entity, m) =>
                            let val k = scopeKey (#space e, "", #name e)
                            in M.insert (m, k, e :: getOpt (M.find (m, k), [])) end)
                   M.empty ex
               val clashes =
                 List.filter (fn es => length es > 1) (List.map #2 (M.listItems byName))
               val where_ = case #ast u of A.Module (_, {name = SOME (A.Name ({span = s, ...}, _)), ...}) => s | _ => span
               fun clash es =
                 Int.toString (length es) ^ " named `" ^ #name (hd es) ^ "` (of " ^
                 String.concatWith " and " (List.map (moduleName o #home) (List.rev es)) ^ ")"
               val () =
                 if null clashes then ()
                 else report (where_, "the module `" ^ #name u ^ "` exports " ^ String.concatWith " and " (List.map clash clashes) ^
                                      ", where the names a module exports name one entity each (5.2)")
             in
               M.insert (acc, #id u, itemsOf ex)
             end)
          M.empty group
    in
      {exports = exportsDone, scopes = scopes, errors = List.rev (!errors)}
    end
end
