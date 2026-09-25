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
     parameter is never made a closure, since a closure is called with one.
   A breach is a bug of the compiler, raised as Error.Bug. *)
structure LowLint =
struct
  open Low

  fun check (p : program) : unit =
    let
      fun bug msg = Error.bug msg

      (* the number of parameters of each function, by its id *)
      val arity : int IntMap.map =
        List.foldl (fn ({id, params, ...} : func, m) => IntMap.insert (m, id, List.length params)) IntMap.empty p
      fun known (where', f, args) =
        case IntMap.find (arity, f) of
          NONE => bug (where' ^ ": a known call of no function f" ^ Int.toString f)
        | SOME n =>
            if n = List.length args then ()
            else bug (where' ^ ": f" ^ Int.toString f ^ " of " ^ Int.toString n ^ " parameters given "
                      ^ Int.toString (List.length args) ^ " arguments")
      fun closure (where', f) =
        case IntMap.find (arity, f) of
          SOME 1 => ()
        | SOME n => bug (where' ^ ": a closure of f" ^ Int.toString f ^ ", which has " ^ Int.toString n ^ " parameters")
        | NONE => bug (where' ^ ": a closure of no function f" ^ Int.toString f)

      fun func ({id, params, nvars, blocks, ...} : func) =
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
                         | Closure (f, _) => closure (here, f)
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
                  | Return _ => if depth = 0 then () else bug (here ^ ": a return with a handler pushed")
                  | TailCall _ => if depth = 0 then () else bug (here ^ ": a tail call with a handler pushed")
                  | TailCallK (f, args) =>
                      (known (here, f, args);
                       if depth = 0 then () else bug (here ^ ": a tail call with a handler pushed"))
                  | Raise _ => ()
                end
        in
          Vector.appi block bv
        end
    in
      List.app func p
    end
end
