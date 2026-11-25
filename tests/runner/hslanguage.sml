(* A module's language (the haskell2010 roadmap's M4, *Tracking language
   settings*, D4 to D10; docs/rhc.md, A module's language): rhc's record of
   each module's edition and features, resolved from the command line and
   the module's header, which the stages ask by module and the store keys
   each unit by.

   - `hs/language/cases/NAME`: each case of tests/hs/language/cases, a
     directory with the program's files and `cmd`, the arguments of
     `bin/rhc`, the root among them: what rhc prints, its standard output,
     then its standard error, then `status N`, compiled a unit at a time
     into a store of its own and `--whole`, both at level 2, is the case's
     `expected`, and the two ways print the same (E4's per-module cases,
     with the features in modules of Haskell 2010, since a module of 98
     reads only the editions its header names: D6). Written again with
     --accept.
   - `hs/language/edits/PROGRAM`: E13's edit test made a test: each program
     a module graph edited step by step, a LANGUAGE pragma added, dropped or
     changed, an edition by pragma, an ordinary edit, the command line's
     setting changed; at each step a compile against a store kept from step
     to step (warm) and one with `--no-store` (cold), at level 2: both make
     the same bytecode, or both refuse with the same diagnostics, the units
     of the program the warm compile makes are those the step names (the
     edited module's unit, which its text and its set key, and no unit
     whose reads of it give what they gave), and every unit of the library
     is taken from the snapshot. Two spellings of one set share a unit
     (p10), and a setting no key held would let a unit made under one
     setting serve another, where the cold compile refuses (p04, p05, p06). *)
structure HsLanguageJobs =
struct
  open Sh

  val accepting = env ("RUNE_TEST_ACCEPT", "") = "1"
  fun fail s = say ("FAIL " ^ s ^ "\n")

  val dir = "tests/hs/language"
  val out = run ^ "/hs-language"

  fun bytesOf p = (let val i = BinIO.openIn p in Byte.bytesToString (BinIO.inputAll i) before BinIO.closeIn i end)
                  handle IO.Io _ => ""

  (* the files of a directory and its directories, copied *)
  fun copyTree (src, dst) =
    (mkdirs dst;
     List.app (fn n => let val s = src ^ "/" ^ n
                           val d = dst ^ "/" ^ n
                       in if isDir s then copyTree (s, d) else write (d, read s) end)
       (entries src))

  (* bin/rhc in d at level 2, RHC_STORE unset: its status; what it printed
     in LOG.out and LOG.err *)
  fun rhcIn (d, args, log) =
    execEnv (fn e => setEnv ("RUNE_LINT", "2") (unsetEnv ["RHC_STORE"] e))
      {cmd = [fromRoot "bin/rhc"] @ args, dir = SOME d, stdin = "", stdout = log ^ ".out", stderr = log ^ ".err",
       timeout = 900}

  (* ---- the per-module cases ---- *)

  fun caseNames () =
    let val d = fromRoot (dir ^ "/cases")
    in List.filter (fn c => exists (d ^ "/" ^ c ^ "/cmd")) (sort (entries d)) end

  fun caseOne name =
    let
      val src = fromRoot (dir ^ "/cases/" ^ name)
      val d = out ^ "/cases/" ^ name
      val () = (rmTree d; copyTree (src, d))
      val args = String.tokens Char.isSpace (read (d ^ "/cmd"))
      fun way (flags, log) =
        let val status = rhcIn (d, flags @ args, d ^ "/" ^ log)
        in read (d ^ "/" ^ log ^ ".out") ^ read (d ^ "/" ^ log ^ ".err") ^ "status " ^ Int.toString status ^ "\n" end
      val units = way (["--store", "st"], "units")
      val whole = way (["--whole", "--no-store"], "whole")
      val () = write (d ^ "/units.said", units)
      val () = write (d ^ "/whole.said", whole)
      val expected = src ^ "/expected"
    in
      if accepting then write (expected, units)
      else if units <> read expected then
        fail ("hs/language/cases/" ^ name ^ ": by units, not what `expected` says: " ^ difference (d ^ "/units.said", expected))
      else if whole <> units then
        fail ("hs/language/cases/" ^ name ^ ": --whole prints otherwise than by units: " ^
              difference (d ^ "/whole.said", d ^ "/units.said"))
      else ()
    end

  (* ---- the store under edits (E13) ---- *)

  (* An edit of a program's file: a LANGUAGE pragma of these names put at
     its head (a literate file's as a line of code), its first LANGUAGE
     line dropped or made one of these names, or a text replaced. *)
  datatype edit =
      Add of string * string
    | Drop of string
    | Set of string * string
    | Replace of string * string * string

  (* What a step expects: every unit of the program made, those units of the
     program made and every other taken, or both compiles refused. *)
  datatype expect = All | Made of string list | Refused

  type step = {what : string, edits : edit list, flags : string list, expect : expect}

  fun st (what, edits, flags, expect) : step = {what = what, edits = edits, flags = flags, expect = expect}

  val mainA = "module Main (main) where\nimport A\nmain :: IO ()\nmain = print (a 3)\n"
  val aPlain = "module A (a) where\na :: Int -> Int\na n = n * 2\n"
  val relaxedA = "{-# LANGUAGE Haskell2010 #-}\nmodule A (f, g) where\nf :: Eq a => a -> Bool\nf x = x == x || g True\n" ^
                 "g :: Ord a => a -> Bool\ng y = y < y || f y\n"

  val programs : (string * (string * string) list * step list) list =
    [("p01-two", [("Main.hs", mainA), ("A.hs", aPlain)],
      [st ("the first compile, into an empty store", [], [], All),
       st ("A: add Haskell2010", [Add ("A.hs", "Haskell2010")], [], Made ["A"]),
       st ("A: its pragma becomes Haskell2010, NPlusKPatterns", [Set ("A.hs", "Haskell2010, NPlusKPatterns")], [], Made ["A"]),
       st ("A: its pragma Haskell2010 again (step 1's text and set)", [Set ("A.hs", "Haskell2010")], [], Made []),
       st ("A: its pragma dropped (step 0's)", [Drop "A.hs"], [], Made []),
       st ("A: add RelaxedPolyRec, which a module of 98 does not read (its text another, its set 98's)",
           [Add ("A.hs", "RelaxedPolyRec")], [], Made ["A"])]),
     ("p02-chain", [("Main.hs", "module Main (main) where\nimport B\nmain :: IO ()\nmain = print (b 3)\n"),
                    ("B.hs", "module B (b) where\nimport A\nb :: Int -> Int\nb n = a n + 1\n"), ("A.hs", aPlain)],
      [st ("the first compile", [], [], All),
       st ("A: add Haskell2010", [Add ("A.hs", "Haskell2010")], [], Made ["A"]),
       st ("B: add Haskell2010", [Add ("B.hs", "Haskell2010")], [], Made ["B"]),
       st ("A: its pragma becomes Haskell2010, NPlusKPatterns", [Set ("A.hs", "Haskell2010, NPlusKPatterns")], [], Made ["A"]),
       st ("B: its pragma dropped (step 0's text)", [Drop "B.hs"], [], Made [])]),
     ("p03-cycle", [("Main.hs", "module Main (main) where\nimport A\nimport C\nmain :: IO ()\nmain = print (a 4, c 1)\n"),
                    ("A.hs", "module A (a) where\nimport {-# SOURCE #-} B (b)\na :: Int -> Int\na n = if n > 0 then b (n - 1) else 0\n"),
                    ("B.hs", "module B (b) where\nimport A (a)\nb :: Int -> Int\nb n = a n + 1\n"),
                    ("C.hs", "module C (c) where\nc :: Int -> Int\nc n = n + 10\n")],
      [st ("the first compile", [], [], All),
       st ("A: add Haskell2010 (one unit, A and B made again together)", [Add ("A.hs", "Haskell2010")], [], Made ["A+B"]),
       st ("B: add Haskell2010", [Add ("B.hs", "Haskell2010")], [], Made ["A+B"]),
       st ("C: add Haskell2010", [Add ("C.hs", "Haskell2010")], [], Made ["C"]),
       st ("A: its pragma dropped (a cycle of a 98 module and a 2010 one)", [Drop "A.hs"], [], Made ["A+B"])]),
     ("p04-npk", [("Main.hs", mainA), ("A.hs", "module A (a) where\na :: Int -> Int\na 0 = 0\na (n+1) = 2 + a n\n")],
      [st ("the first compile", [], [], All),
       st ("A: add Haskell2010, which has no n+k patterns", [Add ("A.hs", "Haskell2010")], [], Refused),
       st ("A: its pragma dropped (step 0's)", [Drop "A.hs"], [], Made []),
       st ("A: add Haskell2010, NPlusKPatterns", [Add ("A.hs", "Haskell2010, NPlusKPatterns")], [], Made ["A"]),
       st ("A: its pragma becomes NoNPlusKPatterns, which a module of 98 does not read",
           [Set ("A.hs", "NoNPlusKPatterns")], [], Made ["A"])]),
     ("p05-dotted", [("Main.hs", "{-# LANGUAGE Haskell2010 #-}\nmodule Main (main) where\nimport Data.Thing (thing)\n" ^
                                 "main :: IO ()\nmain = print thing\n"),
                     ("Data/Thing.hs", "{-# LANGUAGE Haskell2010 #-}\nmodule Data.Thing (thing) where\nthing :: Int\nthing = 42\n")],
      [st ("the first compile: a dotted import of a module of Haskell 2010", [], [], All),
       st ("Main: its pragma dropped, a module of 98, which has no dotted names", [Drop "Main.hs"], [], Refused),
       st ("Main: add Haskell2010 (step 0's)", [Add ("Main.hs", "Haskell2010")], [], Made []),
       st ("command line --dotted-names: Haskell 2010's set the same", [], ["--dotted-names"], Made []),
       st ("Main: its pragma dropped, under --dotted-names", [Drop "Main.hs"], ["--dotted-names"], Made ["Main"]),
       st ("command line as at step 0", [], [], Refused)]),
     ("p06-relaxed", [("Main.hs", "module Main (main) where\nimport A\nmain :: IO ()\nmain = print (f 'c', g (1 :: Int))\n"),
                      ("A.hs", relaxedA)],
      [st ("the first compile: 4.5.1's case in a module of Haskell 2010", [], [], All),
       st ("A: its pragma becomes RelaxedPolyRec, which a module of 98 does not read", [Set ("A.hs", "RelaxedPolyRec")], [],
           Refused),
       st ("A: its pragma Haskell2010 again (step 0's)", [Set ("A.hs", "Haskell2010")], [], Made []),
       st ("A: its pragma dropped, under -XRelaxedPolyRec", [Drop "A.hs"], ["-XRelaxedPolyRec"], Made ["A", "Main"]),
       st ("the same again", [], ["-XRelaxedPolyRec"], Made []),
       st ("the command line without -XRelaxedPolyRec", [], [], Refused)]),
     ("p07-literate", [("Main.hs", mainA), ("A.lhs", "> module A (a) where\n> a :: Int -> Int\n> a n = n * 2\n")],
      [st ("the first compile", [], [], All),
       st ("A: add > {-# LANGUAGE Haskell2010 #-}", [Add ("A.lhs", "Haskell2010")], [], Made ["A"]),
       st ("A: the pragma moved into commentary, which unlit blanks",
           [Replace ("A.lhs", "> {-# LANGUAGE Haskell2010 #-}\n", "{-# LANGUAGE Haskell2010 #-} in commentary\n\n")], [], Made ["A"]),
       st ("A: the pragma code again (step 1's)",
           [Replace ("A.lhs", "{-# LANGUAGE Haskell2010 #-} in commentary\n\n", "> {-# LANGUAGE Haskell2010 #-}\n")], [], Made [])]),
     ("p08-diamond", [("Main.hs", "module Main (main) where\nimport B\nimport C\nmain :: IO ()\nmain = print (b 1 + c 2)\n"),
                      ("B.hs", "module B (b) where\nimport A\nb :: Int -> Int\nb = a\n"),
                      ("C.hs", "module C (c) where\nimport A\nc :: Int -> Int\nc n = a (n + 1)\n"), ("A.hs", aPlain)],
      [st ("the first compile", [], [], All),
       st ("A: add Haskell2010", [Add ("A.hs", "Haskell2010")], [], Made ["A"]),
       st ("A: a's body changed, its type not", [Replace ("A.hs", "a n = n * 2", "a n = n * 3")], [], Made ["A"]),
       st ("A: an export added, which B and C do not read",
           [Replace ("A.hs", "module A (a) where", "module A (a, z) where\nz :: Int\nz = 0")], [], Made ["A"])]),
     ("p09-cmdline", [("Main.hs", mainA), ("A.hs", "{-# LANGUAGE Haskell2010 #-}\n" ^ aPlain)],
      [st ("the first compile", [], [], All),
       st ("command line -XRelaxedPolyRec: A's set of 2010 has it already", [], ["-XRelaxedPolyRec"], Made ["Main"]),
       st ("command line -XNoNPlusKPatterns: so has A's", [], ["-XNoNPlusKPatterns"], Made ["Main"]),
       st ("command line as at step 0", [], [], Made []),
       st ("command line -XHaskell2010: Main's set A's", [], ["-XHaskell2010"], Made ["Main"])]),
     ("p10-spellings", [("Main.hs", mainA), ("A.hs", aPlain)],
      [st ("the first compile, under -XHaskell2010", [], ["-XHaskell2010"], All),
       st ("-XHaskell2010 -XRelaxedPolyRec: the same set", [], ["-XHaskell2010", "-XRelaxedPolyRec"], Made []),
       st ("-XRelaxedPolyRec -XHaskell2010: the edition a base", [], ["-XRelaxedPolyRec", "-XHaskell2010"], Made []),
       st ("-XHaskell2010 -XNoNPlusKPatterns: the same set", [], ["-XHaskell2010", "-XNoNPlusKPatterns"], Made []),
       st ("no flag: Haskell 98's sets, first made here", [], [], Made ["A", "Main"]),
       st ("-XNPlusKPatterns: Haskell 98's own set", [], ["-XNPlusKPatterns"], Made []),
       st ("--dotted-names -XHaskell2010: Haskell 2010's set", [], ["--dotted-names", "-XHaskell2010"], Made [])])]

  fun programNames () = List.map #1 programs

  (* the index of `old` in `t`, if it is there *)
  fun indexOf (t, old) =
    let fun go i = if i + size old > size t then NONE else if String.substring (t, i, size old) = old then SOME i else go (i + 1)
    in go 0 end

  fun applyEdit (d, label) e =
    let
      fun f x = d ^ "/" ^ x
      fun isLanguage l = String.isPrefix "{-# LANGUAGE" l orelse String.isPrefix "> {-# LANGUAGE" l
      fun pragma (file, names) = (if String.isSuffix ".lhs" file then "> " else "") ^ "{-# LANGUAGE " ^ names ^ " #-}"
      fun firstLanguage (file, g) =
        let
          val ls = String.fields (fn c => c = #"\n") (read (f file))
          fun go (_, []) = fail ("hs/language/edits/" ^ label ^ ": " ^ file ^ " has no LANGUAGE pragma")
            | go (prior, l :: rest) =
                if isLanguage l then write (f file, String.concatWith "\n" (List.rev prior @ g l @ rest))
                else go (l :: prior, rest)
        in
          go ([], ls)
        end
    in
      case e of
        Add (file, names) => write (f file, pragma (file, names) ^ "\n" ^ read (f file))
      | Drop file => firstLanguage (file, fn _ => [])
      | Set (file, names) => firstLanguage (file, fn _ => [pragma (file, names)])
      | Replace (file, old, new) =>
          let val t = read (f file)
          in
            case indexOf (t, old) of
              SOME i => write (f file, String.substring (t, 0, i) ^ new ^ String.extract (t, i + size old, NONE))
            | NONE => fail ("hs/language/edits/" ^ label ^ ": " ^ file ^ " has no `" ^ old ^ "`")
          end
    end

  (* what --show-units says of each unit: its name and how *)
  fun unitsSaid text =
    List.mapPartial (fn l => if String.isPrefix "rhc: unit " l
                             then case String.tokens (fn c => c = #" " orelse c = #",") (String.extract (l, 10, NONE)) of
                                    n :: how :: _ => SOME (String.substring (n, 0, size n - 1), how)
                                  | _ => NONE
                             else NONE)
      (lines text)

  fun isLibraryUnit n = List.exists (fn c => c = #":") (String.explode (hd (String.fields (fn c => c = #"+") n)))

  fun editsOne name =
    case List.find (fn (n, _, _) => n = name) programs of
      NONE => fail ("hs/language/edits/" ^ name ^ ": no such program")
    | SOME (_, files, steps) =>
        let
          val d = out ^ "/edits/" ^ name
          fun f x = d ^ "/" ^ x
          val () = (rmTree d; mkdirs d)
          val () = List.app (fn (file, text) => (mkdirs (OS.Path.dir (f file)); write (f file, text))) files
          fun step (k, {what, edits, flags, expect} : step) =
            let
              val label = name ^ "/" ^ Int.toString k
              fun no why = fail ("hs/language/edits/" ^ label ^ " (" ^ what ^ "): " ^ why)
              val () = List.app (applyEdit (d, label)) edits
              val n = Int.toString k
              val warm = rhcIn (d, flags @ ["--store", "st", "--show-units", "Main.hs", "-o", "warm" ^ n ^ ".rbc"], f ("warm" ^ n))
              val cold = rhcIn (d, flags @ ["--no-store", "Main.hs", "-o", "cold" ^ n ^ ".rbc"], f ("cold" ^ n))
              val said = unitsSaid (read (f ("warm" ^ n ^ ".err")))
              val (lib, prog) = List.partition (fn (u, _) => isLibraryUnit u) said
              val made = sort (List.map #1 (List.filter (fn (_, how) => how <> "taken") prog))
              fun diags log = String.concatWith "\n" (List.filter (fn l => not (String.isPrefix "rhc: " l)) (lines (read log)))
            in
              if warm = 0 andalso cold = 0 then
                let val (w, c) = (bytesOf (f ("warm" ^ n ^ ".rbc")), bytesOf (f ("cold" ^ n ^ ".rbc")))
                in
                  if size w <= 12 orelse String.extract (w, 12, NONE) <> String.extract (c, 12, NONE) then
                    no "the warm compile's bytecode is not the cold compile's"
                  else ()
                end
              else if warm <> 0 andalso cold <> 0 then
                if diags (f ("warm" ^ n ^ ".err")) <> diags (f ("cold" ^ n ^ ".err")) then
                  no ("both refuse, otherwise: " ^ difference (f ("warm" ^ n ^ ".err"), f ("cold" ^ n ^ ".err")))
                else ()
              else no ("the warm compile ends with status " ^ Int.toString warm ^ " and the cold one with " ^ Int.toString cold ^
                       ": " ^ firstLine (f ("warm" ^ n ^ ".err")) ^ " / " ^ firstLine (f ("cold" ^ n ^ ".err")));
              List.app (fn (u, how) => if how = "taken" then () else no ("the library's unit " ^ u ^ " is " ^ how)) lib;
              case expect of
                All => if List.exists (fn (_, how) => how = "taken") prog then
                         no ("a unit of the program is taken from an empty store: " ^ String.concatWith ", " (List.map #1 prog))
                       else ()
              | Made us =>
                  if warm <> 0 then no ("refused: " ^ firstLine (f ("warm" ^ n ^ ".err")))
                  else if made = sort us then ()
                  else no ("the units made are " ^ String.concatWith ", " made ^ " where " ^ String.concatWith ", " (sort us) ^
                           " are expected")
              | Refused => if warm = 0 then no "compiles, where it is refused" else ()
            end
        in
          ListPair.app step (List.tabulate (length steps, fn i => i), steps)
        end

  (* ---- the tree ---- *)

  val covers = ["covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:share/rhc/*", "covers:tests/hs/language/*",
                "covers:tests/runner/hslanguage.sml", "covers:rhc.build", "covers:rhc.plan"]

  fun tree () =
    let
      fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
      val cases = List.map (fn c => Tools.job ("cases/" ^ c, ["hs-language-case", c], [], 500, 900)) (caseNames ())
      val edits = List.map (fn p => Tools.job ("edits/" ^ p, ["hs-language-edits", p], [], 600, 1800)) (programNames ())
    in
      tagged (["hs"] @ covers) (Test.requires ["rhc"] (Test.describe "hs/language" (List.map (tagged ["check"]) (cases @ edits))))
    end

  fun command args =
    case args of
      ["hs-language-case", name] => SOME (fn () => caseOne name)
    | ["hs-language-edits", name] => SOME (fn () => editsOne name)
    | _ => NONE
end
