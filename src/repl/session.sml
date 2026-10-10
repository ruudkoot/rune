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

  val env : Env.env ref = ref Env.initial
  val fixity : Fixity.env ref = ref Fixity.initial
  (* the declarations compiled so far, for the names of their units and of
     their printers' sources *)
  val count : int ref = ref 0
  (* whether a declaration's values are echoed: not those of the REPL's own
     declarations at start *)
  val quiet : bool ref = ref false
  fun echoing () = not (!quiet) andalso !RuneCompiler.printDepth > 0
  (* what a declaration's echo was compiled by, as the usages of the cache
     see it (UnitBasis.replSetting) *)
  val () = UnitBasis.replSetting :=
             (fn key => if key = "echo on" then echoing ()
                        else String.isPrefix "p " key andalso RuneShow.hasPrinter (String.extract (key, 2, NONE)))

  fun readBytes (path : string) : string =
    let val inp = BinIO.openIn path
    in Byte.bytesToString (BinIO.inputAll inp) before BinIO.closeIn inp end

  (* start {units, sources, lib}: the units the REPL program was loaded from
     and the source of each, as the build named them; the bases of the
     Basis's among them loaded, each from the file beside its code (.rbi),
     a functor's body from lib's source of it, which must be the one the
     build compiled *)
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
                  UnitBasis.load {pickle = pickle, file = name, at = #counters st, env = !env, fixity = !fixity,
                                  text = fn () => #text (Source.readFile path)}
                  handle Pickle.Bad why => raise Failed (rbi ^ ": " ^ why)
                       | UnitBasis.Missing u => raise Failed (rbi ^ ": names " ^ u ^ ", which was not loaded")
                       | IO.Io _ => raise Failed ("cannot read " ^ path)
              in
                env := Env.plus (!env, #delta l);
                fixity := Fixity.extend (!fixity, #directives l);
                UnitBasis.bind l;
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
    let
      val start = UnitBasis.begin (!env, !fixity)
      val here = ref (!env)
      val () = count := !count + 1
      val k = !count
      val name = case cached of SOME (stem, n, _) => stem ^ "#" ^ Int.toString n | NONE => file ^ "#" ^ Int.toString k
      val cache =
        case cached of
          NONE => NONE
        | SOME _ => Option.map (fn (d, c) => (d, c, UnitCache.key {name = name, text = text, allow = false, settings = ""})) (cacheOf file)
      fun result (l : UnitBasis.result, run) =
        {run = run, delta = #delta l, declared = declared (#delta l), bind = fn () => UnitBasis.bind l}
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
        | SOME {pickle, code, warnings, file = was, others, ...} =>
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
               val l = UnitBasis.loadAgainst ({pickle = pickle, file = file, at = at, env = !env, fixity = #fixity start,
                                               text = fn () => text}, remap)
               (* its source, and those of the functors' bodies it
                  applied, where they are now, in its code's files *)
               val code = if UnitBasis.moves (u, was, file, others) orelse not (List.null remap)
                          then String.concat (UnitFile.chunks (fp, UnitBasis.relocate (u, was, file, others)))
                          else code
               val run = Runtime.link (Byte.stringToBytes code)
             in
               (* the warnings its compile gave, again *)
               List.app (fn w => TextIO.output (TextIO.stdErr, Diagnostic.showCached w ^ "\n")) warnings;
               SOME (result (l, run))
             end)
            handle Pickle.Bad _ => (UnitBasis.abandon at; NONE)
                 | UnitBasis.Missing _ => (UnitBasis.abandon at; NONE)
                 | UnitFile.Bad _ => (UnitBasis.abandon at; NONE)
                 | Fail _ => (UnitBasis.abandon at; NONE)
          end
      val warnings : string list ref = ref []
      (* the source of the printer, which nothing names once it is compiled *)
      val echoName = "<echo " ^ Int.toString k ^ ">"
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
                  val () = Elaborate.elabTop (here, decs)
                  val () = Elaborate.finish ()
                  val delta = !Elaborate.lastDelta
                  val () = warnings := map Error.formatWarning (List.rev (!Error.warnings))
                  val () = Error.flushWarnings ()
                  val pdecs =
                    case if (Usage.use ("echo", "on"); echoing ()) then ReplShow.echoes (bound delta) else NONE of
                      NONE => []
                    | SOME (text, synth) =>
                        let
                          val file = Source.fromString (echoName, text)
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
           Pipeline.unitThrough {start = start, name = name, file = file, text = fn () => text,
                                 decs = decs @ pdecs, delta = delta, fixity = #fixity start, used = used}
         val bytes = String.concat (UnitFile.chunks (Pipeline.fingerprint (), code))
         val () =
           case against of
             SOME e =>
               if UnitCache.verifies (e, file, #pickle exported, bytes, "") then ()
               else raise Fail ("the cache's entry for " ^ name ^ " is not what compiling it gives")
           | NONE => ()
         val () =
           case cache of
             SOME (d, c, _) => UnitCache.storePaths (d, c, #identity (#unit loaded), UnitBasis.pathsOf (#unit loaded))
           | NONE => ()
         val () =
           case cache of
             SOME (d, c, key) =>
               UnitCache.store (d, c, key, {usages = usages, warnings = !warnings, file = file,
                                            others = UnitBasis.sourcesOf (code, file), pickle = #pickle exported,
                                            code = bytes, mid = ""})
           | NONE => ()
       in Source.unregister echoName; result (loaded, Runtime.link (Byte.stringToBytes bytes)) end)
      handle e => (UnitBasis.undo start; Source.unregister echoName; raise e)
    end
end
