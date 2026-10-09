(* The resident compiler (docs/repl.md; the incremental roadmap's D9 and M4):
   the compiler, in the program it compiles for, compiling one top-level
   declaration at a time as a unit (docs/units.md) and linking it into the
   running program with Runtime.link.

   The REPL program is itself units: the files of the Basis Library the
   compiler uses, the compiler, the REPL, loaded one by one, so that what
   they export is in the VM's table (runtime/loader.c). The units a
   declaration makes name the Basis's by the stamps they were compiled
   with, which this session must give them too: `start` compiles the same
   Basis files again, in the same order and in the same way, and the
   compiler being deterministic, it gives each the stamps it had -- which
   the unit it makes, the same bytes as the unit file the REPL was loaded
   from, shows (one Basis for the REPL and for what it compiles: D8).
   Everything after starts above all of those stamps, so that what a
   declaration declares is never taken for something of the REPL's own. *)
structure ReplSession =
struct
  exception Failed of string

  val env : Env.env ref = ref Env.initial
  val fixity : Fixity.env ref = ref Fixity.initial
  val session : string ref = ref ""
  val fingerprint : int ref = ref 0
  (* the declarations compiled so far, for the names of their sources *)
  val count : int ref = ref 0
  (* whether a declaration's values are echoed: not those of the REPL's own
     declarations at start *)
  val quiet : bool ref = ref false

  fun readBytes (path : string) : string =
    let val inp = BinIO.openIn path
    in Byte.bytesToString (BinIO.inputAll inp) before BinIO.closeIn inp end

  (* A unit, elaborated, made into the bytes of its file, of this session *)
  fun unitBytes (decs : Ast.dec list) : string =
    String.concat (UnitFile.chunks (!fingerprint, !session, Pipeline.unitOf decs))

  (* start {units, sources, lib}: the units the REPL program was loaded from
     and the source of each, as the build named them; the Basis's among them
     compiled again, from lib's files, each held to its unit's file *)
  fun start {units : string list, sources : string list, lib : string} : unit =
    let
      val () = Pass.whole := false
      val () = Elaborate.recover := false
      val () =
        case units of
          first :: _ =>
            (let val (fp, s, _) = UnitFile.read (readBytes first)
             in fingerprint := fp; session := s end
             handle UnitFile.Bad why => raise Failed (first ^ ": " ^ why))
        | [] => raise Failed "no units to start from"
      (* the Basis's units: those of the build's library, up to the first
         that is not *)
      fun basisFile name =
        case String.fields (fn c => c = #"/") name of
          parts => List.length parts >= 2 andalso List.nth (parts, List.length parts - 2) = "basis"
      fun replay ((unit, name) :: rest) =
            if not (basisFile name) then ()
            else
              let
                val path = OS.Path.joinDirFile {dir = lib ^ "/basis", file = OS.Path.file name}
                val text = #text (Source.readFile path)
                val file = Source.fromString (name, text)
                val () = Source.register file
                val (decs, fx) = Parser.parseTokensWith (Lexer.tokenize file, !fixity)
                val () = fixity := fx
                val () = Elaborate.allowPrim := true
                val () = Elaborate.elabTop (env, decs)
                val () = Elaborate.finish ()
                val () = Error.warnings := []
                val bytes = unitBytes decs
              in
                if bytes = readBytes unit then replay rest
                else raise Failed ("the library at " ^ lib ^ " is not the one the REPL was built with: " ^ OS.Path.file name)
              end
        | replay [] = ()
      val () = replay (ListPair.zip (units, sources))
    in
      Elaborate.allowPrim := false;
      (* above every stamp of the REPL's own units *)
      if !Elaborate.stampCounter < 0x20000000 then Elaborate.stampCounter := 0x20000000 else ()
    end

  (* The values a declaration bound, in the order of their names, with
     their types: what the REPL echoes *)
  fun bound (delta : Env.env) : (string * Types.ty) list =
    StringMap.foldri (fn (n, Env.Val {scheme, ...}, acc) => (n, scheme) :: acc | (_, _, acc) => acc) []
                     (Env.vals delta)

  (* The other things a declaration declared, as the REPL echoes them *)
  fun declared (delta : Env.env) : string list =
    let
      fun con (name, Env.Con {scheme, info}) =
            if #hasArg info then
              case Types.prune scheme of
                Types.TArrow (a, _) => name ^ " of " ^ Types.toString a
              | _ => name
            else name
        | con (name, _) = name
      fun params (Env.TyStr {fcn = Types.TName c, ...}) =
            (case #arity c of
               0 => ""
             | 1 => "'a "
             | k => "(" ^ String.concatWith ", " (List.tabulate (k, fn i => "'" ^ String.str (Char.chr (97 + i)))) ^ ") ")
        | params _ = ""
      val tys = StringMap.foldri (fn (n, Env.TyStr {cons = [], ...}, acc) => ("type " ^ n) :: acc
                                   | (n, ts as Env.TyStr {cons, ...}, acc) =>
                                       ("datatype " ^ params ts ^ n ^ " = " ^ String.concatWith " | " (List.map con cons)) :: acc)
                                 [] (Env.tys delta)
      val exns = StringMap.foldri (fn (n, Env.Exn _, acc) => ("exception " ^ n) :: acc | (_, _, acc) => acc) []
                                  (Env.vals delta)
      val strs = StringMap.foldri (fn (n, _, acc) => ("structure " ^ n) :: acc) [] (Env.strs delta)
    in tys @ exns @ strs end

  (* compile decs: the declarations elaborated against the session, and the
     printer of what they bind with them (ReplShow), made into a unit and
     linked; the function that runs it, what they bind, which the REPL adds
     to the session once it has run -- a declaration that raises binds
     nothing (Chapter 8), while what it compiled as it ran (a nested `use`)
     is the session's already -- and what to echo of what is not a value.
     A declaration that does not elaborate leaves the session as it was and
     raises Error.CompileError, as the batch compiler does. *)
  fun compile (decs : Ast.dec list) : {run : unit -> unit, delta : Env.env, declared : string list} =
    let
      val saved = Elaborate.snapshot ()
      val here = ref (!env)
    in
      (let
         val () = Elaborate.allowPrim := false
         val () = Elaborate.elabTop (here, decs)
         val () = Elaborate.finish ()
         val delta = !Elaborate.lastDelta
         val () = Error.flushWarnings ()
         val pdecs =
           case if !quiet then NONE else ReplShow.echoes (bound delta) of
             NONE => []
           | SOME (text, synth) =>
               let
                 val () = count := !count + 1
                 val file = Source.fromString ("<echo " ^ Int.toString (!count) ^ ">", text)
                 val () = Source.register file
                 (* the standard fixity, whatever the declarations made of the
                    names the printer uses *)
                 val (pd, _) = Parser.parseTokensWith (Lexer.tokenize file, Fixity.initial)
                 val penv = ref (Env.plus (!here, synth))
                 val () = Elaborate.elabTop (penv, pd)
                 val () = Elaborate.finish ()
                 val () = Error.warnings := []
               in pd end
         val run = Runtime.link (Byte.stringToBytes (unitBytes (decs @ pdecs)))
       in {run = run, delta = delta, declared = declared delta} end)
      handle e => (Elaborate.restore saved; raise e)
    end
end
