(* Basis matrix recovery and verdicts. Section decisions preserve source line
   numbers and are cached separately from a producer's success/failure status. *)
structure MatrixSuite =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun member (x, xs) = List.exists (fn y => y = x) xs
  fun unique xs = MatrixProbe.unique xs
  fun trim text = Hosts.trim text
  fun header word text = List.concat (List.map (fn line =>
       let val prefix = "(* " ^ word ^ ": "
       in if String.isPrefix prefix line andalso String.isSuffix " *)" line then
            String.tokens Char.isSpace (String.substring (line, size prefix, size line - size prefix - 3)) else [] end) (lines text))
  fun marker prefix line =
    let val text = trim line
    in if String.isPrefix prefix text then case String.tokens Char.isSpace text of
           [_, name, "*)"] => SOME name | _ => raise Failed "malformed matrix section marker" else NONE end
  fun sections text =
    let fun loop ([], NONE, found) = List.rev found
          | loop ([], SOME name, _) = raise Failed ("unterminated matrix section " ^ name)
          | loop (line :: rest, current, found) =
            case (marker "(*<< " line, marker "(*>> " line, current) of
              (SOME name, _, NONE) => (need (not (member (name, found)), "duplicate matrix section " ^ name); loop (rest, SOME name, name :: found))
            | (SOME _, _, SOME _) => raise Failed "nested matrix section"
            | (_, SOME name, SOME openName) => (need (name = openName, "mismatched matrix section " ^ name); loop (rest, NONE, found))
            | (_, SOME _, NONE) => raise Failed "matrix section ends without an opening marker"
            | _ => loop (rest, current, found)
    in loop (lines text, NONE, []) end
  fun variant text keep =
    let val _ = sections text
        fun loop ([], _) = []
          | loop (line :: rest, blank) = case (marker "(*<< " line, marker "(*>> " line) of
              (SOME name, _) => "" :: loop (rest, not (member (name, keep)))
            | (_, SOME _) => "" :: loop (rest, false)
            | _ => (if blank then "" else line) :: loop (rest, blank)
    in String.concatWith "\n" (loop (String.fields (fn c => c = #"\n") text, false)) end
  fun checks text = List.filter (fn line => List.exists (fn prefix => String.isPrefix prefix line) ["PASS ", "FAIL ", "SKIP "]) (lines text)
  fun label line = case String.tokens Char.isSpace line of _ :: label :: _ => label | _ => ""
  fun validated test output =
    let val results = checks output
        val summaries = List.filter (String.isPrefix "SUMMARY ") (lines output)
        val claimed = case summaries of [line] => (case String.tokens Char.isSpace line of "SUMMARY" :: count :: _ => Int.fromString count | _ => NONE)
                                    | _ => NONE
        val labels = List.map label results
        val duplicates = List.filter (fn name => length (List.filter (fn x => x = name) labels) > 1) (unique labels)
    in results
       @ (if claimed = SOME (length results) then [] else ["FAIL @load/" ^ test ^ " -- SUMMARY count does not match printed checks"])
       @ (if null duplicates then [] else ["FAIL @load/" ^ test ^ " -- duplicate check labels: " ^ String.concatWith " " duplicates]) end
  fun path config = String.translate (fn c => if c = #":" orelse c = #"@" orelse c = #"/" then "-" else str c) config
  fun collect (config : MatrixModel.config) dir test =
    let val () = mkdirs dir
        val source = fromRoot ("tests/basis/" ^ test ^ ".sml")
        val text = read source
        val () = need (exists source, "missing matrix test " ^ source)
        val uses = header "uses" text
        val required = header "requires" text
        val () = List.app (fn file => need (MatrixLoad.dataPath file andalso exists (fromRoot ("tests/basis/" ^ file)), "invalid uses source " ^ file)) uses
        val start = Runtime.clock ()
        val (prefix, image) = MatrixPrepare.ready config dir
        val ctx = MatrixPrepare.context config dir prefix image
        val selectedPrefix = ref prefix
        val work = dir ^ "/" ^ test ^ ".dir"
        val first = ref NONE : Time.time option ref
        fun ownSources file = [fromRoot "tests/basis/harness.sml"] @ List.map (fn file => fromRoot ("tests/basis/" ^ file)) uses
                            @ [file, fromRoot "tests/basis/finish.sml"]
        fun sources file = !selectedPrefix @ ownSources file
        val () = if MatrixLoad.kind config <> "xc1" orelse MatrixLoad.host config <> "mlton"
                       orelse env ("RUNE_MATRIX_NO_SUBSET", "0") <> "0" then () else
          let val deps = dir ^ "/" ^ test ^ ".deps"
              val compiler = MatrixModel.find (env ("RUNE", fromRoot "bin/rune-stack"))
              val status = Children.exec {addressSpace = NONE, cpuTime = SOME (#timeout ctx),
                                          fileSize = SOME (1024 * 1024), core = SOME 0} (fn e => e)
                {cmd = [compiler, "--basis-deps"] @ ownSources source, dir = SOME root, stdin = "",
                 stdout = deps, stderr = deps ^ ".err", timeout = #timeout ctx}
              val wanted = if status = 0 then words deps else []
              val needed = List.filter (fn path => member (OS.Path.file path, wanted)) (words (dir ^ "/basis.loaded"))
          in if null needed then () else selectedPrefix := words (dir ^ "/basis/prelude") @ needed end
        fun load mode file = MatrixLoad.load ctx work mode (sources file)
        fun record results =
          (MatrixPrepare.atomic (dir ^ "/" ^ test ^ ".result", String.concat (List.map (fn line => line ^ "\n") results));
           MatrixPrepare.atomic (dir ^ "/" ^ test ^ ".time", Time.fmt 3 (Time.- (Runtime.clock (), start)) ^ " "
                    ^ Time.fmt 3 (Time.- (getOpt (!first, Runtime.clock ()), start)) ^ " 0\n"))
        fun provided () =
          let val loaded = words (dir ^ "/basis.provides")
              val all = List.concat (List.map (fn line => case String.fields (fn c => c = #"\t") line of [_, names] => String.tokens Char.isSpace names
                                                       | _ => raise Failed "malformed basis provider table") (lines (read (dir ^ "/basis/files"))))
          in List.mapPartial (fn name => if member (name, loaded) then NONE else SOME ((if member (name, all) then "NA " else "ABSENT ") ^ name)) required end
        val notProvided = if MatrixLoad.kind config = "xc1" then provided () else []
        fun firstError result = MatrixPrepare.firstError (#messages result ^ #output result)
        fun absent name =
          let val () = need (name <> "" andalso CharVector.all (fn c => Char.isAlphaNum c orelse Char.contains "_.'" c) name,
                             "invalid required structure " ^ name)
              val file = dir ^ "/" ^ test ^ ".probe.sml"
              val () = write (file, "structure MigrationStructureProbe__ = " ^ name ^ "\n")
              val result = MatrixLoad.load ctx (dir ^ "/" ^ test ^ ".probe.dir") MatrixLoad.Run
                    (prefix @ [fromRoot "tests/basis/harness.sml", file, fromRoot "tests/basis/finish.sml"])
          in not (#loaded result) end
        val cache = dir ^ "/" ^ test ^ ".sections"
        val key = MatrixLoad.hash (source :: List.map (fn file => fromRoot ("tests/basis/" ^ file)) uses)
                      ^ ":" ^ read (dir ^ "/basis.key") ^ ":" ^ #id config ^ ":" ^ #command config ^ ":" ^ Int.toString (#timeout ctx)
        val cached = String.fields (fn c => c = #"\000") (read cache)
        fun materialize suffix keep = let val file = dir ^ "/" ^ test ^ suffix ^ ".sml"
                                     in write (file, variant text keep); file end
        fun publish keep failures = MatrixPrepare.atomic (cache, key ^ "\000" ^ String.concatWith " " keep ^ "\000"
                                                  ^ String.concat (List.map (fn line => line ^ "\n") failures))
        fun split xs = let val half = length xs div 2 in [List.take (xs, half), List.drop (xs, half)] end
        fun recover (original : MatrixLoad.result) =
          let val missing = List.filter absent required
          in if not (null missing) then List.map (fn name => "ABSENT " ^ name) missing else
             let val names = sections text
                 val base = if null names then NONE else SOME (load MatrixLoad.Check (materialize ".base" []))
             in case base of SOME result => if #loaded result then
                 let fun loop ([], keep, failures) = (keep, failures)
                       | loop (group :: rest, keep, failures) =
                         let val result = load MatrixLoad.Check (materialize ".try" group)
                         in if #loaded result then loop (rest, keep @ group, failures)
                            else if length group = 1 then loop (rest, keep, failures @ ["FAIL @section/" ^ test ^ "/" ^ hd group ^ " -- " ^ firstError result])
                            else loop (split group @ rest, keep, failures) end
                     val (keep, failures) = loop (if length names = 1 then [names] else split names, [], [])
                     val () = publish keep failures
                     val result = load MatrixLoad.Run (materialize ".final" keep)
                 in if #loaded result then failures @ validated test (#output result)
                    else failures @ checks (#output result) @ ["FAIL @load/" ^ test ^ " -- " ^ firstError result] end
                 else checks (#output result) @ ["FAIL @load/" ^ test ^ " -- " ^ firstError result]
               | NONE => checks (#output original) @ ["FAIL @load/" ^ test ^ " -- " ^ firstError original] end
          end
        fun fresh () =
          let val firstTry = load MatrixLoad.Run source
              val result = if #loaded firstTry orelse !selectedPrefix = prefix then firstTry else
                              (selectedPrefix := prefix; load MatrixLoad.Run source)
              val () = first := SOME (Runtime.clock ())
          in if #loaded result then (publish ["@all"] []; validated test (#output result))
             else if #timedOut result then checks (#output result) @ ["FAIL @load/" ^ test ^ " -- timed out after " ^ Int.toString (#timeout ctx) ^ " s"]
             else recover result end
        fun execute () = if not (null notProvided) then notProvided else
          case cached of [previous, keep, failures] =>
            if previous = key andalso env ("RUNE_MATRIX_REFRESH", "0") = "0" then
              let val keep = String.tokens Char.isSpace keep
                  val file = if keep = ["@all"] then source else materialize ".final" keep
                  val result = load MatrixLoad.Run file
                  val () = first := SOME (Runtime.clock ())
              in if #loaded result then lines failures @ validated test (#output result) else fresh () end
            else fresh ()
          | _ => fresh ()
    in record (execute ()) end
  fun explain deviations (id, label) =
    let fun matches (r : Expectations.line) = Expectations.glob (#path r, label) andalso
          (Expectations.glob (#way r, id)
           orelse ((String.isPrefix "xc1:" id orelse String.isPrefix "rune:" id) andalso #way r = "rune"
                     andalso member (#category r, ["RUNE-DEV", "SPEC-AMBIGUOUS"]))
           orelse (String.isPrefix "xc2:" id andalso Expectations.glob (#way r, "native:" ^ String.extract (id, 4, NONE))))
    in Option.map (fn r => (r, Expectations.glob (#way r, id) andalso
                         (not (String.isPrefix "xc2:" id) orelse String.isPrefix "xc2" (#way r)))) (List.find matches deviations) end
  fun failures id test results =
    List.filter (String.isPrefix "FAIL ") results @
      (if String.isPrefix "rune" id andalso List.exists (String.isPrefix "ABSENT ") results then
          ["FAIL @absent/" ^ test ^ " -- " ^ String.concatWith ", " (List.filter (String.isPrefix "ABSENT ") results)] else [])
  fun compare deviations id test file =
    let val () = need (exists file, "missing matrix result " ^ file)
        val results = lines (read file)
        val failures = failures id test results
    in List.filter (fn line => not (isSome (explain deviations (id, label line)))) failures end
  fun stale deviations configs tests directory filtered =
    if filtered then [] else
    let val hasRune = List.exists (fn c : MatrixModel.config => #id c = "rune") configs
        fun one (c : MatrixModel.config) =
          let val id = #id c
              fun result test = lines (read (directory c ^ "/" ^ test ^ ".result"))
              val all = List.concat (List.map (fn test => failures id test (result test)) tests)
              val used = List.mapPartial (fn line => case explain deviations (id, label line) of SOME (r, true) => SOME (#number r) | _ => NONE) all
              fun unrun test =
                let val theirs = result test
                    val present = List.map label (checks (String.concatWith "\n" theirs))
                    val rune = if not hasRune orelse id = "rune" then [] else List.map label
                       (checks (read (directory (valOf (List.find (fn c : MatrixModel.config => #id c = "rune") configs)) ^ "/" ^ test ^ ".result")))
                in List.map label (List.filter (String.isPrefix "SKIP ") theirs)
                   @ List.filter (fn label => not (member (label, present))) rune end
              val notRun = List.concat (List.map unrun tests)
          in List.map (fn r : Expectations.line => id ^ " " ^ Expectations.describe r)
             (List.filter (fn r : Expectations.line => Expectations.glob (#way r, id) andalso #category r <> "HOST-FLAKY"
                    andalso (not (String.isPrefix "xc2:" id) orelse String.isPrefix "xc2" (#way r))
                    andalso not (member (#number r, used)) andalso not (List.exists (fn label => Expectations.glob (#path r, label)) notRun)) deviations) end
    in List.concat (List.map one configs) end
end
