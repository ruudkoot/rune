(* rhc's library, share/rhc/haskell98 (the haskell98 roadmap's M17, M18;
   D36, D37, D38): what it is held to while no compiler runs it. Each job
   prints a line FAIL for what it finds.

   - hs/library/overlay: each module's tokens against the Report's as
     printed (pristine/), by module: every line where they differ is in
     an entry of overlay.tsv marked applied, every file the Report has no
     text of is an entry's `new:`, and overlay.tsv is well formed. The
     tokens are compared a line at a time, white space and comments
     dropped, as DocChecks.signatures compares the Basis's signatures with
     their transcription.
   - hs/library/pristine: pristine/ is what its MANIFEST.tsv says, byte for
     byte, by SHA-256.
   - hs/library/report: the names of the Report's 20 modules, by
     `bin/rhc --dump-names`, are E16's table of the Report (663 export
     pairs, 35 fixities, 164 instances: tests/hs/library/report.names),
     changed exactly by the lines tests/hs/library/overlay.names gives, each
     with the entry of overlay.tsv it is of.
   - hs/library/compile: the 20 modules compile (M18): bin/rhc --whole
     compiles tests/hs/library/All20.hs, which uses a name of each, and
     the VM runs it to All20.expected and the status 3 of its exitWith.
   - hs/library/exitzero: exitWith (ExitFailure 0) is an IOError
     isIllegalOperation holds of (ov.system.exitzero, ruling 57): on
     Core's interpreter and on the VM, ExitZeroCaught catches it and goes
     on, status 0; ExitZeroUncaught ends with status 1, its output written.
   - hs/library/devicefull: on a full device (/dev/full) hFlush, hClose,
     writeFile, appendFile and an unbuffered hPutStr raise isFullError
     (ruling 62), on Core's interpreter and on the VM (DeviceFull.hs). *)
structure HsLibrary =
struct
  open Sh

  fun fail s = say ("FAIL " ^ s ^ "\n")

  val share = "share/rhc/haskell98"

  (* the lines of a text, the empty ones too, so that a line's number is
     its place *)
  fun allLines s = String.fields (fn c => c = #"\n") s

  fun isPrefixAt (s, i, p) = i + size p <= size s andalso String.substring (s, i, size p) = p

  (* ---- tokens: what the Report's lexical syntax makes of a text, close
     enough that two texts with the same tokens have them and two that
     differ in code do not: white space and comments dropped, a string
     with its gaps taken out ---- *)

  fun isSymbol c = Char.contains "!#$%&*+./<=>?@\\^|-~:" c
  fun isIdChar c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'"

  (* `tokens text` is each token of the text, with the number of its line *)
  fun tokens (text : string) : (string * int) list =
    let
      val n = size text
      fun at i = if i < n then String.sub (text, i) else #"\000"
      fun go (i, line, acc) =
        if i >= n then List.rev acc
        else
          let val c = at i
          in
            if c = #"\n" then go (i + 1, line + 1, acc)
            else if Char.isSpace c then go (i + 1, line, acc)
            else if isPrefixAt (text, i, "--") then
              let
                fun dashes j = if at j = #"-" then dashes (j + 1) else j
                val j = dashes i
              in
                if isSymbol (at j) then symbol (i, line, acc)
                else
                  let fun eol k = if k >= n orelse at k = #"\n" then k else eol (k + 1)
                  in go (eol j, line, acc) end
              end
            else if isPrefixAt (text, i, "{-") then
              let
                fun block (k, depth, line) =
                  if k >= n then (k, line)
                  else if isPrefixAt (text, k, "-}") then (if depth = 1 then (k + 2, line) else block (k + 2, depth - 1, line))
                  else if isPrefixAt (text, k, "{-") then block (k + 2, depth + 1, line)
                  else block (k + 1, depth, if at k = #"\n" then line + 1 else line)
                val (k, line') = block (i + 2, 1, line)
              in
                go (k, line', acc)
              end
            else if c = #"\"" then
              let
                (* the string's characters, a gap taken out *)
                fun str (k, line', chars) =
                  if k >= n then (k, line', chars)
                  else if at k = #"\"" then (k + 1, line', chars)
                  else if at k = #"\\" andalso Char.isSpace (at (k + 1)) then
                    let fun gap (j, l) = if at j = #"\\" orelse j >= n then (j + 1, l)
                                         else gap (j + 1, if at j = #"\n" then l + 1 else l)
                        val (j, l) = gap (k + 1, line')
                    in str (j, l, chars) end
                  else if at k = #"\\" then str (k + 2, line', at (k + 1) :: at k :: chars)
                  else str (k + 1, line', at k :: chars)
                val (k, line', chars) = str (i + 1, line, [])
              in
                go (k, line', ("\"" ^ String.implode (List.rev chars) ^ "\"", line) :: acc)
              end
            else if c = #"'" then
              let
                fun chr (k, chars) =
                  if k >= n orelse at k = #"\n" then (k, chars)
                  else if at k = #"'" then (k + 1, chars)
                  else if at k = #"\\" then chr (k + 2, at (k + 1) :: at k :: chars)
                  else chr (k + 1, at k :: chars)
                val (k, chars) = chr (i + 1, [])
              in
                go (k, line, ("'" ^ String.implode (List.rev chars) ^ "'", line) :: acc)
              end
            else if Char.isAlpha c orelse c = #"_" then
              let fun id k = if isIdChar (at k) then id (k + 1) else k
                  val k = id i
              in go (k, line, (String.substring (text, i, k - i), line) :: acc) end
            else if Char.isDigit c then
              let
                fun digits k = if Char.isHexDigit (at k) orelse at k = #"x" orelse at k = #"o"
                                  orelse at k = #"X" orelse at k = #"O" then digits (k + 1) else k
                val k = digits i
                val k = if at k = #"." andalso Char.isDigit (at (k + 1)) then digits (k + 1) else k
                val k = if (at k = #"e" orelse at k = #"E")
                           andalso (Char.isDigit (at (k + 1)) orelse
                                    ((at (k + 1) = #"+" orelse at (k + 1) = #"-") andalso Char.isDigit (at (k + 2))))
                        then digits (k + 2) else k
              in
                go (k, line, (String.substring (text, i, k - i), line) :: acc)
              end
            else if isSymbol c then symbol (i, line, acc)
            else go (i + 1, line, (str c, line) :: acc)
          end
      and symbol (i, line, acc) =
        let fun sym k = if isSymbol (at k) then sym (k + 1) else k
            val k = sym i
        in go (k, line, (String.substring (text, i, k - i), line) :: acc) end
    in
      go (0, 1, [])
    end

  (* the tokens of a text, a line's together: the lines that have any, each
     as its file, its number and its tokens *)
  fun tokenLines (file, text) : (string * int * string) list =
    let
      fun group ([], acc) = List.rev acc
        | group ((t, l) :: rest, (f, l', ts) :: acc) =
            if l = l' then group (rest, (f, l, ts ^ " " ^ t) :: acc) else group (rest, (file, l, t) :: (f, l', ts) :: acc)
        | group ((t, l) :: rest, []) = group (rest, [(file, l, t)])
    in
      group (tokens text, [])
    end

  (* ---- overlay.tsv ---- *)

  type entry = {id : string, lines : string, kind : string, status : string}

  val kinds = ["erratum", "reading", "unresolved", "builtin", "elided", "primitive", "instances", "representation",
               "option", "nochange"]
  val statuses = ["applied", "listed", "open", "none"]

  fun entries () : entry list =
    let
      val rows = List.filter (fn l => not (String.isPrefix "#" l)) (lines (read (fromRoot (share ^ "/overlay.tsv"))))
    in
      case rows of
        [] => (fail "hs/library/overlay: overlay.tsv has no rows"; [])
      | header :: body =>
          List.mapPartial
            (fn row =>
               case String.fields (fn c => c = #"\t") row of
                 [id, _, _, ls, kind, _, status, _] =>
                   (if List.exists (fn k => k = kind) kinds then () else fail ("hs/library/overlay: " ^ id ^ ": kind " ^ kind);
                    if List.exists (fn s => s = status) statuses then () else fail ("hs/library/overlay: " ^ id ^ ": status " ^ status);
                    SOME {id = id, lines = ls, kind = kind, status = status})
               | fs => (fail ("hs/library/overlay: a row of " ^ Int.toString (length fs) ^ " columns, not 8: " ^ row); NONE))
            body
    end

  fun splitOn sep s =
    let
      fun go (i, start, acc) =
        if i + size sep > size s then List.rev (String.extract (s, start, NONE) :: acc)
        else if String.substring (s, i, size sep) = sep then go (i + size sep, i + size sep, String.substring (s, start, i - start) :: acc)
        else go (i + 1, start, acc)
    in
      go (0, 0, [])
    end

  (* what an entry's column lines names: lines of files of pristine/, and
     files of rhc's own (`new:`) *)
  fun places (e : entry) : ((string * int) list * string list) =
    List.foldl
      (fn (part, (ls, news)) =>
         if String.isPrefix "new:" part then (ls, String.extract (part, 4, NONE) :: news)
         else
           case splitOn ":" part of
             [file, ranges] =>
               (List.concat
                  (List.map (fn r =>
                               case List.mapPartial Int.fromString (splitOn "-" r) of
                                 [a] => [(file, a)]
                               | [a, b] => List.tabulate (b - a + 1, fn k => (file, a + k))
                               | _ => (fail ("hs/library/overlay: " ^ #id e ^ ": a range " ^ r); []))
                     (splitOn "," ranges)) @ ls, news)
           | _ => (fail ("hs/library/overlay: " ^ #id e ^ ": lines " ^ part); (ls, news)))
      ([], []) (if #lines e = "" then [] else splitOn "; " (#lines e))

  (* ---- the longest common subsequence of two lists of token lines ---- *)

  (* the pairs (i, j) of the lines in common, in order *)
  fun common (a : string vector, b : string vector) : (int * int) list =
    let
      val (n, m) = (Vector.length a, Vector.length b)
      val t = Array.array ((n + 1) * (m + 1), 0)
      fun get (i, j) = Array.sub (t, i * (m + 1) + j)
      fun fill i =
        if i < 0 then ()
        else
          let
            fun row j =
              if j < 0 then ()
              else
                (Array.update (t, i * (m + 1) + j,
                               if Vector.sub (a, i) = Vector.sub (b, j) then get (i + 1, j + 1) + 1
                               else Int.max (get (i + 1, j), get (i, j + 1)));
                 row (j - 1))
          in
            row (m - 1); fill (i - 1)
          end
      val () = fill (n - 1)
      fun walk (i, j, acc) =
        if i >= n orelse j >= m then List.rev acc
        else if Vector.sub (a, i) = Vector.sub (b, j) then walk (i + 1, j + 1, (i, j) :: acc)
        else if get (i + 1, j) >= get (i, j + 1) then walk (i + 1, j, acc)
        else walk (i, j + 1, acc)
    in
      walk (0, 0, [])
    end

  (* the lines of the base that a text changes, by place, and, for a line
     the text adds, the base's lines either side of it *)
  fun changes (base : (string * int * string) list, text : (string * int * string) list) =
    let
      val a = Vector.fromList (List.map #3 base)
      val b = Vector.fromList (List.map #3 text)
      val pairs = common (a, b)
      val baseAt = Vector.fromList base
      fun placeOf i = let val (f, l, _) = Vector.sub (baseAt, i) in (f, l) end
      (* the gaps between the pairs: base lines removed, text lines added *)
      fun gaps ((i0, j0), [], acc) = finish ((i0, j0), (Vector.length a, Vector.length b), acc)
        | gaps ((i0, j0), (i, j) :: rest, acc) = gaps ((i + 1, j + 1), rest, finish ((i0, j0), (i, j), acc))
      and finish ((i0, j0), (i, j), acc) =
        let
          val removedPlaces = List.tabulate (i - i0, fn k => placeOf (i0 + k))
          val neighbours = List.mapPartial (fn k => if k >= 0 andalso k < Vector.length a then SOME (placeOf k) else NONE)
                             [i0 - 1, i]
          (* a line added where lines are removed is of their change; one
             added alone, of a change at a line either side *)
          val added = if j > j0 then [if null removedPlaces then neighbours else removedPlaces] else []
        in
          acc @ List.map (fn p => [p]) removedPlaces @ added
        end
    in
      gaps ((0, 0), pairs, [])
    end

  (* ---- the jobs ---- *)

  fun moduleFiles () =
    List.filter (fn f => String.isSuffix ".hs" f) (sort (Sh.entries (fromRoot share)))

  fun overlay () =
    let
      val es = entries ()
      val applied = List.filter (fn e => #status e = "applied") es
      val placed = List.map (fn e => (e, places e)) es
      val covered = List.concat (List.map (fn (e, (ls, _)) => if #status e = "applied" then ls else []) placed)
      val news = List.concat (List.map (fn (e, (_, ns)) => if #status e = "applied" then ns else []) placed)
      fun isCovered p = List.exists (fn q => q = p) covered
      (* each place an entry names is a line of its file *)
      val () =
        List.app (fn (e, (ls, ns)) =>
                    (List.app (fn (f, l) =>
                                 let val count = length (allLines (read (fromRoot (share ^ "/pristine/" ^ f))))
                                 in if l >= 1 andalso l <= count then ()
                                    else fail ("hs/library/overlay: " ^ #id e ^ ": " ^ f ^ ":" ^ Int.toString l ^
                                               " is no line of pristine/" ^ f)
                                 end) ls;
                     List.app (fn f => if exists (fromRoot (share ^ "/" ^ f)) then ()
                                       else fail ("hs/library/overlay: " ^ #id e ^ ": no file " ^ f)) ns))
          placed
      fun baseOf m =
        if m = "IO.hs" then tokenLines ("synopsis/IO.hs", read (fromRoot (share ^ "/pristine/synopsis/IO.hs")))
                            @ tokenLines ("IO.hs", read (fromRoot (share ^ "/pristine/IO.hs")))
        else tokenLines (m, read (fromRoot (share ^ "/pristine/" ^ m)))
      val counts = ref (0, 0)
      fun one m =
        if not (exists (fromRoot (share ^ "/pristine/" ^ m))) then
          (if List.exists (fn f => f = m) news then ()
           else fail ("hs/library/overlay: " ^ m ^ ": the Report has no text of it, and no entry names it new"))
        else
          let
            val found = changes (baseOf m, tokenLines (m, read (fromRoot (share ^ "/" ^ m))))
            val uncovered = List.filter (fn ps => not (List.exists isCovered ps) andalso not (null ps)) found
            val () = counts := (#1 (!counts) + 1, #2 (!counts) + length found)
          in
            List.app (fn ps => fail ("hs/library/overlay: " ^ m ^ " differs from the Report at " ^
                                     String.concatWith " or " (List.map (fn (f, l) => f ^ ":" ^ Int.toString l) ps) ^
                                     ", which no applied entry of overlay.tsv names"))
              uncovered
          end
      val () = List.app one (moduleFiles ())
    in
      say ("hs/library/overlay: " ^ Int.toString (#1 (!counts)) ^ " modules against the Report's text, " ^
           Int.toString (#2 (!counts)) ^ " changed places, " ^ Int.toString (length applied) ^ " entries applied of " ^
           Int.toString (length es) ^ "\n")
    end

  fun binary file =
    let val s = BinIO.openIn file in Byte.bytesToString (BinIO.inputAll s) before BinIO.closeIn s end

  fun pristine () =
    let
      val rows = List.filter (fn l => not (String.isPrefix "#" l)) (lines (read (fromRoot (share ^ "/pristine/MANIFEST.tsv"))))
      val files = List.mapPartial (fn row => case String.fields (fn c => c = #"\t") row of
                                                file :: _ :: _ :: _ :: _ :: count :: sha :: _ =>
                                                  if file = "file" then NONE else SOME (file, count, sha)
                                              | _ => (fail ("hs/library/pristine: a row of MANIFEST.tsv: " ^ row); NONE)) rows
      fun one (file, count, sha) =
        let val path = fromRoot (share ^ "/pristine/" ^ file)
            val bytes = binary path
        in
          if Hex.fromBytes (Sha256.digest bytes) = sha then ()
          else fail ("hs/library/pristine: " ^ file ^ " is not the Report's text that MANIFEST.tsv records (sha256)")
        end
      val listed = List.map #1 files
      val onDisk = List.map (fn f => f) (List.filter (String.isSuffix ".hs") (Sh.entries (fromRoot (share ^ "/pristine"))))
                   @ List.map (fn f => "synopsis/" ^ f) (List.filter (String.isSuffix ".hs") (Sh.entries (fromRoot (share ^ "/pristine/synopsis"))))
    in
      List.app one files;
      List.app (fn f => if List.exists (fn g => g = f) listed then () else fail ("hs/library/pristine: " ^ f ^ " is in no row of MANIFEST.tsv")) onDisk;
      say ("hs/library/pristine: " ^ Int.toString (length files) ^ " files as MANIFEST.tsv records them\n")
    end

  (* the Report's 20 modules *)
  val reportModules =
    ["Prelude", "PreludeList", "PreludeText", "PreludeIO", "Ratio", "Complex", "Numeric", "Ix", "Array", "List", "Maybe",
     "Char", "Monad", "IO", "Directory", "System", "Time", "Locale", "CPUTime", "Random"]

  (* whether a line of the dump is about the Report's modules: an export
     or an instance of one of them, or the fixity of one's entity *)
  fun ofReport line =
    let
      fun isReport id = List.exists (fn m => id = "haskell98:" ^ m) reportModules
    in
      case String.fields (fn c => c = #"\t") line of
        "EXPORT" :: m :: _ => isReport m
      | "INSTANCE" :: m :: _ => isReport m
      | "FIX" :: e :: _ =>
          (case String.tokens (fn c => c = #" ") (String.extract (e, 1, NONE)) of
             id :: _ => isReport id
           | [] => false)
      | "ERROR" :: _ => true
      | _ => false
    end

  fun report () =
    let
      val out = run ^ "/hs-library"
      val () = mkdirs out
      val dump = out ^ "/report.dump"
      val status = exec {cmd = [fromRoot "bin/rhc", "--dump-names", fromRoot "tests/hs/names/report/All.hs"], dir = NONE,
                         stdin = "", stdout = dump, stderr = dump ^ ".err", timeout = 600}
      val got = List.filter ofReport (lines (read dump))
      val table = List.filter (fn l => not (String.isPrefix "#" l)) (lines (read (fromRoot "tests/hs/library/report.names")))
      val changes = List.filter (fn l => not (String.isPrefix "#" l)) (lines (read (fromRoot "tests/hs/library/overlay.names")))
      val ids = List.map #id (entries ())
      fun parse l =
        case String.fields (fn c => c = #"\t") l of
          sign :: rest =>
            let val n = length rest
                val (line, id) = (String.concatWith "\t" (List.take (rest, n - 1)), List.nth (rest, n - 1))
            in
              if List.exists (fn i => i = id) ids then () else fail ("hs/library/report: overlay.names names no entry " ^ id);
              (sign, line)
            end
        | [] => ("", "")
      val parsed = List.map parse changes
      val removed = List.map #2 (List.filter (fn (s, _) => s = "-") parsed)
      val added = List.map #2 (List.filter (fn (s, _) => s = "+") parsed)
      fun member (x, xs) = List.exists (fn y => y = x) xs
      val want = List.filter (fn l => not (member (l, removed))) table @ added
      val () = List.app (fn l => if member (l, table) then () else fail ("hs/library/report: a line removed is no line of the Report's table: " ^ l)) removed
      val lost = List.filter (fn l => not (member (l, got))) want
      val gained = List.filter (fn l => not (member (l, want))) got
      fun count prefix ls = Int.toString (length (List.filter (String.isPrefix prefix) ls))
    in
      if status <> 0 then fail ("hs/library/report: bin/rhc --dump-names fails: " ^ firstLine (dump ^ ".err"))
      else
        (List.app (fn l => fail ("hs/library/report: expected, not printed: " ^ l)) lost;
         List.app (fn l => fail ("hs/library/report: printed, not expected: " ^ l)) gained;
         say ("hs/library/report: the Report's table, " ^ count "EXPORT" table ^ " export pairs, " ^ count "FIX" table ^
              " fixities, " ^ count "INSTANCE" table ^ " instances; the overlay adds " ^ Int.toString (length added) ^
              " lines and takes " ^ Int.toString (length removed) ^ "\n"))
    end

  fun compile () =
    let
      val out = run ^ "/hs-library"
      val () = mkdirs out
      fun f x = out ^ "/" ^ x
      val cs = exec {cmd = [fromRoot "bin/rhc", "--whole", "--lint=2", fromRoot "tests/hs/library/All20.hs", "-o", f "all20.rbc"],
                     dir = NONE, stdin = "", stdout = f "all20.c", stderr = f "all20.c", timeout = 900}
    in
      if cs <> 0 then fail ("hs/library/compile: bin/rhc does not compile the 20 modules: " ^ firstLine (f "all20.c"))
      else
        let
          val rs = exec {cmd = [fromRoot "bin/runevm", f "all20.rbc"], dir = SOME out, stdin = "", stdout = f "all20.out",
                         stderr = f "all20.err", timeout = 300}
        in
          if rs <> 3 then fail ("hs/library/compile: All20 ends with status " ^ Int.toString rs ^ ", not 3: " ^ firstLine (f "all20.err"))
          else if read (f "all20.out") <> read (fromRoot "tests/hs/library/All20.expected") then
            fail ("hs/library/compile: All20 prints otherwise than tests/hs/library/All20.expected (" ^ f "all20.out" ^ ")")
          else say "hs/library/compile: the 20 modules compiled whole; the program over them prints what it should\n"
        end
    end

  (* `both (job, name, status)`: tests/hs/library/NAME.hs through bin/rhc --whole
     on Core's interpreter and compiled to the VM, each printing NAME.expected
     and ending with the status *)
  fun both (job, name, status) =
    let
      val out = run ^ "/hs-library/" ^ name
      val () = mkdirs out
      fun f x = out ^ "/" ^ x
      val src = fromRoot ("tests/hs/library/" ^ name ^ ".hs")
      val want = read (fromRoot ("tests/hs/library/" ^ name ^ ".expected"))
      fun judge (way, st, stdout, stderr) =
        if st <> status then fail ("hs/library/" ^ job ^ ": " ^ name ^ " ends with status " ^ Int.toString st ^ " on " ^ way ^ ", not " ^
                                   Int.toString status ^ ": " ^ firstLine stderr)
        else if read stdout <> want then fail ("hs/library/" ^ job ^ ": " ^ name ^ " prints otherwise than its .expected on " ^ way ^
                                              " (" ^ stdout ^ ")")
        else ()
      val ist = exec {cmd = [fromRoot "bin/rhc", "--whole", "--lint=3", src], dir = SOME out, stdin = "", stdout = f "i.out",
                      stderr = f "i.err", timeout = 600}
      val () = judge ("Core's interpreter", ist, f "i.out", f "i.err")
      val cst = exec {cmd = [fromRoot "bin/rhc", "--whole", "--lint=2", src, "-o", f "p.rbc"], dir = NONE, stdin = "",
                      stdout = f "c.err", stderr = f "c.err", timeout = 600}
    in
      if cst <> 0 then fail ("hs/library/" ^ job ^ ": bin/rhc does not compile " ^ name ^ ": " ^ firstLine (f "c.err"))
      else
        judge ("the VM", exec {cmd = [fromRoot "bin/runevm", f "p.rbc"], dir = SOME out, stdin = "", stdout = f "v.out",
                               stderr = f "v.err", timeout = 300},
               f "v.out", f "v.err")
    end

  fun exitzero () =
    (both ("exitzero", "ExitZeroCaught", 0); both ("exitzero", "ExitZeroUncaught", 1);
     say "hs/library/exitzero: exitWith (ExitFailure 0) an IOError, caught and uncaught, on the interpreter and the VM\n")

  fun devicefull () =
    (both ("devicefull", "DeviceFull", 0);
     say "hs/library/devicefull: a full device's IOError, isFullError, from hFlush, hClose, writeFile, appendFile and hPutStr\n")

  fun job (name, cmd) =
    Test.it name
      {program = "/bin/sh", args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ cmd],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 600, cap = 0, cpus = 1, memory = 500,
       pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags

  val covers = ["covers:share/rhc/*", "covers:tests/hs/library/*", "covers:tests/runner/hslibrary.sml",
                "covers:src/rhc/*", "covers:lib/language/haskell/*"]

  fun tree () =
    Test.describe "hs/library"
      [tagged (["check", "hs", "quick"] @ covers)
         (Test.describe ""
            [job ("overlay", "hs-library-overlay"), job ("pristine", "hs-library-pristine"),
             job ("report", "hs-library-report"), job ("compile", "hs-library-compile"),
             job ("exitzero", "hs-library-exitzero"), job ("devicefull", "hs-library-devicefull")])]

  fun command args =
    case args of
      ["hs-library-overlay"] => SOME overlay
    | ["hs-library-pristine"] => SOME pristine
    | ["hs-library-report"] => SOME report
    | ["hs-library-compile"] => SOME compile
    | ["hs-library-exitzero"] => SOME exitzero
    | ["hs-library-devicefull"] => SOME devicefull
    | _ => NONE
end
