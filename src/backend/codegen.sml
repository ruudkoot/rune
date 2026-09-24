(* Code generation: Lambda IR to stack bytecode with flat closure conversion. *)
structure Codegen =
struct
  open Lambda

  datatype item =
      Op of int * int list                (* opcode, immediate operands *)
    | OpLab of int * int                  (* opcode with one label operand *)
    | OpLabImm of int * int * int         (* opcode with a label operand, then an immediate *)
    | Lab of int
    | Pos of int * int * int              (* file, line, column of what follows *)

  type func = {id : int, nlocals : int, code : item list, name : string}

  (* nlabels: the labels of the program are numbered from 0 up to it. *)
  type program = {consts : const list, nglobals : int, funcs : func list, files : string list, nlabels : int}

  (* ---------------------------------------------------------------- *)
  (* Free variables (sorted by stamp).                                  *)

  (* Those of each function, by the stamp of its parameter, worked out once:
     a function's are those of its body, where a function nested in it
     counts with its own, already worked out, so that no part of the program
     is walked again for every function around it. *)
  val freeMemo : int list IntMap.map ref = ref IntMap.empty

  fun fnFree (x : int, body : lexp) : int list =
    case IntMap.find (!freeMemo, x) of
      SOME vs => vs
    | NONE =>
      let val vs = IntMap.listKeys (fv (body, IntMap.insert (IntMap.empty, x, ()), IntMap.empty))
      in freeMemo := IntMap.insert (!freeMemo, x, vs); vs end
  and fv (e, bound : unit IntMap.map, acc : unit IntMap.map) =
    case e of
      Var v => if IntMap.member (bound, v) then acc else IntMap.insert (acc, v, ())
    | Global _ => acc | Const _ => acc | Unit => acc | Con0 _ => acc | Fail => acc
    | NewExn _ => acc | BuiltinExn _ => acc
    | Fn (x, _, b) =>
        List.foldl (fn (v, acc) => if IntMap.member (bound, v) then acc else IntMap.insert (acc, v, ()))
                   acc (fnFree (x, b))
    | Inst (a, _) => fv (a, bound, acc)
    | App (a, b) => fv (b, bound, fv (a, bound, acc))
    | Let (x, a, b) => fv (b, IntMap.insert (bound, x, ()), fv (a, bound, acc))
    | LetRec (bs, b) =>
        let val bound' = List.foldl (fn ((x, _, _), m) => IntMap.insert (m, x, ())) bound bs
        in List.foldl (fn ((_, _, e), acc) => fv (e, bound', acc)) (fv (b, bound', acc)) bs end
    | Seq (a, b) => fv (b, bound, fv (a, bound, acc))
    | SetGlobal (_, a) => fv (a, bound, acc)
    | Mark (_, a) => fv (a, bound, acc)
    | Tuple es => List.foldl (fn (e, acc) => fv (e, bound, acc)) acc es
    | Select (_, a) => fv (a, bound, acc)
    | Con (_, _, a) => fv (a, bound, acc)
    | Decon (_, a) => fv (a, bound, acc)
    | ConTag a => fv (a, bound, acc)
    | If (c, t, f) => fv (f, bound, fv (t, bound, fv (c, bound, acc)))
    | Try (a, b) => fv (b, bound, fv (a, bound, acc))
    | Raise a => fv (a, bound, acc)
    | Handle (a, x, h) => fv (h, IntMap.insert (bound, x, ()), fv (a, bound, acc))
    | MkExn (c, p) => fv (p, bound, fv (c, bound, acc))
    | ExnCon a => fv (a, bound, acc)
    | ExnArg (_, a) => fv (a, bound, acc)
    | Prim (_, _, args) => List.foldl (fn (e, acc) => fv (e, bound, acc)) acc args

  (* ---------------------------------------------------------------- *)
  (* Program-wide state.                                                *)
  val funcs : func list ref = ref []
  val nextFuncId = ref 0
  val consts : const list ref = ref []
  val nconsts = ref 0
  val constIndex : int StringMap.map ref = ref StringMap.empty
  val globals : int IntMap.map ref = ref IntMap.empty
  val nglobals = ref 0
  val nextLabel = ref 0
  (* The source files positions refer to, in the order they were first seen;
     an index into this is what the line table holds. *)
  val files : string list ref = ref []
  val nfiles = ref 0
  val fileIndex : int StringMap.map ref = ref StringMap.empty
  (* What the source called each function, by the stamp of its parameter;
     `compile` is given it by the translation. *)
  val funNames : string IntMap.map ref = ref IntMap.empty

  (* The file numbered last, since positions come file by file. *)
  val lastFile : (string * int) option ref = ref NONE

  fun reset () =
    (funcs := []; nextFuncId := 0; consts := []; nconsts := 0; constIndex := StringMap.empty;
     globals := IntMap.empty; nglobals := 0; nextLabel := 0; funNames := IntMap.empty;
     files := []; nfiles := 0; fileIndex := StringMap.empty; lastFile := NONE;
     freeMemo := IntMap.empty)

  fun fileIdx (name : string) : int =
    case !lastFile of
      SOME (n, i) => if n = name then i else fileIdx' name
    | NONE => fileIdx' name
  and fileIdx' name =
    let
      val i =
        case StringMap.find (!fileIndex, name) of
          SOME i => i
        | NONE =>
          let val i = !nfiles
          in files := name :: !files; nfiles := i + 1;
             fileIndex := StringMap.insert (!fileIndex, name, i); i
          end
    in
      lastFile := SOME (name, i); i
    end

  fun newLabel () = let val l = !nextLabel in nextLabel := l + 1; l end

  fun constKey c =
    case c of
      CInt i => "i:" ^ IntInf.toString i
    | CWord w => "w:" ^ IntInf.toString w
    | CReal r => "r:" ^ r
    | CString s => "s:" ^ s
    | CChar c => "c:" ^ Int.toString c

  fun constIdx c =
    let val key = constKey c
    in
      case StringMap.find (!constIndex, key) of
        SOME i => i
      | NONE =>
        let val i = !nconsts
        in consts := c :: !consts; nconsts := i + 1; constIndex := StringMap.insert (!constIndex, key, i); i end
    end

  fun globalIdx g =
    case IntMap.find (!globals, g) of
      SOME i => i
    | NONE => let val i = !nglobals in globals := IntMap.insert (!globals, g, i); nglobals := i + 1; i end

  fun primIdx name =
    case Prims.find name of
      SOME (i, _) => i
    | NONE => Error.bug ("unknown primitive " ^ name)

  (* immediates are kept within 31 bits so that every host SML Int can hold them *)
  val int32Max : IntInf.int = IntInf.fromInt 1073741823
  val int32Min : IntInf.int = IntInf.fromInt ~1073741824

  (* ---------------------------------------------------------------- *)
  type ctx = {locals : int IntMap.map ref, nlocals : int ref, env : int IntMap.map,
              self : int option, code : item list ref, fails : int list ref,
              pos : (int * int * int) ref}

  fun emit (ctx : ctx, it) = #code ctx := it :: !(#code ctx)

  (* Note where the instructions that follow came from. A span the source was
     not loaded for, and one that repeats the position already in force, cost
     nothing: the line table holds only the places where it changes. *)
  fun markPos (ctx : ctx, sp : Source.span) : unit =
    case Source.lineColOf sp of
      NONE => ()
    | SOME (file, line, col) =>
      let val p = (fileIdx file, line, col)
      in if p = !(#pos ctx) then () else (#pos ctx := p; emit (ctx, Pos p)) end

  fun newLocal (ctx : ctx, x) =
    let val slot = !(#nlocals ctx)
    in #nlocals ctx := slot + 1; #locals ctx := IntMap.insert (!(#locals ctx), x, slot); slot end

  fun loadVar (ctx : ctx, v) =
    case IntMap.find (!(#locals ctx), v) of
      SOME s => emit (ctx, Op (Opcodes.LOCAL, [s]))
    | NONE =>
      if #self ctx = SOME v then emit (ctx, Op (Opcodes.SELF, []))
      else
        case IntMap.find (#env ctx, v) of
          SOME i => emit (ctx, Op (Opcodes.ENV, [i]))
        | NONE => Error.bug ("codegen: unbound variable v" ^ Int.toString v)

  fun gen (ctx : ctx, e : lexp, tail : bool) : unit =
    case e of
      Var v => loadVar (ctx, v)
    | Global g => emit (ctx, Op (Opcodes.GLOBAL, [globalIdx g]))
    | Const (CInt i, _) =>
        if IntInf.>= (i, int32Min) andalso IntInf.<= (i, int32Max) then emit (ctx, Op (Opcodes.INT, [IntInf.toInt i]))
        else emit (ctx, Op (Opcodes.CONST, [constIdx (CInt i)]))
    | Const (c, _) => emit (ctx, Op (Opcodes.CONST, [constIdx c]))
    | Inst (a, _) => gen (ctx, a, tail)
    | Unit => emit (ctx, Op (Opcodes.UNIT, []))
    | Mark (sp, a) => (markPos (ctx, sp); gen (ctx, a, tail))
    | Fn (x, _, b) => ignore (genClosure (ctx, x, b, NONE, []))
    | App (f, a) =>
        (gen (ctx, f, false); gen (ctx, a, false);
         emit (ctx, Op (if tail then Opcodes.TAILCALL else Opcodes.CALL, [])))
    | Let (x, a, b) =>
        (gen (ctx, a, false);
         emit (ctx, Op (Opcodes.SETLOCAL, [newLocal (ctx, x)]));
         gen (ctx, b, tail))
    | LetRec (bs, b) => (genLetRec (ctx, bs); gen (ctx, b, tail))
    | Seq (a, b) => (gen (ctx, a, false); emit (ctx, Op (Opcodes.POP, [])); gen (ctx, b, tail))
    | SetGlobal (g, a) =>
        (gen (ctx, a, false); emit (ctx, Op (Opcodes.SETGLOBAL, [globalIdx g])); emit (ctx, Op (Opcodes.UNIT, [])))
    | Tuple es => (List.app (fn e => gen (ctx, e, false)) es; emit (ctx, Op (Opcodes.TUPLE, [List.length es])))
    | Select (i, a) => (gen (ctx, a, false); emit (ctx, Op (Opcodes.SELECT, [i])))
    | Con0 (t, _) => emit (ctx, Op (Opcodes.CON0, [t]))
    | Con (t, _, a) => (gen (ctx, a, false); emit (ctx, Op (Opcodes.CON, [t])))
    | Decon (_, a) => (gen (ctx, a, false); emit (ctx, Op (Opcodes.DECON, [])))
    | ConTag a => (gen (ctx, a, false); emit (ctx, Op (Opcodes.CONTAG, [])))
    | If (c, t, f) =>
        let
          val lElse = newLabel ()
          val lEnd = newLabel ()
        in
          (* The test of a match against a constructor (MatchComp.testTag)
             is one instruction, where it would be CONTAG, INT t, PRIM
             poly_eq and JUMPIFNOT: 17% of the instructions the compiler
             ran compiling itself (docs/plans/codegen.md, M13). *)
          (case c of
             Prim ("poly_eq", _, [ConTag a, Const (CInt i, _)]) =>
               if IntInf.>= (i, int32Min) andalso IntInf.<= (i, int32Max) then
                 (gen (ctx, a, false); emit (ctx, OpLabImm (Opcodes.JUMPIFNOTTAG, lElse, IntInf.toInt i)))
               else (gen (ctx, c, false); emit (ctx, OpLab (Opcodes.JUMPIFNOT, lElse)))
           | _ => (gen (ctx, c, false); emit (ctx, OpLab (Opcodes.JUMPIFNOT, lElse))));
          gen (ctx, t, tail);
          emit (ctx, OpLab (Opcodes.JUMP, lEnd));
          emit (ctx, Lab lElse);
          gen (ctx, f, tail);
          emit (ctx, Lab lEnd)
        end
    | Try (a, b) =>
        let
          val lFail = newLabel ()
          val lEnd = newLabel ()
        in
          #fails ctx := lFail :: !(#fails ctx);
          gen (ctx, a, tail);
          #fails ctx := List.tl (!(#fails ctx));
          emit (ctx, OpLab (Opcodes.JUMP, lEnd));
          emit (ctx, Lab lFail);
          gen (ctx, b, tail);
          emit (ctx, Lab lEnd)
        end
    | Fail =>
        (case !(#fails ctx) of
           l :: _ => emit (ctx, OpLab (Opcodes.JUMP, l))
         | [] => Error.bug "codegen: Fail outside Try")
    | Raise a => (gen (ctx, a, false); emit (ctx, Op (Opcodes.RAISE, [])))
    | Handle (a, x, h) =>
        let
          val lH = newLabel ()
          val lEnd = newLabel ()
        in
          emit (ctx, OpLab (Opcodes.PUSHHANDLER, lH));
          gen (ctx, a, false);
          emit (ctx, Op (Opcodes.POPHANDLER, []));
          emit (ctx, OpLab (Opcodes.JUMP, lEnd));
          emit (ctx, Lab lH);
          emit (ctx, Op (Opcodes.SETLOCAL, [newLocal (ctx, x)]));
          gen (ctx, h, tail);
          emit (ctx, Lab lEnd)
        end
    | NewExn n => emit (ctx, Op (Opcodes.NEWEXN, [constIdx (CString n)]))
    | BuiltinExn k => emit (ctx, Op (Opcodes.BUILTINEXN, [k]))
    | MkExn (c, p) => (gen (ctx, c, false); gen (ctx, p, false); emit (ctx, Op (Opcodes.MKEXN, [])))
    | ExnCon a => (gen (ctx, a, false); emit (ctx, Op (Opcodes.EXNCON, [])))
    | ExnArg (_, a) => (gen (ctx, a, false); emit (ctx, Op (Opcodes.EXNARG, [])))
    | Prim (p, _, args) => (List.app (fn e => gen (ctx, e, false)) args; emit (ctx, Op (Opcodes.PRIM, [primIdx p])))

  (* Compile a function body into a new function; returns its id. *)
  and genFunction (param : int, body : lexp, envVars : int list, self : int option, name : string,
                   pos0 : int * int * int) : int =
    let
      val id = !nextFuncId
      val () = nextFuncId := id + 1
      val env = #1 (List.foldl (fn (v, (m, i)) => (IntMap.insert (m, v, i), i + 1)) (IntMap.empty, 0) envVars)
      val ctx : ctx = {locals = ref (IntMap.insert (IntMap.empty, param, 0)), nlocals = ref 1, env = env,
                       self = self, code = ref [], fails = ref [], pos = ref (~1, ~1, ~1)}
      (* The code of a function begins where the function does, so that an
         instruction before the first mark of its body is not attributed to
         whatever was compiled before it. *)
      val () = if pos0 = (~1, ~1, ~1) then () else (#pos ctx := pos0; emit (ctx, Pos pos0))
    in
      gen (ctx, body, true);
      emit (ctx, Op (Opcodes.RET, []));
      funcs := {id = id, nlocals = !(#nlocals ctx), code = List.rev (!(#code ctx)), name = name} :: !funcs;
      id
    end

  (* Create a closure for Fn (x, body) in ctx. `pending` are letrec group
     members not yet created; loading them pushes a placeholder to be patched. *)
  and genClosure (ctx : ctx, x : int, body : lexp, self : int option, pending : int list)
      : (int * int) list =
    let
      val fvs = List.filter (fn v => SOME v <> self) (fnFree (x, body))
      (* The name the source gave this function, by the stamp of its
         parameter (Translate.funNames). One that no binding names keeps
         `fn`, with its own stamp where it is recursive, so that two of them
         can still be told apart in a disassembly. *)
      val name =
        case IntMap.find (!funNames, x) of
          SOME n => n
        | NONE => (case self of SOME s => "fn" ^ Int.toString s | NONE => "fn")
      val fid = genFunction (x, body, fvs, self, name, !(#pos ctx))
      val patches =
        #1 (List.foldl (fn (v, (ps, i)) =>
                          if List.exists (fn p => p = v) pending then
                            (emit (ctx, Op (Opcodes.UNIT, [])); ((i, v) :: ps, i + 1))
                          else (loadVar (ctx, v); (ps, i + 1))) ([], 0) fvs)
    in
      emit (ctx, Op (Opcodes.CLOSURE, [fid, List.length fvs]));
      patches
    end

  (* The expression under its marks, with each put in force on the way: for
     an expression whose shape is looked at rather than generated, so that it
     is still compiled where the source says it is. *)
  and markThrough (ctx : ctx, e : lexp) : lexp =
    case e of
      Mark (sp, a) => (markPos (ctx, sp); markThrough (ctx, a))
    | _ => e

  and genLetRec (ctx : ctx, bs : (int * Ty.ty * lexp) list) : unit =
    let
      val bs = List.map (fn (f, _, e) => (f, e)) bs
      val slots = List.map (fn (f, _) => (f, newLocal (ctx, f))) bs
      fun slotOf f = case List.find (fn (g, _) => g = f) slots of SOME (_, s) => s | NONE => Error.bug "letrec slot"
      fun go ([], _) = []
        | go ((f, e) :: rest, pending) =
          let
            val pending' = List.map #1 rest
            val patches =
              case markThrough (ctx, e) of
                Fn (x, _, body) => genClosure (ctx, x, body, SOME f, pending')
              | _ => Error.bug "letrec right-hand side is not a function"
            val () = emit (ctx, Op (Opcodes.SETLOCAL, [slotOf f]))
          in List.map (fn (i, v) => (f, i, v)) patches @ go (rest, pending) end
      val allPatches = go (bs, [])
    in
      List.app (fn (f, i, v) =>
                  (emit (ctx, Op (Opcodes.LOCAL, [slotOf f]));
                   emit (ctx, Op (Opcodes.LOCAL, [slotOf v]));
                   emit (ctx, Op (Opcodes.SETENV, [i])))) allPatches
    end

  (* ---------------------------------------------------------------- *)
  fun compile (top : lexp, names : string IntMap.map) : program =
    let
      val () = reset ()
      val () = funNames := names
      val dummyParam = Elaborate.freshStamp ()
      val _ = genFunction (dummyParam, top, [], NONE, "<toplevel>", (~1, ~1, ~1))
      val sorted = IntMap.listItems (List.foldl (fn (f : func, m) => IntMap.insert (m, #id f, f)) IntMap.empty (!funcs))
    in
      {consts = List.rev (!consts), nglobals = !nglobals, funcs = sorted, files = List.rev (!files),
       nlabels = !nextLabel}
    end

  (* ---------------------------------------------------------------- *)
  fun itemToString it =
    case it of
      Op (opc, args) => "    " ^ Vector.sub (Opcodes.names, opc) ^ " " ^ String.concatWith " " (List.map Int.toString args)
    | OpLab (opc, l) => "    " ^ Vector.sub (Opcodes.names, opc) ^ " L" ^ Int.toString l
    | OpLabImm (opc, l, i) => "    " ^ Vector.sub (Opcodes.names, opc) ^ " L" ^ Int.toString l ^ " " ^ Int.toString i
    | Lab l => "  L" ^ Int.toString l ^ ":"
    | Pos (f, l, c) => "  ; " ^ Int.toString f ^ ":" ^ Int.toString l ^ ":" ^ Int.toString c

  (* The instructions of a program, for --pass-stats. *)
  fun size ({funcs, ...} : program) : int =
    List.foldl (fn ({code, ...} : func, n) =>
                  List.foldl (fn (Lab _, n) => n | (Pos _, n) => n | (_, n) => n + 1) n code) 0 funcs

  fun dump (p : program) : string =
    let
      val cs = String.concat (#1 (List.foldl (fn (c, (acc, i)) => (acc @ ["const " ^ Int.toString i ^ " = " ^ constToString c ^ "\n"], i + 1)) ([], 0) (#consts p)))
      val fs = String.concat (List.map (fn f => "function " ^ Int.toString (#id f) ^ " " ^ #name f ^ " (locals " ^ Int.toString (#nlocals f) ^ ")\n" ^
                                           String.concat (List.map (fn it => itemToString it ^ "\n") (#code f))) (#funcs p))
    in cs ^ "globals " ^ Int.toString (#nglobals p) ^ "\n" ^ fs end
end
