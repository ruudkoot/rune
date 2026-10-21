(* Documentation consistency assertions, with source inspection independent
   of the production compiler. Generation remains a separate operation. *)
structure DocChecks =
struct
  open Sh
  exception Failed of string
  fun trim s = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace (Substring.full s)))
  fun require (ok, message) = if ok then () else raise Failed message
  fun member (x, xs) = List.exists (fn y => y = x) xs
  fun unique xs = List.foldl (fn (x, xs) => if member (x, xs) then xs else xs @ [x]) [] xs
  fun sourceFiles dir = glob (fromRoot dir, ".sml")
  fun features () =
    let
      val errors = ref [] : string list ref
      fun check (ok, message) = if ok then () else errors := message :: !errors
      val document = read (fromRoot "docs/language.md")
      fun row line =
        if not (String.isPrefix "| " line) then NONE else
          case List.map trim (String.fields (fn c => c = #"|") line) of
            _ :: id :: fields =>
              if id <> "" andalso Char.isLower (String.sub (id, 0))
                 andalso CharVector.all (fn c => Char.isLower c orelse Char.isDigit c orelse c = #".") id
              then SOME (id, List.exists (fn field => member (field, ["Supported", "Partial"])) fields) else NONE
          | _ => NONE
      val rows = List.mapPartial row (lines document)
      val ids = List.map #1 rows
      val tested = List.map #1 (List.filter #2 rows)
      val lang = sourceFiles "tests/lang"
      val basis = List.filter (fn path => not (member (OS.Path.file path, ["harness.sml", "finish.sml"]))) (sourceFiles "tests/basis")
      fun hasPrefix id paths = List.exists (fn path => String.isPrefix (id ^ "_") (OS.Path.file path)) paths
      val () = List.app (fn id =>
        check (hasPrefix id lang orelse (String.isPrefix "basis." id andalso
            let val name = String.extract (id, 6, NONE)
            in exists (fromRoot ("tests/basis/" ^ name ^ ".sml")) orelse hasPrefix name basis end),
              "implemented feature has no test: " ^ id)) tested
      val () = List.app (fn id => check (length (List.filter (fn x => x = id) ids) = 1, "duplicate feature id " ^ id)) (unique ids)
      fun checkTest prefix path =
        let val name = OS.Path.base (OS.Path.file path)
            val id = prefix ^ hd (String.fields (fn c => c = #"_") name)
        in check (member (id, ids), "test has no documented feature: " ^ path ^ " (" ^ id ^ ")");
           check (member (id, tested), "test's feature is not Supported or Partial: " ^ id) end
      val () = List.app (checkTest "") lang
      val () = List.app (checkTest "basis.") basis
      val bytecode = read (fromRoot "docs/bytecode.md")
      val docLines = lines bytecode
      fun registerSection ([], _) = []
        | registerSection (line :: rest, false) = if String.isPrefix "## The register bytecode" line
                                                 then line :: registerSection (rest, true) else registerSection (rest, false)
        | registerSection (line :: rest, true) = if String.isPrefix "## " line then [line] else line :: registerSection (rest, true)
      val registers = String.concatWith "\n" (registerSection (docLines, false))
      fun opcode text name = String.isSubstring ("`" ^ name ^ "`") text orelse String.isSubstring ("`" ^ name ^ " ") text
      val () = List.app (fn fields => check (opcode bytecode (hd fields), "undocumented stack opcode " ^ hd fields))
                         (BytecodeFixture.definitions "runtime/stack/opcodes.def")
      val () = List.app (fn fields => check (opcode registers (hd fields), "undocumented register opcode " ^ hd fields))
                         (BytecodeFixture.definitions "runtime/register/regs.def")
      fun primitive name = List.exists (fn (left, right) => String.isSubstring (left ^ name ^ right) bytecode)
                                                [("`", "`"), ("`", " "), (" ", "`"), (" ", " ")]
      val prims = List.map hd (BytecodeFixture.definitions "runtime/prims.def")
      val () = List.app (fn name => check (primitive name, "undocumented primitive " ^ name)) prims
      val library = sourceFiles "lib/basis"
      fun structureNames path =
        List.mapPartial (fn line => if String.isPrefix "structure " line then
                 (case String.tokens Char.isSpace line of _ :: name :: _ => SOME name | _ => NONE) else NONE) (lines (read path))
      val () = List.app (fn path => List.app (fn name => check (List.exists (fn ending => String.isSubstring ("`" ^ name ^ ending) document)
                       ["`", ".", ":"], "undocumented Basis structure " ^ name ^ " in " ^ path)) (structureNames path)) library
      val manifest = List.map (fn r : Hosts.source => OS.Path.file (#path r)) (Hosts.manifest "basis")
      val () = List.app (fn name => check (exists (fromRoot ("lib/basis/" ^ name)), "manifest lists missing Basis file " ^ name)) manifest
      val () = List.app (fn path => check (member (OS.Path.file path, manifest), "Basis file missing from manifest: " ^ path)) library
      val () = List.app (fn path => check (exists (OS.Path.base path ^ ".expected"), "missing expected output for " ^ path))
                         (lang @ sourceFiles "tests/errors")
      fun man program =
        let val path = fromRoot ("share/man/" ^ program ^ ".1")
            val header = String.fields (fn c => c = #"\"") (firstLine path)
            val correct = case header of prefix :: _ :: between :: name :: suffix :: _ =>
                  (case String.tokens Char.isSpace prefix of [".TH", title, "1"] =>
                       CharVector.all (fn c => Char.isUpper c orelse c = #"-") title andalso trim between = "" andalso name = program
                         andalso String.isPrefix " " suffix | _ => false)
                | _ => false
        in check (correct, "manual title must name the program alone: " ^ path) end
      val () = List.app man ["rune", "runedoc", "runeopt", "runevm"]
      val host = SmlScan.code (read (fromRoot "tests/basis/host/rune-prim.sml"))
      fun defines name =
        let fun scan (kind :: identifier :: rest) =
                  (member (kind, ["fun", "val"]) andalso identifier = name) orelse scan (identifier :: rest)
              | scan _ = false
        in scan host end
      val () = List.app (fn name => if member (name, ["poly_eq", "imm_eq", "ptr_eq"]) then ()
                  else check (defines name, "primitive has no host definition: " ^ name)) prims
    in List.app (fn message => say ("FAIL documentation: " ^ message ^ "\n")) (List.rev (!errors));
       if null (!errors) then say ("check-docs: OK (" ^ Int.toString (length tested) ^ " documented features, "
             ^ Int.toString (length lang) ^ " tests, " ^ Int.toString (length basis) ^ " Basis Library suite files)\n")
       else raise Failed "feature/documentation drift" end
  fun tsv path header =
    let val () = require (exists path, "missing documentation export " ^ path)
        val rows = String.fields (fn c => c = #"\n") (read path)
        val actual = case rows of row :: _ => String.fields (fn c => c = #"\t") row | [] => []
        val () = require (actual = header, "invalid documentation export header in " ^ path)
        val rows = List.filter (fn row => row <> "") (List.drop (rows, 1))
        val () = require (length (unique rows) = length rows, "duplicate documentation export row in " ^ path)
        fun one row = let val fields = String.fields (fn c => c = #"\t") row
                      in require (length fields = length header, "invalid documentation export row in " ^ path); fields end
    in List.map one rows end
  val claimsHeader = ["name", "kind", "signature", "realisations", "status", "origin", "source"]
  val notesHeader = ["id", "kind", "suite", "signature", "member", "structure", "pins", "pinned", "source", "text"]
  fun claims file =
    let
      val rows = tsv file claimsHeader
      val errors = ref [] : string list ref
      fun check (ok, why) = if ok then () else errors := why :: !errors
      fun ascription line =
        if not (String.isPrefix "structure " (trim line)) then NONE else
        case SmlScan.code line of "structure" :: _ :: seal :: sigName :: rest =>
          if member (seal, [":", ":>"]) andalso (String.isPrefix "SPEC_" sigName orelse String.isPrefix "SCR_" sigName) then
            let val sigName = String.extract (sigName, if String.isPrefix "SPEC_" sigName then 5 else 4, NONE)
                fun afterEquals ([], found) = found
                  | afterEquals ("=" :: rest, _) = afterEquals (rest, SOME rest)
                  | afterEquals (_ :: rest, found) = afterEquals (rest, found)
                val target = afterEquals (rest, NONE)
            in case target of NONE => NONE | SOME words =>
                 if String.isSuffix "_IMP" sigName then NONE
                 else if null words orelse not (CharVector.all (fn c => Char.isAlphaNum c orelse c = #"_" orelse c = #"." orelse c = #"'") (String.concat words)) then NONE
                 else SOME (String.concat words, sigName) end
          else NONE
        | _ => NONE
      fun held lines =
        let fun loop ([], NONE, acc) = List.rev acc
              | loop ([], SOME line, acc) = List.rev (line :: acc)
              | loop (line :: rest, SOME current, acc) =
                  if String.isPrefix "where " (trim line) then loop (rest, SOME (current ^ " " ^ trim line), acc)
                  else loop (line :: rest, NONE, current :: acc)
              | loop (line :: rest, NONE, acc) =
                  if String.isPrefix "structure " (trim line) then loop (rest, SOME line, acc)
                  else loop (rest, NONE, line :: acc)
        in loop (lines, NONE, []) end
      val suite = unique (List.concat (List.map (fn path => List.mapPartial ascription (held (lines (read path))))
                   (List.filter (String.isSuffix "_sig.sml") (sourceFiles "tests/basis"))))
      fun pairs origin = unique (List.map (fn fields => (List.nth (fields, 0), List.nth (fields, 2)))
        (List.filter (fn fields => List.nth (fields, 1) = "structure" andalso (origin = "" orelse List.nth (fields, 5) = origin)) rows))
      val all = pairs ""
      val claimed = pairs "claimed"
      val signatures = List.filter (fn fields => List.nth (fields, 1) = "signature") rows
      val () = List.app (fn fields =>
        let val name = hd fields
            val transcribed = exists (fromRoot ("tests/basis/spec-sigs/" ^ name ^ ".sml"))
            val status = List.nth (fields, 4)
        in check ((status = "extension") <> transcribed, "signature status disagrees with specification: " ^ name);
           check (List.exists (fn row => List.nth (row, 1) <> "signature" andalso List.nth (row, 2) = name) rows,
                   "nothing implements documented signature " ^ name) end) signatures
      val required = List.filter (fn line => line <> "" andalso not (String.isPrefix "#" line))
                        (List.map trim (lines (read (fromRoot "tests/basis/spec-sigs/REQUIRED"))))
      val () = List.app (fn fields => if List.nth (fields, 1) <> "structure" orelse String.isSubstring "." (hd fields) then () else
                     check ((List.nth (fields, 4) = "required") = member (hd fields, required), "structure requirement disagrees with specification: " ^ hd fields)) rows
      fun declared path =
        let fun loop ("signature" :: name :: rest, acc) = loop (rest, if String.isPrefix "SPEC_" name then String.extract (name, 5, NONE) :: acc else acc)
              | loop (_ :: rest, acc) = loop (rest, acc) | loop ([], acc) = acc
        in loop (SmlScan.code (read path), []) end
      val () = List.app (fn path => if String.isSuffix "_IMP.sml" path then () else
                 List.app (fn name => check (List.exists (fn (_, sigName) => sigName = name) suite, "no suite match for SPEC_" ^ name)) (declared path))
                      (sourceFiles "tests/basis/spec-sigs")
      val () = List.app (fn pair as (name, sigName) => check (member (pair, all), "suite match is unclaimed: " ^ name ^ " " ^ sigName)) suite
      val () = List.app (fn pair as (name, sigName) => if exists (fromRoot ("tests/basis/spec-sigs/" ^ sigName ^ ".sml")) then
                  check (member (pair, suite), "claimed structure/signature has no suite match: " ^ name ^ " " ^ sigName) else ()) claimed
    in List.app (fn why => say ("FAIL documentation claims: " ^ why ^ "\n")) (List.rev (!errors));
       if null (!errors) then say ("check-claims: OK (" ^ Int.toString (length suite) ^ " pairs of a structure and a signature, claimed and tested)\n")
       else raise Failed "documentation claims drift" end
  fun notes notesFile claimsFile =
    let
      val notes = tsv notesFile notesHeader
      val claims = tsv claimsFile claimsHeader
      val deviations = Expectations.read (fromRoot "tests/basis/deviations.txt")
      val rune = List.filter (fn r : Expectations.line => #way r = "rune" andalso member (#category r, ["RUNE-DEV", "SPEC-AMBIGUOUS"])) deviations
      val differs = List.filter (fn row => List.nth (row, 2) = "differs" orelse List.nth (row, 1) = "Deviation") notes
      fun overlap (a, b) = Expectations.glob (a, b) orelse Expectations.glob (b, a)
      fun pinned label note = List.exists (fn pin => overlap (label, pin)) (String.tokens Char.isSpace (List.nth (note, 6)))
      val errors = ref [] : string list ref
      fun check (ok, why) = if ok then () else errors := why :: !errors
      val () = List.app (fn r : Expectations.line => check (List.exists (pinned (#path r)) differs,
                                 "Rune deviation has no pinned reading/deviation note: " ^ #path r)) rune
      val suiteDiffers = List.filter (fn row => List.nth (row, 2) = "differs") notes
      val () = List.app (fn note => check (List.exists (fn r : Expectations.line => pinned (#path r) note) rune,
                                 "suite-differs note has no Rune deviation: " ^ hd note)) suiteDiffers
      val hosts = unique (List.map #path (List.filter (fn r : Expectations.line => #way r <> "rune" andalso #category r = "SPEC-AMBIGUOUS") deviations))
      val count = ref 0
      fun one label =
        let val scope = hd (String.fields (fn c => c = #"/") label)
            val parts = String.fields (fn c => c = #".") scope
            val structName = String.concatWith "." (if length parts > 1 then List.take (parts, length parts - 1) else parts)
            val member = List.last parts
            val sigs = List.map (fn row => List.nth (row, 2)) (List.filter (fn row => hd row = structName andalso List.nth (row, 2) <> "") claims)
        in if String.isPrefix "@" scope orelse String.isPrefix "*" scope orelse null sigs then () else
           (count := !count + 1;
            check (List.exists (fn note => List.nth (note, 1) = "Reading" andalso List.nth (note, 4) = member
                         andalso List.exists (fn sigName => sigName = List.nth (note, 3)) sigs) notes,
                   "host specification reading has no note: " ^ scope)) end
      val () = List.app one hosts
    in List.app (fn why => say ("FAIL documentation notes: " ^ why ^ "\n")) (List.rev (!errors));
       if null (!errors) then say ("check-notes: OK (" ^ Int.toString (length rune) ^ " rune lines and "
              ^ Int.toString (length suiteDiffers) ^ " notes that differ agree; " ^ Int.toString (!count) ^ " host readings of signatures have their note)\n")
       else raise Failed "documentation notes drift" end

  (* Signature boundaries are lexical, so comments, layout and strings cannot
     hide a changed declaration. Keep qualified identifiers as token sequences. *)
  fun signatureTokens text =
    let
      fun rename name = if String.isPrefix "SPEC_" name then String.extract (name, 5, NONE)
                        else if String.isPrefix "SCR_" name then String.extract (name, 4, NONE) else name
      fun loop ([], _, _, acc) = List.rev acc
        | loop ("signature" :: name :: rest, 0, _, acc) = loop (rest, 0, SOME (rename name), acc)
        | loop ((word as "structure") :: rest, 0, _, acc) = loop (rest, 0, NONE, acc)
        | loop ((word as "functor") :: rest, 0, _, acc) = loop (rest, 0, NONE, acc)
        | loop (word :: rest, depth, current, acc) =
            let val depth = if member (word, ["sig", "struct", "let", "local"]) then depth + 1
                            else if word = "end" then depth - 1 else depth
                val word = rename word
                val word = if current = SOME "PRIM_IO" andalso word = "RuneIODesc" then "OS" else word
                (* RuneIODesc.iodesc is the early declaration of OS.IO.iodesc. *)
                val words = if current = SOME "PRIM_IO" andalso word = "OS" andalso
                              (case rest of "." :: "iodesc" :: _ => true | _ => false) then ["OS", ".", "IO"] else [word]
                val acc = case current of NONE => acc | SOME name => List.foldl (fn (word, acc) => (name, word) :: acc) acc words
            in require (depth >= 0, "unbalanced signature declaration"); loop (rest, depth, current, acc) end
    in loop (SmlScan.code text, 0, NONE, []) end
  val limits = {addressSpace = NONE, cpuTime = SOME 600, fileSize = SOME (64 * 1024 * 1024), core = SOME 0}
  fun execute dir name command =
    let val status = Children.exec limits (fn e => e)
          {cmd = command, dir = SOME root, stdin = "", stdout = dir ^ "/" ^ name ^ ".out",
           stderr = dir ^ "/" ^ name ^ ".err", timeout = 600}
    in require (status = 0, name ^ " failed: " ^ firstNonEmpty (dir ^ "/" ^ name ^ ".err")) end
  fun signatures () =
    let
      val files = List.filter (fn file => not (String.isSuffix "_IMP.sml" file)) (sourceFiles "tests/basis/spec-sigs")
      fun transcription file = let val scr = OS.Path.dir file ^ "/scr/" ^ OS.Path.file file
                               in read (if exists scr then scr else file) end
      val expected = List.concat (List.map (signatureTokens o transcription) files)
      val actual = List.concat (List.map (signatureTokens o read) (sourceFiles "lib/basis"))
      val names = unique (List.map #1 expected)
      fun tokens rows name = List.map #2 (List.filter (fn (n, _) => n = name) rows)
      val () = List.app (fn name => require (tokens expected name = tokens actual name,
                        "signature tokens differ: " ^ name)) names
      val dir = (if run = root then fromRoot "tests/out/docs" else run) ^ "/doc-signatures"
      val () = rmTree dir
      val () = mkdirs (dir ^ "/lib/basis")
      val () = List.app (fn file => write (dir ^ "/lib/basis/" ^ file, read (fromRoot ("lib/basis/" ^ file))))
                 (List.filter (fn file => not (isDir (fromRoot ("lib/basis/" ^ file)))) (entries (fromRoot "lib/basis")))
      (* Generation in a private tree is only a producer. Assertions compare its
         result here; the generator's former --check path is never called. *)
      val () = execute dir "generate" ["sh", "scripts/gen-basis-sigs.sh", dir ^ "/lib"]
      val () = require (same (dir ^ "/lib/basis/library.build", fromRoot "lib/basis/library.build"), "stale signature build block")
      val () = List.app (fn file => require (exists (fromRoot ("lib/basis/" ^ file)), "missing signature file " ^ file))
                  (List.filter (String.isSuffix ".sml") (entries (dir ^ "/lib/basis")))
      val () = List.app (fn file =>
           List.app (fn (name, _) => require (member (name, names), "signature file has no transcription: " ^ file ^ ": " ^ name))
               (unique (signatureTokens (read file))))
             (List.filter (fn file => String.isPrefix "sig_" (OS.Path.file file)) (sourceFiles "lib/basis"))
    in say ("gen-basis-sigs: OK (" ^ Int.toString (length names) ^ " signatures have the tokens of their transcriptions)\n") end
  fun annotations () =
    let val dir = (if run = root then fromRoot "tests/out/docs" else run) ^ "/doc-annotations"
        val () = mkdirs dir
        val output = dir ^ "/annotations.txt"
        val () = rmTree output
        val () = execute dir "generate" ["sh", "tests/basis/gen-annotations.sh", "--out", output]
        val () = require (same (output, fromRoot "tests/basis/annotations.txt"), "stale documentation annotations")
    in say "gen-annotations: annotations.txt is up to date\n" end
  fun protect name f () = f () handle Failed message =>
      (say ("FAIL documentation " ^ name ^ ": " ^ message ^ "\n"); Posix.Process.exit 0w1)
    | SmlScan.Bad message => (say ("FAIL documentation " ^ name ^ ": " ^ message ^ "\n"); Posix.Process.exit 0w1)
  fun command ["docs-features"] = SOME (protect "features" features)
    | command ["docs-signatures"] = SOME (protect "signatures" signatures)
    | command ["docs-annotations"] = SOME (protect "annotations" annotations)
    | command ["docs-claims"] = SOME (protect "claims" (fn () => claims (fromRoot "docs/lib/basis/claims.tsv")))
    | command ["docs-claims", file] = SOME (protect "claims" (fn () => claims file))
    | command ["docs-notes"] = SOME (protect "notes" (fn () => notes (fromRoot "docs/lib/basis/notes.tsv") (fromRoot "docs/lib/basis/claims.tsv")))
    | command ["docs-notes", file, claimsFile] = SOME (protect "notes" (fn () => notes file claimsFile))
    | command _ = NONE
  fun job (name, args, after) = Test.it name {program = "/bin/sh", args = ["sh", "-c",
       "exec \"$RUNE_TEST_ROOT\"/bin/rune-doc-check " ^ String.concatWith " " (List.map quote args)],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 1800, cap = 0, cpus = 1,
       memory = 1000, pools = [], exclusive = false, after = after, judge = failLines} : Run.command Test.tree
  val tree = List.foldl (fn (tag, tree) => Test.tag tag tree)
      (Test.describe "documentation" (List.map (fn name => job (name, ["docs-" ^ name], []))
                      ["features", "signatures", "claims", "notes", "annotations"]
                     @ [job ("faults", ["docs-faults"], [])]))
      ["check", "docs", "docs-consistency", "covers:docs/*", "covers:lib/basis/*", "covers:tests/basis/*",
       "covers:tests/runner/doc*.sml", "covers:tests/runner/mutants.sml"]
end
