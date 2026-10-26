(* Witness: what the elaborator records of the nodes of the syntax, by their
   ids (docs/plans/correctness/linting.md, D1, D2): the choices the
   Definition leaves open (*What the Definition says*) that the slots of Ast
   do not already hold. With them a checker works out every other node's
   type without unification (AstLint, E6), and an editor the type of any
   node it is asked about (E12). Each entry keeps its node's span with the
   types, which stay the elaborator's (Types.ty) until something reads them
   as SourceTy, after Elaborate.finish.

   What is recorded, each in a table of its own, by the id of the node:
   - instances: a constructor in a pattern (PApp's, or a PVar that names a
     constructor), the instance of its scheme at that use (rules 35, 41);
   - types: a wildcard's (rule 32), a raise's (rule 11) and a [] pattern's;
   - created: the type names a datatype or abstype declaration made (rule
     17, 19), with the equality worked out for them (SourceTy.admitsEq);
   - scoped: the explicit type variables a value declaration scopes, those
     it names and those implicitly scoped at it (4.6, rule 15), each with
     its rigid variable;
   - generalised: the type variables a binding generalised (rule 15's
     Clos), taken at the binding, since generalising in place marks the
     variables a binding shares with the others of its group generic at
     the group's first (E6); by a val's or val rec's pattern, a fun's
     fundef;
   - defaults: the type an overloaded identifier or constant was given
     where its context ended (Appendix E, --overloading);
   - status: whether each declaration at top level elaborated, so that what
     a failed one recorded (dropped where it failed) is known to be missing.

   What a declaration that fails recorded is dropped where it fails
   (Elaborate.restore), and what a unit recorded where the unit is undone
   (UnitBasis.undo), by marks of a log of what was recorded rather than by
   a range of ids as the tables by stamp are: where a declaration's context
   ends the defaults it records may be of the nodes of declarations before
   it (--overloading=toplevel, topdec), which the snapshot a failed one is
   restored to holds pending again. *)
structure Witness =
struct
  type 'a entry = {span : Source.span, value : 'a}

  val instances : Types.ty entry IntTable.table = IntTable.table 16
  val () = CompilerState.tableRoot ("Witness.instances", instances)
  val types : Types.ty entry IntTable.table = IntTable.table 16
  val () = CompilerState.tableRoot ("Witness.types", types)
  val created : Types.tycon list entry IntTable.table = IntTable.table 16
  val () = CompilerState.tableRoot ("Witness.created", created)
  val scoped : (string * Types.ty) list entry IntTable.table = IntTable.table 16
  val () = CompilerState.tableRoot ("Witness.scoped", scoped)
  val generalised : Types.tvar ref list entry IntTable.table = IntTable.table 16
  val () = CompilerState.tableRoot ("Witness.generalised", generalised)
  val defaults : Types.ty entry IntTable.table = IntTable.table 16
  val () = CompilerState.tableRoot ("Witness.defaults", defaults)
  val status : bool entry IntTable.table = IntTable.table 16
  val () = CompilerState.tableRoot ("Witness.status", status)

  (* what was recorded, newest first, each as the id times eight and the
     table's number, and how many entries that is *)
  val log : int list ref = ref []
  val () = CompilerState.cellRoot ("Witness.log", log)
  val logged = ref 0
  val () = CompilerState.cellRoot ("Witness.logged", logged)

  fun note (k : int, id : int) = (log := id * 8 + k :: !log; logged := !logged + 1)
  fun put (k, table, id, span, value) =
    if id < 0 then () else (IntTable.insert (table, id, {span = span, value = value}); note (k, id))

  fun instance (id, span, t : Types.ty) = put (0, instances, id, span, t)
  fun nodeType (id, span, t : Types.ty) = put (1, types, id, span, t)
  fun names (id, span, cs : Types.tycon list) = put (2, created, id, span, cs)
  fun scope (id, span, vs : (string * Types.ty) list) = put (3, scoped, id, span, vs)
  fun generalisation (id, span, vs : Types.tvar ref list) = put (4, generalised, id, span, vs)
  fun default (id, span, t : Types.ty) = put (5, defaults, id, span, t)
  fun elaborated (id, span, ok : bool) = put (6, status, id, span, ok)

  (* an entry of the log taken out of its table *)
  fun remove (e : int) =
    let
      val k = e mod 8 and id = e div 8
      fun out t = IntTable.removeRange (t, id, id + 1)
    in
      case k of
        0 => out instances | 1 => out types | 2 => out created | 3 => out scoped
      | 4 => out generalised | 5 => out defaults | _ => out status
    end

  (* the mark of what has been recorded so far, and what was recorded since
     a mark taken out again *)
  fun mark () : int = !logged
  fun dropSince (m : int) : unit =
    let
      fun go () =
        if !logged <= m then ()
        else case !log of
               e :: rest => (remove e; log := rest; logged := !logged - 1; go ())
             | [] => logged := 0
    in go () end

  (* --dump-witnesses: each entry recorded of a node of the files wanted, in
     the order it was recorded, with its node's span and its types read as
     SourceTy, one printer for all (after Elaborate.finish) *)
  fun dump (wanted : string -> bool, say : string -> unit) : unit =
    let
      val p = SourceTy.newPrinter ()
      fun show t = SourceTy.toStringWith p (SourceTy.zonk t)
      fun line (span, what) = say (Source.describe span ^ ": " ^ what ^ "\n")
      fun one (e : int) =
        let
          val k = e mod 8 and id = e div 8
          fun with' (table, f) = case IntTable.find (table, id) of
                                   SOME {span, value} => if wanted (#file span) then line (span, f value) else ()
                                 | NONE => ()
        in
          case k of
            0 => with' (instances, fn t => "instance " ^ show t)
          | 1 => with' (types, fn t => "type " ^ show t)
          | 2 => with' (created, fn cs => "created " ^ String.concatWith ", " (List.map (fn c => #name c ^ (if #eq c then " (eq)" else "")) cs))
          | 3 => with' (scoped, fn vs => "scoped " ^ String.concatWith ", " (List.map (fn (v, t) => v ^ " = " ^ show t) vs))
          | 4 => with' (generalised, fn rs => "generalised " ^ String.concatWith ", " (List.map (show o Types.TVar) rs))
          | 5 => with' (defaults, fn t => "default " ^ show t)
          | _ => with' (status, fn ok => if ok then "elaborated" else "failed")
        end
    in SourceTy.batch (fn () => List.app one (List.rev (!log))) end
end
