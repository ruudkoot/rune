(* What every Low keeps (docs/ir.md), checked after the pass lower when
   --lint is given:
   * SSA: every variable of a function is below its number of variables and
     defined once in it, by an instruction or as a block's parameter, and is
     defined on every way to each of its uses -- a handler's block sees only
     what was defined where it was pushed, since its region may raise
     anywhere;
   * blocks: every jump is to a block of its function, with an argument for
     each parameter, and forward in their order -- but a jump back to the
     head of a loop (Lower), where what reaches the head is defined too, so
     that only its parameters change on the way round; a handler's block
     has one parameter, the exception;
   * handlers: every way into a block has the same handlers pushed, a pop
     has one to pop, and a function returns, or calls in tail position,
     with none;
   * calls: a known call (CallK) is of a function of the program, with an
     argument for each of its parameters; a function with other than one
     parameter is never made a closure, since a closure is called with one;
   * closures: a closure is given a value for each its function captures,
     and the function reads each of them (Env i, i below their number) --
     one it never reads it read some other way, as a variable of another
     function, whose variables are numbered as its own are;
   * representations: a variable holds what its representation says, where
     something else says too -- the operation that makes it, a primitive
     that takes it (Prims.repsOf, from the primitive's type), a field of a
     tuple or a constructor made in the function, a block's or a known
     function's parameter it is passed to, what a closure's function reads
     of a value it captures, and an exception. Two agree where a value can
     be both: any with every one, con with con0 and ptr.
   A breach is a bug of the compiler, raised as Error.Bug. *)
structure LowLint =
struct
  open Low

  fun check (p : program) : unit =
    let
      fun bug msg = Error.bug msg

      (* the number of parameters of each function, and of values it
         captures, by its id *)
      val arity : int IntMap.map =
        List.foldl (fn ({id, params, ...} : func, m) => IntMap.insert (m, id, List.length params)) IntMap.empty p
      val captures : int IntMap.map =
        List.foldl (fn ({id, ncaptured, ...} : func, m) => IntMap.insert (m, id, ncaptured)) IntMap.empty p
      fun known (where', f, args) =
        case IntMap.find (arity, f) of
          NONE => bug (where' ^ ": a known call of no function f" ^ Int.toString f)
        | SOME n =>
            if n = List.length args then ()
            else bug (where' ^ ": f" ^ Int.toString f ^ " of " ^ Int.toString n ^ " parameters given "
                      ^ Int.toString (List.length args) ^ " arguments")
      fun closure (where', f, vs) =
        case (IntMap.find (arity, f), IntMap.find (captures, f)) of
          (SOME 1, SOME n) =>
            if n = List.length vs then ()
            else bug (where' ^ ": a closure of f" ^ Int.toString f ^ ", which captures " ^ Int.toString n
                      ^ " values, given " ^ Int.toString (List.length vs))
        | (SOME n, _) => bug (where' ^ ": a closure of f" ^ Int.toString f ^ ", which has " ^ Int.toString n ^ " parameters")
        | (NONE, _) => bug (where' ^ ": a closure of no function f" ^ Int.toString f)

      fun func ({id, params, ncaptured, nvars, blocks, ...} : func) =
        let
          val where' = "function f" ^ Int.toString id
          val defined = Array.array (Int.max (nvars, 1), false)
          fun define x =
            if x < 0 orelse x >= nvars then bug (where' ^ ": v" ^ Int.toString x ^ " is no variable of it")
            else if Array.sub (defined, x) then bug (where' ^ ": v" ^ Int.toString x ^ " is defined twice")
            else Array.update (defined, x, true)
          val () = List.app define params
          val index : int IntMap.map =
            #1 (List.foldl (fn ({label, ...} : block, (m, i)) =>
                              if IntMap.member (m, label) then bug (where' ^ ": block b" ^ Int.toString label ^ " twice")
                              else (IntMap.insert (m, label, i), i + 1))
                           (IntMap.empty, 0) blocks)
          fun blockOf l =
            case IntMap.find (index, l) of
              SOME i => i
            | NONE => bug (where' ^ ": a jump to no block b" ^ Int.toString l)
          val bv = Vector.fromList blocks
          val n = Vector.length bv
          (* what reaches each block: the variables defined on every way to
             it, and the handlers pushed; NONE where nothing has yet *)
          val into : (unit IntMap.map * int) option array = Array.array (n, NONE)
          fun arrive (from, i, avail, depth) =
            if i <= from then
              let val here = where' ^ ": a jump backward, to b" ^ Int.toString (#label (Vector.sub (bv, i)))
              in
                case Array.sub (into, i) of
                  NONE => bug (here ^ ", which nothing reached before")
                | SOME (a, d) =>
                    if d <> depth then bug (here ^ ", with " ^ Int.toString depth ^ " handlers where it has " ^ Int.toString d)
                    else
                      case List.find (fn x => not (IntMap.member (avail, x))) (IntMap.listKeys a) of
                        SOME x => bug (here ^ ", which has v" ^ Int.toString x ^ ", which the jump has not")
                      | NONE => ()
              end
            else
              case Array.sub (into, i) of
                NONE => Array.update (into, i, SOME (avail, depth))
              | SOME (a, d) =>
                  if d <> depth then
                    bug (where' ^ ": b" ^ Int.toString (#label (Vector.sub (bv, i))) ^ " is reached with "
                         ^ Int.toString d ^ " and with " ^ Int.toString depth ^ " handlers")
                  else Array.update (into, i, SOME (IntMap.filteri (fn (x, _) => IntMap.member (avail, x)) a, d))
          val () = Array.update (into, 0, SOME (List.foldl (fn (x, m) => IntMap.insert (m, x, ())) IntMap.empty params, 0))
          fun block (i, {label, params, instrs, transfer} : block) =
            case Array.sub (into, i) of
              NONE => ()        (* not reached: dead code is allowed *)
            | SOME (avail, depth) =>
                let
                  val here = where' ^ ", b" ^ Int.toString label
                  fun needs (avail, x) =
                    if IntMap.member (avail, x) then ()
                    else bug (here ^ ": v" ^ Int.toString x ^ " is used where it is not defined on every way")
                  val avail = List.foldl (fn (x, m) => (define x; IntMap.insert (m, x, ()))) avail params
                  fun step (ins, (avail, depth, pushed)) =
                    case ins of
                      Def (x, oper) =>
                        (List.app (fn y => needs (avail, y)) (uses oper); define x;
                         case oper of
                           CallK (f, args) => known (here, f, args)
                         | Closure (f, vs) => closure (here, f, vs)
                         | _ => ();
                         (IntMap.insert (avail, x, ()), depth, pushed))
                    | Push h =>
                        let val hi = blockOf h
                        in
                          case #params (Vector.sub (bv, hi)) of
                            [_] => ()
                          | _ => bug (here ^ ": the handler b" ^ Int.toString h ^ " has other than one parameter");
                          arrive (i, hi, avail, depth);
                          (avail, depth + 1, pushed + 1)
                        end
                    | Pop => if depth = 0 then bug (here ^ ": a pop with no handler") else (avail, depth - 1, pushed)
                    | At _ => (avail, depth, pushed)
                  val (avail, depth, _) = List.foldl step (avail, depth, 0) instrs
                  val () = List.app (fn y => needs (avail, y)) (transferUses transfer)
                  fun goto (l, args) =
                    let val j = blockOf l
                    in
                      if List.length (#params (Vector.sub (bv, j))) <> List.length args then
                        bug (here ^ ": b" ^ Int.toString l ^ " given " ^ Int.toString (List.length args) ^ " arguments")
                      else arrive (i, j, avail, depth)
                    end
                in
                  case transfer of
                    Goto (l, args) => goto (l, args)
                  | If (_, a, b) => (goto (a, []); goto (b, []))
                  | IfTag (_, _, a, b) => (goto (a, []); goto (b, []))
                  | Switch (_, cases, d) => (List.app (fn (_, l) => goto (l, [])) cases; goto (d, []))
                  | Return _ => if depth = 0 then () else bug (here ^ ": a return with a handler pushed")
                  | TailCall _ => if depth = 0 then () else bug (here ^ ": a tail call with a handler pushed")
                  | TailCallK (f, args) =>
                      (known (here, f, args);
                       if depth = 0 then () else bug (here ^ ": a tail call with a handler pushed"))
                  | Raise _ => ()
                end
          (* what it reads of what it captured, in any block *)
          val read = Array.array (Int.max (ncaptured, 1), false)
          fun env (Def (_, Env i)) =
                if i < 0 orelse i >= ncaptured then
                  bug (where' ^ ": env " ^ Int.toString i ^ " of a function that captures " ^ Int.toString ncaptured)
                else Array.update (read, i, true)
            | env _ = ()
        in
          Vector.appi block bv;
          List.app (fn ({instrs, ...} : block) => List.app env instrs) blocks;
          case List.find (fn i => not (Array.sub (read, i))) (List.tabulate (ncaptured, fn i => i)) of
            SOME i => bug (where' ^ ": env " ^ Int.toString i ^ " is captured and never read")
          | NONE => ()
        end

      (* ---- representations ---- *)

      fun repIn (rs : rep vector, x : var) = if x >= 0 andalso x < Vector.length rs then Vector.sub (rs, x) else RAny
      (* two agree where a value can be both: any with every one, con with
         con0 and ptr *)
      fun agree (a, b) =
        a = RAny orelse b = RAny orelse a = b
        orelse (a = RCon andalso (b = RCon0 orelse b = RPtr))
        orelse (b = RCon andalso (a = RCon0 orelse a = RPtr))
      (* what an operation makes, where it alone says *)
      fun makes (oper : operation) : rep =
        case oper of
          Const (Lambda.CInt _) => RInt
        | Const (Lambda.CWord _) => RWord
        | Const (Lambda.CReal _) => RReal
        | Const (Lambda.CString _) => RPtr
        | Const (Lambda.CChar _) => RChar
        | Unit => RUnit
        | Con0 _ => RCon0
        | Self => RPtr
        | Prim (name, _) => (case Prims.repsOf name of SOME (_, r) => repOfCode r | NONE => RAny)
        | Tuple (_ :: _) => RPtr
        | Con _ => RPtr
        | ConTag _ => RInt
        | NewExn _ => RPtr
        | BuiltinExn _ => RPtr
        | MkExn _ => RPtr
        | ExnCon _ => RPtr
        | Closure _ => RPtr
        | _ => RAny
      (* each function's parameters, and what it reads of what it captured
         where it says what that is *)
      val paramReps : rep list IntMap.map =
        List.foldl (fn ({id, params, reps, ...} : func, m) => IntMap.insert (m, id, List.map (fn x => repIn (reps, x)) params))
                   IntMap.empty p
      val envReps : (int * rep) list IntMap.map =
        List.foldl (fn ({id, blocks, reps, ...} : func, m) =>
                      IntMap.insert (m, id, List.concat (List.map (fn ({instrs, ...} : block) =>
                                                                      List.mapPartial (fn Def (x, Env i) => if repIn (reps, x) = RAny then NONE else SOME (i, repIn (reps, x))
                                                                                        | _ => NONE) instrs) blocks)))
                   IntMap.empty p

      (* Each variable holds what it says: what an operation makes, a field
         of a tuple or a constructor made in the function, what a primitive
         takes, a known call's and a jump's parameters, what a closure's
         function reads of each value it captures, and an exception. *)
      fun representations ({id, blocks, reps = rs, ...} : func) =
        let
          val where' = "function f" ^ Int.toString id
          fun repOf x = repIn (rs, x)
          val paramsOf : var list IntMap.map =
            List.foldl (fn ({label, params, ...} : block, m) => IntMap.insert (m, label, params)) IntMap.empty blocks
          (* what made each variable, for those whose parts are read back *)
          val made : operation IntTable.table = IntTable.table 64
          fun want (here, x, r, what) =
            if agree (repOf x, r) then ()
            else bug (here ^ ": v" ^ Int.toString x ^ " is " ^ repName (repOf x) ^ " where " ^ what ^ " is " ^ repName r)
          fun args (here, xs, rs, what) =
            let
              fun go (k, x :: xs, r :: rs) = (want (here, x, r, what k); go (k + 1, xs, rs))
                | go _ = ()
            in go (0, xs, rs) end
          fun call (here, f, xs) =
            case IntMap.find (paramReps, f) of
              SOME rs => args (here, xs, rs, fn k => "parameter " ^ Int.toString k ^ " of f" ^ Int.toString f)
            | NONE => ()
          fun captured (here, f, i, x) =
            List.app (fn (j, r) => if i = j then want (here, x, r, "env " ^ Int.toString i ^ " of f" ^ Int.toString f) else ())
                     (case IntMap.find (envReps, f) of SOME l => l | NONE => [])
          fun field (here, x, v, parts, i) =
            if i < List.length parts then
              let val y = List.nth (parts, i)
              in want (here, x, repOf y, "field " ^ Int.toString i ^ " of v" ^ Int.toString v ^ ", v" ^ Int.toString y ^ ",") end
            else ()
          fun instr here i =
            case i of
              Def (x, oper) =>
                (want (here, x, makes oper, "what makes it");
                 case oper of
                   Prim (name, xs) =>
                     (case Prims.repsOf name of
                        SOME (rs, _) => args (here, xs, List.map repOfCode rs, fn k => "argument " ^ Int.toString k ^ " of " ^ name)
                      | NONE => ())
                 | Select (k, v) => (case IntTable.find (made, v) of SOME (Tuple parts) => field (here, x, v, parts, k) | _ => ())
                 | Field (tag, k, v) =>
                     (case IntTable.find (made, v) of SOME (Con (tag', parts)) => if tag = tag' then field (here, x, v, parts, k) else () | _ => ())
                 | Decon (tag, v) =>
                     (case IntTable.find (made, v) of SOME (Con (tag', [a])) => if tag = tag' then field (here, x, v, [a], 0) else () | _ => ())
                 | CallK (f, xs) => call (here, f, xs)
                 | Closure (f, xs) =>
                     ignore (List.foldl (fn (y, k) => ((case y of SOME y => captured (here, f, k, y) | NONE => ()); k + 1)) 0 xs)
                 | SetEnv (c, k, y) => (case IntTable.find (made, c) of SOME (Closure (f, _)) => captured (here, f, k, y) | _ => ())
                 | _ => ();
                 IntTable.insert (made, x, oper))
            | Push h =>
                (case IntMap.find (paramsOf, h) of
                   SOME [e] => want (here, e, RPtr, "the exception")
                 | _ => ())
            | _ => ()
          fun block ({label, instrs, transfer, ...} : block) =
            let val here = where' ^ ", b" ^ Int.toString label
            in
              List.app (instr here) instrs;
              case transfer of
                Goto (l, xs) =>
                  (case IntMap.find (paramsOf, l) of
                     SOME ps => args (here, xs, List.map repOf ps, fn k => "parameter " ^ Int.toString k ^ " of b" ^ Int.toString l)
                   | NONE => ())
              | TailCallK (f, xs) => call (here, f, xs)
              | _ => ()
            end
        in
          List.app block blocks
        end
    in
      List.app func p;
      List.app representations p
    end
end
