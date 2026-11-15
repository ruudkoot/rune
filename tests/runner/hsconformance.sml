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
   wants it refused, and a row pinned as the rules want accepted. *)
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
              reading : string list, deviation : string}
  fun field (fields, name) =
    let fun go (h :: hs, f :: fs) = if h = name then f else go (hs, fs)
          | go _ = ""
    in go (header, fields) end
  fun goodId id =
    id <> "" andalso Char.isLower (String.sub (id, 0))
    andalso CharVector.all (fn c => Char.isLower c orelse Char.isDigit c orelse c = #".") id
  (* the readings of tests/hs/readings.md under root: its headings ### Rn. *)
  fun readingsOf root =
    List.mapPartial (fn l => case String.tokens Char.isSpace l of
                               "###" :: r :: _ => if size r > 2 andalso String.sub (r, 0) = #"R" andalso String.isSuffix "." r
                                                  then Int.fromString (String.substring (r, 1, size r - 2)) else NONE
                             | _ => NONE)
                    (String.fields (fn c => c = #"\n") (read (root ^ "/tests/hs/readings.md")))
  fun goodReading more r =
    size r > 1 andalso String.sub (r, 0) = #"R" andalso CharVector.all Char.isDigit (String.extract (r, 1, NONE))
    andalso (case Int.fromString (String.extract (r, 1, NONE)) of
               SOME n => (n >= 1 andalso n <= readings) orelse List.exists (fn m => m = n) more
             | NONE => false)
  fun isReading w = size w > 1 andalso String.sub (w, 0) = #"R" andalso CharVector.all Char.isDigit (String.extract (w, 1, NONE))

  (* ---- the programs *)
  type program = {dir : string, path : string, name : string, ids : string list, pins : string list, deviation : bool,
                  expected : string}
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
  fun programs root : program list =
    List.concat (List.map (fn d =>
      List.map (fn (p : Lang.program) =>
        let
          val ws = firstWords (#src p)
          val ids = idsOf p
        in
          {dir = d, path = d ^ "/" ^ #name p, name = #name p, ids = ids, pins = List.filter isReading ws,
           deviation = member ("deviation", ws), expected = #base p ^ ".expected"}
        end)
        (Lang.programsOf (root ^ "/tests/hs/" ^ d, [".hs", ".lhs"], ["Main.hs", "Main.lhs"])))
      dirs)
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

  (* ---- the check: the failures of the tree at root *)
  fun check root =
    let
      val errors = ref [] : string list ref
      fun fail m = errors := m :: !errors
      fun tsv (file, hdr) =
        DocChecks.tsv (root ^ "/" ^ file) hdr
        handle DocChecks.Failed m => (fail ("table: " ^ m); [])
      val table = tsv ("tests/hs/conformance.tsv", header)
      val errata = tsv ("tests/hs/errata.tsv", errataHeader)
      val notes = tsv ("tests/hs/deviations.tsv", deviationsHeader)
      val more = readingsOf root
      (* the table's form *)
      val rows : row list =
        List.map (fn fs =>
          let
            val id = field (fs, "id")
            val reading = String.tokens Char.isSpace (field (fs, "reading"))
            fun one (name, allowed) =
              if member (field (fs, name), allowed) then ()
              else fail ("table: " ^ id ^ " has the " ^ name ^ " " ^ field (fs, name) ^ ", not one of " ^ String.concatWith ", " allowed)
          in
            if goodId id then () else fail ("table: the id " ^ id ^ " is not lower-case letters, digits and dots");
            one ("class", classes); one ("test", testKinds); one ("status", statuses); one ("source", sources);
            List.app (fn r => if goodReading more r then ()
                              else fail ("table: " ^ id ^ " has the reading " ^ r ^ ", neither one of R1 to R" ^ Int.toString readings
                                         ^ " nor one of tests/hs/readings.md")) reading;
            {id = id, section = field (fs, "section"), statement = field (fs, "statement"), test = field (fs, "test"),
             how = field (fs, "how"), status = field (fs, "status"), reading = reading, deviation = field (fs, "deviation")}
          end) table
      val byId = Vector.fromList (sortBy #id rows)
      fun row id = case lookup (byId, #id) id of r :: _ => SOME r | [] => NONE
      val () = Vector.appi (fn (i, r : row) => if i > 0 andalso #id (Vector.sub (byId, i - 1)) = #id r
                                                then fail ("table: the id " ^ #id r ^ " is twice") else ()) byId
      (* the errata *)
      fun words s = String.tokens Char.isSpace s
      val added = List.concat (List.map (fn fs => words (List.nth (fs, 4))) errata)
      val listed = List.concat (List.map (fn fs => words (List.nth (fs, 3))) errata) @ added
      val () = if length errata = errataCount then ()
               else fail ("errata: tests/hs/errata.tsv lists " ^ Int.toString (length errata) ^ " errata, not the page's "
                          ^ Int.toString errataCount)
      val () = List.app (fn fs => case List.filter (fn gs => List.take (gs, 2) = List.take (fs, 2)) errata of
                                    [_] => ()
                                  | _ => fail ("errata: " ^ String.concatWith " " (List.take (fs, 2)) ^ " is listed twice")) errata
      val () = List.app (fn id => if isSome (row id) then () else fail ("errata: an erratum names " ^ id ^ ", which is no row")) listed
      val () = if length rows = clauses + length added then ()
               else fail ("table: " ^ Int.toString (length rows) ^ " rows, where E9's " ^ Int.toString clauses ^ " and the "
                          ^ Int.toString (length added) ^ " the errata add are " ^ Int.toString (clauses + length added))
      fun namesErratum (r : row) =
        let fun has s = String.isSubstring "errat" (String.map Char.toLower s) in has (#statement r) orelse has (#how r) end
      val () = List.app (fn (r : row) =>
                           case (namesErratum r, member (#id r, listed)) of
                             (true, false) => fail ("errata: " ^ #id r ^ " names an erratum, and no erratum lists it")
                           | (false, true) => fail ("errata: an erratum lists " ^ #id r ^ ", whose text names none")
                           | _ => ()) rows
      (* the programs, and the rows each names *)
      val progs = programs root
      val naming = Vector.fromList (sortBy #1 (List.concat (List.map (fn (p : program) => List.map (fn id => (id, p)) (#ids p)) progs)))
      fun programsOf id = List.map #2 (lookup (naming, #1) id)
      val () = List.app (fn (p : program) =>
                           let
                             val twice = List.filter (fn (q : program) => #dir q = #dir p andalso #name q = #name p) progs
                           in if length twice > 1 then fail ("table: two programs named " ^ #path p) else () end) progs
      (* a program is a row's pin: it says deviation, and the row names it *)
      fun pins (p : program, r : row) = #deviation p andalso #deviation r = #path p
      (* rule 1 *)
      val () = List.app (fn (r : row) =>
                           if #status r = "Planned" orelse #test r = "none" then ()
                           else if List.exists (fn (p : program) => member (#dir p, serves (#test r)) orelse pins (p, r))
                                               (programsOf (#id r)) then ()
                           else fail ("rule 1: " ^ #id r ^ " is " ^ #status r ^ ", and no program of tests/hs/"
                                      ^ String.concatWith " or tests/hs/" (serves (#test r)) ^ " names it")) rows
      (* rule 2 *)
      val () = List.app (fn (p : program) =>
                           List.app (fn id =>
                                       case row id of
                                         NONE => fail ("rule 2: " ^ #path p ^ " names " ^ id ^ ", which is no row")
                                       | SOME r => if member (#dir p, serves (#test r)) orelse pins (p, r) then ()
                                                   else fail ("rule 2: " ^ #path p ^ " names " ^ id ^ ", whose test is " ^ #test r
                                                              ^ ", which tests/hs/" ^ #dir p ^ " does not serve"))
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
                              | [] => fail ("rule 4: " ^ #id r ^ " deviates, and has no note in tests/hs/deviations.tsv")
                              | _ => fail ("rule 4: " ^ #id r ^ " has two notes in tests/hs/deviations.tsv"))) rows
      val () = List.app (fn fs => case row (hd fs) of
                                    SOME r => if #deviation r = "" then fail ("rule 4: tests/hs/deviations.tsv notes " ^ hd fs
                                                                              ^ ", which does not deviate") else ()
                                  | NONE => fail ("rule 4: tests/hs/deviations.tsv notes " ^ hd fs ^ ", which is no row")) notes
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

  fun table () =
    let
      val (errors, rows, progs) = check root
      fun count s = Int.toString (length (List.filter (fn (r : row) => #status r = s) rows))
    in
      List.app (fn m => say ("FAIL " ^ m ^ "\n")) errors;
      say ("hs-conformance: " ^ Int.toString (length rows) ^ " rows (" ^ count "Supported" ^ " Supported, " ^ count "Partial"
           ^ " Partial, " ^ count "Planned" ^ " Planned), " ^ Int.toString (length progs) ^ " programs\n")
    end

  (* ---- breaches planted in a private tree *)
  (* the base of each: the tree's table with every row Planned and no
     deviation, none noted, and the tree's errata and readings; no program *)
  val deviationsHead = String.concatWith "\t" deviationsHeader ^ "\n"
  fun tableText () =
    String.concatWith "\n"
      (List.map (fn line =>
                   case String.fields (fn c => c = #"\t") line of
                     fs as [_, _, _, _, _, _, _, _, _, _] =>
                       if hd fs = "id" then line
                       else String.concatWith "\t" (List.take (fs, 7) @ ["Planned", List.nth (fs, 8), ""])
                   | _ => line)
                (String.fields (fn c => c = #"\n") (read (fromRoot "tests/hs/conformance.tsv"))))
  fun copyTree (dir, edits : (string * string) list) =
    let
      val base = [("tests/hs/conformance.tsv", tableText ()), ("tests/hs/errata.tsv", read (fromRoot "tests/hs/errata.tsv")),
                  ("tests/hs/readings.md", read (fromRoot "tests/hs/readings.md")),
                  ("tests/hs/deviations.tsv", deviationsHead)]
      fun one (file, text) = write (dir ^ "/" ^ file, case List.find (fn (f, _) => f = file) edits of
                                                        SOME (_, edited) => edited
                                                      | NONE => text)
    in
      rmTree dir; List.app (fn d => mkdirs (dir ^ "/tests/hs/" ^ d)) dirs;
      List.app one base
    end
  (* the table with the fields of some rows set *)
  fun setFields (text, sets : (string * string * string) list) =
    String.concatWith "\n"
      (List.map (fn line =>
                   case String.fields (fn c => c = #"\t") line of
                     fs as id :: _ =>
                       let val mine = List.filter (fn (i, _, _) => i = id) sets
                       in
                         if null mine then line
                         else String.concatWith "\t"
                                (ListPair.map (fn (h, f) => case List.find (fn (_, n, _) => n = h) mine of SOME (_, _, v) => v | NONE => f)
                                              (header, fs))
                       end
                   | [] => line)
                (String.fields (fn c => c = #"\n") text))
  fun lineOf (text, id) = valOf (List.find (fn l => String.isPrefix (id ^ "\t") l) (String.fields (fn c => c = #"\n") text))

  fun faults () =
    let
      val base = run ^ "/hs-conformance-faults"
      val text = tableText ()
      (* a case: its name, the edits of the tables, the programs it adds
         (path from tests/hs, without its suffix, first line, and .expected),
         and the rule it must break, or "" for none *)
      fun attempt (name, edits, progs, rule) =
        let
          val dir = base ^ "/" ^ name
          val () = copyTree (dir, edits)
          val () = List.app (fn (path, first, expected) =>
                               (write (dir ^ "/tests/hs/" ^ path ^ ".hs", first ^ "\nmain :: IO ()\nmain = return ()\n");
                                case expected of SOME e => write (dir ^ "/tests/hs/" ^ path ^ ".expected", e) | NONE => ()))
                            progs
          val (errors, _, _) = check dir
          val ok = if rule = "" then null errors else List.exists (String.isPrefix (rule ^ ":")) errors
        in
          if ok then ()
          else if rule = "" then say ("FAIL hs-conformance fault " ^ name ^ ": a tree that keeps the rules is refused: "
                                      ^ String.concatWith "; " errors ^ "\n")
          else say ("FAIL hs-conformance fault " ^ name ^ ": not refused by " ^ rule ^ "; it says: "
                    ^ (if null errors then "nothing" else String.concatWith "; " errors) ^ "\n")
        end
      val t = "tests/hs/conformance.tsv"
      fun table sets = [(t, setFields (text, sets))]
      val errata = read (fromRoot "tests/hs/errata.tsv")
      (* rows of each kind, from the table: an accept row, a run row with a
         reading, two reject rows, the second with no reading, a row with no
         test *)
      val accept = "lex.comment.dashcolon"
      val run = "exp.parse.letnonassoc"
      val runReading = "R9"
      val reject = "lex.any.invalid"
      val reject2 = "lex.comment.unterminated"
      val none = "intro.implementation"
      val () = if String.isSubstring ("\t" ^ runReading ^ "\t") (lineOf (text, run)) then ()
               else say ("FAIL hs-conformance faults: " ^ run ^ " no longer has the reading " ^ runReading ^ "; choose another row\n")
      (* reject2's pin pins no reading, so reject2 must have none *)
      val () = if String.isSubstring "\tPlanned\t\t" (lineOf (text, reject2)) then ()
               else say ("FAIL hs-conformance faults: " ^ reject2 ^ " is no longer Planned with no reading; choose another row\n")
    in
      attempt ("keeps-the-rules",
               table [(accept, "status", "Supported"), (run, "status", "Partial"), (reject, "status", "Supported"),
                      (run, "deviation", "lang/" ^ run ^ "_pin"), (reject2, "status", "Supported"),
                      (reject2, "deviation", "accept/" ^ reject2 ^ "_taken")]
               @ [("tests/hs/deviations.tsv", deviationsHead ^ run ^ "\tconceded by the Report\tlang/" ^ run ^ "_pin\tpinned\n"
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
               [("tests/hs/deviations.tsv", deviationsHead ^ run ^ "\tconceded by the Report\tlang/" ^ run ^ "_pin\tparse-error(t)\n")],
               [], "rule 4");
      attempt ("a-pin-of-no-deviation", [], [("lang/" ^ run ^ "_loose", "-- rows: deviation", SOME "")], "rule 4");
      attempt ("a-pin-that-says-nothing",
               table [(run, "deviation", "lang/" ^ run ^ "_quiet")]
               @ [("tests/hs/deviations.tsv", deviationsHead ^ run ^ "\tconceded by the Report\tlang/" ^ run ^ "_quiet\tparse-error(t)\n")],
               [("lang/" ^ run ^ "_quiet", "-- no deviation said", SOME "")], "rule 4");
      attempt ("a-ground-of-no-kind",
               table [(run, "deviation", "lang/" ^ run ^ "_pin")]
               @ [("tests/hs/deviations.tsv", deviationsHead ^ run ^ "\tunpopular\tlang/" ^ run ^ "_pin\tparse-error(t)\n")],
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
      attempt ("an-erratum-of-no-row", [("tests/hs/errata.tsv", errata ^ "Jan 2026\t1\tplanted\tno.such.row\t\t\n")], [], "errata");
      attempt ("an-erratum-unlisted", table [(none, "how", "an erratum, planted")], [], "errata");
      attempt ("an-erratum-lost",
               [("tests/hs/errata.tsv", String.concatWith "\n" (List.filter (fn l => not (String.isPrefix "Dec 2005" l))
                                                                            (String.fields (fn c => c = #"\n") errata)))],
               [], "errata")
    end

  fun command args =
    case args of
      ["hs-conformance"] => SOME table
    | ["hs-conformance-faults"] => SOME faults
    | _ => NONE

  fun job (name, args) =
    Test.it name
      {program = "/bin/sh",
       args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 600, cap = 0, cpus = 1, memory = 1000,
       pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree
  fun tree () =
    List.foldl (fn (tag, t) => Test.tag tag t)
      (Test.describe "hs/conformance" [job ("table", ["hs-conformance"]), job ("faults", ["hs-conformance-faults"])])
      ["check", "hs", "quick", "covers:tests/hs/conformance.tsv", "covers:tests/hs/errata.tsv", "covers:tests/hs/deviations.tsv", "covers:tests/hs/readings.md",
       "covers:tests/hs/lang/*", "covers:tests/hs/accept/*", "covers:tests/hs/errors/*", "covers:tests/runner/hsconformance.sml"]
end
