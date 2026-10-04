(* The translation of a program into x86-64 assembly, for the GNU assembler
   (docs/native.md). Every instruction becomes the code that does what its
   case in runtime/stack/interp.c does, in the order of the bytecode: nothing is
   dropped, merged or moved. The value stack, the frames and the handlers
   are the interpreter's; the code keeps four things in registers:

     r12  the VM
     r13  vm->stack, reloaded after every call into C
     rbp  the base of the current frame in bytes (the size of a value times
          its index), reloaded where the frame changes (a function's entry,
          a return, a handler)
     r15  the count of instructions executed, written to the VM before
          anything that can read it (docs/native.md, Counting)

   The height of the stack before every instruction is known (RbcCheck), so
   a slot is an address in the frame, and vm->sp is written only before a
   call into C. A call and a return push and pop the VM's frame here, and an
   allocation bumps the heap here, with runtime/native/native.c as the slow path, which
   answers with the native code to jump to; a raise goes through
   runtime/native/native.c, and a primitive is a call through prim_table unless its
   common case is done here (fastPrim). The offsets and numbers of the VM's
   layout are names that rune-offsets.s, made from runtime/vm.h, defines. *)
structure X64 =
struct
  structure L = X64Layout
  (* A number as the assembler writes it. *)
  fun num (n : int) : string = Rbc.minus (Int.toString n)

  fun lab (pc : int) : string = ".Lp" ^ Int.toString pc

  (* A string the assembler reads between quotes. *)
  fun quote (s : string) : string =
    "\"" ^ String.translate (fn #"\"" => "\\\"" | #"\\" => "\\\\" | #"\n" => "\\n" | c => String.str c) s ^ "\""

  (* The symbol of function f: its name and its index, since names repeat. *)
  fun symbol (name : string, f : int) : string = quote (name ^ "#" ^ Int.toString f)

  (* The instructions after which a straight run of code ends, and with it
     what the counter adds at once (docs/native.md, Counting). *)
  fun endsRun opc = Isa.endsRun (Vector.sub (RbcCheck.info, opc))

  (* The numbers the checks of the code give native_fatal, which has the
     messages of runtime/stack/interp.c. *)
  val fatalTuple = 0 val fatalCon = 1 val fatalExn = 2 val fatalEnv = 3 val fatalSelf = 4
  val fatalGlobal = 5 val fatalSelect = 6 val fatalContag = 7 val fatalJumpIfNot = 8
  val fatalJumpIf = 9 val fatalPopHandler = 10 val fatalJumpIfNotTag = 11 val fatalSwitch = 12
  val fatalDecon = 13 val fatalFields = 14 val fatalField = 15 val fatalFieldTag = 16

  val primNames : string vector = Vector.fromList (List.map #1 Prims.table)
  (* The description of each primitive (src/isa/prims.sml), by its number. *)
  val primInfo : Isa.primitive vector = Vector.fromList PrimIsa.primitives

  (* The primitives whose common case the code does itself (docs/native.md,
     Primitives done inline). A PRIM of
     one of them checks that its arguments are immediates (or objects of
     the kind, in bounds) and does the operation; anything else -- a value
     of another shape, a box, an overflow, a divisor of zero, an index out of
     bounds, a pointer for poly_eq -- goes to `slow`, where the primitive of runtime/prims.c is
     called as it is for any other, and raises or stops as it does. So a
     program cannot tell the one from the other, and a PRIM still counts as
     one instruction. The arguments are at heights h - arity .. h - 1, the
     last on top, and the result goes where the first was. tests/opt runs
     every one of them on its edge cases (prims.sml), natively and on runevm-stack,
     and runeopt --inlined lists them. *)
  fun fastPrim (name : string, h : int, pc : int,
                {line, put, sd} : {line : string -> unit, put : string -> unit, sd : int -> string})
      : (string -> unit) option =
    let
      val x = h - 2
      val y = h - 1
      val l = ".Lp" ^ Int.toString pc
      (* every touch of a value or an object is a template of X64Layout (M3
         of docs/plans/heap-layout.md), as the JIT's emitters are written
         over its macro-assembler: sd k is the displacement text of stack
         slot k, RAX and RCX the registers the JIT's tier 1 uses. A value is
         one word (M4). The operands of an int's, a word's or a char's
         arithmetic come into %rax and %rcx in the form the arithmetic is
         done in (twoInt, oneWord ...: their words where an int is 63 bits,
         their 64 bits where the VM keeps 64, a box read in line), the
         arithmetic templates work in that form, and the result goes from
         it to its slot (setInt, setWord, setChar), or from a payload
         (setPayInt, setPayWord: a quotient, a shifted word); `slow` is
         where the form has no word for a slot, or an operand is neither an
         immediate nor a box. The templates clobber %rdx, and the reals'
         %r8. *)
      fun imm ks slow = List.app (fn k => L.checkImm line (sd k, slow)) ks
      fun bool (setcc, k) =
        (line (setcc ^ " %al"); line "movzbl %al, %eax";
         L.setImm line (sd k, L.RAX))
      fun obj (k, kind) slow = L.loadObj line (L.RAX, sd k, kind, slow)
      (* the index at k into %rcx, when it is below the length of the object in %rax *)
      fun index k slow =
        (imm [k] slow;
         L.loadPayload line (L.RCX, sd k); L.loadLen line (L.RDX, L.RAX);
         line "cmp %rdx, %rcx"; line ("jae " ^ slow))
      (* the two operands of an int's, a word's or a char's arithmetic into
         %rax and %rcx, and the one; and the result's way to its slot *)
      datatype num = INT | WORD | CHAR
      fun two num slow =
        (case num of INT => L.twoInt | WORD => L.twoWord | CHAR => L.twoChar) line (sd x, sd y, slow, l ^ "_x")
      fun one num slow =
        (case num of INT => L.oneInt | WORD => L.oneWord | CHAR => L.oneChar) line (sd y, slow, l ^ "_x")
      fun set num (k, r) slow =
        (case num of INT => L.setInt | WORD => L.setWord | CHAR => L.setChar) line (sd k, r, slow)
      fun arith (num, template) =
        SOME (fn slow => (two num slow; template line slow; set num (x, L.RAX) slow))
      fun unary (from, template, to) =
        SOME (fn slow => (one from slow; template line slow; set to (y, L.RAX) slow))
      (* the form compares as the numbers do: signed for an int and a char,
         unsigned for a word *)
      fun compare (num, setcc) =
        SOME (fn slow => (two num slow; line "cmp %rcx, %rax"; bool (setcc, x)))
      (* LESS, EQUAL or GREATER, the nullary constructors 0, 1 and 2: the sum
         of x >= y and x > y *)
      fun order (num, ge, gt) =
        SOME (fn slow =>
          (two num slow; line "cmp %rcx, %rax";
           line (ge ^ " %al"); line (gt ^ " %cl"); line "movzbl %al, %eax"; line "movzbl %cl, %ecx";
           line "add %rcx, %rax";
           L.setImm line (sd x, L.RAX)))
      (* the two real operands into %xmm0 and %xmm1: an immediate decoded,
         a box read *)
      fun twoReal (first, second) slow =
        (L.loadReal line (sd first, slow, l ^ "_x"); L.loadReal1 line (sd second, slow, l ^ "_y"))
      (* ucomisd sets `above` only for an ordered pair, so a NaN compares false *)
      fun realCompare (first, second, setcc) =
        SOME (fn slow => (twoReal (first, second) slow; line "ucomisd %xmm1, %xmm0"; bool (setcc, x)))
      (* a result with no immediate is a box, which the primitive makes *)
      fun real ins =
        SOME (fn slow => (twoReal (x, y) slow; line (ins ^ " %xmm1, %xmm0"); L.setReal line (sd x, slow, l ^ "_z")))
      (* quotient in %rax and remainder in %rdx of C's truncating division; a
         divisor of 0 or ~1 (where the quotient may overflow) is the
         primitive's. Neither is past the dividend, so both have immediates. *)
      fun intDivide finish =
        SOME (fn slow =>
          (two INT slow;
           L.untagInt line L.RCX;
           line "test %rcx, %rcx"; line ("jz " ^ slow);
           line "cmp $-1, %rcx"; line ("je " ^ slow);
           L.untagInt line L.RAX; line "cqo"; line "idiv %rcx";
           finish slow))
      (* the quotient in %rax; the remainder moved there from %rdx, which
         giving a slot its word uses *)
      fun wordDivide remainder =
        SOME (fn slow =>
          (two WORD slow;
           L.untagWord line L.RCX;
           line "test %rcx, %rcx"; line ("jz " ^ slow);
           L.untagWord line L.RAX; line "xor %edx, %edx"; line "div %rcx";
           if remainder then line "mov %rdx, %rax" else ();
           L.setPayWord line (sd x, L.RAX, slow)))
      (* a shift by 64 or more gives 0; a result past what a word's
         immediate holds is the primitive's *)
      fun shift ins =
        SOME (fn slow =>
          (two WORD slow;
           L.untagWord line L.RCX; L.untagWord line L.RAX;
           line "cmp $64, %rcx"; line ("jb " ^ l ^ "_s");
           line "xor %eax, %eax"; line ("jmp " ^ l ^ "_t");
           put (l ^ "_s:\n"); line (ins ^ " %cl, %rax");
           put (l ^ "_t:\n"); L.setPayWord line (sd x, L.RAX, slow)))
      fun length kind =
        SOME (fn slow =>
          (obj (y, kind) slow;
           L.loadLen line (L.RAX, L.RAX);
           L.setImm line (sd y, L.RAX)))
    in
      case name of
        "int_add" => arith (INT, L.intAdd)
      | "int_sub" => arith (INT, L.intSub)
      | "int_mul" => arith (INT, L.intMul)
      | "int_neg" => unary (INT, L.intNeg, INT)
      | "int_quot" => intDivide (fn slow => L.setPayInt line (sd x, L.RAX, slow))
      | "int_rem" => intDivide (fn slow => (line "mov %rdx, %rax"; L.setPayInt line (sd x, L.RAX, slow)))
      | "int_div" =>
          (* floor: one less where there is a remainder and the signs differ *)
          intDivide (fn slow =>
            (line "test %rdx, %rdx"; line ("jz " ^ l ^ "_f");
             line "xor %rcx, %rdx"; line ("jns " ^ l ^ "_f");
             line "dec %rax";
             put (l ^ "_f:\n"); L.setPayInt line (sd x, L.RAX, slow)))
      | "int_mod" =>
          (* the sign of the divisor: the divisor added where they differ *)
          intDivide (fn slow =>
            (line "test %rdx, %rdx"; line ("jz " ^ l ^ "_f");
             line "mov %rdx, %r8"; line "xor %rcx, %r8"; line ("jns " ^ l ^ "_f");
             line "add %rcx, %rdx";
             put (l ^ "_f:\n"); line "mov %rdx, %rax"; L.setPayInt line (sd x, L.RAX, slow)))
      | "int_lt" => compare (INT, "setl")
      | "int_le" => compare (INT, "setle")
      | "int_gt" => compare (INT, "setg")
      | "int_ge" => compare (INT, "setge")
      | "int_order" => order (INT, "setge", "setg")
      | "word_add" => arith (WORD, L.wordAdd)
      | "word_sub" => arith (WORD, L.wordSub)
      | "word_mul" => arith (WORD, L.wordMul)
      | "word_andb" => arith (WORD, L.wordAnd)
      | "word_orb" => arith (WORD, L.wordOr)
      | "word_xorb" => arith (WORD, L.wordXor)
      | "word_notb" => unary (WORD, L.wordNot, WORD)
      | "word_div" => wordDivide false
      | "word_mod" => wordDivide true
      | "word_lsl" => shift "shl"
      | "word_lsr" => shift "shr"
      | "word_lt" => compare (WORD, "setb")
      | "word_le" => compare (WORD, "setbe")
      | "word_gt" => compare (WORD, "seta")
      | "word_ge" => compare (WORD, "setae")
      | "word_order" => order (WORD, "setae", "seta")
      | "char_lt" => compare (CHAR, "setl")
      | "char_le" => compare (CHAR, "setle")
      | "char_gt" => compare (CHAR, "setg")
      | "char_ge" => compare (CHAR, "setge")
      | "char_order" => order (CHAR, "setge", "setg")
        (* a char's code as an int *)
      | "char_ord" => SOME (fn slow => (one CHAR slow; set INT (y, L.RAX) slow))
      | "real_add" => real "addsd"
      | "real_sub" => real "subsd"
      | "real_mul" => real "mulsd"
      | "real_div" => real "divsd"
      | "real_neg" =>
          SOME (fn slow =>
            (L.loadReal line (sd y, slow, l ^ "_x");
             line "movq %xmm0, %rax"; line "btc $63, %rax"; line "movq %rax, %xmm0";
             L.setReal line (sd y, slow, l ^ "_z")))
      | "real_lt" => realCompare (y, x, "seta")
      | "real_le" => realCompare (y, x, "setae")
      | "real_gt" => realCompare (x, y, "seta")
      | "real_ge" => realCompare (x, y, "setae")
      | "real_eq" =>
          SOME (fn slow =>
            (twoReal (x, y) slow; line "ucomisd %xmm1, %xmm0";
             line "sete %al"; line "setnp %cl"; line "and %cl, %al"; line "movzbl %al, %eax";
             L.setImm line (sd x, L.RAX)))
      | "poly_eq" =>
          (* values_equal of two immediates: their words; anything in the
             heap -- an object, a box -- is the primitive's *)
          SOME (fn slow => (L.twoWords line (sd x, sd y, slow); line "cmp %rcx, %rax"; bool ("sete", x)))
      | "imm_eq" =>
          (* two values the compiler knows are never objects: their words,
             but where one is a box (an int or a word past 63 bits), which
             is the primitive's *)
          SOME (fn slow => (L.twoWords line (sd x, sd y, slow); line "cmp %rcx, %rax"; bool ("sete", x)))
      | "ref_get" => SOME (fn slow => (obj (y, "K_REF") slow; L.loadField line (sd y, L.RAX, 0)))
      | "ref_set" =>
          SOME (fn slow =>
            (obj (x, "K_REF") slow;
             L.storeField line (L.RAX, 0, sd y);
             L.set line (sd x, 0)))
      | "word_to_int" => unary (WORD, L.wordToInt, INT)
      | "word_to_int_x" => unary (WORD, L.wordToIntX, INT)
      | "word_from_int" => unary (INT, L.intToWord, WORD)
      | "int_to_char" => unary (INT, L.intToChar, CHAR)
      | "vector_length" => length "K_TUPLE"
      | "vector_sub" =>
          SOME (fn slow =>
            (obj (x, "K_TUPLE") slow; index y slow;
             L.element line (); L.loadField line (sd x, L.RAX, 0)))
      | "string_size" => length "K_STRING"
      | "array_length" => length "K_ARRAY"
      | "string_sub" =>
          SOME (fn slow =>
            (obj (x, "K_STRING") slow; index y slow;
             L.stringByte line ();
             L.setImm line (sd x, L.RCX)))
      | "array_sub" =>
          SOME (fn slow =>
            (obj (x, "K_ARRAY") slow; index y slow;
             L.element line (); L.loadField line (sd x, L.RAX, 0)))
      | "array_update" =>
          SOME (fn slow =>
            (obj (h - 3, "K_ARRAY") slow; index (h - 2) slow;
             L.element line (); L.storeField line (L.RAX, 0, sd (h - 1));
             L.set line (sd (h - 3), 0)))
      | _ => NONE
    end

  (* The names of the primitives fastPrim does inline, for runeopt --inlined. *)
  val silent = {line = fn _ : string => (), put = fn _ : string => (), sd = fn _ : int => ""}
  val inlined : string list = List.filter (fn n => isSome (fastPrim (n, 3, 0, silent))) (Vector.foldr op:: [] primNames)

  fun write (put : string -> unit, p : Rbc.program, facts : RbcCheck.facts,
             {rbc : string, rbcSize : int, options : string}) : unit =
    let
      val instrs = #instrs facts
      val n = Vector.length instrs
      val funcs = #funcs p
      val nfuncs = Vector.length funcs
      val codeLen = String.size (#code p)
      fun ins i = Vector.sub (instrs, i)
      fun line s = put ("\t" ^ s ^ "\n")

      (* the instruction at each pc, and what else reaches it *)
      val index = Array.array (codeLen + 1, ~1)
      val () = Vector.appi (fn (i, {pc, ...} : RbcCheck.instr) => Array.update (index, pc, i)) instrs
      val target = Array.array (n, false)
      val handler = Array.array (n, false)
      val () =
        Vector.app
          (fn {opc, a, ...} : RbcCheck.instr =>
             if RbcCheck.isJump opc then Array.update (target, Array.sub (index, a), true)
             else if RbcCheck.installs opc then Array.update (handler, Array.sub (index, a), true)
             else ())
          instrs
      fun reachable i = Vector.sub (#height facts, i) >= 0
      fun afterCall i =
        i > 0 andalso #flow (Vector.sub (RbcCheck.info, #opc (ins (i - 1)))) = Isa.Call andalso reachable (i - 1)

      (* The places an image can stop at, by pc, with the native code that
         carries on there (M9): the instruction after a CALL, where a frame
         returns to, and after a primitive that writes an image, where the
         world that saved itself starts again. *)
      val resumes : (int * string) list ref = ref []
      fun imagePrim a = Isa.hasEffect (Vector.sub (primInfo, a), Isa.SavesImage)

      (* the line table, as .loc where an entry begins *)
      val lineStarts = Array.array (codeLen + 1, ~1)
      val () = Vector.appi (fn (k, {pc, ...} : Rbc.line) => Array.update (lineStarts, pc, k)) (#lines p)

      fun loc k =
        let val {file, line = l, col, ...} = Vector.sub (#lines p, k)
        in line (".loc " ^ Int.toString (file + 1) ^ " " ^ Int.toString l ^ " " ^ Int.toString col) end

      (* The frame every function runs in, which is rune_enter's: the code
         pushes nothing, so the frame's address is always rsp + 64, and the
         registers of the caller of rune_enter are where it put them. A
         debugger unwinds from any function to main so. *)
      fun cfiFrame () =
        (line ".cfi_startproc";
         line ".cfi_def_cfa_offset 64";
         List.app (fn (r, off) => line (".cfi_offset %" ^ r ^ ", " ^ num off))
           [("rbp", ~16), ("rbx", ~24), ("r12", ~32), ("r13", ~40), ("r14", ~48), ("r15", ~56)])

      (* ---- pieces of the templates ---- *)
      val reloadStack = "mov VM_STACK(%r12), %r13"
      fun reloadFrame () =
        (line reloadStack;
         line "mov VM_FRAMES(%r12), %rax";
         line "mov VM_FP(%r12), %rcx";
         line "imul $FRAME_SIZE, %rcx, %rcx";
         line "mov FRAME_BASE(%rax,%rcx), %rbp";
         line ("shl $" ^ Int.toString L.valueShift ^ ", %rbp"))
      fun closureToRax () =
        (line "mov VM_FRAMES(%r12), %rax";
         line "mov VM_FP(%r12), %rcx";
         line "imul $FRAME_SIZE, %rcx, %rcx";
         line "mov FRAME_CLOSURE(%rax,%rcx), %rax")

      fun function (f, {offset, stop, nlocals, name} : Rbc.func) =
        let
          val sym = symbol (name, f)
          val fatals : (string * int * int * int) list ref = ref []
          (* the calls of the primitives whose common case is done inline *)
          val slows : (unit -> unit) list ref = ref []
          val first = Array.sub (index, offset)
          fun lastOf i = if i + 1 < n andalso #pc (ins (i + 1)) < stop then lastOf (i + 1) else i
          val last = lastOf first
          (* the displacements of stack slot k and local l, and their operands (M3: X64Layout) *)
          fun sd k = L.slotDisp (nlocals + k)
          fun ld l = L.slotDisp l
          fun slot k = sd k ^ "(%r13,%rbp)"
          fun localSlot l = ld l ^ "(%r13,%rbp)"
          fun copy (from, to) = L.copyMem line (from, to)
          (* an immediate of payload value, and unit, which is one *)
          fun put0 (value, k) =
            if value >= L.setMin andalso value <= L.setMax then L.set line (sd k, value)
            else L.setWide line (sd k, value)
          fun putUnit k = L.set line (sd k, 0)
          fun putPtr k = L.setBits line (sd k, L.RAX)
          (* M11: an object of n > 0 fields, its header written, in rax, by
             bumping heap_used as vm_alloc does, with the same counts; to
             `slow` when it does not fit or --gc-stress is on, which is
             vm_alloc's to decide. The fields are the caller's to write. *)
          fun alloc (kind, contag, n, slow) = L.alloc line (kind, contag, n, slow)
          (* the fields of the object in rax: k from stack slot s, or an immediate *)
          fun storeField (k, s) = L.storeField line (L.RAX, k, s)
          fun field k = L.fieldDisp k ^ "(%rax)"
          (* an index of the stack in units of the frame's base (rbp), from a displacement *)
          fun shiftIndex r = line ("shr $" ^ Int.toString L.valueShift ^ ", " ^ r)
          fun startsRun i =
            i = first orelse endsRun (#opc (ins (i - 1))) orelse Array.sub (target, i) orelse Array.sub (handler, i)
          fun runLength i =
            let fun go j = if j > last orelse startsRun j then j - i else go (j + 1)
            in go (i + 1) end
          (* M15: the value a LOCAL pushed, while it is still only in the
             local: its height and the local. A LOCAL leaves it there when
             the instruction after it, in the same run, reads the top of the
             stack and does not write it in place, and calls into C only on
             a slow path, which copies it to its slot first; everything else
             finds the value in its slot, as before. Nothing between the two
             writes a local, so the local still holds the value. *)
          val pending : (int * int) option ref = ref NONE
          fun reads ({opc, a, b, ...} : RbcCheck.instr) =
            opc = Opcodes.SETLOCAL orelse opc = Opcodes.SETGLOBAL orelse opc = Opcodes.SELECT
            orelse opc = Opcodes.DECON orelse opc = Opcodes.EXNCON orelse opc = Opcodes.EXNARG
            orelse opc = Opcodes.JUMPIFNOT orelse opc = Opcodes.JUMPIF orelse opc = Opcodes.JUMPIFNOTTAG
            orelse opc = Opcodes.SWITCH
            orelse opc = Opcodes.CALL orelse opc = Opcodes.TAILCALL orelse opc = Opcodes.RET
            orelse (opc = Opcodes.TUPLE andalso a > 0) orelse opc = Opcodes.CON orelse opc = Opcodes.MKEXN
            orelse (opc = Opcodes.CLOSURE andalso b > 0)
            orelse (opc = Opcodes.PRIM andalso Vector.sub (RbcCheck.arity, a) >= 2
                    andalso isSome (fastPrim (Vector.sub (primNames, a), 3, 0, silent)))
          (* and the next instruction has no position of its own, which would
             take the place of the LOCAL's in the line table *)
          fun forwards i =
            i + 1 <= last andalso not (startsRun (i + 1)) andalso reads (ins (i + 1))
            andalso Array.sub (lineStarts, #pc (ins (i + 1))) = ~1
          (* a check that fails: the code of native_fatal's message *)
          fun fatalLabel (pc, k) = ".Lf" ^ Int.toString pc ^ "_" ^ Int.toString k
          fun check (pc, next, what, arg) =
            let val l = fatalLabel (pc, List.length (!fatals))
            in fatals := (l, next, what, arg) :: !fatals; l end

          fun instruction i =
            let
              val {pc, opc, a, b} = ins i
              val h = Vector.sub (#height facts, i)
              val next = pc + Rbc.instrLength opc
              (* M15: where this instruction reads its operands: the top from
                 the local a LOCAL left it in, if it did; and the copy to its
                 slot that the slow paths make before they call into C *)
              val fwd = !pending
              val () = pending := NONE
              fun rsd k = case fwd of SOME (k', l) => if k = k' then ld l else sd k | NONE => sd k
              fun rslot k = rsd k ^ "(%r13,%rbp)"
              fun unforward () = case fwd of SOME (k, l) => L.copy line (sd k, ld l) | NONE => ()
              fun flushSp () =
                (line ("lea " ^ sd h ^ "(%rbp), %rax");
                 shiftIndex "%rax";
                 line "mov %rax, VM_SP(%r12)")
              fun setPc () = line ("movl $" ^ num next ^ ", VM_PC(%r12)")
              fun flushCount () = line "mov %r15, VM_INSTRUCTIONS(%r12)"
              fun callC (fname, args) = (line "mov %r12, %rdi"; List.app line args; line ("call " ^ fname))
              (* M11: an instruction that allocates, inline, and its helper,
                 which collects, out of line *)
              fun inlineAlloc (fast, helper) =
                let val slow = lab pc ^ "_slow" val done = lab pc ^ "_done"
                in
                  fast slow;
                  put (done ^ ":\n");
                  slows := (fn () => (put (slow ^ ":\n"); unforward (); flushSp (); setPc (); helper ();
                                      line reloadStack; line ("jmp " ^ done))) :: !slows
                end
              fun expectObj (k, kind, what) = L.loadObj line (L.RAX, rsd k, kind, check (pc, next, what, 0))
              val () = put (lab pc ^ ":\t# " ^ Vector.sub (Opcodes.names, opc)
                            ^ (case Vector.sub (Opcodes.nargs, opc) of 0 => "" | 1 => " " ^ num a | _ => " " ^ num a ^ " " ^ num b)
                            ^ "\n")
              val () = case Array.sub (lineStarts, pc) of ~1 => () | k => loc k
              (* CALL and TAILCALL, and JUMPIFNOT and JUMPIF, share a template *)
              fun callTemplate () =
                (* M10: the closure checked, its function index in range, the
                   frame pushed (or, for TAILCALL, kept), the argument moved
                   to the callee's local 0, where the closure was, and a jump
                   to the callee's fast entry; anything else, and a full
                   array of frames, is the glue's (native_call and
                   native_tailcall), as before M10. *)
                let
                  val slow = lab pc ^ "_slow"
                  val tail = opc = Opcodes.TAILCALL
                  val newBase = sd (h - 2)
                in
                  L.loadObj line (L.RAX, sd (h - 2), "K_CLOSURE", slow);
                  L.loadFieldPayload line (L.RCX, L.RAX, 0);
                  line ("cmp $" ^ num nfuncs ^ ", %rcx");
                  line ("jae " ^ slow);
                  if tail then
                    (line "mov VM_FRAMES(%r12), %rdx";
                     line "mov VM_FP(%r12), %rsi";
                     line "imul $FRAME_SIZE, %rsi, %rsi";
                     line "add %rsi, %rdx";
                     line "mov %ecx, FRAME_FUNC(%rdx)";
                     line "mov %rax, FRAME_CLOSURE(%rdx)";
                     L.copy line (ld 0, rsd (h - 1)))
                  else
                    (line "mov VM_FP(%r12), %rdx";
                     line "add $1, %rdx";
                     line "cmp VM_FRAMES_CAP(%r12), %rdx";
                     line ("jae " ^ slow);
                     line "mov %rdx, VM_FP(%r12)";
                     line "imul $FRAME_SIZE, %rdx, %rdx";
                     line "add VM_FRAMES(%r12), %rdx";
                     line "mov %ecx, FRAME_FUNC(%rdx)";
                     line ("movl $" ^ num next ^ ", FRAME_RET_PC(%rdx)");
                     line ("lea " ^ newBase ^ "(%rbp), %rsi");
                     shiftIndex "%rsi";
                     line "mov %rsi, FRAME_BASE(%rdx)";
                     line "mov %rax, FRAME_CLOSURE(%rdx)";
                     line ("lea " ^ lab next ^ "(%rip), %rsi");
                     line "mov %rsi, FRAME_NATIVE_RET(%rdx)";
                     L.copy line (sd (h - 2), rsd (h - 1));
                     line ("lea " ^ newBase ^ "(%rbp), %rbp"));
                  line "lea rune_functions(%rip), %rdx";
                  line "lea (%rcx,%rcx,2), %rcx";
                  line "movslq 4(%rdx,%rcx,4), %rsi";
                  line "add %rdx, %rsi";
                  line "jmp *%rsi";
                  slows := (fn () =>
                              (put (slow ^ ":\n"); unforward (); flushSp (); setPc ();
                               if tail then callC ("native_tailcall", [])
                               else callC ("native_call", ["lea " ^ lab next ^ "(%rip), %rsi"]);
                               line "jmp *%rax")) :: !slows
                end
              (* M8: a known call (CALLK) pushes the frame here, with no
                 closure and its base at the first argument, and jumps
                 straight to the callee's entry for calls of the code; a
                 full array of frames is the glue's (native_callk). A known
                 tail call keeps the frame and moves the arguments down to
                 its first locals, which are below them. *)
              fun callKTemplate () =
                let
                  val tail = opc = Opcodes.TAILCALLK
                  val slow = lab pc ^ "_slow"
                  val newBase = sd (h - b)
                in
                  if tail then
                    (line "mov VM_FRAMES(%r12), %rdx";
                     line "mov VM_FP(%r12), %rsi";
                     line "imul $FRAME_SIZE, %rsi, %rsi";
                     line "add %rsi, %rdx";
                     line ("movl $" ^ num a ^ ", FRAME_FUNC(%rdx)");
                     line "movq $0, FRAME_CLOSURE(%rdx)";
                     List.app (fn k => L.copy line (ld k, rsd (h - b + k))) (List.tabulate (b, fn k => k)))
                  else
                    (line "mov VM_FP(%r12), %rdx";
                     line "add $1, %rdx";
                     line "cmp VM_FRAMES_CAP(%r12), %rdx";
                     line ("jae " ^ slow);
                     line "mov %rdx, VM_FP(%r12)";
                     line "imul $FRAME_SIZE, %rdx, %rdx";
                     line "add VM_FRAMES(%r12), %rdx";
                     line ("movl $" ^ num a ^ ", FRAME_FUNC(%rdx)");
                     line ("movl $" ^ num next ^ ", FRAME_RET_PC(%rdx)");
                     line ("lea " ^ newBase ^ "(%rbp), %rsi");
                     shiftIndex "%rsi";
                     line "mov %rsi, FRAME_BASE(%rdx)";
                     line "movq $0, FRAME_CLOSURE(%rdx)";
                     line ("lea " ^ lab next ^ "(%rip), %rsi");
                     line "mov %rsi, FRAME_NATIVE_RET(%rdx)";
                     line ("lea " ^ newBase ^ "(%rbp), %rbp");
                     slows := (fn () =>
                                 (put (slow ^ ":\n"); unforward (); flushSp (); setPc ();
                                  callC ("native_callk", ["mov $" ^ num a ^ ", %esi", "mov $" ^ num b ^ ", %edx",
                                                          "lea " ^ lab next ^ "(%rip), %rcx"]);
                                  line "jmp *%rax")) :: !slows);
                  line ("jmp .Le" ^ Int.toString a)
                end
              fun jumpIfTemplate () =
                (L.checkImm line (rsd (h - 1), check (pc, next, if opc = Opcodes.JUMPIF then fatalJumpIf else fatalJumpIfNot, 0));
                 L.testFalse line (rsd (h - 1));
                 line ((if opc = Opcodes.JUMPIF then "jne " else "je ") ^ lab a))
            in
              if h < 0 then line "ud2"
              else
                ((if afterCall i then resumes := (pc, lab pc) :: !resumes else ());
                 (if afterCall i orelse Array.sub (handler, i) then reloadFrame () else ());
                 (if startsRun i then line ("add $" ^ Int.toString (runLength i) ^ ", %r15") else ());
                 case Opcode.fromInt opc of
                   Opcode.HALT =>
                   (flushCount (); flushSp (); setPc (); callC ("native_halt", []); line "ud2")
                 | Opcode.CONST =>
                   (line "mov VM_CONSTS(%r12), %rax"; copy (num (L.valueSize * a) ^ "(%rax)", slot h))
                 | Opcode.INT => put0 (a, h)
                 | Opcode.UNIT => putUnit h
                 | Opcode.CON0 => put0 (a, h)
                 | Opcode.LOCAL =>
                   if forwards i then pending := SOME (h, a) else L.copy line (sd h, ld a)
                 | Opcode.SETLOCAL => L.copy line (ld a, rsd (h - 1))
                 | Opcode.TEELOCAL => L.copy line (ld a, rsd (h - 1))
                 | Opcode.ENV =>
                   (closureToRax ();
                    line "test %rax, %rax";
                    line ("jz " ^ check (pc, next, fatalEnv, a));
                    L.needLen line (L.RAX, a + 1, check (pc, next, fatalEnv, a));
                    L.loadField line (sd h, L.RAX, a + 1))
                 | Opcode.SELF =>
                   (closureToRax ();
                    line "test %rax, %rax";
                    line ("jz " ^ check (pc, next, fatalSelf, 0));
                    putPtr h)
                 | Opcode.GLOBAL =>
                   (line "mov VM_GLOBAL_SET(%r12), %rax";
                    line ("cmpb $0, " ^ num a ^ "(%rax)");
                    line ("je " ^ check (pc, next, fatalGlobal, a));
                    line "mov VM_GLOBALS(%r12), %rax";
                    copy (num (L.valueSize * a) ^ "(%rax)", slot h))
                 | Opcode.SETGLOBAL =>
                   (line "mov VM_GLOBALS(%r12), %rax";
                    copy (rslot (h - 1), num (L.valueSize * a) ^ "(%rax)");
                    line "mov VM_GLOBAL_SET(%r12), %rax";
                    line ("movb $1, " ^ num a ^ "(%rax)"))
                 | Opcode.POP => ()
                 | Opcode.TUPLE =>
                   if a = 0 then putUnit h
                   else
                     inlineAlloc (fn slow =>
                                    (alloc (L.K_TUPLE, 0, a, slow);
                                     List.app (fn k => storeField (k, rsd (h - a + k))) (List.tabulate (a, fn k => k));
                                     putPtr (h - a)),
                                  fn () => callC ("native_tuple", ["mov $" ^ num a ^ ", %esi"]))
                 | Opcode.SELECT =>
                   (expectObj (h - 1, "K_TUPLE", fatalTuple);
                    L.needLen line (L.RAX, a, check (pc, next, fatalSelect, a));
                    L.loadField line (sd (h - 1), L.RAX, a))
                 | Opcode.CON =>
                   inlineAlloc (fn slow => (alloc (L.K_CON, a, 1, slow); storeField (0, rsd (h - 1)); putPtr (h - 1)),
                                fn () => callC ("native_con", ["mov $" ^ num a ^ ", %esi"]))
                 | Opcode.DECON =>
                   (* under --checked, the tag tested too (decision D14),
                      out of line: the message has both tags *)
                   let val slow = lab pc ^ "_checked" val done = lab pc ^ "_done"
                   in
                     expectObj (h - 1, "K_CON", fatalCon);
                     line "cmpl $0, VM_CHECKED(%r12)";
                     line ("jne " ^ slow);
                     put (done ^ ":\n");
                     L.loadField line (sd (h - 1), L.RAX, 0);
                     slows := (fn () =>
                                 (put (slow ^ ":\n");
                                  L.loadContag line (L.RCX, L.RAX);
                                  line ("cmp $" ^ num a ^ ", %ecx");
                                  line ("je " ^ done);
                                  line "shl $16, %ecx";
                                  line ("or $" ^ num a ^ ", %ecx");
                                  line "mov %ecx, %edx";
                                  line ("movl $" ^ num next ^ ", VM_PC(%r12)");
                                  line "mov %r12, %rdi";
                                  line ("mov $" ^ num fatalDecon ^ ", %esi");
                                  line "call native_fatal";
                                  line "ud2")) :: !slows
                   end
                 | Opcode.CONN =>
                   inlineAlloc (fn slow =>
                                  (alloc (L.K_CON, a, b, slow);
                                   List.app (fn k => storeField (k, rsd (h - b + k))) (List.tabulate (b, fn k => k));
                                   putPtr (h - b)),
                                fn () => callC ("native_conn", ["mov $" ^ num a ^ ", %esi", "mov $" ^ num b ^ ", %edx"]))
                 | Opcode.FIELD =>
                   (* the tag tested under --checked alone, as DECON's *)
                   let val slow = lab pc ^ "_checked" val done = lab pc ^ "_done"
                   in
                     expectObj (h - 1, "K_CON", fatalFields);
                     L.needLen line (L.RAX, b, check (pc, next, fatalField, b));
                     line "cmpl $0, VM_CHECKED(%r12)";
                     line ("jne " ^ slow);
                     put (done ^ ":\n");
                     L.loadField line (sd (h - 1), L.RAX, b);
                     slows := (fn () =>
                                 (put (slow ^ ":\n");
                                  L.loadContag line (L.RCX, L.RAX);
                                  line ("cmp $" ^ num a ^ ", %ecx");
                                  line ("je " ^ done);
                                  line "shl $16, %ecx";
                                  line ("or $" ^ num a ^ ", %ecx");
                                  line "mov %ecx, %edx";
                                  line ("movl $" ^ num next ^ ", VM_PC(%r12)");
                                  line "mov %r12, %rdi";
                                  line ("mov $" ^ num fatalFieldTag ^ ", %esi");
                                  line "call native_fatal";
                                  line "ud2")) :: !slows
                   end
                 | Opcode.CONTAG =>
                   (L.loadTagOfCon line (L.RAX, sd (h - 1), check (pc, next, fatalContag, 0), lab pc);
                    L.setImm line (sd (h - 1), L.RAX))
                 | Opcode.CLOSURE =>
                   inlineAlloc (fn slow =>
                                  (alloc (L.K_CLOSURE, 0, b + 1, slow);
                                   L.storeFieldImm line (L.RAX, 0, a);
                                   List.app (fn k => storeField (k + 1, rsd (h - b + k))) (List.tabulate (b, fn k => k));
                                   putPtr (h - b)),
                                fn () => callC ("native_closure", ["mov $" ^ num a ^ ", %esi", "mov $" ^ num b ^ ", %edx"]))
                 | Opcode.SETENV =>
                   (flushSp (); setPc (); callC ("native_setenv", ["mov $" ^ num a ^ ", %esi"]))
                 | Opcode.CALL => callTemplate ()
                 | Opcode.TAILCALL => callTemplate ()
                 | Opcode.SWITCH =>
                   (* the tag, as CONTAG finds it, and a jump through a table
                      of the targets of the JUMPs after it, which are never
                      run; past them where the tag is not below a *)
                   let
                     val table = lab pc ^ "_table"
                     val past = next + 5 * a
                   in
                     L.loadTagOfCon line (L.RAX, rsd (h - 1), check (pc, next, fatalSwitch, 0), lab pc);
                     line ("cmp $" ^ num a ^ ", %rax");
                     line ("jae " ^ lab past);
                     line ("lea " ^ table ^ "(%rip), %rcx");
                     line "movslq (%rcx,%rax,4), %rax";
                     line "add %rcx, %rax";
                     line "jmp *%rax";
                     put (table ^ ":\n");
                     List.app (fn k => line (".long " ^ lab (#a (ins (i + 1 + k))) ^ " - " ^ table)) (List.tabulate (a, fn k => k))
                   end
                 | Opcode.CALLK => callKTemplate ()
                 | Opcode.TAILCALLK => callKTemplate ()
                 | Opcode.RET =>
                   (* M10: the result in local 0, where the caller wants it,
                      the frame popped, and a jump to where it returns; the
                      top level's RET ends the run in the glue. *)
                   let val slow = lab pc ^ "_slow"
                   in
                     line "mov VM_FP(%r12), %rdx";
                     line "test %rdx, %rdx";
                     line ("jz " ^ slow);
                     L.copy line (ld 0, rsd (h - 1));
                     line "imul $FRAME_SIZE, %rdx, %rdx";
                     line "add VM_FRAMES(%r12), %rdx";
                     line "decq VM_FP(%r12)";
                     line "jmp *FRAME_NATIVE_RET(%rdx)";
                     slows := (fn () =>
                                 (put (slow ^ ":\n"); unforward (); flushCount (); flushSp (); setPc ();
                                  callC ("native_ret", []); line "jmp *%rax")) :: !slows
                   end
                 | Opcode.JUMP => line ("jmp " ^ lab a)
                 | Opcode.JUMPIFNOT => jumpIfTemplate ()
                 | Opcode.JUMPIF => jumpIfTemplate ()
                 | Opcode.JUMPIFNOTTAG =>
                   (* CONTAG's two cases, each compared with b *)
                   (L.loadTagOfCon line (L.RAX, rsd (h - 1), check (pc, next, fatalJumpIfNotTag, 0), lab pc);
                    line ("cmp $" ^ num b ^ ", %rax");
                    line ("jne " ^ lab a))
                 | Opcode.PUSHHANDLER =>
                   (flushSp (); callC ("vm_push_handler", ["mov $" ^ num a ^ ", %esi"]))
                 | Opcode.POPHANDLER =>
                   (line "cmpq $0, VM_HP(%r12)";
                    line ("je " ^ check (pc, next, fatalPopHandler, 0));
                    line "decq VM_HP(%r12)")
                 | Opcode.RAISE =>
                   (flushCount (); flushSp (); setPc (); callC ("native_raise", []); line "jmp *%rax")
                 | Opcode.NEWEXN =>
                   inlineAlloc (fn slow =>
                                  (alloc (L.K_EXNCON, 0, 1, slow);
                                   line "mov VM_CONSTS(%r12), %rcx";
                                   copy (num (L.valueSize * a) ^ "(%rcx)", field 0);
                                   putPtr h),
                                fn () => callC ("native_newexn", ["mov $" ^ num a ^ ", %esi"]))
                 | Opcode.BUILTINEXN =>
                   (line ("mov VM_BUILTIN_EXNS+" ^ num (8 * a) ^ "(%r12), %rax");
                    putPtr h)
                 | Opcode.MKEXN =>
                   (* a constructor that is none is the helper's to report,
                      after it has allocated, as the interpreter does *)
                   inlineAlloc (fn slow =>
                                  (L.loadObj line (L.RCX, sd (h - 2), "K_EXNCON", slow);
                                   alloc (L.K_EXN, 0, 2, slow);
                                   storeField (0, sd (h - 2));
                                   storeField (1, rsd (h - 1));
                                   putPtr (h - 2)),
                                fn () => callC ("native_mkexn", []))
                 | Opcode.EXNCON =>
                   (expectObj (h - 1, "K_EXN", fatalExn); L.loadField line (sd (h - 1), L.RAX, 0))
                 | Opcode.EXNARG =>
                   (expectObj (h - 1, "K_EXN", fatalExn); L.loadField line (sd (h - 1), L.RAX, 1))
                 | Opcode.PRIM =>
                   let
                     fun callPrim () =
                       (flushCount (); flushSp (); setPc ();
                        line "mov %r12, %rdi";
                        line "lea prim_table(%rip), %rax";
                        line ("call *" ^ num (8 * a) ^ "(%rax)");
                        line "test %eax, %eax";
                        line "jnz rune_unusual";
                        line reloadStack)
                     val () =
                       if imagePrim a then
                         let val stub = ".Lr" ^ Int.toString next
                         in
                           resumes := (next, stub) :: !resumes;
                           slows := (fn () => (put (stub ^ ":\n"); reloadFrame (); line ("jmp " ^ lab next))) :: !slows
                         end
                       else ()
                   in
                     case fastPrim (Vector.sub (primNames, a), h, pc, {line = line, put = put, sd = rsd}) of
                       NONE => callPrim ()
                     | SOME fast =>
                         let val slow = lab pc ^ "_slow" val done = lab pc ^ "_done"
                         in
                           fast slow;
                           put (done ^ ":\n");
                           slows := (fn () => (put (slow ^ ":\n"); unforward (); callPrim (); line ("jmp " ^ done)))
                                    :: !slows
                         end
                   end
                 )
            end
          fun loop i = if i > last then () else (instruction i; loop (i + 1))
        in
          put ("\n\t# function " ^ Int.toString f ^ " " ^ String.toString name ^ " (locals " ^ Int.toString nlocals ^ ")\n");
          line ".p2align 4";
          line (".type " ^ sym ^ ", @function");
          put (sym ^ ":\n");
          cfiFrame ();
          (* the function's own position from its first byte, which is the
             address a debugger or addr2line is given for it, and where
             every call enters: a breakpoint on its line is reached *)
          (case Array.sub (lineStarts, offset) of ~1 => () | k => loc k);
          (* M10: the entry a CALL of the code jumps to -- the symbol itself
             (M8), the frame already pushed and rbp its base: the room the
             frame needs, and its locals but its arguments set to unit, n
             stores where the glue had a loop -- a CALL gives one argument,
             a CALLK as many as the function is given (RbcCheck). The glue
             enters at .Lr, which takes rbp from the frame first. *)
          put (".Le" ^ Int.toString f ^ ":\n");
          line ("lea " ^ sd (Vector.sub (#maxHeight facts, f)) ^ "(%rbp), %rax");
          shiftIndex "%rax";
          line "cmp VM_STACK_CAP(%r12), %rax";
          line ("ja .Lg" ^ Int.toString f);
          put (".Lh" ^ Int.toString f ^ ":\n");
          let fun units k = if k >= nlocals then () else (L.set line (ld k, 0); units (k + 1))
          in units (Vector.sub (#params facts, f)) end;
          slows := (fn () =>
                      (put (".Lg" ^ Int.toString f ^ ":\n");
                       line "mov %rax, %rsi"; line "mov %r12, %rdi"; line "call vm_grow_stack";
                       line reloadStack; line ("jmp .Lh" ^ Int.toString f))) :: !slows;
          slows := (fn () => (put (".Lr" ^ Int.toString f ^ ":\n"); reloadFrame (); line ("jmp .Le" ^ Int.toString f)))
                   :: !slows;
          loop first;
          List.app
            (fn (l, next, what, arg) =>
               (put (l ^ ":\n");
                line ("movl $" ^ num next ^ ", VM_PC(%r12)");
                line "mov %r12, %rdi";
                line ("mov $" ^ num what ^ ", %esi");
                line ("mov $" ^ num arg ^ ", %edx");
                line "call native_fatal";
                line "ud2"))
            (List.rev (!fatals));
          List.app (fn f => f ()) (List.rev (!slows));
          line ".cfi_endproc";
          line (".size " ^ sym ^ ", .-" ^ sym)
        end

      val handlerPcs = List.filter (fn pc => Array.sub (handler, Array.sub (index, pc)) andalso reachable (Array.sub (index, pc)))
                                   (List.map #pc (Vector.foldr op:: [] instrs))
    in
      put ("# Made by runeopt " ^ Config.version ^ " from " ^ String.toString rbc ^ " (docs/native.md).\n");
      line ".include \"rune-offsets.s\"";
      Vector.appi (fn (k, file) => line (".file " ^ Int.toString (k + 1) ^ " " ^ quote file)) (#files p);
      line ".text";
      (* The way in from runtime/native/native.c: the registers C wants kept are kept,
         once, since the code never returns; the stack is left aligned for
         every call the code makes into C. *)
      line ".globl rune_enter";
      line ".type rune_enter, @function";
      put "rune_enter:\n";
      line ".cfi_startproc";
      List.app (fn (r, off) => (line ("push %" ^ r); line (".cfi_def_cfa_offset " ^ num (~ off));
                                line (".cfi_offset %" ^ r ^ ", " ^ num off)))
        [("rbp", ~16), ("rbx", ~24), ("r12", ~32), ("r13", ~40), ("r14", ~48), ("r15", ~56)];
      List.app line ["sub $8, %rsp", ".cfi_def_cfa_offset 64",
                     "mov %rdi, %r12", "mov VM_INSTRUCTIONS(%r12), %r15", "jmp *%rsi", ".cfi_endproc"];
      line ".size rune_enter, .-rune_enter";
      (* a primitive that raised, or replaced the program *)
      put "rune_unusual:\n";
      cfiFrame ();
      (* the count comes from the VM again: a new world brings its own *)
      List.app line ["mov %eax, %esi", "mov %r12, %rdi", "call native_unusual",
                     "mov VM_INSTRUCTIONS(%r12), %r15", "jmp *%rax", ".cfi_endproc"];
      Vector.appi function funcs;

      line ".section .rodata";
      line ".balign 16";
      line ".globl rune_rbc";
      put "rune_rbc:\n";
      line (".incbin " ^ quote rbc);
      line ".balign 4";
      line ".globl rune_rbc_size";
      put "rune_rbc_size:\n";
      line (".long " ^ Int.toString rbcSize);
      line ".globl rune_functions";
      put "rune_functions:\n";
      Vector.appi
        (fn (f, {name, ...} : Rbc.func) =>
           line (".long .Lr" ^ Int.toString f ^ " - rune_functions, .Le" ^ Int.toString f ^ " - rune_functions, "
                 ^ Int.toString (Vector.sub (#maxHeight facts, f))))
        funcs;
      line ".globl rune_handlers";
      put "rune_handlers:\n";
      List.app (fn pc => line (".long " ^ Int.toString pc ^ ", " ^ lab pc ^ " - rune_handlers")) handlerPcs;
      line ".globl rune_resume";
      put "rune_resume:\n";
      List.app (fn (pc, l) => line (".long " ^ Int.toString pc ^ ", " ^ l ^ " - rune_resume")) (List.rev (!resumes));
      line ".globl rune_nresume";
      put "rune_nresume:\n";
      line (".long " ^ Int.toString (List.length (!resumes)));
      line ".globl rune_nhandlers";
      put "rune_nhandlers:\n";
      line (".long " ^ Int.toString (List.length handlerPcs));
      line ".globl rune_options";
      put "rune_options:\n";
      line (".asciz " ^ quote options);
      line ".section .note.GNU-stack,\"\",@progbits"
    end
end
