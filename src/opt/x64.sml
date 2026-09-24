(* The translation of a program into x86-64 assembly, for the GNU assembler
   (docs/plans/codegen.md, D0 to D6). Every instruction becomes the code that
   does what its case in vm/interp.c does, in the order of the bytecode:
   nothing is dropped, merged or moved. The value stack, the frames and the
   handlers are the interpreter's; the code keeps four things in registers:

     r12  the VM
     r13  vm->stack, reloaded after every call into C
     rbp  16 times the base of the current frame, reloaded where the frame
          changes (a function's entry, a return, a handler)
     r15  the count of instructions executed, written to the VM before
          anything that can read it (D6)

   The height of the stack before every instruction is known (RbcCheck), so
   a slot is an address in the frame, and vm->sp is written only before a
   call into C. A call, a return and a raise go through vm/native.c, which
   answers with the native code to jump to (D3, option B); a primitive is a
   call through prim_table. The offsets and numbers of the VM's layout are
   names that rune-offsets.s, made from vm/vm.h, defines. *)
structure X64 =
struct
  (* A number as the assembler writes it. *)
  fun num (n : int) : string = Rbc.minus (Int.toString n)

  fun lab (pc : int) : string = ".Lp" ^ Int.toString pc

  (* A string the assembler reads between quotes. *)
  fun quote (s : string) : string =
    "\"" ^ String.translate (fn #"\"" => "\\\"" | #"\\" => "\\\\" | #"\n" => "\\n" | c => String.str c) s ^ "\""

  (* The symbol of function f: its name and its index, since names repeat. *)
  fun symbol (name : string, f : int) : string = quote (name ^ "#" ^ Int.toString f)

  (* The instructions after which a straight run of code ends, and with it
     what the counter adds at once (D6). *)
  fun endsRun opc =
    opc = Opcodes.CALL orelse opc = Opcodes.TAILCALL orelse opc = Opcodes.PRIM orelse opc = Opcodes.RAISE
    orelse opc = Opcodes.RET orelse opc = Opcodes.JUMP orelse opc = Opcodes.JUMPIF
    orelse opc = Opcodes.JUMPIFNOT orelse opc = Opcodes.HALT

  (* The numbers the checks of the code give native_fatal, which has the
     messages of vm/interp.c. *)
  val fatalTuple = 0 val fatalCon = 1 val fatalExn = 2 val fatalEnv = 3 val fatalSelf = 4
  val fatalGlobal = 5 val fatalSelect = 6 val fatalContag = 7 val fatalJumpIfNot = 8
  val fatalJumpIf = 9 val fatalPopHandler = 10

  val primNames : string vector = Vector.fromList (List.map #1 Prims.table)

  (* D12: the primitives whose common case the code does itself. A PRIM of
     one of them checks the tags (and the kinds, and the bounds) of its
     arguments and does the operation; anything else -- a wrong tag, an
     overflow, a divisor of zero, an index out of bounds, a real or a pointer
     for poly_eq -- goes to `slow`, where the primitive of vm/prims.c is
     called as it is for any other, and raises or stops as it does. So a
     program cannot tell the one from the other, and a PRIM still counts as
     one instruction. The arguments are at heights h - arity .. h - 1, the
     last on top, and the result goes where the first was. tests/opt runs
     every one of them on its edge cases (prims.sml), natively and on runevm,
     and runeopt --inlined lists them. *)
  fun fastPrim (name : string, h : int, pc : int,
                {line, put, slot, payload} : {line : string -> unit, put : string -> unit,
                                              slot : int -> string, payload : int -> string})
      : (string -> unit) option =
    let
      val x = h - 2
      val y = h - 1
      val l = ".Lp" ^ Int.toString pc
      fun tags (t, ks) slow = List.app (fn k => (line ("cmpb $" ^ t ^ ", " ^ slot k); line ("jne " ^ slow))) ks
      fun bool (setcc, k) =
        (line (setcc ^ " %al"); line "movzbl %al, %eax";
         line ("movb $T_CON0, " ^ slot k); line ("mov %rax, " ^ payload k))
      fun obj (k, kind) slow =
        (line ("cmpb $T_PTR, " ^ slot k); line ("jne " ^ slow);
         line ("mov " ^ payload k ^ ", %rax");
         line ("cmpb $" ^ kind ^ ", OBJ_KIND(%rax)"); line ("jne " ^ slow))
      (* the index at k into %rcx, when it is below the length of the object in %rax *)
      fun index k slow =
        (tags ("T_INT", [k]) slow;
         line ("mov " ^ payload k ^ ", %rcx"); line "mov OBJ_LEN(%rax), %edx";
         line "cmp %rdx, %rcx"; line ("jae " ^ slow))
      fun arith (t, ins, overflows) =
        SOME (fn slow =>
          (tags (t, [x, y]) slow;
           line ("mov " ^ payload x ^ ", %rax"); line (ins ^ " " ^ payload y ^ ", %rax");
           if overflows then line ("jo " ^ slow) else ();
           line ("mov %rax, " ^ payload x)))
      fun compare (t, setcc) =
        SOME (fn slow =>
          (tags (t, [x, y]) slow;
           line ("mov " ^ payload x ^ ", %rax"); line ("cmp " ^ payload y ^ ", %rax");
           bool (setcc, x)))
      (* ucomisd sets `above` only for an ordered pair, so a NaN compares false *)
      fun realCompare (first, second, setcc) =
        SOME (fn slow =>
          (tags ("T_REAL", [x, y]) slow;
           line ("movsd " ^ payload first ^ ", %xmm0"); line ("ucomisd " ^ payload second ^ ", %xmm0");
           bool (setcc, x)))
      fun real ins =
        SOME (fn slow =>
          (tags ("T_REAL", [x, y]) slow;
           line ("movsd " ^ payload x ^ ", %xmm0"); line (ins ^ " " ^ payload y ^ ", %xmm0");
           line ("movsd %xmm0, " ^ payload x)))
      (* quotient in %rax and remainder in %rdx of C's truncating division; a
         divisor of 0 or ~1 (where the quotient may overflow) is the primitive's *)
      fun intDivide finish =
        SOME (fn slow =>
          (tags ("T_INT", [x, y]) slow;
           line ("mov " ^ payload y ^ ", %rcx");
           line "test %rcx, %rcx"; line ("jz " ^ slow);
           line "cmp $-1, %rcx"; line ("je " ^ slow);
           line ("mov " ^ payload x ^ ", %rax"); line "cqo"; line "idiv %rcx";
           finish ()))
      fun wordDivide result =
        SOME (fn slow =>
          (tags ("T_WORD", [x, y]) slow;
           line ("mov " ^ payload y ^ ", %rcx");
           line "test %rcx, %rcx"; line ("jz " ^ slow);
           line ("mov " ^ payload x ^ ", %rax"); line "xor %edx, %edx"; line "div %rcx";
           line ("mov " ^ result ^ ", " ^ payload x)))
      (* a shift by 64 or more gives 0 *)
      fun shift ins =
        SOME (fn slow =>
          (tags ("T_WORD", [x, y]) slow;
           line ("mov " ^ payload y ^ ", %rcx"); line ("mov " ^ payload x ^ ", %rax");
           line "cmp $64, %rcx"; line ("jb " ^ l ^ "_s");
           line "xor %eax, %eax"; line ("jmp " ^ l ^ "_t");
           put (l ^ "_s:\n"); line (ins ^ " %cl, %rax");
           put (l ^ "_t:\n"); line ("mov %rax, " ^ payload x)))
      fun length kind =
        SOME (fn slow =>
          (obj (y, kind) slow;
           line "mov OBJ_LEN(%rax), %eax";
           line ("movb $T_INT, " ^ slot y); line ("mov %rax, " ^ payload y)))
    in
      case name of
        "int_add" => arith ("T_INT", "add", true)
      | "int_sub" => arith ("T_INT", "sub", true)
      | "int_mul" => arith ("T_INT", "imul", true)
      | "int_neg" =>
          SOME (fn slow =>
            (tags ("T_INT", [y]) slow;
             line ("mov " ^ payload y ^ ", %rax"); line "neg %rax"; line ("jo " ^ slow);
             line ("mov %rax, " ^ payload y)))
      | "int_quot" => intDivide (fn () => line ("mov %rax, " ^ payload x))
      | "int_rem" => intDivide (fn () => line ("mov %rdx, " ^ payload x))
      | "int_div" =>
          (* floor: one less where there is a remainder and the signs differ *)
          intDivide (fn () =>
            (line "test %rdx, %rdx"; line ("jz " ^ l ^ "_f");
             line "xor %rcx, %rdx"; line ("jns " ^ l ^ "_f");
             line "dec %rax";
             put (l ^ "_f:\n"); line ("mov %rax, " ^ payload x)))
      | "int_mod" =>
          (* the sign of the divisor: the divisor added where they differ *)
          intDivide (fn () =>
            (line "test %rdx, %rdx"; line ("jz " ^ l ^ "_f");
             line "mov %rdx, %r8"; line "xor %rcx, %r8"; line ("jns " ^ l ^ "_f");
             line "add %rcx, %rdx";
             put (l ^ "_f:\n"); line ("mov %rdx, " ^ payload x)))
      | "int_lt" => compare ("T_INT", "setl")
      | "int_le" => compare ("T_INT", "setle")
      | "int_gt" => compare ("T_INT", "setg")
      | "int_ge" => compare ("T_INT", "setge")
      | "word_add" => arith ("T_WORD", "add", false)
      | "word_sub" => arith ("T_WORD", "sub", false)
      | "word_mul" => arith ("T_WORD", "imul", false)
      | "word_andb" => arith ("T_WORD", "and", false)
      | "word_orb" => arith ("T_WORD", "or", false)
      | "word_xorb" => arith ("T_WORD", "xor", false)
      | "word_notb" => SOME (fn slow => (tags ("T_WORD", [y]) slow; line ("notq " ^ payload y)))
      | "word_div" => wordDivide "%rax"
      | "word_mod" => wordDivide "%rdx"
      | "word_lsl" => shift "shl"
      | "word_lsr" => shift "shr"
      | "word_lt" => compare ("T_WORD", "setb")
      | "word_le" => compare ("T_WORD", "setbe")
      | "word_gt" => compare ("T_WORD", "seta")
      | "word_ge" => compare ("T_WORD", "setae")
      | "char_lt" => compare ("T_CHAR", "setl")
      | "char_le" => compare ("T_CHAR", "setle")
      | "char_gt" => compare ("T_CHAR", "setg")
      | "char_ge" => compare ("T_CHAR", "setge")
      | "char_ord" => SOME (fn slow => (tags ("T_CHAR", [y]) slow; line ("movb $T_INT, " ^ slot y)))
      | "real_add" => real "addsd"
      | "real_sub" => real "subsd"
      | "real_mul" => real "mulsd"
      | "real_div" => real "divsd"
      | "real_neg" => SOME (fn slow => (tags ("T_REAL", [y]) slow; line ("btcq $63, " ^ payload y)))
      | "real_lt" => realCompare (y, x, "seta")
      | "real_le" => realCompare (y, x, "setae")
      | "real_gt" => realCompare (x, y, "seta")
      | "real_ge" => realCompare (x, y, "setae")
      | "real_eq" =>
          SOME (fn slow =>
            (tags ("T_REAL", [x, y]) slow;
             line ("movsd " ^ payload x ^ ", %xmm0"); line ("ucomisd " ^ payload y ^ ", %xmm0");
             line "sete %al"; line "setnp %cl"; line "and %cl, %al"; line "movzbl %al, %eax";
             line ("movb $T_CON0, " ^ slot x); line ("mov %rax, " ^ payload x)))
      | "poly_eq" =>
          (* values_equal of two immediates: of different tags, false; of the
             same, the payloads (unit is equal to unit); a real or a pointer is
             the primitive's *)
          SOME (fn slow =>
            (line ("movzbl " ^ slot x ^ ", %eax");
             line ("cmpb %al, " ^ slot y); line ("jne " ^ l ^ "_ne");
             line "cmp $T_REAL, %eax"; line ("je " ^ slow);
             line "cmp $T_PTR, %eax"; line ("je " ^ slow);
             line "cmp $T_UNIT, %eax"; line ("je " ^ l ^ "_eq");
             line ("mov " ^ payload x ^ ", %rax"); line ("cmp " ^ payload y ^ ", %rax");
             line "sete %al"; line "movzbl %al, %eax"; line ("jmp " ^ l ^ "_b");
             put (l ^ "_eq:\n"); line "mov $1, %eax"; line ("jmp " ^ l ^ "_b");
             put (l ^ "_ne:\n"); line "xor %eax, %eax";
             put (l ^ "_b:\n"); line ("movb $T_CON0, " ^ slot x); line ("mov %rax, " ^ payload x)))
      | "ref_get" => SOME (fn slow => (obj (y, "K_REF") slow; line "movdqu OBJ_FIELDS(%rax), %xmm0"; line ("movdqu %xmm0, " ^ slot y)))
      | "ref_set" =>
          SOME (fn slow =>
            (obj (x, "K_REF") slow;
             line ("movdqu " ^ slot y ^ ", %xmm0"); line "movdqu %xmm0, OBJ_FIELDS(%rax)";
             line ("movb $T_UNIT, " ^ slot x); line ("movq $0, " ^ payload x)))
      | "word_to_int" =>
          SOME (fn slow =>
            (tags ("T_WORD", [y]) slow;
             line ("cmpq $0, " ^ payload y); line ("jl " ^ slow);
             line ("movb $T_INT, " ^ slot y)))
      | "word_to_int_x" => SOME (fn slow => (tags ("T_WORD", [y]) slow; line ("movb $T_INT, " ^ slot y)))
      | "word_from_int" => SOME (fn slow => (tags ("T_INT", [y]) slow; line ("movb $T_WORD, " ^ slot y)))
      | "int_to_char" =>
          SOME (fn slow =>
            (tags ("T_INT", [y]) slow;
             line ("cmpq $255, " ^ payload y); line ("ja " ^ slow);
             line ("movb $T_CHAR, " ^ slot y)))
      | "vector_length" => length "K_TUPLE"
      | "vector_sub" =>
          SOME (fn slow =>
            (obj (x, "K_TUPLE") slow; index y slow;
             line "shl $4, %rcx"; line "movdqu OBJ_FIELDS(%rax,%rcx), %xmm0";
             line ("movdqu %xmm0, " ^ slot x)))
      | "string_size" => length "K_STRING"
      | "array_length" => length "K_ARRAY"
      | "string_sub" =>
          SOME (fn slow =>
            (obj (x, "K_STRING") slow; index y slow;
             line "movzbl OBJ_FIELDS(%rax,%rcx), %ecx";
             line ("movb $T_CHAR, " ^ slot x); line ("mov %rcx, " ^ payload x)))
      | "array_sub" =>
          SOME (fn slow =>
            (obj (x, "K_ARRAY") slow; index y slow;
             line "shl $4, %rcx"; line "movdqu OBJ_FIELDS(%rax,%rcx), %xmm0";
             line ("movdqu %xmm0, " ^ slot x)))
      | "array_update" =>
          SOME (fn slow =>
            (obj (h - 3, "K_ARRAY") slow; index (h - 2) slow;
             line "shl $4, %rcx"; line ("movdqu " ^ slot (h - 1) ^ ", %xmm0");
             line "movdqu %xmm0, OBJ_FIELDS(%rax,%rcx)";
             line ("movb $T_UNIT, " ^ slot (h - 3)); line ("movq $0, " ^ payload (h - 3))))
      | _ => NONE
    end

  (* The names of the primitives fastPrim does inline, for runeopt --inlined. *)
  val inlined : string list =
    let val none = {line = fn _ => (), put = fn _ => (), slot = fn _ => "", payload = fn _ => ""}
    in List.filter (fn n => isSome (fastPrim (n, 3, 0, none))) (Vector.foldr op:: [] primNames) end

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
             if opc = Opcodes.JUMP orelse opc = Opcodes.JUMPIF orelse opc = Opcodes.JUMPIFNOT
             then Array.update (target, Array.sub (index, a), true)
             else if opc = Opcodes.PUSHHANDLER then Array.update (handler, Array.sub (index, a), true)
             else ())
          instrs
      fun reachable i = Vector.sub (#height facts, i) >= 0
      fun afterCall i = i > 0 andalso #opc (ins (i - 1)) = Opcodes.CALL andalso reachable (i - 1)

      (* The places an image can stop at, by pc, with the native code that
         carries on there (M9): the instruction after a CALL, where a frame
         returns to, and after a primitive that writes an image, where the
         world that saved itself starts again. *)
      val resumes : (int * string) list ref = ref []
      fun imagePrim a = let val n = Vector.sub (primNames, a) in n = "rt_save" orelse n = "posix_fork" end

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
         line "shl $4, %rbp")
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
          fun slot k = num (16 * (nlocals + k)) ^ "(%r13,%rbp)"
          fun payload k = num (16 * (nlocals + k) + 8) ^ "(%r13,%rbp)"
          fun localSlot l = num (16 * l) ^ "(%r13,%rbp)"
          fun copy (from, to) = (line ("movdqu " ^ from ^ ", %xmm0"); line ("movdqu %xmm0, " ^ to))
          val emitters = {line = line, put = put, slot = slot, payload = payload}
          fun put0 (tag, value, k) = (line ("movb $" ^ tag ^ ", " ^ slot k); line ("movq $" ^ value ^ ", " ^ payload k))
          fun putPtr k = (line ("movb $T_PTR, " ^ slot k); line ("mov %rax, " ^ payload k))
          (* M11: an object of n > 0 fields, its header written, in rax, by
             bumping heap_used as vm_alloc does, with the same counts; to
             `slow` when it does not fit or --gc-stress is on, which is
             vm_alloc's to decide. The fields are the caller's to write. *)
          fun alloc (kind, contag, n, slow) =
            let val size = num (8 + 16 * n)
            in
              line "cmpq $0, VM_GC_STRESS(%r12)";
              line ("jne " ^ slow);
              line "mov VM_HEAP_USED(%r12), %rax";
              line "mov VM_HEAP_SIZE(%r12), %rdx";
              line "sub %rax, %rdx";
              line ("cmp $" ^ size ^ ", %rdx");
              line ("jb " ^ slow);
              line ("lea " ^ size ^ "(%rax), %rdx");
              line "mov %rdx, VM_HEAP_USED(%r12)";
              line "add VM_HEAP_FROM(%r12), %rax";
              line ("addq $" ^ size ^ ", VM_BYTES_ALLOCATED(%r12)");
              line "incq VM_OBJECTS_ALLOCATED(%r12)";
              line ("movl $" ^ kind ^ "+" ^ num (65536 * (contag mod 65536)) ^ ", (%rax)");
              line ("movl $" ^ num n ^ ", OBJ_LEN(%rax)")
            end
          fun field k = "OBJ_FIELDS+" ^ num (16 * k) ^ "(%rax)"
          fun startsRun i =
            i = first orelse endsRun (#opc (ins (i - 1))) orelse Array.sub (target, i) orelse Array.sub (handler, i)
          fun runLength i =
            let fun go j = if j > last orelse startsRun j then j - i else go (j + 1)
            in go (i + 1) end
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
              fun flushSp () =
                (line ("lea " ^ num (16 * (nlocals + h)) ^ "(%rbp), %rax");
                 line "shr $4, %rax";
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
                  slows := (fn () => (put (slow ^ ":\n"); flushSp (); setPc (); helper (); line reloadStack;
                                      line ("jmp " ^ done))) :: !slows
                end
              fun expectObj (k, kind, what) =
                (line ("cmpb $T_PTR, " ^ slot k);
                 line ("jne " ^ check (pc, next, what, 0));
                 line ("mov " ^ payload k ^ ", %rax");
                 line ("cmpb $" ^ kind ^ ", OBJ_KIND(%rax)");
                 line ("jne " ^ check (pc, next, what, 0)))
              val () = put (lab pc ^ ":\t# " ^ Vector.sub (Opcodes.names, opc)
                            ^ (case Vector.sub (Opcodes.nargs, opc) of 0 => "" | 1 => " " ^ num a | _ => " " ^ num a ^ " " ^ num b)
                            ^ "\n")
              val () = case Array.sub (lineStarts, pc) of ~1 => () | k => loc k
            in
              if h < 0 then line "ud2"
              else
                ((if afterCall i then resumes := (pc, lab pc) :: !resumes else ());
                 (if afterCall i orelse Array.sub (handler, i) then reloadFrame () else ());
                 (if startsRun i then line ("add $" ^ Int.toString (runLength i) ^ ", %r15") else ());
                 if opc = Opcodes.HALT then
                   (flushCount (); flushSp (); setPc (); callC ("native_halt", []); line "ud2")
                 else if opc = Opcodes.CONST then
                   (line "mov VM_CONSTS(%r12), %rax"; copy (num (16 * a) ^ "(%rax)", slot h))
                 else if opc = Opcodes.INT then put0 ("T_INT", num a, h)
                 else if opc = Opcodes.UNIT then put0 ("T_UNIT", "0", h)
                 else if opc = Opcodes.CON0 then put0 ("T_CON0", num a, h)
                 else if opc = Opcodes.LOCAL then copy (localSlot a, slot h)
                 else if opc = Opcodes.SETLOCAL then copy (slot (h - 1), localSlot a)
                 else if opc = Opcodes.ENV then
                   (closureToRax ();
                    line "test %rax, %rax";
                    line ("jz " ^ check (pc, next, fatalEnv, a));
                    line ("cmpl $" ^ num (a + 1) ^ ", OBJ_LEN(%rax)");
                    line ("jbe " ^ check (pc, next, fatalEnv, a));
                    copy ("OBJ_FIELDS+" ^ num (16 * (a + 1)) ^ "(%rax)", slot h))
                 else if opc = Opcodes.SELF then
                   (closureToRax ();
                    line "test %rax, %rax";
                    line ("jz " ^ check (pc, next, fatalSelf, 0));
                    line ("movb $T_PTR, " ^ slot h);
                    line ("mov %rax, " ^ payload h))
                 else if opc = Opcodes.GLOBAL then
                   (line "mov VM_GLOBAL_SET(%r12), %rax";
                    line ("cmpb $0, " ^ num a ^ "(%rax)");
                    line ("je " ^ check (pc, next, fatalGlobal, a));
                    line "mov VM_GLOBALS(%r12), %rax";
                    copy (num (16 * a) ^ "(%rax)", slot h))
                 else if opc = Opcodes.SETGLOBAL then
                   (line "mov VM_GLOBALS(%r12), %rax";
                    copy (slot (h - 1), num (16 * a) ^ "(%rax)");
                    line "mov VM_GLOBAL_SET(%r12), %rax";
                    line ("movb $1, " ^ num a ^ "(%rax)"))
                 else if opc = Opcodes.POP then ()
                 else if opc = Opcodes.TUPLE then
                   if a = 0 then put0 ("T_UNIT", "0", h)
                   else
                     inlineAlloc (fn slow =>
                                    (alloc ("K_TUPLE", 0, a, slow);
                                     List.app (fn k => copy (slot (h - a + k), field k)) (List.tabulate (a, fn k => k));
                                     putPtr (h - a)),
                                  fn () => callC ("native_tuple", ["mov $" ^ num a ^ ", %esi"]))
                 else if opc = Opcodes.SELECT then
                   (expectObj (h - 1, "K_TUPLE", fatalTuple);
                    line ("cmpl $" ^ num a ^ ", OBJ_LEN(%rax)");
                    line ("jbe " ^ check (pc, next, fatalSelect, a));
                    copy ("OBJ_FIELDS+" ^ num (16 * a) ^ "(%rax)", slot (h - 1)))
                 else if opc = Opcodes.CON then
                   inlineAlloc (fn slow => (alloc ("K_CON", a, 1, slow); copy (slot (h - 1), field 0); putPtr (h - 1)),
                                fn () => callC ("native_con", ["mov $" ^ num a ^ ", %esi"]))
                 else if opc = Opcodes.DECON then
                   (expectObj (h - 1, "K_CON", fatalCon); copy ("OBJ_FIELDS(%rax)", slot (h - 1)))
                 else if opc = Opcodes.CONTAG then
                   let val ptr = lab pc ^ "_ptr" val done = lab pc ^ "_done"
                   in
                     line ("cmpb $T_CON0, " ^ slot (h - 1));
                     line ("jne " ^ ptr);
                     line ("movb $T_INT, " ^ slot (h - 1));
                     line ("jmp " ^ done);
                     put (ptr ^ ":\n");
                     line ("cmpb $T_PTR, " ^ slot (h - 1));
                     line ("jne " ^ check (pc, next, fatalContag, 0));
                     line ("mov " ^ payload (h - 1) ^ ", %rax");
                     line "cmpb $K_CON, OBJ_KIND(%rax)";
                     line ("jne " ^ check (pc, next, fatalContag, 0));
                     line "movzwl OBJ_CONTAG(%rax), %eax";
                     line ("movb $T_INT, " ^ slot (h - 1));
                     line ("mov %rax, " ^ payload (h - 1));
                     put (done ^ ":\n")
                   end
                 else if opc = Opcodes.CLOSURE then
                   inlineAlloc (fn slow =>
                                  (alloc ("K_CLOSURE", 0, b + 1, slow);
                                   line ("movb $T_INT, " ^ field 0);
                                   line ("movq $" ^ num a ^ ", OBJ_FIELDS+8(%rax)");
                                   List.app (fn k => copy (slot (h - b + k), field (k + 1))) (List.tabulate (b, fn k => k));
                                   putPtr (h - b)),
                                fn () => callC ("native_closure", ["mov $" ^ num a ^ ", %esi", "mov $" ^ num b ^ ", %edx"]))
                 else if opc = Opcodes.SETENV then
                   (flushSp (); setPc (); callC ("native_setenv", ["mov $" ^ num a ^ ", %esi"]))
                 else if opc = Opcodes.CALL orelse opc = Opcodes.TAILCALL then
                   (* M10: the closure checked, its function index in range, the
                      frame pushed (or, for TAILCALL, kept), the argument moved
                      to the callee's local 0, where the closure was, and a jump
                      to the callee's fast entry; anything else, and a full
                      array of frames, is the glue's (native_call and
                      native_tailcall), as before M10. *)
                   let
                     val slow = lab pc ^ "_slow"
                     val tail = opc = Opcodes.TAILCALL
                     val newBase = num (16 * (nlocals + h - 2))
                   in
                     line ("cmpb $T_PTR, " ^ slot (h - 2));
                     line ("jne " ^ slow);
                     line ("mov " ^ payload (h - 2) ^ ", %rax");
                     line "cmpb $K_CLOSURE, OBJ_KIND(%rax)";
                     line ("jne " ^ slow);
                     line "mov OBJ_FIELDS+8(%rax), %rcx";
                     line ("cmp $" ^ num nfuncs ^ ", %rcx");
                     line ("jae " ^ slow);
                     if tail then
                       (line "mov VM_FRAMES(%r12), %rdx";
                        line "mov VM_FP(%r12), %rsi";
                        line "imul $FRAME_SIZE, %rsi, %rsi";
                        line "add %rsi, %rdx";
                        line "mov %ecx, FRAME_FUNC(%rdx)";
                        line "mov %rax, FRAME_CLOSURE(%rdx)";
                        copy (slot (h - 1), "(%r13,%rbp)"))
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
                        line "shr $4, %rsi";
                        line "mov %rsi, FRAME_BASE(%rdx)";
                        line "mov %rax, FRAME_CLOSURE(%rdx)";
                        line ("lea " ^ lab next ^ "(%rip), %rsi");
                        line "mov %rsi, FRAME_NATIVE_RET(%rdx)";
                        copy (slot (h - 1), slot (h - 2));
                        line ("lea " ^ newBase ^ "(%rbp), %rbp"));
                     line "lea rune_functions(%rip), %rdx";
                     line "lea (%rcx,%rcx,2), %rcx";
                     line "movslq 4(%rdx,%rcx,4), %rsi";
                     line "add %rdx, %rsi";
                     line "jmp *%rsi";
                     slows := (fn () =>
                                 (put (slow ^ ":\n"); flushSp (); setPc ();
                                  if tail then callC ("native_tailcall", [])
                                  else callC ("native_call", ["lea " ^ lab next ^ "(%rip), %rsi"]);
                                  line "jmp *%rax")) :: !slows
                   end
                 else if opc = Opcodes.RET then
                   (* M10: the result in local 0, where the caller wants it,
                      the frame popped, and a jump to where it returns; the
                      top level's RET ends the run in the glue. *)
                   let val slow = lab pc ^ "_slow"
                   in
                     line "mov VM_FP(%r12), %rdx";
                     line "test %rdx, %rdx";
                     line ("jz " ^ slow);
                     copy (slot (h - 1), "(%r13,%rbp)");
                     line "imul $FRAME_SIZE, %rdx, %rdx";
                     line "add VM_FRAMES(%r12), %rdx";
                     line "decq VM_FP(%r12)";
                     line "jmp *FRAME_NATIVE_RET(%rdx)";
                     slows := (fn () =>
                                 (put (slow ^ ":\n"); flushCount (); flushSp (); setPc ();
                                  callC ("native_ret", []); line "jmp *%rax")) :: !slows
                   end
                 else if opc = Opcodes.JUMP then line ("jmp " ^ lab a)
                 else if opc = Opcodes.JUMPIFNOT orelse opc = Opcodes.JUMPIF then
                   (line ("cmpb $T_CON0, " ^ slot (h - 1));
                    line ("jne " ^ check (pc, next, if opc = Opcodes.JUMPIF then fatalJumpIf else fatalJumpIfNot, 0));
                    line ("cmpq $0, " ^ payload (h - 1));
                    line ((if opc = Opcodes.JUMPIF then "jne " else "je ") ^ lab a))
                 else if opc = Opcodes.PUSHHANDLER then
                   (flushSp (); callC ("vm_push_handler", ["mov $" ^ num a ^ ", %esi"]))
                 else if opc = Opcodes.POPHANDLER then
                   (line "cmpq $0, VM_HP(%r12)";
                    line ("je " ^ check (pc, next, fatalPopHandler, 0));
                    line "decq VM_HP(%r12)")
                 else if opc = Opcodes.RAISE then
                   (flushCount (); flushSp (); setPc (); callC ("native_raise", []); line "jmp *%rax")
                 else if opc = Opcodes.NEWEXN then
                   inlineAlloc (fn slow =>
                                  (alloc ("K_EXNCON", 0, 1, slow);
                                   line "mov VM_CONSTS(%r12), %rcx";
                                   copy (num (16 * a) ^ "(%rcx)", field 0);
                                   putPtr h),
                                fn () => callC ("native_newexn", ["mov $" ^ num a ^ ", %esi"]))
                 else if opc = Opcodes.BUILTINEXN then
                   (line ("mov VM_BUILTIN_EXNS+" ^ num (8 * a) ^ "(%r12), %rax");
                    line ("movb $T_PTR, " ^ slot h);
                    line ("mov %rax, " ^ payload h))
                 else if opc = Opcodes.MKEXN then
                   (* a constructor that is none is the helper's to report,
                      after it has allocated, as the interpreter does *)
                   inlineAlloc (fn slow =>
                                  (line ("cmpb $T_PTR, " ^ slot (h - 2));
                                   line ("jne " ^ slow);
                                   line ("mov " ^ payload (h - 2) ^ ", %rcx");
                                   line "cmpb $K_EXNCON, OBJ_KIND(%rcx)";
                                   line ("jne " ^ slow);
                                   alloc ("K_EXN", 0, 2, slow);
                                   copy (slot (h - 2), field 0);
                                   copy (slot (h - 1), field 1);
                                   putPtr (h - 2)),
                                fn () => callC ("native_mkexn", []))
                 else if opc = Opcodes.EXNCON then
                   (expectObj (h - 1, "K_EXN", fatalExn); copy ("OBJ_FIELDS(%rax)", slot (h - 1)))
                 else if opc = Opcodes.EXNARG then
                   (expectObj (h - 1, "K_EXN", fatalExn); copy ("OBJ_FIELDS+16(%rax)", slot (h - 1)))
                 else if opc = Opcodes.PRIM then
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
                     case fastPrim (Vector.sub (primNames, a), h, pc, emitters) of
                       NONE => callPrim ()
                     | SOME fast =>
                         let val slow = lab pc ^ "_slow" val done = lab pc ^ "_done"
                         in
                           fast slow;
                           put (done ^ ":\n");
                           slows := (fn () => (put (slow ^ ":\n"); callPrim (); line ("jmp " ^ done))) :: !slows
                         end
                   end
                 else raise Fail ("no template for opcode " ^ Int.toString opc))
            end
          fun loop i = if i > last then () else (instruction i; loop (i + 1))
        in
          put ("\n\t# function " ^ Int.toString f ^ " " ^ String.toString name ^ " (locals " ^ Int.toString nlocals ^ ")\n");
          line ".p2align 4";
          line (".type " ^ sym ^ ", @function");
          put (sym ^ ":\n");
          cfiFrame ();
          (* the function's own position from its first byte, which is the
             address a debugger or addr2line is given for it *)
          (case Array.sub (lineStarts, offset) of ~1 => () | k => loc k);
          reloadFrame ();
          (* M10: the entry a CALL of the code jumps to, the frame already
             pushed and rbp its base: the room the frame needs, and its locals
             but the first set to unit, n stores where the glue had a loop *)
          put (".Le" ^ Int.toString f ^ ":\n");
          line ("lea " ^ num (16 * (nlocals + Vector.sub (#maxHeight facts, f))) ^ "(%rbp), %rax");
          line "shr $4, %rax";
          line "cmp VM_STACK_CAP(%r12), %rax";
          line ("ja .Lg" ^ Int.toString f);
          put (".Lh" ^ Int.toString f ^ ":\n");
          if nlocals > 1 then line "pxor %xmm1, %xmm1" else ();
          let fun units k = if k >= nlocals then () else (line ("movdqu %xmm1, " ^ localSlot k); units (k + 1))
          in units 1 end;
          slows := (fn () =>
                      (put (".Lg" ^ Int.toString f ^ ":\n");
                       line "mov %rax, %rsi"; line "mov %r12, %rdi"; line "call vm_grow_stack";
                       line reloadStack; line ("jmp .Lh" ^ Int.toString f))) :: !slows;
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
      put ("# Made by runeopt " ^ Config.version ^ " from " ^ String.toString rbc ^ " (docs/plans/codegen.md).\n");
      line ".include \"rune-offsets.s\"";
      Vector.appi (fn (k, file) => line (".file " ^ Int.toString (k + 1) ^ " " ^ quote file)) (#files p);
      line ".text";
      (* The way in from vm/native.c: the registers C wants kept are kept,
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
           line (".long " ^ symbol (name, f) ^ " - rune_functions, .Le" ^ Int.toString f ^ " - rune_functions, "
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
