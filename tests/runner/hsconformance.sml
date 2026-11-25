(* rhc's conformance table (docs/plans/language/haskell98.md, D53, M1;
   docs/testing.md, rhc's conformance table): tests/hs/conformance.tsv, a
   row for each clause of the Haskell 98 Report, kept to rhc's programs by
   id in both directions, as DocChecks.features keeps docs/language.md to
   tests/lang.

   A row has E9's columns -- id, section, statement, class, test (accept,
   reject, run or none), how, source -- and three more: status (Supported,
   Partial or Planned), reading (the R numbers of E9's readings that concern
   it, or nothing: E9's R1 to R54, or one with a heading of its own in
   tests/hs/readings.md) and deviation (the program that pins it, `DIR/NAME` from
   tests/hs, or nothing). A program of tests/hs/lang, tests/hs/accept or
   tests/hs/errors names the row of its name's id, the part before its
   first `_`, and on its first line, `-- rows: ...`, the further rows it
   covers, the readings it pins (`R2`) and `deviation` where it pins one.
   The rules, each direction a failure:
   1. a row whose test is accept, reject or run and that is not Planned has
      a program of its class that names it (accept: tests/hs/accept or
      tests/hs/lang; run: tests/hs/lang; reject: tests/hs/errors), or its
      deviation's pin, which is of the other class;
   2. what a program names is a row, of a test its directory serves, but
      the row whose deviation it pins;
   3. a row whose test is none says why in how;
   4. a row with a reading, not Planned, has a program that names it and
      pins each of its readings, and a program pins only readings of the
      rows it names; a row with a deviation names its pin, a program that
      names the row and says `deviation`, and has its note in
      tests/hs/deviations.tsv (its ground, one of D38's four, and why), and
      a pin and a note are each of a row's deviation;
   5. a program of tests/hs/errors has an `.expected`, the text of rhc's own
      message, so that a program refused for another reason fails.
   And the table and the list of errata it applies (tests/hs/errata.tsv,
   D38): their headers, a row's form, no id twice, every row accounted
   for -- E9's 3,901 and what an erratum adds -- and every row whose text
   names an erratum listed by one, and back.

   `hs/conformance/table` checks the tree's; `hs/conformance/faults` plants
   a breach of each rule, and of the table's form, in a private tree, and
   wants it refused, and a row pinned as the rules want accepted.

   A table is an edition's (the haskell2010 roadmap's M1 and D38): Haskell
   98's, above, and Haskell 2010's, tests/hs2010/conformance.tsv, E1's
   5,259 rows with W8's corrections, less the five of 98's chapter 23 that
   leave it (N21), every row Planned, with two more columns: map98, the 98
   rows a row comes from, and delta (same, changed, new or removed-in-2010).
   Its errata are none (the Report of 2010 has none published), its
   readings R1 to R54 and 98's later ones, and N1 to N21 of E1 with those
   tests/hs2010/readings.md heads; its programs are tests/hs2010's, and
   those of tests/hs it shares by clause id: a program of tests/hs serves
   it when every row the program names is a row of it that its text keeps
   (not removed-in-2010), but those tests/hs2010/unshared.tsv names, each
   with why it stays 98's. The same five rules hold of it, each program
   judged by its own table, and `hs2010/conformance/table` and `faults` are
   its jobs. *)
structure HsConformance =
struct
  open Sh

  val header = ["id", "section", "statement", "class", "test", "how", "source", "status", "reading", "deviation"]
  val errataHeader = ["date", "section", "erratum", "rows", "adds", "note"]
  val deviationsHeader = ["id", "ground", "pin", "note"]
  (* E9's rows, and the errata of the Report's page (D38) *)
  val clauses = 3901
  val errataCount = 18
  val classes = ["dynamic", "layout", "lex", "library", "module", "prelude", "static", "syntax"]
  val testKinds = ["accept", "reject", "run", "none"]
  val statuses = ["Supported", "Partial", "Planned"]
  val sources = ["hand", "generated"]
  val grounds = ["wrong", "contradictory", "ambiguous", "conceded by the Report"]
  (* E9's readings, which its readings.md in the drafts holds; those after
     have their headings in tests/hs/readings.md *)
  val readings = 54
  val dirs = ["lang", "accept", "errors"]

  (* ---- the tables, an edition each: its name; its jobs' family; where its
     files are; its header; the rows it was made with and those a decision
     took out of it, each with the 98 row it came from; its errata; its
     readings (a letter, how many its experiment numbered, and the file whose
     headings name more); and where the programs are whose ids it shares, if
     another table's *)
  type edition =
    {name : string, group : string, root : string, header : string list, clauses : int,
     left : (string * string) list, errataCount : int, readings : (string * int * string) list, shared : string option}
  val edition98 : edition =
    {name = "98", group = "hs/conformance", root = "tests/hs", header = header, clauses = clauses, left = [],
     errataCount = errataCount, readings = [("R", readings, "tests/hs/readings.md")], shared = NONE}
  val deltas = ["same", "changed", "new", "removed-in-2010"]
  (* Haskell 2010's (D38): E1's rows, less 98's chapter 23's that leave it
     under N21 (D38's (d)(i): 98's behaviour kept as rhc's documented choice),
     no errata, E1's readings N1 to N21 beside 98's, and 98's programs shared *)
  val edition2010 : edition =
    {name = "2010", group = "hs2010/conformance", root = "tests/hs2010", header = header @ ["map98", "delta"],
     clauses = 5259,
     left = [("lib.r.systemexit.term.error", "lib.r.system.term.error"),
             ("lib.r.systemexit.term.ioerror", "lib.r.system.term.ioerror"),
             ("lib.r.systemexit.term.normal", "lib.r.system.term.normal"),
             ("lib.r.systemenvironment.exitwith.close", "lib.r.system.exitwith.close"),
             ("lib.r.systemenvironment.term.loop", "lib.r.system.term.loop")],
     errataCount = 0, readings = [("R", readings, "tests/hs/readings.md"), ("N", 21, "tests/hs2010/readings.md")],
     shared = SOME "tests/hs"}
  val unsharedHeader = ["program", "why"]

  fun member (x, xs) = List.exists (fn y => y = x) xs
  fun trim s = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace (Substring.full s)))

  (* ---- a map of strings, sorted *)
  fun sortBy (key : 'a -> string) xs =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if key y < key x then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
      fun split (x :: y :: rest) = let val (a, b) = split rest in (x :: a, y :: b) end
        | split xs = (xs, [])
      fun go [] = []
        | go [x] = [x]
        | go xs = let val (a, b) = split xs in merge (go a, go b) end
    in go xs end
  (* the entries of a sorted vector whose key is k *)
  fun lookup (v, key : 'a -> string) k =
    let
      fun first (lo, hi) = if lo >= hi then lo
                           else let val mid = (lo + hi) div 2
                                in if key (Vector.sub (v, mid)) < k then first (mid + 1, hi) else first (lo, mid) end
      fun from i = if i < Vector.length v andalso key (Vector.sub (v, i)) = k then Vector.sub (v, i) :: from (i + 1) else []
    in from (first (0, Vector.length v)) end

  (* ---- the table *)
  type row = {id : string, section : string, statement : string, test : string, how : string, status : string,
              reading : string list, deviation : string, map98 : string list, delta : string}
  (* a field of a row of a table whose header is hdr *)
  fun fieldIn hdr (fields, name) =
    let fun go (h :: hs, f :: fs) = if h = name then f else go (hs, fs)
          | go _ = ""
    in go (hdr, fields) end
  fun field (fields, name) = fieldIn header (fields, name)
  fun goodId id =
    id <> "" andalso Char.isLower (String.sub (id, 0))
    andalso CharVector.all (fn c => Char.isLower c orelse Char.isDigit c orelse c = #".") id
  (* the readings a file under root heads, ### Ln. for the letter L *)
  fun headedIn (root, letter, file) =
    List.mapPartial (fn l => case String.tokens Char.isSpace l of
                               "###" :: r :: _ => if size r > 2 andalso String.isPrefix letter r andalso String.isSuffix "." r
                                                  then Int.fromString (String.substring (r, 1, size r - 2)) else NONE
                             | _ => NONE)
                    (String.fields (fn c => c = #"\n") (read (root ^ "/" ^ file)))
  fun readingsOf root = headedIn (root, "R", "tests/hs/readings.md")
  (* whether r is a reading of an edition's: its letter's, numbered by the
     experiment or headed (`more`, by letter) *)
  fun goodReadingOf (ed : edition) more r =
    size r > 1 andalso CharVector.all Char.isDigit (String.extract (r, 1, NONE))
    andalso List.exists (fn (letter, n, _) =>
                           String.isPrefix letter r
                           andalso (case Int.fromString (String.extract (r, 1, NONE)) of
                                      SOME k => (k >= 1 andalso k <= n)
                                                orelse List.exists (fn (l, ks) => l = letter andalso List.exists (fn m => m = k) ks) more
                                    | NONE => false))
                        (#readings ed)
  fun goodReading more r = goodReadingOf edition98 [("R", more)] r
  (* a reading's name in a program's first line: R or N and its number *)
  fun isReading w = size w > 1 andalso (String.sub (w, 0) = #"R" orelse String.sub (w, 0) = #"N")
                    andalso CharVector.all Char.isDigit (String.extract (w, 1, NONE))

  (* ---- the programs *)
  type program = {dir : string, path : string, name : string, ids : string list, pins : string list, deviation : bool,
                  expected : string, imports98 : bool}

  (* the modules of Haskell 98's library that Haskell 2010's renames or
     drops: all but Numeric (D38's (e); tools/generate/hs2010.sml's import
     map) *)
  val only98 = ["Array", "Char", "Complex", "CPUTime", "Directory", "IO", "Ix", "List", "Locale", "Maybe", "Monad", "Random",
                "Ratio", "System", "Time"]
  (* whether a program imports one of them, in any of its modules: such a
     program stays 98's, and its 2010 program is written with its imports
     rewritten (bin/rune-generate hs2010-programs) *)
  fun importsOnly98 (p : Lang.program) =
    let
      val files = if isDir (#base p) then glob (#base p, ".hs") @ glob (#base p, ".lhs") else [#src p]
      fun imports file =
        List.exists (fn l =>
          let val c = if String.isSuffix ".lhs" file then (if String.isPrefix "> " l then String.extract (l, 2, NONE) else "") else l
          in case String.tokens Char.isSpace c of
               "import" :: "qualified" :: m :: _ => member (hd (String.fields (fn ch => ch = #"(" orelse ch = #";") m), only98)
             | "import" :: m :: _ => member (hd (String.fields (fn ch => ch = #"(" orelse ch = #";") m), only98)
             | _ => false
          end) (String.fields (fn c => c = #"\n") (read file))
    in List.exists imports files end
  (* the first line of the file f, to Haskell's first newline: a return, a
     line feed or a form feed (2.2) *)
  fun firstLine f = hd (String.fields (fn c => c = #"\n" orelse c = #"\r" orelse c = #"\f") (read f))
  (* the words of a program's first line after `-- rows:`, a literate one's
     after a bird track too *)
  fun firstWords src =
    let val l = firstLine src
        val l = if String.isPrefix "> " l then String.extract (l, 2, NONE) else l
    in case String.tokens Char.isSpace l of "--" :: "rows:" :: ws => ws | _ => [] end
  (* the rows a program names: its name's id, then those of its first line *)
  fun idsOf (p : Lang.program) =
    hd (String.fields (fn c => c = #"_") (#name p))
    :: List.filter (fn w => not (isReading w) andalso w <> "deviation") (firstWords (#src p))
  (* the programs of the directories lang, accept and errors under `base`
     (from root), each path from there with `prefix` before it *)
  fun programsUnder (root, base, prefix) : program list =
    List.concat (List.map (fn d =>
      List.map (fn (p : Lang.program) =>
        let
          val ws = firstWords (#src p)
          val ids = idsOf p
        in
          {dir = d, path = prefix ^ d ^ "/" ^ #name p, name = #name p, ids = ids, pins = List.filter isReading ws,
           deviation = member ("deviation", ws), expected = #base p ^ ".expected", imports98 = importsOnly98 p}
        end)
        (Lang.programsOf (root ^ "/" ^ base ^ "/" ^ d, [".hs", ".lhs"], ["Main.hs", "Main.lhs"])))
      dirs)
  fun programs root = programsUnder (root, "tests/hs", "")
  (* ---- whether a program's jobs run: not while every row it names is
     Planned (or no row), so that a row leaves Planned with its program's
     jobs, which rhc then passes (docs/testing.md, rhc's conformance table) *)
  val statusCache : (string * string) vector option ref = ref NONE
  fun statusOf id =
    let
      val v =
        case !statusCache of
          SOME v => v
        | NONE =>
            let
              fun one line = case String.fields (fn c => c = #"\t") line of
                               fs as _ :: _ :: _ :: _ :: _ :: _ :: _ :: _ :: _ => SOME (hd fs, List.nth (fs, 7))
                             | _ => NONE
              val lines = String.fields (fn c => c = #"\n") (read (fromRoot "tests/hs/conformance.tsv"))
              val v = Vector.fromList (sortBy #1 (List.mapPartial one (if null lines then [] else tl lines)))
            in statusCache := SOME v; v end
    in case lookup (v, #1) id of (_, status) :: _ => SOME status | [] => NONE end
  fun planned (p : Lang.program) =
    List.all (fn id => case statusOf id of SOME "Planned" => true | NONE => true | SOME _ => false) (idsOf p)
  fun pending p = if planned p then SOME "the rows it tests are Planned (tests/hs/conformance.tsv)" else NONE

  (* ---- the same for the 2010 suites (tests/runner/hslang.sml): a row's
     status and delta in tests/hs2010/conformance.tsv, read once *)
  val cache2010 : (string * (string * string)) vector option ref = ref NONE
  fun row2010 id =
    let
      val v =
        case !cache2010 of
          SOME v => v
        | NONE =>
            let
              val hdr = #header edition2010
              fun one line = case String.fields (fn c => c = #"\t") line of
                               fs as _ :: _ => if length fs = length hdr
                                               then SOME (hd fs, (fieldIn hdr (fs, "status"), fieldIn hdr (fs, "delta"))) else NONE
                             | [] => NONE
              val lines = String.fields (fn c => c = #"\n") (read (fromRoot "tests/hs2010/conformance.tsv"))
              val v = Vector.fromList (sortBy #1 (List.mapPartial one (if null lines then [] else tl lines)))
            in cache2010 := SOME v; v end
    in case lookup (v, #1) id of (_, x) :: _ => SOME x | [] => NONE end
  (* the programs of tests/hs that tests/hs2010/unshared.tsv keeps 98's *)
  val unsharedCache : string list option ref = ref NONE
  fun unshared2010 () =
    case !unsharedCache of
      SOME xs => xs
    | NONE => let val xs = List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                                                      p :: _ :: _ => if p = "program" then NONE else SOME p
                                                    | _ => NONE)
                                          (String.fields (fn c => c = #"\n") (read (fromRoot "tests/hs2010/unshared.tsv")))
              in unsharedCache := SOME xs; xs end
  (* whether a program of tests/hs/KIND serves the 2010 table: every row it
     names is a row of 2010's that its text keeps, and unshared.tsv does not
     name it *)
  fun shared2010 kind (p : Lang.program) =
    List.all (fn id => case row2010 id of SOME (_, delta) => delta <> "removed-in-2010" | NONE => false) (idsOf p)
    andalso not (importsOnly98 p)
    andalso not (member ("hs/" ^ kind ^ "/" ^ #name p, unshared2010 ()))
  (* whether bin/rhc checks a program of Haskell 2010, a Main that is main
     alone: it takes --language=haskell2010 from the roadmap's M4, and reads
     the 2010 Prelude once M10 and M12 give it one. Asked once a run, and
     kept between runs in tests/out/hs2010-probe while bin/rhc.rbc and the
     files of share/rhc/haskell2010 are as they were, since the check reads
     the whole 2010 library until M6 makes its snapshot *)
  val languageCache : string option option ref = ref NONE
  fun language2010 () =
    case !languageCache of
      SOME x => x
    | NONE =>
        let
          fun stamp f = (Position.toString (OS.FileSys.fileSize f) ^ "@" ^ Time.toString (OS.FileSys.modTime f))
                        handle OS.SysErr _ => "-"
          fun files d = List.concat (List.map (fn n => let val p = d ^ "/" ^ n in if isDir p then files p else [p] end)
                                              (sort (entries d)))
          val key = String.concatWith " " (List.map stamp (fromRoot "bin/rhc.rbc" :: files (fromRoot "share/rhc/haskell2010")))
          val memo = fromRoot "tests/out/hs2010-probe"
          val dir = run ^ "/hs2010-probe"
          fun probe () =
            let
              val () = mkdirs dir
              val () = write (dir ^ "/Main.hs", "main :: IO ()\nmain = return ()\n")
              val status = execProcess false Subprocess.unlimited (fn e => setEnv ("RHC_STORE", "") e)
                             {cmd = [fromRoot "bin/rhc", "--language=haskell2010", "--typecheck-only", "Main.hs"], dir = SOME dir,
                              stdin = "", stdout = dir ^ "/out", stderr = dir ^ "/out", timeout = 120}
            in
              if status = 0 then NONE
              else SOME ("bin/rhc checks no Haskell 2010 program yet, a Main of main alone (until the roadmap's M10 and M12 "
                         ^ "make its 2010 library check): " ^ firstNonEmpty (dir ^ "/out"))
            end
          (* what the last probe of these files said: SOME (NONE) where it checked *)
          val memoed = case lines (read memo) of
                         k :: rest => if k = key then SOME (case rest of [] => NONE | w :: _ => SOME w) else NONE
                       | [] => NONE
          val why =
            if not (exists (fromRoot "bin/rhc")) then SOME "no bin/rhc"
            else
              case memoed of
                SOME w => w
              | NONE => let val w = probe ()
                        in ((mkdirs (fromRoot "tests/out");
                             write (memo, key ^ "\n" ^ (case w of SOME x => x ^ "\n" | NONE => "")))
                            handle IO.Io _ => () | OS.SysErr _ => ());
                           w end
        in languageCache := SOME why; why end
  fun pending2010 p =
    case language2010 () of
      SOME why => SOME why
    | NONE =>
        if List.all (fn id => case row2010 id of SOME ("Planned", _) => true | NONE => true | SOME _ => false) (idsOf p)
        then SOME "the rows it tests are Planned (tests/hs2010/conformance.tsv)" else NONE
  (* the same of a file of a program of tests/hs/lang or tests/hs/accept,
     a module of a directory among them *)
  (* the programs of a directory, listed once: every job's runner builds the
     whole tree, and the relations ask of each program *)
  val programsCache : (string * Lang.program list) list ref = ref []
  fun programsIn d =
    case List.find (fn (x, _) => x = d) (!programsCache) of
      SOME (_, ps) => ps
    | NONE => let val ps = Lang.programsOf (d, [".hs", ".lhs"], ["Main.hs", "Main.lhs"]) in programsCache := (d, ps) :: !programsCache; ps end
  fun pendingFile file =
    case List.find (fn d => String.isPrefix (d ^ "/") file) ["tests/hs/lang", "tests/hs/accept"] of
      NONE => NONE
    | SOME d =>
        let val first = hd (String.fields (fn c => c = #"/") (String.extract (file, size d + 1, NONE)))
        in
          case List.find (fn (p : Lang.program) => #src p = file orelse String.isPrefix (d ^ "/" ^ first ^ "/") (#src p))
                         (programsIn d) of
            SOME p => pending p
          | NONE => NONE
        end

  (* held while any of ids is Planned: what needs every row it names, as
     a metamorphic relation or a generated program does *)
  fun pendingUntil ids =
    case List.filter (fn id => case statusOf id of SOME "Planned" => true | NONE => true | SOME _ => false) ids of
      [] => NONE
    | id :: _ => SOME ("it needs " ^ id ^ ", which is Planned (tests/hs/conformance.tsv)")

  (* the directories whose programs serve a row's test *)
  fun serves test = case test of "accept" => ["accept", "lang"] | "run" => ["lang"] | "reject" => ["errors"] | _ => []

  (* ---- the check: the failures of an edition's table in the tree at root *)
  fun checkWith (ed : edition) root =
    let
      val errors = ref [] : string list ref
      fun fail m = errors := m :: !errors
      val base = #root ed
      fun tsv (file, hdr) =
        DocChecks.tsv (root ^ "/" ^ file) hdr
        handle DocChecks.Failed m => (fail ("table: " ^ m); [])
      val table = tsv (base ^ "/conformance.tsv", #header ed)
      val errata = tsv (base ^ "/errata.tsv", errataHeader)
      val notes = tsv (base ^ "/deviations.tsv", deviationsHeader)
      val more = List.map (fn (l, _, f) => (l, headedIn (root, l, f))) (#readings ed)
      val hasDelta = member ("delta", #header ed)
      val readingsText = "neither " ^ String.concatWith " nor "
                                        (List.concat (List.map (fn (l, n, f) => ["one of " ^ l ^ "1 to " ^ l ^ Int.toString n, "one of " ^ f])
                                                               (#readings ed)))
      (* the table's form *)
      val rows : row list =
        List.map (fn fs =>
          let
            val get = fn name => fieldIn (#header ed) (fs, name)
            val id = get "id"
            val reading = String.tokens Char.isSpace (get "reading")
            fun one (name, allowed) =
              if member (get name, allowed) then ()
              else fail ("table: " ^ id ^ " has the " ^ name ^ " " ^ get name ^ ", not one of " ^ String.concatWith ", " allowed)
          in
            if goodId id then () else fail ("table: the id " ^ id ^ " is not lower-case letters, digits and dots");
            one ("class", classes); one ("test", testKinds); one ("status", statuses); one ("source", sources);
            if hasDelta then one ("delta", deltas) else ();
            List.app (fn r => if goodReadingOf ed more r then ()
                              else fail ("table: " ^ id ^ " has the reading " ^ r ^ ", " ^ readingsText)) reading;
            {id = id, section = get "section", statement = get "statement", test = get "test",
             how = get "how", status = get "status", reading = reading, deviation = get "deviation",
             map98 = String.tokens Char.isSpace (get "map98"), delta = get "delta"}
          end) table
      val byId = Vector.fromList (sortBy #id rows)
      fun row id = case lookup (byId, #id) id of r :: _ => SOME r | [] => NONE
      val () = Vector.appi (fn (i, r : row) => if i > 0 andalso #id (Vector.sub (byId, i - 1)) = #id r
                                                then fail ("table: the id " ^ #id r ^ " is twice") else ()) byId
      (* the rows a decision took out, out; and, for a table of another
         edition than 98, its rows against 98's: each row's 98 rows are
         rows of 98's, a row the same as 98's is 98's, and every row of 98's
         is one some row comes from, or one that left *)
      val () = List.app (fn (id, _) => if isSome (row id) then fail ("table: " ^ id ^ " left the table by a decision, and is in it")
                                       else ()) (#left ed)
      val () =
        if not hasDelta then ()
        else
          let
            val ids98 = Vector.fromList (sortBy (fn x => x) (List.map (fn fs => field (fs, "id"))
                                                              (tsv ("tests/hs/conformance.tsv", header))))
            fun is98 id = not (null (lookup (ids98, fn x => x) id))
            val mapped = Vector.fromList (sortBy (fn x => x) (List.concat (List.map #map98 rows) @ List.map #2 (#left ed)))
          in
            List.app (fn (r : row) =>
                        (List.app (fn m => if m = "-" orelse is98 m then ()
                                           else fail ("table: " ^ #id r ^ " comes from " ^ m ^ ", which is no row of 98's")) (#map98 r);
                         if #delta r = "new" orelse not (null (#map98 r) orelse #map98 r = ["-"]) then ()
                         else fail ("table: " ^ #id r ^ " is " ^ #delta r ^ ", and comes from no row of 98's");
                         if #delta r = "same" andalso #map98 r <> [#id r] then
                           fail ("table: " ^ #id r ^ " is the same as 98's, and comes from " ^ String.concatWith " " (#map98 r))
                         else ())) rows;
            Vector.app (fn id => if null (lookup (mapped, fn x => x) id)
                                 then fail ("table: 98's row " ^ id ^ " is no row's map98, and left no row") else ()) ids98
          end
      (* the errata *)
      fun words s = String.tokens Char.isSpace s
      val added = List.concat (List.map (fn fs => words (List.nth (fs, 4))) errata)
      val listed = List.concat (List.map (fn fs => words (List.nth (fs, 3))) errata) @ added
      val () = if length errata = #errataCount ed then ()
               else fail ("errata: " ^ base ^ "/errata.tsv lists " ^ Int.toString (length errata) ^ " errata, not the page's "
                          ^ Int.toString (#errataCount ed))
      val () = List.app (fn fs => case List.filter (fn gs => List.take (gs, 2) = List.take (fs, 2)) errata of
                                    [_] => ()
                                  | _ => fail ("errata: " ^ String.concatWith " " (List.take (fs, 2)) ^ " is listed twice")) errata
      val () = List.app (fn id => if isSome (row id) then () else fail ("errata: an erratum names " ^ id ^ ", which is no row")) listed
      val clausesText = if null (#left ed) then Int.toString (#clauses ed)
                        else Int.toString (#clauses ed) ^ " less the " ^ Int.toString (length (#left ed)) ^ " that left it"
      val () = if length rows = #clauses ed - length (#left ed) + length added then ()
               else fail ("table: " ^ Int.toString (length rows) ^ " rows, where E9's " ^ clausesText ^ " and the "
                          ^ Int.toString (length added) ^ " the errata add are "
                          ^ Int.toString (#clauses ed - length (#left ed) + length added))
      fun namesErratum (r : row) =
        let fun has s = String.isSubstring "errat" (String.map Char.toLower s) in has (#statement r) orelse has (#how r) end
      (* a table with errata of its own holds each row that names one to it;
         2010's has none, and 98's it does not absorb are its reading N18 *)
      val () = if #errataCount ed = 0 then ()
               else List.app (fn (r : row) =>
                           case (namesErratum r, member (#id r, listed)) of
                             (true, false) => fail ("errata: " ^ #id r ^ " names an erratum, and no erratum lists it")
                           | (false, true) => fail ("errata: an erratum lists " ^ #id r ^ ", whose text names none")
                           | _ => ()) rows
      (* the programs: the table's own, and those it shares, which name only
         rows it keeps, import no module of 98's library that 2010's renames
         or drops, and which its unshared.tsv does not name *)
      fun kept id = case row id of SOME r => #delta r <> "removed-in-2010" | NONE => false
      val own = programsUnder (root, base, "")
      val (shared, _) =
        case #shared ed of
          NONE => ([], [])
        | SOME other =>
            let
              val prefix = OS.Path.file other ^ "/"
              val exceptions = List.map (fn fs => (hd fs, List.nth (fs, 1))) (tsv (base ^ "/unshared.tsv", unsharedHeader))
              val theirs = programsUnder (root, other, prefix)
              fun sharable (p : program) = List.all kept (#ids p) andalso not (#imports98 p)
              val () = List.app (fn (path, why) =>
                                   case List.find (fn (p : program) => #path p = path) theirs of
                                     NONE => fail ("unshared: " ^ path ^ " is no program of " ^ other)
                                   | SOME p => if not (sharable p) then
                                                 fail ("unshared: " ^ path ^ " names a row the table does not keep, or imports a module "
                                                       ^ "of 98's library that 2010's renames or drops, and is shared by none")
                                               else if trim why = "" then fail ("unshared: " ^ path ^ " says not why")
                                               else ()) exceptions
            in (List.filter (fn (p : program) => sharable p andalso not (List.exists (fn (q, _) => q = #path p) exceptions)) theirs,
                exceptions) end
      val progs = own @ shared
      val naming = Vector.fromList (sortBy #1 (List.concat (List.map (fn (p : program) => List.map (fn id => (id, p)) (#ids p)) progs)))
      fun programsOf id = List.map #2 (lookup (naming, #1) id)
      val () = List.app (fn (p : program) =>
                           let
                             val twice = List.filter (fn (q : program) => #path q = #path p) progs
                           in if length twice > 1 then fail ("table: two programs named " ^ #path p) else () end) progs
      (* a program is a row's pin: it says deviation, and the row names it *)
      fun pins (p : program, r : row) = #deviation p andalso #deviation r = #path p
      (* the directory a program is in, from the root *)
      fun dirOf (p : program) = if String.isPrefix (#dir p ^ "/") (#path p) then base ^ "/" ^ #dir p else "tests/" ^ OS.Path.dir (#path p)
      fun dirsText test = base ^ "/" ^ String.concatWith (" or " ^ base ^ "/") (serves test)
                          ^ (case #shared ed of SOME other => ", or of " ^ other ^ " that it shares," | NONE => "")
      (* rule 1 *)
      val () = List.app (fn (r : row) =>
                           if #status r = "Planned" orelse #test r = "none" then ()
                           else if List.exists (fn (p : program) => member (#dir p, serves (#test r)) orelse pins (p, r))
                                               (programsOf (#id r)) then ()
                           else fail ("rule 1: " ^ #id r ^ " is " ^ #status r ^ ", and no program of "
                                      ^ dirsText (#test r) ^ " names it")) rows
      (* rule 2 *)
      val () = List.app (fn (p : program) =>
                           List.app (fn id =>
                                       case row id of
                                         NONE => fail ("rule 2: " ^ #path p ^ " names " ^ id ^ ", which is no row")
                                       | SOME r => if member (#dir p, serves (#test r)) orelse pins (p, r) then ()
                                                   else fail ("rule 2: " ^ #path p ^ " names " ^ id ^ ", whose test is " ^ #test r
                                                              ^ ", which " ^ dirOf p ^ " does not serve"))
                                    (#ids p)) progs
      (* rule 3 *)
      val () = List.app (fn (r : row) => if #test r = "none" andalso trim (#how r) = "" then
                                           fail ("rule 3: " ^ #id r ^ " has no test, and how gives no reason") else ()) rows
      (* rule 4: readings *)
      val () = List.app (fn (r : row) =>
                           if #status r = "Planned" then ()
                           else List.app (fn rd => if List.exists (fn (p : program) => member (rd, #pins p)) (programsOf (#id r)) then ()
                                                   else fail ("rule 4: " ^ #id r ^ " has the reading " ^ rd ^ ", and no program that names it pins it"))
                                         (#reading r)) rows
      val () = List.app (fn (p : program) =>
                           List.app (fn rd => if List.exists (fn id => case row id of SOME r => member (rd, #reading r) | NONE => false) (#ids p) then ()
                                              else fail ("rule 4: " ^ #path p ^ " pins " ^ rd ^ ", the reading of no row it names"))
                                    (#pins p)) progs
      (* rule 4: deviations, their pins and their notes *)
      val notesFile = base ^ "/deviations.tsv"
      fun noteOf id = List.filter (fn fs => hd fs = id) notes
      val () = List.app (fn (r : row) =>
                           if #deviation r = "" then ()
                           else
                             (case List.filter (fn (p : program) => #path p = #deviation r) progs of
                                [] => fail ("rule 4: " ^ #id r ^ "'s deviation is pinned by " ^ #deviation r ^ ", which is no program")
                              | p :: _ =>
                                  if not (member (#id r, #ids p)) then fail ("rule 4: " ^ #id r ^ "'s pin " ^ #path p ^ " does not name it")
                                  else if not (#deviation p) then fail ("rule 4: " ^ #id r ^ "'s pin " ^ #path p ^ " does not say deviation")
                                  else ();
                              case noteOf (#id r) of
                                [fs] => if List.nth (fs, 2) <> #deviation r then
                                          fail ("rule 4: the note of " ^ #id r ^ " names the pin " ^ List.nth (fs, 2) ^ ", not " ^ #deviation r)
                                        else if not (member (List.nth (fs, 1), grounds)) then
                                          fail ("rule 4: the note of " ^ #id r ^ " gives the ground " ^ List.nth (fs, 1) ^ ", not one of "
                                                ^ String.concatWith ", " grounds)
                                        else if trim (List.nth (fs, 3)) = "" then fail ("rule 4: the note of " ^ #id r ^ " says nothing")
                                        else ()
                              | [] => fail ("rule 4: " ^ #id r ^ " deviates, and has no note in " ^ notesFile)
                              | _ => fail ("rule 4: " ^ #id r ^ " has two notes in " ^ notesFile))) rows
      val () = List.app (fn fs => case row (hd fs) of
                                    SOME r => if #deviation r = "" then fail ("rule 4: " ^ notesFile ^ " notes " ^ hd fs
                                                                              ^ ", which does not deviate") else ()
                                  | NONE => fail ("rule 4: " ^ notesFile ^ " notes " ^ hd fs ^ ", which is no row")) notes
      val () = List.app (fn (p : program) =>
                           if #deviation p andalso not (List.exists (fn id => case row id of SOME r => #deviation r = #path p | NONE => false)
                                                                     (#ids p))
                           then fail ("rule 4: " ^ #path p ^ " says deviation, and no row it names has it as its pin") else ()) progs
      (* rule 5, and what every run program has *)
      val () = List.app (fn (p : program) =>
                           if #dir p = "errors" andalso trim (read (#expected p)) = "" then
                             fail ("rule 5: " ^ #path p ^ " has no .expected with rhc's message")
                           else if #dir p = "lang" andalso not (exists (#expected p)) then
                             fail ("programs: " ^ #path p ^ " has no .expected")
                           else ()) progs
    in
      (List.rev (!errors), rows, progs)
    end
  fun check root = checkWith edition98 root

  (* ---- breaches planted in a private tree *)
  (* the base of each: an edition's table with every row Planned and no
     deviation, none noted, and the tree's errata and readings, and for a
     table that shares 98's programs, 98's table, readings and unshared.tsv
     empty; no program *)
  val deviationsHead = String.concatWith "\t" deviationsHeader ^ "\n"
  fun tableTextOf (ed : edition) =
    String.concatWith "\n"
      (List.map (fn line =>
                   case String.fields (fn c => c = #"\t") line of
                     fs as _ :: _ =>
                       if length fs <> length (#header ed) orelse hd fs = "id" then line
                       else String.concatWith "\t" (List.take (fs, 7) @ ["Planned", List.nth (fs, 8), ""] @ List.drop (fs, 10))
                   | [] => line)
                (String.fields (fn c => c = #"\n") (read (fromRoot (#root ed ^ "/conformance.tsv")))))
  fun tableText () = tableTextOf edition98
  fun copyTreeOf (ed : edition) (dir, edits : (string * string) list) =
    let
      val b = #root ed
      val base = [(b ^ "/conformance.tsv", tableTextOf ed), (b ^ "/errata.tsv", read (fromRoot (b ^ "/errata.tsv"))),
                  (b ^ "/deviations.tsv", deviationsHead)]
                 @ List.map (fn (_, _, f) => (f, read (fromRoot f))) (#readings ed)
                 @ (case #shared ed of
                      SOME _ => [("tests/hs/conformance.tsv", read (fromRoot "tests/hs/conformance.tsv")),
                                 (b ^ "/unshared.tsv", String.concatWith "\t" unsharedHeader ^ "\n")]
                    | NONE => [])
      fun one (file, text) = (mkdirs (OS.Path.dir (dir ^ "/" ^ file));
                              write (dir ^ "/" ^ file, case List.find (fn (f, _) => f = file) edits of
                                                         SOME (_, edited) => edited
                                                       | NONE => text))
    in
      rmTree dir; List.app (fn d => (mkdirs (dir ^ "/" ^ b ^ "/" ^ d); mkdirs (dir ^ "/tests/hs/" ^ d))) dirs;
      List.app one base
    end
  fun copyTree x = copyTreeOf edition98 x
  (* the table with the fields of some rows set *)
  fun setFieldsOf hdr (text, sets : (string * string * string) list) =
    String.concatWith "\n"
      (List.map (fn line =>
                   case String.fields (fn c => c = #"\t") line of
                     fs as id :: _ =>
                       let val mine = List.filter (fn (i, _, _) => i = id) sets
                       in
                         if null mine then line
                         else String.concatWith "\t"
                                (ListPair.map (fn (h, f) => case List.find (fn (_, n, _) => n = h) mine of SOME (_, _, v) => v | NONE => f)
                                              (hdr, fs))
                       end
                   | [] => line)
                (String.fields (fn c => c = #"\n") text))
  fun setFields x = setFieldsOf header x
  fun lineOf (text, id) = valOf (List.find (fn l => String.isPrefix (id ^ "\t") l) (String.fields (fn c => c = #"\n") text))

  (* the rows each edition's faults use, from its table: an accept row, a
     run row with a reading, two reject rows, the second with no reading, a
     row with no test *)
  fun faultRows (ed : edition) =
    if #name ed = "98" then
      {accept = "lex.comment.dashcolon", run = "exp.parse.letnonassoc", runReading = "R9", reject = "lex.any.invalid",
       reject2 = "lex.comment.unterminated", none = "intro.implementation"}
    else
      {accept = "lex.comment.dashcolon", run = "lex.string.list", runReading = "R14", reject = "lex.any.invalid",
       reject2 = "lex.comment.unterminated", none = "intro.implementation"}

  fun faultsOf (ed : edition) =
    let
      val base = run ^ "/hs-conformance-faults" ^ (if #name ed = "98" then "" else "-" ^ #name ed)
      val text = tableTextOf ed
      val b = #root ed
      val what = "hs-conformance " ^ #name ed
      (* a case: its name, the edits of the tables, the programs it adds
         (path from the table's directory, or from tests/ where it begins
         with hs/, without its suffix, first line, and .expected), and the
         rule it must break, or "" for none *)
      fun attemptWith want (name, edits, progs, rule) =
        let
          val dir = base ^ "/" ^ name
          val () = copyTreeOf ed (dir, edits)
          fun at path = if String.isPrefix "hs/" path andalso b <> "tests/hs" then dir ^ "/tests/" ^ path else dir ^ "/" ^ b ^ "/" ^ path
          val () = List.app (fn (path, first, expected) =>
                               (write (at path ^ ".hs", first ^ "\nmain :: IO ()\nmain = return ()\n");
                                case expected of SOME e => write (at path ^ ".expected", e) | NONE => ()))
                            progs
          val (errors, _, _) = checkWith ed dir
          val ok = if rule = "" then null errors
                   else List.exists (fn e => String.isPrefix (rule ^ ":") e andalso String.isSubstring want e) errors
        in
          if ok then ()
          else if rule = "" then say ("FAIL " ^ what ^ " fault " ^ name ^ ": a tree that keeps the rules is refused: "
                                      ^ String.concatWith "; " errors ^ "\n")
          else say ("FAIL " ^ what ^ " fault " ^ name ^ ": not refused by " ^ rule ^ (if want = "" then "" else " (" ^ want ^ ")")
                    ^ "; it says: " ^ (if null errors then "nothing" else String.concatWith "; " errors) ^ "\n")
        end
      val attempt = attemptWith ""
      val t = b ^ "/conformance.tsv"
      val dv = b ^ "/deviations.tsv"
      fun table sets = [(t, setFieldsOf (#header ed) (text, sets))]
      val errata = read (fromRoot (b ^ "/errata.tsv"))
      val {accept, run, runReading, reject, reject2, none} = faultRows ed
      val () = if String.isSubstring ("\t" ^ runReading ^ "\t") (lineOf (text, run)) then ()
               else say ("FAIL " ^ what ^ " faults: " ^ run ^ " no longer has the reading " ^ runReading ^ "; choose another row\n")
      (* reject2's pin pins no reading, so reject2 must have none *)
      val () = if String.isSubstring "\tPlanned\t\t" (lineOf (text, reject2)) then ()
               else say ("FAIL " ^ what ^ " faults: " ^ reject2 ^ " is no longer Planned with no reading; choose another row\n")
    in
      attempt ("keeps-the-rules",
               table [(accept, "status", "Supported"), (run, "status", "Partial"), (reject, "status", "Supported"),
                      (run, "deviation", "lang/" ^ run ^ "_pin"), (reject2, "status", "Supported"),
                      (reject2, "deviation", "accept/" ^ reject2 ^ "_taken")]
               @ [(dv, deviationsHead ^ run ^ "\tconceded by the Report\tlang/" ^ run ^ "_pin\tpinned\n"
                       ^ reject2 ^ "\tcontradictory\taccept/" ^ reject2 ^ "_taken\ttaken\n")],
               [("accept/" ^ accept ^ "_op", "-- an accepted program", NONE),
                ("lang/" ^ run ^ "_pin", "-- rows: " ^ runReading ^ " deviation", SOME ""),
                ("errors/" ^ reject ^ "_raw", "-- rows: " ^ reject, SOME "unexpected character"),
                (* a refused row whose deviation is to accept: its pin is accepted *)
                ("accept/" ^ reject2 ^ "_taken", "-- rows: deviation", NONE)],
               "");
      attempt ("no-program", table [(accept, "status", "Supported")], [], "rule 1");
      attempt ("a-program-of-another-class", table [(reject, "status", "Supported")],
               [("lang/" ^ reject ^ "_here", "-- a refused row's program that runs", SOME "")], "rule 1");
      attempt ("a-program-of-no-row", [], [("accept/no.such.row_x", "-- named for no row", NONE)], "rule 2");
      attempt ("a-first-line-of-no-row", [], [("accept/" ^ accept ^ "_more", "-- rows: no.such.row", NONE)], "rule 2");
      attempt ("a-reject-row-run", [], [("lang/" ^ reject ^ "_run", "-- named for a refused row", SOME "")], "rule 2");
      attempt ("no-reason", table [(none, "how", "")], [], "rule 3");
      attempt ("a-reading-unpinned", table [(run, "status", "Supported")],
               [("lang/" ^ run ^ "_plain", "-- pins nothing", SOME "")], "rule 4");
      attempt ("a-stray-pin", [], [("lang/" ^ run ^ "_stray", "-- rows: R2", SOME "")], "rule 4");
      attempt ("a-deviation-without-a-note", table [(run, "deviation", "lang/" ^ run ^ "_pin")],
               [("lang/" ^ run ^ "_pin", "-- rows: " ^ runReading ^ " deviation", SOME "")], "rule 4");
      attempt ("a-note-without-a-deviation",
               [(dv, deviationsHead ^ run ^ "\tconceded by the Report\tlang/" ^ run ^ "_pin\tparse-error(t)\n")],
               [], "rule 4");
      attempt ("a-pin-of-no-deviation", [], [("lang/" ^ run ^ "_loose", "-- rows: deviation", SOME "")], "rule 4");
      attempt ("a-pin-that-says-nothing",
               table [(run, "deviation", "lang/" ^ run ^ "_quiet")]
               @ [(dv, deviationsHead ^ run ^ "\tconceded by the Report\tlang/" ^ run ^ "_quiet\tparse-error(t)\n")],
               [("lang/" ^ run ^ "_quiet", "-- no deviation said", SOME "")], "rule 4");
      attempt ("a-ground-of-no-kind",
               table [(run, "deviation", "lang/" ^ run ^ "_pin")]
               @ [(dv, deviationsHead ^ run ^ "\tunpopular\tlang/" ^ run ^ "_pin\tparse-error(t)\n")],
               [("lang/" ^ run ^ "_pin", "-- rows: " ^ runReading ^ " deviation", SOME "")], "rule 4");
      attempt ("no-message", table [(reject, "status", "Supported")], [("errors/" ^ reject ^ "_raw", "-- refused", NONE)], "rule 5");
      attempt ("a-row-twice", [(t, text ^ lineOf (text, accept) ^ "\n")], [], "table");
      (* a row given another's id: the count holds, the ids do not *)
      attempt ("an-id-twice", table [(none, "id", accept)], [], "table");
      attempt ("a-header", [(t, "id\t" ^ text)], [], "table");
      attempt ("a-status", table [(accept, "status", "Done")], [], "table");
      attempt ("a-reading-of-no-number", table [(accept, "reading", "R99")], [], "table");
      attempt ("a-row-lost", [(t, String.concatWith "\n" (List.filter (fn l => not (String.isPrefix (accept ^ "\t") l))
                                                                      (String.fields (fn c => c = #"\n") text)))], [], "table");
      attempt ("an-erratum-of-no-row", [(b ^ "/errata.tsv", errata ^ "Jan 2026\t1\tplanted\tno.such.row\t\t\n")], [], "errata");
      if #errataCount ed = 0 then ()
      else
        (attempt ("an-erratum-unlisted", table [(none, "how", "an erratum, planted")], [], "errata");
         attempt ("an-erratum-lost",
                  [(b ^ "/errata.tsv", String.concatWith "\n" (List.filter (fn l => not (String.isPrefix "Dec 2005" l))
                                                                         (String.fields (fn c => c = #"\n") errata)))],
                  [], "errata"));
      (* a table that shares another's programs: its own columns, its rows
         against 98's, and what it shares *)
      case #shared ed of
        NONE => ()
      | SOME _ =>
          let
            val (leftId, left98) = hd (#left ed)
            val leftLine = String.concatWith "\t" [leftId, "40", "planted", "library", "run", "", "hand", "Planned", "", "", left98,
                                                   "changed"]
            val removed = valOf (List.find (fn l => String.isSubstring "\tremoved-in-2010" l) (String.fields (fn c => c = #"\n") text))
            val removedId = hd (String.fields (fn c => c = #"\t") removed)
          in
            attemptWith "the delta moved" ("a-delta-of-no-kind", table [(accept, "delta", "moved")], [], "table");
            attemptWith "which is no row of 98's" ("a-map98-of-no-row", table [(accept, "map98", "no.such.row")], [], "table");
            attemptWith "98's row exp.parse.letnonassoc is no row's map98"
                        ("a-row-of-98-unmapped", table [("exp.parse.letnonassoc.h2010", "map98", none)], [], "table");
            attemptWith "is the same as 98's, and comes from" ("a-same-row-from-another", table [(accept, "map98", none)], [],
                                                               "table");
            attemptWith "left the table by a decision" ("a-row-that-left", [(t, text ^ leftLine ^ "\n")], [], "table");
            (* 98's program of a row 2010 keeps is shared, and held to 2010's
               table: here it names a row of another class *)
            attempt ("a-shared-program-of-another-class", table [(reject, "test", "run")],
                     [("hs/errors/" ^ reject ^ "_raw", "-- rows: " ^ reject, SOME "unexpected character")], "rule 2");
            (* one that names a row 2010 removes is not shared at all *)
            attempt ("a-program-of-a-removed-row", [],
                     [("hs/errors/" ^ removedId ^ "_raw", "-- a removed row's", SOME "x")], "");
            attempt ("an-unshared-program-shared-by-none",
                     [(b ^ "/unshared.tsv", String.concatWith "\t" unsharedHeader ^ "\nhs/errors/" ^ removedId ^ "_raw\tplanted\n")],
                     [("hs/errors/" ^ removedId ^ "_raw", "-- a removed row's", SOME "x")], "unshared");
            attempt ("an-unshared-program-of-none",
                     [(b ^ "/unshared.tsv", String.concatWith "\t" unsharedHeader ^ "\nhs/errors/no.such_program\tplanted\n")],
                     [], "unshared");
            attempt ("an-unshared-program-kept",
                     table [(reject, "test", "run")]
                     @ [(b ^ "/unshared.tsv", String.concatWith "\t" unsharedHeader ^ "\nhs/errors/" ^ reject ^ "_raw\tplanted\n")],
                     [("hs/errors/" ^ reject ^ "_raw", "-- rows: " ^ reject, SOME "unexpected character")], "")
          end
    end
  fun faults () = faultsOf edition98

  fun tableOf (ed : edition) () =
    let
      val (errors, rows, progs) = checkWith ed root
      fun count s = Int.toString (length (List.filter (fn (r : row) => #status r = s) rows))
    in
      List.app (fn m => say ("FAIL " ^ m ^ "\n")) errors;
      say ("hs-conformance" ^ (if #name ed = "98" then "" else " " ^ #name ed) ^ ": " ^ Int.toString (length rows)
           ^ " rows (" ^ count "Supported" ^ " Supported, " ^ count "Partial" ^ " Partial, " ^ count "Planned" ^ " Planned), "
           ^ Int.toString (length progs) ^ " programs\n")
    end

  (* ---- the generator of 2010's programs (tools/generate/hs2010.sml),
     held to its work: over this tree, what it writes keeps the 2010 table's
     rules where it would land, and imports no module 2010 renames or drops;
     over planted programs, it writes what it should and leaves out what it
     should, each for its reason *)
  fun copyDir (src, dst) =
    (mkdirs dst;
     List.app (fn n => let val s = src ^ "/" ^ n and d = dst ^ "/" ^ n
                       in if isDir s then copyDir (s, d) else write (d, read s) end) (entries src))
  fun generate (root', out) =
    let
      val log = out ^ ".log"
      val () = mkdirs (OS.Path.dir out)
      val status = execProcess false Subprocess.unlimited (fn e => e)
                     {cmd = [fromRoot "bin/rune-generate", "hs2010-programs", "--root", root', "--out", out], dir = SOME root,
                      stdin = "", stdout = log, stderr = log, timeout = 600}
    in
      if status = 0 then firstNonEmpty log
      else raise Fail ("bin/rune-generate hs2010-programs: status " ^ Int.toString status ^ ": " ^ firstNonEmpty log)
    end
  fun tsvLines f = List.map (String.fields (fn c => c = #"\t")) (tl (lines (read f)) handle Empty => [])

  fun generatorTree () =
    let
      val base = run ^ "/hs2010-generate-tree"
      val out = base ^ "/out"
      val priv = base ^ "/tree"
      val () = (rmTree base; mkdirs base)
      val said = generate (root, out)
      val () = copyTreeOf edition2010 (priv, [])
      val () = List.app (fn d => if isDir (out ^ "/" ^ d) then copyDir (out ^ "/" ^ d, priv ^ "/tests/hs2010/" ^ d) else ()) dirs
      val (errors, _, progs) = checkWith edition2010 priv
      val written = tsvLines (out ^ "/generated.tsv")
      (* what was written imports no module 2010 renames or drops *)
      val still = List.filter (fn (p : program) => #imports98 p) progs
    in
      List.app (fn e => say ("FAIL hs2010 generate: a program written breaks the 2010 table's rules: " ^ e ^ "\n")) errors;
      List.app (fn (p : program) => say ("FAIL hs2010 generate: " ^ #path p ^ " still imports a module 2010 renames or drops\n")) still;
      if null written then say "FAIL hs2010 generate: no program written\n" else ();
      if length progs <> length written then
        say ("FAIL hs2010 generate: " ^ Int.toString (length written) ^ " lines of generated.tsv, " ^ Int.toString (length progs)
             ^ " programs written\n")
      else ();
      say ("hs2010 generate: " ^ said ^ "\n")
    end

  (* the planted programs: each a path under tests/hs, its text, and what
     the generator must make of it, under tests/hs2010, or why it leaves it
     out *)
  val planted : (string * string * string) list =
    [("lang/lib.list.sort_basic.hs",
      "-- rows: a.same R7 R5\nmodule Main (main) where\nimport List (sort,\n             nub)\nimport qualified Char as C\nmain = print (sort [2, 1 :: Int])\n",
      "lang/lib.datalist.sort_basic.hs\t-- rows: a.same R7\nmodule Main (main) where\nimport Data.List as List (sort, nub)\n\nimport qualified Data.Char as C\nmain = print (sort [2, 1 :: Int])\n"),
     ("lang/lib.list.sort_basic.expected", "tests/hs/lang/lib.list.sort_basic.hs:6: [1,2]\n",
      "lang/lib.datalist.sort_basic.expected\ttests/hs2010/lang/lib.datalist.sort_basic.hs:6: [1,2]\n"),
     ("lang/lib.io.hclose_split.hs",
      "module Main (main) where\nimport IO (hClose, ioError, IOMode(..))\nimport IO hiding (hClose)\nimport qualified IO as I\nmain = return ()\n",
      "lang/lib.systemio.hclose_split.hs\tmodule Main (main) where\nimport System.IO as IO (hClose, IOMode(..)); import System.IO.Error as IO (ioError)\n"
      ^ "import System.IO as IO hiding (hClose); import System.IO.Error as IO\nimport qualified System.IO as I; import qualified System.IO.Error as I\nmain = return ()\n"),
     ("lang/a.same_lit.lhs", "> module Main (main) where\n> import List\n\n> main = print (List.sort [1 :: Int])\n",
      "lang/a.same_lit.lhs\t> module Main (main) where\n> import Data.List as List\n\n> main = print (List.sort [1 :: Int])\n"),
     ("lang/a.same_plain.hs", "module Main (main) where\nmain = return ()\n", ""),
     ("errors/a.same_time.hs", "import Time\nmain = return ()\n", "skipped\tit imports Time, which Haskell 2010's library drops"),
     ("lang/pat.npk.toplevel_n.hs", "import List\nmain = return ()\n", "skipped\tit names pat.npk.toplevel, which Haskell 2010 removes"),
     ("lang/x.y_z.hs", "import List\nmain = return ()\n",
      "skipped\tit names x.y, which Haskell 2010 changes beyond a rename (x.y.h2010): its 2010 program is written by hand"),
     ("errors/lib.io.hclose_bad.hs", "import IO (nosuch)\nmain = return ()\n",
      "skipped\tit imports nosuch of IO, which no module of System.IO or System.IO.Error exports")]
  val plantedTable =
    String.concatWith "\t" (#header edition2010) ^ "\n"
    ^ String.concat (List.map (fn (id, statement, how, reading, map98, delta) =>
                                 String.concatWith "\t" [id, "1", statement, "library", "run", how, "hand", "Planned", reading, "", map98,
                                                         delta] ^ "\n")
        [("a.same", "a row kept", "", "R7", "a.same", "same"),
         ("lib.datalist.sort", "sort", "rename List -> Data.List", "", "lib.list.sort", "changed"),
         ("lib.datachar.toupper", "toUpper", "rename Char -> Data.Char", "", "lib.char.toupper", "changed"),
         ("lib.systemio.hclose", "hClose", "rename IO -> System.IO", "", "lib.io.hclose", "changed"),
         ("lib.systemioerror.ioerror", "ioError", "rename IO -> System.IO.Error", "", "lib.io.ioerror", "changed"),
         ("lib.systemio.export.hclose", "module System.IO exports hClose", "", "", "-", "new"),
         ("lib.systemio.export.iomode", "module System.IO exports IOMode(ReadMode,WriteMode)", "", "", "-", "new"),
         ("lib.systemioerror.export.ioerror", "module System.IO.Error exports ioError", "", "", "-", "new"),
         ("pat.npk.toplevel", "n+k", "removed in 2010", "", "pat.npk.toplevel", "removed-in-2010"),
         ("x.y.h2010", "changed", "a change", "", "x.y", "changed")])

  fun generatorFaults () =
    let
      val base = run ^ "/hs2010-generate-faults"
      val priv = base ^ "/tree"
      val out = base ^ "/out"
      val () = (rmTree base; List.app (fn d => mkdirs (priv ^ "/tests/hs/" ^ d)) dirs; mkdirs (priv ^ "/tests/hs2010"))
      val () = write (priv ^ "/tests/hs2010/conformance.tsv", plantedTable)
      val () = List.app (fn (path, text, _) => write (priv ^ "/tests/hs/" ^ path, text)) planted
      val _ = generate (priv, out)
      val skipped = tsvLines (out ^ "/skipped.tsv")
      val generated = tsvLines (out ^ "/generated.tsv")
      fun check (path, _, want) =
        case String.fields (fn c => c = #"\t") want of
          [""] => if List.exists (fn fs => List.nth (fs, 1) = OS.Path.base (OS.Path.file path)) (generated @ skipped)
                  then say ("FAIL hs2010 generate fault: " ^ path ^ ", which needs nothing of 2010, is written or left out\n") else ()
        | ["skipped", why] =>
            (case List.find (fn fs => List.nth (fs, 1) = OS.Path.base (OS.Path.file path)) skipped of
               SOME fs => if List.nth (fs, 2) = why then ()
                          else say ("FAIL hs2010 generate fault: " ^ path ^ " left out because `" ^ List.nth (fs, 2) ^ "`, not `" ^ why ^ "`\n")
             | NONE => say ("FAIL hs2010 generate fault: " ^ path ^ " is not left out (" ^ why ^ ")\n"))
        | [file, text] =>
            let val got = read (out ^ "/" ^ file)
            in if got = text then ()
               else say ("FAIL hs2010 generate fault: " ^ path ^ " gives " ^ out ^ "/" ^ file ^ ", " ^ difference' (got, text) ^ "\n") end
        | _ => say ("FAIL hs2010 generate fault: a planted case of no form: " ^ want ^ "\n")
      and difference' (a, b) =
        let fun go (n, x :: xs, y :: ys) = if x = y then go (n + 1, xs, ys) else "line " ^ Int.toString n ^ ": `" ^ x ^ "`, not `" ^ y ^ "`"
              | go (n, x :: _, []) = "line " ^ Int.toString n ^ ": `" ^ x ^ "` past the end"
              | go (n, [], y :: _) = "line " ^ Int.toString n ^ ": nothing, not `" ^ y ^ "`"
              | go (_, [], []) = "the same"
        in go (1, String.fields (fn c => c = #"\n") a, String.fields (fn c => c = #"\n") b) end
      val sortRow = List.find (fn fs => List.nth (fs, 1) = "lib.list.sort_basic") generated
    in
      List.app check planted;
      case sortRow of
        SOME fs => if List.nth (fs, 3) = "lib.datalist.sort a.same" andalso List.nth (fs, 4) = "dropped R5" then ()
                   else say ("FAIL hs2010 generate fault: lib.list.sort_basic's rows and drops are `" ^ List.nth (fs, 3) ^ "`, `"
                             ^ List.nth (fs, 4) ^ "`\n")
      | NONE => say "FAIL hs2010 generate fault: lib.list.sort_basic is not written\n";
      say ("hs2010 generate faults: " ^ Int.toString (length planted) ^ " planted cases\n")
    end

  fun command args =
    case args of
      ["hs2010-generate", "tree"] => SOME (fn () => generatorTree () handle Fail m => say ("FAIL hs2010 generate: " ^ m ^ "\n"))
    | ["hs2010-generate", "faults"] => SOME (fn () => generatorFaults () handle Fail m => say ("FAIL hs2010 generate: " ^ m ^ "\n"))
    | ["hs-conformance"] => SOME (tableOf edition98)
    | ["hs-conformance", "2010"] => SOME (tableOf edition2010)
    | ["hs-conformance-faults"] => SOME faults
    | ["hs-conformance-faults", "2010"] => SOME (fn () => faultsOf edition2010)
    | _ => NONE

  fun job (name, args) =
    Test.it name
      {program = "/bin/sh",
       args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 600, cap = 0, cpus = 1, memory = 1000,
       pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree
  fun tree () =
    List.foldl (fn (tag, t) => Test.tag tag t)
      (Test.describe ""
         [Test.describe "hs/conformance" [job ("table", ["hs-conformance"]), job ("faults", ["hs-conformance-faults"])],
          Test.tag "covers:tests/hs2010/*"
            (Test.describe "hs2010/conformance" [job ("table", ["hs-conformance", "2010"]),
                                                 job ("faults", ["hs-conformance-faults", "2010"])]),
          Test.tag "covers:tools/generate/hs2010.sml"
            (Test.describe "hs2010/generate" [job ("tree", ["hs2010-generate", "tree"]), job ("faults", ["hs2010-generate", "faults"])])])
      ["check", "hs", "quick", "covers:tests/hs/conformance.tsv", "covers:tests/hs/errata.tsv", "covers:tests/hs/deviations.tsv", "covers:tests/hs/readings.md",
       "covers:tests/hs/lang/*", "covers:tests/hs/accept/*", "covers:tests/hs/errors/*", "covers:tests/runner/hsconformance.sml"]
end
