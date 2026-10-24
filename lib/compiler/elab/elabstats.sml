(* What the elaborator spends its time on, for --pass-stats=elab
   (docs/ir.md, Options; docs/plans/performance.md, M1): a line on standard
   error for each top-level declaration, with its processor time split by
   the context it was spent in and the operation that spent it, and what
   the elaborator counted while it ran. Off, it costs a test of `on` where
   it is asked. *)
structure ElabStats =
struct
  val on = ref false
  val () = CompilerState.cellRoot ("ElabStats.on", on)

  (* The contexts: the top level; a functor's body checked at its
     declaration (rule 86); the copy of a body elaborated at an application
     whose code is made; and an application only checked: inside a
     declaration's check or inside such a copy, or anywhere in a compile
     that makes no code (--typecheck-only). *)
  datatype context = Top | FunDecl | AppCode | AppCheck
  val contexts = [(Top, "top"), (FunDecl, "fundecl"), (AppCode, "appcode"), (AppCheck, "appcheck")]

  (* The operations: core inference, and whatever is not one of the others;
     a signature instantiated (rule 65); where type (rule 64); sharing (rule
     78 and its derived form); a structure matched against a signature
     (rules 52-54); the specifications of a signature, without the
     operations above inside them; a functor's body copied for an
     application. Time goes to the innermost operation running. *)
  datatype operation = Core | Inst | Where | Share | Match | Specs | Copy
  val operations = [(Core, "core"), (Inst, "inst"), (Where, "where"), (Share, "share"), (Match, "match"),
                    (Specs, "specs"), (Copy, "copy")]

  (* The counters. *)
  datatype counter =
      Realize          (* environments realised (Env.realizeEnv) *)
    | Nodes            (* type nodes the realisations visited: their steps of type work *)
    | InstSig          (* signatures instantiated *)
    | InstNames        (* flexible names they renamed *)
    | WhereClause      (* where type clauses *)
    | ShareTypes       (* sharing type equations, the derived form's included *)
    | ShareStructures  (* sharing equations of structures *)
    | MatchSig         (* structures matched against a signature *)
    | MatchPaths       (* the type paths of the signatures matched *)
    | FunDecls         (* functor bodies checked at their declaration *)
    | AppsCode         (* functor applications whose code is made *)
    | AppsCheck        (* functor applications made only to be checked *)
    | AppDepth         (* the deepest nesting of applications (a maximum) *)
    | Unifies          (* unifications, each pair of types visited *)
    | Steps            (* steps of type work, which --type-work bounds *)
  val counters =
    [(Realize, "realize"), (Nodes, "nodes"), (InstSig, "inst"), (InstNames, "inst.names"),
     (WhereClause, "where"), (ShareTypes, "share.types"), (ShareStructures, "share.structures"),
     (MatchSig, "match"), (MatchPaths, "match.paths"), (FunDecls, "fundecl"), (AppsCode, "app.code"),
     (AppsCheck, "app.check"), (AppDepth, "app.depth"), (Unifies, "unify"), (Steps, "steps")]

  fun contextIndex c = case c of Top => 0 | FunDecl => 1 | AppCode => 2 | AppCheck => 3
  fun operationIndex opn =
    case opn of Core => 0 | Inst => 1 | Where => 2 | Share => 3 | Match => 4 | Specs => 5 | Copy => 6
  fun counterIndex c =
    case c of
      Realize => 0 | Nodes => 1 | InstSig => 2 | InstNames => 3 | WhereClause => 4 | ShareTypes => 5
    | ShareStructures => 6 | MatchSig => 7 | MatchPaths => 8 | FunDecls => 9 | AppsCode => 10
    | AppsCheck => 11 | AppDepth => 12 | Unifies => 13 | Steps => 14
  val nOps = List.length operations
  fun cell (c, opn) = contextIndex c * nOps + operationIndex opn

  val times = Array.array (List.length contexts * nOps, Time.zeroTime)
  val () = CompilerState.arrayRoot ("ElabStats.times", times)
  val counts = Array.array (List.length counters, 0)
  val () = CompilerState.arrayRoot ("ElabStats.counts", counts)

  val timer : Timer.cpu_timer option ref = ref NONE
  val () = CompilerState.cellRoot ("ElabStats.timer", timer)
  fun now () =
    case !timer of
      SOME t => let val {usr, sys} = Timer.checkCPUTimer t in Time.+ (usr, sys) end
    | NONE => Time.zeroTime

  val context = ref Top
  val () = CompilerState.cellRoot ("ElabStats.context", context)
  val operation = ref Core
  val () = CompilerState.cellRoot ("ElabStats.operation", operation)
  val last = ref Time.zeroTime
  val () = CompilerState.cellRoot ("ElabStats.last", last)
  val depth = ref 0
  val () = CompilerState.cellRoot ("ElabStats.depth", depth)

  fun enable () = (on := true; timer := SOME (Timer.startCPUTimer ()))

  (* the time since the last charge, to what is running *)
  fun charge () =
    let
      val t = now ()
      val i = cell (!context, !operation)
    in
      Array.update (times, i, Time.+ (Array.sub (times, i), Time.- (t, !last)));
      last := t
    end

  fun add (c, n) =
    if !on then let val i = counterIndex c in Array.update (counts, i, Array.sub (counts, i) + n) end else ()
  fun count c = add (c, 1)

  (* f (), its time the operation's *)
  fun during (opn : operation) (f : unit -> 'a) : 'a =
    if not (!on) then f ()
    else
      let
        val saved = !operation
        val () = (charge (); operation := opn)
        val r = f () handle e => (charge (); operation := saved; raise e)
      in charge (); operation := saved; r end

  (* f (), in the context c, its operations its own *)
  fun within (c : context) (f : unit -> 'a) : 'a =
    if not (!on) then f ()
    else
      let
        val (savedC, savedO) = (!context, !operation)
        val () = (charge (); context := c; operation := Core)
        val r = f () handle e => (charge (); context := savedC; operation := savedO; raise e)
      in charge (); context := savedC; operation := savedO; r end

  (* f (), a functor application -- its match, the copy of the body and
     the copy's elaboration -- in the context of its kind: its code is made
     where the code of what it is in is, if the compile makes code at all
     (`made`; not under --typecheck-only) *)
  fun application (made : bool) (f : unit -> 'a) : 'a =
    if not (!on) then f ()
    else
      let
        val code = made andalso (case !context of Top => true | AppCode => true | _ => false)
        val () = count (if code then AppsCode else AppsCheck)
        val () = depth := !depth + 1
        val i = counterIndex AppDepth
        val () = if !depth > Array.sub (counts, i) then Array.update (counts, i, !depth) else ()
        val r = within (if code then AppCode else AppCheck) f handle e => (depth := !depth - 1; raise e)
      in depth := !depth - 1; r end

  (* what is counted from here on, a declaration's *)
  fun reset () =
    if not (!on) then ()
    else
      (Array.modify (fn _ => Time.zeroTime) times;
       Array.modify (fn _ => 0) counts;
       context := Top; operation := Core; depth := 0;
       last := now ())

  (* The line of a declaration, at `where`, of the kind and name given (a
     name of "" printed as "-"), with its steps of type work:
     `elab WHERE KIND NAME total=US CONTEXT.OPERATION=US ... COUNTER=N ...`,
     in microseconds of processor time, what is zero left out. *)
  fun emit (where_ : string, kind : string, name : string, steps : int) : unit =
    let
      val () = charge ()
      val () = add (Steps, steps)
      val cells =
        List.concat
          (List.map (fn (c, cn) =>
                        List.mapPartial (fn (opn, opName) =>
                                            let val t = Time.toMicroseconds (Array.sub (times, cell (c, opn)))
                                            in if t = 0 then NONE else SOME (cn ^ "." ^ opName, t) end)
                                        operations)
                    contexts)
      (* the cells' microseconds added, so that the line adds up *)
      val total = List.foldl (fn ((_, t), sum) => sum + t) 0 cells
      val cs = List.mapPartial (fn (c, n) =>
                                   let val v = Array.sub (counts, counterIndex c)
                                   in if v = 0 then NONE else SOME (n ^ "=" ^ Int.toString v) end) counters
      val name = if name = "" then "-" else name
    in
      TextIO.output (TextIO.stdErr,
                     String.concatWith " " (["elab", where_, kind, name, "total=" ^ LargeInt.toString total]
                                            @ List.map (fn (k, t) => k ^ "=" ^ LargeInt.toString t) cells @ cs) ^ "\n")
    end
end
