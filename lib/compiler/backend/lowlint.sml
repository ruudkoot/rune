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
          NONE =>
            (* in a unit, a function of a unit before it, or the next unit's top
               level (Lower.imported) *)
            if !Pass.whole then bug (where' ^ ": a known call of no function f" ^ Int.toString f) else ()
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

      fun func (f as {id, params, ncaptured, nvars, blocks, ...} : func) =
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
          (* What is defined on every way to a place, by dominance (linting
             roadmap, M2; a map of what is available, filtered at every
             join, grew with blocks times variables): a block's code is
             segments, one up to each push and one after the last, each
             entered from the one before it -- and a handler's block from
             the segment its push ends, since its region may raise anywhere
             after it. Every way into a segment goes forward, in the order of
             the blocks, but a jump back to the head of a loop, which is
             checked apart; so a segment's dominators are numbered below it,
             and its immediate one is where the segments it is entered from
             meet in the tree. A variable, defined once, is defined on every
             way to a use where the segment of its definition dominates the
             use's, and it is defined before the use in its own. *)
          val nsegs = n + List.foldl (fn ({instrs, ...} : block, k) =>
                                        List.foldl (fn (Push _, k) => k + 1 | (_, k) => k) k instrs) 0 blocks
          val idom = Array.array (Int.max (nsegs, 1), 0)
          val defines = Array.array (Int.max (nsegs, 1), ~1)   (* a variable the segment defines, or ~1 *)
          val segs = ref 0
          fun segment (up : int) = let val s = !segs in segs := s + 1; Array.update (idom, s, up); s end
          fun dominates (a, s) = s = a orelse (s > a andalso dominates (a, Array.sub (idom, s)))
          fun meet (a, b) =
            if a = b then a else if a > b then meet (Array.sub (idom, a), b) else meet (a, Array.sub (idom, b))
          val defSeg = Array.array (Int.max (nvars, 1), ~1)
          fun defineIn (s, x) =
            (define x; Array.update (defSeg, x, s); if Array.sub (defines, s) < 0 then Array.update (defines, s, x) else ())
          (* what enters each block forward: the segments it is entered from,
             and the handlers pushed; NONE where nothing has yet *)
          val into : (int list * int) option array = Array.array (n, NONE)
          (* each block's first segment, once it is reached *)
          val entry = Array.array (n, ~1)
          fun arrive (from, i, seg, depth) =
            if i <= from then
              let val here = where' ^ ": a jump backward, to b" ^ Int.toString (#label (Vector.sub (bv, i)))
              in
                case (Array.sub (into, i), Array.sub (entry, i)) of
                  (SOME (_, d), e) =>
                    if d <> depth then bug (here ^ ", with " ^ Int.toString depth ^ " handlers where it has " ^ Int.toString d)
                    else
                      (* what reaches the head: what its first segment's
                         dominators define, each of which must dominate the
                         jump; one that does, does for all above it *)
                      let
                        fun up a =
                          if a < 0 orelse dominates (a, seg) then ()
                          else if Array.sub (defines, a) >= 0 then
                            bug (here ^ ", which has v" ^ Int.toString (Array.sub (defines, a)) ^ ", which the jump has not")
                          else if a = 0 then ()
                          else up (Array.sub (idom, a))
                      in up (if e > 0 then Array.sub (idom, e) else ~1) end
                | (NONE, _) => bug (here ^ ", which nothing reached before")
              end
            else
              case Array.sub (into, i) of
                NONE => Array.update (into, i, SOME ([seg], depth))
              | SOME (froms, d) =>
                  if d <> depth then
                    bug (where' ^ ": b" ^ Int.toString (#label (Vector.sub (bv, i))) ^ " is reached with "
                         ^ Int.toString d ^ " and with " ^ Int.toString depth ^ " handlers")
                  else Array.update (into, i, SOME (seg :: froms, d))
          (* the function's parameters, defined where it is entered *)
          val () = Array.update (into, 0, SOME ([], 0))
          fun block (i, {label, params, instrs, transfer} : block) =
            case Array.sub (into, i) of
              NONE => ()        (* not reached: dead code is allowed *)
            | SOME (froms, depth) =>
                let
                  val here = where' ^ ", b" ^ Int.toString label
                  val first = segment (case froms of [] => 0 | f :: fs => List.foldl meet f fs)
                  val () = Array.update (entry, i, first)
                  val () = if i = 0 then List.app (fn x => Array.update (defSeg, x, first)) (#params (f : func)) else ()
                  val () = if i = 0 then (case #params f of x :: _ => Array.update (defines, first, x) | [] => ()) else ()
                  fun needs (seg, x) =
                    if x >= 0 andalso x < nvars andalso Array.sub (defSeg, x) >= 0 andalso dominates (Array.sub (defSeg, x), seg)
                    then ()
                    else bug (here ^ ": v" ^ Int.toString x ^ " is used where it is not defined on every way")
                  val () = List.app (fn x => defineIn (first, x)) params
                  fun step (ins, (seg, depth, pushed)) =
                    case ins of
                      Def (x, oper) =>
                        (List.app (fn y => needs (seg, y)) (uses oper); defineIn (seg, x);
                         case oper of
                           CallK (f, args) => known (here, f, args)
                         | Closure (f, vs) => closure (here, f, vs)
                         | _ => ();
                         (seg, depth, pushed))
                    | Push h =>
                        let val hi = blockOf h
                        in
                          case #params (Vector.sub (bv, hi)) of
                            [_] => ()
                          | _ => bug (here ^ ": the handler b" ^ Int.toString h ^ " has other than one parameter");
                          arrive (i, hi, seg, depth);
                          (segment seg, depth + 1, pushed + 1)
                        end
                    | Pop => if depth = 0 then bug (here ^ ": a pop with no handler") else (seg, depth - 1, pushed)
                    | At _ => (seg, depth, pushed)
                  val (seg, depth, _) = List.foldl step (first, depth, 0) instrs
                  val () = List.app (fn y => needs (seg, y)) (transferUses transfer)
                  fun goto (l, args) =
                    let val j = blockOf l
                    in
                      if List.length (#params (Vector.sub (bv, j))) <> List.length args then
                        bug (here ^ ": b" ^ Int.toString l ^ " given " ^ Int.toString (List.length args) ^ " arguments")
                      else arrive (i, j, seg, depth)
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
        | Const (Lambda.CInt64 _) => RInt64
        | Const (Lambda.CWord64 _) => RWord64
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

  (* What Lower keeps of results in globals (performance M8; docs/ir.md,
     Low), checked after every lower, --lint or not: a function of the top
     level that returns n fields, or a datatype's constructor, returns its
     first field, or the constructor's tag, and leaves the rest in globals
     that its call reads at once.
   * a read of such a global (Slot) follows, in its block, a known call
     (CallK) of a function that leaves it, with only other such reads and
     positions between;
   * a function of n fields returns, in each block, either what the
     block's last call gave, a call of another function of n, or a value
     after which, since the block's last call, it has set each global of
     its fields that some call reads;
   * it calls in tail position only a function of n, and never through a
     closure.
   Lower says which functions these are, by their globals, and Low names a
     known call's function by its id: `global` is the function's global
     (the inverse of Lower.globalFids), `fields` a function's n, `slots`
     the globals of fields 1 to n - 1 of n, `needed (n, i)` whether a call
     reads field i, and `sum` the globals of a function's datatype. *)
  type results = {global : int -> int option, fields : int -> int option, slots : int -> int list,
                  needed : int * int -> bool, sum : int -> int list option}

  fun results ({global, fields, slots, needed, sum} : results) (p : program) : unit =
    let
      fun bug msg = Error.bug msg
      fun fieldsOf f = case global f of SOME g => fields g | NONE => NONE
      (* the globals a call of f leaves its results in *)
      fun leaves f =
        case global f of
          NONE => NONE
        | SOME g => (case fields g of SOME n => SOME (slots n) | NONE => sum g)
      fun mem (x, l) = List.exists (fn y => y = x) l
      fun func ({id, blocks, ...} : func) =
        let
          val where' = "function f" ^ Int.toString id
          val own = fieldsOf id
          fun block ({label, instrs, transfer, ...} : block) =
            let
              val here = where' ^ ", b" ^ Int.toString label
              fun g s = "g" ^ Int.toString s
              (* the instructions in order: what the call just before
                 leaves (with only reads and positions between), the last
                 call (a variable, and its function where it is known),
                 and the globals set since *)
              fun scan ([], _, last, sets) = (last, sets)
                | scan (i :: rest, after, last, sets) =
                    case i of
                      At _ => scan (rest, after, last, sets)
                    | Def (_, Slot s) =>
                        (case after of
                           SOME (f, ss) =>
                             if mem (s, ss) then scan (rest, after, last, sets)
                             else bug (here ^ ": " ^ g s ^ " read after a call of f" ^ Int.toString f ^ ", which leaves no result in it")
                         | NONE => bug (here ^ ": " ^ g s ^ " read where no call of a function that leaves results comes just before"))
                    | Def (x, CallK (f, _)) => scan (rest, Option.map (fn ss => (f, ss)) (leaves f), SOME (x, SOME f), [])
                    | Def (x, Call _) => scan (rest, NONE, SOME (x, NONE), [])
                    | Def (_, SetGlobal (s, _)) => scan (rest, NONE, last, s :: sets)
                    | _ => scan (rest, NONE, last, sets)
              val (last, sets) = scan (instrs, NONE, NONE, [])
              fun setsAll n =
                List.app (fn (i, s) => if not (needed (n, i)) orelse mem (s, sets) then ()
                                       else bug (here ^ ": a return that has not set " ^ g s ^ ", field " ^ Int.toString i
                                                 ^ " of " ^ Int.toString n))
                         (ListPair.zip (List.tabulate (n - 1, fn i => i + 1), slots n))
            in
              case (own, transfer) of
                (NONE, _) => ()
              | (SOME n, Return v) =>
                  (case last of
                     SOME (x, SOME f) => if x = v andalso fieldsOf f = SOME n then () else setsAll n
                   | _ => setsAll n)
              | (SOME n, TailCallK (f, _)) =>
                  if fieldsOf f = SOME n then ()
                  else bug (here ^ ": a tail call of f" ^ Int.toString f ^ ", which returns no " ^ Int.toString n ^ " fields")
              | (SOME _, TailCall _) => bug (here ^ ": a tail call through a closure")
              | _ => ()
            end
        in
          List.app block blocks
        end
    in
      List.app func p
    end
end
