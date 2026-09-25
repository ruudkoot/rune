(* What every Low keeps (docs/ir.md), checked after the pass lower when
   --lint is given:
   * SSA: every variable is defined once in the program, by an instruction
     or as a block's parameter, and is defined on every way to each of its
     uses -- a handler's block sees only what was defined where it was
     pushed, since its region may raise anywhere;
   * blocks: every jump is to a block of its function, forward in their
     order, with an argument for each parameter; a handler's block has one
     parameter, the exception;
   * handlers: every way into a block has the same handlers pushed, a pop
     has one to pop, and a function returns, or calls in tail position,
     with none.
   A breach is a bug of the compiler, raised as Error.Bug. *)
structure LowLint =
struct
  open Low

  fun check (p : program) : unit =
    let
      fun bug msg = Error.bug msg
      val defined : unit IntMap.map ref = ref IntMap.empty
      fun define x =
        if IntMap.member (!defined, x) then bug ("v" ^ Int.toString x ^ " is defined twice")
        else defined := IntMap.insert (!defined, x, ())

      fun func ({id, param, blocks, ...} : func) =
        let
          val where' = "function f" ^ Int.toString id
          val () = define param
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
            if i <= from then bug (where' ^ ": a jump backward, to b" ^ Int.toString (#label (Vector.sub (bv, i))))
            else
              case Array.sub (into, i) of
                NONE => Array.update (into, i, SOME (avail, depth))
              | SOME (a, d) =>
                  if d <> depth then
                    bug (where' ^ ": b" ^ Int.toString (#label (Vector.sub (bv, i))) ^ " is reached with "
                         ^ Int.toString d ^ " and with " ^ Int.toString depth ^ " handlers")
                  else Array.update (into, i, SOME (IntMap.filteri (fn (x, _) => IntMap.member (avail, x)) a, d))
          val () = Array.update (into, 0, SOME (IntMap.insert (IntMap.empty, param, ()), 0))
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
                  | Raise _ => ()
                end
        in
          Vector.appi block bv
        end
    in
      List.app func p
    end
end
