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
                 types : HsInfer.env option, evidence : HsEvidence.table}

  fun spaceText Mo.Value = "v"
    | spaceText Mo.Type = "t"

  fun entityText ({space, home, name} : Mo.entity) = spaceText space ^ home ^ " " ^ name

  (* `run (g, fixpoint, check)`: with `check`, each group is checked too,
     its types, classes and instances (HsInfer, M13), under the setting
     of --cycle-default *)
  fun run (g : G.graph, fixpoint : Mo.fixpoint, check : HsInfer.cycleDefault option) : result =
    let
      val nodes = List.concat (#groups g)
      val libraryFiles = List.foldl (fn (n : G.node, s) => M.insert (s, #file n, #library n)) M.empty nodes
      fun isLibrary (span : HsSource.span) = getOpt (M.find (libraryFiles, #file span), false)
      (* rhc's modules of primitives, where a module imports them *)
      val leaves =
        List.filter (fn (l, _) => List.exists (fn (n : G.node) => List.exists (fn (_, t) => t = RhcLibrary.identity l) (#imports n))
                                    nodes)
          RhcLibrary.leaves
      val leafDefs =
        List.concat
          (List.map
             (fn (l, names) =>
                List.map (fn n => {entity = {space = Mo.Value, home = RhcLibrary.identity l, name = n}, sort = Mo.Var,
                                   parent = NONE, arity = 0, span = HsSource.noSpan}) names)
             leaves)
      val defs = leafDefs @ List.concat (List.map (fn (n : G.node) => Mo.defs (#id n, #ast n)) nodes)
      val defTable = List.foldl (fn (d : Mo.def, t) => M.insert (t, Mo.key (#entity d), d)) M.empty defs
      fun defOf k = M.find (defTable, k)
      val universe = List.map #entity defs
      val fixTable =
        List.foldl (fn ((k, f), t) => M.insert (t, k, f)) M.empty
          (List.concat (List.map (fn (n : G.node) => HsRename.topFixities (#id n, #ast n)) nodes))
      val exports : Mo.entity list M.map ref =
        ref (List.foldl (fn ((l, names), m) =>
                           M.insert (m, RhcLibrary.identity l,
                                     List.map (fn n => {space = Mo.Value, home = RhcLibrary.identity l, name = n}) names))
               M.empty leaves)
      fun exportsOf id = getOpt (M.find (!exports, id), [])
      val diags : G.diag list ref = ref []
      fun add errs = diags := !diags @ List.map (fn (sp, msg) => {span = sp, msg = msg, library = isLibrary sp}) errs
      val out : (G.node * A.module) list ref = ref []
      val evidence = HsEvidence.empty ()
      val types =
        ref (HsInfer.initial {primitives = List.concat (List.map (fn (l, names) =>
                                                                     List.map (fn n => Mo.key {space = Mo.Value, home = RhcLibrary.identity l,
                                                                                               name = n}) names) leaves)})
      (* the entity the Prelude exports under a name; Ix's Ix too *)
      fun prelude (space, name) =
        let
          val from = if name = "Ix" then RhcLibrary.identity "Ix" else RhcLibrary.identity "Prelude"
          val sp = if space = "t" then Mo.Type else Mo.Value
        in
          Option.map Mo.key (List.find (fn (e : Mo.entity) => #space e = sp andalso #name e = name) (exportsOf from))
        end
      fun group members =
        let
          val units = List.map (fn (n : G.node) => {id = #id n, name = #name n, ast = #ast n, imports = #imports n}) members
          val solved = Mo.solve {group = units, exportsOf = exportsOf, defOf = defOf, universe = universe,
                                 fixpoint = fixpoint}
          val () = exports := M.foldl (fn (id, es, m) => M.insert (m, id, es)) (!exports) (#exports solved)
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
                val resolved = List.filter (fn (n, _) => List.exists (fn (m : G.node) => #id m = #id n) members) (!out)
                val {env, errors} =
                  HsInfer.check {env = !types, cycleDefault = cycleDefault, prelude = prelude, evidence = evidence,
                                 unit = List.map (fn (n : G.node, m) => {id = #id n, ast = m, library = #library n}) resolved}
              in
                types := env;
                add errors
              end
        end
    in
      List.app group (#groups g);
      {modules = List.rev (!out), exports = !exports, diags = !diags,
       types = Option.map (fn _ => !types) check, evidence = evidence}
    end

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
          val errs =
            List.map (fn {span, msg, ...} : G.diag =>
                        "LIBRARY-ERROR\t" ^ getOpt (M.find (idOfFile, #file span), #file span) ^ ":" ^ where_ span ^ "\t" ^ msg)
              (List.filter (fn d => #library d) (#diags r))
        in
          List.app (fn l => print (l ^ "\n")) (sort lines @ sort errs)
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
