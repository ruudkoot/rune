(* SourceTy: the type language of the syntax (docs/plans/correctness/
   linting.md, D2). It is immutable and hash-consed, so that two types are
   equal exactly where their ids are; its type variables keep their
   equality, the name an explicit one has in the source and the classes of
   an overloaded one, its records their labels, and its type names their
   stamps, whose equality is answered from the table by stamp (admitsEq),
   not from an occurrence: an occurrence of a datatype in the declaration
   that makes it still has the equality it was assumed to have (E6).

   A SourceTy is made from the elaborator's Types.ty by zonk, after
   Elaborate.finish, the one point where no type can change any more in
   any --flex-records mode (E5): settled says so, and a zonk before it is
   the compiler's error. Zonks are done in batches (a declaration's
   witnesses together): in a batch each cell of Types.ty is zonked once,
   and the batch has a budget of steps, as the translation's has, past
   which zonk raises Budget. Nothing zonks unless something reads the
   types (AstLint, the editor, the messages), so that a compile pays for
   SourceTy only where it is used. *)
structure SourceTy =
struct
  datatype ty = T of {id : int, node : node}
  and node =
      (* a type variable: its number (Types' id), whether it ranges over
         equality types, the name an explicit one has in the source, and
         the classes of an overloaded one *)
      Var of {tv : int, eq : bool, name : string option, classes : string list}
      (* a type name, by stamp, applied *)
    | Con of {stamp : int, name : string, args : ty list}
      (* a record, its labels in the order Types sorts them *)
    | Record of (string * ty) list
    | Arrow of ty * ty
      (* a flexible record still open: a generalised one, in a scheme *)
    | Flex of {tv : int, eq : bool, fields : (string * ty) list}

  fun id (T {id, ...}) = id
  fun node (T {node, ...}) = node
  fun same (a : ty, b : ty) = id a = id b

  (* --- hash-consing: one node for each type, by its parts' ids --- *)
  datatype key =
      KVar of int * bool * string option * string list
    | KCon of int * int list
    | KRecord of (string * int) list
    | KArrow of int * int
    | KFlex of int * bool * (string * int) list

  val prime = 1073741789
  fun mix (h, x) = (h * 1009 + x mod prime) mod prime
  fun mixString (h, s) = CharVector.foldl (fn (c, h) => mix (h, Char.ord c)) h s
  fun hash k =
    case k of
      KVar (tv, eq, _, _) => mix (mix (1, tv), if eq then 1 else 0)
    | KCon (s, xs) => List.foldl (fn (x, h) => mix (h, x)) (mix (2, s)) xs
    | KRecord fs => List.foldl (fn ((l, x), h) => mix (mixString (h, l), x)) 3 fs
    | KArrow (a, b) => mix (mix (4, a), b)
    | KFlex (tv, _, fs) => List.foldl (fn ((l, x), h) => mix (mixString (h, l), x)) (mix (5, tv)) fs

  fun keyOf (n : node) : key =
    case n of
      Var {tv, eq, name, classes} => KVar (tv, eq, name, classes)
    | Con {stamp, args, ...} => KCon (stamp, List.map id args)
    | Record fs => KRecord (List.map (fn (l, t) => (l, id t)) fs)
    | Arrow (a, b) => KArrow (id a, id b)
    | Flex {tv, eq, fields} => KFlex (tv, eq, List.map (fn (l, t) => (l, id t)) fields)

  (* the nodes made, by the hash of their keys; the number of the next *)
  val pool : (key * ty) list IntTable.table = IntTable.table 16
  val () = CompilerState.tableRoot ("SourceTy.pool", pool)
  val made = ref 0
  val () = CompilerState.cellRoot ("SourceTy.made", made)

  fun mk (n : node) : ty =
    let
      val k = keyOf n
      val h = hash k
      val bucket = getOpt (IntTable.find (pool, h), [])
    in
      case List.find (fn (k', _) => k' = k) bucket of
        SOME (_, t) => t
      | NONE =>
          let val t = T {id = !made, node = n}
          in made := !made + 1; IntTable.insert (pool, h, (k, t) :: bucket); t end
    end

  fun var (tv, eq, name, classes) = mk (Var {tv = tv, eq = eq, name = name, classes = classes})
  fun con (stamp, name, args) = mk (Con {stamp = stamp, name = name, args = args})
  fun record fs = mk (Record fs)
  fun arrow (a, b) = mk (Arrow (a, b))

  (* --- the equality of type names, by stamp --- *)
  (* whether each type name admits equality: what the declaration that
     made it worked out (Witness.created, Elaborate), else what its first
     occurrence a zonk meets says, for a name of the initial basis or of a
     unit before *)
  val equality : bool IntTable.table = IntTable.table 16
  val () = CompilerState.tableRoot ("SourceTy.equality", equality)
  fun setEquality (stamp, eq) = IntTable.insert (equality, stamp, eq)
  fun admitsEq (stamp : int) : bool option = IntTable.find (equality, stamp)

  (* --- zonking --- *)
  (* whether the elaborator's types may be read: set by Elaborate.finish,
     cleared where elaboration starts again (Elaborate.elabTop) *)
  val settled = ref false
  val () = CompilerState.cellRoot ("SourceTy.settled", settled)

  exception Budget
  (* the steps a batch may take, and those the one going on has taken *)
  val budget = ref 10000000
  val () = CompilerState.cellRoot ("SourceTy.budget", budget)
  val steps = ref 0
  val () = CompilerState.cellRoot ("SourceTy.steps", steps)
  fun step () = (steps := !steps + 1; if !steps > !budget then raise Budget else ())

  (* A bound cell is zonked once a batch: the first visit puts in it a
     marker, a type name of a stamp below markerBase whose distance from it
     numbers the result, and every cell is put back when the batch ends,
     whatever happens, so that the elaborator's types are as they were *)
  val markerBase = ~2000000000
  val results : ty option array ref = ref (Array.array (16, NONE))
  val () = CompilerState.refRoot ("SourceTy.results", results, CompilerState.copyArray)
  val nresults = ref 0
  val () = CompilerState.cellRoot ("SourceTy.nresults", nresults)
  val undo : (Types.tvar ref * Types.tvar) list ref = ref []
  val () = CompilerState.cellRoot ("SourceTy.undo", undo)

  fun restore () =
    (List.app (fn (r, v) => r := v) (!undo); undo := []; nresults := 0; steps := 0)

  fun remember (r : Types.tvar ref, z : ty) : unit =
    let
      val k = !nresults
      val () = if k < Array.length (!results) then ()
               else let val a = Array.array (2 * k, NONE)
                    in Array.copy {src = !results, dst = a, di = 0}; results := a end
    in
      Array.update (!results, k, SOME z); nresults := k + 1;
      undo := (r, !r) :: !undo;
      r := Types.Bound (Types.TCon ({name = "", stamp = markerBase - k, arity = 0, eq = false}, []))
    end

  fun zonk (t : Types.ty) : ty =
    (step ();
     case t of
       Types.TVar r =>
         (case !r of
            Types.Bound (t' as Types.TCon ({stamp, ...}, _)) =>
              if stamp <= markerBase then valOf (Array.sub (!results, markerBase - stamp))
              else let val z = zonk t' in remember (r, z); z end
          | Types.Bound t' => let val z = zonk t' in remember (r, z); z end
          | Types.Unbound {id = tv, kind, eq, ...} =>
              (case kind of
                 Types.KPlain => var (tv, eq, NONE, [])
               | Types.KRigid n => var (tv, eq, SOME n, [])
               | Types.KOverload ns => var (tv, eq, NONE, ns)
               | Types.KFlex (fields, _) =>
                   mk (Flex {tv = tv, eq = eq, fields = List.map (fn (l, a) => (l, zonk a)) fields})))
     | Types.TCon (c, args) =>
         ((case IntTable.find (equality, #stamp c) of
             NONE => IntTable.insert (equality, #stamp c, #eq c)
           | SOME _ => ());
          con (#stamp c, #name c, List.map zonk args))
     | Types.TRecord fs => record (List.map (fn (l, a) => (l, zonk a)) fs)
     | Types.TArrow (a, b) => arrow (zonk a, zonk b))

  (* f, a batch of zonks: the cells put back and the steps counted afresh
     where it ends, whatever happens; only once the types are settled *)
  fun batch (f : unit -> 'a) : 'a =
    if not (!settled) then Error.bug "SourceTy: a type read before Elaborate.finish"
    else (let val r = f () in restore (); r end) handle e => (restore (); raise e)

  fun ofType (t : Types.ty) : ty = batch (fn () => zonk t)

  (* --- printing --- *)
  (* A printer names the type variables of every type it prints alike, so
     that one printer for a unit shows a variable under one name in all of
     its hovers and messages (E12). qualify gives the name a type name has
     where it is printed (its path), else its own is used, with its stamp
     where another name of the same text was shown already *)
  type printer = {names : string IntTable.table, count : int ref, shown : (string * int) list ref,
                  qualify : int * string -> string option}
  fun printer (qualify : int * string -> string option) : printer =
    {names = IntTable.table 16, count = ref 0, shown = ref [], qualify = qualify}
  fun newPrinter () = printer (fn _ => NONE)

  fun isTuple fields =
    let fun go (_, []) = true | go (i, (l, _) :: rest) = l = Int.toString i andalso go (i + 1, rest)
    in List.length fields >= 2 andalso go (1, fields) end

  (* as Types.toStringWith prints the type it was zonked from *)
  fun toStringWith ({names, count, shown, qualify} : printer) (t : ty) : string =
    let
      fun tvName (tv, eq) =
        case IntTable.find (names, tv) of
          SOME s => s
        | NONE =>
            let
              val k = !count
              val base = if k < 26 then String.str (Char.chr (Char.ord #"a" + k)) else "t" ^ Int.toString k
              val s = (if eq then "''" else "'") ^ base
            in count := k + 1; IntTable.insert (names, tv, s); s end
      fun tcName (stamp, name) =
        case qualify (stamp, name) of
          SOME n => n
        | NONE =>
            (case List.find (fn (n, _) => n = name) (!shown) of
               SOME (_, s) => if s = stamp then name else name ^ "/" ^ Int.toString stamp
             | NONE => (shown := (name, stamp) :: !shown; name))
      fun paren (b, s) = if b then "(" ^ s ^ ")" else s
      fun fields fs = String.concatWith ", " (List.map (fn (l, a) => l ^ " : " ^ go (0, a)) fs)
      and go (prec, t) =
        case node t of
          Var {name = SOME n, ...} => n
        | Var {tv, eq, classes = [], ...} => tvName (tv, eq)
        | Var {tv, classes, ...} =>
            if List.exists (fn k => k = "int") classes then "int"
            else if List.exists (fn k => k = "real") classes then "real"
            else (case classes of k :: _ => k | [] => tvName (tv, false))
        | Con {stamp, name, args = []} => tcName (stamp, name)
        | Con {stamp, name, args = [a]} => go (3, a) ^ " " ^ tcName (stamp, name)
        | Con {stamp, name, args} => "(" ^ String.concatWith ", " (List.map (fn a => go (0, a)) args) ^ ") " ^ tcName (stamp, name)
        | Record [] => "unit"
        | Record fs =>
            if isTuple fs then paren (prec >= 2, String.concatWith " * " (List.map (fn (_, a) => go (2, a)) fs))
            else "{" ^ fields fs ^ "}"
        | Arrow (a, b) => paren (prec >= 1, go (1, a) ^ " -> " ^ go (0, b))
        | Flex {fields = fs, ...} => "{" ^ fields fs ^ ", ...}"
    in go (0, t) end

  fun toString t = toStringWith (newPrinter ()) t
end
