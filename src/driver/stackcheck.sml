(* The check of a program's stack code (the linting roadmap's D11 and M10):
   the code as its file has it (Emit.serialize), read back as runevm-stack's
   loader reads it, every refusal of the loader's at the same point and with
   the same message (Rbc.read), and held to what runeopt relies on and the
   loader does not promise (RbcCheck: the stack's height and the handlers'
   depth the same on every path into an instruction, no jump out of a
   function, no RET or TAILCALL with a handler of the function installed,
   one arity for every function). Pipeline runs it after the stack stage of
   a whole program, and Main at a link of units of stack code, each from
   level 2 of the lint, or at every level where RUNE_RBCCHECK=1 says, and at
   none where 0 does (Pipeline.checkStack, a check of Pass.checkAt,
   "rbccheck"); a refusal is Error.Bug.

   Rbc and RbcCheck are runeopt's (src/opt), and the descriptions of the
   instructions they read src/isa's: they are built with the driver, after
   the compiler library, which they are not part of, and set
   Pipeline.stackCheck.

   RUNE_RBCCHECK_INJECT=KIND or KIND@N corrupts the N-th place (from 0) of
   that kind in the code the check is given, not in the code written, for
   the check's tests (tests/runner/oracles.sml, rbccheck); it says on stderr
   what it did, or that it found no place:
     underflow   a POP where a function begins
     height      a UNIT before a JUMP
     handler     a POPHANDLER where a function begins
     jump-out    a JUMP to a label of another function
     ret-handler a PUSHHANDLER before a RET, its handler a RET of its own
     local       a LOCAL of a local the function has not *)
structure StackCheck =
struct
  structure C = Code

  fun inject (p : C.program) : C.program =
    case OS.Process.getEnv "RUNE_RBCCHECK_INJECT" of
      NONE => p
    | SOME "" => p
    | SOME spec =>
        let
          val (kind, nth) =
            case String.tokens (fn ch => ch = #"@") spec of
              [k, n] => (k, case Int.fromString n of SOME n => n | NONE => 0)
            | _ => (spec, 0)
          val seen = ref 0
          val did = ref ""
          fun hit () = (seen := !seen + 1; !seen - 1 = nth)
          (* a label no function has, for a handler of its own *)
          val fresh =
            1 + List.foldl (fn (f : C.func, m) =>
                              List.foldl (fn (C.Lab l, m) => Int.max (l, m) | (_, m) => m) m (#code f))
                           0 (#funcs p)
          (* the labels of each function, for a jump out of one *)
          val labels = List.map (fn (f : C.func) => (#id f, List.mapPartial (fn C.Lab l => SOME l | _ => NONE) (#code f)))
                                (#funcs p)
          fun elsewhere id = List.find (fn (id', ls) => id' <> id andalso not (List.null ls)) labels
          fun func (f : C.func) : C.func =
            let
              fun note what = did := what ^ " in " ^ #name f ^ " (f" ^ Int.toString (#id f) ^ ")"
              fun start code =
                case kind of
                  "underflow" => if hit () then (note "POP where it begins"; C.Op (Opcodes.POP, []) :: code) else code
                | "handler" => if hit () then (note "POPHANDLER where it begins"; C.Op (Opcodes.POPHANDLER, []) :: code) else code
                | _ => code
              fun go items =
                case items of
                  [] => []
                | (it as C.OpLab (opc, l)) :: rest =>
                    if opc = Opcodes.JUMP andalso kind = "height" andalso hit ()
                    then (note "UNIT before a JUMP"; C.Op (Opcodes.UNIT, []) :: it :: go rest)
                    else if opc = Opcodes.JUMP andalso kind = "jump-out" then
                      (case elsewhere (#id f) of
                         SOME (other, l' :: _) =>
                           if hit () then (note ("a JUMP to L" ^ Int.toString l' ^ " of f" ^ Int.toString other); C.OpLab (opc, l') :: go rest)
                           else it :: go rest
                       | _ => it :: go rest)
                    else it :: go rest
                | (it as C.Op (opc, args)) :: rest =>
                    if opc = Opcodes.RET andalso kind = "ret-handler" andalso hit ()
                    then (note "PUSHHANDLER before a RET";
                          C.OpLab (Opcodes.PUSHHANDLER, fresh) :: it :: C.Lab fresh :: C.Op (Opcodes.RET, []) :: go rest)
                    else if opc = Opcodes.LOCAL andalso kind = "local" andalso hit ()
                    then (note ("LOCAL " ^ Int.toString (#nlocals f + 3)); C.Op (opc, [#nlocals f + 3]) :: go rest)
                    else it :: go rest
                | it :: rest => it :: go rest
            in
              {id = #id f, nlocals = #nlocals f, code = go (start (#code f)), name = #name f, meta = #meta f}
            end
          val funcs = List.map func (#funcs p)
        in
          TextIO.output (TextIO.stdErr, "rbccheck inject " ^ spec ^ ": " ^ (if !did = "" then "no place found" else !did) ^ "\n");
          {consts = #consts p, nglobals = #nglobals p, funcs = funcs, files = #files p, inlines = #inlines p,
           nlabels = Int.max (#nlabels p, fresh + 1), globalReps = #globalReps p, expects = #expects p}
        end

  fun check (p : C.program) : unit =
    let
      val bytes = String.concat (Emit.serialize (Opcodes.fingerprint, inject p))
    in
      ignore (RbcCheck.check (Rbc.read bytes))
      handle Rbc.Bad why => Error.bug ("the loader refuses the stack code: " ^ why)
           | RbcCheck.Refused why => Error.bug ("the stack code breaks what runeopt relies on: " ^ why)
    end

  val () = Pipeline.stackCheck := check
end
