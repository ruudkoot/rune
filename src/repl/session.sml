(* The resident compiler (docs/repl.md; the incremental roadmap's D9 and M4):
   the compiler, in the program it compiles for, compiling one top-level
   declaration at a time as a unit (docs/units.md) and linking it into the
   running program with Runtime.link.

   The REPL program is itself units: the files of the Basis Library the
   compiler uses, the compiler, the REPL, loaded one by one, so that what
   they export is in the VM's table (runtime/loader.c), by each unit's
   identity and its numbers there. At start the session loads the bases of
   the Basis's units (UnitBasis), which the build wrote beside their code:
   the environment the declarations are compiled in, and the units their
   code names, by the same identities (one Basis for the REPL and for what
   it compiles: D8). A declaration is a unit after them, compiled and loaded
   again from its basis, as the build's units were. *)
structure ReplSession =
struct
  exception Failed of string
  (* a declaration whose errors were reported as they were found: each
     independent one of a top-level declaration (Elaborate.recover, D17) *)
  exception Reported

  val env : Env.env ref = ref Env.initial
  val fixity : Fixity.env ref = ref Fixity.initial
  (* the declarations compiled so far, for the names of their units and of
     their printers' sources *)
  val count : int ref = ref 0
  (* whether a declaration's values are echoed: not those of the REPL's own
     declarations at start *)
  val quiet : bool ref = ref false
  (* how the files the session uses are read, as rune-repl --unicode[=ENC]
     says (Source.mode); what is typed is UTF-8 under --unicode, whatever
     the files' encoding (docs/plans/utf8.md, D1) *)
  val mode : Source.mode ref = ref Source.Ascii
  fun typedMode () : Source.mode = case !mode of Source.Ascii => Source.Ascii | Source.Unicode _ => Source.Unicode Source.Utf8
  (* the mode the source named file was read in, where it was registered
     (the REPL's parse); else the files' *)
  fun modeOf (file : string) : Source.mode =
    case Source.findFile file of SOME f => #mode f | NONE => !mode
  fun echoing () = not (!quiet) andalso !RuneCompiler.printDepth > 0 andalso !RuneCompiler.feedback <> "silent"
  (* what a declaration's echo was compiled by, as the usages of the cache
     see it (UnitBasis.replSetting) *)
  val () = UnitBasis.replSetting :=
             (fn key => if key = "echo on" then echoing ()
                        else String.isPrefix "p " key andalso RuneShow.hasPrinter (String.extract (key, 2, NONE)))

  (* Where the session's top-level names were bound, by kind and name ("v x",
     "t t", "s S", "g SIG", "f F"): the file and the line of the declaration,
     and for the Basis's the file of its unit, line 0 (:info, :edit) *)
  val defined : (string * int) StringMap.map ref = ref StringMap.empty

  fun noteDefined (delta : Env.env, file : string, line : int) : unit =
    let
      fun note kind n = defined := StringMap.insert (!defined, kind ^ " " ^ n, (file, line))
    in
      StringMap.appi (fn (n, _) => note "v" n) (Env.vals delta);
      StringMap.appi (fn (n, _) => note "t" n) (Env.tys delta);
      StringMap.appi (fn (n, _) => note "s" n) (Env.strs delta)
    end

  (* ---- -g: what the debugger knows of the units (the REPL roadmap's D22
     and M12) ----
     While debugging is on, a declaration is compiled for the debugger: at
     -O0, each variable of the source a register of its own (Regs), and what
     each function binds and captures kept (Lower.debugVars, Ty.names), so
     that a stopped frame's variables are found by name and shown by their
     types; no cache is read or written. Each unit compiled so is kept here
     by the number its first function has in the program. *)
  val debugging = ref false
  (* a variable of a function: its name, its type, where it is -- a register,
     from the byte of the function's code where it has been set, or a slot
     of the closure's environment *)
  datatype place = Reg of int * int | Captured of int
  type var = {name : string, ty : Types.ty, place : place}
  val debugUnits : {base : int, funcs : var list vector} list ref = ref []

  (* The types of a unit's own declarations are made again when it is
     loaded from its basis (UnitBasis.load): the types its variables had as
     it was compiled are the old ones, which the session names no more. The
     old type constructors of the unit's types, by stamp, to the new: the
     two environments, by name. *)
  fun tyconsMoved (old : Env.env, new : Env.env) : Types.tycon IntMap.map =
    let
      fun go (old, new, acc) =
        let
          val acc =
            StringMap.foldli (fn (n, Env.TyStr {fcn, ...}, acc) =>
                                case (StringMap.find (Env.tys new, n), Types.fcnIsName fcn) of
                                  (SOME (Env.TyStr {fcn = fcn', ...}), SOME c) =>
                                    (case Types.fcnIsName fcn' of
                                       SOME c' => if #stamp c = #stamp c' then acc else IntMap.insert (acc, #stamp c, c')
                                     | NONE => acc)
                                | _ => acc)
                             acc (Env.tys old)
        in
          StringMap.foldli (fn (n, s, acc) => case StringMap.find (Env.strs new, n) of
                                                SOME s' => go (s, s', acc)
                                              | NONE => acc)
                           acc (Env.strs old)
        end
    in go (old, new, IntMap.empty) end

  fun retype (m : Types.tycon IntMap.map) (t : Types.ty) : Types.ty =
    if IntMap.isEmpty m then t
    else
      case Types.prune t of
        Types.TCon (c, args) => Types.TCon (getOpt (IntMap.find (m, #stamp c), c), List.map (retype m) args)
      | Types.TRecord fs => Types.TRecord (List.map (fn (l, a) => (l, retype m a)) fs)
      | Types.TArrow (a, b) => Types.TArrow (retype m a, retype m b)
      | t => t

  (* the variables of each function of the unit just compiled, by its
     number in the unit, their types the loaded unit's (moved) *)
  fun debugTable (moved : Types.tycon IntMap.map) : var list vector =
    let
      val n = List.foldl (fn ({id, ...} : {id : int, vars : (int * int) list, env : (int * int) list}, m) =>
                            Int.max (id + 1, m)) 0 (!Lower.debugVars)
      fun regOf (id, v) =
        case List.find (fn (i, _, _) => i = id) (!Lower.debugRegs) of
          SOME (_, rs, at) => if v >= 0 andalso v < Vector.length rs then (Vector.sub (rs, v), Vector.sub (at, v)) else (~1, ~1)
        | NONE => (~1, ~1)
      fun named (stamp, place) =
        case IntTable.find (Ty.names, stamp) of
          SOME (name, ty) => SOME {name = name, ty = retype moved ty, place = place}
        | NONE => NONE
      val a = Array.array (n, [])
    in
      List.app (fn {id, vars, env} =>
                  if id < 0 orelse id >= n then ()
                  else Array.update (a, id,
                         List.mapPartial (fn (s, v) => let val (r, at) = regOf (id, v)
                                                       in if r < 0 orelse at < 0 then NONE else named (s, Reg (r, at)) end)
                                         vars
                         @ List.mapPartial (fn (s, i) => named (s, Captured i)) env))
               (!Lower.debugVars);
      Array.vector a
    end

  (* f () compiling for the debugger, where debugging is on *)
  fun forDebugger (f : unit -> 'a) : 'a =
    if not (!debugging) then f ()
    else
      let
        val (level, info, names) = (!Pass.level, !Lower.debugInfo, !Ty.keepNames)
        fun restore () = (Pass.level := level; Lower.debugInfo := info; Ty.keepNames := names)
      in
        Pass.level := 0; Lower.debugInfo := true; Ty.keepNames := true;
        (f () before restore ()) handle e => (restore (); raise e)
      end

  (* the unit just compiled linked, and kept for the debugger where it was
     compiled for it; the breakpoints set again, which its files may have *)
  val linkedHook : (unit -> unit) ref = ref (fn () => ())
  fun linkFor (bytes : string, moved : Types.tycon IntMap.map) : unit -> unit =
    let val run = Runtime.link (Byte.stringToBytes bytes)
    in
      if !debugging then
        let val table = debugTable moved
        in debugUnits := {base = RuneRuntime.debugProgram () - Vector.length table, funcs = table} :: !debugUnits end
      else ();
      !linkedHook ();
      run
    end

  (* the variables of function f of the program, where a unit compiled for
     the debugger has it *)
  fun varsOf (f : int) : var list option =
    case List.find (fn {base, funcs} => f >= base andalso f < base + Vector.length funcs) (!debugUnits) of
      SOME {base, funcs} => SOME (Vector.sub (funcs, f - base))
    | NONE => NONE

  fun readBytes (path : string) : string =
    let val inp = BinIO.openIn path
    in Byte.bytesToString (BinIO.inputAll inp) before BinIO.closeIn inp end

  (* start {units, sources, lib}: the units the REPL program was loaded from
     and the source of each, as the build named them; the bases of the
     Basis's among them loaded, each from the file beside its code (.rbi) *)
  fun start {units : string list, sources : string list, lib : string} : unit =
    let
      val () = Pass.whole := false
      val () = Elaborate.recover := false
      val () = UnitBasis.startSession ()
      (* the Basis's units: those of the build's library, up to the first
         that is not *)
      fun basisFile name =
        case String.fields (fn c => c = #"/") name of
          parts => List.length parts >= 2 andalso List.nth (parts, List.length parts - 2) = "basis"
      fun load ((unit, name) :: rest) =
            if not (basisFile name) then ()
            else
              let
                val path = OS.Path.joinDirFile {dir = lib ^ "/basis", file = OS.Path.file name}
                val rbi = OS.Path.joinBaseExt {base = OS.Path.base unit, ext = SOME "rbi"}
                val pickle = readBytes rbi handle IO.Io _ => raise Failed ("cannot read " ^ rbi)
                val st = UnitBasis.begin (!env, !fixity)
                val l =
                  UnitBasis.load {pickle = pickle, file = name, at = #counters st}
                  handle Pickle.Bad why => raise Failed (rbi ^ ": " ^ why)
                       | UnitBasis.Missing u => raise Failed (rbi ^ ": names " ^ u ^ ", which was not loaded")
                       | IO.Io _ => raise Failed ("cannot read " ^ path)
              in
                env := Env.plus (!env, #delta l);
                fixity := Fixity.extend (!fixity, #directives l);
                UnitBasis.bind l;
                noteDefined (#delta l, "lib/basis/" ^ OS.Path.file name, 0);
                load rest
              end
        | load [] = ()
    in
      load (ListPair.zip (units, sources));
      (* where Compiler.addPrettyPrinter puts the printers (Translate) *)
      case Env.findVal (!env, (["RuneShow"], "addPrinterAt")) of
        SOME (Env.Val {stamp, ...}) => Translate.printerTarget := SOME stamp
      | _ => raise Failed "the library has no RuneShow.addPrinterAt"
    end

  (* The values a declaration bound, in the order of their names, with
     their types: what the REPL echoes *)
  fun bound (delta : Env.env) : (string * Types.ty) list =
    StringMap.foldri (fn (n, Env.Val {scheme, ...}, acc) => (n, scheme) :: acc | (_, _, acc) => acc) []
                     (Env.vals delta)

  (* The other things a declaration declared, as the REPL echoes them, the
     types named as the session env names them *)
  fun declared (env : Env.env, delta : Env.env) : string list =
    let
      fun con (name, Env.Con {scheme, info}) =
            if #hasArg info then
              case Types.prune scheme of
                Types.TArrow (a, _) => name ^ " of " ^ ReplShow.typeIn env a
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
      (* with feedback verbose, a structure with its signature *)
      val verbose = !RuneCompiler.feedback = "verbose"
      val strs = StringMap.foldri (fn (n, s, acc) =>
                                     if verbose then
                                       String.concatWith "\n" (("structure " ^ n ^ " :") :: "  sig"
                                                               :: ReplShow.signatureLines (env, s, "    ") @ ["  end"]) :: acc
                                     else ("structure " ^ n) :: acc) [] (Env.strs delta)
    in tys @ exns @ strs end

  (* compile decs: the declarations elaborated against the session, and the
     printer of what they bind with them (ReplShow), made into a unit and
     linked; the function that runs it, what they bind, which the REPL adds
     to the session once it has run -- a declaration that raises binds
     nothing (Chapter 8), while what it compiled as it ran (a nested `use`)
     is the session's already -- and what to echo of what is not a value.
     A declaration that does not elaborate leaves the session as it was and
     raises Error.CompileError, as the batch compiler does. *)
  (* The cache of a file's units (UnitCache): RUNE_CACHE, else .rune beside
     the file; NONE where RUNE_CACHE is empty *)
  fun cacheOf (file : string) : (string * string) option =
    let
      val dir = case OS.Process.getEnv "RUNE_CACHE" of
                  SOME d => if d = "" then NONE else SOME d
                | NONE => SOME (OS.Path.joinDirFile {dir = OS.Path.dir file, file = ".rune"})
    in Option.map (fn d => (d, UnitCache.configuration ())) dir end

  (* compile (decs, file, text, cached): the declarations elaborated against
     the session, and the printer of what they bind with them (ReplShow),
     made into a unit and linked; the function that runs it, what they bind,
     which the REPL adds to the session once it has run -- a declaration that
     raises binds nothing (Chapter 8), while what it compiled as it ran (a
     nested use) is the session's already -- and what to echo of what is not
     a value; and bind, which makes its names the unit's for the usages of
     the units after it, when the REPL adds them. A declaration that does not
     elaborate leaves the session as it was and raises
     Error.CompileError, as the batch compiler does.

     cached is SOME (stem, n, names) for the n-th declaration of a file
     `use`d, or of a part of one (Repl.compileReader), which stem names, and
     which parsing it looked up names of: the unit is the text's n-th, and is
     taken from the cache where an entry's usages hold (docs/units.md, The
     cache), and kept there where it is compiled. *)
  fun compile (decs : Ast.dec list, file : string, text : string, cached : (string * int * string list) option)
      : {run : unit -> unit, delta : Env.env, declared : string list, bind : unit -> unit} =
    forDebugger (fn () => compileWith (decs, file, text, if !debugging then NONE else cached, Env.empty))

  (* compileWith (..., extra): extra, beside the session, in the environment
     the declarations are elaborated in: the constructors of the printers of
     a stopped frame's variables (ReplDebug) *)
  and compileWith (decs : Ast.dec list, file : string, text : string, cached : (string * int * string list) option,
                   extra : Env.env)
      : {run : unit -> unit, delta : Env.env, declared : string list, bind : unit -> unit} =
    let
      val start = UnitBasis.begin (!env, !fixity)
      val here = ref (Env.plus (!env, extra))
      val () = count := !count + 1
      val k = !count
      val name = case cached of SOME (stem, n, _) => stem ^ "#" ^ Int.toString n | NONE => file ^ "#" ^ Int.toString k
      (* the mode its text was read in, which its key says where it is not
         the default, as a compile in units says it (Main), and
         --no-unicode-lints, whose warnings an entry would keep *)
      val srcMode = modeOf file
      val settings = String.concatWith " " (List.filter (fn s => s <> "")
                                              [if srcMode = Source.Ascii then "" else Source.modeName srcMode,
                                               if !Lexer.lints then "" else "no-unicode-lints"])
      val cache =
        case cached of
          NONE => NONE
        | SOME _ => Option.map (fn (d, c) => (d, c, UnitCache.key {name = name, text = text, allow = false, settings = settings}))
                               (cacheOf file)
      fun result (l : UnitBasis.result, run) =
        {run = run, delta = #delta l, declared = declared (Env.plus (!env, #delta l), #delta l),
         bind = fn () => UnitBasis.bind l}
      val found =
        case cache of
          NONE => NONE
        | SOME (d, c, key) =>
            (UnitBasis.position (!env, #fixity start);
             case UnitCache.find (d, c, key) of UnitCache.Found e => SOME e | UnitCache.Missed _ => NONE)
      (* RUNE_VERIFY_CACHE: an entry found is compiled all the same, and what
         that gives is compared with it (UnitCache.verifying) *)
      val against = case found of
                      SOME (e as {usages, ...}) => if UnitCache.verifying () andalso UnitBasis.exact usages then SOME e else NONE
                    | NONE => NONE
      (* from the cache: its basis loaded, its code linked; when verifying,
         compiled all the same, and one taken across a unit that changed
         compiled again rather than compared (issue 15) *)
      val hit =
        case if UnitCache.verifying () then NONE else found of
          NONE => NONE
        | SOME {pickle, identity, code, warnings, file = was, others, schemes, ...} =>
          let val at = UnitBasis.counters ()
          in
            (let
               val (fp, u) = UnitFile.read code
               (* the units it was compiled against that are others now
                  (M6's third part) *)
               val remap = case cache of
                             SOME (d, c, _) => UnitBasis.remapping (pickle, u, UnitCache.pathsIn ([d], c))
                           | NONE => []
               val u = UnitBasis.remapKeys (u, remap)
               val () = Option.app (fn i => raise UnitBasis.Missing i) (UnitBasis.absent u)
               (* the schemes of what it names of other units, against those
                  units now (UnitBasis.schemesHold) *)
               val () = if List.null remap then UnitBasis.checkSchemes schemes else ()
               (* a file used again, the same text against the same units:
                  loaded and linked under an identity of its own, that what
                  named the first's globals still does (UnitBasis.unused) *)
               val as' = UnitBasis.unused identity
               val l = UnitBasis.loadKnown ({pickle = pickle, file = file, at = at}, SOME as', remap)
               (* its source, and those of the functors' bodies it
                  applied, where they are now, in its code's files *)
               val code = if UnitBasis.moves (u, was, file, others) orelse not (List.null remap) orelse as' <> identity
                          then String.concat (UnitFile.chunks (fp, UnitBasis.relocate (UnitBasis.renamed (u, as'), was, file, others)))
                          else code
               val run = linkFor (code, IntMap.empty)
             in
               (* the warnings its compile gave, again *)
               List.app (fn w => TextIO.output (TextIO.stdErr, Diagnostic.showCached w ^ "\n")) warnings;
               SOME (result (l, run))
             end)
            handle Pickle.Bad _ => (UnitBasis.abandon at; NONE)
                 | UnitBasis.Missing _ => (UnitBasis.abandon at; NONE)
                 | UnitBasis.SchemeChanged _ => (UnitBasis.abandon at; NONE)
                 | UnitFile.Bad _ => (UnitBasis.abandon at; NONE)
                 | Fail _ => (UnitBasis.abandon at; NONE)
          end
      val warnings : string list ref = ref []
      (* the source of the printer, which nothing names once it is compiled:
         one name for every declaration's, which are compiled one at a time,
         so that a declaration's code does not depend on how many the session
         compiled before it, and an entry of the cache is what compiling the
         declaration again in another session gives (RUNE_VERIFY_CACHE, S76) *)
      val echoName = "<echo>"
    in
      case hit of
        SOME r => r
      | NONE =>
      (let
         val ((delta, pdecs), names) =
           Usage.record
             (fn () =>
                let
                  val () = Elaborate.allowPrim := false
                  (* every independent error of the declaration reported,
                     and then none of it kept *)
                  val errors = !Error.errors
                  val recovering = !Elaborate.recover
                  val () = Elaborate.recover := true
                  val () = Elaborate.elabTop (here, decs) handle e => (Elaborate.recover := recovering; raise e)
                  val () = Elaborate.recover := recovering
                  val () = if !Error.errors > errors then (Error.warnings := []; raise Reported) else ()
                  val () = Elaborate.finish ()
                  val delta = !Elaborate.lastDelta
                  val () = warnings := map Error.formatWarning (List.rev (!Error.warnings))
                  val () = Error.flushWarnings ()
                  val pdecs =
                    case ReplShow.echoes (!here, bound delta, delta, (Usage.use ("echo", "on"); echoing ())) of
                      NONE => []
                    | SOME (text, synth) =>
                        let
                          (* read as --unicode reads, since it names the
                             declaration's values, which may be Unicode *)
                          val file = Source.fromStringIn (Source.Unicode Source.Utf8, echoName, text)
                          val () = Source.register file
                          (* the standard fixity, whatever the declarations made of the
                             names the printer uses *)
                          val (pd, _) = Parser.parseTokensWith (Lexer.tokenize file, Fixity.initial)
                          val penv = ref (Env.plus (!here, synth))
                          val () = Elaborate.elabTop (penv, pd)
                          val () = Elaborate.finish ()
                          val () = Error.warnings := []
                        in pd end
                in (delta, pdecs) end)
         val used = names @ (case cached of SOME (_, _, ns) => ns | NONE => [])
         val usages = UnitBasis.usagesOf used
         (* compiled, and loaded again from its basis: what it declared,
            the session's after it has run, is what the basis says *)
         val {code, loaded, exported} =
           Pipeline.unitThrough {start = start, name = name, file = file, text = fn () => text, mode = srcMode,
                                 decs = decs @ pdecs, delta = delta, fixity = #fixity start, used = used, fresh = true}
         val bytes = String.concat (UnitFile.chunks (Pipeline.fingerprint (), code))
         (* its code read back, at level 2 *)
         val () = Pass.checkAt ("code-rt", 2) (Pipeline.codeRoundTrip (Pipeline.fingerprint (), bytes)) code
         (* linked as it was loaded, under an identity of its own where it
            is a file used again (Pipeline.unitThrough's fresh) *)
         val linked = if #identity (#unit loaded) = #identity code then bytes
                      else String.concat (UnitFile.chunks (Pipeline.fingerprint (), UnitBasis.renamed (code, #identity (#unit loaded))))
         val () =
           case against of
             SOME e =>
               if UnitCache.verifies (e, file, #pickle exported, bytes, "") then ()
               else raise Fail ("the cache's entry for " ^ name ^ " is not what compiling it gives")
           | NONE => ()
         val () =
           case cache of
             SOME (d, c, _) => UnitCache.storePaths (d, c, #identity exported, UnitBasis.pathsOf (#unit loaded))
           | NONE => ()
         val () =
           case cache of
             SOME (d, c, key) =>
               UnitCache.store (d, c, key, {usages = usages, warnings = !warnings, file = file,
                                            others = UnitBasis.sourcesOf (code, file), pickle = #pickle exported,
                                            identity = #identity exported, code = bytes, mid = "",
                                            level = UnitCache.level (), schemes = UnitBasis.importedSchemes code})
           | NONE => ()
       in
         Source.unregister echoName;
         result (loaded, linkFor (linked, if !debugging then tyconsMoved (delta, #delta loaded) else IntMap.empty))
       end)
      handle e => (UnitBasis.undo start; Source.unregister echoName; raise e)
    end
end

(* What the REPL's commands ask of the session without running anything
   (src/repl/commands.sml): the type of an expression, elaborated as
   `val it = (exp);` and then undone, as a declaration that fails is. *)
structure ReplQuery =
struct
  (* a text's tokens as declarations, or else as an expression behind the
     tokens of `val it =`: lexed by itself, so that its positions are its
     own (the source stdIn) *)
  fun declarations (text : string) : Ast.dec list =
    let
      val file = Source.fromStringIn (ReplSession.typedMode (), "stdIn", text)
      val () = Source.register file
      val toks = Lexer.tokenize file
      val n = Vector.length toks
      val at = {file = "stdIn", start = 0, stop = 0}
      val stop = #2 (Vector.sub (toks, n - 1))
      fun asDecs () = #1 (Parser.parseTokensWith (toks, !ReplSession.fixity))
      fun asExp () =
        #1 (Parser.parseTokensWith (Vector.concat [Vector.fromList [(Token.VAL, at), (Token.ID "it", at), (Token.EQUALS, at)],
                                                   VectorSlice.vector (VectorSlice.slice (toks, 0, SOME (n - 1))),
                                                   Vector.fromList [(Token.SEMI, stop), (Token.EOF, stop)]],
                                    !ReplSession.fixity))
    in
      asDecs () handle Error.CompileError e => (asExp () handle Error.CompileError _ => raise Error.CompileError e)
    end

  (* the text elaborated against the session, every error reported, and then
     undone: the declarations, their variables resolved and typed (the
     engine's typeAt and check) *)
  fun elaborated (text : string) : Ast.dec list =
    let
      val decs = declarations text
      val start = UnitBasis.begin (!ReplSession.env, !ReplSession.fixity)
      val snap = Elaborate.snapshot ()
      val here = ref (!ReplSession.env)
      val errors = !Error.errors
      val recovering = !Elaborate.recover
      fun undo () = (Elaborate.recover := recovering; Elaborate.restore snap; UnitBasis.undo start; Error.warnings := [])
    in
      (Elaborate.allowPrim := false;
       Elaborate.recover := true;
       Elaborate.elabTop (here, decs);
       if !Error.errors > errors then raise ReplSession.Reported else Elaborate.finish ();
       undo ();
       decs)
      handle e => (undo (); raise e)
    end

  fun typeOf (text : string) : Types.ty =
    let
      (* the expression lexed by itself, so that an error points into it,
         behind the tokens of `val it =` *)
      val file = Source.fromStringIn (ReplSession.typedMode (), "stdIn", text)
      val () = Source.register file
      val toks = Lexer.tokenize file
      val n = Vector.length toks
      val at = {file = "stdIn", start = 0, stop = 0}
      val stop = #2 (Vector.sub (toks, n - 1))
      val whole = Vector.concat [Vector.fromList [(Token.VAL, at), (Token.ID "it", at), (Token.EQUALS, at)],
                                 VectorSlice.vector (VectorSlice.slice (toks, 0, SOME (n - 1))),
                                 Vector.fromList [(Token.SEMI, stop), (Token.EOF, stop)]]
      val (decs, _) = Parser.parseTokensWith (whole, !ReplSession.fixity)
      val start = UnitBasis.begin (!ReplSession.env, !ReplSession.fixity)
      val snap = Elaborate.snapshot ()
      val here = ref (!ReplSession.env)
      fun undo () = (Elaborate.restore snap; UnitBasis.undo start; Error.warnings := [])
    in
      (let
         val () = Elaborate.allowPrim := false
         val () = Elaborate.elabTop (here, decs)
         val () = Elaborate.finish ()
         val t = case StringMap.find (Env.vals (!Elaborate.lastDelta), "it") of
                   SOME (Env.Val {scheme, ...}) => scheme
                 | _ => raise Fail "the expression has no type"
       in undo (); t end)
      handle e => (undo (); raise e)
    end
end
