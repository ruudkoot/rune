(* A unit's file, `.rbu` (docs/bytecode.md, *Units*; docs/units.md): its
   code as a program's file has it, numbered from 0, and what the linker
   needs beside it (Link.unitCode). `rune --emit-units` writes one per unit;
   the static linker reads them back into the code they were made from
   (read), so that a program linked from files is linked by Link as one
   compiled in units is, and is the same bytes. A unit names what units
   declared by keys (Link.key): in the file, the unit's identity, then those
   of the units it names, and each key by its unit's place among them, 0
   being the unit's own. *)
structure UnitFile =
struct
  open Code

  val magic = "RUNU"
  val version = 2

  (* the code kind: the bytecode of the instruction set the fingerprint
     names; native code will be another (docs/plans/incremental-compilation.md,
     D18) *)
  val bytecode = 0

  exception Bad of string

  (* ---- writing ---- *)

  (* The chunks of the file of a unit whose code is of the instruction set of
     fingerprint. *)
  fun chunks (fingerprint : int, u : Link.unitCode) : string list =
    let
      val u32 = Emit.u32
      val code = #code u
      val self = #identity u
      (* the units it names, in the order it first names them *)
      val keys = List.map #1 (#globals u) @ List.map #2 (#imports u)
      val named =
        List.rev (List.foldl (fn ({unit, ...} : Link.key, acc) =>
                                if unit = self orelse unit = "" orelse List.exists (fn x => x = unit) acc then acc
                                else unit :: acc) [] keys)
      fun place unit =
        if unit = self orelse unit = "" then 0
        else
          let fun go (_, []) = raise Bad "a unit not among those named"
                | go (i, x :: rest) = if x = unit then i else go (i + 1, rest)
          in go (1, named) end
      fun key ({unit, number} : Link.key) = u32 (place unit) ^ u32 number
      val globals = Array.array (#nglobals code, Link.nextKey)
      val () = List.app (fn (k, ix) => Array.update (globals, ix, k)) (#globals u)
    in
      [magic, u32 version, u32 fingerprint, u32 bytecode, Emit.str self,
       u32 (List.length named), String.concat (List.map Emit.str named)]
      @ Emit.sections code
      @ [String.concat (Array.foldr (fn (k, acc) => key k :: acc) [] globals),
         u32 (List.length (#imports u)), String.concat (List.map (fn (ix, k) => u32 ix ^ key k) (#imports u)),
         u32 (List.length (#exports u)), String.concat (List.map (fn (n, ix) => u32 n ^ u32 ix) (#exports u))]
    end

  fun write (path : string, fingerprint : int, u : Link.unitCode) : unit =
    let val out = BinIO.openOut path
    in
      List.app (fn s => BinIO.output (out, Byte.stringToBytes s)) (chunks (fingerprint, u));
      BinIO.closeOut out
    end

  (* ---- reading ---- *)

  type reader = {s : string, pos : int ref}

  fun need ({s, pos} : reader, n) = if n < 0 orelse !pos + n > String.size s then raise Bad "the file is cut short" else ()
  fun u8 (r as {s, pos} : reader) = (need (r, 1); Char.ord (String.sub (s, !pos)) before pos := !pos + 1)
  (* a number of four bytes, signed: a stamp may be negative (Link.next),
     and every other number is far below 2^30, which every host's int holds *)
  fun i32 r =
    let val a = u8 r val b = u8 r val c = u8 r val d = u8 r
    in
      if d >= 128 then a + 256 * (b + 256 * (c + 256 * (d - 256)))
      else if d >= 64 then raise Bad "a number out of range"
      else a + 256 * (b + 256 * (c + 256 * d))
    end
  fun count r = let val n = i32 r in if n < 0 then raise Bad "a negative count" else n end
  fun bytes (r as {s, pos} : reader, n) = (need (r, n); String.substring (s, !pos, n) before pos := !pos + n)
  fun str r = bytes (r, count r)
  val two64 = IntInf.pow (IntInf.fromInt 2, 64)
  val two63 = IntInf.pow (IntInf.fromInt 2, 63)
  fun u64 r = List.foldr (fn (b, acc) => IntInf.+ (IntInf.* (acc, IntInf.fromInt 256), IntInf.fromInt b))
                         (IntInf.fromInt 0) (List.tabulate (8, fn _ => u8 r))
  fun s64 r = let val v = u64 r in if IntInf.>= (v, two63) then IntInf.- (v, two64) else v end
  fun list (r, f) = List.tabulate (count r, fn _ => f r)

  (* the numbers of the line table and the frames, base 128 (Emit.uvar) *)
  fun uvar r =
    let
      fun go (shift, acc) =
        let val b = u8 r
        in if b < 128 then acc + b * shift else go (shift * 128, acc + (b - 128) * shift) end
    in go (1, 0) end
  fun svar r = let val v = uvar r in if v mod 2 = 0 then v div 2 else ~ ((v + 1) div 2) end

  (* SML's text of a real, which Emit wrote with C's minus signs *)
  fun realOf t = String.map (fn #"-" => #"~" | c => c) t

  fun const r : Lambda.const =
    case u8 r of
      0 => Lambda.CInt (s64 r)
    | 1 => Lambda.CWord (u64 r)
    | 2 => Lambda.CReal (realOf (str r))
    | 3 => Lambda.CString (str r)
    | 4 => Lambda.CChar (u8 r)
    | 5 => Lambda.CInt64 (s64 r)
    | 6 => Lambda.CWord64 (u64 r)
    | _ => raise Bad "a constant of no kind"

  (* The layout of the instructions of the set a fingerprint names: each
     opcode's operands by kind, and the operand that says how long its list
     is and whether it names a primitive (RegCodes, Opcodes). *)
  fun layout (fingerprint : int) =
    if fingerprint = RegCodes.fingerprint then
      {kinds = RegCodes.operandKinds, listAt = RegCodes.listAt, listPrim = RegCodes.listPrim,
       label = RegCodes.kindLabel, handler = RegCodes.kindHandlerLabel}
    else if fingerprint = Opcodes.fingerprint then
      {kinds = Opcodes.operandKinds, listAt = Vector.map (fn _ => ~1) Opcodes.operandKinds,
       listPrim = Vector.map (fn _ => false) Opcodes.operandKinds,
       label = RegCodes.kindLabel, handler = RegCodes.kindHandlerLabel}
    else raise Bad "the code of another instruction set"

  val primArity : int vector =
    let val n = List.foldl (fn ((_, i, _), m) => Int.max (m, i + 1)) 0 Prims.table
    in Vector.tabulate (n, fn i =>
         List.foldl (fn ((_, k, arity), found) => if k = i then arity else found) 0 Prims.table) end

  (* A unit's file read back: the instruction set it is of, and the unit, its
     code as the target made it -- every instruction an Ops of its operands,
     a jump's target a label again, the positions and the representations
     where they were. *)
  fun read (s : string) : int * Link.unitCode =
    let
      val r = {s = s, pos = ref 0}
      val () = if bytes (r, 4) = magic then () else raise Bad "not a unit of Rune bytecode"
      val () = if i32 r = version then () else raise Bad "a unit of another version"
      val fingerprint = i32 r
      val () = if i32 r = bytecode then () else raise Bad "a unit of another kind of code"
      val self = str r
      val named = Vector.fromList (list (r, str))
      fun unitAt i = if i = 0 then self else Vector.sub (named, i - 1) handle Subscript => raise Bad "a unit out of range"
      fun key r = let val i = count r in {unit = unitAt i, number = i32 r} : Link.key end
      val {kinds, listAt, listPrim, label, handler} = layout fingerprint
      val consts = list (r, const)
      val nglobals = count r
      val funcs = list (r, fn r => let val off = count r val nlocals = count r in (off, nlocals, str r) end)
      val codeLen = count r
      val codeAt = !(#pos r)
      val () = need (r, codeLen)
      val () = #pos r := codeAt + codeLen
      val files = list (r, str)
      val nlines = count r
      val tableLen = count r
      val tableEnd = !(#pos r) + tableLen
      val lines =
        let
          fun go (0, _, acc) = List.rev acc
            | go (n, (pc, f, l, c, i), acc) =
                let val e = (pc + uvar r, f + svar r, l + svar r, c + svar r, i + svar r)
                in go (n - 1, e, e :: acc) end
        in go (nlines, (0, 0, 0, 0, 0), []) end
      val () = if !(#pos r) = tableEnd then () else raise Bad "the line table"
      val names = Vector.fromList (list (r, str))
      val ninlines = count r
      val framesLen = count r
      val framesEnd = !(#pos r) + framesLen
      val inlines =
        List.tabulate (ninlines, fn _ =>
                         let val n = uvar r val f = uvar r val l = uvar r val c = uvar r val p = uvar r
                         in (Vector.sub (names, n), f, l, c, p) end)
                      handle Subscript => raise Bad "the frames of inlined functions"
      val () = if !(#pos r) = framesEnd then () else raise Bad "the frames of inlined functions"
      val nmeta = count r
      val metas =
        List.tabulate (nmeta, fn _ =>
                         let
                           val arity = count r
                           val reps = list (r, u8)
                           val blocks = list (r, fn r => let val pc = count r in (pc, list (r, count)) end)
                           val loops = list (r, count)
                         in (arity, reps, blocks, loops) end)
      val globals = List.tabulate (nglobals, fn _ => key r)
      val imports = list (r, fn r => let val ix = count r
                                     in case key r of
                                          {unit, number = ~1} => (ix, if unit = self then Link.nextKey else raise Bad "an import")
                                        | k => (ix, k)
                                     end)
      val exports = list (r, fn r => let val n = count r in (n, count r) end)
      val () = if !(#pos r) = String.size s then () else raise Bad "more after the unit"

      (* the code, decoded: each instruction's opcode and operands *)
      fun byte pc = Char.ord (String.sub (s, codeAt + pc))
      (* an operand, signed: an immediate may be negative, and the
         compiler keeps every one within 2^30 (Regs.int32Max) *)
      fun word pc =
        let val a = byte pc val b = byte (pc + 1) val c = byte (pc + 2) val d = byte (pc + 3)
        in
          if d >= 128 then a + 256 * (b + 256 * (c + 256 * (d - 256)))
          else if d >= 64 then raise Bad "an operand out of range"
          else a + 256 * (b + 256 * (c + 256 * d))
        end
      fun decode pc : int * (int * int) list * int =
        let
          val opc = byte pc
          val ks = Vector.sub (kinds, opc) handle Subscript => raise Bad "no such instruction"
          val fixed = List.tabulate (List.length ks, fn i => (List.nth (ks, i), word (pc + 1 + 4 * i)))
          val at = Vector.sub (listAt, opc)
          val n =
            if at < 0 then 0
            else
              let val v = #2 (List.nth (fixed, at))
              in if Vector.sub (listPrim, opc) then Vector.sub (primArity, v) handle Subscript => raise Bad "no such primitive" else v end
          val start = pc + 1 + 4 * List.length ks
          val rest = List.tabulate (n, fn i => (~1, word (start + 4 * i)))
        in (opc, fixed @ rest, start + 4 * n) end
        handle Subscript => raise Bad "an instruction cut short"
      fun isLabel k = k = label orelse k = handler
      (* every place a label names: a jump's target, a block's or a loop's
         head; numbered in order *)
      val ends = List.map #1 (List.tl funcs) @ [codeLen] handle Empty => []
      val targets =
        let
          fun scan (pc, stop, acc) =
            if pc >= stop then acc
            else
              let val (_, ops, next) = decode pc
              in scan (next, stop, List.foldl (fn ((k, v), acc) => if isLabel k then IntMap.insert (acc, v, ()) else acc) acc ops) end
          val m = ListPair.foldl (fn ((off, _, _), stop, acc) => scan (off, stop, acc)) IntMap.empty (funcs, ends)
          val m = List.foldl (fn ((_, _, blocks, loops), m) =>
                                List.foldl (fn (pc, m) => IntMap.insert (m, pc, ()))
                                           (List.foldl (fn ((pc, _), m) => IntMap.insert (m, pc, ())) m blocks) loops)
                             m metas
        in #2 (IntMap.foldli (fn (pc, _, (n, acc)) => (n + 1, IntMap.insert (acc, pc, n))) (0, IntMap.empty) m) end
      fun labelAt pc = case IntMap.find (targets, pc) of SOME l => l | NONE => raise Bad "a label of no place"
      (* the positions, by the pc they begin at, in order *)
      val positions =
        List.foldr (fn ((pc, f, l, c, i), m) => IntMap.insert (m, pc, Pos (f, l, c, i) :: (case IntMap.find (m, pc) of SOME ps => ps | NONE => [])))
                   IntMap.empty lines
      fun items (pc, stop) =
        if pc >= stop then []
        else
          let
            val (opc, ops, next) = decode pc
            val lab = case IntMap.find (targets, pc) of SOME l => [Lab l] | NONE => []
            val pos = case IntMap.find (positions, pc) of SOME ps => ps | NONE => []
            val ins = Ops (opc, List.map (fn (k, v) => if isLabel k then L (labelAt v) else I v) ops)
          in lab @ pos @ ins :: items (next, stop) end
      val metaOf =
        if nmeta = 0 then (fn _ => NONE)
        else if nmeta <> List.length funcs then raise Bad "the representations section"
        else
          let val ms = Vector.fromList metas
          in fn i =>
               let val (arity, reps, blocks, loops) = Vector.sub (ms, i)
               in SOME {arity = arity, reps = reps, blocks = List.map (fn (pc, ps) => (labelAt pc, ps)) blocks,
                        loops = List.map labelAt loops} end
          end
      val funcs' =
        ListPair.map (fn (((off, nlocals, name), stop), i) =>
                        {id = i, nlocals = nlocals, code = items (off, stop), name = name, meta = metaOf i})
                     (ListPair.zip (funcs, ends), List.tabulate (List.length funcs, fn i => i))
      val code = {consts = consts, nglobals = nglobals, funcs = funcs', files = files, inlines = inlines,
                  nlabels = IntMap.numItems targets}
    in
      (fingerprint,
       {code = code, identity = self, globals = ListPair.zip (globals, List.tabulate (nglobals, fn i => i)),
        imports = imports, exports = exports})
    end
    handle Subscript => raise Bad "the file is cut short"

  (* u with the source the files of its code name old named new: a unit
     from the cache whose source has moved *)
  fun mapFiles ({code = {consts, nglobals, funcs, files, inlines, nlabels}, identity, globals, imports, exports}
                : Link.unitCode, f : string -> string) : Link.unitCode =
    {code = {consts = consts, nglobals = nglobals, funcs = funcs, files = List.map f files,
             inlines = inlines, nlabels = nlabels},
     identity = identity, globals = globals, imports = imports, exports = exports}

  fun renameFile (u : Link.unitCode, old : string, new : string) : Link.unitCode =
    mapFiles (u, fn f => if f = old then new else f)

  fun readFile (path : string) : int * Link.unitCode =
    let
      val inp = BinIO.openIn path
      val s = Byte.bytesToString (BinIO.inputAll inp) before BinIO.closeIn inp
    in read s handle Bad why => raise Bad (path ^ ": " ^ why) end
end
