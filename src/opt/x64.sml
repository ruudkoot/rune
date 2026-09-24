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

  fun write (put : string -> unit, p : Rbc.program, facts : RbcCheck.facts,
             {rbc : string, rbcSize : int, options : string}) : unit =
    let
      val instrs = #instrs facts
      val n = Vector.length instrs
      val funcs = #funcs p
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

      (* the line table, as .loc where an entry begins *)
      val lineStarts = Array.array (codeLen + 1, ~1)
      val () = Vector.appi (fn (k, {pc, ...} : Rbc.line) => Array.update (lineStarts, pc, k)) (#lines p)

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
          val first = Array.sub (index, offset)
          fun lastOf i = if i + 1 < n andalso #pc (ins (i + 1)) < stop then lastOf (i + 1) else i
          val last = lastOf first
          fun slot k = num (16 * (nlocals + k)) ^ "(%r13,%rbp)"
          fun payload k = num (16 * (nlocals + k) + 8) ^ "(%r13,%rbp)"
          fun localSlot l = num (16 * l) ^ "(%r13,%rbp)"
          fun copy (from, to) = (line ("movdqu " ^ from ^ ", %xmm0"); line ("movdqu %xmm0, " ^ to))
          fun put0 (tag, value, k) = (line ("movb $" ^ tag ^ ", " ^ slot k); line ("movq $" ^ value ^ ", " ^ payload k))
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
              fun expectObj (k, kind, what) =
                (line ("cmpb $T_PTR, " ^ slot k);
                 line ("jne " ^ check (pc, next, what, 0));
                 line ("mov " ^ payload k ^ ", %rax");
                 line ("cmpb $" ^ kind ^ ", OBJ_KIND(%rax)");
                 line ("jne " ^ check (pc, next, what, 0)))
              val () = put (lab pc ^ ":\t# " ^ Vector.sub (Opcodes.names, opc)
                            ^ (case Vector.sub (Opcodes.nargs, opc) of 0 => "" | 1 => " " ^ num a | _ => " " ^ num a ^ " " ^ num b)
                            ^ "\n")
              val () =
                case Array.sub (lineStarts, pc) of
                  ~1 => ()
                | k => let val {file, line = l, col, ...} = Vector.sub (#lines p, k)
                       in line (".loc " ^ Int.toString (file + 1) ^ " " ^ Int.toString l ^ " " ^ Int.toString col) end
            in
              if h < 0 then line "ud2"
              else
                ((if afterCall i orelse Array.sub (handler, i) then reloadFrame () else ());
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
                   else (flushSp (); setPc (); callC ("native_tuple", ["mov $" ^ num a ^ ", %esi"]); line reloadStack)
                 else if opc = Opcodes.SELECT then
                   (expectObj (h - 1, "K_TUPLE", fatalTuple);
                    line ("cmpl $" ^ num a ^ ", OBJ_LEN(%rax)");
                    line ("jbe " ^ check (pc, next, fatalSelect, a));
                    copy ("OBJ_FIELDS+" ^ num (16 * a) ^ "(%rax)", slot (h - 1)))
                 else if opc = Opcodes.CON then
                   (flushSp (); setPc (); callC ("native_con", ["mov $" ^ num a ^ ", %esi"]); line reloadStack)
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
                   (flushSp (); setPc ();
                    callC ("native_closure", ["mov $" ^ num a ^ ", %esi", "mov $" ^ num b ^ ", %edx"]);
                    line reloadStack)
                 else if opc = Opcodes.SETENV then
                   (flushSp (); setPc (); callC ("native_setenv", ["mov $" ^ num a ^ ", %esi"]))
                 else if opc = Opcodes.CALL then
                   (flushSp (); setPc (); callC ("native_call", ["lea " ^ lab next ^ "(%rip), %rsi"]); line "jmp *%rax")
                 else if opc = Opcodes.TAILCALL then
                   (flushSp (); setPc (); callC ("native_tailcall", []); line "jmp *%rax")
                 else if opc = Opcodes.RET then
                   (flushCount (); flushSp (); setPc (); callC ("native_ret", []); line "jmp *%rax")
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
                   (flushSp (); setPc (); callC ("native_newexn", ["mov $" ^ num a ^ ", %esi"]); line reloadStack)
                 else if opc = Opcodes.BUILTINEXN then
                   (line ("mov VM_BUILTIN_EXNS+" ^ num (8 * a) ^ "(%r12), %rax");
                    line ("movb $T_PTR, " ^ slot h);
                    line ("mov %rax, " ^ payload h))
                 else if opc = Opcodes.MKEXN then
                   (flushSp (); setPc (); callC ("native_mkexn", []); line reloadStack)
                 else if opc = Opcodes.EXNCON then
                   (expectObj (h - 1, "K_EXN", fatalExn); copy ("OBJ_FIELDS(%rax)", slot (h - 1)))
                 else if opc = Opcodes.EXNARG then
                   (expectObj (h - 1, "K_EXN", fatalExn); copy ("OBJ_FIELDS+16(%rax)", slot (h - 1)))
                 else if opc = Opcodes.PRIM then
                   (flushCount (); flushSp (); setPc ();
                    line "mov %r12, %rdi";
                    line "lea prim_table(%rip), %rax";
                    line ("call *" ^ num (8 * a) ^ "(%rax)");
                    line "test %eax, %eax";
                    line "jnz rune_unusual";
                    line reloadStack)
                 else raise Fail ("no template for opcode " ^ Int.toString opc))
            end
          fun loop i = if i > last then () else (instruction i; loop (i + 1))
        in
          put ("\n\t# function " ^ Int.toString f ^ " " ^ String.toString name ^ " (locals " ^ Int.toString nlocals ^ ")\n");
          line ".p2align 4";
          line (".type " ^ sym ^ ", @function");
          put (sym ^ ":\n");
          reloadFrame ();
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
      List.app line ["push %rbp", "push %rbx", "push %r12", "push %r13", "push %r14", "push %r15",
                     "sub $8, %rsp", "mov %rdi, %r12", "mov VM_INSTRUCTIONS(%r12), %r15", "jmp *%rsi"];
      line ".size rune_enter, .-rune_enter";
      (* a primitive that raised, or replaced the program *)
      put "rune_unusual:\n";
      List.app line ["mov %eax, %esi", "mov %r12, %rdi", "call native_unusual", "jmp *%rax"];
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
           line (".long " ^ symbol (name, f) ^ " - rune_functions, " ^ Int.toString (Vector.sub (#maxHeight facts, f))))
        funcs;
      line ".globl rune_handlers";
      put "rune_handlers:\n";
      List.app (fn pc => line (".long " ^ Int.toString pc ^ ", " ^ lab pc ^ " - rune_handlers")) handlerPcs;
      line ".globl rune_nhandlers";
      put "rune_nhandlers:\n";
      line (".long " ^ Int.toString (List.length handlerPcs));
      line ".globl rune_options";
      put "rune_options:\n";
      line (".asciz " ^ quote options);
      line ".section .note.GNU-stack,\"\",@progbits"
    end
end
