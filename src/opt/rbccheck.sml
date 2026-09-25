(* What runeopt relies on and the loader does not promise (docs/native.md,
   The contract): in every function, the height of the stack above
   the locals, and the number of handlers the function has installed, are
   the same on every path into an instruction; no path pops below the
   locals, leaves the function by a jump, or falls off its end; no TAILCALL
   or RET happens with a handler of the function still installed, and no
   POPHANDLER without one; every operand fits an int; and every function is
   given one number of arguments -- as many as every known call of it
   (CALLK, TAILCALLK) passes, and one where it is made a closure or is the
   top level -- since its code sets the rest of its locals to unit. The
   compiler's code generators keep all of it (src/backend/codegen.sml,
   stack.sml); a file that does not is refused, and runevm remains the
   place where it runs. *)
structure RbcCheck =
struct
  exception Refused of string

  (* An instruction of the code: where it is, its opcode, and its operands
     (0 where it has fewer). *)
  type instr = {pc : int, opc : int, a : int, b : int}

  (* What a translation needs to know: every instruction, the function of
     each, the height and handler depth before each (~1 where no path reaches
     it), the highest the stack goes above the locals in each function, and
     the number of arguments each is given. *)
  type facts =
    {instrs : instr vector,
     func : int vector,
     height : int vector,
     depth : int vector,
     maxHeight : int vector,
     params : int vector}

  val arity : int vector =
    Vector.fromList (List.map (fn (_, _, a) => a) Prims.table)

  fun refuse msg = raise Refused msg

  (* The instructions of a program the loader has accepted. An operand that
     does not fit an int is refused. *)
  fun decode (p : Rbc.program) : instr vector =
    let
      val code = #code p
      val codeLen = String.size code
      fun operand (pc, k) =
        case Rbc.i32At (code, pc + 1 + 4 * k) of
          Rbc.In v => v
        | _ => refuse ("an operand at " ^ Int.toString pc ^ " is out of range (runeopt takes -2^30 .. 2^30 - 1)")
      fun go (pc, acc) =
        if pc >= codeLen then Vector.fromList (List.rev acc)
        else
          let
            val opc = Rbc.byte (code, pc)
            val n = Vector.sub (Opcodes.nargs, opc)
            val a = if n > 0 then operand (pc, 0) else 0
            val b = if n > 1 then operand (pc, 1) else 0
          in
            go (pc + Rbc.instrLength opc, {pc = pc, opc = opc, a = a, b = b} :: acc)
          end
    in
      go (0, [])
    end

  (* The description of each opcode (src/isa/stack.sml), by its number. *)
  val info : Isa.instruction vector = StackIsa.info

  (* (pops, pushes) of an instruction, from its description. A CALL pushes
     its result when the call returns. *)
  fun effect ({opc, a, b, ...} : instr) : int * int =
    let
      val i = Vector.sub (info, opc)
      fun operand 0 = a
        | operand _ = b
      val pops =
        case #pops i of
          Isa.Fixed n => n
        | Isa.OperandValue k => operand k
        | Isa.ArityOf k => Vector.sub (arity, operand k)
    in
      (pops, #pushes i)
    end

  (* An instruction after which control does not go on to the next. *)
  fun ends opc = Isa.ends (Vector.sub (info, opc))

  (* One that goes to the label of its first operand, always or on a
     condition. *)
  fun isJump opc =
    case #flow (Vector.sub (info, opc)) of Isa.Jump => true | Isa.Branch => true | _ => false

  fun leaves opc =
    case #flow (Vector.sub (info, opc)) of Isa.TailCall => true | Isa.Return => true | _ => false
  fun installs opc = #handlers (Vector.sub (info, opc)) = Isa.Installs
  fun removes opc = #handlers (Vector.sub (info, opc)) = Isa.Removes

  fun check (p : Rbc.program) : facts =
    let
      val instrs = decode p
      val n = Vector.length instrs
      val codeLen = String.size (#code p)
      val funcs = #funcs p
      (* the instruction that begins at a pc *)
      val index = Array.array (codeLen + 1, ~1)
      val () = Vector.appi (fn (i, {pc, ...} : instr) => Array.update (index, pc, i)) instrs
      (* the function of each instruction: both are in order of pc *)
      val nfuncs = Vector.length funcs
      val func = Array.array (n, 0)
      fun owner (i, f) =
        if i >= n then ()
        else
          let
            val pc = #pc (Vector.sub (instrs, i))
            fun advance f = if f + 1 < nfuncs andalso pc >= #offset (Vector.sub (funcs, f + 1)) then advance (f + 1) else f
            val f = advance f
          in
            Array.update (func, i, f);
            owner (i + 1, f)
          end
      val () = owner (0, 0)
      val height = Array.array (n, ~1)
      val depth = Array.array (n, ~1)
      val maxHeight = Array.array (Vector.length funcs, 0)

      fun name f = #name (Vector.sub (funcs, f))
      fun at (pc, f) = " at " ^ Int.toString pc ^ " in " ^ name f

      (* One function: the state at its entry is (0, 0), and every
         instruction a path reaches gets the state of the first path to
         reach it, which every other path must agree with. *)
      fun analyse (f, {offset, stop, ...} : Rbc.func) =
        let
          val () = if offset >= stop then refuse ("function " ^ name f ^ " has no code") else ()
          fun enter (i, h, d, from, work) =
            if Array.sub (height, i) < 0 then
              (Array.update (height, i, h); Array.update (depth, i, d); i :: work)
            else if Array.sub (height, i) <> h orelse Array.sub (depth, i) <> d then
              refuse ("the stack or the handlers differ on the paths into " ^ Int.toString (#pc (Vector.sub (instrs, i)))
                      ^ " (from " ^ Int.toString from ^ ") in " ^ name f)
            else work
          fun target (t, h, d, from, work) =
            if t < offset orelse t >= stop then refuse ("a jump leaves its function" ^ at (from, f))
            else enter (Array.sub (index, t), h, d, from, work)
          fun step (i, work) =
            let
              val ins as {pc, opc, a, ...} = Vector.sub (instrs, i)
              val h = Array.sub (height, i)
              val d = Array.sub (depth, i)
              val (pops, pushes) = effect ins
              val () = if pops > h then refuse ("the stack underflows" ^ at (pc, f)) else ()
              val h' = h - pops + pushes
              val () = if h' > Array.sub (maxHeight, f) then Array.update (maxHeight, f, h') else ()
              val () = if leaves opc andalso d > 0
                       then refuse ("a handler of the function is still installed" ^ at (pc, f)) else ()
              val () = if removes opc andalso d = 0
                       then refuse (Vector.sub (Opcodes.names, opc) ^ " without a handler of the function" ^ at (pc, f)) else ()
              val d' = if installs opc then d + 1 else if removes opc then d - 1 else d
              val work =
                if isJump opc then target (a, h', d', pc, work)
                else if installs opc then target (a, h + 1, d, pc, work)
                else work
            in
              if ends opc then work
              else if i + 1 >= n orelse #pc (Vector.sub (instrs, i + 1)) >= stop
              then refuse ("the code runs off the end of " ^ name f)
              else enter (i + 1, h', d', pc, work)
            end
          fun loop [] = ()
            | loop (i :: rest) = loop (step (i, rest))
          val first = Array.sub (index, offset)
        in
          Array.update (height, first, 0);
          Array.update (depth, first, 0);
          loop [first]
        end
      val () = Vector.appi analyse funcs

      (* the arguments each function is given: ~1 where nothing says yet *)
      val params = Array.array (nfuncs, ~1)
      fun give (f, k, pc) =
        if f < 0 orelse f >= nfuncs then ()
        else if Array.sub (params, f) < 0 orelse Array.sub (params, f) = k then Array.update (params, f, k)
        else refuse ("function " ^ name f ^ " is given " ^ Int.toString (Array.sub (params, f)) ^ " and "
                     ^ Int.toString k ^ " arguments (at " ^ Int.toString pc ^ ")")
      val () = if nfuncs > 0 then give (0, 1, 0) else ()
      val () =
        Vector.app (fn {pc, opc, a, b} =>
                      if opc = Opcodes.CALLK orelse opc = Opcodes.TAILCALLK then give (a, b, pc)
                      else if opc = Opcodes.CLOSURE then give (a, 1, pc)
                      else ())
                   instrs
    in
      {instrs = instrs,
       func = Array.vector func,
       height = Array.vector height,
       depth = Array.vector depth,
       maxHeight = Array.vector maxHeight,
       params = Vector.map (fn k => Int.max (k, 1)) (Array.vector params)}
    end
end
