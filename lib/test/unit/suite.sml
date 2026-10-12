(* Running a suite: the options, the order, the events and the report. *)
structure Suite :> SUITE_RUN =
struct
  type summary = {tests : int, passed : int, failed : int, skipped : int}

  type options = {list : bool, listMeta : bool, filter : TestFilter.filter, only : string list,
                  after : string option, events : string option, accept : bool, quiet : bool}

  exception Usage of string

  fun options args =
    let
      fun go ([], opt : options) = opt
        | go ("--list" :: rest, {listMeta, filter, only, after, events, accept, quiet, ...}) =
            go (rest, {list = true, listMeta = listMeta, filter = filter, only = only, after = after, events = events,
                       accept = accept, quiet = quiet})
        | go ("--list-meta" :: rest, {list, filter, only, after, events, accept, quiet, ...}) =
            go (rest, {list = list, listMeta = true, filter = filter, only = only, after = after, events = events,
                       accept = accept, quiet = quiet})
        | go ("--filter" :: f :: rest, {list, listMeta, only, after, events, accept, quiet, ...}) =
            go (rest, {list = list, listMeta = listMeta,
                       filter = TestFilter.parse f handle TestFilter.Parse m => raise Usage ("--filter: " ^ m),
                       only = only, after = after, events = events, accept = accept, quiet = quiet})
        | go ("--run" :: p :: rest, {list, listMeta, filter, only, after, events, accept, quiet}) =
            go (rest, {list = list, listMeta = listMeta, filter = filter, only = only @ [p], after = after,
                       events = events, accept = accept, quiet = quiet})
        | go ("--after" :: p :: rest, {list, listMeta, filter, only, events, accept, quiet, ...}) =
            go (rest, {list = list, listMeta = listMeta, filter = filter, only = only, after = SOME p, events = events,
                       accept = accept, quiet = quiet})
        | go ("--events" :: f :: rest, {list, listMeta, filter, only, after, accept, quiet, ...}) =
            go (rest, {list = list, listMeta = listMeta, filter = filter, only = only, after = after, events = SOME f,
                       accept = accept, quiet = quiet})
        | go ("--accept" :: rest, {list, listMeta, filter, only, after, events, quiet, ...}) =
            go (rest, {list = list, listMeta = listMeta, filter = filter, only = only, after = after, events = events,
                       accept = true, quiet = quiet})
        | go ("--quiet" :: rest, {list, listMeta, filter, only, after, events, accept, ...}) =
            go (rest, {list = list, listMeta = listMeta, filter = filter, only = only, after = after, events = events,
                       accept = accept, quiet = true})
        | go (a :: rest, opt) =
            if String.isPrefix "--" a then raise Usage ("unknown option " ^ a ^ " (or its argument missing)")
            else go (rest, opt)
    in
      go (args, {list = false, listMeta = false, filter = TestFilter.all, only = [], after = NONE, events = NONE,
                 accept = false, quiet = false})
    end

  fun json s =
    let
      fun esc #"\"" = "\\\""
        | esc #"\\" = "\\\\"
        | esc #"\n" = "\\n"
        | esc #"\t" = "\\t"
        | esc c = if Char.ord c < 32 then "\\u00" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c))
                  else str c
    in "\"" ^ String.translate esc s ^ "\"" end

  fun jsonList xs = "[" ^ String.concatWith "," (List.map json xs) ^ "]"
  fun jsonOpt f NONE = "null"
    | jsonOpt f (SOME x) = f x

  fun metaJson ({tags, timeout, requires, cpus, memory, pending} : Test.meta) =
    "\"tags\":" ^ jsonList tags
    ^ ",\"timeout\":" ^ jsonOpt (fn t => Real.fmt (StringCvt.FIX (SOME 3)) (Time.toReal t)) timeout
    ^ ",\"requires\":" ^ jsonList requires
    ^ ",\"cpus\":" ^ jsonOpt Int.toString cpus
    ^ ",\"memory\":" ^ jsonOpt Int.toString memory
    ^ ",\"pending\":" ^ jsonOpt json pending

  (* a message of several lines, indented under its test *)
  fun indent m = "  - " ^ String.concatWith "\n    " (String.fields (fn c => c = #"\n") m) ^ "\n"

  fun duplicates paths =
    let
      fun go ([], _, acc) = rev acc
        | go (p :: ps, seen, acc) =
            if List.exists (fn q => q = p) seen then go (ps, seen, if List.exists (fn q => q = p) acc then acc else p :: acc)
            else go (ps, p :: seen, acc)
    in go (paths, [], []) end

  fun run {args, print} tests =
    let
      val opts = options args
      val () = Golden.accept := #accept opts
      val all = Test.leaves tests
      val dups = duplicates (List.map #path all)
      val chosen =
        List.filter (fn {path, meta, ...} =>
                       TestFilter.matches (#filter opts) {path = path, tags = #tags meta}
                       andalso (null (#only opts) orelse List.exists (fn p => p = path) (#only opts))) all
      val chosen =
        case #after opts of
          NONE => chosen
        | SOME p =>
            let
              fun drop ([] : {path : string, meta : Test.meta, leaf : unit -> unit} list) = []
                | drop ({path, ...} :: rest) = if path = p then rest else drop rest
            in if List.exists (fn {path, ...} => path = p) chosen then drop chosen else chosen end
      val events = Option.map TextIO.openAppend (#events opts)
      fun event line = case events of
                         NONE => ()
                       | SOME s => (TextIO.output (s, "{" ^ line ^ "}\n"); TextIO.flushOut s)
      val counts = ref {tests = 0, passed = 0, failed = List.length dups, skipped = 0}
      fun count f = counts := f (!counts)
      fun one {path, meta : Test.meta, leaf} =
        case #pending meta of
          SOME why =>
            (count (fn {tests, passed, failed, skipped} =>
                       {tests = tests + 1, passed = passed, failed = failed, skipped = skipped + 1});
             event ("\"event\":\"end\",\"path\":" ^ json path ^ ",\"verdict\":\"SKIP\",\"message\":" ^ json why);
             print ("SKIP " ^ path ^ ": " ^ why ^ "\n"))
        | NONE =>
            let
              val () = event ("\"event\":\"start\",\"path\":" ^ json path)
              val timer = Timer.startRealTimer ()
              val {outcome, checks} = Expect.run leaf
              val seconds = Real.fmt (StringCvt.FIX (SOME 4)) (Time.toReal (Timer.checkRealTimer timer))
              val messages = case outcome of
                               Expect.Pass => []
                             | Expect.Fail ms => ms
                             | Expect.Error m => ["raised " ^ m]
              val verdict = if null messages then "PASS" else "FAIL"
            in
              List.app (fn m => event ("\"event\":\"check\",\"path\":" ^ json path ^ ",\"message\":" ^ json m)) messages;
              event ("\"event\":\"end\",\"path\":" ^ json path ^ ",\"verdict\":\"" ^ verdict ^ "\",\"checks\":"
                     ^ Int.toString checks ^ ",\"seconds\":" ^ seconds);
              if null messages then
                (count (fn {tests, passed, failed, skipped} =>
                           {tests = tests + 1, passed = passed + 1, failed = failed, skipped = skipped});
                 if #quiet opts then () else print ("PASS " ^ path ^ "\n"))
              else
                (count (fn {tests, passed, failed, skipped} =>
                           {tests = tests + 1, passed = passed, failed = failed + 1, skipped = skipped});
                 print ("FAIL " ^ path ^ "\n" ^ String.concat (List.map indent messages)))
            end
    in
      List.app (fn p => print ("FAIL " ^ p ^ ": two tests have this path\n")) dups;
      (if #list opts then List.app (fn {path, ...} => print (path ^ "\n")) chosen
       else if #listMeta opts then
         List.app (fn {path, meta, ...} => print ("{\"path\":" ^ json path ^ "," ^ metaJson meta ^ "}\n")) chosen
       else
         (List.app one chosen;
          let val {tests, passed, failed, skipped} = !counts
          in print ("SUMMARY " ^ Int.toString tests ^ " tests, " ^ Int.toString passed ^ " passed, "
                    ^ Int.toString failed ^ " failed, " ^ Int.toString skipped ^ " skipped\n")
          end));
      Option.app TextIO.closeOut events;
      !counts
    end
    handle Usage m => (print ("FAIL usage: " ^ m ^ "\n"); {tests = 0, passed = 0, failed = 1, skipped = 0})

  fun main tests =
    let val {failed, ...} = run {args = CommandLine.arguments (), print = print} tests
    in if failed > 0 then OS.Process.exit OS.Process.failure else () end
end

(* The program of a suite: the suite's tests run with the program's
   arguments, as `Suite.main` runs them. *)
functor Main (S : SUITE) :> SUITE_MAIN =
struct
  fun main () = Suite.main S.tests
end
