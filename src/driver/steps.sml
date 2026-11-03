(* What a build runs before it reads a source (docs/build.md, Generated
   sources; the build-system roadmap's D16): its declared steps, each a tool
   with its arguments, inputs and outputs, and its preprocessors, each a tool
   that a file of its class is given to. A compile runs them, before its
   units are read; planning, --plan and an editor never do, so that the
   graph stays static.

   A step's key is its tool's bytes, its arguments, and its inputs' paths and
   bytes. The cache keeps, under steps/, the key a step last ran under and the
   hash of each output it made then. A step whose key and outputs are as kept
   is not run. One whose key is not runs, its outputs being stale, and each
   output must be there after: a tool that fails or leaves an output unmade
   stops the build, and what was there before is not compiled. An output that
   is not what its step made under the key it still has is refused: it was
   edited by hand, and a build would otherwise compile the edit or overwrite
   it. A step that declares no inputs runs on every build, since nothing
   says when it is due, and a build with one is never up to date. With
   --no-cache nothing is kept, and every step runs.

   Every file a step or a preprocessor reads is told to a build that keeps
   what it reads (Source.reading; UnitMemo, up to date) before it is read,
   and each step's outputs, made or found made, are given to noteOutput, so
   that a build is up to date only where none of it changed.

   A preprocessor's output is what a unit compiles in place of its file,
   under the file's name (Source.overlays): a unit's key holds that output,
   so a build after an edit of the file is the build of what the edit makes
   of it (S41). Outputs are kept in the cache by the tool's bytes, its
   arguments, its inputs' bytes and the file's, and the tool is run on a
   file only where none is kept. A tool runs in the directory of the build
   file that declares it, as TOOL ARGUMENT ... for a step and as
   TOOL ARGUMENT ... INPUT OUTPUT for a preprocessor. *)
structure Steps =
struct
  exception Refused of string

  type generate = CompilerProject.generate
  type preprocessor = CompilerProject.preprocessor

  fun hash (text : string) : string = Hex.fromBytes (Sha256.digest text)
  fun exists (path : string) : bool = OS.FileSys.access (path, []) handle OS.SysErr _ => false
  fun bytes (path : string) : string =
    let val i = BinIO.openIn path
    in Byte.bytesToString (BinIO.inputAll i) before BinIO.closeIn i end
  (* an output's hash, and a file's that the step reads, told first *)
  fun hashOf (path : string) : string option = SOME (hash (bytes path)) handle IO.Io _ => NONE
  fun readHash (path : string) : string option = (!Source.reading path; hashOf path)
  (* a file written whole or not at all *)
  fun write (path : string, text : string) : unit =
    (UnitStore.mkdirs (OS.Path.dir path);
     UnitStore.withTemporary path (fn tmp =>
       (let val out = BinIO.openOut tmp
        in (BinIO.output (out, Byte.stringToBytes text); BinIO.closeOut out)
           handle e => (BinIO.closeOut out handle _ => (); raise e)
        end;
        OS.FileSys.rename {old = tmp, new = path})))

  (* a path as the tool is given it, from where it runs *)
  fun full (path : string) : string =
    OS.FileSys.fullPath path handle OS.SysErr _ => raise Refused ("no file " ^ path)
  fun absolute (path : string) : string =
    if OS.Path.isAbsolute path then path else OS.Path.mkAbsolute {path = path, relativeTo = OS.FileSys.getDir ()}

  (* a command line, each word quoted as the shell of the system reads it *)
  fun quote (windows : bool) (word : string) : string =
    if windows then "\"" ^ String.translate (fn #"\"" => "\\\"" | c => String.str c) word ^ "\""
    else "'" ^ String.translate (fn #"'" => "'\\''" | c => String.str c) word ^ "'"
  fun run {windows : bool, dir : string, words : string list} : bool =
    let
      val q = quote windows
      val command = (if windows then "cd /d " else "cd ") ^ q (full dir) ^ " && " ^ String.concatWith " " (List.map q words)
    in OS.Process.isSuccess (OS.Process.system command) handle OS.SysErr _ => false end

  (* what a tool is, by what it is made of: its bytes, its arguments, and
     its inputs' paths and bytes; kind is "generate" or "preprocess", and
     what names the step or the preprocessor where it is refused *)
  fun toolKey (kind : string, what : string, tool : string, arguments : string list, inputs : string list) : string =
    let
      fun of' path = case readHash path of
                       SOME h => h
                     | NONE => raise Refused (what ^ " reads " ^ path ^ ", which cannot be read")
      val toolHash = case readHash tool of
                       SOME h => h
                     | NONE => raise Refused (what ^ " has no tool " ^ tool)
    in
      hash (String.concatWith "\000" ([kind, toolHash] @ arguments @ ["inputs"]
                                      @ List.concat (List.map (fn p => [p, of' p]) inputs)))
    end

  (* ---- steps ---- *)

  (* a step's record: the key it ran under and each output's hash *)
  fun recordFile (cache : string, {dir, outputs, ...} : generate) : string =
    OS.Path.joinDirFile {dir = OS.Path.joinDirFile {dir = cache, file = "steps"},
                         file = hash (String.concatWith "\000" (absolute dir :: List.map absolute outputs))}
  fun readRecord (file : string) : (string * (string * string) list) option =
    (case String.tokens (fn c => c = #"\n") (bytes file) of
       first :: rest =>
         (case String.tokens Char.isSpace first of
            ["rune-step", "1", key] =>
              SOME (key, List.map (fn l => if String.isPrefix "output " l andalso size l > 72 andalso String.sub (l, 71) = #" "
                                           then (String.extract (l, 72, NONE), String.substring (l, 7, 64))
                                           else raise Fail "a step's record") rest)
          | _ => NONE)
     | [] => NONE)
    handle IO.Io _ => NONE | Fail _ => NONE
  fun writeRecord (file : string, key : string, outputs : (string * string) list) : unit =
    write (file, String.concat (("rune-step 1 " ^ key ^ "\n") :: List.map (fn (p, h) => "output " ^ h ^ " " ^ p ^ "\n") outputs))
    handle IO.Io _ => () | OS.SysErr _ => ()

  fun describe ({tool, arguments, ...} : generate) : string =
    "the step " ^ String.concatWith " " (tool :: arguments)

  (* whether a step says what it reads, and so when it is due *)
  fun reads ({inputs, ...} : generate) : bool = not (List.null inputs)

  fun generate {windows : bool, cache : string option, explain : string -> unit}
               (step as {tool, arguments, inputs, outputs, dir} : generate) : unit =
    let
      val what = describe step
      (* the tool's key, which refuses a tool that is not there *)
      val key = toolKey ("generate", what, tool, arguments @ ["outputs"] @ outputs, inputs)
      val record = Option.map (fn c => recordFile (c, step)) cache
      val kept = if not (reads step) then NONE else Option.mapPartial readRecord record
      val now = List.map (fn p => (p, hashOf p)) outputs
      val due =
        case kept of
          SOME (k, made) =>
            if k <> key then true
            else
              (List.app (fn (p, h) =>
                  case (h, List.find (fn (q, _) => q = p) made) of
                    (SOME h, SOME (_, m)) =>
                      if h = m then ()
                      else raise Refused (p ^ " is not what " ^ what ^ " made of its inputs: it was changed since, by hand or by "
                                          ^ "another tool; remove it, and the build makes it again")
                  | _ => ())
                now;
               List.exists (fn (_, h) => not (isSome h)) now)
        | NONE => true
    in
      if not due then explain ("rune: " ^ what ^ " is up to date")
      else
        let
          val () = explain ("rune: running " ^ what ^ (if reads step then "" else ", which runs on every build"))
          (* where each output goes, which a fresh checkout may not have *)
          val () = List.app (fn p => UnitStore.mkdirs (OS.Path.dir p)) outputs
          val ok = run {windows = windows, dir = dir, words = full tool :: arguments}
          val () = if ok then () else raise Refused (what ^ " failed, and what it makes is not compiled")
          val made = List.map (fn p => case hashOf p of
                                          SOME h => (p, h)
                                        | NONE => raise Refused (what ^ " did not make " ^ p ^ ", which it says it makes"))
                              outputs
        in
          case record of SOME file => writeRecord (file, key, made) | NONE => ()
        end
    end

  (* ---- preprocessors ---- *)

  (* what this process made of each file, so that a compile made again
     (compiledAgain) does not give a tool its own output *)
  val made : string StringMap.map ref = ref StringMap.empty

  fun preprocess {windows : bool, cache : string option, explain : string -> unit}
                 (classes : preprocessor list) (units : (string * string list) list) : unit =
    let
      val keys = List.map (fn (p as {name, tool, arguments, inputs, ...} : preprocessor) =>
                             (name, (p, toolKey ("preprocess", "the preprocessor " ^ name, tool, arguments, inputs)))) classes
      val runs = ref 0
      fun one (file, annotations) =
        case BuildFile.preprocessorOf annotations of
          NONE => ()
        | SOME name =>
            let
              val overlay = StringMap.find (!Source.overlays, file)
            in
              if isSome overlay andalso overlay = StringMap.find (!made, file) then ()
              else
                let
                  val ({tool, arguments, dir, ...}, classKey) =
                    case List.find (fn (n, _) => n = name) keys of
                      SOME (_, found) => found
                    | NONE => raise Refused (file ^ " is put in the preprocessor " ^ name ^ ", which no build file of it declares")
                  (* the file, or an editor's text of it (Serve) *)
                  val text = case overlay of
                               SOME text => text
                             | NONE => (!Source.reading file; bytes file) handle IO.Io _ => raise Refused ("cannot read " ^ file)
                  val key = hash (classKey ^ "\000" ^ hash text)
                  val kept = Option.map (fn c => OS.Path.joinDirFile {dir = OS.Path.joinDirFile {dir = c, file = "steps"},
                                                                      file = "pre-" ^ key}) cache
                  (* a kept output says its own hash first, so that a damaged one is not used *)
                  fun keptText path =
                    let val s = bytes path
                    in if size s >= 65 andalso String.sub (s, 64) = #"\n"
                          andalso String.substring (s, 0, 64) = hash (String.extract (s, 65, NONE))
                       then SOME (String.extract (s, 65, NONE)) else NONE
                    end
                    handle IO.Io _ => NONE
                  val output =
                    case Option.mapPartial keptText kept of
                      SOME out => out
                    | NONE =>
                        let
                          fun remove p = OS.FileSys.remove p handle OS.SysErr _ => ()
                          (* a name no other file has, and no file yet: a
                             tool that writes nothing has made nothing *)
                          val target = OS.FileSys.tmpName ()
                          val () = remove target
                          val source = case overlay of
                                         SOME text => let val t = OS.FileSys.tmpName () in write (t, text); SOME t end
                                       | NONE => NONE
                          fun clean () = (remove target; Option.app remove source)
                          val () = runs := !runs + 1
                          val ok = run {windows = windows, dir = dir,
                                        words = full tool :: arguments @ [getOpt (source, full file), target]}
                          val out = if ok then (bytes target handle IO.Io _ => (clean (); raise Refused ("the preprocessor " ^ name ^ " made nothing of " ^ file)))
                                    else (clean (); raise Refused ("the preprocessor " ^ name ^ " failed on " ^ file))
                        in
                          clean ();
                          (case kept of
                             SOME path => (write (path, hash out ^ "\n" ^ out) handle IO.Io _ => () | OS.SysErr _ => ())
                           | NONE => ());
                          out
                        end
                in
                  Source.overlays := StringMap.insert (!Source.overlays, file, output);
                  made := StringMap.insert (!made, file, output)
                end
            end
    in
      List.app one units;
      if !runs > 0 then explain ("rune: preprocessed " ^ Int.toString (!runs) ^ (if !runs = 1 then " file" else " files")) else ()
    end

  (* what a build runs before its units are read, in order: its steps, each
     output given to noteOutput once its step is done, then its
     preprocessors, on the files they make too *)
  fun prepare {project : CompilerProject.plan, cache : string option, windows : bool, explain : string -> unit,
               noteOutput : string -> unit} : unit =
    let val how = {windows = windows, cache = cache, explain = explain}
    in
      List.app (fn step => (generate how step; List.app noteOutput (#outputs step))) (#generates project);
      preprocess how (#preprocessors project) (CompilerProject.units (#steps project))
    end
end
