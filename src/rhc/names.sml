(* The names of a program (the haskell98 roadmap's M12): each group of
   RhcGraph's, dependencies first, solved for its exports and scopes by
   HsModules at the fixpoint asked for (D29: `--names=least`, the default,
   or `--names=greatest`), each of its modules renamed by HsRename, and
   then resolved by HsFixity, with the fixities of every entity of the
   program, which their modules declare, read after names and with no
   iteration. Instances are not names: every one a module declares is
   visible to the whole program, and `--dump-names` lists them.

   `rhc --dump-names FILE...` prints what this finds, sorted, a line each:

     EXPORT    module, entity              what a module exports
     FIX       entity, associativity, precedence
     INSTANCE  module, class, type, written or derived
     ERROR     module:line:column, message

   where an entity is its space (`v` a value, `t` a type or class), the
   identity of its module and its name, and a built-in type has no module:
   `t ()`. The library's own errors, which a compile does not show (the 8
   names that do not resolve as printed, until M17's overlay), are among
   the ERROR lines. *)
structure RhcNames =
struct
  structure A = HsAst
  structure M = HsStringMap
  structure Mo = HsModules
  structure G = RhcGraph

  type result = {modules : (G.node * A.module) list, exports : Mo.entity list M.map, diags : G.diag list,
                 types : HsInfer.env option, evidence : HsEvidence.table,
                 derived : (string * string * A.decl list) list}

  fun spaceText Mo.Value = "v"
    | spaceText Mo.Type = "t"

  fun entityText ({space, home, name} : Mo.entity) = spaceText space ^ home ^ " " ^ name

  (* What the groups of a graph leave for the groups after them: the
     tables of every module's entities and fixities, whether a file is the
     library's, and what names and the checker have found so far. The
     saved world (RhcWorld) is the state the library's groups leave. *)
  type state = {defs : Mo.def M.map, universe : Mo.entity list, fixities : (A.fixity * int) M.map,
                library : bool M.map, exports : Mo.entity list M.map, scopes : Mo.scope M.map, diags : G.diag list,
                modules : (G.node * A.module) list, derived : (string * string * A.decl list) list,
                evidence : HsEvidence.table, types : HsInfer.env}

  (* the entities of rhc's modules of primitives `leaves` *)
  fun leafEntities leaves =
    List.concat
      (List.map (fn (l, names) => List.map (fn n => {space = Mo.Value, home = RhcLibrary.identity l, name = n}) names)
         leaves)

  (* rhc's modules of primitives that a module of `nodes` imports *)
  fun leavesOf (nodes : G.node list) =
    List.filter (fn (l, _) => List.exists (fn (n : G.node) => List.exists (fn (_, t) => t = RhcLibrary.identity l) (#imports n))
                                nodes)
      RhcLibrary.leaves

  (* `extend (s, nodes)` is `s` with the entities and fixities of `nodes`,
     which follow its groups *)
  fun extend (s : state, nodes : G.node list) : state =
    let
      val defs = List.concat (List.map (fn (n : G.node) => Mo.defs (#id n, #ast n)) nodes)
    in
      {defs = List.foldl (fn (d : Mo.def, t) => M.insert (t, Mo.key (#entity d), d)) (#defs s) defs,
       universe = #universe s @ List.map #entity defs,
       fixities = List.foldl (fn ((k, f), t) => M.insert (t, k, f)) (#fixities s)
                    (List.concat (List.map (fn (n : G.node) => HsRename.topFixities (#id n, #ast n)) nodes)),
       library = List.foldl (fn (n : G.node, t) => M.insert (t, #file n, #library n)) (#library s) nodes,
       exports = #exports s, scopes = #scopes s, diags = #diags s, modules = #modules s, derived = #derived s,
       evidence = #evidence s, types = #types s}
    end

  (* `install (s, ifaces)` is `s` with modules present by their interfaces
     (HsModIface, M21) and not their source: their exports, definitions and
     fixities, and their parts of the checker's environment, so that a unit
     is named and checked against them *)
  fun install (s : state, ifaces : HsModIface.t list) : state =
    List.foldl
      (fn ({id, exports, defs, fixities, checked} : HsModIface.t, s : state) =>
         {defs = List.foldl (fn (d : Mo.def, t) => M.insert (t, Mo.key (#entity d), d)) (#defs s) defs,
          universe = #universe s @ List.map #entity defs,
          fixities = List.foldl (fn ((k, f), t) => M.insert (t, k, f)) (#fixities s) fixities,
          library = #library s, exports = M.insert (#exports s, id, exports), scopes = #scopes s, diags = #diags s,
          modules = #modules s, derived = #derived s, evidence = #evidence s, types = HsInfer.extend (#types s, checked)})
      s ifaces

  (* the state before any group: rhc's modules of primitives `leaves`,
     which no file holds, and nothing found *)
  fun initial leaves : state =
    let
      val leafDefs = List.map (fn e => {entity = e, sort = Mo.Var, parent = NONE, arity = 0, span = HsSource.noSpan})
                       (leafEntities leaves)
    in
      {defs = List.foldl (fn (d : Mo.def, t) => M.insert (t, Mo.key (#entity d), d)) M.empty leafDefs,
       universe = List.map #entity leafDefs, fixities = M.empty, library = M.empty,
       exports = List.foldl (fn ((l, names), m) =>
                               M.insert (m, RhcLibrary.identity l,
                                         List.map (fn n => {space = Mo.Value, home = RhcLibrary.identity l, name = n}) names))
                   M.empty leaves,
       scopes = M.empty, diags = [], modules = [], derived = [], evidence = HsEvidence.empty (),
       types = HsInfer.initial {primitives = List.map Mo.key (leafEntities leaves)}}
    end

  (* The first number a program's fresh type variables and kinds take, past
     any the library's checking takes, so that they are numbered alike
     whether the library was checked now or restored (RhcWorld), or its
     groups by interface (RhcIface); the program's units go on from it, so
     that no two dictionaries of a program have one name *)
  val unitCounters = 100000000

  (* The first number a unit of the library's fresh variables take: a range
     of its own, a million wide, by the place of its first module among the
     library's files, so that each of its units is numbered alike whether
     the saved world checks them all or a whole program the ones it
     reaches; and the names of dictionaries apart *)
  val libraryOrder : string list option ref = ref NONE
  fun librarySlot (members : G.node list) =
    let
      val order =
        case !libraryOrder of
          SOME o_ => o_
        | NONE => let val o_ = List.map #1 (G.libraryFiles ()) in libraryOrder := SOME o_; o_ end
      fun index (name, i, []) = i
        | index (name, i, x :: xs) = if x = name then i else index (name, i + 1, xs)
      val least = List.foldl (fn (n : G.node, m) => Int.min (index (#name n, 0, order), m)) (length order) members
    in
      1000000 * (1 + least)
    end

  (* `groups (s, gs, fixpoint, check)`: each group of `gs` solved for its
     exports and scopes, its modules renamed and resolved, and with
     `check`, each group checked too, its types, classes and instances
     (HsInfer, M13), under the setting of --cycle-default *)
  fun groups (s : state, gs : G.node list list, fixpoint : Mo.fixpoint, check : HsInfer.cycleDefault option) : state =
    let
      val defTable = #defs s
      fun defOf k = M.find (defTable, k)
      val universe = #universe s
      val fixTable = #fixities s
      fun isLibrary (span : HsSource.span) = getOpt (M.find (#library s, #file span), false)
      val exports = ref (#exports s)
      val scopes = ref (#scopes s)
      fun exportsOf id = getOpt (M.find (!exports, id), [])
      val diags = ref (#diags s)
      fun add errs = diags := !diags @ List.map (fn (sp, msg) => {span = sp, msg = msg, library = isLibrary sp}) errs
      val out = ref (#modules s)
      val derivedOut = ref (#derived s)
      val evidence = #evidence s
      val types = ref (#types s)
      (* the entity the Prelude exports under a name; Ix's Ix too *)
      fun prelude (space, name) =
        let
          val from =
            if List.exists (fn n => n = name) ["Ix", "range", "index", "inRange", "rangeSize"] then RhcLibrary.identity "Ix"
            else RhcLibrary.identity "Prelude"
          val sp = if space = "t" then Mo.Type else Mo.Value
        in
          HsUsage.read (HsUsage.Standard {space = space, name = name});
          Option.map Mo.key (List.find (fn (e : Mo.entity) => #space e = sp andalso #name e = name) (exportsOf from))
        end
      fun group members =
        let
          val units = List.map (fn (n : G.node) => {id = #id n, name = #name n, ast = #ast n, imports = #imports n}) members
          val solved = Mo.solve {group = units, exportsOf = exportsOf, defOf = defOf, universe = universe,
                                 fixpoint = fixpoint}
          val () = exports := M.foldl (fn (id, es, m) => M.insert (m, id, es)) (!exports) (#exports solved)
          val () = scopes := M.foldl (fn (id, sc, m) => M.insert (m, id, sc)) (!scopes) (#scopes solved)
          val () = add (#errors solved)
          fun one (n : G.node) =
            let
              val scope = getOpt (M.find (#scopes solved, #id n), M.empty)
              val r = HsRename.rename {id = #id n, scope = scope, defOf = defOf} (#ast n)
              val () = add (#errors r)
              fun fixityOf ({qual, name} : A.qname) =
                if qual = "" then
                  if name = ":" then SOME (A.Infixr, 5) else M.find (#localFixities r, name)
                else M.find (fixTable, Mo.key {space = Mo.Value, home = qual, name = name})
              val (m, errs) = HsFixity.resolve {fixityOf = fixityOf} (#module r)
            in
              add errs;
              out := (n, m) :: !out
            end
          val () = List.app one members
          (* a program whose names or fixity fail is not checked further *)
          val failed = List.exists (fn d => not (#library d)) (!diags)
        in
          case (check, failed) of
            (NONE, _) => ()
          | (_, true) => ()
          | (SOME cycleDefault, false) =>
              let
                val () = if List.all #library members then HsInfer.numberFrom (librarySlot members)
                         else HsInfer.renumber unitCounters
                val resolved = List.filter (fn (n, _) => List.exists (fn (m : G.node) => #id m = #id n) members) (!out)
                (* 5.4: an instance in scope where imports reach it *)
                val () = HsInfer.setReaches RhcGraph.reaches
                val {env, errors, derived} =
                  HsInfer.check {env = !types, cycleDefault = cycleDefault, prelude = prelude, evidence = evidence,
                                 fixity = fn k => M.find (fixTable, k),
                                 unit = List.map (fn (n : G.node, m) => {id = #id n, ast = m, library = #library n}) resolved}
              in
                types := env;
                derivedOut := !derivedOut @ derived;
                add errors
              end
        end
    in
      List.app group gs;
      {defs = defTable, universe = universe, fixities = fixTable, library = #library s, exports = !exports,
       scopes = !scopes, diags = !diags, modules = !out, derived = !derivedOut, evidence = evidence, types = !types}
    end

  (* the result of a state, for a check (`checked`) or not *)
  fun result (s : state, checked : bool) : result =
    {modules = List.rev (#modules s), exports = #exports s, diags = #diags s,
     types = if checked then SOME (#types s) else NONE, evidence = #evidence s, derived = #derived s}

  (* `run (g, fixpoint, check)`: with `check`, each group is checked too,
     its types, classes and instances (HsInfer, M13), under the setting
     of --cycle-default *)
  fun run (g : G.graph, fixpoint : Mo.fixpoint, check : HsInfer.cycleDefault option) : result =
    let val nodes = List.concat (#groups g)
    in result (groups (extend (initial (leavesOf nodes), nodes), #groups g, fixpoint, check), isSome check) end

  (* ---- --dump-names ---- *)

  fun fixText (f, p) =
    (case f of A.Infix => "infix" | A.Infixl => "infixl" | A.Infixr => "infixr") ^ "\t" ^ Int.toString p

  (* the type constructor at the head of an instance's type *)
  fun headOf (A.T (_, x)) =
    case x of
      A.TCon (A.Name (_, q)) => SOME q
    | A.TApp (f, _) => headOf f
    | A.TParen t => headOf t
    | A.TList _ => SOME {qual = "", name = "[]"}
    | A.TTuple ts => SOME {qual = "", name = "(" ^ CharVector.tabulate (length ts - 1, fn _ => #",") ^ ")"}
    | A.TFun _ => SOME {qual = "", name = "(->)"}
    | A.TVar _ => NONE

  fun typeText ({qual, name} : A.qname) = "t" ^ qual ^ " " ^ name

  fun instances (n : G.node, A.Module (_, {decls, ...})) =
    let
      fun line (cls : A.qname, ty, how) = "INSTANCE\t" ^ #id n ^ "\t" ^ typeText cls ^ "\t" ^ ty ^ "\t" ^ how
      fun one (A.D (_, x)) =
        case x of
          A.DInstance (_, A.Name (_, cls), t, _) =>
            [line (cls, case headOf t of SOME q => typeText q | NONE => "?", "written")]
        | A.DData (_, A.Name (_, tq), _, _, SOME (A.Deriv (_, _, cs))) =>
            List.map (fn A.Name (_, c) => line (c, typeText tq, "derived")) cs
        | A.DNewtype (_, A.Name (_, tq), _, _, SOME (A.Deriv (_, _, cs))) =>
            List.map (fn A.Name (_, c) => line (c, typeText tq, "derived")) cs
        | _ => []
    in
      List.concat (List.map one decls)
    end

  (* strings in order, by merging *)
  fun sort [] = []
    | sort [x] = [x]
    | sort xs =
        let
          val half = length xs div 2
          fun merge ([], ys) = ys
            | merge (xs, []) = xs
            | merge (x :: xs, y :: ys) = if String.<= (x, y) then x :: merge (xs, y :: ys) else y :: merge (x :: xs, ys)
        in
          merge (sort (List.take (xs, half)), sort (List.drop (xs, half)))
        end

  fun where_ (span : HsSource.span) =
    case G.textOf (#file span) of
      SOME t =>
        let val {line, column} = HsSource.position (t, #start span)
        in Int.toString line ^ ":" ^ Int.toString column end
    | NONE => "0:0"

  fun dump (g : G.graph, r : result) =
    let
      val nodes = List.concat (#groups g)
      val idOfFile = List.foldl (fn (n : G.node, s) => M.insert (s, #file n, #id n)) M.empty nodes
      val exportLines =
        List.concat (List.map (fn (id, es) => List.map (fn e => "EXPORT\t" ^ id ^ "\t" ^ entityText e) es)
                       (M.listItems (#exports r)))
      val fixLines =
        List.concat
          (List.map (fn (n : G.node) =>
                       let
                         val A.Module (_, {decls, ...}) = #ast n
                         fun prec p = case p of SOME (A.Lit (_, A.LInt (v, _))) => IntInf.toInt v | _ => 9
                         fun ops (f, p, qs) =
                           List.map (fn A.VarOp (A.Name (_, {name, ...})) => "FIX\tv" ^ #id n ^ " " ^ name ^ "\t" ^ fixText (f, prec p)
                                      | A.ConOp (A.Name (_, {name, ...})) => "FIX\tv" ^ #id n ^ " " ^ name ^ "\t" ^ fixText (f, prec p))
                             qs
                         fun one (A.D (_, x)) =
                           case x of
                             A.DFixity (f, p, qs) => ops (f, p, qs)
                           | A.DClass (_, _, _, SOME body) =>
                               List.concat (List.map (fn A.D (_, A.DFixity (f, p, qs)) => ops (f, p, qs) | _ => []) body)
                           | _ => []
                       in
                         List.concat (List.map one decls)
                       end)
             nodes)
      val instanceLines = List.concat (List.map instances (#modules r))
      val errorLines =
        List.map (fn {span, msg, ...} : G.diag =>
                    "ERROR\t" ^ getOpt (M.find (idOfFile, #file span), #file span) ^ ":" ^ where_ span ^ "\t" ^ msg)
          (#diags g @ #diags r)
      val sorted = sort (exportLines @ fixLines @ instanceLines @ errorLines)
    in
      List.app (fn l => print (l ^ "\n")) sorted
    end

  (* ---- --dump-types ---- *)

  (* the type of each top-level value of the program's modules, a line each, sorted *)
  fun dumpTypes (g : G.graph, r : result) =
    case #types r of
      NONE => ()
    | SOME env =>
        let
          val lines =
            List.concat
              (List.map (fn (n : G.node, _) =>
                           if #library n then []
                           else
                             List.mapPartial
                               (fn {entity, sort, ...} : Mo.def =>
                                  case (sort, HsInfer.valueScheme (env, Mo.key entity)) of
                                    (Mo.Var, SOME s) => SOME ("TYPE\t" ^ #id n ^ "\t" ^ #name entity ^ "\t" ^ HsTypes.showScheme s)
                                  | _ => NONE)
                               (Mo.defs (#id n, #ast n)))
                 (#modules r))
          val idOfFile = List.foldl (fn (n : G.node, s) => M.insert (s, #file n, #id n)) M.empty (List.concat (#groups g))
          val programIds = List.mapPartial (fn (n : G.node, _) => if #library n then NONE else SOME (#id n)) (#modules r)
          val insts =
            List.mapPartial
              (fn {cls = c, tycon, home, ctx, vars, derived, ...} : HsClasses.instance =>
                 if not (List.exists (fn m => m = home) programIds) then NONE
                 else
                   let
                     val names = List.tabulate (vars, fn k => HsTypes.TCon (str (Char.chr (97 + k))))
                     val shown = List.map (fn {cls, ty} => HsTypes.showPred {cls = cls, ty = HsTypes.substGen (names, ty)}) ctx
                     val head = HsTypes.showPred {cls = c, ty = HsTypes.apply (HsTypes.TCon tycon, names)}
                   in
                     SOME ("INSTANCE\t" ^ home ^ "\t" ^
                           (case shown of [] => "" | [c] => c ^ " => " | cs => "(" ^ String.concatWith ", " cs ^ ") => ") ^
                           head ^ "\t" ^ (if derived then "derived" else "written"))
                   end)
              (HsClasses.instances (HsInfer.classes env))
          val errs =
            List.map (fn {span, msg, ...} : G.diag =>
                        "LIBRARY-ERROR\t" ^ getOpt (M.find (idOfFile, #file span), #file span) ^ ":" ^ where_ span ^ "\t" ^ msg)
              (List.filter (fn d => #library d) (#diags r))
        in
          List.app (fn l => print (l ^ "\n")) (sort lines @ sort insts @ sort errs)
        end

  (* ---- --dump-evidence ---- *)

  (* every evidence record of the program's modules, its node first, a
     line each, in the order of the nodes' keys; the library's left out *)
  fun dumpEvidence (g : G.graph, r : result) =
    let
      val libraryFiles = List.mapPartial (fn (n : G.node) => if #library n then SOME (#file n) else NONE) (List.concat (#groups g))
      fun ofLibrary key = List.exists (fn f => String.isSubstring ("@" ^ f ^ ":") key) libraryFiles
    in
      List.app (fn (k, rs) => if ofLibrary k then ()
                              else List.app (fn rec_ => print (k ^ "\t" ^ HsEvidence.showRecord rec_ ^ "\n")) rs)
        (HsEvidence.all (#evidence r))
    end

  (* ---- --dump-derived ---- *)

  (* the derived instances of the program's modules, as HsDerive made
     them, each printed as an instance declaration *)
  fun dumpDerived (g : G.graph, r : result) =
    let val programIds = List.mapPartial (fn (n : G.node, _) => if #library n then NONE else SOME (#id n)) (#modules r)
    in
      List.app (fn (h, id, ds) =>
                  if List.exists (fn m => m = h) programIds then
                    (print ("-- " ^ h ^ ": instance " ^ HsClasses.showInstance id ^ "\n");
                     List.app (fn d => print (HsPrint.decl d ^ "\n")) ds)
                  else ())
        (#derived r)
    end

  (* ---- --dump-binders ---- *)

  (* every occurrence of a local name of the program's own modules, which
     HsRename makes x#k: a pattern's a binding site (BIND), an expression's
     or an operator's a use (USE), with its renamed name and its file and
     bytes start-end, in order. D55's renaming relation edits a program by
     these (tests/runner/hsmeta.sml) *)
  fun dumpBinders (g : G.graph, r : result) =
    List.app
      (fn ((n : G.node), m) =>
         if #library n then ()
         else
           List.app
             (fn l =>
                case String.tokens Char.isSpace l of
                  kind :: name :: at :: _ =>
                    if String.isSubstring "#" name andalso String.isPrefix "@" at then
                      print ((if String.isPrefix "E" kind orelse String.isSuffix "Op" kind then "USE" else "BIND") ^ "\t" ^ name
                             ^ "\t" ^ #file n ^ ":" ^ String.extract (at, 1, NONE) ^ "\n")
                    else ()
                | _ => ())
             (String.fields (fn c => c = #"\n") (HsDump.module {spans = true} m)))
      (#modules r)
end
