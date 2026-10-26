(* The editor's types (the linting roadmap's M14, D7 A): a type at every
   node of the syntax, each declaration's worked out from the witnesses the
   elaborator recorded (M11) by AstLint's typer (M12) when a position in it
   is first asked about, and kept for the unit.

   What the typer reads of a unit is kept when its elaboration ends (capture,
   before UnitBasis.undo drops the tables): its declarations at top level
   with the environment each was elaborated in, and copies of the witnesses
   of its nodes' ids, of the binders of its stamps and of the module
   language's results AstLint takes as axioms. A declaration once typed has
   an index from positions to its innermost node (a sweep of its nodes'
   spans, in place of a scan): where an infix application and its tuple
   share a span, the application; where a variable pattern binds a value of
   its own, the binder, which shows the variables its own binding
   generalised marked ("'a. 'a -> 'a"), and a lambda's variable no mark,
   since what its type names an enclosing binding generalised. One printer
   for the unit names a type variable alike in every answer. *)
structure CompilerNodeTypes =
struct
  structure S = SourceTy
  type top = {dec : Ast.dec, env : Env.env, delta : Env.env}
  (* a declaration's index: the starts of its segments, and the node each
     is innermost in (~1, none) *)
  type index = {starts : int vector, nodes : int vector, all : AstLint.node vector}
  datatype t = Unit of {tops : top vector, reader : AstLint.reader, qualify : int * string -> string option,
                        typed : index option array, printer : S.printer}

  (* what the typer needs of a unit whose elaboration ended, before its
     tables are dropped: its ids (from lo up to hi) and stamps *)
  fun capture {tops : top list, ids = (idLo, idHi) : int * int, stamps = (stampLo, stampHi) : int * int, env : Env.env} : t =
    let
      fun copy (table : 'a Witness.entry IntTable.table) =
        let val c = IntTable.copyRange (table, idLo, idHi) in fn n => Option.map #value (IntTable.find (c, n)) end
      val binders = IntTable.copyRange (Ty.binders, stampLo, stampHi)
      val results = IntTable.copyRange (Elaborate.moduleResults, idLo, idHi)
      val params = IntTable.copyRange (Elaborate.functorParams, idLo, idHi)
      val reader : AstLint.reader =
        {instance = copy Witness.instances, nodeType = copy Witness.types, created = copy Witness.created,
         scoped = copy Witness.scoped, generalised = copy Witness.generalised,
         binder = fn s => IntTable.find (binders, s), moduleResult = fn n => IntTable.find (results, n),
         functorParam = fn n => IntTable.find (params, n)}
      val tops = Vector.fromList tops
      (* a type name's path from the unit's top level, once per name *)
      val qualified : string option IntTable.table = IntTable.table 64
      fun qualify (stamp, name) =
        case IntTable.find (qualified, stamp) of
          SOME q => q
        | NONE => let val q = Env.qualifiedName (env, {name = name, stamp = stamp, arity = 0, eq = false})
                  in IntTable.insert (qualified, stamp, q); q end
    in
      Unit {tops = tops, reader = reader, qualify = qualify, typed = Array.array (Vector.length tops, NONE),
            printer = S.printer qualify}
    end

  (* the preference among nodes of one span: the innermost the latest *)
  fun rank (n : AstLint.node) =
    case #kind n of
      "ETuple" => 0 | "PTuple" => 0 | "EApp" => 2 | "PApp" => 2 | "binder" => 3 | _ => 1
  fun precedes (a : AstLint.node, b : AstLint.node) =
    let val sa = #span a and sb = #span b
    in
      if #start sa <> #start sb then #start sa < #start sb
      else if #stop sa <> #stop sb then #stop sa > #stop sb
      else rank a < rank b
    end
  fun sort (xs : AstLint.node list) : AstLint.node list =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if precedes (y, x) then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
      fun split (xs, a, b) = case xs of [] => (a, b) | x :: rest => split (rest, b, x :: a)
      fun go [] = [] | go [x] = [x]
        | go xs = let val (a, b) = split (xs, [], []) in merge (go a, go b) end
    in go xs end

  (* the index of a declaration's nodes of one file: a sweep over them in
     order of start, the longest first, with a stack of the nodes open, a
     segment starting wherever the innermost changes *)
  fun index (file : string, nodes : AstLint.node list) : index =
    let
      val all = Vector.fromList (sort (List.filter (fn n : AstLint.node => #file (#span n) = file andalso
                                                                         #start (#span n) < #stop (#span n)) nodes))
      val segs : (int * int) list ref = ref []
      fun emit (at, n) =
        case !segs of
          (a, _) :: rest => if a = at then segs := (at, n) :: rest else segs := (at, n) :: !segs
        | [] => segs := [(at, n)]
      fun stopOf i = #stop (#span (Vector.sub (all, i)))
      fun close (stack, upTo) =
        case stack of
          i :: rest => if stopOf i <= upTo then (emit (stopOf i, case rest of j :: _ => j | [] => ~1); close (rest, upTo)) else stack
        | [] => []
      fun sweep (i, stack) =
        if i = Vector.length all then ignore (close (stack, valOf Int.maxInt))
        else
          let val start = #start (#span (Vector.sub (all, i)))
              val stack = close (stack, start)
          in emit (start, i); sweep (i + 1, i :: stack) end
      val () = sweep (0, [])
      val segs = List.rev (!segs)
    in {starts = Vector.fromList (List.map #1 segs), nodes = Vector.fromList (List.map #2 segs), all = all} end

  (* the node innermost at an offset: the last segment starting at or before it *)
  fun lookup ({starts, nodes, all} : index, offset : int) : AstLint.node option =
    let
      fun search (lo, hi) =
        if lo >= hi then lo - 1
        else let val mid = lo + (hi - lo) div 2
             in if Vector.sub (starts, mid) <= offset then search (mid + 1, hi) else search (lo, mid) end
      val k = search (0, Vector.length starts)
    in
      if k < 0 then NONE
      else case Vector.sub (nodes, k) of ~1 => NONE | i => SOME (Vector.sub (all, i))
    end

  (* a node's type as the printer shows it, a binder's own generalised
     variables marked *)
  fun show (printer : S.printer, n : AstLint.node) : string =
    let
      val text = S.toStringWith printer (#ty n)
      fun vars t =
        case S.node t of
          S.Var {tv, eq, ...} => [(tv, eq)]
        | S.Con {args, ...} => List.concat (List.map vars args)
        | S.Record fs => List.concat (List.map (vars o #2) fs)
        | S.Arrow (a, b) => vars a @ vars b
        | S.Flex {tv, eq, fields, ...} => (tv, eq) :: List.concat (List.map (vars o #2) fields)
      val occurring = vars (#ty n)
      val own = List.mapPartial (fn tv => Option.map (fn (_, eq) => S.toStringWith printer (S.var (tv, eq, NONE, [], true)))
                                                    (List.find (fn (v, _) => v = tv) occurring)) (#own n)
    in case own of [] => text | _ => String.concatWith " " own ^ ". " ^ text end

  (* the declaration at top level whose span holds an offset of a file *)
  fun topAt (tops : top vector, file : string, offset : int) : int option =
    let
      fun holds i = let val sp = Ast.spanOfDec (#dec (Vector.sub (tops, i)))
                    in #file sp = file andalso #start sp <= offset andalso offset < #stop sp end
      fun find i = if i = Vector.length tops then NONE else if holds i then SOME i else find (i + 1)
    in find 0 end

  (* the type at an offset of a file the unit holds: its declaration typed
     first if it was not yet, then its index's innermost node; NONE where no
     node is there (a keyword, a declaration of the module language) *)
  fun typeAt (Unit {tops, reader, typed, printer, ...}, file : string, offset : int) : string option =
    case topAt (tops, file, offset) of
      NONE => NONE
    | SOME i =>
        let
          val idx = case Array.sub (typed, i) of
                      SOME idx => idx
                    | NONE =>
                        let
                          val nodes = ref []
                          val () = AstLint.typeDecl (reader, fn n => nodes := n :: !nodes, Vector.sub (tops, i))
                                   handle S.Budget => ()
                          val idx = index (file, !nodes)
                        in Array.update (typed, i, SOME idx); idx end
        in Option.map (fn n => show (printer, n)) (lookup (idx, offset)) end

  (* the batch query's (CompilerQuery): the declarations just elaborated,
     the tables as they are, a fresh printer *)
  fun typeAtNow (tops : top list, env : Env.env, file : string, offset : int) : string option =
    let
      val qualify = fn (stamp, name) => Env.qualifiedName (env, {name = name, stamp = stamp, arity = 0, eq = false})
      val tops = Vector.fromList tops
    in
      typeAt (Unit {tops = tops, reader = AstLint.global, qualify = qualify, typed = Array.array (Vector.length tops, NONE),
                    printer = S.printer qualify}, file, offset)
    end
end
